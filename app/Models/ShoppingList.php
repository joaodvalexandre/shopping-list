<?php

namespace App\Models;

use App\Enums\ListAbility;
use App\Models\Concerns\Syncable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;

class ShoppingList extends Model
{
    use HasFactory, Syncable;

    protected $fillable = ['uuid', 'name', 'name_changed_at', 'family_id', 'list_type_id', 'created_by'];

    /** Synced field => column holding when it last changed. */
    protected array $syncedFields = ['name' => 'name_changed_at'];

    protected function casts(): array
    {
        return ['name_changed_at' => 'datetime'];
    }

    /**
     * A shopping list has many items.
     */
    public function items()
    {
        return $this->hasMany(Item::class, 'shopping_list_id');
    }

    public function family(): BelongsTo
    {
        return $this->belongsTo(Family::class);
    }

    public function listType(): BelongsTo
    {
        return $this->belongsTo(ListType::class);
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    /**
     * Members who must not see this list at all.
     */
    public function hiddenFrom(): BelongsToMany
    {
        return $this->belongsToMany(User::class, 'shopping_list_hidden_from');
    }

    public function isHiddenFrom(User $user): bool
    {
        return $this->hiddenFrom()->where('users.id', $user->id)->exists();
    }

    /**
     * The only way lists should be fetched for a signed-in user: same family,
     * a list type they may view, and not hidden from them. Hiding wins over
     * every role, admins included.
     */
    public function scopeVisibleTo(Builder $query, User $user): Builder
    {
        return $query
            ->where('shopping_lists.family_id', $user->family_id)
            ->whereIn('shopping_lists.list_type_id', $user->listTypeIdsWith(ListAbility::View))
            ->whereDoesntHave('hiddenFrom', fn (Builder $hidden) => $hidden->where('users.id', $user->id));
    }

    /**
     * Get total number of items in the list.
     */
    public function getTotalItems()
    {
        return $this->items()->count();
    }

    /**
     * Count items by status name.
     */
    private function getItemsByStatus(string $statusName): int
    {
        return $this->items()
            ->whereHas('status', fn($q) => $q->where('code', $statusName))
            ->count();
    }

    public function getPendingItems(): int
    {
        return $this->getItemsByStatus('to_buy');
    }

    public function getPurchasedItems(): int
    {
        return $this->getItemsByStatus('purchased');
    }

    public function getInCartItems(): int
    {
        return $this->getItemsByStatus('in_cart');
    }

    /**
     * Calculate the dynamic status of the shopping list.
     */
    public function calculateStatus(): array
    {
        $total = $this->getTotalItems();

        if ($total === 0) {
            return [
                'name' => 'no_items',
                'color' => 'gray',
                'icon' => 'cart-off'
            ];
        }

        $toBuy = $this->getPendingItems();
        $inCart = $this->getInCartItems();
        $purchased = $this->getPurchasedItems();

        if ($purchased === $total) {
            return [
                'name' => 'finished',
                'color' => 'green',
                'icon' => 'check-circle'
            ];
        }

        if ($inCart === $total) {
            return [
                'name' => 'all_in_cart',
                'color' => 'blue',
                'icon' => 'cart-check'
            ];
        }

        if ($inCart > 0) {
            return [
                'name' => 'shopping',
                'color' => 'orange',
                'icon' => 'cart-outline'
            ];
        }

        if ($toBuy === $total) {
            return [
                'name' => 'pending',
                'color' => 'yellow',
                'icon' => 'cart-arrow-down'
            ];
        }

        return [
            'name' => 'mixed',
            'color' => 'purple',
            'icon' => 'playlist-check'
        ];
    }
}

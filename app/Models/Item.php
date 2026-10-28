<?php

namespace App\Models;

use App\Models\Concerns\Syncable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Item extends Model
{
    use HasFactory, Syncable;

    protected $fillable = [
        'uuid', 'shopping_list_id', 'name', 'quantity', 'status_id',
        'name_changed_at', 'quantity_changed_at', 'status_changed_at',
    ];

    /** Synced field => column holding when it last changed. */
    protected array $syncedFields = [
        'name' => 'name_changed_at',
        'quantity' => 'quantity_changed_at',
        'status_id' => 'status_changed_at',
    ];

    protected function casts(): array
    {
        return [
            'name_changed_at' => 'datetime',
            'quantity_changed_at' => 'datetime',
            'status_changed_at' => 'datetime',
        ];
    }

    /**
     * Items of lists the user may see (see ShoppingList::scopeVisibleTo).
     */
    public function scopeVisibleTo(Builder $query, User $user): Builder
    {
        return $query->whereHas('shoppingList', fn (Builder $list) => $list->visibleTo($user));
    }

    /**
     * Each item belongs to a shopping list.
     */
    public function shoppingList()
    {
        return $this->belongsTo(ShoppingList::class, 'shopping_list_id');
    }

    /**
     * Each item has a status (e.g., pending, purchased).
     */
    public function status()
    {
        return $this->belongsTo(Status::class);
    }
}

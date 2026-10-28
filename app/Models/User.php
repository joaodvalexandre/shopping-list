<?php

namespace App\Models;

use App\Enums\FamilyRole;
use App\Enums\ListAbility;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Collection;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    protected $fillable = [
        'family_id',
        'name',
        'email',
        'password',
        'role',
        'must_change_password',
        'locale',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'last_login_at' => 'datetime',
            'password' => 'hashed',
            'role' => FamilyRole::class,
            'must_change_password' => 'boolean',
        ];
    }

    protected static function booted(): void
    {
        // Device tokens are not covered by database foreign keys
        static::deleting(fn (User $user) => $user->tokens()->delete());
    }

    /** Per-request cache of permission rows, keyed by list type id. */
    private ?Collection $permissionCache = null;

    public function family(): BelongsTo
    {
        return $this->belongsTo(Family::class);
    }

    public function listTypes(): BelongsToMany
    {
        return $this->belongsToMany(ListType::class, 'list_type_user')
            ->withPivot(['can_view', 'can_add_items', 'can_edit_items', 'can_change_status', 'can_manage_lists'])
            ->withTimestamps();
    }

    public function hiddenLists(): BelongsToMany
    {
        return $this->belongsToMany(ShoppingList::class, 'shopping_list_hidden_from');
    }

    public function isFamilyAdmin(): bool
    {
        return $this->role === FamilyRole::Admin;
    }

    /** True if this user is the only admin their family has. */
    public function isLastFamilyAdmin(): bool
    {
        return $this->isFamilyAdmin()
            && ! static::where('family_id', $this->family_id)
                ->where('role', FamilyRole::Admin->value)
                ->where('id', '!=', $this->id)
                ->exists();
    }

    /**
     * May this user perform $ability on lists of $type?
     * Admins can do everything inside their own family.
     */
    public function canOnListType(ListAbility $ability, ListType|int $type): bool
    {
        $typeId = $type instanceof ListType ? $type->id : $type;

        if ($type instanceof ListType && (int) $type->family_id !== (int) $this->family_id) {
            return false;
        }

        if ($this->isFamilyAdmin()) {
            return $type instanceof ListType
                ? true
                : ListType::whereKey($typeId)->where('family_id', $this->family_id)->exists();
        }

        $row = $this->permissionRows()->get($typeId);

        return $row !== null && (bool) $row->{$ability->value};
    }

    /**
     * Ids of the list types in which this user holds $ability.
     * Admins get every type of their family.
     *
     * @return Collection<int, int>
     */
    public function listTypeIdsWith(ListAbility $ability): Collection
    {
        if ($this->isFamilyAdmin()) {
            return ListType::where('family_id', $this->family_id)->pluck('id');
        }

        return $this->permissionRows()
            ->filter(fn ($row) => (bool) $row->{$ability->value})
            ->keys()
            ->values();
    }

    /**
     * Replace this user's permissions for the family's list types.
     *
     * @param  array<int, array<string, mixed>>  $matrix  list_type_id => [ability column => bool]
     */
    public function syncListPermissions(array $matrix): void
    {
        $familyTypeIds = ListType::where('family_id', $this->family_id)->pluck('id')->all();
        $payload = [];

        foreach ($matrix as $typeId => $abilities) {
            // Never accept a type from another family
            if (! in_array((int) $typeId, $familyTypeIds, true)) {
                continue;
            }

            $normalised = ListAbility::normalise((array) $abilities);
            if (in_array(true, $normalised, true)) {
                $payload[(int) $typeId] = $normalised;
            }
        }

        $this->listTypes()->sync($payload);
        $this->permissionCache = null;
    }

    private function permissionRows(): Collection
    {
        return $this->permissionCache ??= $this->listTypes()->get()
            ->mapWithKeys(fn (ListType $type) => [$type->id => $type->pivot]);
    }

    public function forgetPermissionCache(): void
    {
        $this->permissionCache = null;
    }
}

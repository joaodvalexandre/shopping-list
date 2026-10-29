<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Family extends Model
{
    use HasFactory;

    protected $fillable = ['name'];

    protected static function booted(): void
    {
        // Deleting a family removes its members in the database (cascade), which
        // skips model events - so sign their devices out here first.
        // A list type cannot go while a list (even a deleted one, kept as a tombstone) still
        // points at it, and the database may cascade the types before the lists: so the lists
        // (and their items) go first.
        static::deleting(function (Family $family) {
            $family->users->each(fn (User $user) => $user->tokens()->delete());
            $family->shoppingLists()->withTrashed()->forceDelete();
        });
    }

    public function users(): HasMany
    {
        return $this->hasMany(User::class);
    }

    public function listTypes(): HasMany
    {
        return $this->hasMany(ListType::class);
    }

    public function shoppingLists(): HasMany
    {
        return $this->hasMany(ShoppingList::class);
    }
}

<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;

class ListType extends Model
{
    use HasFactory;

    protected $fillable = ['family_id', 'name'];

    public function family(): BelongsTo
    {
        return $this->belongsTo(Family::class);
    }

    public function shoppingLists(): HasMany
    {
        return $this->hasMany(ShoppingList::class);
    }

    public function members(): BelongsToMany
    {
        return $this->belongsToMany(User::class, 'list_type_user')
            ->withPivot(['can_view', 'can_add_items', 'can_edit_items', 'can_change_status', 'can_manage_lists'])
            ->withTimestamps();
    }
}

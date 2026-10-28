<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Item extends Model
{
    use HasFactory;

    protected $fillable = ['shopping_list_id', 'name', 'quantity', 'status_id'];

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

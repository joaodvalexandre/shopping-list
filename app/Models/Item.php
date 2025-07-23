<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Item extends Model
{
    protected $fillable = ['shopping_list_id', 'name', 'quantity', 'status_id'];

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

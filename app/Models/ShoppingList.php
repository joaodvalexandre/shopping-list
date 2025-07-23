<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ShoppingList extends Model
{
    protected $table = 'list'; // because your table name is "list"

    protected $fillable = ['shopping_list_id', 'item_name', 'quantity', 'status_id'];

    /**
     * Each item belongs to a shopping list.
     */
    public function shoppingList()
    {
        return $this->belongsTo(ShoppingLists::class, 'shopping_list_id');
    }

    /**
     * Each item has a status (e.g., pending, purchased).
     */
    public function status()
    {
        return $this->belongsTo(Status::class);
    }
}

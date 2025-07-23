<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ShoppingLists extends Model
{
    protected $table = 'shopping_lists'; // explicitly declare for clarity

    protected $fillable = ['name', 'status_id'];

    /**
     * A shopping list has many items.
     */
    public function items()
    {
        return $this->hasMany(ShoppingList::class, 'shopping_list_id');
    }

    /**
     * A shopping list belongs to a status.
     */
    public function status()
    {
        return $this->belongsTo(Status::class);
    }
}

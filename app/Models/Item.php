<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Item extends Model
{
    protected $fillable = ['name', 'description'];

    // Relation: one Item can belong to many ShoppingLists
    public function shoppingLists()
    {
        return $this->hasMany(ShoppingList::class);
    }
}

<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ShoppingList extends Model
{
    protected $fillable = ['item_id', 'quantity', 'status_id'];

    // Relation to Item
    public function item()
    {
        return $this->belongsTo(Item::class);
    }

    // Relation to Status
    public function status()
    {
        return $this->belongsTo(Status::class);
    }
}

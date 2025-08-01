<?php

namespace App\Observers;

use App\Models\ShoppingList;
use App\Events\ModelChanged;

class ShoppingListObserver
{
    public function created(ShoppingList $list)
    {
        broadcast(new ModelChanged('shopping_list', 'created', $list->toArray()));
    }

    public function updated(ShoppingList $list)
    {
        broadcast(new ModelChanged('shopping_list', 'updated', $list->toArray()));
    }

    public function deleted(ShoppingList $list)
    {
        broadcast(new ModelChanged('shopping_list', 'deleted', ['id' => $list->id]));
    }
}

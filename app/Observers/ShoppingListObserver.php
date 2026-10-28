<?php

namespace App\Observers;

use App\Events\ModelChanged;
use App\Models\ShoppingList;

class ShoppingListObserver
{
    public function created(ShoppingList $list): void
    {
        $this->announce($list, 'created');
    }

    public function updated(ShoppingList $list): void
    {
        $this->announce($list, 'updated');
    }

    public function deleted(ShoppingList $list): void
    {
        $this->announce($list, 'deleted');
    }

    private function announce(ShoppingList $list, string $action): void
    {
        broadcast(new ModelChanged('shopping_list', $action, $list->id, $list->family_id));
    }
}

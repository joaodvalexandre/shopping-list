<?php

namespace App\Observers;

use App\Models\Item;
use App\Events\ModelChanged;

class ItemObserver
{
    public function created(Item $item)
    {
        broadcast(new ModelChanged('item', 'created', $item->toArray()));
    }

    public function updated(Item $item)
    {
        broadcast(new ModelChanged('item', 'updated', $item->toArray()));
    }

    public function deleted(Item $item)
    {
        broadcast(new ModelChanged('item', 'deleted', ['id' => $item->id]));
    }
}

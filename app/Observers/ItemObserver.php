<?php

namespace App\Observers;

use App\Events\ModelChanged;
use App\Models\Item;
use App\Support\Activity\ActivityRecorder;

class ItemObserver
{
    public function created(Item $item): void
    {
        $this->announce($item, 'created');
        ActivityRecorder::itemAdded($item);
    }

    public function updated(Item $item): void
    {
        $this->announce($item, 'updated');
        ActivityRecorder::itemChanged($item);
    }

    public function deleted(Item $item): void
    {
        $this->announce($item, 'deleted');
    }

    private function announce(Item $item, string $action): void
    {
        // The list may be soft-deleted already, hence withTrashed()
        $familyId = $item->shoppingList()->withTrashed()->value('family_id');

        if ($familyId !== null) {
            broadcast(new ModelChanged('item', $action, $item->id, (int) $familyId));
        }
    }
}

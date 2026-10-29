<?php

namespace App\Support\Activity;

use App\Models\Activity;
use App\Models\Item;
use App\Models\ShoppingList;
use Illuminate\Database\QueryException;

/**
 * Writes the family activity feed from what happens to lists and items, whichever way
 * it happens (the web pages or the phone sync). The actor is whoever is signed in on
 * the request; changes made by the system itself have none.
 */
class ActivityRecorder
{
    /** Item status ids (see StatusSeeder). */
    private const STATUS_KINDS = [2 => Activity::ITEM_IN_CART, 3 => Activity::ITEM_PURCHASED];

    /** How long the feed is kept: a phone that was off for longer simply misses the oldest. */
    public const KEEP_DAYS = 14;

    public static function itemAdded(Item $item): void
    {
        self::record($item->shoppingList()->withTrashed()->first(), Activity::ITEM_ADDED, $item);
    }

    /** Only a change of status is news; renaming an item or changing its quantity is not. */
    public static function itemChanged(Item $item): void
    {
        $kind = self::STATUS_KINDS[(int) $item->status_id] ?? null;

        if ($kind !== null && $item->wasChanged('status_id')) {
            self::record($item->shoppingList()->withTrashed()->first(), $kind, $item);
        }
    }

    public static function listCreated(ShoppingList $list): void
    {
        self::record($list, Activity::LIST_CREATED);
    }

    private static function record(?ShoppingList $list, string $kind, ?Item $item = null): void
    {
        if ($list === null) {
            return;
        }

        try {
            Activity::create([
                'family_id' => $list->family_id,
                'shopping_list_id' => $list->id,
                'actor_id' => request()->user()?->id,
                'kind' => $kind,
                'subject' => $item?->name,
                'quantity' => $item?->quantity,
            ]);

            // Old news is dropped now and then, which saves a scheduler
            if (random_int(1, 100) === 1) {
                Activity::where('created_at', '<', now()->subDays(self::KEEP_DAYS))->delete();
            }
        } catch (QueryException) {
            // the feed is a courtesy: it must never stop a list or an item from being saved
        }
    }
}

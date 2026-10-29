<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Item;
use App\Models\ShoppingList;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * A very cheap question the phone asks every few seconds while it is open: "has anything
 * changed that I may see?". The answer is only a marker; when it differs from the one the phone
 * holds, the phone runs its ordinary sync. Nothing else is revealed (not what, nor where, nor by whom),
 * and changes to lists hidden from this person, or of types they may not see, do not move it.
 */
class WatchController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        $user = $request->user();

        $lists = ShoppingList::withTrashed()->visibleTo($user);
        $listIds = (clone $lists)->select('shopping_lists.id');

        $items = Item::withTrashed()->whereIn('shopping_list_id', $listIds);

        $state = [
            // lists and items: edits, deletions (soft deletes touch updated_at) and what is visible at all
            'lists' => [(clone $lists)->count(), (clone $lists)->max('shopping_lists.updated_at')],
            'items' => [(clone $items)->count(), (clone $items)->max('items.updated_at')],
            // what this person may do, and who they are
            'rights' => [
                $user->updated_at?->getTimestamp(),
                $user->listTypes()->count(),
                $user->listTypes()->max('list_type_user.updated_at'),
            ],
            'types' => [$user->family->listTypes()->count(), $user->family->listTypes()->max('updated_at')],
        ];

        return response()->json([
            'version' => substr(hash_hmac('sha256', json_encode($state), (string) config('app.key')), 0, 16),
        ]);
    }
}

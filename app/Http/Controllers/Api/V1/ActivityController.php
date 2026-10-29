<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Activity;
use App\Models\ShoppingList;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * What others did on the family lists, for the phone to turn into notifications. Only
 * the lists this person may see (their type, not hidden from them), and never their own doing.
 *
 * The phone keeps the id it has got up to. With no `after` it is told only where the feed
 * stands now (`last_id`), so a freshly installed app does not announce the past.
 */
class ActivityController extends Controller
{
    private const LIMIT = 100;

    public function index(Request $request): JsonResponse
    {
        $user = $request->user();

        $lastId = (int) Activity::where('family_id', $user->family_id)->max('id');

        if (! $request->filled('after')) {
            return response()->json(['data' => [], 'last_id' => $lastId]);
        }

        $after = max(0, (int) $request->query('after'));

        $rows = Activity::where('family_id', $user->family_id)
            ->where('id', '>', $after)
            ->whereIn('shopping_list_id', ShoppingList::visibleTo($user)->select('shopping_lists.id'))
            ->where(fn ($query) => $query->whereNull('actor_id')->orWhere('actor_id', '!=', $user->id))
            ->with(['actor:id,name', 'shoppingList:id,uuid,name'])
            ->orderBy('id')
            ->limit(self::LIMIT)
            ->get();

        return response()->json([
            'data' => $rows->map(fn (Activity $activity) => [
                'id' => $activity->id,
                'kind' => $activity->kind,
                'actor' => $activity->actor?->name,
                'list_uuid' => $activity->shoppingList->uuid,
                'list' => $activity->shoppingList->name,
                'item' => $activity->subject,
                'quantity' => $activity->quantity,
                'at' => $activity->created_at->toIso8601String(),
            ])->all(),
            // A full page: more is waiting, so the cursor stops at what was sent
            'last_id' => $rows->count() === self::LIMIT ? $rows->last()->id : $lastId,
        ]);
    }
}

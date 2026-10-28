<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Services\Sync\SyncService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SyncController extends Controller
{
    private const STATUSES = 'in:to_buy,in_cart,purchased';

    /**
     * Push the device's offline changes and pull everything new, in one call.
     * See App\Services\Sync\SyncService for the rules.
     */
    public function __invoke(Request $request, SyncService $sync): JsonResponse
    {
        $payload = $request->validate([
            'since' => 'nullable|date',
            'known_lists' => 'nullable|array|max:1000',
            'known_lists.*' => 'uuid',

            'changes' => 'nullable|array',
            'changes.lists' => 'nullable|array|max:500',
            'changes.lists.*.uuid' => 'required|uuid',
            'changes.lists.*.name' => 'sometimes|string|max:255',
            'changes.lists.*.name_changed_at' => 'nullable|date',
            'changes.lists.*.list_type_id' => 'nullable|integer',
            'changes.lists.*.deleted_at' => 'nullable|date',
            'changes.lists.*.hidden_from' => 'sometimes|array|max:100',
            'changes.lists.*.hidden_from.*' => 'integer',

            'changes.items' => 'nullable|array|max:2000',
            'changes.items.*.uuid' => 'required|uuid',
            'changes.items.*.list_uuid' => 'required|uuid',
            'changes.items.*.name' => 'sometimes|string|max:255',
            'changes.items.*.name_changed_at' => 'nullable|date',
            'changes.items.*.quantity' => 'sometimes|integer|min:1|max:9999',
            'changes.items.*.quantity_changed_at' => 'nullable|date',
            'changes.items.*.status' => 'sometimes|string|' . self::STATUSES,
            'changes.items.*.status_changed_at' => 'nullable|date',
            'changes.items.*.deleted_at' => 'nullable|date',
        ]);

        return response()->json($sync->sync($request->user(), $payload));
    }
}

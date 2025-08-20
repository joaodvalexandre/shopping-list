<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ShoppingList;
use App\Models\Item;
use App\Models\Status;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\DB;

class ShoppingListController extends Controller
{
    /**
     * Health check endpoint
     */
    public function health(): JsonResponse
    {
        return response()->json(['status' => 'ok', 'timestamp' => now()]);
    }

    /**
     * Get all shopping lists
     */
    public function index(): JsonResponse
    {
        try {
            $shoppingLists = ShoppingList::with(['items.status'])
                ->orderBy('created_at', 'desc')
                ->get()
                ->map(function ($list) {
                    return [
                        'id' => $list->id,
                        'name' => $list->name,
                        'created_at' => $list->created_at,
                        'updated_at' => $list->updated_at,
                        'items' => $list->items->map(function ($item) {
                            return [
                                'id' => $item->id,
                                'name' => $item->name,
                                'quantity' => $item->quantity,
                                'status' => $item->status->code,
                                'created_at' => $item->created_at,
                                'updated_at' => $item->updated_at,
                            ];
                        }),
                    ];
                });

            return response()->json($shoppingLists);
        } catch (\Exception $e) {
            return response()->json([
                'error' => 'Failed to fetch shopping lists',
                'message' => $e->getMessage()
            ], 500);
        }
    }

    /**
     * Create a new shopping list
     */
    public function store(Request $request): JsonResponse
    {
        try {
            $validator = Validator::make($request->all(), [
                'name' => 'required|string|max:255',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => 'Validation failed',
                    'errors' => $validator->errors()
                ], 422);
            }

            DB::beginTransaction();

            $shoppingList = ShoppingList::create([
                'name' => $request->name,
            ]);

            // Create default status if it doesn't exist
            $defaultStatus = Status::firstOrCreate(
                ['code' => 'to_buy'],
                ['name' => 'To Buy', 'color' => 'yellow']
            );

            DB::commit();

            return response()->json([
                'id' => $shoppingList->id,
                'name' => $shoppingList->name,
                'created_at' => $shoppingList->created_at,
                'updated_at' => $shoppingList->updated_at,
                'items' => [],
            ], 201);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json([
                'error' => 'Failed to create shopping list',
                'message' => $e->getMessage()
            ], 500);
        }
    }

    /**
     * Update a shopping list
     */
    public function update(Request $request, $id): JsonResponse
    {
        try {
            $shoppingList = ShoppingList::findOrFail($id);

            $validator = Validator::make($request->all(), [
                'name' => 'sometimes|string|max:255',
                'items' => 'sometimes|array',
                'items.*.name' => 'required_with:items|string|max:255',
                'items.*.quantity' => 'required_with:items|string|max:50',
                'items.*.status' => 'required_with:items|string|in:to_buy,in_cart,purchased',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => 'Validation failed',
                    'errors' => $validator->errors()
                ], 422);
            }

            DB::beginTransaction();

            if ($request->has('name')) {
                $shoppingList->update(['name' => $request->name]);
            }

            if ($request->has('items')) {
                // Clear existing items
                $shoppingList->items()->delete();

                // Create new items
                foreach ($request->items as $itemData) {
                    $status = Status::firstOrCreate(
                        ['code' => $itemData['status']],
                        [
                            'name' => ucfirst(str_replace('_', ' ', $itemData['status'])),
                            'color' => $this->getStatusColor($itemData['status'])
                        ]
                    );

                    Item::create([
                        'shopping_list_id' => $shoppingList->id,
                        'name' => $itemData['name'],
                        'quantity' => $itemData['quantity'],
                        'status_id' => $status->id,
                    ]);
                }
            }

            $shoppingList->refresh();
            $shoppingList->load(['items.status']);

            DB::commit();

            return response()->json([
                'id' => $shoppingList->id,
                'name' => $shoppingList->name,
                'created_at' => $shoppingList->created_at,
                'updated_at' => $shoppingList->updated_at,
                'items' => $shoppingList->items->map(function ($item) {
                    return [
                        'id' => $item->id,
                        'name' => $item->name,
                        'quantity' => $item->quantity,
                        'status' => $item->status->code,
                        'created_at' => $item->created_at,
                        'updated_at' => $item->updated_at,
                    ];
                }),
            ]);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json([
                'error' => 'Failed to update shopping list',
                'message' => $e->getMessage()
            ], 500);
        }
    }

    /**
     * Delete a shopping list
     */
    public function destroy($id): JsonResponse
    {
        try {
            $shoppingList = ShoppingList::findOrFail($id);

            // Delete associated items first
            $shoppingList->items()->delete();
            $shoppingList->delete();

            return response()->json(null, 204);

        } catch (\Exception $e) {
            return response()->json([
                'error' => 'Failed to delete shopping list',
                'message' => $e->getMessage()
            ], 500);
        }
    }

    /**
     * Sync shopping lists with mobile app
     */
    public function sync(Request $request): JsonResponse
    {
        try {
            $validator = Validator::make($request->all(), [
                'lists' => 'required|array',
                'lists.*.name' => 'required|string|max:255',
                'lists.*.items' => 'sometimes|array',
                'lists.*.items.*.name' => 'required_with:lists.*.items|string|max:255',
                'lists.*.items.*.quantity' => 'required_with:lists.*.items|string|max:50',
                'lists.*.items.*.status' => 'required_with:lists.*.items|string|in:to_buy,in_cart,purchased',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => 'Validation failed',
                    'errors' => $validator->errors()
                ], 422);
            }

            DB::beginTransaction();

            $syncedLists = [];
            $conflicts = [];

            foreach ($request->lists as $listData) {
                // Create or update shopping list
                $shoppingList = ShoppingList::create([
                    'name' => $listData['name'],
                ]);

                // Create items if provided
                if (isset($listData['items'])) {
                    foreach ($listData['items'] as $itemData) {
                        $status = Status::firstOrCreate(
                            ['code' => $itemData['status']],
                            [
                                'name' => ucfirst(str_replace('_', ' ', $itemData['status'])),
                                'color' => $this->getStatusColor($itemData['status'])
                            ]
                        );

                        Item::create([
                            'shopping_list_id' => $shoppingList->id,
                            'name' => $itemData['name'],
                            'quantity' => $itemData['quantity'],
                            'status_id' => $status->id,
                        ]);
                    }
                }

                $shoppingList->refresh();
                $shoppingList->load(['items.status']);

                $syncedLists[] = [
                    'id' => $shoppingList->id,
                    'name' => $shoppingList->name,
                    'created_at' => $shoppingList->created_at,
                    'updated_at' => $shoppingList->updated_at,
                    'items' => $shoppingList->items->map(function ($item) {
                        return [
                            'id' => $item->id,
                            'name' => $item->name,
                            'quantity' => $item->quantity,
                            'status' => $item->status->code,
                            'created_at' => $item->created_at,
                            'updated_at' => $item->updated_at,
                        ];
                    }),
                ];
            }

            DB::commit();

            return response()->json([
                'success' => true,
                'synced_lists' => $syncedLists,
                'conflicts' => $conflicts,
            ]);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json([
                'error' => 'Failed to sync shopping lists',
                'message' => $e->getMessage()
            ], 500);
        }
    }

    /**
     * Get status color based on status code
     */
    private function getStatusColor(string $statusCode): string
    {
        return match ($statusCode) {
            'to_buy' => 'yellow',
            'in_cart' => 'blue',
            'purchased' => 'green',
            default => 'gray',
        };
    }
}

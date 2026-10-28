<?php

namespace App\Http\Controllers;

use App\Enums\ListAbility;
use App\Models\Item;
use App\Models\ListType;
use App\Models\ShoppingList;
use App\Models\User;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\Rule;

class ShoppingListController extends Controller
{
    private const STATUS_TO_BUY = 1;
    private const STATUS_IN_CART = 2;
    private const STATUS_PURCHASED = 3;

    public function index()
    {
        $shoppingList = $this->listsWithStats(auth()->user());

        return view('shopping_list.index', [
            'shoppingList' => $shoppingList,
            'canCreate' => $this->manageableTypes(auth()->user())->isNotEmpty(),
        ]);
    }

    public function show(ShoppingList $shoppingList)
    {
        $user = auth()->user();
        $items = Item::with('status')->where('shopping_list_id', $shoppingList->id)->orderBy('status_id')->get();

        $itemsQueue = $items->where('status_id', self::STATUS_TO_BUY)->count();
        $itemsInCart = $items->where('status_id', self::STATUS_IN_CART)->count();

        // Disables finish list button
        $allInCart = $itemsQueue + $itemsInCart > 0 && $itemsQueue === 0;

        // Checks if the list has any item
        $listHasItems = $items->count() > 0;

        $can = [
            'add_items' => $user->can('addItems', $shoppingList),
            'edit_items' => $user->can('editItems', $shoppingList),
            'change_status' => $user->can('changeStatus', $shoppingList),
        ];

        return view('shopping_list.show', compact('items', 'shoppingList', 'allInCart', 'listHasItems', 'can'));
    }

    // List
    public function create()
    {
        $user = auth()->user();
        $types = $this->manageableTypes($user);
        abort_if($types->isEmpty(), 403);

        return view('shopping_list.create', [
            'types' => $types,
            'members' => $this->otherMembers($user),
            'hidden' => [],
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $user = $request->user();
        $types = $this->manageableTypes($user);

        $data = $request->validate([
            'name' => 'required|string|max:255',
            'list_type_id' => ['required', Rule::in($types->pluck('id'))],
            'hidden_from' => 'nullable|array',
            'hidden_from.*' => 'integer',
        ]);

        $type = $types->firstWhere('id', (int) $data['list_type_id']);
        Gate::authorize('create', [ShoppingList::class, $type]);

        $list = ShoppingList::create([
            'name' => $data['name'],
            'list_type_id' => $type->id,
            'family_id' => $user->family_id,
            'created_by' => $user->id,
        ]);
        $this->syncHidden($list, $user, $data['hidden_from'] ?? []);

        $this->notificationToggle('list_created_success', 'success');

        return redirect()->route('shopping_list.index');
    }

    public function edit(ShoppingList $shoppingList)
    {
        Gate::authorize('update', $shoppingList);
        $user = auth()->user();

        return view('shopping_list.edit', [
            'shoppingList' => $shoppingList,
            'types' => $this->manageableTypes($user),
            'members' => $this->otherMembers($user),
            'hidden' => $shoppingList->hiddenFrom()->pluck('users.id')->all(),
        ]);
    }

    public function update(Request $request, ShoppingList $shoppingList): RedirectResponse
    {
        Gate::authorize('update', $shoppingList);
        $user = $request->user();
        $types = $this->manageableTypes($user);

        $data = $request->validate([
            'name' => 'required|string|max:255',
            'list_type_id' => ['required', Rule::in($types->pluck('id'))],
            'hidden_from' => 'nullable|array',
            'hidden_from.*' => 'integer',
        ]);

        $shoppingList->update(['name' => $data['name'], 'list_type_id' => (int) $data['list_type_id']]);
        $this->syncHidden($shoppingList, $user, $data['hidden_from'] ?? []);

        $this->notificationToggle('list_updated_success', 'success');

        return redirect()->route('shopping_list.index');
    }

    public function destroy(ShoppingList $shoppingList): RedirectResponse
    {
        Gate::authorize('delete', $shoppingList);

        $shoppingList->delete();
        $this->notificationToggle('list_destroyed_success', 'success');

        return redirect()->route('shopping_list.index');
    }

    // Item
    public function create_item(Request $request)
    {
        $list = $this->visibleList($request->route('list_id'));
        Gate::authorize('addItems', $list);

        return view('shopping_list.create_item', ['list_id' => $list->id]);
    }

    public function store_item(Request $request): RedirectResponse
    {
        $list = $this->visibleList($request->route('list_id'));
        Gate::authorize('addItems', $list);

        $data = $request->validate([
            'name' => 'required|string|max:255',
            'quantity' => 'required|integer|min:1',
        ]);

        $list->items()->create($data + ['status_id' => self::STATUS_TO_BUY]);
        $this->notificationToggle('item_created_success', 'success');

        return redirect()->route('shopping_list.show', $list);
    }

    public function edit_item(Request $request)
    {
        $item = $this->visibleItem($request->route('item_id'));
        Gate::authorize('editItems', $item->shoppingList);

        return view('shopping_list.edit_item', ['item' => $item, 'list_id' => $item->shopping_list_id]);
    }

    public function update_item(Request $request): RedirectResponse
    {
        $item = $this->visibleItem($request->route('item_id'));
        Gate::authorize('editItems', $item->shoppingList);

        $data = $request->validate([
            'name' => 'required|string|max:255',
            'quantity' => 'required|integer|min:1',
        ]);

        $item->update($data);
        $this->notificationToggle('list_updated_success', 'success');

        return redirect()->route('shopping_list.show', $item->shopping_list_id);
    }

    public function destroy_item(Request $request): RedirectResponse
    {
        $item = $this->visibleItem($request->route('item_id'));
        Gate::authorize('editItems', $item->shoppingList);

        $item->delete();
        $this->notificationToggle('item_destroyed_success', 'success');

        return redirect()->route('shopping_list.show', $item->shopping_list_id);
    }

    public function export(Request $request, $list_id)
    {
        $shoppingList = $this->visibleList($list_id)->load('items');
        Gate::authorize('view', $shoppingList);

        $filename = str($shoppingList->name)->slug() . '.md';

        $content = "";

        foreach ($shoppingList->items as $item) {
            $content .= "- [ ] {$item->name}\n";
        }

        return response($content)
            ->header('Content-Type', 'text/markdown')
            ->header("Content-Disposition", "attachment; filename={$filename}");
    }

    // Status Update
    public function add_cart($item_id): RedirectResponse
    {
        return $this->changeStatus($item_id, self::STATUS_IN_CART, 'item_moved_to_cart');
    }

    public function remove_cart($item_id): RedirectResponse
    {
        return $this->changeStatus($item_id, self::STATUS_TO_BUY, 'item_removed_from_cart');
    }

    public function mark_purchased($list_id): RedirectResponse
    {
        $list = $this->visibleList($list_id);
        Gate::authorize('changeStatus', $list);

        $list->items()->where('status_id', self::STATUS_IN_CART)->get()
            ->each(fn (Item $item) => $item->update(['status_id' => self::STATUS_PURCHASED]));

        $this->notificationToggle('items_marked_success', 'success');

        return redirect()->route('shopping_list.show', $list);
    }

    // Reusable method to change status of the Items
    private function changeStatus($item_id, int $status, string $message): RedirectResponse
    {
        $item = $this->visibleItem($item_id);
        Gate::authorize('changeStatus', $item->shoppingList);

        $item->update(['status_id' => $status]);
        $this->notificationToggle($message . '_success', 'success');

        return redirect()->route('shopping_list.show', $item->shopping_list_id);
    }

    /**
     * Lists the user may see, with the counters the list views display.
     */
    public static function listsWithStats(User $user)
    {
        $lists = ShoppingList::visibleTo($user)->with(['items.status', 'listType'])->orderBy('name')->get();

        $lists->each(function ($list) {
            $list->status = $list->calculateStatus();
            $list->pending = $list->getPendingItems();
            $list->in_cart = $list->getInCartItems();
            $list->purchased = $list->getPurchasedItems();
            $list->total = $list->getTotalItems();
        });

        return $lists;
    }

    /** A list the user may see, or 404 (never reveals that it exists). */
    private function visibleList($id): ShoppingList
    {
        return ShoppingList::visibleTo(auth()->user())->findOrFail($id);
    }

    private function visibleItem($id): Item
    {
        return Item::visibleTo(auth()->user())->with('shoppingList')->findOrFail($id);
    }

    /** List types in which the user may create/manage lists. */
    private function manageableTypes(User $user)
    {
        return ListType::whereIn('id', $user->listTypeIdsWith(ListAbility::ManageLists))->orderBy('name')->get();
    }

    private function otherMembers(User $user)
    {
        return User::where('family_id', $user->family_id)->where('id', '!=', $user->id)->orderBy('name')->get();
    }

    /**
     * Hide the list from the given members. Only members of the same family
     * are accepted and nobody can hide a list from themselves.
     */
    private function syncHidden(ShoppingList $list, User $actor, array $ids): void
    {
        $valid = User::where('family_id', $actor->family_id)
            ->where('id', '!=', $actor->id)
            ->whereIn('id', $ids)
            ->pluck('id');

        $list->hiddenFrom()->sync($valid);
    }
}

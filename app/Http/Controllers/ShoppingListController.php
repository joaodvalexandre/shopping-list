<?php

namespace App\Http\Controllers;

use App\Models\Item;
use App\Models\ShoppingList;
use App\Models\Status;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Response;
use Jenssegers\Agent\Agent;

class ShoppingListController extends Controller
{
    public function index()
    {
        // Eager load items and their statuses
        $shoppingList = ShoppingList::with('items.status')->get();

        // Add dynamic status attribute to each list
        $shoppingList->each(function ($list) {
            $list->status = $list->calculateStatus();
            $list->pending = $list->getPendingItems();
            $list->in_cart = $list->getInCartItems();
            $list->purchased = $list->getPurchasedItems();
            $list->total = $list->getTotalItems();
        });

        return view('shopping_list.index', compact('shoppingList'));
    }

    public function show(ShoppingList $shoppingList)
    {
        $items = Item::with('status')->where('shopping_list_id', $shoppingList->id)->orderBy('status_id')->get();
        $itemsQueue = Item::with('status')->where('shopping_list_id', $shoppingList->id)->where('status_id', 1)->count();
        $itemsInCart = Item::with('status')->where('shopping_list_id', $shoppingList->id)->where('status_id', 2)->count();
        $itemsPurchased = Item::with('status')->where('shopping_list_id', $shoppingList->id)->where('status_id', 3)->count();

        // Disables finish list button
        if($itemsQueue != 0 || $itemsInCart != 0)
            $allInCart = ($itemsQueue+$itemsInCart == $itemsInCart);
        else
            $allInCart = false;

        // Checks if the list has any item
        $listHasItems = $items->count() > 0;

        return view ('shopping_list.show', compact('items', 'shoppingList', 'allInCart', 'listHasItems'));
    }

    // List
    public function create()
    {
        return view('shopping_list.create');
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'name' => 'required',
        ]);

        if(ShoppingList::create($data))
            $this->notificationToggle('list_created_success', 'success');
        else
            $this->notificationToggle('list_created_error', 'error');

        return redirect()->route('shopping_list.index');
    }

    public function edit(ShoppingList $shoppingList)
    {
        return view('shopping_list.edit', compact('shoppingList'));
    }

    public function update(Request $request, ShoppingList $shoppingList)
    {
        $validatedData = $request->validate([
            'name' => 'required',
        ]);

        if($shoppingList->update($validatedData))
            $this->notificationToggle('list_updated_success', 'success');
        else
            $this->notificationToggle('list_updated_error', 'error');

        return redirect()->route('shopping_list.index');
    }

    public function destroy(ShoppingList $shoppingList)
    {
        if($shoppingList->delete())
            $this->notificationToggle('list_destroyed_success', 'success');
        else
            $this->notificationToggle('list_destroyed_error', 'error');

        return redirect()->route('shopping_list.index');
    }

    // Item
    public function create_item(Request $request)
    {
        $list_id = $request->route('list_id');
        return view('shopping_list.create_item', compact('list_id'));
    }

    public function store_item(Request $request)
    {
        $data = $request->validate([
            'name' => 'required',
            'quantity' => 'required'
        ]);

        // Set item status to to_buy (1)
        $data['status_id'] = 1;
        $data['shopping_list_id'] = $request->route('list_id');

        if(Item::create($data))
            $this->notificationToggle('item_created_success', 'success');
        else
            $this->notificationToggle('item_created_error', 'error');

        return redirect()->route('shopping_list.show', $request->route('list_id'));
    }

    public function edit_item(Request $request)
    {
        $item = Item::findOrFail($request->route('item_id'));
        $list_id = $item->shopping_list_id;
        return view('shopping_list.edit_item', compact('item', 'list_id'));
    }

    public function update_item(Request $request)
    {
        $item = Item::findOrFail($request->get('id'));
        $data = $request->validate([
            'name' => 'required',
            'quantity' => 'required'
        ]);

        if($item->update($data))
            $this->notificationToggle('list_updated_success', 'success');
        else
            $this->notificationToggle('list_updated_error', 'error');

        return redirect()->route('shopping_list.show', $item->shopping_list_id);
    }

    public function destroy_item(Request $request)
    {
        $item = Item::findOrFail($request->route('item_id'));
        $list_id = $item->shopping_list_id;

        if($item->delete())
            $this->notificationToggle('item_destroyed_success', 'success');
        else
            $this->notificationToggle('item_destroyed_error', 'error');

        return redirect()->route('shopping_list.show', $list_id);
    }

    public function export(Request $request){
        $agent = new Agent();
        $isMobile = $agent->isMobile();

        if ($isMobile)
            dd('Mobile FTW!!!');
        else
            dd('Desktop Filth!!!');


        // // Your list data
        // $items = ['Apples', 'Bananas', 'Milk'];
        // $content = "# 🛒 Shopping List\n\n";
        // foreach ($items as $item) {
        //     $content .= "- [ ] $item\n";
        // }

        // if ($isMobile) {
        //     return response($content)
        //         ->header('Content-Type', 'text/markdown')
        //         ->header('Content-Disposition', 'attachment; filename="shopping_list.md"');
        // }

        // // Fallback for desktop (e.g., show on screen)
        // return view('shopping_list.preview', compact('items'));
    }

    // Status Update
    public function add_cart($item_id)
    {
        $list_id = $this->changeStatus($item_id, 2, 'item_moved_to_cart');
        return redirect()->route('shopping_list.show', $list_id);
    }

    public function remove_cart($item_id)
    {
        $list_id = $this->changeStatus($item_id, 1, 'item_removed_from_cart');
        return redirect()->route('shopping_list.show', $list_id);
    }

    public function mark_purchased($list_id)
    {
        $items = Item::where('shopping_list_id', $list_id)->where('status_id', 2)->get();
        foreach($items as $item){
            $this->changeStatus($item->id, 3, '', true);
        }
        $this->notificationToggle('items_marked_success', 'success');
        return redirect()->route('shopping_list.show', $list_id);
    }

    // Reusable method to change status of the Items
    private function changeStatus($item_id, $status, $message, $purchased = false)
    {
        $item = Item::findOrFail($item_id);
        $list_id = $item->shopping_list_id;
        $data = ['status_id' => $status];

        if($purchased){
            if($item->update($data))
                return true;
        } else {
            if($item->update($data))
                $this->notificationToggle($message.'_success', 'success');
            else
                $this->notificationToggle($message.'_error', 'error');
        }

        return $list_id;
    }
}

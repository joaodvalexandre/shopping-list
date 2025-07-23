<?php

namespace App\Http\Controllers;

use App\Models\ShoppingList;
use App\Models\Status;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Response;

class ShoppingListController extends Controller
{
    public function index()
    {
        // Eager load items and their statuses
        $shoppingList = ShoppingList::with('items.status')->get();

        // Add dynamic status attribute to each list
        $shoppingList->each(function ($list) {
            $list->status = $list->calculateStatus();
            $list->pending_items = $list->getPendingItems();
            $list->in_cart_items = $list->getInCartItems();
            $list->purchased_items = $list->getPurchasedItems();
            $list->total_items = $list->getTotalItems();
        });

        return view('shopping_list.index', compact('shoppingList'));
    }

    public function show()
    {
        return view ('shopping_list.show');
    }

    public function create()
    {
        return view('shopping_list.create');
    }

    public function store(Request $request)
    {
        $validatedData = $request->validate([
            'name' => 'required',
        ]);

        ShoppingList::create($validatedData);

        $this->notificationToggle('list_created_success', 'success');
        return redirect()->route('shopping_list.index')->with('success', __('list_created_success'));
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

        $shoppingList->update($validatedData);

        $this->notificationToggle('list_updated_success', 'success');
        return redirect()->route('shopping_list.index')->with('success', __('list_updated_success'));
    }

    public function destroy(ShoppingList $shoppingList)
    {
        $shoppingList->delete();
        $this->notificationToggle('list_destroyed_success', 'success');
        return redirect()->route('shopping_list.index')->with('success', __('list_destroyed_success'));
    }
}

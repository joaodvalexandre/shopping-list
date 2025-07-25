<?php

namespace App\Http\Controllers;

use App\Models\Item;
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
            $list->pending = $list->getPendingItems();
            $list->in_cart = $list->getInCartItems();
            $list->purchased = $list->getPurchasedItems();
            $list->total = $list->getTotalItems();
        });

        return view('shopping_list.index', compact('shoppingList'));
    }

    public function show(ShoppingList $shoppingList)
    {
        $items = Item::with('status')
                    ->where('shopping_list_id', $shoppingList->id)
                    ->orderBy('status_id')
                    ->get();
        return view ('shopping_list.show', compact('items', 'shoppingList'));
    }

    public function create()
    {
        return view('shopping_list.create');
    }

    public function create_item()
    {
        return view('shopping_list.create_item');
    }

    public function store(Request $request)
    {
        $validatedData = $request->validate([
            'name' => 'required',
        ]);

        ShoppingList::create($validatedData);

        $this->notificationToggle('list_created_success', 'success');
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

        $shoppingList->update($validatedData);

        $this->notificationToggle('list_updated_success', 'success');
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
}

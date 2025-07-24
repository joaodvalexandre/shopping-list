<?php

namespace App\Http\Controllers;

use App\Models\ShoppingList;
use Illuminate\Http\Request;

class DashboardController extends Controller
{
    public function index(){
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

        return view('dashboard', compact('shoppingList'));
    }
}

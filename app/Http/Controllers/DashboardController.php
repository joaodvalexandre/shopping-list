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
            $list->pending = $list->getPendingItems();
            $list->in_cart = $list->getInCartItems();
            $list->purchased = $list->getPurchasedItems();
            $list->total = $list->getTotalItems();
        });

        return view('dashboard', compact('shoppingList'));
    }
}

<?php

namespace App\Http\Controllers;

class DashboardController extends Controller
{
    public function index()
    {
        $shoppingList = ShoppingListController::listsWithStats(auth()->user());

        return view('dashboard', compact('shoppingList'));
    }
}

<?php

use Illuminate\Support\Facades\App;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\ShoppingListController;
use App\Http\Controllers\ItemController;

Route::get('/', function () {
    return redirect()->route('dashboard');
});

Route::view('dashboard', 'dashboard')->name('dashboard');

Route::resource('shopping_list', ShoppingListController::class)->except(['show']);
Route::get('shopping_list/export', [ShoppingListController::class, 'export'])->name('shopping_list.export');
Route::patch('shopping_list/{shoppingList}/change-status/{newStatus}', [ShoppingListController::class, 'changeStatus'])->name('shopping_list.changeStatus');

Route::resource('item', ItemController::class)->except(['show']);

Route::get('switch-language/{locale}', function (string $locale) {
    if (! in_array($locale, ['en', 'pt'])) {
        abort(400);
    }

    session(['locale' => $locale]);
    App::setLocale($locale);

    return redirect()->back();
})->middleware('web')->name('switch-language');

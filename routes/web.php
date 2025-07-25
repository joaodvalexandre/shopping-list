<?php

use App\Http\Controllers\DashboardController;
use App\Http\Controllers\ShoppingListController;
use Illuminate\Support\Facades\App;
use Illuminate\Support\Facades\Route;

// Redirect root to dashboard
Route::redirect('/', '/dashboard');

Route::get('dashboard', [DashboardController::class, 'index'])->name('dashboard');

// Resource routes for shopping lists
Route::resource('shopping_list', ShoppingListController::class);

// Group routes related to shopping list items
Route::prefix('shopping_list/{list_id}')
    ->name('shopping_list.')
    ->group(function () {
        // Item create/edit routes (show forms)
        Route::get('create_item', [ShoppingListController::class, 'create_item'])->name('create_item');
        Route::get('edit_item/{item_id}', [ShoppingListController::class, 'edit_item'])->name('edit_item');

        // Item store/update routes (handle form submissions)
        Route::post('store_item', [ShoppingListController::class, 'store_item'])->name('store_item');
        Route::put('update_item/{item_id}', [ShoppingListController::class, 'update_item'])->name('update_item');

        // Item delete route
        Route::delete('destroy_item/{item_id}', [ShoppingListController::class, 'destroy_item'])->name('destroy_item');
    });

// Cart and purchase actions - note: item_id is enough, no list_id needed here
Route::prefix('shopping_list')
    ->name('shopping_list.')
    ->group(function () {
        Route::get('add_cart/{item_id}', [ShoppingListController::class, 'add_cart'])->name('add_cart');
        Route::get('remove_cart/{item_id}', [ShoppingListController::class, 'remove_cart'])->name('remove_cart');
        Route::get('mark_purchased/{item_id}', [ShoppingListController::class, 'mark_purchased'])->name('mark_purchased');
    });

// Export route with list_id
Route::get('shopping_list/export/{list_id}', [ShoppingListController::class, 'export'])->name('shopping_list.export');

// Language switching
Route::get('switch-language/{locale}', function (string $locale) {
    if (!in_array($locale, ['en', 'pt'])) {
        abort(400);
    }

    session(['locale' => $locale]);
    App::setLocale($locale);

    return redirect()->back();
})->middleware('web')->name('switch-language');

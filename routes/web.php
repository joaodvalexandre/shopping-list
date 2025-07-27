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

// Routes for item management
Route::prefix('shopping_list')
    ->name('shopping_list.')
    ->group(function () {
        // CRUD Actions
        Route::get('{list_id}/create_item', [ShoppingListController::class, 'create_item'])->name('create_item');
        Route::post('{list_id}/store_item', [ShoppingListController::class, 'store_item'])->name('store_item');
        Route::get('edit_item/{item_id}', [ShoppingListController::class, 'edit_item'])->name('edit_item');
        Route::put('update_item/{item_id}', [ShoppingListController::class, 'update_item'])->name('update_item');
        Route::delete('destroy_item/{item_id}', [ShoppingListController::class, 'destroy_item'])->name('destroy_item');

        // Status Change
        Route::get('add_cart/{item_id}', [ShoppingListController::class, 'add_cart'])->name('add_cart');
        Route::get('remove_cart/{item_id}', [ShoppingListController::class, 'remove_cart'])->name('remove_cart');
        Route::get('mark_purchased/{list_id}', [ShoppingListController::class, 'mark_purchased'])->name('mark_purchased');

        // QOL
        Route::get('export/{list_id}', [ShoppingListController::class, 'export'])->name('export');
    });

// Language switching
Route::get('switch-language/{locale}', function (string $locale) {
    if (!in_array($locale, ['en', 'pt'])) {
        abort(400);
    }

    session(['locale' => $locale]);
    App::setLocale($locale);

    return redirect()->back();
})->middleware('web')->name('switch-language');

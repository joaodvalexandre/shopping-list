<?php

use App\Http\Controllers\DashboardController;
use App\Http\Controllers\ItemController;
use Illuminate\Support\Facades\App;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\ShoppingListController;

Route::get('/', function () {
    return redirect()->route('dashboard');
});

Route::get('dashboard', [DashboardController::class, 'index'])->name('dashboard');

Route::resource('shopping_list', ShoppingListController::class);

Route::get('item/export', [ItemController::class, 'export'])->name('item.export');
Route::patch('item/change-status/{newStatus}', [ItemController::class, 'changeStatus'])->name('item.changeStatus');

Route::get('switch-language/{locale}', function (string $locale) {
    if (! in_array($locale, ['en', 'pt'])) {
        abort(400);
    }

    session(['locale' => $locale]);
    App::setLocale($locale);

    return redirect()->back();
})->middleware('web')->name('switch-language');

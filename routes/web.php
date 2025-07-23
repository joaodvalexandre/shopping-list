<?php

use Illuminate\Support\Facades\App;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\ShoppingListController;
use App\Http\Controllers\ItemController;

Route::get('/', function () {
    return redirect()->route('dashboard');
});

Route::view('dashboard', 'dashboard')->name('dashboard');

Route::resource('shopping_list', ShoppingListController::class);

Route::get('item/export', [ShoppingListController::class, 'export'])->name('item.export');
Route::patch('item/change-status/{newStatus}', [ShoppingListController::class, 'changeStatus'])->name('item.changeStatus');

Route::get('switch-language/{locale}', function (string $locale) {
    if (! in_array($locale, ['en', 'pt'])) {
        abort(400);
    }

    session(['locale' => $locale]);
    App::setLocale($locale);

    return redirect()->back();
})->middleware('web')->name('switch-language');

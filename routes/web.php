<?php

use App\Http\Controllers\Auth\LoginController;
use App\Http\Controllers\DashboardController;
use App\Http\Controllers\Family\ListTypeController;
use App\Http\Controllers\Family\MemberController;
use App\Http\Controllers\PageController;
use App\Http\Controllers\SettingsController;
use App\Http\Controllers\ShoppingListController;
use App\Models\Language;
use Illuminate\Support\Facades\App;
use Illuminate\Support\Facades\Route;

// Language switching (also available on the login page); the languages on
// offer are the ones switched on in the backoffice
Route::get('switch-language/{locale}', function (string $locale) {
    if (! Language::isActive($locale)) {
        abort(400);
    }

    session(['locale' => $locale]);
    App::setLocale($locale);

    // Remember the choice on the account too
    if ($user = auth()->user()) {
        $user->update(['locale' => $locale]);
    }

    return redirect()->back();
})->name('switch-language');

// Content pages written in the backoffice (public)
Route::get('p/{slug}', [PageController::class, 'show'])->name('pages.show');

// Accounts are created by a family admin: there is no public registration
Route::middleware('guest')->group(function () {
    Route::get('login', [LoginController::class, 'create'])->name('login');
    Route::post('login', [LoginController::class, 'store'])->name('login.store');
});

Route::middleware('auth')->group(function () {
    Route::post('logout', [LoginController::class, 'destroy'])->name('logout');

    // Reachable while a temporary password is still set
    Route::get('settings', [SettingsController::class, 'edit'])->name('settings.edit');
    Route::put('settings/profile', [SettingsController::class, 'updateProfile'])->name('settings.profile');
    Route::put('settings/password', [SettingsController::class, 'updatePassword'])->name('settings.password');

    Route::middleware('password.changed')->group(function () {
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

                // Status change (state-changing, so POST)
                Route::post('add_cart/{item_id}', [ShoppingListController::class, 'add_cart'])->name('add_cart');
                Route::post('remove_cart/{item_id}', [ShoppingListController::class, 'remove_cart'])->name('remove_cart');
                Route::post('mark_purchased/{list_id}', [ShoppingListController::class, 'mark_purchased'])->name('mark_purchased');

                // QOL
                Route::get('export/{list_id}', [ShoppingListController::class, 'export'])->name('export');
            });

        // Family administration (family admins only)
        Route::middleware('can:manage-family')->prefix('family')->name('family.')->group(function () {
            Route::resource('members', MemberController::class)->except('show');
            Route::post('members/{member}/reset-password', [MemberController::class, 'resetPassword'])->name('members.reset_password');
            Route::resource('list-types', ListTypeController::class)->except('show');
        });
    });
});

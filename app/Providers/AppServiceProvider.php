<?php

namespace App\Providers;

use App\Livewire\Layout\NotificationComponent;
use App\Models\Item;
use App\Models\ShoppingList;
use App\Models\User;
use App\Observers\ItemObserver;
use App\Observers\ShoppingListObserver;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\ServiceProvider;
use Illuminate\Validation\Rules\Password;
use Livewire\Livewire;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        RateLimiter::for('api', function (Request $request) {
            return Limit::perMinute(60)->by($request->user()?->id ?: $request->ip());
        });

        Password::defaults(fn () => Password::min(8)->letters()->numbers());

        // Family admins manage their own family's members and list types
        Gate::define('manage-family', fn (User $user) => $user->isFamilyAdmin());

        // Route bindings never leave the signed-in user's scope; anything
        // outside it is a 404, so other families' data cannot be probed.
        Route::bind('shopping_list', function (string $value) {
            return ShoppingList::visibleTo(request()->user())->findOrFail($value);
        });
        Route::bind('member', function (string $value) {
            return User::where('family_id', request()->user()->family_id)->findOrFail($value);
        });

        Livewire::component('layout.notification-component', NotificationComponent::class);
        Item::observe(ItemObserver::class);
        ShoppingList::observe(ShoppingListObserver::class);
    }
}

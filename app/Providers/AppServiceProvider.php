<?php

namespace App\Providers;

use App\Livewire\Layout\NotificationComponent;
use App\Models\Item;
use App\Models\ShoppingList;
use App\Observers\ItemObserver;
use App\Observers\ShoppingListObserver;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;
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

        Livewire::component('layout.notification-component', NotificationComponent::class);
        Item::observe(ItemObserver::class);
        ShoppingList::observe(ShoppingListObserver::class);
    }
}

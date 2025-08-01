<?php

namespace App\Providers;

use App\Livewire\Layout\NotificationComponent;
use Illuminate\Support\Facades\App;
use Illuminate\Support\Facades\Session;
use Illuminate\Support\ServiceProvider;
use App\Models\Item;
use App\Models\ShoppingList;
use App\Observers\ItemObserver;
use App\Observers\ShoppingListObserver;
use Livewire\Livewire;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     *
     * @return void
     */
    public function register()
    {
        //
    }

    /**
     * Bootstrap any application services.
     *
     * @return void
     */
    public function boot()
    {
        if(Session::has('locale')) {
            App::setLocale(Session::get('locale'));
        }

        Livewire::component('layout.notification-component', NotificationComponent::class);
        Item::observe(ItemObserver::class);
        ShoppingList::observe(ShoppingListObserver::class);
    }
}

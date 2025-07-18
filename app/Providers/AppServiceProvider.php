<?php

namespace App\Providers;

use App\Livewire\Layout\NotificationComponent;
use Illuminate\Support\Facades\App;
use Illuminate\Support\Facades\Session;
use Illuminate\Support\ServiceProvider;
use Illuminate\Support\Facades\URL;
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
        // Force HTTPS in production environment
        if (app()->environment('production')) {
            URL::forceScheme('https');
        }

        if(Session::has('locale')) {
            App::setLocale(Session::get('locale'));
        }

        Livewire::component('layout.notification-component', NotificationComponent::class);
    }
}

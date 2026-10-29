<?php

namespace App\Providers;

use App\Livewire\Layout\NotificationComponent;
use App\Models\Admin;
use App\Models\Family;
use App\Models\Item;
use App\Models\Language;
use App\Models\MenuItem;
use App\Models\Page;
use App\Models\Permission;
use App\Models\Role;
use App\Models\ShoppingList;
use App\Models\Translation;
use App\Models\User;
use App\Observers\ItemObserver;
use App\Observers\ShoppingListObserver;
use App\Policies\Backoffice\AdminPolicy;
use App\Policies\Backoffice\FamilyPolicy;
use App\Policies\Backoffice\LanguagePolicy;
use App\Policies\Backoffice\MemberPolicy;
use App\Policies\Backoffice\MenuItemPolicy;
use App\Policies\Backoffice\PagePolicy;
use App\Policies\Backoffice\PermissionPolicy;
use App\Policies\Backoffice\RolePolicy;
use App\Policies\Backoffice\TranslationPolicy;
use App\Support\Translations\DatabaseTranslationLoader;
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
        // Texts edited in the backoffice override the ones shipped in resources/lang
        $this->app->extend('translation.loader', fn ($loader) => new DatabaseTranslationLoader($loader));
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

        $this->registerBackofficeAccess();

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

    /** Which backoffice administrator may do what (roles and permissions). */
    private function registerBackofficeAccess(): void
    {
        foreach ([
            Family::class => FamilyPolicy::class,
            User::class => MemberPolicy::class,
            Page::class => PagePolicy::class,
            MenuItem::class => MenuItemPolicy::class,
            Language::class => LanguagePolicy::class,
            Translation::class => TranslationPolicy::class,
            Admin::class => AdminPolicy::class,
            Role::class => RolePolicy::class,
            Permission::class => PermissionPolicy::class,
        ] as $model => $policy) {
            Gate::policy($model, $policy);
        }

        // No Gate::before shortcut for super administrators on purpose: it would also
        // skip the rules that protect everyone (built-in roles cannot be deleted...).
        // The policies already answer "yes" to a super administrator's permission checks.
    }
}

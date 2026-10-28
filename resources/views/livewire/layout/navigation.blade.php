<?php

use App\Livewire\Actions\Logout;
use Livewire\Volt\Component;

new class extends Component
{
    /**
     * Log the current user out of the application.
     */
    public function logout(Logout $logout): void
    {
        $logout();

        $this->redirect(route("login"));
    }
}; ?>

<nav x-data="{ mobileMenuOpen: false, userMenuOpen: false, shoppingMenuOpen: false }" class="bg-white dark:bg-gray-800 border-b border-gray-100 dark:border-gray-700">
    <div class="max-w-7xl mx-auto lg:px-6">
        <div class="flex justify-between h-16">
            <div class="flex items-center">
                <!-- Mobile menu button -->
                <div class="flex items-center lg:hidden p-2">
                    <div x-data="{ open: false, shoppingMenuOpen: false }" class="relative">
                        <x-navbar.hamburguer-menu />
                        <x-navbar.mobile-menu />
                    </div>
                </div>

                <!-- Logo -->
                <div class="shrink-0 flex items-center">
                    <a href="{{ route('dashboard') }}" wire:navigate>
                        <x-custom-icon package="mingcute" icon="shopping-cart-2-line" size="38" class="text-gray-800 dark:text-gray-200"/>
                    </a>
                </div>

                <!-- Navigation Links (visible on larger screens) -->
                <x-navbar.desktop-menu />
            </div>

            <!-- Right side items: Language selector, dark mode toggle, and user menu -->
            <div class="flex items-center space-x-4">
                <!-- Language selector and dark mode toggle -->
                <div class="flex items-center space-x-2">
                    @include('partials.language-dropdown')
                    @include('partials.theme-toggle')
                </div>

                <!-- User menu -->
                @auth
                    <div class="relative pr-2" x-data="{ open: false }">
                        <button @click="open = !open" type="button"
                                class="flex items-center gap-1 text-sm font-medium text-gray-700 dark:text-gray-300 hover:text-gray-900 dark:hover:text-white focus:outline-hidden">
                            <x-custom-icon icon="account-circle" size="28" />
                            <span class="hidden sm:block max-w-32 truncate">{{ auth()->user()->name }}</span>
                        </button>

                        <div x-show="open" x-cloak @click.away="open = false"
                             class="absolute right-0 z-50 mt-2 w-48 origin-top-right rounded-md bg-white dark:bg-gray-700 py-1 shadow-lg ring-1 ring-black ring-opacity-5"
                             role="menu">
                            <x-dropdown-nav-link :href="route('settings.edit')" wire:navigate class="text-gray-700 dark:text-gray-300">
                                {{ __('settings') }}
                            </x-dropdown-nav-link>
                            @can('manage-family')
                                <x-dropdown-nav-link :href="route('family.members.index')" wire:navigate class="text-gray-700 dark:text-gray-300">
                                    {{ __('family') }}
                                </x-dropdown-nav-link>
                            @endcan
                            <button wire:click="logout" type="button"
                                    class="mx-2 my-1 block w-[calc(100%-1rem)] px-4 py-2 text-left text-sm text-gray-700 dark:text-gray-300 rounded-md hover:bg-gray-100 dark:hover:bg-gray-600">
                                {{ __('logout') }}
                            </button>
                        </div>
                    </div>
                @endauth
            </div>
        </div>
    </div>
</nav>

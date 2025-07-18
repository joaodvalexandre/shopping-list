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

        $this->redirect('/', navigate: true);
    }
}; ?>

<nav x-data="{ mobileMenuOpen: false, userMenuOpen: false, vehicleMenuOpen: false }" class="bg-white dark:bg-gray-800 border-b border-gray-100 dark:border-gray-700">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between h-16">
            <div class="flex items-center">
                <!-- Mobile menu button -->
                <div class="flex items-center lg:hidden mr-2">
                    <div x-data="{ open: false, vehicleMenuOpen: false }" class="relative">
                        <x-navbar.hamburguer-menu />
                        <x-navbar.mobile-menu />
                    </div>
                </div>

                <!-- Logo -->
                <div class="shrink-0 flex items-center">
                    <a href="{{ route('dashboard') }}" wire:navigate>
                        <x-application-logo class="block h-9 w-auto fill-current text-gray-800 dark:text-gray-200" />
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
            </div>
        </div>
    </div>
</nav>

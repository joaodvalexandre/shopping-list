<div x-show="open"
     x-transition:enter="transition ease-out duration-200"
     x-transition:enter-start="transform opacity-0 scale-95"
     x-transition:enter-end="transform opacity-100 scale-100"
     x-transition:leave="transition ease-in duration-150"
     x-transition:leave-start="transform opacity-100 scale-100"
     x-transition:leave-end="transform opacity-0 scale-95"
     @click.away="if (shoppingMenuOpen) { shoppingMenuOpen = false; setTimeout(() => { open = false }, 150); } else { open = false; }"
     class="origin-top-left absolute left-0 mt-2 w-48 rounded-md shadow-lg py-1 bg-white dark:bg-gray-700 ring-1 ring-black ring-opacity-5 focus:outline-none"
     role="menu"
     aria-orientation="vertical"
     aria-labelledby="user-menu-button"
     tabindex="-1">
    <x-dropdown-nav-link :href="route('dashboard')" :active="request()->routeIs('dashboard')" wire:navigate class="text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-500">
        {{ __('dashboard') }}
    </x-dropdown-nav-link>
    <x-dropdown-nav-link :href="route('shopping_list.index')" :active="request()->routeIs(['shopping_list*', 'item*'])" wire:navigate class="text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-500">
        {{ __('shopping_list') }}
    </x-dropdown-nav-link>
</div>

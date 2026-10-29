<div x-show="open"
     x-transition:enter="transition ease-out duration-200"
     x-transition:enter-start="transform opacity-0 scale-95"
     x-transition:enter-end="transform opacity-100 scale-100"
     x-transition:leave="transition ease-in duration-150"
     x-transition:leave-start="transform opacity-100 scale-100"
     x-transition:leave-end="transform opacity-0 scale-95"
     @click.away="if (shoppingMenuOpen) { shoppingMenuOpen = false; setTimeout(() => { open = false }, 150); } else { open = false; }"
     class="origin-top-left absolute left-0 mt-2 w-48 rounded-md shadow-lg py-1 bg-white dark:bg-gray-700 ring-1 ring-black ring-opacity-5 focus:outline-hidden"
     role="menu"
     aria-orientation="vertical"
     aria-labelledby="user-menu-button"
     tabindex="-1">
    @include('partials.navbar-items', ['mobile' => true])
</div>

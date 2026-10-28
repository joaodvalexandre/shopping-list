<div class="hidden lg:flex lg:items-center lg:ml-6 lg:space-x-4">
    <x-nav-link :href="route('dashboard')" :active="request()->routeIs('dashboard')" wire:navigate class="text-gray-900 dark:text-gray-100">
        {{ __('dashboard') }}
    </x-nav-link>
    <x-nav-link :href="route('shopping_list.index')" :active="request()->routeIs(['shopping_list*', 'item*'])" wire:navigate class="text-gray-900 dark:text-gray-100">
        {{ __('shopping_list') }}
    </x-nav-link>
    @can('manage-family')
        <x-nav-link :href="route('family.members.index')" :active="request()->routeIs('family*')" wire:navigate class="text-gray-900 dark:text-gray-100">
            {{ __('family') }}
        </x-nav-link>
    @endcan
</div>

{{-- Links of the account menu, as arranged in the backoffice (Menus). Log out is always there, after them. --}}
@foreach(\App\Models\MenuItem::tree('user_menu', auth()->user()) as $menuItem)
    @if($menuItem->children->isEmpty())
        <x-dropdown-nav-link :href="$menuItem->href()" :active="$menuItem->isCurrent()" :target="$menuItem->new_tab ? '_blank' : null" :rel="$menuItem->new_tab ? 'noopener noreferrer' : null" :wire:navigate="(bool) $menuItem->screen" class="text-gray-700 dark:text-gray-300">
            {{ $menuItem->labelIn() }}
        </x-dropdown-nav-link>
    @else
        <p class="mx-4 mt-2 px-2 text-xs font-semibold uppercase tracking-wide text-gray-500 dark:text-gray-400">{{ $menuItem->labelIn() }}</p>
        @foreach($menuItem->children as $child)
            <x-dropdown-nav-link :href="$child->href()" :active="$child->isCurrent()" :target="$child->new_tab ? '_blank' : null" :rel="$child->new_tab ? 'noopener noreferrer' : null" :wire:navigate="(bool) $child->screen" class="text-gray-700 dark:text-gray-300">
                {{ $child->labelIn() }}
            </x-dropdown-nav-link>
        @endforeach
    @endif
@endforeach

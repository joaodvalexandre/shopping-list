{{-- Links of the navbar, as arranged in the backoffice (Menus) for whoever is looking. $mobile: stacked list for the small-screen menu --}}
@php
    $navbarItems = \App\Models\MenuItem::navbarFor(auth()->user());
    $isMobile = $mobile ?? false;
@endphp

@foreach($navbarItems as $navItem)
    @if($navItem->children->isEmpty())
        @if($isMobile)
            <x-dropdown-nav-link :href="$navItem->href()" :active="$navItem->isCurrent()" :target="$navItem->new_tab ? '_blank' : null" :rel="$navItem->new_tab ? 'noopener noreferrer' : null" :wire:navigate="(bool) $navItem->screen" class="text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-500">
                {{ $navItem->labelIn() }}
            </x-dropdown-nav-link>
        @else
            <x-nav-link :href="$navItem->href()" :active="$navItem->isCurrent()" :target="$navItem->new_tab ? '_blank' : null" :rel="$navItem->new_tab ? 'noopener noreferrer' : null" :wire:navigate="(bool) $navItem->screen" class="text-gray-900 dark:text-gray-100">
                {{ $navItem->labelIn() }}
            </x-nav-link>
        @endif
    @elseif($isMobile)
        {{-- On a small screen a dropdown is a small heading with its links under it --}}
        <p class="mx-4 mt-2 px-2 text-xs font-semibold uppercase tracking-wide text-gray-500 dark:text-gray-400">{{ $navItem->labelIn() }}</p>
        @foreach($navItem->children as $child)
            <x-dropdown-nav-link :href="$child->href()" :active="$child->isCurrent()" :target="$child->new_tab ? '_blank' : null" :rel="$child->new_tab ? 'noopener noreferrer' : null" :wire:navigate="(bool) $child->screen" class="text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-500">
                {{ $child->labelIn() }}
            </x-dropdown-nav-link>
        @endforeach
    @else
        <div class="relative" x-data="{ open: false }" @click.away="open = false" @keydown.escape.window="open = false">
            <button type="button" @click="open = !open" :aria-expanded="open"
                    class="flex items-center gap-1 px-4 py-2 text-sm leading-5 text-gray-900 dark:text-gray-100 rounded-md hover:bg-gray-100 dark:hover:bg-gray-600 focus:outline-hidden transition duration-150 ease-in-out">
                {{ $navItem->labelIn() }}
                <svg class="h-4 w-4 transition-transform" :class="{ 'rotate-180': open }" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true"><path fill-rule="evenodd" d="M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z" clip-rule="evenodd"/></svg>
            </button>
            <div x-show="open" x-cloak x-transition
                 class="absolute left-0 z-50 mt-2 w-52 rounded-md bg-white dark:bg-gray-700 py-1 shadow-lg ring-1 ring-black/5" role="menu">
                @if($navItem->href())
                    <x-dropdown-nav-link :href="$navItem->href()" :active="$navItem->isCurrent()" class="font-semibold">{{ $navItem->labelIn() }}</x-dropdown-nav-link>
                @endif
                @foreach($navItem->children as $child)
                    <x-dropdown-nav-link :href="$child->href()" :active="$child->isCurrent()" :target="$child->new_tab ? '_blank' : null" :rel="$child->new_tab ? 'noopener noreferrer' : null" :wire:navigate="(bool) $child->screen">
                        {{ $child->labelIn() }}
                    </x-dropdown-nav-link>
                @endforeach
            </div>
        </div>
    @endif
@endforeach

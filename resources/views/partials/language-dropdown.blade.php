@php
    $languages = \App\Models\Language::active();
    $currentCode = app()->getLocale();
    $current = $languages->firstWhere('code', $currentCode);
@endphp

{{-- Hidden when there is only one language to choose from --}}
@if($languages->count() > 1)
    <div class="relative" x-data="{ open: false }">
        <button @click="open = !open" type="button"
                class="flex items-center text-sm font-medium text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 focus:outline-hidden transition duration-150 ease-in-out"
                aria-label="{{ __('select_language') }}">
            <span class="mr-1">
                {!! \App\Models\Language::flagHtml($current['flag'] ?? null, $currentCode) !!}
            </span>
            <svg class="ml-1 h-5 w-5 transition-transform duration-200"
                 :class="{'rotate-180': open}"
                 xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clip-rule="evenodd" />
            </svg>
        </button>

        <div x-show="open" x-cloak
             x-transition:enter="transition ease-out duration-200"
             x-transition:enter-start="transform opacity-0 scale-95"
             x-transition:enter-end="transform opacity-100 scale-100"
             x-transition:leave="transition ease-in duration-75"
             x-transition:leave-start="transform opacity-100 scale-100"
             x-transition:leave-end="transform opacity-0 scale-95"
             @click.away="open = false"
             class="absolute right-0 z-50 mt-2 origin-top-right rounded-md bg-white dark:bg-gray-700 py-1 shadow-lg ring-1 ring-black ring-opacity-5 focus:outline-hidden"
             role="menu" aria-orientation="vertical">
            @foreach($languages as $language)
                <x-dropdown-nav-link :href="route('switch-language', $language['code'])" :active="$currentCode === $language['code']" class="hover:bg-gray-200 dark:hover:bg-gray-500">
                    <div class="flex items-center gap-2 whitespace-nowrap">
                        {!! \App\Models\Language::flagHtml($language['flag'], $language['code']) !!}
                        <span>{{ $language['native_name'] }}</span>
                    </div>
                </x-dropdown-nav-link>
            @endforeach
        </div>
    </div>
@endif

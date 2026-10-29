{{-- The footer, from the links arranged in the backoffice (Menus): columns for links with others under them, then the loose ones --}}
@php
    $footerItems = \App\Models\MenuItem::tree('footer');
    $footerColumns = $footerItems->filter(fn ($item) => $item->children->isNotEmpty());
    $footerLoose = $footerItems->filter(fn ($item) => $item->children->isEmpty());
    $linkClass = 'hover:text-gray-900 hover:underline dark:hover:text-gray-100';
@endphp

<footer class="mt-auto w-full px-6 py-6 text-sm text-gray-500 dark:text-gray-400">
    <div class="mx-auto flex max-w-7xl flex-col items-center gap-5">
        @if($footerColumns->isNotEmpty())
            <div class="flex flex-wrap justify-center gap-x-14 gap-y-6">
                @foreach($footerColumns as $column)
                    <div class="min-w-32">
                        <p class="mb-2 font-semibold text-gray-700 dark:text-gray-200">
                            @if($column->href())
                                @include('partials.menu-link', ['item' => $column, 'class' => $linkClass])
                            @else
                                {{ $column->labelIn() }}
                            @endif
                        </p>
                        <ul class="flex flex-col gap-1">
                            @foreach($column->children as $child)
                                <li>@include('partials.menu-link', ['item' => $child, 'class' => $linkClass])</li>
                            @endforeach
                        </ul>
                    </div>
                @endforeach
            </div>
        @endif

        @if($footerLoose->isNotEmpty())
            <nav class="flex flex-wrap justify-center gap-x-5 gap-y-1">
                @foreach($footerLoose as $item)
                    @include('partials.menu-link', ['item' => $item, 'class' => $linkClass])
                @endforeach
            </nav>
        @endif

        <p class="text-xs text-gray-400 dark:text-gray-500">&copy; {{ now()->year }} {{ config('app.name') }}</p>
    </div>
</footer>

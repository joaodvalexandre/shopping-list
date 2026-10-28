@php($footerPages = \App\Models\Page::footerLinks())

@if($footerPages->isNotEmpty())
    <footer class="py-4 text-center text-sm text-gray-500 dark:text-gray-400">
        <nav class="flex flex-wrap justify-center gap-x-4 gap-y-1">
            @foreach($footerPages as $footerPage)
                <a href="{{ route('pages.show', $footerPage->slug) }}" class="hover:text-gray-700 hover:underline dark:hover:text-gray-200">
                    {{ $footerPage->titleIn() }}
                </a>
            @endforeach
        </nav>
    </footer>
@endif

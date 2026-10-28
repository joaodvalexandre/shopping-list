<x-guest-layout wide :title="$title">
    <h1 class="mb-4 text-2xl font-semibold">{{ $title }}</h1>

    <div class="prose-content flex flex-col gap-3 leading-relaxed [&_a]:text-blue-600 [&_a]:underline dark:[&_a]:text-blue-400 [&_h2]:mt-4 [&_h2]:text-xl [&_h2]:font-semibold [&_h3]:mt-3 [&_h3]:text-lg [&_h3]:font-semibold [&_ol]:ml-6 [&_ol]:list-decimal [&_ul]:ml-6 [&_ul]:list-disc">
        {!! $html !!}
    </div>

    <div class="mt-6 text-sm">
        <a href="{{ auth()->check() ? route('dashboard') : route('login') }}" class="text-blue-600 underline dark:text-blue-400">
            {{ __('go_back') }}
        </a>
    </div>
</x-guest-layout>

<x-guest-layout wide :title="$title">
    {{-- Back to where the reader came from: the login page, or the dashboard when signed in --}}
    <a href="{{ auth()->check() ? route('dashboard') : route('login') }}"
       class="mb-4 -ml-2 inline-flex items-center gap-2 rounded-md px-2 py-1.5 text-sm font-medium text-gray-700 hover:bg-gray-100 hover:text-gray-900 focus:outline-none focus:ring-2 focus:ring-gray-400 dark:text-gray-300 dark:hover:bg-gray-700 dark:hover:text-white">
        <x-custom-icon icon="arrow-back" />
        <span>{{ auth()->check() ? __('back_to_dashboard') : __('back_to_login') }}</span>
    </a>

    <h1 class="mb-4 text-2xl font-semibold">{{ $title }}</h1>

    <div class="prose-content flex flex-col gap-3 leading-relaxed [&_a]:text-blue-600 [&_a]:underline dark:[&_a]:text-blue-400 [&_h2]:mt-4 [&_h2]:text-xl [&_h2]:font-semibold [&_h3]:mt-3 [&_h3]:text-lg [&_h3]:font-semibold [&_ol]:ml-6 [&_ol]:list-decimal [&_ul]:ml-6 [&_ul]:list-disc">
        {!! $html !!}
    </div>
</x-guest-layout>

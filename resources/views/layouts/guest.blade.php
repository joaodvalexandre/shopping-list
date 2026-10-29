<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="csrf-token" content="{{ csrf_token() }}">

        <title>{{ $attributes->get('title') ?? __('login') }}</title>

        <link rel="preconnect" href="https://fonts.bunny.net">
        <link href="https://fonts.bunny.net/css?family=figtree:400,500,600&display=swap" rel="stylesheet" />

        @vite(['resources/css/app.css', 'resources/js/app.js'])

        {{-- Livewire brings Alpine, which the language menu and the dark-mode toggle need --}}
        @livewireStyles
        <style>[x-cloak] { display: none !important; }</style>
    </head>
    <body class="font-sans antialiased">
        <div class="min-h-screen flex flex-col items-center justify-center bg-gray-100 dark:bg-gray-900 px-6 py-6">
            {{-- Links of the navbar (backoffice: Menus), then the language and theme choice --}}
            <div class="flex flex-wrap items-center justify-center gap-2 mb-6">
                {{-- (not while choosing a first password: every link would only lead back there) --}}
                @unless($attributes->has('no-menu'))
                    @include('partials.navbar-items')
                @endunless
                @include('partials.language-dropdown')
                @include('partials.theme-toggle')
            </div>

            <div class="w-full {{ $attributes->has('wide') ? 'sm:max-w-3xl' : 'sm:max-w-md' }} p-6 bg-white dark:bg-gray-800 shadow-md rounded-lg text-gray-900 dark:text-gray-100">
                <div class="flex justify-center mb-4">
                    <x-custom-icon package="mingcute" icon="shopping-cart-2-line" size="48" class="text-gray-800 dark:text-gray-200"/>
                </div>
                {{ $slot }}
            </div>

            @include('partials.footer-pages')
        </div>

        @livewireScripts
    </body>
</html>

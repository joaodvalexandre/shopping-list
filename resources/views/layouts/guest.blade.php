<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="csrf-token" content="{{ csrf_token() }}">

        <title>{{ __('login') }}</title>

        <link rel="preconnect" href="https://fonts.bunny.net">
        <link href="https://fonts.bunny.net/css?family=figtree:400,500,600&display=swap" rel="stylesheet" />

        @vite(['resources/css/app.css', 'resources/js/app.js'])
    </head>
    <body class="font-sans antialiased">
        <div class="min-h-screen flex flex-col items-center justify-center bg-gray-100 dark:bg-gray-900 px-6">
            <div class="flex items-center gap-2 mb-6">
                @include('partials.language-dropdown')
                @include('partials.theme-toggle')
            </div>

            <div class="w-full sm:max-w-md p-6 bg-white dark:bg-gray-800 shadow-md rounded-lg text-gray-900 dark:text-gray-100">
                <div class="flex justify-center mb-4">
                    <x-custom-icon package="mingcute" icon="shopping-cart-2-line" size="48" class="text-gray-800 dark:text-gray-200"/>
                </div>
                {{ $slot }}
            </div>
        </div>
    </body>
</html>

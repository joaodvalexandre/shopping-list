@php
    use App\Models\Page;
    $route = (explode('.', Route::currentRouteName())[0] == 'item') ? 'shopping_list' : explode('.', Route::currentRouteName())[0];
@endphp

<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="csrf-token" content="{{ csrf_token() }}">

        @include('partials.head-icons')

        <title>{{ $attributes->get('heading') ?? __(explode('.', Route::currentRouteName())[0]) }}</title>

        <!-- Fonts -->
        <link rel="preconnect" href="https://fonts.bunny.net">
        <link href="https://fonts.bunny.net/css?family=figtree:400,500,600&display=swap" rel="stylesheet" />
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.1.1/css/all.min.css">

        <!-- Include Vite CSS and JS -->
        <script>window.familyId = @json(auth()->user()?->family_id);</script>
        @vite(['resources/css/app.css', 'resources/js/app.js'])

        <!-- Include Livewire CSS -->
        @livewireStyles
    </head>
    <body class="font-sans antialiased">
        <div class="flex flex-col min-h-screen bg-gray-100 dark:bg-gray-900">
            <livewire:layout.navigation />

            <!-- Page Heading -->
            <header class="bg-white dark:bg-gray-800 shadow-sm text-black dark:text-white">
                <div class="max-w-7xl mx-auto py-4 px-6">
                    {{ $attributes->get('heading') ?? __($route) }}
                </div>
            </header>

            <!-- Page Content -->
            <main class="py-4">
                @if($route == 'dashboard')
                    <div class="text-gray-900 dark:text-gray-100 max-w-7xl mx-auto">
                        {{ $slot }}
                    </div>
                @else
                    <div class="flex flex-col gap-4 p-6 text-gray-900 dark:text-gray-100 max-w-7xl mx-auto bg-white dark:bg-gray-800 shadow-xs xl:rounded-lg">
                        {{ $slot }}
                    </div>
                @endif
            </main>

            @include('partials.footer-pages')
        </div>
        @livewireScripts
        <livewire:layout.notification-component />
        <script>
            document.addEventListener('DOMContentLoaded', function () {
                if(@json(session('notification')))
                    Livewire.dispatch('showNotification', @json(session('notification')));
            });

            var notificationToggle = function(message, status){
                Livewire.dispatch('showNotification', { message: message, type: status })
            }
        </script>
    </body>
</html>

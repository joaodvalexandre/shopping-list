{{-- Signed in: inside the app, in its white middle block under the navbar. Not signed in: on its own, like the login. --}}
@auth
    {{-- (no back button here: the navbar above already takes people anywhere) --}}
    <x-app-layout :heading="$title">
        @include('pages._content', ['html' => $html])
    </x-app-layout>
@else
    <x-guest-layout wide :title="$title">
        {{-- Back to the login page --}}
        <a href="{{ route('login') }}"
           class="mb-4 -ml-2 inline-flex items-center gap-2 rounded-md px-2 py-1.5 text-sm font-medium text-gray-700 hover:bg-gray-100 hover:text-gray-900 focus:outline-none focus:ring-2 focus:ring-gray-400 dark:text-gray-300 dark:hover:bg-gray-700 dark:hover:text-white">
            <x-custom-icon icon="arrow-back" />
            <span>{{ __('back_to_login') }}</span>
        </a>

        <h1 class="mb-4 text-2xl font-semibold">{{ $title }}</h1>

        @include('pages._content', ['html' => $html])
    </x-guest-layout>
@endauth

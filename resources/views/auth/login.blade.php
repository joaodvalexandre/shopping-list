<x-guest-layout>
    <form method="POST" action="{{ route('login.store') }}" class="flex flex-col gap-4">
        @csrf

        <x-input.input name="email" label="email" type="email" required autofocus autocomplete="username" />
        @error('email')
            <p class="text-sm text-red-600 dark:text-red-400">{{ $message }}</p>
        @enderror

        <x-input.input name="password" label="password" type="password" required autocomplete="current-password" />
        @error('password')
            <p class="text-sm text-red-600 dark:text-red-400">{{ $message }}</p>
        @enderror

        <label class="inline-flex items-center gap-2 text-sm text-gray-700 dark:text-gray-300">
            <input type="checkbox" name="remember" value="1" class="h-4 w-4 rounded">
            {{ __('remember_me') }}
        </label>

        <x-primary-button class="justify-center">{{ __('login') }}</x-primary-button>

        <p class="text-xs text-center text-gray-500 dark:text-gray-400">{{ __('login_help') }}</p>
    </form>
</x-guest-layout>

<x-guest-layout no-menu :title="__('choose_password')">
    <form method="POST" action="{{ route('password.choose.store') }}" class="flex flex-col gap-4">
        @csrf

        <div class="p-4 rounded-lg bg-yellow-100 text-yellow-900 dark:bg-yellow-900 dark:text-yellow-100 text-sm">
            {{ __('must_change_password') }}
        </div>

        <x-input.input name="password" label="new_password" type="password" required autofocus autocomplete="new-password" />
        @error('password')
            <p class="text-sm text-red-600 dark:text-red-400">{{ $message }}</p>
        @enderror

        <x-input.input name="password_confirmation" label="confirm_password" type="password" required autocomplete="new-password" />

        <x-primary-button class="justify-center">{{ __('change_password') }}</x-primary-button>

        <p class="text-xs text-center text-gray-500 dark:text-gray-400">{{ __('password_rules') }}</p>
    </form>

    <form method="POST" action="{{ route('logout') }}" class="mt-3 text-center">
        @csrf
        <button type="submit" class="text-sm text-blue-600 underline dark:text-blue-400">{{ __('logout') }}</button>
    </form>
</x-guest-layout>

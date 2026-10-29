<x-app-layout>
    <div class="grid gap-8 lg:grid-cols-2">
        <!-- Profile -->
        <form method="POST" action="{{ route('settings.profile') }}" class="flex flex-col gap-3">
            @csrf
            @method('PUT')
            <div class="text-xl">{{ __('profile') }}</div>

            <x-input.input name="name" label="name" :value="$user->name" required />
            @error('name') <p class="text-sm text-red-600 dark:text-red-400">{{ $message }}</p> @enderror

            <x-input.input name="email" label="email" type="email" :value="$user->email" required />
            @error('email') <p class="text-sm text-red-600 dark:text-red-400">{{ $message }}</p> @enderror

            <div class="w-full flex flex-col gap-1">
                <label for="locale" class="text-sm font-medium text-gray-700 dark:text-gray-300">{{ __('language') }}</label>
                <select name="locale" id="locale"
                        class="w-full px-4 py-2 text-sm rounded-lg shadow-xs border border-gray-300 bg-white text-gray-900 dark:bg-gray-800 dark:border-gray-600 dark:text-gray-100">
                    @foreach(App\Models\Language::active() as $language)
                        <option value="{{ $language['code'] }}" @selected(old('locale', $user->locale ?? app()->getLocale()) === $language['code'])>{{ $language['native_name'] }}</option>
                    @endforeach
                </select>
            </div>

            <div class="flex justify-end">
                <x-primary-button>{{ __('save') }}</x-primary-button>
            </div>
        </form>

        <!-- Password -->
        <form method="POST" action="{{ route('settings.password') }}" class="flex flex-col gap-3">
            @csrf
            @method('PUT')
            <div class="text-xl">{{ __('change_password') }}</div>

            <x-input.input name="current_password" label="current_password" type="password" required autocomplete="current-password" />
            @error('current_password') <p class="text-sm text-red-600 dark:text-red-400">{{ $message }}</p> @enderror

            <x-input.input name="password" label="new_password" type="password" required autocomplete="new-password" />
            @error('password') <p class="text-sm text-red-600 dark:text-red-400">{{ $message }}</p> @enderror

            <x-input.input name="password_confirmation" label="confirm_password" type="password" required autocomplete="new-password" />

            <div class="flex justify-end">
                <x-primary-button>{{ __('change_password') }}</x-primary-button>
            </div>
        </form>
    </div>
</x-app-layout>

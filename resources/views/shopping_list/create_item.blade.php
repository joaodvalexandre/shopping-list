<x-app-layout>
    <div class="text-xl">
        {{ __('create') }}
    </div>
    <form action="{{ route('shopping_list.store_item') }}" method="POST">
        @csrf

        <div class="flex flex-col gap-2">
            <!-- Name -->
            <div class="flex-1">
                <x-input.input
                    name="name"
                    label="name"
                    type="text"
                    required
                />
            </div>
        </div>

        <!-- Buttons aligned to right -->
        <div class="flex items-center justify-end space-x-2 mt-4">
            <a href="{{ route('shopping_list.show', $list_id) }}"
            class="inline-flex items-center px-4 py-2 bg-gray-800 dark:bg-gray-200 border border-transparent rounded-md font-semibold text-xs text-white dark:text-gray-800 uppercase tracking-widest hover:bg-gray-700 dark:hover:bg-white focus:bg-gray-700 dark:focus:bg-white active:bg-gray-900 dark:active:bg-gray-300 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 dark:focus:ring-offset-gray-800 transition ease-in-out duration-150"
            wire:navigate>
                {{ __('back_to_list') }}
            </a>

            <button type="submit"
                    class="inline-flex items-center px-4 py-2 bg-gray-800 dark:bg-gray-200 border border-transparent rounded-md font-semibold text-xs text-white dark:text-gray-800 uppercase tracking-widest hover:bg-gray-700 dark:hover:bg-white focus:bg-gray-700 dark:focus:bg-white active:bg-gray-900 dark:active:bg-gray-300 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 dark:focus:ring-offset-gray-800 transition ease-in-out duration-150">
                {{ __('create') }}
            </button>
        </div>
    </form>
</x-app-layout>

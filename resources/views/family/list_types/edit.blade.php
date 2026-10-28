<x-app-layout>
    <div class="text-xl">{{ __('edit') }}</div>

    <form action="{{ route('family.list-types.update', $listType->id) }}" method="POST">
        @csrf
        @method('PUT')
        <x-input.input name="name" label="name" :value="$listType->name" required />
        @error('name') <p class="text-sm text-red-600 dark:text-red-400">{{ $message }}</p> @enderror

        <div class="flex items-center justify-end space-x-2 mt-4">
            <a href="{{ route('family.list-types.index') }}"
               class="inline-flex items-center px-4 py-2 bg-gray-800 dark:bg-gray-200 border border-transparent rounded-md font-semibold text-xs text-white dark:text-gray-800 uppercase tracking-widest hover:bg-gray-700 dark:hover:bg-white transition ease-in-out duration-150"
               wire:navigate>{{ __('back_to_list') }}</a>
            <x-primary-button>{{ __('save') }}</x-primary-button>
        </div>
    </form>
</x-app-layout>

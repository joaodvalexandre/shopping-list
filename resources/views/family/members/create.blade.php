<x-app-layout>
    <div class="text-xl">{{ __('new_member') }}</div>
    <p class="text-sm text-gray-500 dark:text-gray-400">{{ __('new_member_help') }}</p>

    <form action="{{ route('family.members.store') }}" method="POST">
        @csrf
        @include('family.members._form')

        <div class="flex items-center justify-end space-x-2 mt-4">
            <a href="{{ route('family.members.index') }}"
               class="inline-flex items-center px-4 py-2 bg-gray-800 dark:bg-gray-200 border border-transparent rounded-md font-semibold text-xs text-white dark:text-gray-800 uppercase tracking-widest hover:bg-gray-700 dark:hover:bg-white transition ease-in-out duration-150"
               wire:navigate>{{ __('back_to_list') }}</a>
            <x-primary-button>{{ __('create') }}</x-primary-button>
        </div>
    </form>
</x-app-layout>

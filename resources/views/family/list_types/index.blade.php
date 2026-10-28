<x-app-layout>
    <div class="flex justify-between items-center">
        <div class="flex gap-2">
            <a href="{{ route('family.members.index') }}" class="px-4 py-2 rounded-full bg-gray-200 text-gray-800 dark:bg-gray-700 dark:text-gray-200" wire:navigate>{{ __('members') }}</a>
            <a href="{{ route('family.list-types.index') }}" class="px-4 py-2 rounded-full bg-gray-800 text-white dark:bg-gray-200 dark:text-gray-800" wire:navigate>{{ __('list_types') }}</a>
        </div>
        <a href="{{ route('family.list-types.create') }}" class="bg-blue-500 hover:bg-blue-600 text-white font-bold py-2 px-4 rounded-full transition duration-300 ease-in-out transform hover:scale-105" wire:navigate>
            <i class="fas fa-plus mr-2"></i>{{ __('new_list_type') }}
        </a>
    </div>

    @error('list_type')
        <div class="p-3 rounded-lg bg-red-100 text-red-900 dark:bg-red-900 dark:text-red-100">{{ $message }}</div>
    @enderror

    <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
            <thead class="bg-gray-200 dark:bg-gray-600 border-b-2 border-gray-300 dark:border-gray-500">
                <tr>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-700 dark:text-gray-200 uppercase tracking-wider">{{ __('name') }}</th>
                    <th class="px-6 py-3 w-0 text-left text-xs font-medium text-gray-700 dark:text-gray-200 uppercase tracking-wider">{{ __('lists') }}</th>
                    <th class="px-6 py-3 w-0 text-left text-xs font-medium text-gray-700 dark:text-gray-200 uppercase tracking-wider">{{ __('actions') }}</th>
                </tr>
            </thead>
            <tbody class="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
                @foreach($listTypes as $type)
                    <tr class="odd:bg-gray-50 even:bg-white dark:odd:bg-gray-700 dark:even:bg-gray-800">
                        <td class="px-6 py-4 whitespace-nowrap">{{ $type->name }}</td>
                        <td class="px-6 py-4 whitespace-nowrap text-right">{{ $type->shopping_lists_count }}</td>
                        <td class="px-6 py-4 whitespace-nowrap">
                            <div class="flex flex-row gap-2">
                                <a href="{{ route('family.list-types.edit', $type->id) }}"
                                   class="text-yellow-600 hover:text-yellow-900 dark:text-yellow-400 dark:hover:text-yellow-600" wire:navigate>
                                    <x-custom-icon icon="pencil"/>
                                </a>
                                @if($type->shopping_lists_count === 0)
                                    <x-delete-button action="{{ route('family.list-types.destroy', $type->id) }}" />
                                @endif
                            </div>
                        </td>
                    </tr>
                @endforeach
            </tbody>
        </table>
    </div>
</x-app-layout>

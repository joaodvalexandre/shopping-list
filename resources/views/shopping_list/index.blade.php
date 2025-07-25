<x-app-layout>
    <div class="flex justify-between items-center">
        <p></p>
        <div>
            <a href="{{ route('shopping_list.create') }}" class="bg-blue-500 hover:bg-blue-600 text-white font-bold py-2 px-4 rounded-full transition duration-300 ease-in-out transform hover:scale-105" wire:navigate>
                <i class="fas fa-plus mr-2"></i>{{ __('new_list') }}
            </a>
        </div>
    </div>

    @if($shoppingList->isEmpty())
        <p class="text-gray-500 dark:text-gray-400 text-center py-8">{{ __('no_lists_yet') }}</p>
    @else
        <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
                <thead class="bg-gray-200 dark:bg-gray-600 border-b-2 border-gray-300 dark:border-gray-500">
                    <tr>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-700 dark:text-gray-200 uppercase tracking-wider">{{ __('name') }}</th>
                        <th class="px-6 py-3 w-0 text-left text-xs font-medium text-gray-700 dark:text-gray-200 uppercase tracking-wider">{{ __('pending') }}</th>
                        <th class="px-6 py-3 w-0 text-left text-xs font-medium text-gray-700 dark:text-gray-200 uppercase tracking-wider">{{ __('in_cart') }}</th>
                        <th class="px-6 py-3 w-0 text-left text-xs font-medium text-gray-700 dark:text-gray-200 uppercase tracking-wider">{{ __('purchased') }}</th>
                        <th class="px-6 py-3 w-0 text-left text-xs font-medium text-gray-700 dark:text-gray-200 uppercase tracking-wider">{{ __('total') }}</th>
                        <th class="px-6 py-3 w-0 text-left text-xs font-medium text-gray-700 dark:text-gray-200 uppercase tracking-wider">{{ __('status') }}</th>
                        <th class="px-6 py-3 w-0 text-left text-xs font-medium text-gray-700 dark:text-gray-200 uppercase tracking-wider">{{ __('actions') }}</th>
                    </tr>
                </thead>
                <tbody class="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
                    @foreach($shoppingList as $item)
                        <tr class="transition duration-150 ease-in-out
                                    odd:bg-gray-50 even:bg-white
                                    dark:odd:bg-gray-700 dark:even:bg-gray-800
                                    hover:bg-gray-100 dark:hover:bg-gray-600">
                            <td class="px-6 py-4 whitespace-nowrap">{{ $item->name }}</td>
                            <td class="px-6 py-4 whitespace-nowrap text-right">{{ $item->pending }}</td>
                            <td class="px-6 py-4 whitespace-nowrap text-right">{{ $item->in_cart }}</td>
                            <td class="px-6 py-4 whitespace-nowrap text-right">{{ $item->purchased }}</td>
                            <td class="px-6 py-4 whitespace-nowrap text-right">{{ $item->total }}</td>
                            <td class="px-6 py-4 whitespace-nowrap text-center">
                                <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-{{$item->status['color']}}-500">
                                    {{ __($item->status['name']) }}
                                </span>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap text-right">
                                <div class="flex flex-row gap-2">
                                    <a href="{{ route('shopping_list.show', $item) }}"
                                        class="text-blue-600 hover:text-blue-900 dark:text-blue-400 dark:hover:text-blue-600" wire:navigate>
                                        <x-custom-icon icon="eye"/>
                                    </a>
                                    <x-delete-button action="{{ route('shopping_list.destroy', $item) }}" />
                                </div>
                            </td>
                        </tr>
                    @endforeach
                </tbody>
            </table>
        </div>
    @endif
</x-app-layout>

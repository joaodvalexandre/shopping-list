<x-app-layout>
    <div class="flex justify-between items-center">
        <p></p>
        <div>
            <a href="{{ route('shopping_list.create') }}" class="bg-blue-500 hover:bg-blue-600 text-white font-bold py-2 px-4 rounded-full transition duration-300 ease-in-out transform hover:scale-105" wire:navigate>
                <i class="fas fa-plus mr-2"></i>{{ __('add_item') }}
            </a>
        </div>
    </div>

    @if($shoppingList->isEmpty())
        <p class="text-gray-500 dark:text-gray-400 text-center py-8">{{ __('no_items_yet') }}</p>
    @else
        <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
                <thead class="bg-gray-200 dark:bg-gray-600 border-b-2 border-gray-300 dark:border-gray-500">
                    <tr>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-700 dark:text-gray-200 uppercase tracking-wider">{{ __('name') }}</th>
                        <th class="px-6 py-3 w-0 text-left text-xs font-medium text-gray-700 dark:text-gray-200 uppercase tracking-wider">{{ __('pending_items') }}</th>
                        <th class="px-6 py-3 w-0 text-left text-xs font-medium text-gray-700 dark:text-gray-200 uppercase tracking-wider">{{ __('in_cart_items') }}</th>
                        <th class="px-6 py-3 w-0 text-left text-xs font-medium text-gray-700 dark:text-gray-200 uppercase tracking-wider">{{ __('purchased_items') }}</th>
                        <th class="px-6 py-3 w-0 text-left text-xs font-medium text-gray-700 dark:text-gray-200 uppercase tracking-wider">{{ __('total_items') }}</th>
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
                            <td class="px-6 py-4 whitespace-nowrap">{{ $item->pending_items }}</td>
                            <td class="px-6 py-4 whitespace-nowrap">{{ $item->in_cart_items }}</td>
                            <td class="px-6 py-4 whitespace-nowrap">{{ $item->purchased_items }}</td>
                            <td class="px-6 py-4 whitespace-nowrap">{{ $item->total_items }}</td>
                            <td class="px-6 py-4 whitespace-nowrap">
                                <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-{{$item->status['color']}}-500">
                                    {{ __($item->status['name']) }}
                                </span>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap text-right">
                                <div class="flex flex-row gap-2">
                                    <a href="{{ route('shopping_list.show', $item->id) }}"
                                        class="text-blue-600 hover:text-blue-900 dark:text-blue-400 dark:hover:text-blue-600">
                                        <x-custom-icon icon="eye"/>
                                    </a>
                                    <form action="{{ route('shopping_list.destroy', $item) }}" method="POST" class="inline-block">
                                        @csrf
                                        @method('DELETE')
                                        <button type="submit" class="text-red-600 hover:text-red-900 dark:text-red-400 dark:hover:text-red-600" onclick="return confirm('{{ __('confirm_delete') }}')">
                                            <x-custom-icon icon="trash"/>
                                        </button>
                                    </form>
                                </div>
                            </td>
                        </tr>
                    @endforeach
                </tbody>
            </table>
        </div>
    @endif
</x-app-layout>

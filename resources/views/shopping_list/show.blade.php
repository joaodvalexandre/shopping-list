<x-app-layout>
    <style>
        .disabled-btn {
            color: rgb(50 50 50); /* Tailwind text-gray-400 */
            opacity: 0.6;
            cursor: not-allowed;
            pointer-events: none;
        }
        .dark .disabled-btn {
            color: rgb(107 114 128); /* Tailwind text-gray-500 for dark mode */
            opacity: 0.6;
        }
        .disabled-btn:hover {
            background: transparent !important;
            color: inherit !important;
        }
    </style>

    @php
        $size = 32;
    @endphp

    <div class="text-xl">
        {{ $shoppingList->name }}
    </div>
    <div class="flex justify-between items-center">
        <div class="flex flex-row gap-2">
            <a href="{{ route('shopping_list.index') }}" class="flex flex-row gap-2 bg-gray-500 hover:bg-gray-600 text-white font-bold py-2 px-4 rounded-full transition duration-300 ease-in-out transform hover:scale-105" wire:navigate>
                <x-custom-icon icon="arrow-back" /><span class="hidden sm:block">{{ __('go_back') }}</span>
            </a>
        </div>
        <div class="flex flex-row gap-2">
            @if($can['change_status'])
                <form method="POST" action="{{ route('shopping_list.mark_purchased', ['list_id' => $shoppingList->id]) }}">
                    @csrf
                    <button type="submit" @disabled(!$allInCart || !$listHasItems)
                        class="flex flex-row gap-2 font-bold py-2 px-4 rounded-full transition duration-300 ease-in-out transform {{ !$allInCart || !$listHasItems ? 'bg-gray-400 cursor-not-allowed opacity-50' : 'bg-green-500 hover:bg-green-600 text-white hover:scale-105' }}">
                        <x-custom-icon icon="cart-check" />
                        <span class="hidden sm:block">{{ __('finish_list') }}</span>
                    </button>
                </form>
            @endif
            <a href="{{ !$listHasItems ? '#' : route('shopping_list.export', ['list_id' => $shoppingList->id]) }}"
                class="flex flex-row gap-2 font-bold py-2 px-4 rounded-full transition duration-300 ease-in-out transform {{ !$listHasItems ? 'bg-gray-400 cursor-not-allowed opacity-50' : 'bg-orange-500 hover:bg-orange-600 text-white hover:scale-105' }}"
                @if(!$listHasItems) onclick="return false;" @endif>
                <x-custom-icon icon="download" />
                <span class="hidden sm:block">{{ __('export') }}</span>
            </a>
            @if($can['add_items'])
                <a href="{{ route('shopping_list.create_item', ['list_id' => $shoppingList->id]) }}" class="flex flex-row gap-2 bg-blue-500 hover:bg-blue-600 text-white font-bold py-2 px-4 rounded-full transition duration-300 ease-in-out transform hover:scale-105" wire:navigate>
                    <x-custom-icon icon="plus" /><span class="hidden sm:block">{{ __('new_item') }}</span>
                </a>
            @endif
        </div>
    </div>

    @if($items->isEmpty())
        <p class="text-gray-500 dark:text-gray-400 text-center py-8">{{ __('no_items_yet') }}</p>
    @else
        <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
                <thead class="bg-gray-200 dark:bg-gray-600 border-b-2 border-gray-300 dark:border-gray-500">
                    <tr>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-700 dark:text-gray-200 uppercase tracking-wider">{{ __('name') }}</th>
                        <th class="px-6 py-3 w-0 text-left text-xs font-medium text-gray-700 dark:text-gray-200 uppercase tracking-wider">{{ __('quant') }}</th>
                        <th class="px-6 py-3 w-0 text-left text-xs font-medium text-gray-700 dark:text-gray-200 uppercase tracking-wider">{{ __('status') }}</th>
                        <th class="px-6 py-3 w-0 text-left text-xs font-medium text-gray-700 dark:text-gray-200 uppercase tracking-wider">{{ __('actions') }}</th>
                    </tr>
                </thead>
                <tbody class="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
                    @foreach($items as $item)
                        <tr class="transition duration-150 ease-in-out
                                    odd:bg-gray-50 even:bg-white
                                    dark:odd:bg-gray-700 dark:even:bg-gray-800
                                    hover:bg-gray-100 dark:hover:bg-gray-600">
                            <td class="px-6 py-4 whitespace-nowrap">{{ $item->name }}</td>
                            <td class="px-6 py-4 whitespace-nowrap text-right">{{ $item->quantity }}</td>
                            <td class="px-6 py-4 whitespace-nowrap text-center">
                                <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full" style="background-color: {{ $item->status->color }}">
                                    {{ __($item->status->code) }}
                                </span>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap text-right">
                                <div class="flex flex-row gap-2">
                                    <!-- To buy -->
                                    @if($item->status->id == 1)
                                        @if($can['change_status'])
                                            <form method="POST" action="{{ route('shopping_list.add_cart', ['item_id' => $item->id]) }}" class="inline">
                                                @csrf
                                                <button type="submit" class="text-blue-600 hover:text-blue-900 dark:text-blue-400 dark:hover:text-blue-600" aria-label="{{ __('add_cart') }}">
                                                    <x-custom-icon icon="cart-arrow-down" />
                                                </button>
                                            </form>
                                        @endif
                                        @if($can['edit_items'])
                                            <a href="{{ route('shopping_list.edit_item', ['item_id' => $item->id]) }}"
                                                class="text-yellow-600 hover:text-yellow-900 dark:text-yellow-400 dark:hover:text-yellow-600" wire:navigate>
                                                <x-custom-icon icon="pencil" />
                                            </a>
                                        @endif
                                    @endif

                                    <!-- In Cart -->
                                    @if($item->status->id == 2 && $can['change_status'])
                                        <form method="POST" action="{{ route('shopping_list.remove_cart', ['item_id' => $item->id]) }}" class="inline">
                                            @csrf
                                            <button type="submit" class="text-orange-600 hover:text-orange-900 dark:text-orange-400 dark:hover:text-orange-600" aria-label="{{ __('remove_cart') }}">
                                                <x-custom-icon icon="cart-arrow-up" />
                                            </button>
                                        </form>
                                    @endif

                                    <!-- Delete -->
                                    @if($can['edit_items'] && ! $item->isInCart())
                                        <x-delete-button action="{{ route('shopping_list.destroy_item', ['item_id' => $item->id]) }}" />
                                    @endif
                                </div>
                            </td>
                        </tr>
                    @endforeach
                </tbody>
            </table>
        </div>
    @endif
</x-app-layout>

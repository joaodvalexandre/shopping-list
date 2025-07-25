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
        $size=32;
    @endphp
    <div class="text-xl">
        {{ $shoppingList->name }}
    </div>
    <div class="flex justify-between items-center">
        <div class="flex flex-row gap-2">
            <a href="{{ route('shopping_list.index') }}" class="flex flex-row gap-2 bg-gray-500 hover:bg-gray-600 text-white font-bold py-2 px-4 rounded-full transition duration-300 ease-in-out transform hover:scale-105" wire:navigate>
                <x-custom-icon icon="arrow-back"/><span class="hidden sm:block">{{ __('go_back') }}</span>
            </a>
        </div>
        <div class="flex flex-row gap-2">
            <!-- TODO: Improve this method, to something better in the future -->
            <a href="{{ route('shopping_list.create') }}" class="flex flex-row gap-2 bg-green-500 hover:bg-green-600 text-white font-bold py-2 px-4 rounded-full transition duration-300 ease-in-out transform hover:scale-105" wire:navigate>
                <x-custom-icon icon="download"/><span class="hidden sm:block">{{ __('export') }}</span>
            </a>
            <a href="{{ route('shopping_list.create') }}" class="flex flex-row gap-2 bg-blue-500 hover:bg-blue-600 text-white font-bold py-2 px-4 rounded-full transition duration-300 ease-in-out transform hover:scale-105" wire:navigate>
                <x-custom-icon icon="plus"/><span class="hidden sm:block">{{ __('new_item') }}</span>
            </a>
        </div>
    </div>

    @if($items->isEmpty())
        <p class="text-gray-500 dark:text-gray-400 text-center py-8">{{ __('no_lists_yet') }}</p>
    @else
        <div class="inline-flex flex-row gap-2 p-2 bg-gray-400 dark:bg-gray-900 shadow-sm rounded-lg self-start">
            <!-- Add to Cart -->
            <a x-data="{ show: false }" @mouseenter="show = true" @mouseleave="show = false"
            data-action="add_cart"
            class="relative action-btn text-blue-600 hover:text-blue-900 dark:text-blue-400 dark:hover:text-blue-600"
            href="{{ route('shopping_list.index') }}">
                <x-custom-icon icon="cart-arrow-down" size="{{ $size }}"/>
                <!-- Tooltip -->
                <div x-show="show" x-transition
                    class="absolute top-full mt-2 left-1/2 transform -translate-x-1/2 bg-gray-200 dark:bg-gray-700 text-gray-900 dark:text-white text-xs rounded py-1 px-2 shadow-lg whitespace-nowrap z-10">
                    {{ __('add_cart') }}
                </div>
            </a>

            <!-- Remove from Cart -->
            <a x-data="{ show: false }" @mouseenter="show = true" @mouseleave="show = false"
            data-action="remove_cart"
            class="relative action-btn text-orange-600 hover:text-orange-900 dark:text-orange-400 dark:hover:text-orange-600"
            href="{{ route('shopping_list.index') }}">
                <x-custom-icon icon="cart-arrow-up" size="{{ $size }}"/>
                <div x-show="show" x-transition
                    class="absolute top-full mt-2 left-1/2 transform -translate-x-1/2 bg-gray-200 dark:bg-gray-700 text-gray-900 dark:text-white text-xs rounded py-1 px-2 shadow-lg whitespace-nowrap z-10">
                    {{ __('remove_cart') }}
                </div>
            </a>

            <!-- Purchase -->
            <a x-data="{ show: false }" @mouseenter="show = true" @mouseleave="show = false"
            data-action="purchase"
            class="relative action-btn text-green-600 hover:text-green-900 dark:text-green-400 dark:hover:text-green-600"
            href="{{ route('shopping_list.index') }}">
                <x-custom-icon icon="cart-check" size="{{ $size }}"/>
                <div x-show="show" x-transition
                    class="absolute top-full mt-2 left-1/2 transform -translate-x-1/2 bg-gray-200 dark:bg-gray-700 text-gray-900 dark:text-white text-xs rounded py-1 px-2 shadow-lg whitespace-nowrap z-10">
                    {{ __('purchase') }}
                </div>
            </a>

            <!-- Delete -->
            <a x-data="{ show: false }" @mouseenter="show = true" @mouseleave="show = false"
            data-action="delete"
            class="relative action-btn text-red-600 hover:text-red-900 dark:text-red-400 dark:hover:text-red-600"
            href="{{ route('shopping_list.index') }}">
                <x-custom-icon icon="trash" size="{{ $size }}"/>
                <div x-show="show" x-transition
                    class="absolute top-full mt-2 left-1/2 transform -translate-x-1/2 bg-gray-200 dark:bg-gray-700 text-gray-900 dark:text-white text-xs rounded py-1 px-2 shadow-lg whitespace-nowrap z-10">
                    {{ __('delete') }}
                </div>
            </a>
        </div>

        <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
                <thead class="bg-gray-200 dark:bg-gray-600 border-b-2 border-gray-300 dark:border-gray-500">
                    <tr>
                        <th class="px-6 py-3 w-0 text-center text-xs font-medium text-gray-700 dark:text-gray-200 uppercase tracking-wider">
                            <x-input.simple-checkbox
                                name='general'
                                id="general"
                            />
                        </th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-700 dark:text-gray-200 uppercase tracking-wider">{{ __('name') }}</th>
                        <th class="px-6 py-3 w-0 text-left text-xs font-medium text-gray-700 dark:text-gray-200 uppercase tracking-wider">{{ __('quantity') }}</th>
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
                            <td class="px-6 py-4 whitespace-nowrap">
                                <x-input.simple-checkbox
                                    name='check_{{$item->id}}'
                                    id="{{$item->id}}"
                                    data-status="{{ $item->status_id }}"
                                />
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap">{{ $item->name }}</td>
                            <td class="px-6 py-4 whitespace-nowrap text-right">{{ $item->quantity }}</td>
                            <td class="px-6 py-4 whitespace-nowrap text-center">
                                <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full" style="background-color: {{$item->status->color}}">
                                    {{ __($item->status->code) }}
                                </span>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap text-right">
                                <div class="flex flex-row gap-2">
                                    <!-- To buy -->
                                    @if($item->status->id == 1)
                                        <a href="{{ route('item.add_cart', $item) }}"
                                            class="text-blue-600 hover:text-blue-900 dark:text-blue-400 dark:hover:text-blue-600" wire:navigate>
                                            <x-custom-icon icon="cart-arrow-down"/>
                                        </a>
                                        <a href="{{ route('item.edit', $item) }}"
                                            class="text-yellow-600 hover:text-yellow-900 dark:text-yellow-400 dark:hover:text-yellow-600" wire:navigate>
                                            <x-custom-icon icon="pencil"/>
                                        </a>
                                    @endif

                                    <!-- In Cart -->
                                    @if($item->status->id == 2)
                                        <a href="{{ route('item.remove_cart', $item) }}"
                                            class="text-orange-600 hover:text-orange-900 dark:text-orange-400 dark:hover:text-orange-600" wire:navigate>
                                            <x-custom-icon icon="cart-arrow-up"/>
                                        </a>
                                        <a href="{{ route('item.mark_purchased', $item) }}"
                                            class="text-green-600 hover:text-green-900 dark:text-green-400 dark:hover:text-green-600" wire:navigate>
                                            <x-custom-icon icon="cart-check"/>
                                        </a>
                                    @endif

                                    <!-- Delete -->
                                    <x-delete-button action="{{ route('item.destroy', $item) }}" />
                                </div>
                            </td>
                        </tr>
                    @endforeach
                </tbody>
            </table>
        </div>
    @endif
</x-app-layout>
<script>
    function setBulkButtons(){
        const bulkCheckbox = document.getElementById('general');
        const itemCheckboxes = document.querySelectorAll('input[type="checkbox"][id]:not(#general)');
        const actionButtons = document.querySelectorAll('.action-btn');

        const confirmMessages = {
            add_cart:       {!! json_encode(__('confirm_add_cart')) !!},
            remove_cart:    {!! json_encode(__('confirm_remove_cart')) !!},
            purchase:       {!! json_encode(__('confirm_purchase')) !!},
            delete:         {!! json_encode(__('confirm_delete')) !!}
        };

        function disableAllButtons() {
            actionButtons.forEach(btn => btn.classList.add('disabled-btn'));
        }

        function enableButton(action) {
            const btn = document.querySelector(`[data-action="${action}"]`);
            if (btn) btn.classList.remove('disabled-btn');
        }

        function getSelectedItems() {
            return Array.from(itemCheckboxes).filter(cb => cb.checked);
        }

        function getSelectedStatuses() {
            return getSelectedItems().map(cb => cb.dataset.status);
        }

        function updateActionButtons() {
            const selected = getSelectedItems();

            disableAllButtons();

            if (selected.length === 0) return;

            enableButton('delete');

            const statuses = getSelectedStatuses();
            const allSameStatus = statuses.every(s => s === statuses[0]);

            if (allSameStatus) {
                if (statuses[0] === 'to_buy' || statuses[0] === '1') {
                    enableButton('add_cart');
                }
                if (statuses[0] === 'in_cart' || statuses[0] === '2') {
                    enableButton('remove_cart');
                    enableButton('purchase');
                }
            }
        }

        bulkCheckbox.addEventListener('change', function () {
            const isChecked = this.checked;
            itemCheckboxes.forEach(cb => cb.checked = isChecked);
            updateActionButtons();
        });

        itemCheckboxes.forEach(cb => {
            cb.addEventListener('change', function () {
                const allChecked = Array.from(itemCheckboxes).every(c => c.checked);
                bulkCheckbox.checked = allChecked;
                updateActionButtons();
            });
        });

        // Confirmation dialogs
        actionButtons.forEach(btn => {
            btn.addEventListener('click', function (e) {
                if (this.classList.contains('disabled-btn')) {
                    e.preventDefault();
                    return;
                }
                const action = this.dataset.action;
                if (confirmMessages[action] && !confirm(confirmMessages[action])) {
                    e.preventDefault();
                }
            });
        });

        disableAllButtons();
    }

    document.addEventListener('DOMContentLoaded', setBulkButtons());

    if (window.Livewire) {
        Livewire.hook('message.processed', (message, component) => {
            bindCheckboxLogic();
        });
    }
</script>

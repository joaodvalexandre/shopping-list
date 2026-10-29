<x-app-layout>
    <div class="max-w-5xl mx-auto px-2 sm:px-4 pb-8">
        @if($lists->isEmpty())
            <p class="text-black dark:text-white text-center py-8">{{ __('dashboard_information') }}</p>
        @else
            <!-- Where the shopping stands -->
            <div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6" data-dashboard="totals">
                @foreach ([
                    ['key' => 'dashboard_lists', 'value' => $totals['lists'], 'color' => 'gray'],
                    ['key' => 'pending', 'value' => $totals['pending'], 'color' => 'amber'],
                    ['key' => 'in_cart', 'value' => $totals['in_cart'], 'color' => 'blue'],
                    ['key' => 'purchased', 'value' => $totals['purchased'], 'color' => 'green'],
                ] as $tile)
                    <div class="bg-white dark:bg-gray-800 rounded-lg shadow-md p-4 text-center">
                        <span class="block text-3xl font-bold text-{{ $tile['color'] }}-600 dark:text-{{ $tile['color'] }}-400">{{ $tile['value'] }}</span>
                        <span class="text-xs text-gray-500 dark:text-gray-400">{{ __($tile['key']) }}</span>
                    </div>
                @endforeach
            </div>

            <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
                <!-- In the cart -->
                <section class="bg-white dark:bg-gray-800 rounded-lg shadow-md p-5" data-dashboard="in-cart">
                    <h3 class="font-semibold text-lg text-gray-700 dark:text-gray-300 mb-3">{{ __('dashboard_in_cart') }}</h3>
                    @if($inCart->isEmpty())
                        <p class="text-sm text-gray-500 dark:text-gray-400">{{ __('dashboard_cart_empty') }}</p>
                    @else
                        <ul class="divide-y divide-gray-100 dark:divide-gray-700">
                            @foreach($inCart as $item)
                                <li class="py-2 flex items-center justify-between gap-3">
                                    <span class="text-gray-800 dark:text-gray-100">{{ $item->name }} <span class="text-gray-500 dark:text-gray-400">× {{ $item->quantity }}</span></span>
                                    <a href="{{ route('shopping_list.show', $item->shopping_list_id) }}" class="text-xs text-blue-600 dark:text-blue-400 hover:underline">{{ $item->shoppingList->name }}</a>
                                </li>
                            @endforeach
                        </ul>
                    @endif
                </section>

                <!-- Still to buy -->
                <section class="bg-white dark:bg-gray-800 rounded-lg shadow-md p-5" data-dashboard="to-buy">
                    <h3 class="font-semibold text-lg text-gray-700 dark:text-gray-300 mb-3">{{ __('dashboard_to_buy') }}</h3>
                    @if($toBuy->isEmpty())
                        <p class="text-sm text-gray-500 dark:text-gray-400">{{ __('dashboard_nothing_to_buy') }}</p>
                    @else
                        <ul class="divide-y divide-gray-100 dark:divide-gray-700">
                            @foreach($toBuy as $item)
                                <li class="py-2 flex items-center justify-between gap-3">
                                    <span class="text-gray-800 dark:text-gray-100">{{ $item->name }} <span class="text-gray-500 dark:text-gray-400">× {{ $item->quantity }}</span></span>
                                    <a href="{{ route('shopping_list.show', $item->shopping_list_id) }}" class="text-xs text-blue-600 dark:text-blue-400 hover:underline">{{ $item->shoppingList->name }}</a>
                                </li>
                            @endforeach
                        </ul>
                        @if($toBuyMore > 0)
                            <p class="mt-2 text-xs text-gray-500 dark:text-gray-400">{{ __('dashboard_more', ['count' => $toBuyMore]) }}</p>
                        @endif
                    @endif
                </section>
            </div>

            <!-- How far each list has got -->
            @if($progress->isNotEmpty())
                <section class="bg-white dark:bg-gray-800 rounded-lg shadow-md p-5 mt-4" data-dashboard="progress">
                    <h3 class="font-semibold text-lg text-gray-700 dark:text-gray-300 mb-3">{{ __('dashboard_progress') }}</h3>
                    <div class="space-y-3">
                        @foreach($progress as $list)
                            @php
                                $bought = round($list->purchased / $list->total * 100);
                                $carted = round($list->in_cart / $list->total * 100);
                            @endphp
                            <a href="{{ route('shopping_list.show', $list->id) }}" class="block group">
                                <div class="flex justify-between text-sm mb-1">
                                    <span class="text-gray-800 dark:text-gray-100 group-hover:underline">{{ $list->name }}</span>
                                    <span class="text-gray-500 dark:text-gray-400">{{ $list->purchased }}/{{ $list->total }}</span>
                                </div>
                                <div class="h-2 rounded-full bg-gray-200 dark:bg-gray-700 overflow-hidden flex">
                                    <div class="bg-green-500" style="width: {{ $bought }}%"></div>
                                    <div class="bg-blue-500" style="width: {{ $carted }}%"></div>
                                </div>
                            </a>
                        @endforeach
                    </div>
                </section>
            @endif
        @endif
    </div>
</x-app-layout>

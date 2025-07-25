@props([
    'type' => '',
    'model' => '',
    'data' => [],
])

<div class="w-full sm:w-1/2 md:w-1/2 lg:w-1/3 xl:w-1/4 p-2">
    <a href="{{ route($type.'.show', $data->id) }}"
       class="block h-full bg-white dark:bg-gray-800 rounded-lg shadow-md hover:shadow-xl transition-all duration-300 overflow-hidden relative group">

        @php
            $title = $data->name;
            $icon = $data->status['icon'];
            $color = $data->status['color'];
            $iconName = Str::startsWith($icon, 'mdi:') ? $icon : "mdi:{$icon}";

            // Assign colors for each stat
            $colors = [
                'pending'   => 'amber',   // Yellow for pending
                'in_cart'   => 'blue',    // Blue for in-cart
                'purchased' => 'green',   // Green for purchased
                'total'     => 'gray',    // Neutral for total
            ];
        @endphp

        <!-- Background Icon -->
        <div class="absolute top-8 right-0 opacity-15 group-hover:opacity-50 transition-all duration-300 ease-in-out">
            <i class="iconify text-{{ $color }}-600 dark:text-{{ $color }}-400 transform translate-x-1/4 group-hover:-translate-y-6 group-hover:translate-x-8 transition-transform duration-300" style="font-size: 200px;" data-icon="{{ $iconName }}"></i>
        </div>

        <div class="p-6 relative z-10">
            <!-- Title -->
            <h4 class="font-semibold text-lg text-gray-700 dark:text-gray-300 mb-6 group-hover:text-{{ $color }}-600 dark:group-hover:text-{{ $color }}-400 transition-colors duration-300">
                {{ __($title) }}
            </h4>

            @if($data->total == 0)
                <!-- Message when no items exist -->
                <div class="flex items-center justify-center h-24 text-center">
                    <p class="text-gray-500 dark:text-gray-400 text-sm font-medium">
                        {{ __('empty_list') }}
                    </p>
                </div>
            @else
                <!-- Stats Grid (2x2) -->
                <div class="grid grid-cols-2 gap-6 text-center">
                    <div>
                        <span class="block text-2xl font-bold text-{{ $colors['pending'] }}-600 dark:text-{{ $colors['pending'] }}-400">{{ $data->pending }}</span>
                        <span class="text-xs text-gray-500 dark:text-gray-400">{{ __('pending') }}</span>
                    </div>
                    <div>
                        <span class="block text-2xl font-bold text-{{ $colors['in_cart'] }}-600 dark:text-{{ $colors['in_cart'] }}-400">{{ $data->in_cart }}</span>
                        <span class="text-xs text-gray-500 dark:text-gray-400">{{ __('in_cart') }}</span>
                    </div>
                    <div>
                        <span class="block text-2xl font-bold text-{{ $colors['purchased'] }}-600 dark:text-{{ $colors['purchased'] }}-400">{{ $data->purchased }}</span>
                        <span class="text-xs text-gray-500 dark:text-gray-400">{{ __('purchased') }}</span>
                    </div>
                    <div>
                        <span class="block text-2xl font-bold text-{{ $colors['total'] }}-600 dark:text-{{ $colors['total'] }}-400">{{ $data->total }}</span>
                        <span class="text-xs text-gray-500 dark:text-gray-400">{{ __('total') }}</span>
                    </div>
                </div>
            @endif
        </div>

        <!-- Hover underline -->
        <div class="absolute bottom-0 left-0 w-full h-1 bg-{{ $color }}-500 dark:bg-{{ $color }}-600 transform scale-x-0 group-hover:scale-x-100 transition-transform duration-300 ease-out origin-left"></div>
    </a>
</div>

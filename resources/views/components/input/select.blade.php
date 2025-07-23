@props([
    'name',
    'label' => null,
    'items' => [],
    'selected' => null
])

<div class="w-full flex flex-col gap-1">
    @if($label)
        <label for="{{ $name }}" class="text-sm font-medium text-gray-700 dark:text-gray-300">
            {{ $label }}
        </label>
    @endif

    <select
        name="{{ $name }}"
        id="{{ $name }}"
        {{ $attributes->merge([
            'class' => 'w-full px-4 py-2 text-sm rounded-lg shadow-sm
                        border border-gray-300 bg-white text-gray-900
                        focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500
                        dark:bg-gray-800 dark:border-gray-600 dark:text-gray-100
                        dark:focus:ring-blue-500 dark:focus:border-blue-500'
        ]) }}
    >
        <option value="" disabled selected>{{ __('select_option') }}</option>
        @foreach($items as $item)
            <option value="{{ $item->id }}" @if($selected == $item->id) selected @endif>
                {{ __($item->name) }}
            </option>
        @endforeach
    </select>
</div>

@props([
    'name',
    'label' => null,
    'type' => 'text',      // text, number, email, etc.
    'value' => null,
    'placeholder' => '',
    'rows' => 4,           // for textarea only
])

<div class="w-full flex flex-col gap-1">
    @if($label)
        <label for="{{ $name }}" class="text-sm font-medium text-gray-700 dark:text-gray-300">
            {{ $label }}
        </label>
    @endif

    @if($type === 'textarea')
        <textarea
            name="{{ $name }}"
            id="{{ $name }}"
            rows="{{ $rows }}"
            placeholder="{{ $placeholder }}"
            {{ $attributes->merge([
                'class' => 'w-full px-4 py-2 text-sm rounded-lg shadow-sm border border-gray-300 bg-white text-gray-900
                            focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500
                            dark:bg-gray-800 dark:border-gray-600 dark:text-gray-100 dark:focus:ring-blue-500 dark:focus:border-blue-500'
            ]) }}
        >{{ old($name, $value) }}</textarea>
    @else
        <input
            type="{{ $type }}"
            name="{{ $name }}"
            id="{{ $name }}"
            value="{{ old($name, $value) }}"
            placeholder="{{ $placeholder }}"
            {{ $attributes->merge([
                'class' => 'w-full px-4 py-2 text-sm rounded-lg shadow-sm border border-gray-300 bg-white text-gray-900
                            focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500
                            dark:bg-gray-800 dark:border-gray-600 dark:text-gray-100 dark:focus:ring-blue-500 dark:focus:border-blue-500'
            ]) }}
        />
    @endif
</div>

@props([
    'name',
    'label' => null,
    'type' => 'text',       // text, number, email, etc.
    'value' => null,
    'placeholder' => '',
    'min' => '0',           // can only be used if it is number
    'max' => '100',         // can only be used if it is number
    'step' => '1',          // can only be used if it is number
    'rows' => 4,            // for textarea only
    'required' => false,
])

<div class="w-full flex flex-col gap-1">
    @if($label)
        <label for="{{ $name }}" class="text-sm font-medium text-gray-700 dark:text-gray-300">
            {{ __($label) }}
        </label>
    @endif

    @if($type === 'textarea')
        <textarea
            name="{{ $name }}"
            id="{{ $name }}"
            rows="{{ $rows }}"
            placeholder="{{ $placeholder }}"
            {{ $attributes->merge([
                'class' => 'w-full px-4 py-2 text-sm rounded-lg shadow-xs border border-gray-300 bg-white text-gray-900
                            focus:outline-hidden focus:ring-2 focus:ring-blue-500 focus:border-blue-500
                            dark:bg-gray-800 dark:border-gray-600 dark:text-gray-100 dark:focus:ring-blue-500 dark:focus:border-blue-500'
            ]) }}
        >{{ old($name, $value) }}</textarea>
    @else
        <input
            type="{{ $type }}"
            name="{{ $name }}"
            id="{{ $name }}"
            {{ ($type == 'number') ?  'min=' . $min . ' max=' . $max . ' step=' . $step : ''}}
            value="{{ old($name, $value) }}"
            placeholder="{{ $placeholder }}"
            {{ ($required) ? 'required' : '' }}
            {{ $attributes->merge([
                'class' => 'w-full px-4 py-2 text-sm rounded-lg shadow-xs border border-gray-300 bg-white text-gray-900
                            focus:outline-hidden focus:ring-2 focus:ring-blue-500 focus:border-blue-500
                            dark:bg-gray-800 dark:border-gray-600 dark:text-gray-100 dark:focus:ring-blue-500 dark:focus:border-blue-500'
            ]) }}
        />
    @endif
</div>

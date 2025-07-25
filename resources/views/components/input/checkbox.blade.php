@props([
    'name',
    'label' => null,
    'options' => [],       // array of ['value' => '', 'label' => '']
    'selected' => null,    // can be string or array
    'disabled' => false,
])

@php
    // Normalize selected into array for easier handling
    $selectedValues = is_array($selected) ? $selected : (isset($selected) ? [$selected] : []);
    $isMultiple = count($options) > 1; // multiple if more than one option
@endphp

<div class="w-full flex flex-col gap-2">
    @if($label)
        <span class="text-sm font-medium text-gray-700 dark:text-gray-300">{{ $label }}</span>
    @endif

    <fieldset class="flex flex-col gap-1">
        @foreach($options as $index => $option)
            @php
                $inputId = $name.'_'.$index;
                $isChecked = in_array($option['value'], $selectedValues);
            @endphp
            <label for="{{ $inputId }}" class="inline-flex items-center space-x-2 cursor-pointer text-gray-900 dark:text-gray-100">
                <input
                    type="checkbox"
                    id="{{ $inputId }}"
                    name="{{ $name }}{{ $isMultiple ? '[]' : '' }}"
                    value="{{ $option['value'] }}"
                    @checked($isChecked)
                    @disabled($disabled)
                    {{ $attributes->merge(['class' => 'form-checkbox h-4 w-4 text-blue-600']) }}
                />
                <span>{{ $option['label'] }}</span>
            </label>
        @endforeach
    </fieldset>
</div>

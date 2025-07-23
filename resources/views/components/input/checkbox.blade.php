@props([
    'name',
    'label' => null,
    'options' => [],       // array of ['value' => '', 'label' => '']
    'selected' => [],      // array of selected values or single value
])

@php
    $isMultiple = is_array($selected);
@endphp

<div class="w-full flex flex-col gap-2">
    @if($label)
        <span class="text-sm font-medium text-gray-700 dark:text-gray-300">{{ $label }}</span>
    @endif

    <div class="flex flex-col gap-1">
        @foreach($options as $option)
            <label class="inline-flex items-center space-x-2 cursor-pointer text-gray-900 dark:text-gray-100">
                <input
                    type="checkbox"
                    name="{{ $name }}{{ $isMultiple ? '[]' : '' }}"
                    value="{{ $option['value'] }}"
                    @if($isMultiple && in_array($option['value'], $selected)) checked @elseif(!$isMultiple && $selected == $option['value']) checked @endif
                    {{ $attributes->merge(['class' => 'form-checkbox h-4 w-4 text-blue-600']) }}
                />
                <span>{{ $option['label'] }}</span>
            </label>
        @endforeach
    </div>
</div>

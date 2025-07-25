@props([
    'name',
    'label' => null,
    'checked' => false,
    'disabled' => false,
])

@php
    $id = $attributes->get('id', $name);
@endphp

<label for="{{ $id }}" class="inline-flex items-center space-x-2 cursor-pointer text-gray-900 dark:text-gray-100">
    <input
        type="checkbox"
        id="{{ $id }}"
        name="{{ $name }}"
        value="1"
        @checked($checked)
        @disabled($disabled)
        {{ $attributes->merge(['class' => 'form-checkbox h-4 w-4 text-blue-600']) }}
    />
    @if($label)
        <span>{{ $label }}</span>
    @endif
</label>

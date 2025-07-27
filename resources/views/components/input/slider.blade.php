@props([
    'name',
    'label' => null,
    'min' => 0,
    'max' => 100,
    'step' => 1,
    'value' => null,
])

<div class="w-full flex flex-col gap-1">
    @if($label)
        <label for="{{ $name }}" class="text-sm font-medium text-gray-700 dark:text-gray-300">
            {{ __($label) }}
        </label>
    @endif

    <input
        type="range"
        name="{{ $name }}"
        id="{{ $name }}"
        min="{{ $min }}"
        max="{{ $max }}"
        step="{{ $step }}"
        value="{{ old($name, $value) }}"
        {{ $attributes->merge(['class' => 'w-full accent-blue-600 cursor-pointer']) }}
    />
</div>

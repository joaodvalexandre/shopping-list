@props([
    'name',
    'label' => null,
])

<div class="w-full flex flex-col gap-1">
    @if($label)
        <label for="{{ $name }}" class="text-sm font-medium text-gray-700 dark:text-gray-300">
            {{ $label }}
        </label>
    @endif

    <input
        type="file"
        name="{{ $name }}"
        id="{{ $name }}"
        {{ $attributes->merge([
            'class' => 'w-full text-sm text-gray-500
                        file:mr-4 file:py-2 file:px-4
                        file:rounded-full file:border-0
                        file:text-sm file:font-semibold
                        file:bg-blue-50 file:text-blue-700
                        hover:file:bg-blue-100
                        dark:text-gray-300 dark:file:bg-gray-700 dark:file:text-gray-300 dark:hover:file:bg-gray-600'
        ]) }}
    />
</div>

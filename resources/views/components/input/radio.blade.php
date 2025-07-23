@props([
    'name',
    'label' => null,
    'options' => [],      // array of ['value' => '', 'label' => '']
    'selected' => null,
])

<div class="w-full flex flex-col gap-2">
    @if($label)
        <span class="text-sm font-medium text-gray-700 dark:text-gray-300">{{ $label }}</span>
    @endif

    <div class="flex flex-col gap-1">
        @foreach($options as $option)
            <label class="inline-flex items-center space-x-2 cursor-pointer text-gray-900 dark:text-gray-100">
                <input
                    type="radio"
                    name="{{ $name }}"
                    value="{{ $option['value'] }}"
                    @if($selected == $option['value']) checked @endif
                    {{ $attributes->merge(['class' => 'form-radio h-4 w-4 text-blue-600']) }}
                />
                <span>{{ $option['label'] }}</span>
            </label>
        @endforeach
    </div>
</div>

@php
    $shoppingList = $shoppingList ?? null;
    $selectedType = old('list_type_id', $shoppingList?->list_type_id);
    $selectedHidden = old('hidden_from', $hidden ?? []);
@endphp

<div class="flex flex-col gap-3">
    <x-input.input name="name" label="name" type="text" :value="$shoppingList?->name" required />
    @error('name') <p class="text-sm text-red-600 dark:text-red-400">{{ $message }}</p> @enderror

    <div class="w-full flex flex-col gap-1">
        <label for="list_type_id" class="text-sm font-medium text-gray-700 dark:text-gray-300">{{ __('list_type') }}</label>
        <select name="list_type_id" id="list_type_id" required
                class="w-full px-4 py-2 text-sm rounded-lg shadow-xs border border-gray-300 bg-white text-gray-900 dark:bg-gray-800 dark:border-gray-600 dark:text-gray-100">
            @foreach($types as $type)
                <option value="{{ $type->id }}" @selected($selectedType == $type->id)>{{ $type->name }}</option>
            @endforeach
        </select>
        @error('list_type_id') <p class="text-sm text-red-600 dark:text-red-400">{{ $message }}</p> @enderror
    </div>

    @if($members->isNotEmpty())
        <fieldset class="flex flex-col gap-1">
            <legend class="text-sm font-medium text-gray-700 dark:text-gray-300">{{ __('hidden_from') }}</legend>
            <p class="text-xs text-gray-500 dark:text-gray-400">{{ __('hidden_from_help') }}</p>
            @foreach($members as $member)
                <label class="inline-flex items-center gap-2 text-gray-900 dark:text-gray-100">
                    <input type="checkbox" name="hidden_from[]" value="{{ $member->id }}" class="h-4 w-4 rounded"
                           @checked(in_array($member->id, $selectedHidden))>
                    {{ $member->name }}
                </label>
            @endforeach
        </fieldset>
    @endif
</div>

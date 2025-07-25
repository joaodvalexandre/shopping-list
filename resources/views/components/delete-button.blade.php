@props([
    'action',        // URL for the form action
    'confirmMessage' => __('confirm_delete_single'),
    'class' => 'text-red-600 hover:text-red-900 dark:text-red-400 dark:hover:text-red-600',
    'icon' => 'trash',
    'size' => '24',
])

<form method="POST" action="{{ $action }}" onsubmit="return confirm('{{ $confirmMessage }}')" class="inline">
    @csrf
    @method('DELETE')
    <button type="submit" class="{{ $class }}" aria-label="{{ __('delete') }}">
        <x-custom-icon :icon="$icon" size="{{ $size }}" />
    </button>
</form>

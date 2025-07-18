@props(['id', 'name', 'value', 'min'])

<div
    x-data="{ picker: null }"
    x-init="
        picker = flatpickr($refs.input, {
            enableTime: true,
            dateFormat: 'Y-m-d H:i:S',
            time_24hr: true,
            defaultDate: new Date(),
            minDate: '{{ $min ?? '' }}',
            onChange: (selectedDates, dateStr) => {
                $dispatch('input', dateStr);
            },
            onReady: (selectedDates, dateStr, instance) => {
                instance.calendarContainer.classList.add('flatpickr-theme-dark');
            }
        });
    "
    class="relative"
>
    <input
        x-ref="input"
        type="text"
        {{ $attributes->merge(['class' => 'mt-1 block w-full pl-10 pr-10 py-2 border-gray-300 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-300 focus:border-indigo-500 dark:focus:border-indigo-600 focus:ring-indigo-500 dark:focus:ring-indigo-600 rounded-md shadow-sm']) }}
    >
    <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
        <svg class="h-5 w-5 text-gray-400 dark:text-gray-500" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
            <path fill-rule="evenodd" d="M6 2a1 1 0 00-1 1v1H4a2 2 0 00-2 2v10a2 2 0 002 2h12a2 2 0 002-2V6a2 2 0 00-2-2h-1V3a1 1 0 10-2 0v1H7V3a1 1 0 00-1-1zm0 5a1 1 0 000 2h8a1 1 0 100-2H6z" clip-rule="evenodd" />
        </svg>
    </div>
</div>

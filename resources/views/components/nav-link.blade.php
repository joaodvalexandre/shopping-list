@props(['active'])

@php
$classes = ($active ?? false)
            ? 'block px-4 py-2 text-sm leading-5 text-gray-900 dark:text-white bg-gray-200 dark:bg-gray-700 rounded-md focus:outline-hidden transition duration-150 dark:hover:bg-gray-600 hover:bg-gray-300 ease-in-out'
            : 'block px-4 py-2 text-sm leading-5 text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-800 hover:text-gray-900 dark:hover:text-white hover:bg-gray-100 dark:hover:bg-gray-600 rounded-md focus:outline-hidden focus:bg-gray-100 dark:focus:bg-gray-600 transition duration-150 ease-in-out';
@endphp

<a {{ $attributes->merge(['class' => $classes]) }}>
    {{ $slot }}
</a>

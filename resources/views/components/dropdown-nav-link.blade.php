@props(['active'])

@php
$classes = ($active ?? false)
            ? 'mx-2 my-1 block px-4 py-2 text-left text-sm leading-5 text-gray-900 dark:text-white bg-gray-100 dark:bg-gray-600 rounded-md hover:bg-gray-200 dark:hover:bg-gray-500 focus:outline-none focus:bg-gray-200 dark:focus:bg-gray-800 transition duration-150 ease-in-out'
            : 'mx-2 my-1 block px-4 py-2 text-left text-sm leading-5 text-gray-700 dark:text-gray-300 rounded-md hover:bg-gray-100 hover:text-gray-900 dark:hover:bg-gray-600 dark:hover:text-white focus:outline-none focus:bg-gray-100 dark:focus:bg-gray-700 transition duration-150 ease-in-out';
@endphp

<a {{ $attributes->merge(['class' => $classes]) }}>
    {{ $slot }}
</a>

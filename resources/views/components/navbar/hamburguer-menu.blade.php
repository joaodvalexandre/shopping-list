<button
    @click="open = !open; shoppingMenuOpen = false"
    class="inline-flex items-center justify-center p-2 rounded-md text-gray-400 dark:text-gray-500 hover:text-gray-500 dark:hover:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-900 focus:outline-hidden focus:bg-gray-100 dark:focus:bg-gray-900 focus:text-gray-500 dark:focus:text-gray-400 transition duration-150 ease-in-out"
>
    <svg
        class="h-6 w-6 transition-transform duration-300 ease-in-out"
        :class="{'rotate-90': open}"
        stroke="currentColor"
        fill="none"
        viewBox="0 0 24 24"
    >
        <path
            class="transition-opacity duration-300 ease-in-out origin-center"
            :class="{'opacity-0 scale-80': open, 'opacity-100 scale-100': !open}"
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M4 6h16M4 12h16M4 18h16"
        />
        <path
            class="transition-opacity duration-300 ease-in-out origin-center"
            :class="{'opacity-100 scale-100': open, 'opacity-0 scale-80': !open}"
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M6 18L18 6M6 6l12 12"
        />
    </svg>
</button>

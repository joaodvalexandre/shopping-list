<div x-data="{ darkMode: localStorage.getItem('theme') === 'dark' }"
    x-init="
        darkMode = localStorage.getItem('theme') === 'dark';
        if (darkMode) document.documentElement.classList.add('dark');
        else document.documentElement.classList.remove('dark');
    "
    class="flex items-center justify-center p-4 ml-auto">
    <!-- Toggle Container -->
    <button
        @click="
            darkMode = !darkMode;
            if (darkMode) {
                document.documentElement.classList.add('dark');
                localStorage.setItem('theme', 'dark');
            } else {
                document.documentElement.classList.remove('dark');
                localStorage.setItem('theme', 'light');
            }
        "
        class="relative flex items-center w-16 h-8 rounded-full bg-gray-300 dark:bg-gray-600 transition-all duration-300 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
        <!-- Slider with Icon -->
        <span
            :class="{ 'translate-x-8': darkMode, 'translate-x-0': !darkMode }"
            class="absolute left-1 top-1 flex items-center justify-center w-6 h-6 bg-white rounded-full transform transition-transform duration-300 text-neutral-800 dark:text-neutral-200">
            <span x-show="!darkMode">
                <x-sun class="w-6 h-6 text-neutral-800 dark:text-neutral-200" />
            </span>
            <span x-show="darkMode">
                <x-moon class="w-6 h-6 text-neutral-800 dark:text-neutral-200" />
            </span>
        </span>
    </button>
</div>

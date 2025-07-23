<x-app-layout>
    <h1 class="p-6 text-2xl text-gray-900 dark:text-gray-100">Test</h1>
    <div class="p-6 text-gray-900 dark:text-gray-100">
        <p>Dashboard Component</p>
        <button
            onclick="notificationToggle('test_message', 'success')"
            class="text-lg font-semibold bg-green-400 text-black hover:bg-green-600 hover:text-white transition-all duration-300 ease-in-out px-6 py-2 rounded-lg">
            Trigger Success
        </button>
        <button
            onclick="notificationToggle('test_message', 'error')"
            class="text-lg font-semibold bg-red-400 text-black hover:bg-red-600 hover:text-white transition-all duration-300 ease-in-out px-6 py-2 rounded-lg">
            Trigger Failure
        </button>
        <button
            onclick="notificationToggle('test_message', 'info')"
            class="text-lg font-semibold bg-blue-400 text-black hover:bg-blue-600 hover:text-white transition-all duration-300 ease-in-out px-6 py-2 rounded-lg">
            Trigger Info
        </button>
        <button
            onclick="notificationToggle('test_message', 'warning')"
            class="text-lg font-semibold bg-yellow-400 text-black hover:bg-yellow-600 hover:text-white transition-all duration-300 ease-in-out px-6 py-2 rounded-lg">
            Trigger Warning
        </button>
    </div>
    <div class="p-6 text-gray-900 dark:text-gray-100">
        <p>Livewire Component</p>
        <livewire:dashboard-buttons />
    </div>
</x-app-layout>

<div>
    <button
        wire:click="notificationToggle('test_message', 'success')"
        class="text-lg font-semibold bg-green-400 text-black hover:bg-green-600 hover:text-white transition-all duration-300 ease-in-out px-6 py-2 rounded-lg">
        Trigger Success
    </button>

    <button
        wire:click="notificationToggle('test_message', 'error')"
        class="text-lg font-semibold bg-red-400 text-black hover:bg-red-600 hover:text-white transition-all duration-300 ease-in-out px-6 py-2 rounded-lg">
        Trigger Failure
    </button>

    <button
        wire:click="notificationToggle('test_message', 'info')"
        class="text-lg font-semibold bg-blue-400 text-black hover:bg-blue-600 hover:text-white transition-all duration-300 ease-in-out px-6 py-2 rounded-lg">
        Trigger Info
    </button>

    <button
        wire:click="notificationToggle('test_message', 'warning')"
        class="text-lg font-semibold bg-yellow-400 text-black hover:bg-yellow-600 hover:text-white transition-all duration-300 ease-in-out px-6 py-2 rounded-lg">
        Trigger Warning
    </button>
</div>

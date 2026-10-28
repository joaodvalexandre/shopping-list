<div>
    <div id="notification-container" class="fixed top-0 right-0 flex flex-col items-end justify-start px-4 py-6 pointer-events-none sm:p-6 z-50">
        @foreach($notifications as $notification)
            <div
                x-data="{ show: false, progress: 0, timer: null, increment: 0 }"
                x-init="
                    $nextTick(() => {
                        show = true;
                        setTimeout(() => {
                            const animationDuration = 300; // ms
                            const interval = 10; // ms
                            const steps = ({{ $notification['duration'] }} - animationDuration) / interval;
                            increment = 100 / steps;
                            timer = setInterval(() => {
                                progress += increment;
                                if (progress >= 100) {
                                    clearInterval(timer);
                                    show = false;
                                }
                            }, interval);
                        }, 50);
                    });
                "
                @mouseenter="clearInterval(timer)"
                @mouseleave="
                    timer = setInterval(() => {
                        progress += increment;
                        if (progress >= 100) {
                            clearInterval(timer);
                            show = false;
                        }
                    }, 10);
                "
                x-show="show"
                x-transition:enter="transform ease-out duration-300 transition"
                x-transition:enter-start="translate-y-2 opacity-0 sm:translate-y-0 sm:translate-x-2"
                x-transition:enter-end="translate-y-0 opacity-100 sm:translate-x-0"
                x-transition:leave="transition ease-in duration-100"
                x-transition:leave-start="opacity-100"
                x-transition:leave-end="opacity-0"
                @click="show = false; $wire.removeNotification('{{ $notification['id'] }}')"
                class="w-[30vw] shadow-lg rounded-lg pointer-events-auto ring-1 ring-black ring-opacity-5 overflow-hidden mb-3 cursor-pointer relative transition-all duration-300 ease-in-out"
                :class="{
                    'bg-green-500 hover:bg-green-600 active:bg-green-700': '{{ $notification['type'] }}' === 'success',
                    'bg-red-500 hover:bg-red-600 active:bg-red-700': '{{ $notification['type'] }}' === 'error',
                    'bg-yellow-500 hover:bg-yellow-600 active:bg-yellow-700': '{{ $notification['type'] }}' === 'warning',
                    'bg-blue-500 hover:bg-blue-600 active:bg-blue-700': '{{ $notification['type'] }}' === 'info'
                }"
            >
                <div class="p-4">
                    <div class="flex items-start">
                        <div class="shrink-0">
                            <!-- Icon based on notification type -->
                            @if($notification['type'] === 'success')
                                <svg class="h-6 w-6 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                                </svg>
                            @elseif($notification['type'] === 'error')
                                <svg class="h-6 w-6 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                                </svg>
                            @elseif($notification['type'] === 'warning')
                                <svg class="h-6 w-6 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                                </svg>
                            @else
                                <svg class="h-6 w-6 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                                </svg>
                            @endif
                        </div>
                        <div class="ml-3 w-0 flex-1 pt-0.5">
                            <p class="text-sm font-medium text-white">
                                {{ $notification['message'] }}
                            </p>
                        </div>
                    </div>
                </div>
                <div class="absolute bottom-0 left-0 w-full h-1 bg-white bg-opacity-30">
                    <div class="h-full bg-white transition-all duration-100 ease-out" :style="{ width: `${progress}%` }"></div>
                </div>
            </div>
        @endforeach
    </div>
</div>

<script>
    document.addEventListener('livewire:load', function () {
        Livewire.on('new-notification', () => {
            const container = document.getElementById('notification-container');
            container.lastElementChild.scrollIntoView({ behavior: 'smooth', block: 'start' });
        });
    });
</script>

<?php

namespace App\Livewire\Layout;

use Livewire\Component;
use Illuminate\Support\Facades\Queue;

class NotificationComponent extends Component
{
    public $notifications = [];

    protected $listeners = ['showNotification', 'removeNotification'];

    public function showNotification($message, $type = 'info', $duration = 5000)
    {
        $id = uniqid();
        $this->notifications[] = [
            'id' => $id,
            'message' => __($message),
            'type' => $type,
            'duration' => $duration,
        ];

        $this->dispatch('new-notification');

        // Schedule removal of the notification using a job
        Queue::later($duration / 1000, function () use ($id) {
            $this->removeNotification($id);
        });
    }

    public function removeNotification($id)
    {
        $this->notifications = array_filter($this->notifications, function ($notification) use ($id) {
            return $notification['id'] !== $id;
        });
    }

    public function render()
    {
        return view('livewire.layout.notification-component');
    }
}

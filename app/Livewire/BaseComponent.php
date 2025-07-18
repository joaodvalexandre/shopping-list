<?php

namespace App\Livewire;

use Livewire\Component;

abstract class BaseComponent extends Component
{
    public function notificationToggle($message, $type = 'info')
    {
        $this->dispatch('showNotification', message: $message, type: $type);
    }
}

<?php

namespace App\Events;

use Illuminate\Broadcasting\Channel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Queue\SerializesModels;
use Illuminate\Broadcasting\InteractsWithSockets;

class ModelChanged implements ShouldBroadcast
{
    use InteractsWithSockets, SerializesModels;

    public string $model;
    public string $action;
    public array $data;

    public function __construct(string $model, string $action, array $data)
    {
        $this->model = $model;
        $this->action = $action;
        $this->data = $data;

        $this->dontBroadcastToCurrentUser();
    }

    public function broadcastOn(): Channel
    {
        return new Channel('models');
    }
}

<?php

namespace App\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Queue\SerializesModels;

/**
 * Tells open browsers of ONE family that a list or item changed.
 *
 * It travels on a private channel (authorised in routes/channels.php) and
 * carries only identifiers - never names, quantities or any other content -
 * so the realtime channel cannot leak data. The browser simply reloads.
 */
class ModelChanged implements ShouldBroadcast
{
    use InteractsWithSockets, SerializesModels;

    public function __construct(
        public string $model,
        public string $action,
        public int $id,
        public int $familyId,
    ) {
        $this->dontBroadcastToCurrentUser();
    }

    public function broadcastOn(): PrivateChannel
    {
        return new PrivateChannel('family.' . $this->familyId);
    }

    public function broadcastWith(): array
    {
        return ['model' => $this->model, 'action' => $this->action, 'id' => $this->id];
    }
}

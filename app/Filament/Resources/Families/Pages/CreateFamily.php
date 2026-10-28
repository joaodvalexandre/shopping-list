<?php

namespace App\Filament\Resources\Families\Pages;

use App\Filament\Resources\Families\FamilyResource;
use App\Filament\Support\MemberActions;
use App\Services\FamilyProvisioner;
use Filament\Notifications\Notification;
use Filament\Resources\Pages\CreateRecord;
use Illuminate\Database\Eloquent\Model;

class CreateFamily extends CreateRecord
{
    protected static string $resource = FamilyResource::class;

    /**
     * A family is created together with its first admin and a default list
     * type, exactly like `php artisan family:create`.
     */
    protected function handleRecordCreation(array $data): Model
    {
        $result = app(FamilyProvisioner::class)->create($data['name'], $data['admin_name'], $data['admin_email']);

        // The one and only time the temporary password is visible
        MemberActions::showTemporaryPassword($result['admin']->email, $result['password']);

        return $result['family'];
    }

    protected function getCreatedNotification(): ?Notification
    {
        return null; // the temporary-password notice replaces the generic "created" toast
    }
}

<?php

namespace App\Filament\Resources\Users\Pages;

use App\Filament\Resources\Users\UserResource;
use App\Filament\Support\MemberActions;
use App\Models\Family;
use App\Models\User;
use App\Support\TemporaryPassword;
use Filament\Notifications\Notification;
use Filament\Resources\Pages\CreateRecord;
use Illuminate\Database\Eloquent\Model;

class CreateUser extends CreateRecord
{
    protected static string $resource = UserResource::class;

    /** Members are created with a temporary password they must change on first login. */
    protected function handleRecordCreation(array $data): Model
    {
        $temporary = TemporaryPassword::for(Family::findOrFail($data['family_id']));

        $member = User::create($data + [
            'password' => $temporary,
            'must_change_password' => true,
        ]);

        MemberActions::showTemporaryPassword($member->email, $temporary);

        return $member;
    }

    protected function getCreatedNotification(): ?Notification
    {
        return null;
    }
}

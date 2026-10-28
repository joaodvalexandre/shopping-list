<?php

namespace App\Filament\Resources\Users\Pages;

use App\Enums\FamilyRole;
use App\Filament\Resources\Users\UserResource;
use App\Filament\Support\MemberActions;
use Filament\Actions\ActionGroup;
use Filament\Notifications\Notification;
use Filament\Resources\Pages\EditRecord;

class EditUser extends EditRecord
{
    protected static string $resource = UserResource::class;

    protected function getHeaderActions(): array
    {
        return [
            ActionGroup::make([
                MemberActions::resetPassword(),
                MemberActions::signOutEverywhere(),
                MemberActions::delete(),
            ]),
        ];
    }

    /** A family must keep at least one admin. */
    protected function beforeSave(): void
    {
        $newRole = $this->data['role'] ?? null;

        if ($newRole !== FamilyRole::Admin->value && $this->getRecord()->isLastFamilyAdmin()) {
            Notification::make()->danger()->title(__('last_admin_error'))->send();

            $this->halt();
        }
    }
}

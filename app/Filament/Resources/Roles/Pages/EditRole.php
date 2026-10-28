<?php

namespace App\Filament\Resources\Roles\Pages;

use App\Filament\Resources\Roles\Pages\Concerns\SavesPermissionGrants;
use App\Filament\Resources\Roles\RoleResource;
use Filament\Resources\Pages\EditRecord;

class EditRole extends EditRecord
{
    use SavesPermissionGrants;

    protected static string $resource = RoleResource::class;

    protected function mutateFormDataBeforeFill(array $data): array
    {
        return $this->loadGrants($data);
    }

    protected function mutateFormDataBeforeSave(array $data): array
    {
        return $this->rememberGrants($data);
    }

    protected function afterSave(): void
    {
        $this->saveGrants();
    }
}

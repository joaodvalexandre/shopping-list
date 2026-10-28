<?php

namespace App\Filament\Resources\Roles\Pages\Concerns;

use App\Models\Permission;
use App\Models\Role;

/**
 * The role form shows permissions as one checkbox list per area ("grants.pages",
 * "grants.families"...). This turns those lists into the role's permissions
 * and back.
 *
 * @property Role $record
 */
trait SavesPermissionGrants
{
    /** @var list<int> */
    private array $grantedPermissionIds = [];

    protected function rememberGrants(array $data): array
    {
        $this->grantedPermissionIds = collect($data['grants'] ?? [])->flatten()->map(fn ($id) => (int) $id)->all();

        unset($data['grants']);

        return $data;
    }

    protected function saveGrants(): void
    {
        // The super administrator always has everything; its boxes are read-only
        if (! $this->record->isSuperAdmin()) {
            $this->record->permissions()->sync($this->grantedPermissionIds);
        }
    }

    protected function loadGrants(array $data): array
    {
        // Everything shows ticked for the super administrator
        $granted = $this->record->isSuperAdmin() ? Permission::all() : $this->record->permissions;

        $data['grants'] = $granted
            ->groupBy(fn (Permission $permission) => $permission->group())
            ->map(fn ($permissions) => $permissions->pluck('id')->map(fn ($id) => (string) $id)->all())
            ->all();

        return $data;
    }
}

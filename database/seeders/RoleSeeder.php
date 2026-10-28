<?php

namespace Database\Seeders;

use App\Models\Permission;
use App\Models\Role;
use App\Support\Backoffice\PermissionCatalog;
use Illuminate\Database\Seeder;

/**
 * The roles that ship with the app. Safe to run again: a role that already exists
 * keeps whatever was ticked on it in the backoffice, except the super
 * administrator, which always gets every permission (including new ones).
 */
class RoleSeeder extends Seeder
{
    public function run(): void
    {
        $this->call(PermissionSeeder::class);

        $permissions = Permission::pluck('id', 'name');

        foreach (PermissionCatalog::roles() as $name => $granted) {
            $role = Role::firstOrCreate(['name' => $name], ['is_system' => true]);

            if ($role->wasRecentlyCreated || $role->isSuperAdmin()) {
                $role->permissions()->sync($permissions->only($granted)->values());
            }
        }
    }
}

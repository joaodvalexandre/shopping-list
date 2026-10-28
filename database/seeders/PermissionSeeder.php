<?php

namespace Database\Seeders;

use App\Models\Permission;
use App\Support\Backoffice\PermissionCatalog;
use Illuminate\Database\Seeder;

/** Every permission the backoffice checks. Safe to run again: it only adds what is missing. */
class PermissionSeeder extends Seeder
{
    public function run(): void
    {
        foreach (PermissionCatalog::names() as $name) {
            Permission::firstOrCreate(['name' => $name], ['is_system' => true]);
        }
    }
}

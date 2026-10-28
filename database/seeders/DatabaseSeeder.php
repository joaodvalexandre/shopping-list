<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     *
     * Only reference data lives here. Families and their admins are created
     * with `php artisan family:create` (or the backoffice).
     */
    public function run(): void
    {
        $this->call([
            StatusSeeder::class,
        ]);
    }
}

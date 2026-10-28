<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     *
     * Only reference data lives here. Families are created from the
     * backoffice (or `php artisan family:create`), and the first backoffice
     * administrator with `php artisan admin:create`. Every seeder can be run
     * again safely.
     */
    public function run(): void
    {
        $this->call([
            StatusSeeder::class,
            LanguageSeeder::class,
            PermissionSeeder::class,
            RoleSeeder::class,
            TranslationSeeder::class,   // after the languages: one row per text and language
            PageSeeder::class,
        ]);
    }
}

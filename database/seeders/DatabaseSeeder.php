<?php

namespace Database\Seeders;

use App\Support\Translations\TranslationRepository;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     *
     * Only reference data lives here. Families are created from the
     * backoffice (or `php artisan family:create`), and the first backoffice
     * administrator with `php artisan admin:create`.
     */
    public function run(): void
    {
        $this->call([
            StatusSeeder::class,
            LanguageSeeder::class,
        ]);

        // One editable row per text and language (the texts themselves ship in resources/lang)
        TranslationRepository::sync();
    }
}

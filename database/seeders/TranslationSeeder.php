<?php

namespace Database\Seeders;

use App\Support\Translations\TranslationRepository;
use Illuminate\Database\Seeder;

/**
 * One editable row per text and language. The texts themselves ship in
 * resources/lang/*.json; this only makes sure each has a row for the
 * backoffice to edit. Existing rows (and what was typed in them) are untouched.
 */
class TranslationSeeder extends Seeder
{
    public function run(): void
    {
        TranslationRepository::sync();
    }
}

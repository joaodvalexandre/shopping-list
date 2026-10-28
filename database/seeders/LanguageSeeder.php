<?php

namespace Database\Seeders;

use App\Models\Language;
use Illuminate\Database\Seeder;

class LanguageSeeder extends Seeder
{
    /**
     * The two languages the app ships with. Safe to re-run: existing rows
     * (and any change made in the backoffice) are left alone.
     */
    public function run(): void
    {
        $languages = [
            ['code' => 'pt', 'name' => 'Portuguese', 'native_name' => 'Português', 'flag' => 'language-pt', 'is_default' => true, 'sort' => 1],
            ['code' => 'en', 'name' => 'English', 'native_name' => 'English', 'flag' => 'language-en', 'is_default' => false, 'sort' => 2],
        ];

        foreach ($languages as $language) {
            Language::firstOrCreate(['code' => $language['code']], $language + ['is_active' => true]);
        }
    }
}

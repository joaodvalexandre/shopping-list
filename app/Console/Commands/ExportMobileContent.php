<?php

namespace App\Console\Commands;

use App\Support\Mobile\MobileContent;
use Illuminate\Console\Command;

/**
 * Writes the content a fresh install of the phone app starts with, so About, Privacy,
 * Terms and every text are there before the first connection.
 */
class ExportMobileContent extends Command
{
    protected $signature = 'mobile:export-content {--path= : Where to write it (default: the app\'s assets)}';

    protected $description = 'Write the texts, pages and menus the phone app ships with';

    public function handle(): int
    {
        $path = $this->option('path') ?: base_path('mobile/shopping_list/assets/content.json');

        file_put_contents($path, json_encode(MobileContent::build(), JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) . "\n");

        $this->info("Wrote {$path}");

        return self::SUCCESS;
    }
}

<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class StatusSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $statuses = [
            ['code' => 'to_buy',      'color' => '#FFA500'], // Orange
            ['code' => 'in_cart',     'color' => '#1E90FF'], // Dodger Blue
            ['code' => 'purchased',   'color' => '#4CAF50'], // Green
        ];

        // Safe to run again: only the missing ones are added (ids 1, 2, 3 are hard-coded elsewhere)
        foreach ($statuses as $status) {
            if (! DB::table('status')->where('code', $status['code'])->exists()) {
                DB::table('status')->insert($status);
            }
        }
    }
}

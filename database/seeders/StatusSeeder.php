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

        foreach ($statuses as $status) {
            DB::table('status')->insert($status);
        }
    }
}

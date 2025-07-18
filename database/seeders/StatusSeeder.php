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
            ['status' => 'To Buy',      'code' => 'to_buy',      'color' => '#FFA500'], // Orange
            ['status' => 'In Cart',     'code' => 'in_cart',     'color' => '#1E90FF'], // Dodger Blue
            ['status' => 'Purchased',   'code' => 'purchased',   'color' => '#4CAF50'], // Green
            ['status' => 'Out of Stock','code' => 'out_of_stock','color' => '#FF0000'], // Red
            ['status' => 'On Hold',     'code' => 'on_hold',     'color' => '#FFC107'], // Amber
            ['status' => 'Cancelled',   'code' => 'cancelled',   'color' => '#9E9E9E'], // Grey
            ['status' => 'Favorite',    'code' => 'favorite',    'color' => '#FF69B4'], // Hot Pink
            ['status' => 'On Sale',     'code' => 'on_sale',     'color' => '#8A2BE2'], // Blue Violet
        ];

        foreach ($statuses as $status) {
            DB::table('status')->insert($status);
        }
    }
}

<?php

namespace Database\Factories;

use App\Models\Item;
use App\Models\ShoppingList;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Item>
 */
class ItemFactory extends Factory
{
    public function definition(): array
    {
        return [
            'shopping_list_id' => ShoppingList::factory(),
            'name' => fake()->word(),
            'quantity' => fake()->numberBetween(1, 5),
            'status_id' => 1,
        ];
    }
}

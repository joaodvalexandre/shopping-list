<?php

namespace Database\Factories;

use App\Models\ListType;
use App\Models\ShoppingList;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<ShoppingList>
 */
class ShoppingListFactory extends Factory
{
    public function definition(): array
    {
        return [
            'name' => fake()->words(2, true),
            'list_type_id' => ListType::factory(),
            // Keep the list in the same family as its type
            'family_id' => fn (array $attributes) => ListType::find($attributes['list_type_id'])->family_id,
        ];
    }
}

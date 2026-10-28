<?php

namespace Database\Factories;

use App\Models\Family;
use App\Models\ListType;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<ListType>
 */
class ListTypeFactory extends Factory
{
    public function definition(): array
    {
        return [
            'family_id' => Family::factory(),
            'name' => fake()->unique()->word(),
        ];
    }
}

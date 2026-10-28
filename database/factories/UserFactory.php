<?php

namespace Database\Factories;

use App\Enums\FamilyRole;
use App\Models\Family;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<User>
 */
class UserFactory extends Factory
{
    public function definition(): array
    {
        return [
            'family_id' => Family::factory(),
            'name' => fake()->name(),
            'email' => fake()->unique()->safeEmail(),
            'email_verified_at' => now(),
            'password' => 'password',
            'role' => FamilyRole::Member,
            'must_change_password' => false,
            'remember_token' => str()->random(10),
        ];
    }

    public function admin(): static
    {
        return $this->state(['role' => FamilyRole::Admin]);
    }

    public function mustChangePassword(): static
    {
        return $this->state(['must_change_password' => true]);
    }
}

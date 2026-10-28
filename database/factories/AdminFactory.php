<?php

namespace Database\Factories;

use App\Models\Admin;
use App\Models\Role;
use Database\Seeders\RoleSeeder;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Admin>
 */
class AdminFactory extends Factory
{
    public function definition(): array
    {
        return [
            'name' => fake()->name(),
            'email' => fake()->unique()->safeEmail(),
            'password' => 'password',
        ];
    }

    /** Holds the super administrator role: allowed to do everything. */
    public function superAdmin(): static
    {
        return $this->withRole(Role::SUPER_ADMIN);
    }

    /** Holds one of the shipped roles (e.g. "content-editor"). */
    public function withRole(string $name): static
    {
        return $this->afterCreating(function (Admin $admin) use ($name) {
            (new RoleSeeder)->run();

            $admin->roles()->attach(Role::where('name', $name)->value('id'));
            $admin->unsetRelation('roles');
        });
    }
}

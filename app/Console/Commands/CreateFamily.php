<?php

namespace App\Console\Commands;

use App\Services\FamilyProvisioner;
use Illuminate\Console\Command;

class CreateFamily extends Command
{
    protected $signature = 'family:create
        {name : Family name}
        {admin_name : Name of the family\'s first admin}
        {admin_email : Email the admin logs in with}';

    protected $description = 'Create a family and its first admin account (prints a one-time temporary password)';

    public function handle(FamilyProvisioner $provisioner): int
    {
        if (\App\Models\User::where('email', $this->argument('admin_email'))->exists()) {
            $this->error('A user with that email already exists.');

            return self::FAILURE;
        }

        $result = $provisioner->create(
            $this->argument('name'),
            $this->argument('admin_name'),
            $this->argument('admin_email'),
        );

        $this->info("Family \"{$result['family']->name}\" created.");
        $this->line("Admin:              {$result['admin']->email}");
        $this->line("Temporary password: {$result['password']}  (must be changed on first login)");

        return self::SUCCESS;
    }
}

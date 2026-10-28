<?php

namespace App\Console\Commands;

use App\Models\Admin;
use App\Models\Role;
use Database\Seeders\RoleSeeder;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Validator;

use function Laravel\Prompts\password;
use function Laravel\Prompts\text;

class CreateAdmin extends Command
{
    protected $signature = 'admin:create
        {name? : Name of the administrator}
        {email? : Email used to sign in to the backoffice}
        {--password= : Password (min 12 characters); asked for when omitted}';

    protected $description = 'Create a backoffice administrator (needed once, to sign in to /admin the first time)';

    public function handle(): int
    {
        $name = $this->argument('name') ?? text('Name', required: true);
        $email = $this->argument('email') ?? text('Email', required: true);
        $password = $this->option('password') ?? password('Password (min 12 characters)', required: true);

        $validator = Validator::make(
            ['name' => $name, 'email' => $email, 'password' => $password],
            [
                'name' => 'required|string|max:255',
                'email' => 'required|email|max:255|unique:admins,email',
                'password' => 'required|string|min:12',
            ],
        );

        if ($validator->fails()) {
            foreach ($validator->errors()->all() as $error) {
                $this->error($error);
            }

            return self::FAILURE;
        }

        // The roles ship as seed data; make sure they exist before using one
        $this->callSilently('db:seed', ['--class' => RoleSeeder::class, '--force' => true]);

        $admin = Admin::create(['name' => $name, 'email' => $email, 'password' => $password]);
        $admin->roles()->attach(Role::where('name', Role::SUPER_ADMIN)->value('id'));

        $this->info("Super administrator {$email} created. Sign in at " . url('/admin'));

        return self::SUCCESS;
    }
}

<?php

namespace App\Services;

use App\Enums\FamilyRole;
use App\Models\Family;
use App\Models\User;
use App\Support\TemporaryPassword;
use Illuminate\Support\Facades\DB;

/**
 * The app admin creates families; this is the single place that does it
 * (used by the artisan command now, and by the backoffice later).
 */
class FamilyProvisioner
{
    /**
     * Create a family with its first admin and a default list type.
     *
     * @return array{family: Family, admin: User, password: string}
     */
    public function create(string $familyName, string $adminName, string $adminEmail): array
    {
        return DB::transaction(function () use ($familyName, $adminName, $adminEmail) {
            $family = Family::create(['name' => $familyName]);
            $password = TemporaryPassword::for($family);

            $family->listTypes()->create(['name' => __('default_list_type')]);

            $admin = User::create([
                'family_id' => $family->id,
                'name' => $adminName,
                'email' => $adminEmail,
                'password' => $password,
                'role' => FamilyRole::Admin,
                'must_change_password' => true,
            ]);

            return ['family' => $family, 'admin' => $admin, 'password' => $password];
        });
    }
}

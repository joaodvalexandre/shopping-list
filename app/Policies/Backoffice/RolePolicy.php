<?php

namespace App\Policies\Backoffice;

use Illuminate\Contracts\Auth\Authenticatable;
use Illuminate\Database\Eloquent\Model;

class RolePolicy extends BackofficePolicy
{
    protected function group(): string
    {
        return 'roles';
    }

    /** Roles that ship with the app can be adjusted but never removed, by anyone. */
    public function delete(Authenticatable $user, Model $record): bool
    {
        return ! $record->is_system && parent::delete($user, $record);
    }
}

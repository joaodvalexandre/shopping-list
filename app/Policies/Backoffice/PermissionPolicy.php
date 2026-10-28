<?php

namespace App\Policies\Backoffice;

use Illuminate\Contracts\Auth\Authenticatable;
use Illuminate\Database\Eloquent\Model;

class PermissionPolicy extends BackofficePolicy
{
    protected function group(): string
    {
        return 'permissions';
    }

    /** The code checks the shipped permissions by name, so they can never be removed, by anyone. */
    public function delete(Authenticatable $user, Model $record): bool
    {
        return ! $record->is_system && parent::delete($user, $record);
    }
}

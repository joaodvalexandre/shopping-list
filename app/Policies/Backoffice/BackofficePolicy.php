<?php

namespace App\Policies\Backoffice;

use App\Models\Admin;
use Illuminate\Contracts\Auth\Authenticatable;
use Illuminate\Database\Eloquent\Model;

/**
 * One policy per backoffice resource: each ability is the matching permission
 * of the administrator's roles ("pages.update" and so on). Anyone who is not
 * an `Admin` (a family account, say) is refused everything.
 */
abstract class BackofficePolicy
{
    /** The permission group, e.g. "pages". */
    abstract protected function group(): string;

    protected function allows(Authenticatable $user, string $action): bool
    {
        return $user instanceof Admin && $user->hasPermission($this->group() . '.' . $action);
    }

    public function viewAny(Authenticatable $user): bool
    {
        return $this->allows($user, 'view');
    }

    public function view(Authenticatable $user, Model $record): bool
    {
        return $this->allows($user, 'view');
    }

    public function create(Authenticatable $user): bool
    {
        return $this->allows($user, 'create');
    }

    public function update(Authenticatable $user, Model $record): bool
    {
        return $this->allows($user, 'update');
    }

    public function delete(Authenticatable $user, Model $record): bool
    {
        return $this->allows($user, 'delete');
    }

    public function deleteAny(Authenticatable $user): bool
    {
        return $this->allows($user, 'delete');
    }

    /** Drag-and-drop ordering is an edit. */
    public function reorder(Authenticatable $user): bool
    {
        return $this->allows($user, 'update');
    }
}

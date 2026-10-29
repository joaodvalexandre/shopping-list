<?php

namespace App\Services;

use App\Enums\FamilyRole;
use App\Models\ListType;
use App\Models\User;
use App\Support\TemporaryPassword;
use Illuminate\Validation\ValidationException;

/**
 * What a family admin does with their family's members and list types, with the rules
 * in one place so the web pages and the phone API can never disagree: a family always
 * keeps an admin, nobody deletes themselves, a type in use stays, and a new or reset
 * password is the family's name and must be changed at the first login.
 */
class FamilyAdministration
{
    /**
     * @param  array{name: string, email: string, role: string, permissions?: ?array}  $data
     * @return array{0: User, 1: string} the member and the temporary password they sign in with
     */
    public function createMember(User $admin, array $data): array
    {
        $temporary = TemporaryPassword::for($admin->family);

        $member = User::create([
            'family_id' => $admin->family_id,
            'name' => $data['name'],
            'email' => $data['email'],
            'role' => $data['role'],
            'password' => $temporary,
            'must_change_password' => true,
        ]);
        $member->syncListPermissions($data['permissions'] ?? []);

        return [$member, $temporary];
    }

    /** @param  array{name: string, email: string, role: string, permissions?: ?array}  $data */
    public function updateMember(User $member, array $data): User
    {
        $newRole = FamilyRole::from($data['role']);

        if ($member->isFamilyAdmin() && $newRole !== FamilyRole::Admin) {
            $this->ensureNotLastAdmin($member);
        }

        $member->update(['name' => $data['name'], 'email' => $data['email'], 'role' => $newRole]);
        $member->syncListPermissions($data['permissions'] ?? []);

        return $member;
    }

    public function deleteMember(User $actor, User $member): void
    {
        if ($member->is($actor)) {
            throw ValidationException::withMessages(['member' => __('cannot_delete_yourself')]);
        }

        if ($member->isFamilyAdmin()) {
            $this->ensureNotLastAdmin($member);
        }

        $member->tokens()->delete();
        $member->delete();
    }

    /** A new temporary password; the member is signed out everywhere (browsers and phones). */
    public function resetPassword(User $member): string
    {
        $temporary = TemporaryPassword::for($member->family);
        $member->update(['password' => $temporary, 'must_change_password' => true]);

        $member->forceFill(['remember_token' => null])->save();
        $member->tokens()->delete();

        return $temporary;
    }

    public function createListType(User $admin, string $name): ListType
    {
        return ListType::create(['name' => $name, 'family_id' => $admin->family_id]);
    }

    public function deleteListType(ListType $type): void
    {
        if ($type->shoppingLists()->exists()) {
            throw ValidationException::withMessages(['list_type' => __('list_type_in_use')]);
        }

        // Deleted lists linger as tombstones for syncing devices and would
        // block the foreign key; the type is going away, so they can too.
        $type->shoppingLists()->onlyTrashed()->forceDelete();
        $type->delete();
    }

    /** A family must always keep at least one admin. */
    private function ensureNotLastAdmin(User $member): void
    {
        $otherAdmins = User::where('family_id', $member->family_id)
            ->where('role', FamilyRole::Admin->value)
            ->where('id', '!=', $member->id)
            ->count();

        if ($otherAdmins === 0) {
            throw ValidationException::withMessages(['member' => __('last_admin_error')]);
        }
    }
}

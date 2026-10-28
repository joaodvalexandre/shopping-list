<?php

namespace App\Http\Controllers\Family;

use App\Enums\FamilyRole;
use App\Http\Controllers\Controller;
use App\Models\ListType;
use App\Models\User;
use App\Support\TemporaryPassword;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class MemberController extends Controller
{
    public function index(Request $request)
    {
        $members = User::where('family_id', $request->user()->family_id)
            ->with('listTypes')
            ->orderBy('name')
            ->get();

        return view('family.members.index', [
            'members' => $members,
            'listTypes' => $this->familyTypes($request),
        ]);
    }

    public function create(Request $request)
    {
        return view('family.members.create', [
            'listTypes' => $this->familyTypes($request),
            'permissions' => [],
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|string|email|max:255|unique:users,email',
            'role' => ['required', Rule::enum(FamilyRole::class)],
            'permissions' => 'nullable|array',
        ]);

        $temporary = TemporaryPassword::for($request->user()->family);

        $member = User::create([
            'family_id' => $request->user()->family_id,
            'name' => $data['name'],
            'email' => $data['email'],
            'role' => $data['role'],
            'password' => $temporary,
            'must_change_password' => true,
        ]);
        $member->syncListPermissions($data['permissions'] ?? []);

        return redirect()->route('family.members.index')
            ->with('temporary_password', ['email' => $member->email, 'password' => $temporary]);
    }

    public function edit(Request $request, User $member)
    {
        return view('family.members.edit', [
            'member' => $member,
            'listTypes' => $this->familyTypes($request),
            'permissions' => $member->listTypes->mapWithKeys(fn (ListType $type) => [
                $type->id => $type->pivot->only(['can_view', 'can_add_items', 'can_edit_items', 'can_change_status', 'can_manage_lists']),
            ])->all(),
        ]);
    }

    public function update(Request $request, User $member): RedirectResponse
    {
        $data = $request->validate([
            'name' => 'required|string|max:255',
            'email' => ['required', 'string', 'email', 'max:255', Rule::unique('users')->ignore($member->id)],
            'role' => ['required', Rule::enum(FamilyRole::class)],
            'permissions' => 'nullable|array',
        ]);

        $newRole = FamilyRole::from($data['role']);
        if ($member->isFamilyAdmin() && $newRole !== FamilyRole::Admin) {
            $this->ensureNotLastAdmin($member);
        }

        $member->update([
            'name' => $data['name'],
            'email' => $data['email'],
            'role' => $newRole,
        ]);
        $member->syncListPermissions($data['permissions'] ?? []);

        $this->notificationToggle('member_updated_success', 'success');

        return redirect()->route('family.members.index');
    }

    public function destroy(Request $request, User $member): RedirectResponse
    {
        if ($member->is($request->user())) {
            throw ValidationException::withMessages(['member' => __('cannot_delete_yourself')]);
        }

        if ($member->isFamilyAdmin()) {
            $this->ensureNotLastAdmin($member);
        }

        $member->tokens()->delete();
        $member->delete();
        $this->notificationToggle('member_destroyed_success', 'success');

        return redirect()->route('family.members.index');
    }

    public function resetPassword(User $member): RedirectResponse
    {
        $temporary = TemporaryPassword::for($member->family);
        $member->update(['password' => $temporary, 'must_change_password' => true]);

        // Sign the member out everywhere: "remember me" cookies and every phone
        $member->forceFill(['remember_token' => null])->save();
        $member->tokens()->delete();

        return redirect()->route('family.members.index')
            ->with('temporary_password', ['email' => $member->email, 'password' => $temporary]);
    }

    private function familyTypes(Request $request)
    {
        return ListType::where('family_id', $request->user()->family_id)->orderBy('name')->get();
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

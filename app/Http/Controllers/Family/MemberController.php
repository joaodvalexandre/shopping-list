<?php

namespace App\Http\Controllers\Family;

use App\Enums\FamilyRole;
use App\Http\Controllers\Controller;
use App\Models\ListType;
use App\Models\User;
use App\Services\FamilyAdministration;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

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

    public function store(Request $request, FamilyAdministration $family): RedirectResponse
    {
        $data = $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|string|email|max:255|unique:users,email',
            'role' => ['required', Rule::enum(FamilyRole::class)],
            'permissions' => 'nullable|array',
        ]);

        [$member, $temporary] = $family->createMember($request->user(), $data);

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

    public function update(Request $request, User $member, FamilyAdministration $family): RedirectResponse
    {
        $data = $request->validate([
            'name' => 'required|string|max:255',
            'email' => ['required', 'string', 'email', 'max:255', Rule::unique('users')->ignore($member->id)],
            'role' => ['required', Rule::enum(FamilyRole::class)],
            'permissions' => 'nullable|array',
        ]);

        $family->updateMember($member, $data);

        $this->notificationToggle('member_updated_success', 'success');

        return redirect()->route('family.members.index');
    }

    public function destroy(Request $request, User $member, FamilyAdministration $family): RedirectResponse
    {
        $family->deleteMember($request->user(), $member);
        $this->notificationToggle('member_destroyed_success', 'success');

        return redirect()->route('family.members.index');
    }

    public function resetPassword(User $member, FamilyAdministration $family): RedirectResponse
    {
        $temporary = $family->resetPassword($member);

        return redirect()->route('family.members.index')
            ->with('temporary_password', ['email' => $member->email, 'password' => $temporary]);
    }

    private function familyTypes(Request $request)
    {
        return ListType::where('family_id', $request->user()->family_id)->orderBy('name')->get();
    }
}

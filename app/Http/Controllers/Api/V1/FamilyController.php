<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\FamilyRole;
use App\Enums\ListAbility;
use App\Http\Controllers\Controller;
use App\Models\ListType;
use App\Models\User;
use App\Services\FamilyAdministration;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/**
 * Members and list types of the family, for the phone's family admins (the web's Family
 * pages). The rules are the web's: they live in FamilyAdministration.
 */
class FamilyController extends Controller
{
    public function __construct(private readonly FamilyAdministration $family) {}

    /** Everything the admin screens need in one go. */
    public function show(Request $request): JsonResponse
    {
        $familyId = $request->user()->family_id;

        return response()->json([
            'members' => User::where('family_id', $familyId)->with('listTypes')->orderBy('name')->get()
                ->map(fn (User $member) => $this->presentMember($member))->all(),
            'list_types' => ListType::where('family_id', $familyId)->withCount('shoppingLists')->orderBy('name')->get()
                ->map(fn (ListType $type) => $this->presentType($type))->all(),
        ]);
    }

    public function storeMember(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|string|email|max:255|unique:users,email',
            'role' => ['required', Rule::enum(FamilyRole::class)],
            'permissions' => 'nullable|array',
        ]);

        [$member, $temporary] = $this->family->createMember($request->user(), $data);

        return response()->json([
            'member' => $this->presentMember($member->load('listTypes')),
            'temporary_password' => $temporary,
        ], 201);
    }

    public function updateMember(Request $request, User $member): JsonResponse
    {
        $data = $request->validate([
            'name' => 'required|string|max:255',
            'email' => ['required', 'string', 'email', 'max:255', Rule::unique('users')->ignore($member->id)],
            'role' => ['required', Rule::enum(FamilyRole::class)],
            'permissions' => 'nullable|array',
        ]);

        $this->family->updateMember($member, $data);

        return response()->json(['member' => $this->presentMember($member->load('listTypes'))]);
    }

    public function destroyMember(Request $request, User $member): JsonResponse
    {
        $this->family->deleteMember($request->user(), $member);

        return response()->json(['message' => 'deleted']);
    }

    public function resetPassword(User $member): JsonResponse
    {
        return response()->json(['temporary_password' => $this->family->resetPassword($member)]);
    }

    public function storeType(Request $request): JsonResponse
    {
        $data = $request->validate(['name' => ['required', 'string', 'max:100', $this->uniqueName($request)]]);

        $type = $this->family->createListType($request->user(), $data['name']);

        return response()->json(['list_type' => $this->presentType($type->loadCount('shoppingLists'))], 201);
    }

    public function updateType(Request $request, int $type): JsonResponse
    {
        $listType = $this->findType($request, $type);

        $data = $request->validate(['name' => ['required', 'string', 'max:100', $this->uniqueName($request, $listType)]]);
        $listType->update($data);

        return response()->json(['list_type' => $this->presentType($listType->loadCount('shoppingLists'))]);
    }

    public function destroyType(Request $request, int $type): JsonResponse
    {
        $this->family->deleteListType($this->findType($request, $type));

        return response()->json(['message' => 'deleted']);
    }

    /** @return array<string, mixed> */
    private function presentMember(User $member): array
    {
        return [
            'id' => $member->id,
            'name' => $member->name,
            'email' => $member->email,
            'role' => $member->role->value,
            'must_change_password' => (bool) $member->must_change_password,
            // type id => ability => bool; a type the member has nothing on is simply absent
            'permissions' => $member->listTypes->mapWithKeys(fn (ListType $type) => [
                $type->id => collect(ListAbility::cases())
                    ->mapWithKeys(fn (ListAbility $ability) => [$ability->value => (bool) $type->pivot->{$ability->value}])
                    ->all(),
            ])->all(),
        ];
    }

    /** @return array<string, mixed> */
    private function presentType(ListType $type): array
    {
        return ['id' => $type->id, 'name' => $type->name, 'lists_count' => (int) ($type->shopping_lists_count ?? 0)];
    }

    /** Only the signed-in admin's own family's types; any other is a 404. */
    private function findType(Request $request, int $id): ListType
    {
        return ListType::where('family_id', $request->user()->family_id)->findOrFail($id);
    }

    private function uniqueName(Request $request, ?ListType $ignore = null)
    {
        return Rule::unique('list_types', 'name')
            ->where('family_id', $request->user()->family_id)
            ->ignore($ignore?->id);
    }
}

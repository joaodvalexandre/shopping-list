<?php

namespace App\Http\Controllers\Family;

use App\Http\Controllers\Controller;
use App\Models\ListType;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class ListTypeController extends Controller
{
    public function index(Request $request)
    {
        $listTypes = $this->query($request)->withCount('shoppingLists')->orderBy('name')->get();

        return view('family.list_types.index', compact('listTypes'));
    }

    public function create()
    {
        return view('family.list_types.create');
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:100', $this->uniqueName($request)],
        ]);

        ListType::create($data + ['family_id' => $request->user()->family_id]);
        $this->notificationToggle('list_type_created_success', 'success');

        return redirect()->route('family.list-types.index');
    }

    public function edit(Request $request, string $listType)
    {
        return view('family.list_types.edit', ['listType' => $this->find($request, $listType)]);
    }

    public function update(Request $request, string $listType): RedirectResponse
    {
        $type = $this->find($request, $listType);

        $data = $request->validate([
            'name' => ['required', 'string', 'max:100', $this->uniqueName($request, $type)],
        ]);

        $type->update($data);
        $this->notificationToggle('list_type_updated_success', 'success');

        return redirect()->route('family.list-types.index');
    }

    public function destroy(Request $request, string $listType): RedirectResponse
    {
        $type = $this->find($request, $listType);

        if ($type->shoppingLists()->exists()) {
            throw ValidationException::withMessages(['list_type' => __('list_type_in_use')]);
        }

        // Deleted lists linger as tombstones for syncing devices and would
        // block the foreign key; the type is going away, so they can too.
        $type->shoppingLists()->onlyTrashed()->forceDelete();
        $type->delete();
        $this->notificationToggle('list_type_destroyed_success', 'success');

        return redirect()->route('family.list-types.index');
    }

    /** Only the signed-in admin's own family's types. */
    private function query(Request $request)
    {
        return ListType::where('family_id', $request->user()->family_id);
    }

    private function find(Request $request, string $id): ListType
    {
        return $this->query($request)->findOrFail($id);
    }

    private function uniqueName(Request $request, ?ListType $ignore = null)
    {
        return Rule::unique('list_types', 'name')
            ->where('family_id', $request->user()->family_id)
            ->ignore($ignore?->id);
    }
}

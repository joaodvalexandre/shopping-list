<?php

use App\Enums\FamilyRole;
use App\Models\ListType;
use App\Models\User;
use App\Services\FamilyProvisioner;

beforeEach(function () {
    $this->f = makeFamily();
});

it('keeps family administration away from members', function () {
    $member = memberWith($this->f['family'], $this->f['groceries'], ['can_view', 'can_manage_lists']);

    $this->actingAs($member)->get('/family/members')->assertForbidden();
    $this->actingAs($member)->get('/family/members/create')->assertForbidden();
    $this->actingAs($member)->post('/family/members', [
        'name' => 'X', 'email' => 'x@example.com', 'role' => 'admin',
    ])->assertForbidden();
    $this->actingAs($member)->get('/family/list-types')->assertForbidden();
    $this->actingAs($member)->post('/family/list-types', ['name' => 'Hack'])->assertForbidden();

    expect(User::where('email', 'x@example.com')->exists())->toBeFalse();
});

it('creates a member with a temporary password and per-type permissions', function () {
    $response = $this->actingAs($this->f['admin'])->post('/family/members', [
        'name' => 'Bia',
        'email' => 'bia@example.com',
        'role' => 'member',
        'permissions' => [
            $this->f['groceries']->id => ['can_add_items' => '1', 'can_change_status' => '1'],
            $this->f['party']->id => ['can_view' => '1'],
        ],
    ]);

    $response->assertRedirect(route('family.members.index'))->assertSessionHas('temporary_password');

    $bia = User::where('email', 'bia@example.com')->firstOrFail();
    expect($bia->family_id)->toBe($this->f['family']->id)
        ->and($bia->role)->toBe(FamilyRole::Member)
        ->and($bia->must_change_password)->toBeTrue();

    $tmp = session('temporary_password.password');
    expect(strlen($tmp))->toBe(12);
    expect(Hash::check($tmp, $bia->password))->toBeTrue();

    // "add items" implies "view"
    expect($bia->canOnListType(App\Enums\ListAbility::AddItems, $this->f['groceries']))->toBeTrue()
        ->and($bia->canOnListType(App\Enums\ListAbility::View, $this->f['groceries']))->toBeTrue()
        ->and($bia->canOnListType(App\Enums\ListAbility::EditItems, $this->f['groceries']))->toBeFalse()
        ->and($bia->canOnListType(App\Enums\ListAbility::View, $this->f['party']))->toBeTrue()
        ->and($bia->canOnListType(App\Enums\ListAbility::AddItems, $this->f['party']))->toBeFalse();
});

it('ignores permissions for list types of other families', function () {
    $other = makeFamily();

    $this->actingAs($this->f['admin'])->post('/family/members', [
        'name' => 'Bia', 'email' => 'bia@example.com', 'role' => 'member',
        'permissions' => [$other['groceries']->id => ['can_view' => '1', 'can_manage_lists' => '1']],
    ])->assertRedirect();

    $bia = User::where('email', 'bia@example.com')->firstOrFail();
    expect($bia->listTypes()->count())->toBe(0);
    expect($bia->canOnListType(App\Enums\ListAbility::View, $other['groceries']))->toBeFalse();
});

it('lets an admin promote a member to admin', function () {
    $member = memberWith($this->f['family'], $this->f['groceries'], ['can_view']);

    $this->actingAs($this->f['admin'])->put("/family/members/{$member->id}", [
        'name' => $member->name, 'email' => $member->email, 'role' => 'admin',
    ])->assertRedirect();

    $promoted = $member->fresh();
    expect($promoted->isFamilyAdmin())->toBeTrue();

    // and the new admin can now administer the family
    $this->actingAs($promoted)->get('/family/members')->assertOk();
});

it('updates a member\'s permissions', function () {
    $member = memberWith($this->f['family'], $this->f['groceries'], ['can_view']);

    $this->actingAs($this->f['admin'])->put("/family/members/{$member->id}", [
        'name' => $member->name, 'email' => $member->email, 'role' => 'member',
        'permissions' => [$this->f['party']->id => ['can_edit_items' => '1']],
    ])->assertRedirect();

    $member = $member->fresh();
    expect($member->canOnListType(App\Enums\ListAbility::View, $this->f['groceries']))->toBeFalse()
        ->and($member->canOnListType(App\Enums\ListAbility::EditItems, $this->f['party']))->toBeTrue();
});

it('never touches members of another family', function () {
    $other = makeFamily();
    $victim = User::factory()->create(['family_id' => $other['family']->id]);

    $admin = $this->f['admin'];
    $this->actingAs($admin)->get("/family/members/{$victim->id}/edit")->assertNotFound();
    $this->actingAs($admin)->put("/family/members/{$victim->id}", ['name' => 'Pwned', 'email' => $victim->email, 'role' => 'admin'])->assertNotFound();
    $this->actingAs($admin)->delete("/family/members/{$victim->id}")->assertNotFound();
    $this->actingAs($admin)->post("/family/members/{$victim->id}/reset-password")->assertNotFound();

    expect($victim->fresh()->name)->not->toBe('Pwned')->and($victim->fresh()->role)->toBe(FamilyRole::Member);
});

it('protects the last admin and the admin\'s own account', function () {
    $admin = $this->f['admin'];

    $this->actingAs($admin)->delete("/family/members/{$admin->id}")->assertSessionHasErrors('member');
    $this->actingAs($admin)->put("/family/members/{$admin->id}", [
        'name' => $admin->name, 'email' => $admin->email, 'role' => 'member',
    ])->assertSessionHasErrors('member');

    expect($admin->fresh()->isFamilyAdmin())->toBeTrue();

    // with a second admin, demoting the first is fine
    User::factory()->admin()->create(['family_id' => $this->f['family']->id]);
    $this->actingAs($admin)->put("/family/members/{$admin->id}", [
        'name' => $admin->name, 'email' => $admin->email, 'role' => 'member',
    ])->assertRedirect();
    expect($admin->fresh()->isFamilyAdmin())->toBeFalse();
});

it('deletes a member', function () {
    $member = memberWith($this->f['family'], $this->f['groceries'], ['can_view']);

    $this->actingAs($this->f['admin'])->delete("/family/members/{$member->id}")->assertRedirect();

    expect(User::find($member->id))->toBeNull();
});

it('resets a member\'s password to a new temporary one', function () {
    $member = User::factory()->create(['family_id' => $this->f['family']->id, 'password' => 'old-password-1']);

    $this->actingAs($this->f['admin'])->post("/family/members/{$member->id}/reset-password")
        ->assertRedirect()->assertSessionHas('temporary_password');

    $member = $member->fresh();
    expect($member->must_change_password)->toBeTrue()
        ->and(Hash::check('old-password-1', $member->password))->toBeFalse()
        ->and(Hash::check(session('temporary_password.password'), $member->password))->toBeTrue();
});

it('manages list types per family', function () {
    $admin = $this->f['admin'];

    $this->actingAs($admin)->post('/family/list-types', ['name' => 'Pharmacy'])->assertRedirect();
    $type = ListType::where('name', 'Pharmacy')->firstOrFail();
    expect($type->family_id)->toBe($this->f['family']->id);

    // unique within the family...
    $this->actingAs($admin)->post('/family/list-types', ['name' => 'Pharmacy'])->assertSessionHasErrors('name');
    // ...but another family may reuse the name
    $other = makeFamily();
    $this->actingAs($other['admin'])->post('/family/list-types', ['name' => 'Pharmacy'])->assertRedirect();

    $this->actingAs($admin)->put("/family/list-types/{$type->id}", ['name' => 'Chemist'])->assertRedirect();
    expect($type->fresh()->name)->toBe('Chemist');

    $this->actingAs($admin)->delete("/family/list-types/{$type->id}")->assertRedirect();
    expect(ListType::find($type->id))->toBeNull();
});

it('refuses to delete a list type that still has lists', function () {
    listIn($this->f['groceries']);

    $this->actingAs($this->f['admin'])->delete("/family/list-types/{$this->f['groceries']->id}")
        ->assertSessionHasErrors('list_type');

    expect(ListType::find($this->f['groceries']->id))->not->toBeNull();
});

it('cannot reach another family\'s list types', function () {
    $other = makeFamily();

    $this->actingAs($this->f['admin'])->get("/family/list-types/{$other['groceries']->id}/edit")->assertNotFound();
    $this->actingAs($this->f['admin'])->put("/family/list-types/{$other['groceries']->id}", ['name' => 'Pwned'])->assertNotFound();
    $this->actingAs($this->f['admin'])->delete("/family/list-types/{$other['party']->id}")->assertNotFound();

    expect($other['groceries']->fresh()->name)->toBe('Groceries');
});

it('provisions a family with its first admin and a default list type', function () {
    $result = app(FamilyProvisioner::class)->create('Silva', 'Joana Silva', 'joana@example.com');

    expect($result['family']->name)->toBe('Silva')
        ->and($result['admin']->isFamilyAdmin())->toBeTrue()
        ->and($result['admin']->must_change_password)->toBeTrue()
        ->and($result['family']->listTypes()->count())->toBe(1);

    $this->post('/login', ['email' => 'joana@example.com', 'password' => $result['password']])
        ->assertRedirect(route('dashboard'));
});

<?php

use App\Enums\ListAbility;
use App\Models\Family;
use App\Models\ListType;
use App\Models\User;
use Laravel\Sanctum\Sanctum;

beforeEach(function () {
    $this->f = makeFamily();
});

it('keeps family administration for family admins', function () {
    $this->getJson('/api/v1/family')->assertUnauthorized();

    $member = memberWith($this->f['family'], $this->f['groceries'], ['can_view', 'can_manage_lists']);
    Sanctum::actingAs($member, ['sync']);

    $this->getJson('/api/v1/family')->assertForbidden();
    $this->postJson('/api/v1/family/members', ['name' => 'X', 'email' => 'x@example.com', 'role' => 'admin'])->assertForbidden();
    $this->postJson('/api/v1/family/list-types', ['name' => 'Hack'])->assertForbidden();
    $this->deleteJson("/api/v1/family/members/{$this->f['admin']->id}")->assertForbidden();

    expect(User::where('email', 'x@example.com')->exists())->toBeFalse();
});

it('lists the members with their permissions, and the list types with their lists', function () {
    $bia = memberWith($this->f['family'], $this->f['groceries'], ['can_add_items', 'can_change_status']);
    listIn($this->f['groceries']);
    $stranger = Family::factory()->create();
    User::factory()->create(['family_id' => $stranger->id, 'name' => 'Stranger']);

    Sanctum::actingAs($this->f['admin'], ['sync']);
    $response = $this->getJson('/api/v1/family')->assertOk();

    $members = collect($response->json('members'))->keyBy('id');
    expect($members)->toHaveCount(2)->and($members->pluck('name')->all())->not->toContain('Stranger');

    $permissions = $members[$bia->id]['permissions'][(string) $this->f['groceries']->id];
    expect($permissions)->toBe([
        'can_view' => true, 'can_add_items' => true, 'can_edit_items' => false,
        'can_change_status' => true, 'can_manage_lists' => false,
    ])->and($members[$bia->id]['permissions'])->not->toHaveKey((string) $this->f['party']->id);

    $types = collect($response->json('list_types'))->keyBy('name');
    expect($types['Groceries']['lists_count'])->toBe(1)->and($types['Party']['lists_count'])->toBe(0);
});

it('creates a member with the family name as temporary password and per-type permissions', function () {
    Sanctum::actingAs($this->f['admin'], ['sync']);

    $response = $this->postJson('/api/v1/family/members', [
        'name' => 'Bia', 'email' => 'bia@example.com', 'role' => 'member',
        'permissions' => [$this->f['groceries']->id => ['can_add_items' => true]],
    ])->assertCreated()->assertJsonPath('temporary_password', $this->f['family']->name);

    $bia = User::where('email', 'bia@example.com')->firstOrFail();
    expect($bia->family_id)->toBe($this->f['family']->id)
        ->and($bia->must_change_password)->toBeTrue()
        ->and($response->json('member.permissions.' . $this->f['groceries']->id . '.can_view'))->toBeTrue();   // adding implies viewing

    // and she can sign in with it, only to choose her own password
    $this->postJson('/api/v1/auth/login', ['email' => 'bia@example.com', 'password' => $this->f['family']->name, 'device_name' => 'Phone'])
        ->assertOk()->assertJsonPath('password_change_required', true);
});

it('validates a new member', function () {
    Sanctum::actingAs($this->f['admin'], ['sync']);
    $taken = User::factory()->create(['email' => 'taken@example.com']);

    $this->postJson('/api/v1/family/members', ['name' => '', 'email' => 'nope', 'role' => 'boss'])
        ->assertUnprocessable()->assertJsonValidationErrors(['name', 'email', 'role']);
    $this->postJson('/api/v1/family/members', ['name' => 'X', 'email' => $taken->email, 'role' => 'member'])
        ->assertUnprocessable()->assertJsonValidationErrors(['email']);
});

it('ignores permissions on list types of other families', function () {
    $foreign = ListType::factory()->create(['family_id' => Family::factory()->create()->id]);
    Sanctum::actingAs($this->f['admin'], ['sync']);

    $this->postJson('/api/v1/family/members', [
        'name' => 'Bia', 'email' => 'bia@example.com', 'role' => 'member',
        'permissions' => [$foreign->id => ['can_view' => true]],
    ])->assertCreated();

    expect(User::where('email', 'bia@example.com')->first()->listTypes()->count())->toBe(0);
});

it('updates a member, promotes and demotes, but never leaves the family without an admin', function () {
    $bia = memberWith($this->f['family'], $this->f['groceries'], ['can_view']);
    Sanctum::actingAs($this->f['admin'], ['sync']);

    $this->putJson("/api/v1/family/members/{$bia->id}", [
        'name' => 'Bia Silva', 'email' => $bia->email, 'role' => 'member',
        'permissions' => [$this->f['party']->id => ['can_manage_lists' => true]],
    ])->assertOk()->assertJsonPath('member.name', 'Bia Silva');

    $bia = $bia->fresh();
    expect($bia->canOnListType(ListAbility::ManageLists, $this->f['party']))->toBeTrue()
        ->and($bia->canOnListType(ListAbility::View, $this->f['groceries']))->toBeFalse();   // not sent: taken away

    $this->putJson("/api/v1/family/members/{$bia->id}", ['name' => 'Bia', 'email' => $bia->email, 'role' => 'admin'])->assertOk();
    expect($bia->fresh()->isFamilyAdmin())->toBeTrue();

    // two admins: the first may step down, the last may not
    $this->putJson("/api/v1/family/members/{$this->f['admin']->id}", ['name' => 'Admin', 'email' => $this->f['admin']->email, 'role' => 'member'])->assertOk();
    Sanctum::actingAs($bia->fresh(), ['sync']);
    $this->putJson("/api/v1/family/members/{$bia->id}", ['name' => 'Bia', 'email' => $bia->email, 'role' => 'member'])
        ->assertUnprocessable()->assertJsonValidationErrors(['member']);
});

it('never touches members of another family', function () {
    $stranger = User::factory()->create(['family_id' => Family::factory()->create()->id]);
    Sanctum::actingAs($this->f['admin'], ['sync']);

    $this->putJson("/api/v1/family/members/{$stranger->id}", ['name' => 'X', 'email' => 'x@example.com', 'role' => 'admin'])->assertNotFound();
    $this->deleteJson("/api/v1/family/members/{$stranger->id}")->assertNotFound();
    $this->postJson("/api/v1/family/members/{$stranger->id}/reset-password")->assertNotFound();
});

it('deletes a member and signs their phones out, but not yourself', function () {
    $bia = memberWith($this->f['family'], $this->f['groceries'], ['can_view']);
    $bia->createToken('Phone', ['sync']);
    Sanctum::actingAs($this->f['admin'], ['sync']);

    $this->deleteJson("/api/v1/family/members/{$this->f['admin']->id}")->assertUnprocessable()->assertJsonValidationErrors(['member']);

    $this->deleteJson("/api/v1/family/members/{$bia->id}")->assertOk();
    expect(User::find($bia->id))->toBeNull()->and($bia->tokens()->count())->toBe(0);
});

it('resets a password to the family name and signs the member out everywhere', function () {
    $bia = memberWith($this->f['family'], $this->f['groceries'], ['can_view']);
    $bia->update(['password' => 'her-own-secret', 'must_change_password' => false]);
    $bia->createToken('Phone', ['sync']);
    Sanctum::actingAs($this->f['admin'], ['sync']);

    $this->postJson("/api/v1/family/members/{$bia->id}/reset-password")->assertOk()
        ->assertJsonPath('temporary_password', $this->f['family']->name);

    expect($bia->fresh()->must_change_password)->toBeTrue()->and($bia->tokens()->count())->toBe(0);
});

it('manages the list types of the family', function () {
    Sanctum::actingAs($this->f['admin'], ['sync']);

    $id = $this->postJson('/api/v1/family/list-types', ['name' => 'Pharmacy'])->assertCreated()
        ->assertJsonPath('list_type.name', 'Pharmacy')->json('list_type.id');

    $this->postJson('/api/v1/family/list-types', ['name' => 'Pharmacy'])->assertUnprocessable()->assertJsonValidationErrors(['name']);
    $this->putJson("/api/v1/family/list-types/{$id}", ['name' => 'Chemist'])->assertOk()->assertJsonPath('list_type.name', 'Chemist');
    $this->putJson("/api/v1/family/list-types/{$id}", ['name' => 'Groceries'])->assertUnprocessable();   // another type's name
    $this->deleteJson("/api/v1/family/list-types/{$id}")->assertOk();

    expect(ListType::find($id))->toBeNull();
});

it('refuses to delete a list type that still has lists, and never reaches another family type', function () {
    listIn($this->f['groceries']);
    $foreign = ListType::factory()->create(['family_id' => Family::factory()->create()->id]);
    Sanctum::actingAs($this->f['admin'], ['sync']);

    $this->deleteJson("/api/v1/family/list-types/{$this->f['groceries']->id}")->assertUnprocessable()->assertJsonValidationErrors(['list_type']);
    $this->putJson("/api/v1/family/list-types/{$foreign->id}", ['name' => 'Mine now'])->assertNotFound();
    $this->deleteJson("/api/v1/family/list-types/{$foreign->id}")->assertNotFound();
});

it('answers in the language the phone shows', function () {
    Sanctum::actingAs($this->f['admin'], ['sync']);
    $url = "/api/v1/family/members/{$this->f['admin']->id}";
    $body = ['name' => 'Admin', 'email' => $this->f['admin']->email, 'role' => 'member'];

    $this->withHeader('Accept-Language', 'en')->putJson($url, $body)->assertUnprocessable()
        ->assertJsonPath('errors.member.0', 'A family must keep at least one admin.');
    $this->withHeader('Accept-Language', 'pt-PT,pt;q=0.9')->putJson($url, $body)
        ->assertJsonPath('errors.member.0', 'Uma família tem de manter pelo menos um administrador.');
    // not on offer, or not said: the default language
    $this->withHeader('Accept-Language', 'xx')->putJson($url, $body)
        ->assertJsonPath('errors.member.0', 'Uma família tem de manter pelo menos um administrador.');
});

<?php

use App\Enums\FamilyRole;
use App\Filament\Resources\Families\Pages\CreateFamily;
use App\Models\Family;
use App\Models\User;
use App\Services\FamilyProvisioner;
use Illuminate\Support\Facades\Hash;
use Livewire\Livewire;

// The first-time password of anyone in a family is the family's name,
// and it only gets them as far as choosing their own.

it('gives a new family admin the family name as first password', function () {
    $result = app(FamilyProvisioner::class)->create('Família Silva', 'Joana', 'joana@example.com');

    expect($result['password'])->toBe('Família Silva')
        ->and(Hash::check('Família Silva', $result['admin']->password))->toBeTrue()
        ->and($result['admin']->must_change_password)->toBeTrue();
});

it('shows the backoffice admin what the first password is', function () {
    backofficeAdmin();

    Livewire::test(CreateFamily::class)
        ->fillForm(['name' => 'Silva', 'admin_name' => 'Joana', 'admin_email' => 'joana@example.com'])
        ->call('create');

    expect(shownTemporaryPassword())->toBe('Silva');
});

it('forces the family admin to choose their own password before anything else', function () {
    app(FamilyProvisioner::class)->create('Silva', 'Joana', 'joana@example.com');

    $this->post('/login', ['email' => 'joana@example.com', 'password' => 'Silva'])->assertRedirect(route('dashboard'));

    // every page sends them to the "choose your password" page until they do
    $this->get('/dashboard')->assertRedirect(route('password.choose'));
    $this->get('/shopping_list')->assertRedirect(route('password.choose'));
    $this->get('/settings')->assertRedirect(route('password.choose'));
    $this->get('/password/choose')->assertOk()->assertDontSee('current_password');

    // the family name is not accepted as the new password
    $this->put('/password/choose', ['password' => 'Silva', 'password_confirmation' => 'Silva'])
        ->assertSessionHasErrors('password');

    // no old password needed: they just proved it by signing in
    $this->put('/password/choose', ['password' => 'Brand-new-1', 'password_confirmation' => 'Brand-new-1'])
        ->assertRedirect(route('dashboard'));

    $this->get('/dashboard')->assertOk();
    expect(User::where('email', 'joana@example.com')->first()->must_change_password)->toBeFalse();

    // and the family name no longer works
    auth()->logout();
    $this->post('/login', ['email' => 'joana@example.com', 'password' => 'Silva'])->assertSessionHasErrors();
});

it('gives members added by a family admin the same first password', function () {
    $f = makeFamily();
    $f['family']->update(['name' => 'Os Pereira']);

    $this->actingAs($f['admin'])->post('/family/members', [
        'name' => 'Bia', 'email' => 'bia@example.com', 'role' => FamilyRole::Member->value,
    ])->assertSessionHas('temporary_password.password', 'Os Pereira');

    $bia = User::where('email', 'bia@example.com')->first();
    expect(Hash::check('Os Pereira', $bia->password))->toBeTrue()->and($bia->must_change_password)->toBeTrue();
});

it('resets a password back to the family name and forces a change', function () {
    $f = makeFamily();
    $member = User::factory()->create(['family_id' => $f['family']->id, 'password' => 'chosen-by-them-1', 'must_change_password' => false]);

    $this->actingAs($f['admin'])->post("/family/members/{$member->id}/reset-password")
        ->assertSessionHas('temporary_password.password', $f['family']->name);

    $member = $member->fresh();
    expect(Hash::check($f['family']->name, $member->password))->toBeTrue()
        ->and($member->must_change_password)->toBeTrue();
});

it('only gives a phone the right to change the password until it has been changed', function () {
    app(FamilyProvisioner::class)->create('Silva', 'Joana', 'joana@example.com');

    $login = $this->postJson('/api/v1/auth/login', ['email' => 'joana@example.com', 'password' => 'Silva', 'device_name' => 'Pixel'])
        ->assertOk()
        ->assertJsonPath('password_change_required', true);

    $this->withToken($login->json('token'))->postJson('/api/v1/sync', [])->assertForbidden();

    $this->withToken($login->json('token'))->putJson('/api/v1/me/password', [
        'current_password' => 'Silva', 'password' => 'Brand-new-1', 'password_confirmation' => 'Brand-new-1',
    ])->assertOk()->assertJsonPath('password_change_required', false);
});

it('uses the name of the right family, not another one', function () {
    app(FamilyProvisioner::class)->create('Silva', 'Joana', 'joana@example.com');
    app(FamilyProvisioner::class)->create('Costa', 'Rui', 'rui@example.com');

    $this->post('/login', ['email' => 'rui@example.com', 'password' => 'Silva'])->assertSessionHasErrors();
    $this->post('/login', ['email' => 'rui@example.com', 'password' => 'Costa'])->assertRedirect(route('dashboard'));
});

it('keeps the choose-password page for people on a temporary password only', function () {
    $f = makeFamily();   // the admin has a chosen password

    $this->actingAs($f['admin'])->get('/password/choose')->assertRedirect(route('dashboard'));
    $this->actingAs($f['admin'])->put('/password/choose', ['password' => 'Brand-new-1', 'password_confirmation' => 'Brand-new-1'])
        ->assertForbidden();
});

it('keeps guests out of the choose-password page', function () {
    $this->get('/password/choose')->assertRedirect(route('login'));
    $this->put('/password/choose', [])->assertRedirect(route('login'));
});

it('checks the new password on the choose-password page', function () {
    app(FamilyProvisioner::class)->create('Silva', 'Joana', 'joana@example.com');
    $this->post('/login', ['email' => 'joana@example.com', 'password' => 'Silva']);

    $this->put('/password/choose', ['password' => 'short1', 'password_confirmation' => 'short1'])->assertSessionHasErrors('password');
    $this->put('/password/choose', ['password' => 'Brand-new-1', 'password_confirmation' => 'different-1'])->assertSessionHasErrors('password');
    $this->put('/password/choose', ['password' => 'onlyletters', 'password_confirmation' => 'onlyletters'])->assertSessionHasErrors('password');

    expect(User::where('email', 'joana@example.com')->first()->must_change_password)->toBeTrue();
});

it('submits the choose-password form the way a browser does (a POST that says _method=PUT)', function () {
    app(FamilyProvisioner::class)->create('Silva', 'Joana', 'joana@example.com');
    $this->post('/login', ['email' => 'joana@example.com', 'password' => 'Silva']);

    // the page's own form must carry the method override...
    $this->get('/password/choose')->assertOk()
        ->assertSee('name="_method"', false)->assertSee('value="PUT"', false)
        ->assertSee('action="' . route('password.choose.store') . '"', false);

    // ...and a real POST with it must work
    $this->post('/password/choose', ['_method' => 'PUT', 'password' => 'Brand-new-1', 'password_confirmation' => 'Brand-new-1'])
        ->assertRedirect(route('dashboard'));

    expect(User::where('email', 'joana@example.com')->first()->must_change_password)->toBeFalse();
});

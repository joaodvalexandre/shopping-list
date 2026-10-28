<?php

use App\Filament\Resources\Admins\Pages\CreateAdmin;
use App\Filament\Resources\Admins\Pages\EditAdmin;
use App\Filament\Resources\Admins\Pages\ListAdmins;
use App\Models\Admin;
use App\Models\Role;
use Filament\Actions\Testing\TestAction;
use Illuminate\Support\Facades\Hash;
use Livewire\Livewire;

beforeEach(function () {
    $this->me = backofficeAdmin();
});

it('creates another administrator with a role', function () {
    $viewer = Role::where('name', 'viewer')->firstOrFail();

    Livewire::test(CreateAdmin::class)
        ->fillForm(['name' => 'Second', 'email' => 'second@example.com', 'password' => 'a-very-long-pass', 'roles' => [$viewer->id]])
        ->call('create')
        ->assertHasNoFormErrors();

    $second = Admin::where('email', 'second@example.com')->firstOrFail();
    expect(Hash::check('a-very-long-pass', $second->password))->toBeTrue()
        ->and($second->roles->pluck('name')->all())->toBe(['viewer']);
});

it('requires a role for a new administrator', function () {
    Livewire::test(CreateAdmin::class)
        ->fillForm(['name' => 'Second', 'email' => 'second@example.com', 'password' => 'a-very-long-pass'])
        ->call('create')
        ->assertHasFormErrors(['roles' => 'required']);
});

it('requires a long password and a unique email', function () {
    Livewire::test(CreateAdmin::class)
        ->fillForm(['name' => 'Weak', 'email' => 'weak@example.com', 'password' => 'short'])
        ->call('create')
        ->assertHasFormErrors(['password' => 'min']);

    Livewire::test(CreateAdmin::class)
        ->fillForm(['name' => 'Dup', 'email' => $this->me->email, 'password' => 'a-very-long-pass'])
        ->call('create')
        ->assertHasFormErrors(['email' => 'unique']);
});

it('keeps the current password when the field is left blank on edit', function () {
    $other = Admin::factory()->withRole('viewer')->create(['password' => 'original-password-1']);

    Livewire::test(EditAdmin::class, ['record' => $other->getKey()])
        ->fillForm(['name' => 'Renamed', 'password' => ''])
        ->call('save')
        ->assertHasNoFormErrors();

    $other = $other->fresh();
    expect($other->name)->toBe('Renamed')->and(Hash::check('original-password-1', $other->password))->toBeTrue();
});

it('changes a password when one is typed', function () {
    $other = Admin::factory()->withRole('viewer')->create(['password' => 'original-password-1']);

    Livewire::test(EditAdmin::class, ['record' => $other->getKey()])
        ->fillForm(['password' => 'brand-new-password-2'])
        ->call('save')
        ->assertHasNoFormErrors();

    expect(Hash::check('brand-new-password-2', $other->fresh()->password))->toBeTrue();
});

it('hides delete for yourself and deletes others', function () {
    $other = Admin::factory()->create();

    Livewire::test(ListAdmins::class)
        ->assertActionHidden(TestAction::make('delete')->table($this->me))
        ->callAction(TestAction::make('delete')->table($other));

    expect(Admin::find($other->id))->toBeNull()->and(Admin::find($this->me->id))->not->toBeNull();
});

it('resets two-factor for someone who lost their authenticator', function () {
    $locked = Admin::factory()->create();
    $locked->forceFill([
        'app_authentication_secret' => 'JBSWY3DPEHPK3PXP',
        'app_authentication_recovery_codes' => ['aaaa-bbbb', 'cccc-dddd'],
    ])->save();

    Livewire::test(ListAdmins::class)
        ->assertActionVisible(TestAction::make('resetTwoFactor')->table($locked))
        ->assertActionHidden(TestAction::make('resetTwoFactor')->table($this->me))
        ->callAction(TestAction::make('resetTwoFactor')->table($locked));

    $locked = $locked->fresh();
    expect($locked->app_authentication_secret)->toBeNull()->and($locked->app_authentication_recovery_codes)->toBeNull();
});

it('stores the two-factor secret and recovery codes encrypted', function () {
    $this->me->saveAppAuthenticationSecret('JBSWY3DPEHPK3PXP');
    $this->me->saveAppAuthenticationRecoveryCodes(['aaaa-bbbb']);

    $raw = DB::table('admins')->where('id', $this->me->id)->first();

    expect($raw->app_authentication_secret)->not->toContain('JBSWY3DPEHPK3PXP')
        ->and($raw->app_authentication_recovery_codes)->not->toContain('aaaa-bbbb');
    expect($this->me->fresh()->getAppAuthenticationSecret())->toBe('JBSWY3DPEHPK3PXP')
        ->and($this->me->fresh()->getAppAuthenticationRecoveryCodes())->toBe(['aaaa-bbbb']);
});

it('never exposes the password or two-factor secret when serialised', function () {
    $this->me->saveAppAuthenticationSecret('JBSWY3DPEHPK3PXP');

    $array = $this->me->fresh()->toArray();

    expect($array)->not->toHaveKeys(['password', 'remember_token', 'app_authentication_secret', 'app_authentication_recovery_codes']);
});

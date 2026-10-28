<?php

use App\Models\Admin;
use App\Models\User;

it('sends guests to the backoffice login', function () {
    $this->get('/admin')->assertRedirect('/admin/login');
    $this->get('/admin/families')->assertRedirect('/admin/login');
    $this->get('/admin/login')->assertOk();
});

it('keeps family accounts out of the backoffice, whatever their role', function () {
    $f = makeFamily();

    foreach (['/admin', '/admin/families', '/admin/users', '/admin/admins', '/admin/languages', '/admin/translations', '/admin/pages'] as $url) {
        $this->actingAs($f['admin'])->get($url)->assertRedirect('/admin/login');
    }

    $member = memberWith($f['family'], $f['groceries'], ['can_view']);
    $this->actingAs($member)->get('/admin/families')->assertRedirect('/admin/login');
});

it('does not let a backoffice administrator into the family web app', function () {
    backofficeAdmin();

    $this->get('/dashboard')->assertRedirect(route('login'));
    $this->get('/shopping_list')->assertRedirect(route('login'));
});

it('keeps administrators and family users in separate tables', function () {
    $user = User::factory()->create(['email' => 'same@example.com']);
    $admin = Admin::factory()->create(['email' => 'same@example.com']);

    expect($user)->toBeInstanceOf(User::class)->and($admin)->toBeInstanceOf(Admin::class);
    expect(User::count())->toBe(1)->and(Admin::count())->toBe(1);
});

it('opens every backoffice screen for an administrator', function () {
    backofficeAdmin();
    $f = makeFamily();

    foreach (['/admin', '/admin/families', '/admin/families/create', "/admin/families/{$f['family']->id}/edit",
        '/admin/users', '/admin/users/create', "/admin/users/{$f['admin']->id}/edit",
        '/admin/admins', '/admin/admins/create',
        '/admin/languages', '/admin/languages/create',
        '/admin/translations', '/admin/pages', '/admin/pages/create'] as $url) {
        $this->get($url)->assertOk();
    }
});

it('signs an administrator in through the login form', function () {
    Admin::factory()->create(['email' => 'boss@example.com', 'password' => 'a-long-secret-1']);

    Livewire\Livewire::test(Filament\Auth\Pages\Login::class)
        ->fillForm(['email' => 'boss@example.com', 'password' => 'a-long-secret-1'])
        ->call('authenticate')
        ->assertHasNoFormErrors();

    $this->assertAuthenticatedAs(Admin::where('email', 'boss@example.com')->first(), 'admin');
});

it('refuses a family member\'s credentials at the backoffice login', function () {
    User::factory()->admin()->create(['email' => 'mum@example.com', 'password' => 'family-pass-1']);

    Livewire\Livewire::test(Filament\Auth\Pages\Login::class)
        ->fillForm(['email' => 'mum@example.com', 'password' => 'family-pass-1'])
        ->call('authenticate')
        ->assertHasFormErrors(['email']);

    $this->assertGuest('admin');
});

it('creates administrators from the command line', function () {
    $this->artisan('admin:create', ['name' => 'Boss', 'email' => 'boss@example.com', '--password' => 'twelve-chars-ok'])
        ->assertSuccessful();

    expect(Admin::where('email', 'boss@example.com')->exists())->toBeTrue();

    $this->artisan('admin:create', ['name' => 'Weak', 'email' => 'weak@example.com', '--password' => 'short'])
        ->assertFailed();
    expect(Admin::where('email', 'weak@example.com')->exists())->toBeFalse();

    $this->artisan('admin:create', ['name' => 'Dup', 'email' => 'boss@example.com', '--password' => 'twelve-chars-ok'])
        ->assertFailed();
});

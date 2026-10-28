<?php

use App\Models\User;

it('redirects guests to the login page', function () {
    $this->get('/dashboard')->assertRedirect(route('login'));
    $this->get('/shopping_list')->assertRedirect(route('login'));
});

it('logs a member in with the right credentials', function () {
    $user = User::factory()->create(['email' => 'ana@example.com', 'password' => 'secret-pass1']);

    $this->post('/login', ['email' => 'ana@example.com', 'password' => 'secret-pass1'])
        ->assertRedirect(route('dashboard'));

    $this->assertAuthenticatedAs($user);
    expect($user->fresh()->last_login_at)->not->toBeNull();
});

it('rejects wrong credentials', function () {
    User::factory()->create(['email' => 'ana@example.com', 'password' => 'secret-pass1']);

    $this->post('/login', ['email' => 'ana@example.com', 'password' => 'nope'])
        ->assertSessionHasErrors('email');

    $this->assertGuest();
});

it('locks the login after five failed attempts', function () {
    User::factory()->create(['email' => 'ana@example.com', 'password' => 'secret-pass1']);

    foreach (range(1, 5) as $i) {
        $this->post('/login', ['email' => 'ana@example.com', 'password' => 'wrong']);
    }

    // Even the correct password is refused while locked out
    $this->post('/login', ['email' => 'ana@example.com', 'password' => 'secret-pass1'])
        ->assertSessionHasErrors('email');
    $this->assertGuest();
});

it('has no public registration', function () {
    $this->get('/register')->assertNotFound();
    $this->post('/register', ['name' => 'x', 'email' => 'x@example.com', 'password' => 'password1'])->assertStatus(404);
});

it('logs out', function () {
    $this->actingAs(User::factory()->create())->post('/logout')->assertRedirect(route('login'));

    $this->assertGuest();
});

it('forces members with a temporary password to choose their own', function () {
    $user = User::factory()->mustChangePassword()->create(['password' => 'temp-pass-123']);

    $this->actingAs($user)->get('/dashboard')->assertRedirect(route('settings.edit'));
    $this->actingAs($user)->get('/shopping_list')->assertRedirect(route('settings.edit'));
    $this->actingAs($user)->get('/settings')->assertOk();

    $this->actingAs($user)->put('/settings/password', [
        'current_password' => 'temp-pass-123',
        'password' => 'brand-new-pass1',
        'password_confirmation' => 'brand-new-pass1',
    ])->assertRedirect(route('dashboard'));

    expect($user->fresh()->must_change_password)->toBeFalse();
    $this->actingAs($user->fresh())->get('/dashboard')->assertOk();
});

it('refuses a new password equal to the current one or too weak', function () {
    $user = User::factory()->mustChangePassword()->create(['password' => 'temp-pass-123']);

    $this->actingAs($user)->put('/settings/password', [
        'current_password' => 'temp-pass-123',
        'password' => 'temp-pass-123',
        'password_confirmation' => 'temp-pass-123',
    ])->assertSessionHasErrors('password');

    $this->actingAs($user)->put('/settings/password', [
        'current_password' => 'temp-pass-123',
        'password' => 'short',
        'password_confirmation' => 'short',
    ])->assertSessionHasErrors('password');

    expect($user->fresh()->must_change_password)->toBeTrue();
});

it('applies the language saved on the account', function () {
    $user = User::factory()->create(['locale' => 'en']);

    $this->actingAs($user)->get('/dashboard');

    expect(app()->getLocale())->toBe('en');
});

<?php

use App\Models\User;
use Laravel\Sanctum\Sanctum;

it('keeps the health check public', function () {
    $this->getJson('/api/v1/health')->assertOk()->assertJsonPath('status', 'ok');
});

it('refuses unauthenticated access to every data route', function () {
    $this->getJson('/api/v1/me')->assertUnauthorized();
    $this->postJson('/api/v1/sync', [])->assertUnauthorized();
    $this->getJson('/api/v1/me/devices')->assertUnauthorized();
});

it('issues a device token for valid credentials', function () {
    $user = User::factory()->create(['email' => 'ana@example.com', 'password' => 'secret-pass1']);

    $response = $this->postJson('/api/v1/auth/login', [
        'email' => 'ana@example.com', 'password' => 'secret-pass1', 'device_name' => 'Ana\'s Pixel',
    ])->assertOk()->assertJsonPath('password_change_required', false);

    $token = $response->json('token');
    expect($user->tokens()->count())->toBe(1)->and($user->tokens()->first()->name)->toBe('Ana\'s Pixel');

    $this->withToken($token)->getJson('/api/v1/me')->assertOk()->assertJsonPath('user.email', 'ana@example.com');
});

it('rejects wrong credentials without saying which part was wrong', function () {
    User::factory()->create(['email' => 'ana@example.com', 'password' => 'secret-pass1']);

    $wrongPassword = $this->postJson('/api/v1/auth/login', ['email' => 'ana@example.com', 'password' => 'nope', 'device_name' => 'x']);
    $unknownEmail = $this->postJson('/api/v1/auth/login', ['email' => 'ghost@example.com', 'password' => 'nope', 'device_name' => 'x']);

    $wrongPassword->assertUnprocessable();
    $unknownEmail->assertUnprocessable();
    expect($wrongPassword->json('errors.email'))->toBe($unknownEmail->json('errors.email'));
});

it('locks the api login after five failed attempts', function () {
    User::factory()->create(['email' => 'ana@example.com', 'password' => 'secret-pass1']);

    foreach (range(1, 5) as $i) {
        $this->postJson('/api/v1/auth/login', ['email' => 'ana@example.com', 'password' => 'wrong', 'device_name' => 'x']);
    }

    $this->postJson('/api/v1/auth/login', ['email' => 'ana@example.com', 'password' => 'secret-pass1', 'device_name' => 'x'])
        ->assertUnprocessable();
});

it('only lets a temporary-password token change the password', function () {
    $user = User::factory()->mustChangePassword()->create(['email' => 'new@example.com', 'password' => 'temp-pass-123']);

    $restricted = $this->postJson('/api/v1/auth/login', [
        'email' => 'new@example.com', 'password' => 'temp-pass-123', 'device_name' => 'Phone',
    ])->assertOk()->assertJsonPath('password_change_required', true)->json('token');

    // cannot use the app yet
    $this->withToken($restricted)->getJson('/api/v1/me')->assertForbidden();
    $this->withToken($restricted)->postJson('/api/v1/sync', [])->assertForbidden();

    // ...but can choose a password, and gets the real token in exchange
    $full = $this->withToken($restricted)->putJson('/api/v1/me/password', [
        'current_password' => 'temp-pass-123',
        'password' => 'brand-new-pass1',
        'password_confirmation' => 'brand-new-pass1',
    ])->assertOk()->assertJsonPath('password_change_required', false)->json('token');

    expect($user->fresh()->must_change_password)->toBeFalse();

    // the restricted token is gone, the new one works
    app('auth')->forgetGuards();
    $this->withToken($restricted)->getJson('/api/v1/me')->assertUnauthorized();
    app('auth')->forgetGuards();
    $this->withToken($full)->getJson('/api/v1/me')->assertOk();
});

it('signs out the current device', function () {
    $user = User::factory()->create(['password' => 'secret-pass1']);
    $token = $this->postJson('/api/v1/auth/login', ['email' => $user->email, 'password' => 'secret-pass1', 'device_name' => 'x'])->json('token');

    $this->withToken($token)->postJson('/api/v1/auth/logout')->assertOk();

    expect($user->tokens()->count())->toBe(0);
});

it('lists and revokes only the user\'s own devices', function () {
    $user = User::factory()->create();
    $other = User::factory()->create();
    $user->createToken('Old phone', ['sync']);
    $theirs = $other->createToken('Their phone', ['sync'])->accessToken;

    Sanctum::actingAs($user, ['sync']);

    $this->getJson('/api/v1/me/devices')->assertOk()->assertJsonCount(1)->assertJsonPath('0.name', 'Old phone');

    $this->deleteJson("/api/v1/me/devices/{$theirs->id}")->assertNotFound();
    expect($other->tokens()->count())->toBe(1);

    $mine = $user->tokens()->first();
    $this->deleteJson("/api/v1/me/devices/{$mine->id}")->assertOk();
    expect($user->tokens()->count())->toBe(0);
});

it('describes the member\'s permissions the same way the web app enforces them', function () {
    $f = makeFamily();
    $member = memberWith($f['family'], $f['groceries'], ['can_view', 'can_add_items']);

    Sanctum::actingAs($member, ['sync']);

    $me = $this->getJson('/api/v1/me')->assertOk();
    $me->assertJsonPath('user.role', 'member')
        ->assertJsonPath("permissions.{$f['groceries']->id}.can_add_items", true)
        ->assertJsonPath("permissions.{$f['groceries']->id}.can_edit_items", false)
        ->assertJsonPath("permissions.{$f['party']->id}.can_view", false)
        ->assertJsonPath('members', []); // cannot manage lists, so no member roster

    Sanctum::actingAs($f['admin'], ['sync']);
    $this->getJson('/api/v1/me')
        ->assertJsonPath("permissions.{$f['party']->id}.can_manage_lists", true);
});

it('signs every device out when an admin resets a password', function () {
    $f = makeFamily();
    $member = User::factory()->create(['family_id' => $f['family']->id]);
    $member->createToken('Phone', ['sync']);

    $this->actingAs($f['admin'])->post("/family/members/{$member->id}/reset-password")->assertRedirect();

    expect($member->tokens()->count())->toBe(0);
});

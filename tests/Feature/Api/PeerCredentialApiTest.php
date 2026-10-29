<?php

use Laravel\Sanctum\Sanctum;

beforeEach(function () {
    $this->f = makeFamily();
    $this->bia = memberWith($this->f['family'], $this->f['groceries'], ['can_view', 'can_add_items']);
    $this->devicePair = sodium_crypto_sign_keypair();
    $this->devicePublic = sodium_crypto_sign_publickey($this->devicePair);
});

it('signs who a phone belongs to and what its person may do', function () {
    Sanctum::actingAs($this->bia, ['sync']);

    $response = $this->postJson('/api/v1/me/peer-credential', ['public_key' => base64_encode($this->devicePublic)])->assertOk();

    // the signature is over the exact text, and checks against the server key the phone is given
    $signature = base64_decode($response->json('signature'));
    $serverKey = base64_decode($response->json('server_key'));
    expect(sodium_crypto_sign_verify_detached($signature, $response->json('credential'), $serverKey))->toBeTrue();

    $credential = json_decode($response->json('credential'), true);
    expect($credential['user_id'])->toBe($this->bia->id)
        ->and($credential['family_id'])->toBe($this->f['family']->id)
        ->and($credential['name'])->toBe($this->bia->name)
        ->and($credential['role'])->toBe('member')
        ->and($credential['key'])->toBe(base64_encode($this->devicePublic))
        ->and($credential['exp'] - $credential['iat'])->toBe(7 * 86400)
        ->and($credential['permissions'][$this->f['groceries']->id])->toBe([
            'can_view' => true, 'can_add_items' => true, 'can_edit_items' => false,
            'can_change_status' => false, 'can_manage_lists' => false,
        ])
        ->and($credential['permissions'][$this->f['party']->id]['can_view'])->toBeFalse();
});

it('gives an admin every right', function () {
    Sanctum::actingAs($this->f['admin'], ['sync']);

    $credential = json_decode(
        $this->postJson('/api/v1/me/peer-credential', ['public_key' => base64_encode($this->devicePublic)])->json('credential'),
        true,
    );

    expect($credential['role'])->toBe('admin')
        ->and(array_values(array_unique($credential['permissions'][$this->f['party']->id])))->toBe([true]);
});

it('refuses anything that is not an Ed25519 public key', function () {
    Sanctum::actingAs($this->bia, ['sync']);

    $this->postJson('/api/v1/me/peer-credential', [])->assertUnprocessable()->assertJsonValidationErrors(['public_key']);
    $this->postJson('/api/v1/me/peer-credential', ['public_key' => 'not base64!'])->assertUnprocessable();
    $this->postJson('/api/v1/me/peer-credential', ['public_key' => base64_encode('too short')])->assertUnprocessable();
});

it('uses the same server key every time, so phones can check each other', function () {
    Sanctum::actingAs($this->bia, ['sync']);
    $first = $this->postJson('/api/v1/me/peer-credential', ['public_key' => base64_encode($this->devicePublic)])->json('server_key');

    Sanctum::actingAs($this->f['admin'], ['sync']);
    $second = $this->postJson('/api/v1/me/peer-credential', ['public_key' => base64_encode($this->devicePublic)])->json('server_key');

    expect($second)->toBe($first);
});

it('needs a signed-in phone with the full token', function () {
    $this->postJson('/api/v1/me/peer-credential', ['public_key' => base64_encode($this->devicePublic)])->assertUnauthorized();

    Sanctum::actingAs($this->bia, ['change-password']);
    $this->postJson('/api/v1/me/peer-credential', ['public_key' => base64_encode($this->devicePublic)])->assertForbidden();
});

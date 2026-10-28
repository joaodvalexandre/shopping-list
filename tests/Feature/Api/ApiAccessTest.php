<?php

it('keeps the health check public for the mobile app', function () {
    $this->getJson('/api/shopping-lists/health')->assertOk();
});

it('refuses unauthenticated access to shopping list data', function () {
    $this->getJson('/api/shopping-lists')->assertUnauthorized();
    $this->postJson('/api/shopping-lists', ['name' => 'x'])->assertUnauthorized();
    $this->putJson('/api/shopping-lists/1', ['name' => 'x'])->assertUnauthorized();
    $this->deleteJson('/api/shopping-lists/1')->assertUnauthorized();
    $this->postJson('/api/shopping-lists/sync', [])->assertUnauthorized();
});

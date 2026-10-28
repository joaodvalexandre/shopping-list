<?php

use App\Models\User;

it('sends guests from the root to the login page', function () {
    $this->get('/')->assertRedirect(route('login'));
});

it('sends signed-in members from the root to the dashboard', function () {
    $this->actingAs(User::factory()->create())->get('/')->assertRedirect('/dashboard');
});

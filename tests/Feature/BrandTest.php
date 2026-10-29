<?php

it('gives every page the app icon and its name', function () {
    $login = $this->get('/login')->assertOk();

    $login->assertSee('favicon.ico', false)->assertSee('img/logo.svg', false)->assertSee('site.webmanifest', false);

    $f = makeFamily();
    $this->actingAs($f['admin'])->get('/dashboard')->assertOk()->assertSee('favicon.ico', false)->assertSee('img/logo.svg', false);
});

it('ships the icon files the pages point at', function () {
    foreach (['favicon.ico', 'img/logo.svg', 'img/apple-touch-icon.png', 'img/icon-192.png', 'img/icon-512.png', 'site.webmanifest'] as $file) {
        expect(file_exists(public_path($file)))->toBeTrue("missing public/{$file}");
    }

    expect(json_decode(file_get_contents(public_path('site.webmanifest')), true)['name'])->toBe('Family Shopper');
});

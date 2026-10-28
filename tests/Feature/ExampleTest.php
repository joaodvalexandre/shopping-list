<?php

it('redirects the root to the dashboard', function () {
    $response = $this->get('/');

    $response->assertRedirect("/dashboard");
});

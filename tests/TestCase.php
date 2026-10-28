<?php

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;

abstract class TestCase extends BaseTestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        // Views call @vite(); tests must not depend on a prior `npm run build`
        $this->withoutVite();
    }
}

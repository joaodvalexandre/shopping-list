<?php

namespace App\Policies\Backoffice;

class AdminPolicy extends BackofficePolicy
{
    protected function group(): string
    {
        return 'administrators';
    }
}

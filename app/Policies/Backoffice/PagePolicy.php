<?php

namespace App\Policies\Backoffice;

class PagePolicy extends BackofficePolicy
{
    protected function group(): string
    {
        return 'pages';
    }
}

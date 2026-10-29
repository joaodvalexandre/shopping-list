<?php

namespace App\Policies\Backoffice;

class MenuItemPolicy extends BackofficePolicy
{
    protected function group(): string
    {
        return 'menus';
    }
}

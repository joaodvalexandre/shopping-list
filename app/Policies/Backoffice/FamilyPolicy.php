<?php

namespace App\Policies\Backoffice;

class FamilyPolicy extends BackofficePolicy
{
    protected function group(): string
    {
        return 'families';
    }
}

<?php

namespace App\Policies\Backoffice;

/** Family members, seen from the backoffice (the `User` model). */
class MemberPolicy extends BackofficePolicy
{
    protected function group(): string
    {
        return 'members';
    }
}

<?php

namespace App\Policies\Backoffice;

class LanguagePolicy extends BackofficePolicy
{
    protected function group(): string
    {
        return 'languages';
    }
}

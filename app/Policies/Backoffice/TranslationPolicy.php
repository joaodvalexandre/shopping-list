<?php

namespace App\Policies\Backoffice;

/** Texts are edited, never created or deleted by hand (one row per text and language). */
class TranslationPolicy extends BackofficePolicy
{
    protected function group(): string
    {
        return 'texts';
    }
}

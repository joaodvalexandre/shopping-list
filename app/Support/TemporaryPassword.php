<?php

namespace App\Support;

use App\Models\Family;

class TemporaryPassword
{
    /**
     * The first-time password of anyone in a family is the family's name, exactly
     * as written. It is easy to pass on, and useless after the first login: the
     * member is forced to choose their own (and the new one must differ).
     */
    public static function for(Family $family): string
    {
        return $family->name;
    }
}

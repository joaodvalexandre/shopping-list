<?php

namespace App\Enums;

enum FamilyRole: string
{
    case Admin = 'admin';
    case Member = 'member';

    public function label(): string
    {
        return __('role_' . $this->value);
    }
}

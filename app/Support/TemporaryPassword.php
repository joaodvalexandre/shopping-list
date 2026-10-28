<?php

namespace App\Support;

class TemporaryPassword
{
    /**
     * A readable one-time password (no look-alike characters) that the
     * member must replace on first login.
     */
    public static function generate(int $length = 12): string
    {
        $alphabet = 'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
        $password = '';

        for ($i = 0; $i < $length; $i++) {
            $password .= $alphabet[random_int(0, strlen($alphabet) - 1)];
        }

        return $password;
    }
}

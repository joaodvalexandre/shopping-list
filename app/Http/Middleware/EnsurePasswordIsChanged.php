<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Accounts are created with a temporary password; until the member picks
 * their own, the only reachable page is the one where they choose it.
 */
class EnsurePasswordIsChanged
{
    public function handle(Request $request, Closure $next): Response
    {
        if ($request->user()?->must_change_password) {
            return redirect()->route('password.choose');
        }

        return $next($request);
    }
}

<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Accounts are created with a temporary password; until the member picks
 * their own, the only reachable page is their settings.
 */
class EnsurePasswordIsChanged
{
    public function handle(Request $request, Closure $next): Response
    {
        if ($request->user()?->must_change_password) {
            return redirect()->route('settings.edit')->with('must_change_password', true);
        }

        return $next($request);
    }
}

<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * A phone that was signed in before its owner was put on a temporary password (the family name,
 * set again by a reset) holds a full token. It is signed out here, so the next sign-in goes
 * through the "choose your password" step, exactly as a first login does.
 */
class EnsureApiPasswordIsChanged
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if ($user?->must_change_password) {
            $user->currentAccessToken()?->delete();

            return response()->json(['message' => 'password_change_required'], 401);
        }

        return $next($request);
    }
}

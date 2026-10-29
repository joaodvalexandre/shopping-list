<?php

namespace App\Http\Middleware;

use App\Models\Language;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\App;

/**
 * The phone says which language it is showing (Accept-Language: pt), so the server's
 * messages (a refused change, a validation error) come back in that language. A
 * language that is not on offer (or none) falls back to the default.
 */
class ApiLanguage
{
    public function handle(Request $request, Closure $next)
    {
        $code = strtolower(substr((string) strtok((string) $request->header('Accept-Language'), ',;'), 0, 2));

        App::setLocale(Language::isActive($code) ? $code : Language::defaultCode());

        return $next($request);
    }
}

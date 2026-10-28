<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\App;

class LanguageMiddleware
{
    private const SUPPORTED = ['en', 'pt'];

    public function handle(Request $request, Closure $next)
    {
        // The account's saved language wins, then the session choice
        $locale = $request->user()?->locale ?? session('locale');

        if (in_array($locale, self::SUPPORTED, true)) {
            App::setLocale($locale);
        }

        return $next($request);
    }
}

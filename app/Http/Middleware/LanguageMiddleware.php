<?php

namespace App\Http\Middleware;

use App\Models\Language;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\App;

class LanguageMiddleware
{
    public function handle(Request $request, Closure $next)
    {
        // The account's saved language wins, then the session choice, then the
        // default set in the backoffice. A language that has since been
        // switched off falls back to the default.
        $locale = $request->user()?->locale ?? session('locale');

        App::setLocale(Language::isActive($locale) ? $locale : Language::defaultCode());

        return $next($request);
    }
}

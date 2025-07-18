<?php

namespace App\Http\Middleware;

use App\Providers\RouteServiceProvider;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Symfony\Component\HttpFoundation\Response;

class RedirectIfAuthenticated
{
    /**
     * Handle an incoming request.
     *
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     */
    public function handle(Request $request, Closure $next, string ...$guards): Response
    {
        // If user is authenticated, redirect to the dashboard
        if (Auth::check()) {
            return redirect()->route('dashboard'); // Redirect authenticated users to the dashboard
        }

        // If user is not authenticated, redirect to the welcome page
        return redirect()->route('welcome'); // Redirect unauthenticated users to the welcome page
    }
}

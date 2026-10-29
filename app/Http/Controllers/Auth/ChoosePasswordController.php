<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rules\Password;

/**
 * First login with a temporary password: the one page a member can reach until
 * they choose their own. They just proved the temporary password by signing in,
 * so only the new password (and its confirmation) is asked for.
 */
class ChoosePasswordController extends Controller
{
    public function create(Request $request)
    {
        if (! $request->user()->must_change_password) {
            return redirect()->route('dashboard');
        }

        return view('auth.choose-password');
    }

    public function store(Request $request): RedirectResponse
    {
        $user = $request->user();

        // Only for someone still on a temporary password; everyone else changes it in settings
        abort_unless($user->must_change_password, 403);

        $request->validate([
            'password' => [
                'required',
                'confirmed',
                Password::defaults(),
                // The temporary password (the family name) is no password at all
                fn (string $attribute, mixed $value, \Closure $fail) => Hash::check((string) $value, $user->password)
                    ? $fail(__('password_must_differ'))
                    : null,
            ],
        ]);

        $user->update([
            'password' => $request->input('password'),
            'must_change_password' => false,
        ]);

        $this->notificationToggle('password_changed_success', 'success');

        return redirect()->route('dashboard');
    }
}

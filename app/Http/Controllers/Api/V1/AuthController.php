<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Auth\Events\Lockout;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Str;
use Illuminate\Validation\Rules\Password;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    /** Ability of a full token, and of the restricted one issued with a temporary password. */
    public const ABILITY_SYNC = 'sync';
    public const ABILITY_CHANGE_PASSWORD = 'change-password';

    /**
     * Exchange email + password for a token that belongs to this device.
     * A member still on a temporary password only gets a token that can
     * change the password; the full token comes with the new one.
     */
    public function login(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => 'required|string|email',
            'password' => 'required|string',
            'device_name' => 'required|string|max:100',
        ]);

        $throttleKey = 'api-login|' . Str::lower($data['email']) . '|' . $request->ip();

        if (RateLimiter::tooManyAttempts($throttleKey, 5)) {
            event(new Lockout($request));

            throw ValidationException::withMessages([
                'email' => __('login_throttled', ['seconds' => RateLimiter::availableIn($throttleKey)]),
            ]);
        }

        $user = User::where('email', $data['email'])->first();

        // Same answer and similar cost whether the email exists or not
        $valid = Hash::check($data['password'], $user?->password ?? Hash::make('dummy-password'));

        if (! $user || ! $valid) {
            RateLimiter::hit($throttleKey);

            throw ValidationException::withMessages(['email' => __('login_failed')]);
        }

        RateLimiter::clear($throttleKey);
        $user->forceFill(['last_login_at' => now()])->save();

        return $this->tokenResponse($user, $data['device_name']);
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'logged_out']);
    }

    /**
     * Choose a permanent password (also how a first login completes).
     * The token used is replaced by a full one.
     */
    public function changePassword(Request $request): JsonResponse
    {
        $user = $request->user();

        $data = $request->validate([
            'current_password' => 'required|current_password',
            'password' => ['required', 'confirmed', 'different:current_password', Password::defaults()],
        ]);

        $deviceName = $user->currentAccessToken()->name;

        $user->update(['password' => $data['password'], 'must_change_password' => false]);

        // Every other device must sign in again with the new password
        $user->tokens()->delete();

        return $this->tokenResponse($user->fresh(), $deviceName);
    }

    private function tokenResponse(User $user, string $deviceName): JsonResponse
    {
        $mustChange = $user->must_change_password;
        $abilities = $mustChange ? [self::ABILITY_CHANGE_PASSWORD] : [self::ABILITY_SYNC];

        return response()->json([
            'token' => $user->createToken($deviceName, $abilities)->plainTextToken,
            'token_type' => 'Bearer',
            'password_change_required' => $mustChange,
            'user' => ['id' => $user->id, 'name' => $user->name, 'email' => $user->email],
        ]);
    }
}

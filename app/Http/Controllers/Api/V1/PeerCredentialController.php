<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Support\Mobile\PeerCredentials;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

/**
 * Gives a phone the signed statement it shows to family phones nearby (see PeerCredentials).
 * The phone sends the public half of a key pair it keeps to itself.
 */
class PeerCredentialController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate(['public_key' => 'required|string|max:64']);

        $key = base64_decode($data['public_key'], true);

        if ($key === false || strlen($key) !== SODIUM_CRYPTO_SIGN_PUBLICKEYBYTES) {
            throw ValidationException::withMessages(['public_key' => 'The public key must be a base64 Ed25519 key.']);
        }

        return response()->json(PeerCredentials::issue($request->user(), $key));
    }
}

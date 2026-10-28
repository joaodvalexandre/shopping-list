<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Services\Sync\SyncService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MeController extends Controller
{
    public function show(Request $request, SyncService $sync): JsonResponse
    {
        return response()->json($sync->profile($request->user()));
    }

    /** The signed-in devices of this account. */
    public function devices(Request $request): JsonResponse
    {
        $current = $request->user()->currentAccessToken()->id;

        return response()->json(
            $request->user()->tokens()->orderByDesc('last_used_at')->get()->map(fn ($token) => [
                'id' => $token->id,
                'name' => $token->name,
                'last_used_at' => $token->last_used_at?->toIso8601String(),
                'created_at' => $token->created_at->toIso8601String(),
                'current' => $token->id === $current,
            ])
        );
    }

    /** Sign a lost phone out remotely. */
    public function revokeDevice(Request $request, int $device): JsonResponse
    {
        $deleted = $request->user()->tokens()->whereKey($device)->delete();

        abort_if($deleted === 0, 404);

        return response()->json(['message' => 'revoked']);
    }
}

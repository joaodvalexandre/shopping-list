<?php

use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\ContentController;
use App\Http\Controllers\Api\V1\MeController;
use App\Http\Controllers\Api\V1\SyncController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Mobile API v1
|--------------------------------------------------------------------------
|
| Token (Sanctum) per device. A member on a temporary password only gets a
| token able to change the password; every other route needs the full
| "sync" ability. All data is scoped to the user's family and obeys the
| same permissions and hidden lists as the web app.
|
*/

Route::prefix('v1')->group(function () {
    Route::get('health', fn () => response()->json(['status' => 'ok', 'time' => now()->toIso8601String()]));

    Route::post('auth/login', [AuthController::class, 'login']);
    Route::get('content', [ContentController::class, 'show']);

    // Reachable with either token (needed to finish a first login)
    Route::middleware(['auth:sanctum', 'ability:sync,change-password'])->group(function () {
        Route::post('auth/logout', [AuthController::class, 'logout']);
        Route::put('me/password', [AuthController::class, 'changePassword']);
    });

    Route::middleware(['auth:sanctum', 'abilities:sync'])->group(function () {
        Route::get('me', [MeController::class, 'show']);
        Route::get('me/devices', [MeController::class, 'devices']);
        Route::delete('me/devices/{device}', [MeController::class, 'revokeDevice']);

        Route::post('sync', SyncController::class);
    });
});

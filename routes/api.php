<?php

use App\Http\Controllers\Api\V1\ActivityController;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\ContentController;
use App\Http\Controllers\Api\V1\FamilyController;
use App\Http\Controllers\Api\V1\MeController;
use App\Http\Controllers\Api\V1\PeerCredentialController;
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
        Route::post('me/peer-credential', [PeerCredentialController::class, 'store']);
        Route::delete('me/devices/{device}', [MeController::class, 'revokeDevice']);

        Route::post('sync', SyncController::class);
        Route::get('activity', [ActivityController::class, 'index']);

        // Family administration, for family admins only (the web's Family pages)
        Route::middleware('can:manage-family')->prefix('family')->group(function () {
            Route::get('/', [FamilyController::class, 'show']);
            Route::post('members', [FamilyController::class, 'storeMember']);
            Route::put('members/{member}', [FamilyController::class, 'updateMember']);
            Route::delete('members/{member}', [FamilyController::class, 'destroyMember']);
            Route::post('members/{member}/reset-password', [FamilyController::class, 'resetPassword']);
            Route::post('list-types', [FamilyController::class, 'storeType']);
            Route::put('list-types/{type}', [FamilyController::class, 'updateType'])->whereNumber('type');
            Route::delete('list-types/{type}', [FamilyController::class, 'destroyType'])->whereNumber('type');
        });
    });
});

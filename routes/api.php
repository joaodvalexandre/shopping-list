<?php

use App\Http\Controllers\Api\ShoppingListController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
|
| Everything except the health check requires a Sanctum token. The mobile
| API is being reworked (token login per device, family-scoped data and
| delta sync); until then the data routes are closed on purpose, because
| they used to expose every list without authentication.
|
*/

Route::middleware('auth:sanctum')->get('/user', function (Request $request) {
    return $request->user();
});

Route::prefix('shopping-lists')->group(function () {
    Route::get('/health', [ShoppingListController::class, 'health']);

    Route::middleware('auth:sanctum')->group(function () {
        Route::get('/', [ShoppingListController::class, 'index']);
        Route::post('/', [ShoppingListController::class, 'store']);
        Route::put('/{id}', [ShoppingListController::class, 'update']);
        Route::delete('/{id}', [ShoppingListController::class, 'destroy']);
        Route::post('/sync', [ShoppingListController::class, 'sync']);
    });
});

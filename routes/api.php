<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\ShoppingListController;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
|
| Here is where you can register API routes for your application. These
| routes are loaded by the RouteServiceProvider and all of them will
| be assigned to the "api" middleware group. Make something great!
|
*/

Route::middleware('auth:sanctum')->get('/user', function (Request $request) {
    return $request->user();
});

// Shopping List API Routes (no authentication required for mobile app)
Route::prefix('shopping-lists')->group(function () {
    Route::get('/health', [ShoppingListController::class, 'health']);
    Route::get('/', [ShoppingListController::class, 'index']);
    Route::post('/', [ShoppingListController::class, 'store']);
    Route::put('/{id}', [ShoppingListController::class, 'update']);
    Route::delete('/{id}', [ShoppingListController::class, 'destroy']);
    Route::post('/sync', [ShoppingListController::class, 'sync']);
});

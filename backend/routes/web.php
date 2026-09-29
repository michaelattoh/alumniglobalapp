<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\PaymentReturnController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\ConnectionController;

Route::get('/', function () {
    return view('welcome');
});

Route::get('/payments/return', PaymentReturnController::class);

Route::get('/email/verify/{id}/{hash}', [AuthController::class, 'verifyEmail'])
    ->middleware('signed')
    ->name('verification.verify');

Route::get('/password/reset/{token}', [AuthController::class, 'showResetForm'])
    ->name('password.reset');
Route::post('/password/reset', [AuthController::class, 'resetPasswordWeb'])
    ->name('password.update');

Route::get('/open-app/{destination}', [ConnectionController::class, 'openApp'])
    ->whereIn('destination', ['network', 'messages']);

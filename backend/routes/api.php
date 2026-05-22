<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Auth\AuthController;
use App\Http\Controllers\FilesController;
use App\Http\Controllers\SettingsController;
use App\Http\Controllers\OtpController;

/*
|--------------------------------------------------------------------------
| Public Auth Routes
|--------------------------------------------------------------------------
*/
Route::post('/auth/signup',          [AuthController::class, 'signup']);
Route::post('/auth/login',           [AuthController::class, 'login']);
Route::post('/auth/forgot-password', [AuthController::class, 'forgotPassword']);
Route::post('/auth/reset-password',  [AuthController::class, 'resetPassword']);

// FIX: refresh needs a (possibly expired) token in the header — must be public
// but still requires the token to be present, so it stays outside auth middleware.
Route::post('/auth/refresh', [AuthController::class, 'refresh']);

/*
|--------------------------------------------------------------------------
| Public OTP Routes
|--------------------------------------------------------------------------
*/
Route::post('/send-otp',   [OtpController::class, 'sendOtp']);
Route::post('/verify-otp', [OtpController::class, 'verifyOtp']);
Route::post('/resend-otp', [OtpController::class, 'resendOtp']);

/*
|--------------------------------------------------------------------------
| Protected Routes (JWT)
|--------------------------------------------------------------------------
*/
Route::middleware('auth:api')->group(function () {

    // Auth
    Route::post('/auth/logout', [AuthController::class, 'logout']);
    Route::delete('/auth/avatar', [AuthController::class, 'deleteAvatar']);
    Route::delete('/me', [AuthController::class, 'deleteAccount']);
    // Profile
    Route::get('/me', [AuthController::class, 'me']);
    Route::post('/me', [AuthController::class, 'updateProfile']);
    Route::put('/me', [AuthController::class, 'updateProfile']);
    Route::put('/me/name', [AuthController::class, 'updateName']);
    Route::post('/auth/change-email/send-otp', [AuthController::class, 'changeEmailSendOtp']);
    Route::post('/auth/change-email/verify', [AuthController::class, 'changeEmailVerify']);
    Route::post('/auth/change-password', [AuthController::class, 'changePassword']);

    // Settings
    Route::prefix('settings')->group(function () {
        Route::put('/language', [SettingsController::class, 'changeLanguage']);
        Route::put('/theme',    [SettingsController::class, 'changeTheme']);
        Route::put('/password', [SettingsController::class, 'changePassword']);
        Route::put('/email', [SettingsController::class, 'changeEmail']);
    });

    // FIX: upload moved inside auth — anonymous uploads are a security risk
    // (anyone could fill the server with files and rack up AI costs)
    Route::post('/files/upload', [FilesController::class, 'upload']);

    // Files
    Route::get('/files',              [FilesController::class, 'recent']);
    Route::get('/files/history',      [FilesController::class, 'getHistory']);
    Route::get('/files/{id}/details', [FilesController::class, 'getFileDetails']);
    Route::get('/files/{id}/download', [FilesController::class, 'download']);
    Route::get('/files/{id}/results', [FilesController::class, 'results']);
    Route::delete('/files/{id}',      [FilesController::class, 'destroy']);

    // AI Processing
    Route::post('/files/{id}/summarize', [FilesController::class, 'summarize']);
    Route::post('/files/{id}/questions', [FilesController::class, 'questions']);
    Route::post('/files/{id}/explain',   [FilesController::class, 'explain']);
    Route::post('/files/{id}/chat',    [FilesController::class, 'chat']);
    Route::post('/files/{id}/mindmap', [FilesController::class, 'mindmap']);
});
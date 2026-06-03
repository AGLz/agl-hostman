<?php

use App\Http\Controllers\AuthMd\AgentAuthController;
use App\Http\Controllers\AuthMd\AuthMdDocumentController;
use App\Http\Controllers\AuthMd\WellKnownController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| auth.md — protocolo de registo de agentes (WorkOS)
| https://workos.com/auth-md
|--------------------------------------------------------------------------
*/

Route::get('/auth.md', AuthMdDocumentController::class)->name('auth-md.document');

Route::get('/.well-known/oauth-protected-resource', [WellKnownController::class, 'protectedResource'])
    ->name('auth-md.well-known.prm');

Route::get('/.well-known/oauth-authorization-server', [WellKnownController::class, 'authorizationServer'])
    ->name('auth-md.well-known.authorization-server');

Route::prefix('agent/auth')->name('auth-md.agent.')->group(function (): void {
    Route::post('/', [AgentAuthController::class, 'register'])->name('register');
    Route::post('/claim', [AgentAuthController::class, 'claim'])->name('claim');
    Route::post('/claim/complete', [AgentAuthController::class, 'completeClaim'])->name('claim.complete');
    Route::get('/claim/view', [AgentAuthController::class, 'claimView'])->name('claim.view');
    Route::post('/revoke', [AgentAuthController::class, 'revoke'])->name('revoke');
});

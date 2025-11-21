<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use Illuminate\Http\Request;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\Password;
use Illuminate\View\View;

/**
 * Forgot Password Controller
 * AGL Infrastructure Admin Platform - Phase 5
 *
 * Handles password reset link requests with audit logging.
 */
class ForgotPasswordController extends Controller
{
    /**
     * Display the password reset request form
     *
     * @return View
     */
    public function showLinkRequestForm(): View
    {
        return view('auth.forgot-password');
    }

    /**
     * Handle password reset link request
     *
     * @param Request $request
     * @return RedirectResponse
     */
    public function sendResetLinkEmail(Request $request): RedirectResponse
    {
        $request->validate([
            'email' => ['required', 'email'],
        ]);

        // Attempt to send password reset link
        $status = Password::sendResetLink(
            $request->only('email')
        );

        // Log password reset request
        $user = \App\Models\User::where('email', $request->email)->first();

        if ($status === Password::RESET_LINK_SENT) {
            AuditLog::logAuth(
                $user,
                AuditLog::CATEGORY_PASSWORD_RESET,
                AuditLog::STATUS_SUCCESS,
                [
                    'email' => $request->email,
                    'action' => 'reset_link_sent',
                ]
            );

            return back()->with('status', __($status));
        }

        // Log failed attempt (but don't reveal if email exists)
        AuditLog::record([
            'event_type' => AuditLog::EVENT_AUTH,
            'event_category' => AuditLog::CATEGORY_PASSWORD_RESET,
            'action' => 'reset_link_failed',
            'description' => 'Password reset link request failed',
            'status' => AuditLog::STATUS_FAILED,
            'severity' => AuditLog::SEVERITY_INFO,
            'metadata' => [
                'email' => $request->email,
                'reason' => $status,
            ],
        ]);

        // Always return success message to prevent email enumeration
        return back()->with('status', __('If that email address exists in our system, we have sent a password reset link.'));
    }
}

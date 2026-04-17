<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;

class LocalAuthController extends Controller
{
    /**
     * Show the local login form.
     */
    public function showLoginForm()
    {
        // If WorkOS is configured, redirect to WorkOS
        if (config('services.workos.api_key')) {
            return redirect()->route('workos.redirect');
        }

        return view('auth.login');
    }

    /**
     * Handle local login attempt.
     */
    public function login(Request $request)
    {
        // If WorkOS is configured, always redirect to WorkOS
        if (config('services.workos.api_key')) {
            return redirect()->route('workos.redirect');
        }

        $credentials = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required'],
        ]);

        if (Auth::attempt($credentials, $request->boolean('remember'))) {
            $request->session()->regenerate();

            $user = Auth::user();
            if ($user) {
                $user->update(['last_login_at' => now()]);
            }

            return redirect()->intended('/dashboard');
        }

        return back()->withErrors([
            'email' => __('These credentials do not match our records.'),
        ])->onlyInput('email');
    }

    /**
     * Log the user out.
     */
    public function logout(Request $request)
    {
        Auth::logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect('/auth/login');
    }
}

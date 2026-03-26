<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use WorkOS\WorkOS;

class WorkOSController extends Controller
{
    /**
     * Redirect to WorkOS for authentication
     */
    public function redirect(Request $request)
    {
        $workos = new WorkOS(config('services.workos.api_key'));

        // Generate state parameter for CSRF protection
        $state = bin2hex(random_bytes(16));
        $request->session()->put('workos_state', $state);

        // Store intended URL for redirect after login
        if (! $request->session()->has('url_intended')) {
            $request->session()->put('url_intended', $request->query('redirect', route('dashboard')));
        }

        // Get the authorization URL
        $authorizationUrl = $workos->getAuthorizationUrl(
            config('services.workos.client_id'),
            route('workos.callback'),
            ['profile', 'email'],
            $state
        );

        return redirect($authorizationUrl);
    }

    /**
     * Handle WorkOS callback
     */
    public function callback(Request $request)
    {
        $workos = new WorkOS(config('services.workos.api_key'));

        // Verify state parameter to prevent CSRF attacks
        $state = $request->query('state');
        if ($state !== $request->session()->get('workos_state')) {
            return redirect()->route('login')
                ->with('error', 'Invalid state parameter. Please try again.');
        }

        try {
            // Exchange code for user profile
            $profile = $workos->getProfile($request->query('code'));

            // Get or create user
            $user = \App\Models\User::firstOrCreate(
                ['email' => $profile->email],
                [
                    'name' => trim($profile->firstName.' '.$profile->lastName),
                    'workos_id' => $profile->id,
                    'email_verified_at' => now(),
                    'password' => bcrypt(str_random(32)), // Random password (not used with OAuth)
                ]
            );

            // Login the user
            Auth::login($user);

            // Regenerate session ID for security
            $request->session()->regenerate();

            // Clear the state
            $request->session()->forget('workos_state');

            // Get intended URL or default to dashboard
            $intendedUrl = $request->session()->pull('url_intended', route('dashboard'));

            return redirect($intendedUrl)
                ->with('success', 'Welcome back, '.$user->name.'!');

        } catch (\Exception $e) {
            return redirect()->route('login')
                ->with('error', 'Authentication failed: '.$e->getMessage());
        }
    }

    /**
     * Logout user
     */
    public function logout(Request $request)
    {
        Auth::logout();

        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('home')
            ->with('success', 'You have been logged out successfully.');
    }
}

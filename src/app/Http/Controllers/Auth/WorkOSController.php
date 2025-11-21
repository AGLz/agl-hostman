<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use WorkOS\WorkOS;

class WorkOSController extends Controller
{
    protected WorkOS $workos;

    public function __construct()
    {
        $this->workos = new WorkOS(config('services.workos.api_key'));
    }

    /**
     * Redirect to WorkOS OAuth provider
     */
    public function redirect()
    {
        $authorizationUrl = $this->workos->sso->getAuthorizationUrl([
            'clientId' => config('services.workos.client_id'),
            'redirectUri' => config('services.workos.redirect_uri'),
            'provider' => 'authkit', // or specific provider like 'GoogleOAuth', 'MicrosoftOAuth'
        ]);

        return redirect($authorizationUrl);
    }

    /**
     * Handle WorkOS OAuth callback
     */
    public function callback(Request $request)
    {
        try {
            // Get the code from the callback
            $code = $request->query('code');

            if (!$code) {
                return redirect()->route('home')->withErrors(['error' => 'Authentication failed: No code provided']);
            }

            // Exchange the code for a profile
            $profile = $this->workos->sso->getProfileAndToken([
                'code' => $code,
                'clientId' => config('services.workos.client_id'),
            ]);

            // Extract user info from profile
            $workosId = $profile->profile->id;
            $email = $profile->profile->email;
            $firstName = $profile->profile->firstName ?? '';
            $lastName = $profile->profile->lastName ?? '';
            $name = trim("$firstName $lastName") ?: $email;

            // Find or create user
            $user = User::firstOrCreate(
                ['workos_id' => $workosId],
                [
                    'name' => $name,
                    'email' => $email,
                    'email_verified_at' => now(),
                    'workos_access_token' => $profile->accessToken ?? null,
                    'workos_refresh_token' => $profile->refreshToken ?? null,
                ]
            );

            // Update tokens if user exists
            if (!$user->wasRecentlyCreated) {
                $user->update([
                    'workos_access_token' => $profile->accessToken ?? null,
                    'workos_refresh_token' => $profile->refreshToken ?? null,
                ]);
            }

            // Log the user in
            Auth::login($user);

            Log::info('User authenticated via WorkOS', [
                'user_id' => $user->id,
                'email' => $user->email,
                'workos_id' => $workosId,
            ]);

            return redirect()->intended(route('dashboard'));

        } catch (\Exception $e) {
            Log::error('WorkOS authentication failed', [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]);

            return redirect()->route('home')->withErrors([
                'error' => 'Authentication failed: ' . $e->getMessage()
            ]);
        }
    }

    /**
     * Log the user out and revoke WorkOS session
     */
    public function logout(Request $request)
    {
        $user = Auth::user();

        if ($user) {
            Log::info('User logged out', [
                'user_id' => $user->id,
                'email' => $user->email,
            ]);
        }

        Auth::logout();

        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('home');
    }
}

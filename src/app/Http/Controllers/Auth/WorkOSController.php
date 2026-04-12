<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use WorkOS\UserManagement;
use WorkOS\WorkOS;

class WorkOSController extends Controller
{
    public function __construct(
        protected UserManagement $userManagement
    ) {
        $apiKey = config('services.workos.api_key');
        $clientId = config('services.workos.client_id');
        if (is_string($apiKey) && $apiKey !== '') {
            WorkOS::setApiKey($apiKey);
        }
        if (is_string($clientId) && $clientId !== '') {
            WorkOS::setClientId($clientId);
        }
    }

    /**
     * Redirect to WorkOS OAuth provider (User Management / AuthKit).
     */
    public function redirect()
    {
        $authorizationUrl = $this->userManagement->getAuthorizationUrl(
            (string) config('services.workos.redirect_uri'),
            null,
            UserManagement::AUTHORIZATION_PROVIDER_AUTHKIT
        );

        return redirect($authorizationUrl);
    }

    /**
     * Handle WorkOS OAuth callback
     */
    public function callback(Request $request)
    {
        try {
            $code = $request->query('code');

            if (! $code) {
                return redirect()->route('home')->withErrors(['error' => 'Authentication failed: No code provided']);
            }

            $auth = $this->userManagement->authenticateWithCode(
                (string) config('services.workos.client_id'),
                (string) $code
            );

            $workosUser = $auth->user;
            $workosId = $workosUser->id;
            $email = $workosUser->email;
            $firstName = $workosUser->firstName ?? '';
            $lastName = $workosUser->lastName ?? '';
            $name = trim("{$firstName} {$lastName}") ?: $email;

            $user = User::firstOrCreate(
                ['workos_id' => $workosId],
                [
                    'name' => $name,
                    'email' => $email,
                    'email_verified_at' => now(),
                    'password' => Hash::make(Str::password(32)),
                ]
            );

            if (! $user->wasRecentlyCreated) {
                $user->update([
                    'name' => $name,
                    'email' => $email,
                ]);
            }

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
                'error' => 'Authentication failed: '.$e->getMessage(),
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

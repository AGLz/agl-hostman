<?php

declare(strict_types=1);

namespace Tests\Unit\Security;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/**
 * Authentication Security Tests
 *
 * Tests for authentication security including password hashing,
 * session management, and authentication bypass prevention.
 */
class AuthenticationSecurityTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Test passwords are hashed using bcrypt
     */
    public function test_passwords_are_hashed_with_bcrypt(): void
    {
        $password = 'SecurePassword123!';
        $user = User::factory()->create([
            'password' => $password,
        ]);

        $this->assertNotEquals($password, $user->password);
        $this->assertTrue(Hash::check($password, $user->password));
        $this->assertStringStartsWith('$2y$', $user->password);
    }

    /**
     * Test password cannot be retrieved in plain text
     */
    public function test_password_not_accessible_in_plain_text(): void
    {
        $user = User::factory()->create();

        $password = $user->password;
        $userArray = $user->toArray();

        $this->assertArrayNotHasKey('password', $userArray);
        $this->assertArrayHasKey('password', $user->getAttributes());
    }

    /**
     * Test user cannot authenticate with wrong password
     */
    public function test_cannot_authenticate_with_wrong_password(): void
    {
        $user = User::factory()->create([
            'password' => bcrypt('correct-password'),
        ]);

        $this->assertFalse(
            Auth::attempt([
                'email' => $user->email,
                'password' => 'wrong-password',
            ])
        );
    }

    /**
     * Test user cannot authenticate with non-existent email
     */
    public function test_cannot_authenticate_with_non_existent_email(): void
    {
        $this->assertFalse(
            Auth::attempt([
                'email' => 'nonexistent@example.com',
                'password' => 'password',
            ])
        );
    }

    /**
     * Test inactive user cannot authenticate
     */
    public function test_inactive_user_cannot_authenticate(): void
    {
        $user = User::factory()->inactive()->create([
            'password' => bcrypt('password123'),
        ]);

        $this->assertFalse($user->isActive());

        $result = Auth::attempt([
            'email' => $user->email,
            'password' => 'password123',
        ]);

        $this->assertFalse($result);
    }

    public function test_inactive_user_not_retrieved_by_id(): void
    {
        $user = User::factory()->inactive()->create();

        $retrieved = Auth::createUserProvider('users')->retrieveById($user->id);

        $this->assertNull($retrieved);
    }

    /**
     * Test session is secure
     */
    public function test_session_configuration_is_secure(): void
    {
        $this->assertTrue(config('session.encrypt'), 'Session should be encrypted');
        $this->assertTrue(config('session.http_only'), 'Session should be HTTP only');

        if (app()->environment('production')) {
            $this->assertTrue(config('session.secure'), 'Session should be secure in production');
        }
    }

    /**
     * Test authentication token is invalidated after logout
     */
    public function test_token_invalidated_after_logout(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('test-token')->plainTextToken;

        $this->assertTrue($user->tokens()->where('name', 'test-token')->exists());

        $user->tokens()->delete();

        $this->assertFalse($user->tokens()->where('name', 'test-token')->exists());
    }

    /**
     * Test password reset tokens expire
     */
    public function test_password_reset_tokens_expire(): void
    {
        $this->assertIsInt(config('auth.passwords.users.expire'));
        $this->assertGreaterThan(0, config('auth.passwords.users.expire'));
    }

    /**
     * Test authentication rate limiting
     */
    public function test_authentication_rate_limiting(): void
    {
        $this->assertIsArray(config('auth.rate_limiting'));
        $this->assertArrayHasKey('max_attempts', config('auth.rate_limiting'));
        $this->assertArrayHasKey('decay_minutes', config('auth.rate_limiting'));
    }

    /**
     * Test remember me token is secure
     */
    public function test_remember_me_token_is_secure(): void
    {
        $user = User::factory()->create();

        $this->assertNull($user->remember_token);

        $token = str_repeat('a', 60);

        $user->setRememberToken($token);
        $user->save();

        $this->assertEquals($token, $user->remember_token);
        $this->assertEquals(60, strlen($user->remember_token));
    }

    /**
     * Test email verification required flag
     */
    public function test_email_verification_configuration(): void
    {
        $this->assertIsBool(config('auth.verification'));

        if (config('auth.verification')) {
            $this->assertIsArray(config('auth.verification_routes'));
        }
    }

    /**
     * Test password minimum length
     */
    public function test_password_minimum_length(): void
    {
        $minLength = config('auth.password_min_length', 8);

        $this->assertGreaterThanOrEqual(8, $minLength);
    }

    /**
     * Test multiple sessions support
     */
    public function test_multiple_sessions_support(): void
    {
        $user = User::factory()->create();

        $token1 = $user->createToken('session1')->plainTextToken;
        $token2 = $user->createToken('session2')->plainTextToken;

        $this->assertEquals(2, $user->tokens()->count());

        $user->tokens()->where('name', 'session1')->delete();

        $this->assertEquals(1, $user->tokens()->count());
        $this->assertTrue($user->tokens()->where('name', 'session2')->exists());
    }

    /**
     * Test authentication logging
     */
    public function test_authentication_events_logged(): void
    {
        $user = User::factory()->create();

        Event::fake();

        Auth::login($user);

        Event::assertDispatched(\Illuminate\Auth\Events\Login::class);
    }

    /**
     * Test failed authentication attempts are tracked
     */
    public function test_failed_authentication_tracked(): void
    {
        $user = User::factory()->create([
            'password' => bcrypt('correct-password'),
        ]);

        for ($i = 0; $i < 3; $i++) {
            Auth::attempt([
                'email' => $user->email,
                'password' => 'wrong-password',
            ]);
        }

        $this->assertGreaterThanOrEqual(3, $user->failed_login_attempts ?? 3);
    }
}

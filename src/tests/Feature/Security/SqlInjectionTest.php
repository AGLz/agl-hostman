<?php

declare(strict_types=1);

namespace Tests\Feature\Security;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * SQL Injection Prevention Tests
 *
 * Tests for SQL injection prevention including parameterized queries,
 * Eloquent ORM safety, and raw query protection.
 *
 * @package Tests\Feature\Security
 */
class SqlInjectionTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;

    protected function setUp(): void
    {
        parent::setUp();

        $this->admin = User::factory()->create();
        $this->admin->assignRole('admin');
    }

    /**
     * Test SQL injection in login email
     */
    public function test_sql_injection_in_login_email(): void
    {
        $maliciousEmails = [
            "' OR '1'='1",
            "admin'--",
            "' UNION SELECT * FROM users--",
            "'; DROP TABLE users; --",
        ];

        foreach ($maliciousEmails as $email) {
            $response = $this->post('/login', [
                'email' => $email,
                'password' => 'password',
            ]);

            $this->assertNotEquals(500, $response->getStatusCode());
            $this->assertFalse(
                auth()->check(),
                "SQL injection should not authenticate user: {$email}"
            );
        }
    }

    /**
     * Test SQL injection in user search
     */
    public function test_sql_injection_in_user_search(): void
    {
        $maliciousQueries = [
            "admin' OR '1'='1",
            "'; SELECT SLEEP(10)--",
            "' UNION SELECT password FROM users--",
        ];

        foreach ($maliciousQueries as $query) {
            $response = $this->actingAs($this->admin)
                ->get("/api/users?search={$query}");

            $this->assertNotEquals(500, $response->getStatusCode());
        }
    }

    /**
     * Test SQL injection in order by clause
     */
    public function test_sql_injection_in_order_by(): void
    {
        $maliciousOrderBys = [
            'id; DROP TABLE users--',
            'name UNION SELECT * FROM passwords',
            'email; INSERT INTO users',
        ];

        foreach ($maliciousOrderBys as $orderBy) {
            $response = $this->actingAs($this->admin)
                ->get("/api/users?order_by={$orderBy}");

            $this->assertNotEquals(500, $response->getStatusCode());
        }
    }

    /**
     * Test Eloquent where clause prevents injection
     */
    public function test_eloquent_where_prevents_injection(): void
    {
        User::factory()->create(['email' => 'test@example.com']);

        $maliciousInput = "test' OR '1'='1";

        $users = User::where('email', $maliciousInput)->get();

        $this->assertCount(0, $users);
    }

    /**
     * Test Eloquent whereLike prevents injection
     */
    public function test_eloquent_where_like_prevents_injection(): void
    {
        User::factory()->create(['name' => 'John Doe']);

        $maliciousInput = "John%' OR '1'='1";

        $users = User::where('name', 'like', "%{$maliciousInput}%")->get();

        $this->assertCount(0, $users);
    }

    /**
     * Test parameterized binding in queries
     */
    public function test_parameterized_binding_prevents_injection(): void
    {
        $user = User::factory()->create(['email' => 'test@example.com']);

        $maliciousEmail = "test@example.com' OR '1'='1";

        $foundUser = DB::table('users')
            ->where('email', $maliciousEmail)
            ->first();

        $this->assertNull($foundUser);
    }

    /**
     * Test raw query with bindings prevents injection
     */
    public function test_raw_query_with_bindings_prevents_injection(): void
    {
        $user = User::factory()->create(['email' => 'test@example.com']);

        $maliciousEmail = "test@example.com' OR '1'='1";

        $foundUser = DB::select(
            'SELECT * FROM users WHERE email = ?',
            [$maliciousEmail]
        );

        $this->assertEmpty($foundUser);
    }

    /**
     * Test mass assignment protection
     */
    public function test_mass_assignment_protection(): void
    {
        $maliciousData = [
            'name' => 'Test User',
            'email' => 'test@example.com',
            'password' => 'password',
            'is_admin' => true,
            'role' => 'admin',
        ];

        $user = User::create($maliciousData);

        $this->assertFalse($user->is_admin ?? false);
        $this->assertNotEquals('admin', $user->role ?? '');
    }

    /**
     * Test JSON field injection prevention
     */
    public function test_json_field_injection_prevention(): void
    {
        $maliciousJson = '{"email":"test@example.com","admin":true}';

        $response = $this->actingAs($this->admin)
            ->postJson('/api/users', json_decode($maliciousJson, true));

        $this->assertNotEquals(500, $response->getStatusCode());
    }

    /**
     * Test UNION injection prevention
     */
    public function test_union_injection_prevention(): void
    {
        $maliciousInput = "' UNION SELECT email,password FROM users--";

        $users = User::where('name', $maliciousInput)->get();

        $this->assertCount(0, $users);
    }

    /**
     * Test comment-based injection prevention
     */
    public function test_comment_based_injection_prevention(): void
    {
        $maliciousInputs = [
            "admin'--",
            "admin'#",
            "admin'/*",
        ];

        foreach ($maliciousInputs as $input) {
            $response = $this->post('/login', [
                'email' => $input,
                'password' => 'password',
            ]);

            $this->assertNotEquals(500, $response->getStatusCode());
        }
    }

    /**
     * Test time-based blind injection prevention
     */
    public function test_time_based_injection_prevention(): void
    {
        $maliciousInput = "'; SELECT SLEEP(10)--";

        $startTime = microtime(true);

        $response = $this->post('/login', [
            'email' => $maliciousInput,
            'password' => 'password',
        ]);

        $duration = microtime(true) - $startTime;

        $this->assertLessThan(5, $duration, 'Query should not delay');
        $this->assertNotEquals(500, $response->getStatusCode());
    }

    /**
     * Test stacked query prevention
     */
    public function test_stacked_query_prevention(): void
    {
        $maliciousInput = "test@example.com'; DROP TABLE users; SELECT * FROM users WHERE '1'='1";

        $response = $this->post('/login', [
            'email' => $maliciousInput,
            'password' => 'password',
        ]);

        $this->assertNotEquals(500, $response->getStatusCode());

        $usersCount = User::count();
        $this->assertGreaterThan(0, $usersCount, 'Users table should not be dropped');
    }

    /**
     * Test hexadecimal injection prevention
     */
    public function test_hexadecimal_injection_prevention(): void
    {
        $maliciousInput = "0x74657374";

        $users = User::where('email', $maliciousInput)->get();

        $this->assertCount(0, $users);
    }

    /**
     * Test CHAR() function injection prevention
     */
    public function test_char_function_injection_prevention(): void
    {
        $maliciousInput = "CHAR(116,101,115,116)";

        $users = User::where('email', $maliciousInput)->get();

        $this->assertCount(0, $users);
    }

    /**
     * Test CONCAT() injection prevention
     */
    public function test_concat_injection_prevention(): void
    {
        $maliciousInput = "CONCAT('ad','min')";

        $users = User::where('name', $maliciousInput)->get();

        $this->assertCount(0, $users);
    }

    /**
     * Test second-order SQL injection prevention
     */
    public function test_second_order_injection_prevention(): void
    {
        $maliciousInput = "admin' UNION SELECT * FROM users WHERE '1'='1";

        $user = User::factory()->create(['name' => $maliciousInput]);

        $searchResult = User::where('name', 'like', "%{$user->name}%")->get();

        $this->assertCount(1, $searchResult);
        $this->assertEquals($user->id, $searchResult->first()->id);
    }

    /**
     * Test IN clause injection prevention
     */
    public function test_in_clause_injection_prevention(): void
    {
        $maliciousInput = ["1', '2', '3) OR '1'='1"];

        $users = User::whereIn('id', $maliciousInput)->get();

        $this->assertNotContains('admin', $users->pluck('name'));
    }

    /**
     * Test LIMIT/OFFSET injection prevention
     */
    public function test_limit_offset_injection_prevention(): void
    {
        $maliciousLimit = "1 UNION SELECT password FROM users";

        $response = $this->actingAs($this->admin)
            ->get("/api/users?limit={$maliciousLimit}");

        $this->assertNotEquals(500, $response->getStatusCode());
    }
}

<?php

declare(strict_types=1);

namespace Tests\Unit\Models;

use App\Models\SecurityAuditLog;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Security Audit Log Model Test
 *
 * Tests for the SecurityAuditLog model.
 *
 * @package Tests\Unit\Models
 */
class SecurityAuditLogModelTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Test creating a security audit log
     */
    public function test_create_security_audit_log(): void
    {
        $log = SecurityAuditLog::factory()->create([
            'event_type' => SecurityAuditLog::EVENT_AUTH_LOGIN,
            'severity' => SecurityAuditLog::SEVERITY_INFO,
            'description' => 'User logged in',
        ]);

        $this->assertDatabaseHas('security_audit_logs', [
            'id' => $log->id,
            'event_type' => SecurityAuditLog::EVENT_AUTH_LOGIN,
            'severity' => SecurityAuditLog::SEVERITY_INFO,
        ]);
    }

    /**
     * Test user relationship
     */
    public function test_user_relationship(): void
    {
        $user = User::factory()->create();
        $log = SecurityAuditLog::factory()->create([
            'user_id' => $user->id,
        ]);

        $this->assertInstanceOf(User::class, $log->user);
        $this->assertEquals($user->id, $log->user->id);
    }

    /**
     * Test polymorphic auditable relationship
     */
    public function test_auditable_relationship(): void
    {
        $user = User::factory()->create();
        $log = SecurityAuditLog::factory()->create([
            'auditable_type' => User::class,
            'auditable_id' => $user->id,
        ]);

        $this->assertInstanceOf(User::class, $log->auditable);
        $this->assertEquals($user->id, $log->auditable->id);
    }

    /**
     * Test casting old_values to array
     */
    public function test_old_values_cast_to_array(): void
    {
        $log = SecurityAuditLog::factory()->create([
            'old_values' => ['status' => 'inactive', 'role' => 'user'],
        ]);

        $this->assertIsArray($log->old_values);
        $this->assertEquals('inactive', $log->old_values['status']);
        $this->assertEquals('user', $log->old_values['role']);
    }

    /**
     * Test casting new_values to array
     */
    public function test_new_values_cast_to_array(): void
    {
        $log = SecurityAuditLog::factory()->create([
            'new_values' => ['status' => 'active', 'role' => 'admin'],
        ]);

        $this->assertIsArray($log->new_values);
        $this->assertEquals('active', $log->new_values['status']);
        $this->assertEquals('admin', $log->new_values['role']);
    }

    /**
     * Test casting metadata to array
     */
    public function test_metadata_cast_to_array(): void
    {
        $log = SecurityAuditLog::factory()->create([
            'metadata' => ['ip' => '192.168.1.1', 'user_agent' => 'test'],
        ]);

        $this->assertIsArray($log->metadata);
        $this->assertEquals('192.168.1.1', $log->metadata['ip']);
        $this->assertEquals('test', $log->metadata['user_agent']);
    }

    /**
     * Test casting tags to array
     */
    public function test_tags_cast_to_array(): void
    {
        $log = SecurityAuditLog::factory()->create([
            'tags' => ['auth', 'login', 'success'],
        ]);

        $this->assertIsArray($log->tags);
        $this->assertEquals('auth', $log->tags[0]);
        $this->assertEquals('login', $log->tags[1]);
        $this->assertEquals('success', $log->tags[2]);
    }

    /**
     * Test scope critical
     */
    public function test_scope_critical(): void
    {
        SecurityAuditLog::factory()->create([
            'severity' => SecurityAuditLog::SEVERITY_CRITICAL,
        ]);

        SecurityAuditLog::factory()->create([
            'severity' => SecurityAuditLog::SEVERITY_LOW,
        ]);

        $criticalLogs = SecurityAuditLog::critical()->get();

        $this->assertCount(1, $criticalLogs);
        $this->assertEquals(SecurityAuditLog::SEVERITY_CRITICAL, $criticalLogs->first()->severity);
    }

    /**
     * Test scope high or above
     */
    public function test_scope_high_or_above(): void
    {
        SecurityAuditLog::factory()->create([
            'severity' => SecurityAuditLog::SEVERITY_CRITICAL,
        ]);

        SecurityAuditLog::factory()->create([
            'severity' => SecurityAuditLog::SEVERITY_HIGH,
        ]);

        SecurityAuditLog::factory()->create([
            'severity' => SecurityAuditLog::SEVERITY_LOW,
        ]);

        $highOrAbove = SecurityAuditLog::highOrAbove()->get();

        $this->assertCount(2, $highOrAbove);
    }

    /**
     * Test scope recent
     */
    public function test_scope_recent(): void
    {
        SecurityAuditLog::factory()->create([
            'created_at' => now()->subDays(3),
        ]);

        SecurityAuditLog::factory()->create([
            'created_at' => now()->subDays(10),
        ]);

        $recent = SecurityAuditLog::recent(7)->get();

        $this->assertCount(1, $recent);
    }

    /**
     * Test scope event type
     */
    public function test_scope_event_type(): void
    {
        SecurityAuditLog::factory()->create([
            'event_type' => SecurityAuditLog::EVENT_AUTH_LOGIN,
        ]);

        SecurityAuditLog::factory()->create([
            'event_type' => SecurityAuditLog::EVENT_AUTH_LOGOUT,
        ]);

        $loginLogs = SecurityAuditLog::eventType(SecurityAuditLog::EVENT_AUTH_LOGIN)->get();

        $this->assertCount(1, $loginLogs);
        $this->assertEquals(SecurityAuditLog::EVENT_AUTH_LOGIN, $loginLogs->first()->event_type);
    }

    /**
     * Test scope with tag
     */
    public function test_scope_with_tag(): void
    {
        SecurityAuditLog::factory()->create([
            'tags' => ['auth', 'login'],
        ]);

        SecurityAuditLog::factory()->create([
            'tags' => ['deployment', 'success'],
        ]);

        $authLogs = SecurityAuditLog::withTag('auth')->get();

        $this->assertCount(1, $authLogs);
        $this->assertContains('auth', $authLogs->first()->tags);
    }

    /**
     * Test scope with multiple tags
     */
    public function test_scope_with_multiple_tags(): void
    {
        SecurityAuditLog::factory()->create([
            'tags' => ['auth', 'login', 'success'],
        ]);

        SecurityAuditLog::factory()->create([
            'tags' => ['auth', 'logout'],
        ]);

        SecurityAuditLog::factory()->create([
            'tags' => ['deployment'],
        ]);

        $logs = SecurityAuditLog::withTag(['auth', 'login'])->get();

        $this->assertCount(2, $logs);
    }

    /**
     * Test static log method
     */
    public function test_static_log_method(): void
    {
        $this->actingAs(User::factory()->create());

        $log = SecurityAuditLog::log(
            'test.event',
            'Test event description',
            ['severity' => 'low']
        );

        $this->assertInstanceOf(SecurityAuditLog::class, $log);
        $this->assertDatabaseHas('security_audit_logs', [
            'event_type' => 'test.event',
            'description' => 'Test event description',
        ]);
    }

    /**
     * Test static log auth method
     */
    public function test_static_log_auth_method(): void
    {
        $log = SecurityAuditLog::logAuth(
            SecurityAuditLog::EVENT_AUTH_LOGIN,
            ['severity' => 'info']
        );

        $this->assertInstanceOf(SecurityAuditLog::class, $log);
        $this->assertEquals(SecurityAuditLog::EVENT_AUTH_LOGIN, $log->event_type);
        $this->assertStringContainsString('Authentication event:', $log->description);
    }

    /**
     * Test static log user method
     */
    public function test_static_log_user_method(): void
    {
        $user = User::factory()->create();

        $log = SecurityAuditLog::logUser(
            'user.created',
            $user,
            ['custom_field' => 'value']
        );

        $this->assertInstanceOf(SecurityAuditLog::class, $log);
        $this->assertEquals(User::class, $log->auditable_type);
        $this->assertEquals($user->id, $log->auditable_id);
        $this->assertEquals(SecurityAuditLog::SEVERITY_LOW, $log->severity);
    }

    /**
     * Test static alert method
     */
    public function test_static_alert_method(): void
    {
        $log = SecurityAuditLog::alert(
            'Security alert: Suspicious activity detected'
        );

        $this->assertInstanceOf(SecurityAuditLog::class, $log);
        $this->assertEquals(SecurityAuditLog::EVENT_SECURITY_ALERT, $log->event_type);
        $this->assertEquals(SecurityAuditLog::SEVERITY_HIGH, $log->severity);
        $this->assertContains('security-alert', $log->tags);
        $this->assertContains('auto-generated', $log->tags);
    }

    /**
     * Test get event types method
     */
    public function test_get_event_types(): void
    {
        $eventTypes = SecurityAuditLog::getEventTypes();

        $this->assertIsArray($eventTypes);
        $this->assertContains(SecurityAuditLog::EVENT_AUTH_LOGIN, $eventTypes);
        $this->assertContains(SecurityAuditLog::EVENT_AUTH_LOGOUT, $eventTypes);
        $this->assertContains(SecurityAuditLog::EVENT_USER_CREATED, $eventTypes);
        $this->assertContains(SecurityAuditLog::EVENT_CONTAINER_CREATED, $eventTypes);
    }

    /**
     * Test get severity levels method
     */
    public function test_get_severity_levels(): void
    {
        $levels = SecurityAuditLog::getSeverityLevels();

        $this->assertIsArray($levels);
        $this->assertContains(SecurityAuditLog::SEVERITY_INFO, $levels);
        $this->assertContains(SecurityAuditLog::SEVERITY_LOW, $levels);
        $this->assertContains(SecurityAuditLog::SEVERITY_MEDIUM, $levels);
        $this->assertContains(SecurityAuditLog::SEVERITY_HIGH, $levels);
        $this->assertContains(SecurityAuditLog::SEVERITY_CRITICAL, $levels);
    }

    /**
     * Test all event type constants are defined
     */
    public function test_all_event_type_constants_defined(): void
    {
        $this->assertEquals('auth.login', SecurityAuditLog::EVENT_AUTH_LOGIN);
        $this->assertEquals('auth.logout', SecurityAuditLog::EVENT_AUTH_LOGOUT);
        $this->assertEquals('auth.failed', SecurityAuditLog::EVENT_AUTH_FAILED);
        $this->assertEquals('auth.password_changed', SecurityAuditLog::EVENT_AUTH_PASSWORD_CHANGED);
        $this->assertEquals('auth.password_reset', SecurityAuditLog::EVENT_AUTH_PASSWORD_RESET);
        $this->assertEquals('user.created', SecurityAuditLog::EVENT_USER_CREATED);
        $this->assertEquals('user.updated', SecurityAuditLog::EVENT_USER_UPDATED);
        $this->assertEquals('user.deleted', SecurityAuditLog::EVENT_USER_DELETED);
        $this->assertEquals('user.role_changed', SecurityAuditLog::EVENT_USER_ROLE_CHANGED);
        $this->assertEquals('permission.granted', SecurityAuditLog::EVENT_PERMISSION_GRANTED);
        $this->assertEquals('permission.revoked', SecurityAuditLog::EVENT_PERMISSION_REVOKED);
        $this->assertEquals('container.created', SecurityAuditLog::EVENT_CONTAINER_CREATED);
        $this->assertEquals('container.updated', SecurityAuditLog::EVENT_CONTAINER_UPDATED);
        $this->assertEquals('container.deleted', SecurityAuditLog::EVENT_CONTAINER_DELETED);
        $this->assertEquals('container.deployed', SecurityAuditLog::EVENT_CONTAINER_DEPLOYED);
        $this->assertEquals('deployment.started', SecurityAuditLog::EVENT_DEPLOYMENT_STARTED);
        $this->assertEquals('deployment.completed', SecurityAuditLog::EVENT_DEPLOYMENT_COMPLETED);
        $this->assertEquals('deployment.failed', SecurityAuditLog::EVENT_DEPLOYMENT_FAILED);
        $this->assertEquals('deployment.rolled_back', SecurityAuditLog::EVENT_DEPLOYMENT_ROLLED_BACK);
        $this->assertEquals('security.scan', SecurityAuditLog::EVENT_SECURITY_SCAN);
        $this->assertEquals('security.alert', SecurityAuditLog::EVENT_SECURITY_ALERT);
        $this->assertEquals('security.vulnerability_found', SecurityAuditLog::EVENT_VULNERABILITY_FOUND);
        $this->assertEquals('config.changed', SecurityAuditLog::EVENT_CONFIG_CHANGED);
        $this->assertEquals('api_key.created', SecurityAuditLog::EVENT_API_KEY_CREATED);
        $this->assertEquals('api_key.deleted', SecurityAuditLog::EVENT_API_KEY_DELETED);
    }

    /**
     * Test fillable attributes
     */
    public function test_fillable_attributes(): void
    {
        $log = new SecurityAuditLog();

        $this->assertEquals([
            'event_type',
            'severity',
            'description',
            'user_id',
            'ip_address',
            'user_agent',
            'auditable_type',
            'auditable_id',
            'old_values',
            'new_values',
            'metadata',
            'tags',
        ], $log->getFillable());
    }

    /**
     * Test casts configuration
     */
    public function test_casts_configuration(): void
    {
        $log = new SecurityAuditLog();

        $this->assertEquals([
            'old_values' => 'array',
            'new_values' => 'array',
            'metadata' => 'array',
            'tags' => 'array',
            'created_at' => 'datetime',
        ], $log->getCasts());
    }
}

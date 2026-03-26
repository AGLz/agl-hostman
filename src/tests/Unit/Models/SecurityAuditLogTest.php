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
 */
class SecurityAuditLogTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();

        $this->user = User::factory()->create();
    }

    /**
     * Test creating a security audit log
     */
    public function test_create_security_audit_log(): void
    {
        $log = SecurityAuditLog::create([
            'event_type' => SecurityAuditLog::EVENT_AUTH_LOGIN,
            'severity' => SecurityAuditLog::SEVERITY_INFO,
            'description' => 'User logged in',
            'user_id' => $this->user->id,
            'ip_address' => '192.168.1.1',
            'user_agent' => 'Test Browser',
        ]);

        $this->assertDatabaseHas('security_audit_logs', [
            'event_type' => SecurityAuditLog::EVENT_AUTH_LOGIN,
            'user_id' => $this->user->id,
        ]);

        $this->assertEquals(SecurityAuditLog::EVENT_AUTH_LOGIN, $log->event_type);
        $this->assertEquals(SecurityAuditLog::SEVERITY_INFO, $log->severity);
        $this->assertEquals('User logged in', $log->description);
    }

    /**
     * Test log user relationship
     */
    public function test_log_belongs_to_user(): void
    {
        $log = SecurityAuditLog::create([
            'event_type' => SecurityAuditLog::EVENT_AUTH_LOGIN,
            'severity' => SecurityAuditLog::SEVERITY_INFO,
            'description' => 'User logged in',
            'user_id' => $this->user->id,
        ]);

        $this->assertInstanceOf(User::class, $log->user);
        $this->assertEquals($this->user->id, $log->user->id);
    }

    /**
     * Test log with auditable polymorphic relation
     */
    public function test_log_with_auditable(): void
    {
        $log = SecurityAuditLog::create([
            'event_type' => SecurityAuditLog::EVENT_USER_UPDATED,
            'severity' => SecurityAuditLog::SEVERITY_LOW,
            'description' => 'User updated',
            'user_id' => $this->user->id,
            'auditable_type' => User::class,
            'auditable_id' => $this->user->id,
            'old_values' => ['name' => 'Old Name'],
            'new_values' => ['name' => 'New Name'],
        ]);

        $this->assertEquals(User::class, $log->auditable_type);
        $this->assertEquals($this->user->id, $log->auditable_id);
        $this->assertIsArray($log->old_values);
        $this->assertIsArray($log->new_values);
    }

    /**
     * Test scope critical
     */
    public function test_scope_critical(): void
    {
        SecurityAuditLog::create([
            'event_type' => SecurityAuditLog::EVENT_SECURITY_ALERT,
            'severity' => SecurityAuditLog::SEVERITY_CRITICAL,
            'description' => 'Critical security event',
            'user_id' => $this->user->id,
        ]);

        SecurityAuditLog::create([
            'event_type' => SecurityAuditLog::EVENT_AUTH_LOGIN,
            'severity' => SecurityAuditLog::SEVERITY_INFO,
            'description' => 'User logged in',
            'user_id' => $this->user->id,
        ]);

        $criticalLogs = SecurityAuditLog::critical()->get();

        $this->assertCount(1, $criticalLogs);
        $this->assertEquals(SecurityAuditLog::SEVERITY_CRITICAL, $criticalLogs->first()->severity);
    }

    /**
     * Test scope highOrAbove
     */
    public function test_scope_high_or_above(): void
    {
        SecurityAuditLog::create([
            'event_type' => SecurityAuditLog::EVENT_SECURITY_ALERT,
            'severity' => SecurityAuditLog::SEVERITY_CRITICAL,
            'description' => 'Critical security event',
            'user_id' => $this->user->id,
        ]);

        SecurityAuditLog::create([
            'event_type' => SecurityAuditLog::EVENT_SECURITY_ALERT,
            'severity' => SecurityAuditLog::SEVERITY_HIGH,
            'description' => 'High security event',
            'user_id' => $this->user->id,
        ]);

        SecurityAuditLog::create([
            'event_type' => SecurityAuditLog::EVENT_AUTH_LOGIN,
            'severity' => SecurityAuditLog::SEVERITY_INFO,
            'description' => 'User logged in',
            'user_id' => $this->user->id,
        ]);

        $highOrAbove = SecurityAuditLog::highOrAbove()->get();

        $this->assertCount(2, $highOrAbove);
    }

    /**
     * Test scope recent
     */
    public function test_scope_recent(): void
    {
        SecurityAuditLog::create([
            'event_type' => SecurityAuditLog::EVENT_AUTH_LOGIN,
            'severity' => SecurityAuditLog::SEVERITY_INFO,
            'description' => 'User logged in',
            'user_id' => $this->user->id,
            'created_at' => now()->subDays(3),
        ]);

        SecurityAuditLog::create([
            'event_type' => SecurityAuditLog::EVENT_AUTH_LOGOUT,
            'severity' => SecurityAuditLog::SEVERITY_INFO,
            'description' => 'User logged out',
            'user_id' => $this->user->id,
            'created_at' => now()->subDays(10),
        ]);

        $recentLogs = SecurityAuditLog::recent(7)->get();

        $this->assertCount(1, $recentLogs);
        $this->assertEquals(SecurityAuditLog::EVENT_AUTH_LOGIN, $recentLogs->first()->event_type);
    }

    /**
     * Test scope eventType
     */
    public function test_scope_event_type(): void
    {
        SecurityAuditLog::create([
            'event_type' => SecurityAuditLog::EVENT_AUTH_LOGIN,
            'severity' => SecurityAuditLog::SEVERITY_INFO,
            'description' => 'User logged in',
            'user_id' => $this->user->id,
        ]);

        SecurityAuditLog::create([
            'event_type' => SecurityAuditLog::EVENT_AUTH_LOGOUT,
            'severity' => SecurityAuditLog::SEVERITY_INFO,
            'description' => 'User logged out',
            'user_id' => $this->user->id,
        ]);

        $loginLogs = SecurityAuditLog::eventType(SecurityAuditLog::EVENT_AUTH_LOGIN)->get();

        $this->assertCount(1, $loginLogs);
        $this->assertEquals(SecurityAuditLog::EVENT_AUTH_LOGIN, $loginLogs->first()->event_type);
    }

    /**
     * Test scope withTag
     */
    public function test_scope_with_tag(): void
    {
        SecurityAuditLog::create([
            'event_type' => SecurityAuditLog::EVENT_SECURITY_ALERT,
            'severity' => SecurityAuditLog::SEVERITY_HIGH,
            'description' => 'Security alert',
            'user_id' => $this->user->id,
            'tags' => ['security', 'alert', 'auto-generated'],
        ]);

        SecurityAuditLog::create([
            'event_type' => SecurityAuditLog::EVENT_AUTH_LOGIN,
            'severity' => SecurityAuditLog::SEVERITY_INFO,
            'description' => 'User logged in',
            'user_id' => $this->user->id,
            'tags' => ['auth', 'info'],
        ]);

        $securityLogs = SecurityAuditLog::withTag('security')->get();

        $this->assertCount(1, $securityLogs);
        $this->assertEquals(SecurityAuditLog::EVENT_SECURITY_ALERT, $securityLogs->first()->event_type);

        $authLogs = SecurityAuditLog::withTag(['auth', 'security'])->get();

        $this->assertCount(2, $authLogs);
    }

    /**
     * Test log static method
     */
    public function test_log_static_method(): void
    {
        $log = SecurityAuditLog::log(
            SecurityAuditLog::EVENT_AUTH_LOGIN,
            'User logged in successfully',
            [
                'severity' => SecurityAuditLog::SEVERITY_INFO,
                'user_id' => $this->user->id,
                'ip_address' => '192.168.1.1',
                'user_agent' => 'Test Browser',
                'metadata' => ['login_method' => 'password'],
            ]
        );

        $this->assertDatabaseHas('security_audit_logs', [
            'event_type' => SecurityAuditLog::EVENT_AUTH_LOGIN,
            'description' => 'User logged in successfully',
            'user_id' => $this->user->id,
        ]);

        $this->assertEquals('192.168.1.1', $log->ip_address);
        $this->assertEquals('Test Browser', $log->user_agent);
        $this->assertIsArray($log->metadata);
    }

    /**
     * Test logAuth static method
     */
    public function test_log_auth_static_method(): void
    {
        $log = SecurityAuditLog::logAuth(
            SecurityAuditLog::EVENT_AUTH_LOGIN,
            ['user_id' => $this->user->id]
        );

        $this->assertEquals(SecurityAuditLog::EVENT_AUTH_LOGIN, $log->event_type);
        $this->assertStringContainsString('Authentication event', $log->description);
    }

    /**
     * Test logUser static method
     */
    public function test_log_user_static_method(): void
    {
        $log = SecurityAuditLog::logUser(
            SecurityAuditLog::EVENT_USER_CREATED,
            $this->user,
            ['metadata' => ['created_by' => 'admin']]
        );

        $this->assertEquals(SecurityAuditLog::EVENT_USER_CREATED, $log->event_type);
        $this->assertEquals(User::class, $log->auditable_type);
        $this->assertEquals($this->user->id, $log->auditable_id);
        $this->assertEquals(SecurityAuditLog::SEVERITY_LOW, $log->severity);
    }

    /**
     * Test alert static method
     */
    public function test_alert_static_method(): void
    {
        $log = SecurityAuditLog::alert('Suspicious activity detected', [
            'user_id' => $this->user->id,
            'ip_address' => '192.168.1.100',
        ]);

        $this->assertEquals(SecurityAuditLog::EVENT_SECURITY_ALERT, $log->event_type);
        $this->assertEquals(SecurityAuditLog::SEVERITY_HIGH, $log->severity);
        $this->assertEquals('Suspicious activity detected', $log->description);
        $this->assertContains('security-alert', $log->tags);
        $this->assertContains('auto-generated', $log->tags);
    }

    /**
     * Test getEventTypes method
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
     * Test getSeverityLevels method
     */
    public function test_get_severity_levels(): void
    {
        $severityLevels = SecurityAuditLog::getSeverityLevels();

        $this->assertIsArray($severityLevels);
        $this->assertContains(SecurityAuditLog::SEVERITY_INFO, $severityLevels);
        $this->assertContains(SecurityAuditLog::SEVERITY_LOW, $severityLevels);
        $this->assertContains(SecurityAuditLog::SEVERITY_MEDIUM, $severityLevels);
        $this->assertContains(SecurityAuditLog::SEVERITY_HIGH, $severityLevels);
        $this->assertContains(SecurityAuditLog::SEVERITY_CRITICAL, $severityLevels);
    }

    /**
     * Test JSON casting for old_values and new_values
     */
    public function test_json_casting(): void
    {
        $oldValues = ['name' => 'Old Name', 'email' => 'old@example.com'];
        $newValues = ['name' => 'New Name', 'email' => 'new@example.com'];

        $log = SecurityAuditLog::create([
            'event_type' => SecurityAuditLog::EVENT_USER_UPDATED,
            'severity' => SecurityAuditLog::SEVERITY_LOW,
            'description' => 'User updated',
            'user_id' => $this->user->id,
            'old_values' => $oldValues,
            'new_values' => $newValues,
        ]);

        $this->assertIsArray($log->old_values);
        $this->assertIsArray($log->new_values);
        $this->assertEquals($oldValues, $log->old_values);
        $this->assertEquals($newValues, $log->new_values);
    }

    /**
     * Test JSON casting for metadata and tags
     */
    public function test_metadata_and_tags_casting(): void
    {
        $metadata = ['key1' => 'value1', 'key2' => 'value2'];
        $tags = ['tag1', 'tag2', 'tag3'];

        $log = SecurityAuditLog::create([
            'event_type' => SecurityAuditLog::EVENT_AUTH_LOGIN,
            'severity' => SecurityAuditLog::SEVERITY_INFO,
            'description' => 'User logged in',
            'user_id' => $this->user->id,
            'metadata' => $metadata,
            'tags' => $tags,
        ]);

        $this->assertIsArray($log->metadata);
        $this->assertIsArray($log->tags);
        $this->assertEquals($metadata, $log->metadata);
        $this->assertEquals($tags, $log->tags);
    }
}

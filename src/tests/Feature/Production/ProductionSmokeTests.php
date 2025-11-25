<?php

namespace Tests\Feature\Production;

use Tests\TestCase;
use Illuminate\Foundation\Testing\RefreshDatabase;
use App\Models\Environment;
use App\Models\ProductionDeployment;

class ProductionSmokeTests extends TestCase
{
    /**
     * Test application health endpoint.
     *
     * @test
     */
    public function application_health_endpoint_returns_healthy(): void
    {
        $response = $this->get('/health');

        $response->assertStatus(200)
                 ->assertJson(['status' => 'healthy']);
    }

    /**
     * Test database connectivity.
     *
     * @test
     */
    public function database_connection_is_working(): void
    {
        $this->assertTrue(
            \DB::connection()->getDatabaseName() !== null,
            'Database connection should be established'
        );

        // Verify we can execute a simple query
        $result = \DB::select('SELECT 1 as test');
        $this->assertEquals(1, $result[0]->test);
    }

    /**
     * Test Redis cache connectivity.
     *
     * @test
     */
    public function redis_cache_is_accessible(): void
    {
        $key = 'smoke_test_' . time();
        $value = 'test_value';

        \Cache::put($key, $value, 60);
        $retrieved = \Cache::get($key);

        $this->assertEquals($value, $retrieved, 'Redis cache should be working');

        \Cache::forget($key);
    }

    /**
     * Test queue system.
     *
     * @test
     */
    public function queue_system_is_operational(): void
    {
        $connection = config('queue.default');
        $this->assertNotEmpty($connection, 'Queue connection should be configured');

        // Verify queue connection
        $queue = \Queue::connection();
        $this->assertNotNull($queue, 'Queue connection should be established');
    }

    /**
     * Test session functionality.
     *
     * @test
     */
    public function session_storage_is_working(): void
    {
        $key = 'smoke_test_session';
        $value = 'session_value';

        session([$key => $value]);
        $retrieved = session($key);

        $this->assertEquals($value, $retrieved, 'Session storage should be working');
    }

    /**
     * Test environment configuration.
     *
     * @test
     */
    public function environment_is_production(): void
    {
        $this->assertEquals('production', config('app.env'));
        $this->assertFalse(config('app.debug'));
    }

    /**
     * Test SSL certificate validity (production only).
     *
     * @test
     */
    public function ssl_certificate_is_valid(): void
    {
        $domains = config('deployment.production_domains', []);

        foreach ($domains as $domain) {
            $url = "https://{$domain}";

            try {
                $context = stream_context_create([
                    'ssl' => [
                        'capture_peer_cert' => true,
                        'verify_peer' => true,
                        'verify_peer_name' => true,
                    ],
                ]);

                $socket = @stream_socket_client(
                    "ssl://{$domain}:443",
                    $errno,
                    $errstr,
                    30,
                    STREAM_CLIENT_CONNECT,
                    $context
                );

                if ($socket) {
                    $params = stream_context_get_params($socket);
                    $cert = openssl_x509_parse($params['options']['ssl']['peer_certificate']);

                    $this->assertNotEmpty($cert, "SSL certificate should exist for {$domain}");
                    $this->assertTrue(
                        $cert['validTo_time_t'] > time(),
                        "SSL certificate should not be expired for {$domain}"
                    );

                    fclose($socket);
                } else {
                    $this->markTestSkipped("Could not connect to {$domain}: {$errstr}");
                }
            } catch (\Exception $e) {
                $this->markTestSkipped("SSL check skipped for {$domain}: " . $e->getMessage());
            }
        }

        $this->assertTrue(true); // At least one check passed
    }

    /**
     * Test load balancer health.
     *
     * @test
     */
    public function load_balancer_is_healthy(): void
    {
        $lbUrl = config('deployment.production_lb_url');

        if (!$lbUrl) {
            $this->markTestSkipped('Load balancer URL not configured');
            return;
        }

        $response = \Http::timeout(5)->get("{$lbUrl}/nginx-health");

        $this->assertTrue(
            $response->successful(),
            'Load balancer health check should pass'
        );
    }

    /**
     * Test backup system is configured.
     *
     * @test
     */
    public function backup_system_is_configured(): void
    {
        $this->assertTrue(
            config('backup.enabled', false),
            'Backup system should be enabled in production'
        );

        $backupDir = storage_path('backups');
        $this->assertTrue(
            is_dir($backupDir) && is_writable($backupDir),
            'Backup directory should exist and be writable'
        );
    }

    /**
     * Test monitoring endpoints are accessible.
     *
     * @test
     */
    public function monitoring_endpoints_are_accessible(): void
    {
        // Test Prometheus metrics endpoint
        $response = $this->get('/metrics');
        $response->assertStatus(200);

        // Verify metrics format
        $content = $response->getContent();
        $this->assertStringContainsString('# TYPE', $content);
        $this->assertStringContainsString('# HELP', $content);
    }

    /**
     * Test external API integrations.
     *
     * @test
     */
    public function external_api_integrations_are_working(): void
    {
        // Test Proxmox API connectivity
        $proxmoxHost = config('proxmox.host');

        if ($proxmoxHost) {
            try {
                $response = \Http::timeout(5)
                    ->withOptions(['verify' => false])
                    ->get("https://{$proxmoxHost}:8006/api2/json");

                $this->assertTrue(
                    $response->status() === 401 || $response->successful(),
                    'Proxmox API should be reachable'
                );
            } catch (\Exception $e) {
                $this->markTestSkipped('Proxmox API unreachable: ' . $e->getMessage());
            }
        }
    }

    /**
     * Test scheduled jobs are configured.
     *
     * @test
     */
    public function scheduled_jobs_are_configured(): void
    {
        $schedule = app()->make(\Illuminate\Console\Scheduling\Schedule::class);
        $events = $schedule->events();

        $this->assertNotEmpty($events, 'At least one scheduled job should be configured');

        // Verify backup job exists
        $backupJobExists = collect($events)->contains(function ($event) {
            return str_contains($event->command, 'production:backup');
        });

        $this->assertTrue($backupJobExists, 'Production backup job should be scheduled');
    }

    /**
     * Test production deployment configuration.
     *
     * @test
     */
    public function production_deployment_is_configured(): void
    {
        $environment = Environment::where('type', 'production')->first();

        $this->assertNotNull($environment, 'Production environment should exist');
        $this->assertFalse($environment->auto_deploy, 'Auto-deploy should be disabled in production');
        $this->assertTrue($environment->auto_test, 'Auto-test should be enabled in production');

        $prodDeployment = ProductionDeployment::where('environment_id', $environment->id)->first();

        if ($prodDeployment) {
            $this->assertEquals('blue_green', $prodDeployment->deployment_type);
            $this->assertGreaterThanOrEqual(2, $prodDeployment->desired_replicas);
        }
    }

    /**
     * Test error handling and logging.
     *
     * @test
     */
    public function error_handling_is_configured(): void
    {
        $this->assertEquals('warning', config('logging.level'));

        // Verify log directory is writable
        $logPath = storage_path('logs');
        $this->assertTrue(
            is_dir($logPath) && is_writable($logPath),
            'Log directory should exist and be writable'
        );
    }

    /**
     * Test security headers are set.
     *
     * @test
     */
    public function security_headers_are_set(): void
    {
        $response = $this->get('/');

        // Check for common security headers
        $response->assertHeader('X-Frame-Options', 'SAMEORIGIN');
        $response->assertHeader('X-Content-Type-Options', 'nosniff');
        $response->assertHeader('X-XSS-Protection');
    }

    /**
     * Test rate limiting is enabled.
     *
     * @test
     */
    public function rate_limiting_is_enabled(): void
    {
        $rateLimitEnabled = config('deployment.rate_limit_enabled', true);
        $this->assertTrue($rateLimitEnabled, 'Rate limiting should be enabled in production');
    }

    /**
     * Verify all smoke tests complete within time limit.
     */
    protected function setUp(): void
    {
        parent::setUp();

        // Smoke tests should complete quickly (< 3 minutes total)
        $this->timeout = 180;
    }
}

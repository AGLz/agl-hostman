<?php

declare(strict_types=1);

use App\Services\N8NService;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

describe('N8NService monitoring helpers', function () {
    it('skips triggerMonitoring when workflow id is not configured', function () {
        Config::set('n8n.workflows.monitoring', null);
        Log::shouldReceive('info')->once();

        $result = (new N8NService)->triggerMonitoring(['AGLSRV1']);

        expect($result['skipped'])->toBeTrue();
    });

    it('executes monitoring workflow when configured', function () {
        Config::set('n8n.api_url', 'http://n8n.test');
        Config::set('n8n.workflows.monitoring', 'infra-monitor');

        Http::fake([
            'http://n8n.test/webhook/infra-monitor' => Http::response(['ok' => true], 200),
        ]);

        $result = (new N8NService)->triggerMonitoring(['AGLSRV1']);

        expect($result['success'])->toBeTrue();
    });
});

describe('BackupService database dump', function () {
    it('reports unsupported driver without executing dump', function () {
        Config::set('backup.databases', ['legacy']);
        Config::set('database.connections.legacy', [
            'driver' => 'sqlsrv',
            'host' => '127.0.0.1',
        ]);

        $service = new \App\Services\BackupService;
        $method = new ReflectionMethod($service, 'backupDatabases');
        $method->setAccessible(true);

        $temp = sys_get_temp_dir().'/backup-test-'.uniqid();
        mkdir($temp);

        $results = $method->invoke($service, $temp);

        expect($results['legacy']['success'])->toBeFalse()
            ->and($results['legacy']['error'])->toContain('Unsupported driver');

        @rmdir($temp);
    });

    it('cleanOldBackups does not throw on empty backup dir', function () {
        $temp = sys_get_temp_dir().'/backup-clean-'.uniqid();
        mkdir($temp);

        Config::set('backup.path', $temp);
        Config::set('backup.retention', 7);

        $service = new \App\Services\BackupService;
        $method = new ReflectionMethod($service, 'cleanOldBackups');
        $method->setAccessible(true);
        $method->invoke($service);

        expect(true)->toBeTrue();
        @rmdir($temp);
    });
});

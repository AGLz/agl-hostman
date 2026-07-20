<?php

declare(strict_types=1);

namespace App\Services\MissionControl;

use App\Services\Proxmox\ProxmoxApiClient;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Throwable;

final class MissionControlSnapshotService
{
    public function __construct(
        private readonly ?ProxmoxApiClient $proxmox = null,
    ) {}

    /**
     * @return array<string, mixed>|null
     */
    public function getHostSnapshot(string $code, bool $forceRefresh = false): ?array
    {
        $host = $this->hostConfig($code);
        if ($host === null) {
            return null;
        }

        $cacheKey = "mission_control_host_{$code}";
        $ttl = (int) config('mission-control.cache_ttl', 45);

        if ($forceRefresh) {
            Cache::forget($cacheKey);
        }

        return Cache::remember($cacheKey, $ttl, fn (): array => $this->buildSnapshot($host));
    }

    /**
     * @return list<array<string, mixed>>
     */
    public function getHostGuests(string $code): ?array
    {
        $snapshot = $this->getHostSnapshot($code);
        if ($snapshot === null) {
            return null;
        }

        return $snapshot['guests'];
    }

    /**
     * @param  array<string, mixed>  $host
     * @return array<string, mixed>
     */
    private function buildSnapshot(array $host): array
    {
        $code = (string) $host['code'];
        $services = $this->probeServices($code);
        [$guests, $proxmoxOk] = $this->buildGuests($code, $services);
        $alerts = $this->evaluateRunbooks($services, $guests);

        $healthOk = count(array_filter($services, static fn (array $s): bool => $s['health'] === 'ok'));
        $healthDown = count(array_filter($services, static fn (array $s): bool => $s['health'] === 'down'));
        $running = count(array_filter($guests, static fn (array $g): bool => $g['status'] === 'running'));
        $stopped = count(array_filter($guests, static fn (array $g): bool => $g['status'] === 'stopped'));

        return [
            'checked_at' => now()->toIso8601String(),
            'host' => $host,
            'summary' => [
                'guests_total' => count($guests),
                'guests_running' => $running,
                'guests_stopped' => $stopped,
                'services_total' => count($services),
                'services_ok' => $healthOk,
                'services_down' => $healthDown,
                'alerts_total' => count($alerts),
                'semaphore' => $this->hostSemaphore($healthDown, $stopped, $alerts),
            ],
            'guests' => $guests,
            'services' => array_values($services),
            'alerts' => $alerts,
            'sources' => [
                'registry' => true,
                'proxmox' => $proxmoxOk,
                'health_probes' => (bool) config('mission-control.probe_health', true),
            ],
            'poll_interval_ms' => (int) config('mission-control.poll_interval_ms', 45000),
        ];
    }

    /**
     * @return array<string, array<string, mixed>>
     */
    private function probeServices(string $hostCode): array
    {
        $all = config('mission-control.services', []);
        $timeout = (int) config('mission-control.health_timeout', 3);
        $probe = (bool) config('mission-control.probe_health', true);
        $result = [];

        foreach ($all as $key => $service) {
            if (($service['host'] ?? '') !== $hostCode) {
                continue;
            }

            $entry = [
                'key' => $key,
                'name' => $service['name'] ?? $key,
                'vmid' => $service['vmid'] ?? null,
                'category' => $service['category'] ?? 'other',
                'health_url' => $service['health_url'] ?? null,
                'runbook' => $service['runbook'] ?? null,
                'priority' => (bool) ($service['priority'] ?? false),
                'health' => 'unknown',
                'http_status' => null,
                'latency_ms' => null,
            ];

            if (! $probe || empty($service['health_url'])) {
                $result[$key] = $entry;

                continue;
            }

            $accept = $service['accept_statuses'] ?? [200];
            $started = hrtime(true);

            try {
                $url = (string) $service['health_url'];
                // Reason: HTTPS público valida TLS; HTTP LAN/Tailscale sem verify
                $response = Http::timeout($timeout)
                    ->withOptions(['verify' => str_starts_with($url, 'https://')])
                    ->get($url);
                $entry['http_status'] = $response->status();
                $entry['latency_ms'] = (int) round((hrtime(true) - $started) / 1_000_000);
                $entry['health'] = in_array($response->status(), $accept, true) ? 'ok' : 'down';
            } catch (Throwable $e) {
                $entry['latency_ms'] = (int) round((hrtime(true) - $started) / 1_000_000);
                $entry['health'] = 'down';
                $entry['error'] = $e->getMessage();
            }

            $result[$key] = $entry;
        }

        return $result;
    }

    /**
     * @param  array<string, array<string, mixed>>  $services
     * @return array{0: list<array<string, mixed>>, 1: bool}
     */
    private function buildGuests(string $hostCode, array $services): array
    {
        $registry = array_values(array_filter(
            config('mission-control.guests', []),
            static fn (array $g): bool => ($g['host'] ?? '') === $hostCode,
        ));

        $proxmoxByVmid = $this->fetchProxmoxGuests($hostCode);
        $proxmoxOk = $proxmoxByVmid !== [];
        $healthByVmid = [];
        foreach ($services as $service) {
            $vmid = $service['vmid'] ?? null;
            if ($vmid === null) {
                continue;
            }
            $healthByVmid[(int) $vmid][] = $service['health'];
        }

        $guests = [];
        foreach ($registry as $guest) {
            $vmid = (int) $guest['vmid'];
            $px = $proxmoxByVmid[$vmid] ?? null;
            $status = $px['status'] ?? 'unknown';
            $health = $this->aggregateHealth($healthByVmid[$vmid] ?? []);

            $guests[] = [
                'vmid' => $vmid,
                'type' => $guest['type'] ?? ($px['type'] ?? 'lxc'),
                'name' => $guest['name'] ?? ($px['name'] ?? "guest-{$vmid}"),
                'category' => $guest['category'] ?? 'other',
                'status' => $status,
                'health' => $health,
                'semaphore' => $this->guestSemaphore($status, $health),
                'cpu' => $px['cpu'] ?? null,
                'mem' => $px['mem'] ?? null,
                'maxmem' => $px['maxmem'] ?? null,
                'proxmox' => $px !== null,
                'priority' => $this->isPriorityVmid($vmid, $services),
            ];
        }

        // Reason: incluir guests Proxmox não listados no registry (inventário vivo)
        foreach ($proxmoxByVmid as $vmid => $px) {
            if (collect($guests)->contains(fn (array $g): bool => $g['vmid'] === $vmid)) {
                continue;
            }
            $guests[] = [
                'vmid' => $vmid,
                'type' => $px['type'],
                'name' => $px['name'],
                'category' => 'other',
                'status' => $px['status'],
                'health' => 'unknown',
                'semaphore' => $this->guestSemaphore($px['status'], 'unknown'),
                'cpu' => $px['cpu'],
                'mem' => $px['mem'],
                'maxmem' => $px['maxmem'],
                'proxmox' => true,
                'priority' => false,
            ];
        }

        usort($guests, static fn (array $a, array $b): int => $a['vmid'] <=> $b['vmid']);

        return [$guests, $proxmoxOk];
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function fetchProxmoxGuests(string $hostCode): array
    {
        if (! config('mission-control.probe_proxmox', true) || $this->proxmox === null) {
            return [];
        }

        try {
            $response = $this->proxmox->get('/cluster/resources');
            if (! $response->success || ! is_array($response->data)) {
                return [];
            }

            $node = (string) (config("mission-control.hosts.{$hostCode}.node") ?? '');
            $map = [];

            foreach ($response->data as $row) {
                if (! is_array($row)) {
                    continue;
                }
                $type = (string) ($row['type'] ?? '');
                if (! in_array($type, ['lxc', 'qemu'], true)) {
                    continue;
                }
                if ($node !== '' && isset($row['node']) && (string) $row['node'] !== $node) {
                    continue;
                }
                $vmid = (int) ($row['vmid'] ?? 0);
                if ($vmid <= 0) {
                    continue;
                }
                $map[$vmid] = [
                    'type' => $type,
                    'name' => (string) ($row['name'] ?? "guest-{$vmid}"),
                    'status' => (string) ($row['status'] ?? 'unknown'),
                    'cpu' => isset($row['cpu']) ? round((float) $row['cpu'] * 100, 1) : null,
                    'mem' => isset($row['mem']) ? (int) $row['mem'] : null,
                    'maxmem' => isset($row['maxmem']) ? (int) $row['maxmem'] : null,
                ];
            }

            return $map;
        } catch (Throwable $e) {
            Log::warning('Mission Control: Proxmox probe failed', [
                'host' => $hostCode,
                'error' => $e->getMessage(),
            ]);

            return [];
        }
    }

    /**
     * @param  array<string, array<string, mixed>>  $services
     * @param  list<array<string, mixed>>  $guests
     * @return list<array<string, mixed>>
     */
    private function evaluateRunbooks(array $services, array $guests): array
    {
        $alerts = [];

        foreach (config('mission-control.runbook_rules', []) as $rule) {
            if (! is_array($rule) || ! $this->ruleMatches($rule, $services, $guests)) {
                continue;
            }
            $alerts[] = [
                'id' => $rule['id'] ?? uniqid('rule_', true),
                'severity' => $rule['severity'] ?? 'warning',
                'title' => $rule['title'] ?? 'Alerta',
                'runbook' => $rule['runbook'] ?? null,
            ];
        }

        return $alerts;
    }

    /**
     * @param  array<string, mixed>  $rule
     * @param  array<string, array<string, mixed>>  $services
     * @param  list<array<string, mixed>>  $guests
     */
    private function ruleMatches(array $rule, array $services, array $guests): bool
    {
        $when = $rule['when'] ?? [];
        if (! is_array($when) || $when === []) {
            return false;
        }

        if (isset($when['service'], $when['health'])) {
            $svc = $services[$when['service']] ?? null;

            return $svc !== null && ($svc['health'] ?? null) === $when['health'];
        }

        if (isset($when['any_service'], $when['health']) && is_array($when['any_service'])) {
            foreach ($when['any_service'] as $key) {
                if (($services[$key]['health'] ?? null) === $when['health']) {
                    return true;
                }
            }

            return false;
        }

        if (isset($when['vmid'], $when['guest_status'])) {
            $guest = collect($guests)->firstWhere('vmid', (int) $when['vmid']);
            if ($guest === null) {
                return false;
            }
            $allowed = is_array($when['guest_status']) ? $when['guest_status'] : [$when['guest_status']];

            return in_array($guest['status'], $allowed, true);
        }

        if (! empty($when['priority_guest_stopped'])) {
            return collect($guests)->contains(
                static fn (array $g): bool => ($g['priority'] ?? false) && ($g['status'] ?? '') === 'stopped',
            );
        }

        return false;
    }

    /**
     * @return array<string, mixed>|null
     */
    private function hostConfig(string $code): ?array
    {
        $host = config("mission-control.hosts.{$code}");

        return is_array($host) ? $host : null;
    }

    /**
     * @param  list<string>  $healths
     */
    private function aggregateHealth(array $healths): string
    {
        if ($healths === []) {
            return 'unknown';
        }
        if (in_array('down', $healths, true)) {
            return 'down';
        }
        if (in_array('ok', $healths, true)) {
            return 'ok';
        }

        return 'unknown';
    }

    private function guestSemaphore(string $status, string $health): string
    {
        if ($status === 'stopped' || $health === 'down') {
            return 'red';
        }
        if ($status === 'running' && $health === 'ok') {
            return 'green';
        }
        if ($status === 'running') {
            return 'yellow';
        }

        return 'gray';
    }

    /**
     * @param  list<array<string, mixed>>  $alerts
     */
    private function hostSemaphore(int $healthDown, int $stopped, array $alerts): string
    {
        $critical = collect($alerts)->contains(fn (array $a): bool => ($a['severity'] ?? '') === 'critical');
        if ($critical || $healthDown > 0) {
            return 'red';
        }
        if ($stopped > 0 || $alerts !== []) {
            return 'yellow';
        }

        return 'green';
    }

    /**
     * @param  array<string, array<string, mixed>>  $services
     */
    private function isPriorityVmid(int $vmid, array $services): bool
    {
        foreach ($services as $service) {
            if ((int) ($service['vmid'] ?? 0) === $vmid && ($service['priority'] ?? false)) {
                return true;
            }
        }

        return in_array($vmid, [186, 187, 188, 182, 180, 134], true);
    }

}

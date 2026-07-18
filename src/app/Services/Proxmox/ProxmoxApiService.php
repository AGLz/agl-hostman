<?php

namespace App\Services\Proxmox;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Cache;
use Carbon\Carbon;

/**
 * Service for interacting with Proxmox VE API
 */
class ProxmoxApiService
{
    protected string $baseUrl;
    protected string $username;
    protected string $password;
    protected string $realm;
    protected ?string $apiToken;
    protected bool $useApiToken;
    protected int $timeout;
    protected bool $verifySsl;

    public function __construct()
    {
        $this->baseUrl = config('proxmox.url', 'https://localhost:8006');
        $this->username = config('proxmox.username', 'root@pam');
        $this->password = config('proxmox.password', '');
        $this->realm = config('proxmox.realm', 'pam');
        $this->apiToken = config('proxmox.api_token');
        $this->useApiToken = !empty($this->apiToken);
        $this->timeout = config('proxmox.timeout', 30);
        $this->verifySsl = config('proxmox.verify_ssl', true);
    }

    /**
     * Create a new container
     */
    public function createContainer(array $data): array
    {
        $node = $data['node'];
        $vmid = $data['vmid'];

        $requestBody = [
            'vmid' => $vmid,
            'hostname' => $data['hostname'],
            'cores' => $data['cores'],
            'memory' => $data['memory_mb'],
            'rootfs' => $this->buildRootfs($data),
            'ostype' => $data['ostype'],
            'password' => $data['password'] ?? '',
            'sshkey' => $data['ssh_key'] ?? '',
            'start' => $data['start'] ?? 0,
            'unprivileged' => $data['unprivileged'] ? 1 : 0,
            'features' => $this->buildFeatures($data['features'] ?? []),
            'net0' => $this->buildNetworkConfig($data['network'] ?? []),
        ];

        // Add template if specified
        if (!empty($data['template'])) {
            $requestBody['template'] = $data['template'];
        }

        $response = $this->post("/nodes/{$node}/lxc", $requestBody);

        Log::info('Container creation initiated via Proxmox API', [
            'node' => $node,
            'vmid' => $vmid,
            'hostname' => $data['hostname'],
            'response' => $response,
        ]);

        return [
            'node' => $node,
            'vmid' => $vmid,
            'status' => 'pending',
            'message' => 'Container creation initiated',
            'api_response' => $response,
            'created_at' => now()->toISOString(),
        ];
    }

    /**
     * Get container status
     */
    public function getContainerStatus(int $vmid, string $node): array
    {
        $cacheKey = "proxmox_container_status_{$node}_{$vmid}";

        return Cache::remember($cacheKey, 60, function () use ($vmid, $node) {
            try {
                $response = $this->get("/nodes/{$node}/lxc/{$vmid}/status/current");

                return [
                    'status' => $response['status'] ?? 'unknown',
                    'uptime' => $response['uptime'] ?? 0,
                    'cpu' => $response['cpu'] ?? 0,
                    'mem' => $response['mem'] ?? 0,
                    'disk' => $response['disk'] ?? 0,
                    'maxmem' => $response['maxmem'] ?? 0,
                    'maxdisk' => $response['maxdisk'] ?? 0,
                    'netin' => $response['netin'] ?? 0,
                    'netout' => $response['netout'] ?? 0,
                    'diskread' => $response['diskread'] ?? 0,
                    'diskwrite' => $response['diskwrite'] ?? 0,
                    'raw' => $response,
                    'last_updated' => now()->toISOString(),
                ];
            } catch (\Exception $e) {
                Log::error('Failed to get container status', [
                    'error' => $e->getMessage(),
                    'node' => $node,
                    'vmid' => $vmid,
                ]);

                return [
                    'status' => 'error',
                    'error' => $e->getMessage(),
                    'last_updated' => now()->toISOString(),
                ];
            }
        });
    }

    /**
     * Start container
     */
    public function startContainer(int $vmid, string $node): array
    {
        $response = $this->post("/nodes/{$node}/lxc/{$vmid}/status/start", [
            'timeout' => $this->timeout,
        ]);

        return [
            'vmid' => $vmid,
            'node' => $node,
            'action' => 'start',
            'response' => $response,
            'timestamp' => now()->toISOString(),
        ];
    }

    /**
     * Stop container
     */
    public function stopContainer(int $vmid, string $node, bool $force = false): array
    {
        $response = $this->post("/nodes/{$node}/lxc/{$vmid}/status/stop", [
            'timeout' => $this->timeout,
            'force' => $force ? 1 : 0,
        ]);

        return [
            'vmid' => $vmid,
            'node' => $node,
            'action' => 'stop',
            'force' => $force,
            'response' => $response,
            'timestamp' => now()->toISOString(),
        ];
    }

    /**
     * Restart container
     */
    public function restartContainer(int $vmid, string $node): array
    {
        $response = $this->post("/nodes/{$node}/lxc/{$vmid}/status/reboot", [
            'timeout' => $this->timeout,
        ]);

        return [
            'vmid' => $vmid,
            'node' => $node,
            'action' => 'restart',
            'response' => $response,
            'timestamp' => now()->toISOString(),
        ];
    }

    /**
     * Delete container
     */
    public function deleteContainer(int $vmid, string $node): array
    {
        try {
            // First stop the container if it's running
            $this->stopContainer($vmid, $node, true);

            $response = $this->delete("/nodes/{$node}/lxc/{$vmid}");

            return [
                'vmid' => $vmid,
                'node' => $node,
                'action' => 'delete',
                'response' => $response,
                'timestamp' => now()->toISOString(),
            ];
        } catch (\Exception $e) {
            Log::error('Failed to delete container', [
                'error' => $e->getMessage(),
                'node' => $node,
                'vmid' => $vmid,
            ]);

            throw $e;
        }
    }

    /**
     * Clone container
     */
    public function cloneContainer(int $sourceVmid, string $sourceNode, string $targetNode, int $targetVmid, array $options): array
    {
        $requestBody = [
            'vmid' => $targetVmid,
            'node' => $targetNode,
            'target' => $targetNode,
            'source' => $sourceNode,
            'storage' => $options['storage'] ?? 'local',
            'format' => $options['format'] ?? 'qcow2',
            'full' => $options['full'] ?? 1,
            'compress' => $options['compress'] ?? '0',
            'bwlimit' => $options['bwlimit'] ?? 0,
            'pool' => $options['pool'] ?? '',
            'description' => $options['description'] ?? '',
        ];

        if (!empty($options['target_hostname'])) {
            $requestBody['hostname'] = $options['target_hostname'];
        }

        $response = $this->post("/nodes/{$sourceNode}/lxc/{$sourceVmid}/clone", $requestBody);

        return [
            'source_vmid' => $sourceVmid,
            'source_node' => $sourceNode,
            'target_vmid' => $targetVmid,
            'target_node' => $targetNode,
            'options' => $options,
            'response' => $response,
            'timestamp' => now()->toISOString(),
        ];
    }

    /**
     * Migrate container
     */
    public function migrateContainer(int $vmid, string $sourceNode, string $targetNode, array $options): array
    {
        $requestBody = [
            'target' => $targetNode,
            'online' => $options['online'] ?? 1,
            'migration_network' => $options['migration_network'] ?? '',
            'bwlimit' => $options['bwlimit'] ?? 0,
            'compression' => $options['compression'] ?? '0',
            'ssh' => $options['ssh'] ?? 1,
            'storage' => $options['storage'] ?? '',
            'targetstorage' => $options['targetstorage'] ?? '',
            'targetdisk' => $options['targetdisk'] ?? '',
        ];

        $response = $this->post("/nodes/{$sourceNode}/lxc/{$vmid}/migrate", $requestBody);

        return [
            'vmid' => $vmid,
            'source_node' => $sourceNode,
            'target_node' => $targetNode,
            'options' => $options,
            'response' => $response,
            'timestamp' => now()->toISOString(),
        ];
    }

    /**
     * Backup container
     */
    public function backupContainer(int $vmid, string $node, array $options): array
    {
        $requestBody = [
            'storage' => $options['storage'],
            'vmid' => $vmid,
            'mode' => $options['mode'],
            'compress' => $options['compress'] ?? '0',
            'storage' => $options['storage'],
            'target' => $options['target'] ?? '',
            'filename' => $options['filename'] ?? '',
            'notes' => $options['notes'] ?? '',
        ];

        $response = $this->post("/nodes/{$node}/lxc/{$vmid}/snapshot", $requestBody);

        return [
            'vmid' => $vmid,
            'node' => $node,
            'options' => $options,
            'response' => $response,
            'timestamp' => now()->toISOString(),
        ];
    }

    /**
     * Create snapshot
     */
    public function createSnapshot(int $vmid, string $node, string $name, array $options): array
    {
        $requestBody = [
            'vmid' => $vmid,
            'snapname' => $name,
            'description' => $options['description'] ?? '',
            'parent' => $options['parent'] ?? '',
            'storage' => $options['storage'] ?? '',
        ];

        $response = $this->post("/nodes/{$node}/lxc/{$vmid}/snapshot", $requestBody);

        return [
            'vmid' => $vmid,
            'node' => $node,
            'name' => $name,
            'options' => $options,
            'response' => $response,
            'timestamp' => now()->toISOString(),
        ];
    }

    /**
     * Restore snapshot
     */
    public function restoreSnapshot(int $vmid, string $node, string $snapshot): array
    {
        $response = $this->post("/nodes/{$node}/lxc/{$vmid}/snapshot/{$snapshot}/rollback", [
            'timeout' => $this->timeout,
        ]);

        return [
            'vmid' => $vmid,
            'node' => $node,
            'snapshot' => $snapshot,
            'response' => $response,
            'timestamp' => now()->toISOString(),
        ];
    }

    /**
     * List all containers
     */
    public function listContainers(string $node = ''): array
    {
        $cacheKey = "proxmox_containers_" . ($node ?: 'all');
        $cacheTime = config('proxmox.cache_ttl', 30); // 30 seconds

        return Cache::remember($cacheKey, $cacheTime, function () use ($node) {
            try {
                $endpoint = $node ? "/nodes/{$node}/lxc" : '/lxc';
                $response = $this->get($endpoint);

                return array_map(function ($container) {
                    return [
                        'vmid' => $container['vmid'] ?? 0,
                        'name' => $container['name'] ?? '',
                        'node' => $container['node'] ?? '',
                        'type' => $container['type'] ?? '',
                        'status' => $container['status'] ?? '',
                        'cpu' => $container['cpu'] ?? 0,
                        'mem' => $container['mem'] ?? 0,
                        'maxmem' => $container['maxmem'] ?? 0,
                        'disk' => $container['disk'] ?? 0,
                        'maxdisk' => $container['maxdisk'] ?? 0,
                        'uptime' => $container['uptime'] ?? 0,
                        'template' => $container['template'] ?? null,
                        'tags' => $container['tags'] ?? '',
                        'lock' => $container['lock'] ?? 'false',
                    ];
                }, $response);
            } catch (\Exception $e) {
                Log::error('Failed to list containers', [
                    'error' => $e->getMessage(),
                    'node' => $node,
                ]);

                return [];
            }
        });
    }

    /**
     * Get container configuration
     */
    public function getContainerConfig(int $vmid, string $node): array
    {
        $cacheKey = "proxmox_container_config_{$node}_{$vmid}";
        $cacheTime = config('proxmox.cache_ttl', 60); // 1 minute

        return Cache::remember($cacheKey, $cacheTime, function () use ($vmid, $node) {
            try {
                $response = $this->get("/nodes/{$node}/lxc/{$vmid}/config");

                return $response;
            } catch (\Exception $e) {
                Log::error('Failed to get container config', [
                    'error' => $e->getMessage(),
                    'node' => $node,
                    'vmid' => $vmid,
                ]);

                return [];
            }
        });
    }

    /**
     * Update container configuration
     */
    public function updateContainerConfig(int $vmid, string $node, array $config): array
    {
        $response = $this->put("/nodes/{$node}/lxc/{$vmid}/config", $config);

        // Clear cache for this container config
        $cacheKey = "proxmox_container_config_{$node}_{$vmid}";
        Cache::forget($cacheKey);

        return [
            'vmid' => $vmid,
            'node' => $node,
            'config' => $config,
            'response' => $response,
            'timestamp' => now()->toISOString(),
        ];
    }

    /**
     * Get node information
     */
    public function getNodeInfo(string $node): array
    {
        $cacheKey = "proxmox_node_info_{$node}";
        $cacheTime = config('proxmox.cache_ttl', 60); // 1 minute

        return Cache::remember($cacheKey, $cacheTime, function () use ($node) {
            try {
                $status = $this->get("/nodes/{$node}/status");
                $resources = $this->get("/nodes/{$node}/resources");
                $version = $this->get("/nodes/{$node}/version");

                return [
                    'node' => $node,
                    'status' => $status['status'] ?? 'offline',
                    'cpu' => $status['cpu'] ?? 0,
                    'cpuusage' => $status['cpuusage'] ?? 0,
                    'mem' => $status['mem'] ?? 0,
                    'maxmem' => $status['maxmem'] ?? 0,
                    'memusage' => $status['memusage'] ?? 0,
                    'disk' => $status['disk'] ?? 0,
                    'maxdisk' => $status['maxdisk'] ?? 0,
                    'diskusage' => $status['diskusage'] ?? 0,
                    'uptime' => $status['uptime'] ?? 0,
                    'idletime' => $status['idletime'] ?? 0,
                    'resources' => $resources,
                    'version' => $version,
                    'last_updated' => now()->toISOString(),
                ];
            } catch (\Exception $e) {
                Log::error('Failed to get node info', [
                    'error' => $e->getMessage(),
                    'node' => $node,
                ]);

                return [
                    'node' => $node,
                    'status' => 'error',
                    'error' => $e->getMessage(),
                    'last_updated' => now()->toISOString(),
                ];
            }
        });
    }

    /**
     * Get cluster status
     */
    public function getClusterStatus(): array
    {
        try {
            $response = $this->get('/cluster/status');

            return [
                'cluster' => $response['cluster'] ?? [],
                'nodes' => $response['nodes'] ?? [],
                'resources' => $response['resources'] ?? [],
                'version' => $response['version'] ?? [],
                'last_updated' => now()->toISOString(),
            ];
        } catch (\Exception $e) {
            Log::error('Failed to get cluster status', [
                'error' => $e->getMessage(),
            ]);

            return [
                'error' => $e->getMessage(),
                'last_updated' => now()->toISOString(),
            ];
        }
    }

    /**
     * Make API request to Proxmox
     */
    protected function get(string $endpoint, array $params = []): array
    {
        return $this->request('GET', $endpoint, $params);
    }

    protected function post(string $endpoint, array $data = []): array
    {
        return $this->request('POST', $endpoint, $data);
    }

    protected function put(string $endpoint, array $data = []): array
    {
        return $this->request('PUT', $endpoint, $data);
    }

    protected function delete(string $endpoint, array $data = []): array
    {
        return $this->request('DELETE', $endpoint, $data);
    }

    /**
     * Make HTTP request to Proxmox API
     */
    protected function request(string $method, string $endpoint, array $data = []): array
    {
        $url = $this->baseUrl . '/api2/json' . $endpoint;

        // Prepare authentication
        $options = [
            'timeout' => $this->timeout,
            'verify' => $this->verifySsl,
            'headers' => [
                'Accept' => 'application/json',
                'Content-Type' => 'application/json',
            ],
        ];

        // Add CSRF token for POST/PUT/DELETE requests
        if (in_array($method, ['POST', 'PUT', 'DELETE'])) {
            $csrfToken = $this->getCsrfToken();
            $options['headers']['CSRFPreventionToken'] = $csrfToken;
        }

        // Add authentication
        if ($this->useApiToken) {
            $options['headers']['Authorization'] = 'PVEAPIToken=' . $this->apiToken;
        } else {
            $options['auth'] = [$this->username, $this->password];
        }

        // Add params for GET requests
        if ($method === 'GET' && !empty($data)) {
            $url .= '?' . http_build_query($data);
        } else {
            $options['json'] = $data;
        }

        Log::debug('Proxmox API request', [
            'method' => $method,
            'endpoint' => $endpoint,
            'url' => $url,
            'data' => $data,
        ]);

        $response = Http::withOptions($options)
            ->send($method, $url);

        if (!$response->successful()) {
            throw new \Exception("Proxmox API request failed: {$response->status()} - {$response->body()}");
        }

        $result = $response->json();

        // Check for PVE API errors
        if (isset($result['errors']) && !empty($result['errors'])) {
            throw new \Exception("Proxmox API error: " . implode(', ', $result['errors']));
        }

        return $result['data'] ?? $result;
    }

    /**
     * Get CSRF token for authenticated requests
     */
    protected function getCsrfToken(): string
    {
        $cacheKey = 'proxmox_csrf_token';
        $cacheTime = 300; // 5 minutes

        return Cache::remember($cacheKey, $cacheTime, function () {
            $url = $this->baseUrl . '/api2/json/access/ticket';

            $response = Http::timeout($this->timeout)
                ->verify($this->verifySsl)
                ->asForm()
                ->post($url, [
                    'username' => $this->username,
                    'password' => $this->password,
                    'realm' => $this->realm,
                ]);

            if (!$response->successful()) {
                throw new \Exception("Failed to authenticate with Proxmox: {$response->status()}");
            }

            $result = $response->json();
            return $result['data']['CSRFPreventionToken'] ?? '';
        });
    }

    /**
     * Build rootfs configuration
     */
    protected function buildRootfs(array $data): string
    {
        $storage = $data['storage'] ?? 'local';
        $size = $data['disk_size_gb'] ?? '20G';

        return "local-lvm:vm-{$data['vmid']}-disk-0,size={$size}";
    }

    /**
     * Build features configuration
     */
    protected function buildFeatures(array $features): string
    {
        if (empty($features)) {
            return '';
        }

        return implode(',', array_map(function ($feature) {
            return "nesting={$feature}";
        }, $features));
    }

    /**
     * Build network configuration
     */
    protected function buildNetworkConfig(array $network): string
    {
        if (empty($network)) {
            return 'bridge=vmbr0';
        }

        $parts = [];

        if (!empty($network['bridge'])) {
            $parts[] = "bridge={$network['bridge']}";
        }

        if (!empty($network['ip'])) {
            $parts[] = "ip={$network['ip']}";
        }

        if (!empty($network['gateway'])) {
            $parts[] = "gw={$network['gateway']}";
        }

        return implode(',', $parts);
    }

    /**
     * Test API connection
     */
    public function testConnection(): array
    {
        try {
            $version = $this->get('/version');
            $ticket = $this->getCsrfToken();

            return [
                'connected' => true,
                'version' => $version,
                'auth' => $this->useApiToken ? 'token' : 'password',
                'last_updated' => now()->toISOString(),
            ];
        } catch (\Exception $e) {
            return [
                'connected' => false,
                'error' => $e->getMessage(),
                'last_updated' => now()->toISOString(),
            ];
        }
    }
}
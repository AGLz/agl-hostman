<?php

declare(strict_types=1);

namespace App\Services;

use App\DTOs\Harbor\HarborProjectDTO;
use App\DTOs\Harbor\HarborRepositoryDTO;
use App\DTOs\Harbor\HarborArtifactDTO;
use App\DTOs\Harbor\HarborVulnerabilityDTO;
use App\Repositories\HarborRepository;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Cache;
use Exception;

/**
 * Harbor Service
 *
 * Main service class for Harbor Container Registry API operations
 * Provides methods for managing projects, repositories, artifacts, and vulnerability scanning
 *
 * @see https://goharbor.io/docs/2.10.0/overview/
 */
class HarborService
{
    private const CACHE_TTL = 300; // 5 minutes

    public function __construct(
        private readonly HarborRepository $repository
    ) {}

    // ========== Project Management ==========

    /**
     * Get all projects
     */
    public function getProjects(): Collection
    {
        try {
            $cacheKey = 'harbor:projects';

            $data = Cache::remember($cacheKey, self::CACHE_TTL, function () {
                return $this->repository->get('/api/v2.0/projects');
            });

            return collect($data)
                ->map(fn($project) => HarborProjectDTO::fromArray($project));
        } catch (Exception $e) {
            Log::error('Failed to get Harbor projects', [
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Get project by ID or name
     */
    public function getProject(string $projectIdentifier): HarborProjectDTO
    {
        try {
            $data = $this->repository->get("/api/v2.0/projects/{$projectIdentifier}");

            return HarborProjectDTO::fromArray($data);
        } catch (Exception $e) {
            Log::error('Failed to get Harbor project', [
                'project' => $projectIdentifier,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Create new project
     */
    public function createProject(array $data): HarborProjectDTO
    {
        try {
            $payload = [
                'project_name' => $data['name'],
                'public' => $data['public'] ?? false,
                'metadata' => [
                    'public' => $data['public'] ?? false ? 'true' : 'false',
                    'enable_content_trust' => $data['enable_content_trust'] ?? false ? 'true' : 'false',
                    'enable_content_trust_ci' => $data['enable_content_trust_ci'] ?? false ? 'true' : 'false',
                    'prevent_vul' => $data['prevent_vulnerable_images'] ?? false ? 'true' : 'false',
                    'severity' => $data['severity'] ?? 'medium',
                    'auto_scan' => $data['auto_scan'] ?? true ? 'true' : 'false',
                ],
            ];

            if (isset($data['storage_limit'])) {
                $payload['storage_quota'] = [
                    'hard' => ['value' => $data['storage_limit']],
                ];
            }

            $result = $this->repository->post('/api/v2.0/projects', $payload);

            Cache::forget('harbor:projects');

            Log::info('Created Harbor project', [
                'name' => $data['name'],
                'projectId' => $result['project_id'] ?? null,
            ]);

            return HarborProjectDTO::fromArray($result);
        } catch (Exception $e) {
            Log::error('Failed to create Harbor project', [
                'name' => $data['name'] ?? 'unknown',
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Update project
     */
    public function updateProject(string $projectId, array $data): HarborProjectDTO
    {
        try {
            $payload = array_filter([
                'metadata' => isset($data['public']) ? [
                    'public' => $data['public'] ? 'true' : 'false',
                ] : null,
            ]);

            $result = $this->repository->put("/api/v2.0/projects/{$projectId}", $payload);

            Cache::forget('harbor:projects');

            Log::info('Updated Harbor project', [
                'projectId' => $projectId,
            ]);

            return HarborProjectDTO::fromArray($result);
        } catch (Exception $e) {
            Log::error('Failed to update Harbor project', [
                'projectId' => $projectId,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Delete project
     */
    public function deleteProject(string $projectId): bool
    {
        try {
            $this->repository->delete("/api/v2.0/projects/{$projectId}");

            Cache::forget('harbor:projects');

            Log::info('Deleted Harbor project', [
                'projectId' => $projectId,
            ]);

            return true;
        } catch (Exception $e) {
            Log::error('Failed to delete Harbor project', [
                'projectId' => $projectId,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    // ========== Repository Management ==========

    /**
     * Get repositories for a project
     */
    public function getRepositories(string $projectName): Collection
    {
        try {
            $cacheKey = "harbor:repositories:{$projectName}";

            $data = Cache::remember($cacheKey, self::CACHE_TTL, function () use ($projectName) {
                return $this->repository->get("/api/v2.0/projects/{$projectName}/repositories");
            });

            return collect($data)
                ->map(fn($repo) => HarborRepositoryDTO::fromArray($repo));
        } catch (Exception $e) {
            Log::error('Failed to get Harbor repositories', [
                'project' => $projectName,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Get repository details
     */
    public function getRepository(string $projectName, string $repositoryName): HarborRepositoryDTO
    {
        try {
            $data = $this->repository->get(
                "/api/v2.0/projects/{$projectName}/repositories/{$repositoryName}"
            );

            return HarborRepositoryDTO::fromArray($data);
        } catch (Exception $e) {
            Log::error('Failed to get Harbor repository', [
                'project' => $projectName,
                'repository' => $repositoryName,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Delete repository
     */
    public function deleteRepository(string $projectName, string $repositoryName): bool
    {
        try {
            $this->repository->delete(
                "/api/v2.0/projects/{$projectName}/repositories/{$repositoryName}"
            );

            Cache::forget("harbor:repositories:{$projectName}");

            Log::info('Deleted Harbor repository', [
                'project' => $projectName,
                'repository' => $repositoryName,
            ]);

            return true;
        } catch (Exception $e) {
            Log::error('Failed to delete Harbor repository', [
                'project' => $projectName,
                'repository' => $repositoryName,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    // ========== Artifact Management ==========

    /**
     * Get artifacts for a repository
     */
    public function getArtifacts(string $projectName, string $repositoryName): Collection
    {
        try {
            $data = $this->repository->get(
                "/api/v2.0/projects/{$projectName}/repositories/{$repositoryName}/artifacts"
            );

            return collect($data)
                ->map(fn($artifact) => HarborArtifactDTO::fromArray($artifact));
        } catch (Exception $e) {
            Log::error('Failed to get Harbor artifacts', [
                'project' => $projectName,
                'repository' => $repositoryName,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Get artifact details
     */
    public function getArtifact(
        string $projectName,
        string $repositoryName,
        string $reference
    ): HarborArtifactDTO {
        try {
            $data = $this->repository->get(
                "/api/v2.0/projects/{$projectName}/repositories/{$repositoryName}/artifacts/{$reference}"
            );

            return HarborArtifactDTO::fromArray($data);
        } catch (Exception $e) {
            Log::error('Failed to get Harbor artifact', [
                'project' => $projectName,
                'repository' => $repositoryName,
                'reference' => $reference,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Delete artifact
     */
    public function deleteArtifact(
        string $projectName,
        string $repositoryName,
        string $reference
    ): bool {
        try {
            $this->repository->delete(
                "/api/v2.0/projects/{$projectName}/repositories/{$repositoryName}/artifacts/{$reference}"
            );

            Log::info('Deleted Harbor artifact', [
                'project' => $projectName,
                'repository' => $repositoryName,
                'reference' => $reference,
            ]);

            return true;
        } catch (Exception $e) {
            Log::error('Failed to delete Harbor artifact', [
                'project' => $projectName,
                'repository' => $repositoryName,
                'reference' => $reference,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Copy artifact between projects/repositories
     */
    public function copyArtifact(
        string $fromProject,
        string $fromRepository,
        string $fromReference,
        string $toProject,
        string $toRepository
    ): bool {
        try {
            $payload = [
                'from' => [
                    'project_name' => $fromProject,
                    'repository_name' => $fromRepository,
                    'reference' => $fromReference,
                ],
            ];

            $this->repository->post(
                "/api/v2.0/projects/{$toProject}/repositories/{$toRepository}/artifacts",
                $payload
            );

            Log::info('Copied Harbor artifact', [
                'from' => "{$fromProject}/{$fromRepository}:{$fromReference}",
                'to' => "{$toProject}/{$toRepository}",
            ]);

            return true;
        } catch (Exception $e) {
            Log::error('Failed to copy Harbor artifact', [
                'from' => "{$fromProject}/{$fromRepository}:{$fromReference}",
                'to' => "{$toProject}/{$toRepository}",
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    // ========== Vulnerability Scanning ==========

    /**
     * Get vulnerability scan results for an artifact
     */
    public function getVulnerabilities(
        string $projectName,
        string $repositoryName,
        string $reference
    ): HarborVulnerabilityDTO {
        try {
            $artifact = $this->getArtifact($projectName, $repositoryName, $reference);

            if (!isset($artifact->scanOverview)) {
                // Trigger scan if not available
                $this->triggerScan($projectName, $repositoryName, $reference);
                throw new Exception('Vulnerability scan not available. Scan triggered.');
            }

            return HarborVulnerabilityDTO::fromArtifact($artifact);
        } catch (Exception $e) {
            Log::error('Failed to get Harbor vulnerabilities', [
                'project' => $projectName,
                'repository' => $repositoryName,
                'reference' => $reference,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Trigger vulnerability scan for an artifact
     */
    public function triggerScan(
        string $projectName,
        string $repositoryName,
        string $reference
    ): bool {
        try {
            $this->repository->post(
                "/api/v2.0/projects/{$projectName}/repositories/{$repositoryName}/artifacts/{$reference}/scan"
            );

            Log::info('Triggered Harbor vulnerability scan', [
                'project' => $projectName,
                'repository' => $repositoryName,
                'reference' => $reference,
            ]);

            return true;
        } catch (Exception $e) {
            Log::error('Failed to trigger Harbor vulnerability scan', [
                'project' => $projectName,
                'repository' => $repositoryName,
                'reference' => $reference,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Get all vulnerabilities with severity filter
     */
    public function getVulnerabilitiesBySeverity(
        string $projectName,
        string $repositoryName,
        string $reference,
        ?string $severity = null
    ): array {
        try {
            $vuln = $this->getVulnerabilities($projectName, $repositoryName, $reference);

            if ($severity) {
                return array_filter($vuln->vulnerabilities, function ($v) use ($severity) {
                    return strcasecmp($v['severity'], $severity) === 0;
                });
            }

            return $vuln->vulnerabilities;
        } catch (Exception $e) {
            Log::error('Failed to get Harbor vulnerabilities by severity', [
                'project' => $projectName,
                'repository' => $repositoryName,
                'reference' => $reference,
                'severity' => $severity,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    // ========== Retention Policy ==========

    /**
     * Get retention policies for a project
     */
    public function getRetentionPolicies(string $projectId): Collection
    {
        try {
            $data = $this->repository->get("/api/v2.0/retentions/{$projectId}");

            return collect($data['rules'] ?? []);
        } catch (Exception $e) {
            Log::error('Failed to get Harbor retention policies', [
                'projectId' => $projectId,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Create retention policy
     */
    public function createRetentionPolicy(string $projectId, array $policy): array
    {
        try {
            $payload = [
                'algorithm' => 'or',
                'rules' => [
                    [
                        'disabled' => false,
                        'action' => 'retain',
                        'scope_selectors' => [
                            'repository' => [
                                ['kind' => 'doublestar', 'decoration' => 'repoMatches', 'pattern' => '**'],
                            ],
                        ],
                        'tag_selectors' => [
                            ['kind' => 'doublestar', 'decoration' => 'matches', 'pattern' => $policy['tag_pattern'] ?? '**'],
                        ],
                        'params' => [
                            'latestPushedK' => $policy['keep_last_n'] ?? 10,
                        ],
                        'template' => 'rule.template.latestPushedK',
                    ],
                ],
                'scope' => [
                    'level' => 'project',
                    'ref' => (int) $projectId,
                ],
            ];

            return $this->repository->put("/api/v2.0/retentions/{$projectId}", $payload);
        } catch (Exception $e) {
            Log::error('Failed to create Harbor retention policy', [
                'projectId' => $projectId,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    // ========== Webhook Management ==========

    /**
     * Get webhooks for a project
     */
    public function getWebhooks(string $projectId): Collection
    {
        try {
            $data = $this->repository->get("/api/v2.0/projects/{$projectId}/webhook/policies");

            return collect($data);
        } catch (Exception $e) {
            Log::error('Failed to get Harbor webhooks', [
                'projectId' => $projectId,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Create webhook for a project
     */
    public function createWebhook(string $projectId, array $webhook): array
    {
        try {
            $payload = [
                'name' => $webhook['name'] ?? 'Dokploy Integration',
                'description' => $webhook['description'] ?? 'Webhook for Dokploy deployment automation',
                'projects' => [
                    ['project_id' => (int) $projectId],
                ],
                'targets' => [
                    [
                        'type' => 'http',
                        'address' => $webhook['url'],
                        'auth_header' => $webhook['secret'] ?? null,
                        'skip_cert_verify' => $webhook['skip_ssl_verify'] ?? false,
                    ],
                ],
                'event_types' => $webhook['events'] ?? [
                    'PUSH_ARTIFACT',
                    'PULL_ARTIFACT',
                    'DELETE_ARTIFACT',
                    'SCANNING_COMPLETED',
                ],
                'enabled' => $webhook['enabled'] ?? true,
            ];

            return $this->repository->post("/api/v2.0/projects/{$projectId}/webhook/policies", $payload);
        } catch (Exception $e) {
            Log::error('Failed to create Harbor webhook', [
                'projectId' => $projectId,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Delete webhook
     */
    public function deleteWebhook(string $projectId, int $webhookId): bool
    {
        try {
            $this->repository->delete("/api/v2.0/projects/{$projectId}/webhook/policies/{$webhookId}");

            Log::info('Deleted Harbor webhook', [
                'projectId' => $projectId,
                'webhookId' => $webhookId,
            ]);

            return true;
        } catch (Exception $e) {
            Log::error('Failed to delete Harbor webhook', [
                'projectId' => $projectId,
                'webhookId' => $webhookId,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    // ========== System & Health ==========

    /**
     * Get Harbor system info
     */
    public function getSystemInfo(): array
    {
        try {
            return Cache::remember('harbor:system_info', 3600, function () {
                return $this->repository->get('/api/v2.0/systeminfo');
            });
        } catch (Exception $e) {
            Log::error('Failed to get Harbor system info', [
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Get Harbor health status
     */
    public function getHealthStatus(): array
    {
        try {
            return $this->repository->get('/api/v2.0/systemhealth');
        } catch (Exception $e) {
            Log::error('Failed to get Harbor health status', [
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Test API connection
     */
    public function testConnection(): bool
    {
        return $this->repository->testConnection();
    }

    /**
     * Get registry credentials for docker login
     */
    public function getPullCredentials(): array
    {
        return [
            'registry' => rtrim(config('harbor.base_url'), '/'),
            'username' => config('harbor.username'),
            'password' => config('harbor.password'),
        ];
    }

    /**
     * Get pull token for docker login (JWT)
     */
    public function getPullToken(): string
    {
        try {
            $response = $this->repository->post('/api/v2.0/users/current', [
                'username' => config('harbor.username'),
                'password' => config('harbor.password'),
            ]);

            return $response['token'] ?? '';
        } catch (Exception $e) {
            Log::error('Failed to get Harbor pull token', [
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Clear all caches
     */
    public function clearCache(): void
    {
        Cache::forget('harbor:projects');
        Cache::forget('harbor:system_info');
    }
}

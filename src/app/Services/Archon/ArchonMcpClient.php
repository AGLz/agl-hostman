<?php

declare(strict_types=1);

namespace App\Services\Archon;

use App\Exceptions\ArchonMcpException;
use Illuminate\Http\Client\PendingRequest;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

/**
 * Archon MCP Client - JSON-RPC 2.0 Protocol Implementation
 *
 * Communicates with Archon MCP server (CT183) using JSON-RPC 2.0 protocol.
 * Supports all 28 MCP tools for task management, projects, and knowledge base.
 *
 * @see https://archon.aglz.io
 * @see docs/ARCHON.md
 */
class ArchonMcpClient
{
    private string $mcpUrl;

    private int $timeout;

    private int $retryTimes;

    private int $retryDelay;

    private array $requestHistory = [];

    public function __construct()
    {
        $this->mcpUrl = config('archon.mcp_url');
        $this->timeout = (int) config('archon.timeout', 30);
        $this->retryTimes = (int) config('archon.retry_times', 3);
        $this->retryDelay = (int) config('archon.retry_delay', 1000);
    }

    /**
     * Call an MCP tool using JSON-RPC 2.0 protocol
     *
     * @param  string  $toolName  The MCP tool name (e.g., 'find_projects')
     * @param  array  $arguments  Tool-specific arguments
     * @param  bool  $useCache  Whether to cache the result
     * @return array The tool result
     *
     * @throws ArchonMcpException
     */
    public function call(string $toolName, array $arguments = [], bool $useCache = false): array
    {
        // Generate request ID
        $requestId = $this->generateRequestId($toolName);

        // Check cache for read-only operations
        if ($useCache && $this->isReadOnlyTool($toolName)) {
            $cacheKey = $this->getCacheKey($toolName, $arguments);
            $cached = Cache::get($cacheKey);

            if ($cached !== null) {
                Log::info('Archon MCP cache hit', [
                    'tool' => $toolName,
                    'cache_key' => $cacheKey,
                ]);

                return $cached;
            }
        }

        // Build JSON-RPC 2.0 request
        $request = $this->buildRequest($requestId, $toolName, $arguments);

        // Execute with retry logic
        $response = $this->executeWithRetry($request, $requestId);

        // Parse and validate response
        $result = $this->parseResponse($response, $requestId, $toolName);

        // Cache successful read-only operations
        if ($useCache && $this->isReadOnlyTool($toolName)) {
            $cacheKey = $this->getCacheKey($toolName, $arguments);
            $cacheTtl = config('archon.cache_ttl', 3600);
            Cache::put($cacheKey, $result, $cacheTtl);
        }

        return $result;
    }

    /**
     * Execute multiple MCP tool calls in batch
     *
     * @param  array  $calls  Array of ['tool' => toolName, 'args' => arguments]
     * @return array Results indexed by request ID
     */
    public function batch(array $calls): array
    {
        $requests = [];
        $requestMap = [];

        foreach ($calls as $call) {
            $requestId = $this->generateRequestId($call['tool']);
            $requests[] = $this->buildRequest($requestId, $call['tool'], $call['args'] ?? []);
            $requestMap[$requestId] = $call['tool'];
        }

        $responses = [];
        foreach ($requests as $request) {
            try {
                $response = $this->executeWithRetry($request, $request['id']);
                $responses[$request['id']] = $this->parseResponse($response, $request['id'], $requestMap[$request['id']]);
            } catch (ArchonMcpException $e) {
                Log::error('Batch call failed', [
                    'request_id' => $request['id'],
                    'tool' => $requestMap[$request['id']],
                    'error' => $e->getMessage(),
                ]);
                $responses[$request['id']] = ['error' => $e->getMessage()];
            }
        }

        return $responses;
    }

    /**
     * Test MCP connection health
     */
    public function ping(): bool
    {
        try {
            $result = $this->call('health_check');

            return isset($result['status']) && $result['status'] === 'ok';
        } catch (ArchonMcpException $e) {
            Log::error('Archon MCP ping failed', ['error' => $e->getMessage()]);

            return false;
        }
    }

    /**
     * Build JSON-RPC 2.0 request
     */
    private function buildRequest(string $requestId, string $toolName, array $arguments): array
    {
        return [
            'jsonrpc' => '2.0',
            'id' => $requestId,
            'method' => 'tools/call',
            'params' => [
                'name' => $toolName,
                'arguments' => $arguments,
            ],
        ];
    }

    /**
     * Execute HTTP request with retry logic
     */
    private function executeWithRetry(array $request, string $requestId): array
    {
        $attempt = 0;
        $lastException = null;

        while ($attempt < $this->retryTimes) {
            try {
                $startTime = microtime(true);

                $responseBody = $this->getHttpClient()
                    ->post('', $request)
                    ->throw()
                    ->body();

                // Parse SSE (Server-Sent Events) format
                $response = $this->parseSSE($responseBody);

                $duration = round((microtime(true) - $startTime) * 1000, 2);

                Log::info('Archon MCP call success', [
                    'request_id' => $requestId,
                    'tool' => $request['params']['name'],
                    'duration_ms' => $duration,
                    'attempt' => $attempt + 1,
                ]);

                // Track request for debugging
                $this->requestHistory[] = [
                    'request_id' => $requestId,
                    'tool' => $request['params']['name'],
                    'duration_ms' => $duration,
                    'timestamp' => now()->toIso8601String(),
                ];

                return $response;

            } catch (\Illuminate\Http\Client\RequestException $e) {
                $lastException = $e;
                $attempt++;

                Log::warning('Archon MCP call failed, retrying', [
                    'request_id' => $requestId,
                    'attempt' => $attempt,
                    'max_attempts' => $this->retryTimes,
                    'error' => $e->getMessage(),
                ]);

                if ($attempt < $this->retryTimes) {
                    usleep($this->retryDelay * 1000); // Convert ms to microseconds
                }
            }
        }

        throw new ArchonMcpException(
            "MCP call failed after {$this->retryTimes} attempts: ".$lastException?->getMessage(),
            500,
            $lastException
        );
    }

    /**
     * Parse and validate JSON-RPC 2.0 response
     */
    private function parseResponse(array $response, string $requestId, string $toolName): array
    {
        // Validate JSON-RPC 2.0 response structure
        if (! isset($response['jsonrpc']) || $response['jsonrpc'] !== '2.0') {
            throw new ArchonMcpException('Invalid JSON-RPC 2.0 response: missing or invalid jsonrpc field');
        }

        if (! isset($response['id']) || $response['id'] !== $requestId) {
            throw new ArchonMcpException('Invalid JSON-RPC 2.0 response: request ID mismatch');
        }

        // Check for errors
        if (isset($response['error'])) {
            $error = $response['error'];
            throw new ArchonMcpException(
                "MCP tool '{$toolName}' error: ".($error['message'] ?? 'Unknown error'),
                $error['code'] ?? 500,
                data: $error['data'] ?? null
            );
        }

        // Return result
        if (! isset($response['result'])) {
            throw new ArchonMcpException('Invalid JSON-RPC 2.0 response: missing result field');
        }

        $result = $response['result'];

        // Archon wraps results in content/structuredContent - extract the actual data
        if (isset($result['structuredContent']['result'])) {
            // Parse the JSON string in structuredContent.result
            $actualResult = json_decode($result['structuredContent']['result'], true);

            return $actualResult ?? $result;
        }

        // If content array exists with text type, try parsing that
        if (isset($result['content'][0]['text'])) {
            $actualResult = json_decode($result['content'][0]['text'], true);

            return $actualResult ?? $result;
        }

        return $result;
    }

    /**
     * Get configured HTTP client
     */
    private function getHttpClient(): PendingRequest
    {
        return Http::baseUrl($this->mcpUrl)
            ->timeout($this->timeout)
            ->withHeaders([
                'Accept' => 'application/json, text/event-stream',
                'Content-Type' => 'application/json',
                'User-Agent' => 'AGL-HostMan-Laravel/1.0',
                'X-Client-Version' => config('app.version', '1.0.0'),
            ]);
    }

    /**
     * Generate unique request ID
     */
    private function generateRequestId(string $toolName): string
    {
        return sprintf(
            '%s-%s-%s',
            $toolName,
            now()->format('YmdHis'),
            Str::random(8)
        );
    }

    /**
     * Parse Server-Sent Events (SSE) response
     */
    private function parseSSE(string $body): array
    {
        // SSE format: "event: message\ndata: {...}\n\n"
        $lines = explode("\n", $body);
        $data = null;

        foreach ($lines as $line) {
            $line = trim($line);
            if (str_starts_with($line, 'data: ')) {
                $jsonData = substr($line, 6); // Remove "data: " prefix
                $data = json_decode($jsonData, true);
                break;
            }
        }

        if ($data === null) {
            throw new ArchonMcpException('Failed to parse SSE response: no data field found');
        }

        return $data;
    }

    /**
     * Get cache key for request
     */
    private function getCacheKey(string $toolName, array $arguments): string
    {
        $argsHash = md5(json_encode($arguments));

        return "archon:mcp:{$toolName}:{$argsHash}";
    }

    /**
     * Check if tool is read-only (safe to cache)
     */
    private function isReadOnlyTool(string $toolName): bool
    {
        $readOnlyTools = [
            'health_check',
            'session_info',
            'archon_get_status',
            'rag_get_available_sources',
            'rag_search_knowledge_base',
            'rag_search_code_examples',
            'rag_list_pages_for_source',
            'rag_read_full_page',
            'find_projects',
            'get_project_features',
            'find_tasks',
            'find_documents',
            'find_versions',
            'archon_search_knowledge',
            'archon_get_knowledge_sources',
            'archon_get_code_examples',
        ];

        return in_array($toolName, $readOnlyTools, true);
    }

    /**
     * Get request history for debugging
     */
    public function getRequestHistory(): array
    {
        return $this->requestHistory;
    }

    /**
     * Clear request history
     */
    public function clearRequestHistory(): void
    {
        $this->requestHistory = [];
    }

    /**
     * Clear cache for specific tool
     */
    public function clearCache(?string $toolName = null): void
    {
        if ($toolName) {
            Cache::forget("archon:mcp:{$toolName}:*");
        } else {
            Cache::flush(); // Nuclear option - clear all cache
        }
    }
}

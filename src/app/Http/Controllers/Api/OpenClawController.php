<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Cache;

class OpenClawController extends Controller
{
    /**
     * Get OpenClaw status overview
     */
    public function index(): JsonResponse
    {
        $status = $this->getOpenClawStatus();
        
        return response()->json([
            'status' => $status['gateway'] === 'running' ? 'online' : 'offline',
            'gateway' => $status['gateway'],
            'agents' => $status['agents'] ?? [],
            'sessions' => $status['sessions'] ?? 0,
            'tasks' => $status['tasks'] ?? [],
        ]);
    }

    /**
     * Get detailed agent information
     */
    public function agents(): JsonResponse
    {
        $status = $this->getOpenClawStatus();
        $agents = $status['agents'] ?? [];
        
        // Organize agents by category
        $categorized = [
            'core' => [],
            'infrastructure' => [],
            'scrum' => [],
            'executive' => [],
        ];
        
        foreach ($agents as $id => $agent) {
            if (str_starts_with($id, 'scr-')) {
                $categorized['scrum'][$id] = $agent;
            } elseif (in_array($id, ['altman', 'musk', 'gates', 'hassabis', 'hinton', 'karpathy', 'nadella', 'pichai'])) {
                $categorized['executive'][$id] = $agent;
            } elseif (in_array($id, ['devops', 'sre-team', 'infra-manager'])) {
                $categorized['infrastructure'][$id] = $agent;
            } else {
                $categorized['core'][$id] = $agent;
            }
        }
        
        return response()->json([
            'total' => count($agents),
            'active' => count(array_filter($agents, fn($a) => ($a['status'] ?? '') === 'active')),
            'categorized' => $categorized,
        ]);
    }

    /**
     * Get active sessions
     */
    public function sessions(): JsonResponse
    {
        $status = $this->getOpenClawStatus();
        $sessions = $status['sessions_data'] ?? [];
        
        return response()->json([
            'total' => $status['sessions'] ?? 0,
            'recent' => array_slice($sessions, 0, 20),
        ]);
    }

    /**
     * Get tasks overview
     */
    public function tasks(): JsonResponse
    {
        $status = $this->getOpenClawStatus();
        $tasks = $status['tasks'] ?? [];
        
        $grouped = [
            'active' => array_filter($tasks, fn($t) => ($t['status'] ?? '') === 'running'),
            'queued' => array_filter($tasks, fn($t) => ($t['status'] ?? '') === 'queued'),
            'failed' => array_filter($tasks, fn($t) => in_array($t['status'] ?? '', ['failed', 'lost'])),
            'completed' => array_filter($tasks, fn($t) => ($t['status'] ?? '') === 'succeeded'),
        ];
        
        return response()->json([
            'total' => count($tasks),
            'grouped' => [
                'active' => count($grouped['active']),
                'queued' => count($grouped['queued']),
                'failed' => count($grouped['failed']),
                'completed' => count($grouped['completed']),
            ],
            'recent_failed' => array_slice($grouped['failed'], 0, 10),
        ]);
    }

    /**
     * Execute OpenClaw command and return result
     */
    public function execute(Request $request): JsonResponse
    {
        $command = $request->input('command');
        $args = $request->input('args', []);
        
        if (!$command) {
            return response()->json(['error' => 'Command required'], 400);
        }
        
        $result = $this->runOpenClawCommand($command, $args);
        
        return response()->json($result);
    }

    /**
     * Get OpenClaw status by running CLI commands
     */
    private function getOpenClawStatus(): array
    {
        return Cache::remember('openclaw_status', 30, function () {
            $result = [
                'gateway' => 'offline',
                'agents' => [],
                'sessions' => 0,
                'sessions_data' => [],
                'tasks' => [],
            ];
            
            // Check if OpenClaw is installed
            $checkCmd = 'command -v openclaw >/dev/null 2>&1 && echo "installed" || echo "not_installed"';
            $checkResult = trim(shell_exec($checkCmd));
            
            if ($checkResult !== 'installed') {
                // Return mock data for demo
                return $this->getMockData();
            }
            
            // Get status
            $statusOutput = shell_exec('openclaw status 2>&1');
            if ($statusOutput) {
                $result['gateway'] = str_contains($statusOutput, 'running') ? 'running' : 'stopped';
                $result['raw_status'] = $statusOutput;
            }
            
            // Get agents
            $agentsOutput = shell_exec('openclaw agents list 2>&1');
            if ($agentsOutput) {
                $result['agents'] = $this->parseAgentsOutput($agentsOutput);
            }
            
            // Get tasks
            $tasksOutput = shell_exec('openclaw tasks list 2>&1');
            if ($tasksOutput) {
                $result['tasks'] = $this->parseTasksOutput($tasksOutput);
            }
            
            return $result;
        });
    }

    /**
     * Run OpenClaw CLI command
     */
    private function runOpenClawCommand(string $command, array $args = []): array
    {
        $checkCmd = 'command -v openclaw >/dev/null 2>&1 && echo "installed" || echo "not_installed"';
        if (trim(shell_exec($checkCmd)) !== 'installed') {
            return ['success' => false, 'error' => 'OpenClaw not installed'];
        }
        
        $cmd = 'openclaw ' . escapeshellarg($command);
        foreach ($args as $arg) {
            $cmd .= ' ' . escapeshellarg($arg);
        }
        $cmd .= ' 2>&1';
        
        $output = shell_exec($cmd);
        
        return [
            'success' => true,
            'output' => $output,
            'command' => $command,
        ];
    }

    /**
     * Parse agents list output
     */
    private function parseAgentsOutput(string $output): array
    {
        $agents = [];
        $lines = explode("\n", $output);
        
        foreach ($lines as $line) {
            // Parse agent lines from openclaw agents list
            if (preg_match('/(\S+)\s+(\w+)\s+(.+?)(?:\s+(\d+)\s+sessions)?/i', $line, $matches)) {
                $id = $matches[1];
                $agents[$id] = [
                    'id' => $id,
                    'status' => strtolower($matches[2]) === 'on' ? 'active' : 'standby',
                    'role' => trim($matches[3]),
                    'sessions' => isset($matches[4]) ? (int)$matches[4] : 0,
                ];
            }
        }
        
        return $agents;
    }

    /**
     * Parse tasks list output
     */
    private function parseTasksOutput(string $output): array
    {
        $tasks = [];
        $lines = explode("\n", $output);
        
        foreach ($lines as $line) {
            if (preg_match('/([a-f0-9-]+)\s+(\w+)\s+(\w+)\s+(.+)/i', $line, $matches)) {
                $tasks[] = [
                    'id' => $matches[1],
                    'kind' => $matches[2],
                    'status' => $matches[3],
                    'summary' => trim($matches[4]),
                ];
            }
        }
        
        return $tasks;
    }

    /**
     * Get mock data when OpenClaw is not available
     */
    private function getMockData(): array
    {
        return [
            'gateway' => 'running',
            'agents' => [
                'main' => ['id' => 'main', 'name' => 'Main Agent', 'role' => 'Coordinator', 'status' => 'active', 'sessions' => 12, 'lastActive' => '2m ago'],
                'devops' => ['id' => 'devops', 'name' => 'DevOps Agent', 'role' => 'DevOps Engineer', 'status' => 'active', 'sessions' => 8, 'lastActive' => '5m ago'],
                'security' => ['id' => 'security', 'name' => 'Security Agent', 'role' => 'Security Analyst', 'status' => 'active', 'sessions' => 15, 'lastActive' => '1m ago'],
                'sre-team' => ['id' => 'sre-team', 'name' => 'SRE Team', 'role' => 'Site Reliability', 'status' => 'active', 'sessions' => 6, 'lastActive' => '10m ago'],
                'infra-manager' => ['id' => 'infra-manager', 'name' => 'Infra Manager', 'role' => 'Infrastructure Manager', 'status' => 'active', 'sessions' => 4, 'lastActive' => '15m ago'],
                'release-manager' => ['id' => 'release-manager', 'name' => 'Release Manager', 'role' => 'Release Coordination', 'status' => 'standby', 'sessions' => 2, 'lastActive' => '1h ago'],
                'scr-agl-hostman' => ['id' => 'scr-agl-hostman', 'name' => 'Scrum - Hostman', 'role' => 'Project Tracking', 'status' => 'active', 'sessions' => 20, 'lastActive' => '3m ago'],
                'scr-api8' => ['id' => 'scr-api8', 'name' => 'Scrum - API8', 'role' => 'API Tracking', 'status' => 'standby', 'sessions' => 5, 'lastActive' => '30m ago'],
                'scr-api9' => ['id' => 'scr-api9', 'name' => 'Scrum - API9', 'role' => 'API Tracking', 'status' => 'standby', 'sessions' => 3, 'lastActive' => '45m ago'],
                'scr-crowbar' => ['id' => 'scr-crowbar', 'name' => 'Scrum - Crowbar', 'role' => 'Project Tracking', 'status' => 'standby', 'sessions' => 1, 'lastActive' => '2h ago'],
                'altman' => ['id' => 'altman', 'name' => 'Altman', 'role' => 'AI Advisor', 'status' => 'standby', 'sessions' => 0, 'lastActive' => '1d ago'],
                'musk' => ['id' => 'musk', 'name' => 'Musk', 'role' => 'Strategy Advisor', 'status' => 'standby', 'sessions' => 0, 'lastActive' => '2d ago'],
                'gates' => ['id' => 'gates', 'name' => 'Gates', 'role' => 'Tech Advisor', 'status' => 'standby', 'sessions' => 0, 'lastActive' => '3d ago'],
                'hassabis' => ['id' => 'hassabis', 'name' => 'Hassabis', 'role' => 'AI Research', 'status' => 'standby', 'sessions' => 0, 'lastActive' => '1d ago'],
                'hinton' => ['id' => 'hinton', 'name' => 'Hinton', 'role' => 'AI Research', 'status' => 'standby', 'sessions' => 0, 'lastActive' => '4d ago'],
                'karpathy' => ['id' => 'karpathy', 'name' => 'Karpathy', 'role' => 'ML Advisor', 'status' => 'standby', 'sessions' => 0, 'lastActive' => '2d ago'],
                'nadella' => ['id' => 'nadella', 'name' => 'Nadella', 'role' => 'Cloud Strategy', 'status' => 'standby', 'sessions' => 0, 'lastActive' => '3d ago'],
                'pichai' => ['id' => 'pichai', 'name' => 'Pichai', 'role' => 'AI Strategy', 'status' => 'standby', 'sessions' => 0, 'lastActive' => '2d ago'],
            ],
            'sessions' => 51,
            'sessions_data' => [],
            'tasks' => [],
        ];
    }
}

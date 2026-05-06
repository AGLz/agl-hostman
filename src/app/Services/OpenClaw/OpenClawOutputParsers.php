<?php

declare(strict_types=1);

namespace App\Services\OpenClaw;

/**
 * Parsers e dados de exemplo legados (não referenciados pelo fluxo atual da API).
 */
final class OpenClawOutputParsers
{
    /**
     * @return array<string, mixed>
     */
    public static function parseAgentsOutput(string $output): array
    {
        $agents = [];
        $lines = explode("\n", $output);

        foreach ($lines as $line) {
            if (preg_match('/(\S+)\s+(\w+)\s+(.+?)(?:\s+(\d+)\s+sessions)?/i', $line, $matches)) {
                $id = $matches[1];
                $agents[$id] = [
                    'id' => $id,
                    'status' => strtolower($matches[2]) === 'on' ? 'active' : 'standby',
                    'role' => trim($matches[3]),
                    'sessions' => isset($matches[4]) ? (int) $matches[4] : 0,
                ];
            }
        }

        return $agents;
    }

    /**
     * @return array<int, array{id: string, kind: string, status: string, summary: string}>
     */
    public static function parseTasksOutput(string $output): array
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
     * @return array<string, mixed>
     */
    public static function mockData(): array
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

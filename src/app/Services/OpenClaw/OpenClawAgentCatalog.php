<?php

declare(strict_types=1);

namespace App\Services\OpenClaw;

final class OpenClawAgentCatalog
{
    /**
     * @var array<string, array{name: string, role: string, group: string}>
     */
    public const CATALOG = [
        'main' => ['name' => 'Main Agent', 'role' => 'Coordinator', 'group' => 'Core'],
        'devops' => ['name' => 'DevOps Agent', 'role' => 'DevOps Engineer', 'group' => 'Core'],
        'security' => ['name' => 'Security Agent', 'role' => 'Security Analyst', 'group' => 'Core'],
        'sre-team' => ['name' => 'SRE Team', 'role' => 'Site Reliability', 'group' => 'Operations'],
        'infra-manager' => ['name' => 'Infra Manager', 'role' => 'Infrastructure Manager', 'group' => 'Operations'],
        'release-manager' => ['name' => 'Release Manager', 'role' => 'Release Coordination', 'group' => 'Operations'],
        'scr-agl-hostman' => ['name' => 'Scrum - Hostman', 'role' => 'Project Tracking', 'group' => 'Scrum Agents'],
        'scr-api8' => ['name' => 'Scrum - API8', 'role' => 'API Tracking', 'group' => 'Scrum Agents'],
        'scr-api9' => ['name' => 'Scrum - API9', 'role' => 'API Tracking', 'group' => 'Scrum Agents'],
        'scr-crowbar' => ['name' => 'Scrum - Crowbar', 'role' => 'Project Tracking', 'group' => 'Scrum Agents'],
        'altman' => ['name' => 'Altman', 'role' => 'AI Advisor', 'group' => 'Specialists'],
        'gates' => ['name' => 'Gates', 'role' => 'Tech Advisor', 'group' => 'Specialists'],
        'hassabis' => ['name' => 'Hassabis', 'role' => 'AI Research', 'group' => 'Specialists'],
        'karpathy' => ['name' => 'Karpathy', 'role' => 'ML Advisor', 'group' => 'Specialists'],
        'musk' => ['name' => 'Musk', 'role' => 'Strategy Advisor', 'group' => 'Specialists'],
    ];

    /**
     * @var array<string, array{name: string, role: string, group: string}>
     */
    public const ROLE_HINTS = [
        'coder' => ['name' => 'Coder', 'role' => 'Code Implementation', 'group' => 'Engineering'],
        'planner' => ['name' => 'Planner', 'role' => 'Planning', 'group' => 'Engineering'],
        'researcher' => ['name' => 'Researcher', 'role' => 'Research', 'group' => 'Engineering'],
        'reviewer' => ['name' => 'Reviewer', 'role' => 'Code Review', 'group' => 'Engineering'],
        'tester' => ['name' => 'Tester', 'role' => 'Quality Assurance', 'group' => 'Engineering'],
        'infra' => ['name' => 'Infra', 'role' => 'Infrastructure', 'group' => 'Operations'],
        'storage' => ['name' => 'Storage', 'role' => 'Storage Operations', 'group' => 'Operations'],
        'harbor' => ['name' => 'Harbor', 'role' => 'Registry Operations', 'group' => 'Operations'],
        'net' => ['name' => 'Network', 'role' => 'Network Operations', 'group' => 'Operations'],
        'openclaw-expert' => ['name' => 'OpenClaw Expert', 'role' => 'OpenClaw Specialist', 'group' => 'Specialists'],
    ];

    /**
     * @return array{name: string, role: string, group: string}
     */
    public static function inferMetadata(string $id): array
    {
        $name = str($id)->replace(['-', '_'], ' ')->title()->toString();

        return [
            'name' => $name,
            'role' => str_starts_with($id, 'scr-') ? 'Scrum Tracking' : 'OpenClaw Agent',
            'group' => match (true) {
                str_starts_with($id, 'scr-') => 'Scrum Agents',
                in_array($id, ['altman', 'bezos', 'gates', 'hassabis', 'hinton', 'karpathy', 'musk', 'nadella', 'norvig', 'pichai'], true) => 'Specialists',
                in_array($id, ['devops', 'infra', 'infra-manager', 'sre-team', 'storage', 'harbor', 'net'], true) => 'Operations',
                default => 'Core',
            },
        ];
    }
}

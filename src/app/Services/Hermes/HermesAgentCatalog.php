<?php

declare(strict_types=1);

namespace App\Services\Hermes;

final class HermesAgentCatalog
{
    /** @var array<string, array{name: string, role: string, group: string, profile: string}> */
    public const CATALOG = [
        'jarvis' => [
            'name' => 'Jarvis',
            'role' => 'CEO — visão, prioridades, delegação',
            'group' => 'Executive',
            'profile' => 'jarvis',
        ],
        'elon' => [
            'name' => 'Elon',
            'role' => 'CPO/CRO — produto, pesquisa, inovação',
            'group' => 'Executive',
            'profile' => 'elon',
        ],
        'satya' => [
            'name' => 'Satya',
            'role' => 'COO — execução, código, entrega',
            'group' => 'Executive',
            'profile' => 'satya',
        ],
        'werner' => [
            'name' => 'Werner',
            'role' => 'VP Infra — Proxmox, rede, plataforma',
            'group' => 'Infrastructure',
            'profile' => 'werner',
        ],
        'curator' => [
            'name' => 'Curator',
            'role' => 'KB Steward — llm-wiki ingest, lint, index',
            'group' => 'Knowledge',
            'profile' => 'curator',
        ],
        'orion' => [
            'name' => 'Orion',
            'role' => 'VP Media — *arr stack, grabs, media-grabber',
            'group' => 'Media',
            'profile' => 'orion',
        ],
        'argus' => [
            'name' => 'Argus',
            'role' => 'Quota Steward — limites LLM, monitor providers, gate LiteLLM',
            'group' => 'FinOps',
            'profile' => 'argus',
        ],
    ];

    /**
     * @return array{name: string, role: string, group: string, profile: string}
     */
    public static function metadata(string $id): array
    {
        return self::CATALOG[$id] ?? [
            'name' => ucfirst($id),
            'role' => 'Hermes Agent',
            'group' => 'Agents',
            'profile' => $id,
        ];
    }
}

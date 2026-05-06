<?php

declare(strict_types=1);

namespace App\Services\OpenClaw;

final class OpenClawLocalCliService
{
    /**
     * @param  array<int, string|int|float>  $args
     * @return array{success: bool, output?: string|null, error?: string, command?: string}
     */
    public function run(string $command, array $args = []): array
    {
        $checkCmd = 'command -v openclaw >/dev/null 2>&1 && echo "installed" || echo "not_installed"';
        if (trim((string) shell_exec($checkCmd)) !== 'installed') {
            return ['success' => false, 'error' => 'OpenClaw not installed'];
        }

        $cmd = 'openclaw '.escapeshellarg($command);
        foreach ($args as $arg) {
            $cmd .= ' '.escapeshellarg((string) $arg);
        }
        $cmd .= ' 2>&1';

        $output = shell_exec($cmd);

        return [
            'success' => true,
            'output' => $output,
            'command' => $command,
        ];
    }
}

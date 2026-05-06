<?php

declare(strict_types=1);

namespace App\Services\OpenClaw;

use Symfony\Component\Process\Process;

final class OpenClawRemoteExecutor
{
    /**
     * @param  array<int, string>  $openClawArgs
     * @return array{success: bool, output: string, exit_code: int|null}
     */
    public function runOpenClaw(array $openClawArgs, int $timeout): array
    {
        $host = config('openclaw.ssh_host');
        $container = config('openclaw.docker_container');
        $connectTimeout = config('openclaw.ssh_connect_timeout');
        $remoteCommand = implode(' ', [
            'docker',
            'exec',
            $this->escapeShellArg($container),
            'openclaw',
            ...array_map(fn (string $arg) => $this->escapeShellArg($arg), $openClawArgs),
        ]);

        $process = new Process([
            'ssh',
            '-o',
            'BatchMode=yes',
            '-o',
            'ConnectTimeout='.$connectTimeout,
            $host,
            $remoteCommand,
        ]);
        $process->setTimeout($timeout);
        $process->run();

        return [
            'success' => $process->isSuccessful(),
            'output' => trim($process->getOutput()."\n".$process->getErrorOutput()),
            'exit_code' => $process->getExitCode(),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function decodeJsonOutput(string $output): array
    {
        $decoded = json_decode($output, true);
        if (is_array($decoded)) {
            return $decoded;
        }

        if (preg_match('/\{.*\}/s', $output, $matches)) {
            $decoded = json_decode($matches[0], true);
            if (is_array($decoded)) {
                return $decoded;
            }
        }

        return [];
    }

    private function escapeShellArg(string $value): string
    {
        return "'".str_replace("'", "'\\''", $value)."'";
    }
}

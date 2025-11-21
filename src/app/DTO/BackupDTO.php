<?php

declare(strict_types=1);

namespace App\DTO;

/**
 * Container Backup DTO
 *
 * Immutable data transfer object for backup metadata and status.
 *
 * @package App\DTO
 */
readonly class BackupDTO
{
    public const MODE_SNAPSHOT = 'snapshot';
    public const MODE_SUSPEND = 'suspend';
    public const MODE_STOP = 'stop';

    public const COMPRESS_NONE = '0';
    public const COMPRESS_LZO = 'lzo';
    public const COMPRESS_GZIP = 'gzip';
    public const COMPRESS_ZSTD = 'zstd';

    public const STATUS_PENDING = 'pending';
    public const STATUS_RUNNING = 'running';
    public const STATUS_COMPLETED = 'completed';
    public const STATUS_FAILED = 'failed';

    /**
     * @param int $vmid Container VMID
     * @param string $storage Storage name (e.g., 'local', 'fgsrv6-wg')
     * @param string $mode Backup mode (snapshot, suspend, stop)
     * @param string $compress Compression algorithm (0, lzo, gzip, zstd)
     * @param string|null $filename Backup filename (generated if null)
     * @param string $status Backup status
     * @param int|null $sizeMb Backup size in MB
     * @param string|null $taskId Proxmox task UPID
     * @param int $progress Progress percentage (0-100)
     * @param bool $removeOnRestore Remove backup after successful restore
     * @param string|null $notes User notes about backup
     * @param \DateTimeImmutable|null $createdAt Backup creation time
     * @param \DateTimeImmutable|null $completedAt Backup completion time
     * @param array<string, mixed> $metadata Additional metadata
     */
    public function __construct(
        public int $vmid,
        public string $storage = 'local',
        public string $mode = self::MODE_SNAPSHOT,
        public string $compress = self::COMPRESS_ZSTD,
        public ?string $filename = null,
        public string $status = self::STATUS_PENDING,
        public ?int $sizeMb = null,
        public ?string $taskId = null,
        public int $progress = 0,
        public bool $removeOnRestore = false,
        public ?string $notes = null,
        public ?\DateTimeImmutable $createdAt = null,
        public ?\DateTimeImmutable $completedAt = null,
        public array $metadata = [],
    ) {
        $this->validate();
    }

    /**
     * Create from array
     *
     * @param array<string, mixed> $data
     * @return self
     */
    public static function fromArray(array $data): self
    {
        return new self(
            vmid: (int)($data['vmid'] ?? throw new \InvalidArgumentException('vmid is required')),
            storage: $data['storage'] ?? 'local',
            mode: $data['mode'] ?? self::MODE_SNAPSHOT,
            compress: $data['compress'] ?? self::COMPRESS_ZSTD,
            filename: $data['filename'] ?? null,
            status: $data['status'] ?? self::STATUS_PENDING,
            sizeMb: isset($data['size_mb']) ? (int)$data['size_mb'] : null,
            taskId: $data['task_id'] ?? $data['task'] ?? null,
            progress: (int)($data['progress'] ?? 0),
            removeOnRestore: (bool)($data['remove'] ?? $data['remove_on_restore'] ?? false),
            notes: $data['notes'] ?? null,
            createdAt: isset($data['created_at']) ? new \DateTimeImmutable($data['created_at']) : null,
            completedAt: isset($data['completed_at']) ? new \DateTimeImmutable($data['completed_at']) : null,
            metadata: $data['metadata'] ?? [],
        );
    }

    /**
     * Create pending backup
     *
     * @param int $vmid
     * @param string $storage
     * @param string $mode
     * @param string $compress
     * @return self
     */
    public static function pending(int $vmid, string $storage = 'local', string $mode = self::MODE_SNAPSHOT, string $compress = self::COMPRESS_ZSTD): self
    {
        return new self(
            vmid: $vmid,
            storage: $storage,
            mode: $mode,
            compress: $compress,
            status: self::STATUS_PENDING,
            createdAt: new \DateTimeImmutable(),
        );
    }

    /**
     * Convert to Proxmox API parameters
     *
     * @return array<string, mixed>
     */
    public function toProxmoxParams(): array
    {
        $params = [
            'vmid' => $this->vmid,
            'mode' => $this->mode,
            'compress' => $this->compress,
            'storage' => $this->storage,
            'remove' => $this->removeOnRestore ? 1 : 0,
        ];

        if ($this->notes) {
            $params['notes'] = $this->notes;
        }

        return $params;
    }

    /**
     * Convert to database attributes
     *
     * @return array<string, mixed>
     */
    public function toDatabaseAttributes(): array
    {
        return [
            'container_id' => null, // Set by caller
            'storage' => $this->storage,
            'filename' => $this->filename,
            'size_mb' => $this->sizeMb,
            'mode' => $this->mode,
            'compress' => $this->compress,
            'status' => $this->status,
            'task_id' => $this->taskId,
            'notes' => $this->notes,
            'metadata' => $this->metadata,
            'created_at' => $this->createdAt,
            'completed_at' => $this->completedAt,
        ];
    }

    /**
     * Update with task ID
     *
     * @param string $taskId
     * @return self
     */
    public function withTaskId(string $taskId): self
    {
        return new self(
            vmid: $this->vmid,
            storage: $this->storage,
            mode: $this->mode,
            compress: $this->compress,
            filename: $this->filename,
            status: self::STATUS_RUNNING,
            sizeMb: $this->sizeMb,
            taskId: $taskId,
            progress: $this->progress,
            removeOnRestore: $this->removeOnRestore,
            notes: $this->notes,
            createdAt: $this->createdAt,
            completedAt: $this->completedAt,
            metadata: $this->metadata,
        );
    }

    /**
     * Mark as completed
     *
     * @param string $filename
     * @param int $sizeMb
     * @return self
     */
    public function withCompleted(string $filename, int $sizeMb): self
    {
        return new self(
            vmid: $this->vmid,
            storage: $this->storage,
            mode: $this->mode,
            compress: $this->compress,
            filename: $filename,
            status: self::STATUS_COMPLETED,
            sizeMb: $sizeMb,
            taskId: $this->taskId,
            progress: 100,
            removeOnRestore: $this->removeOnRestore,
            notes: $this->notes,
            createdAt: $this->createdAt,
            completedAt: new \DateTimeImmutable(),
            metadata: $this->metadata,
        );
    }

    /**
     * Mark as failed
     *
     * @param string $error
     * @return self
     */
    public function withError(string $error): self
    {
        return new self(
            vmid: $this->vmid,
            storage: $this->storage,
            mode: $this->mode,
            compress: $this->compress,
            filename: $this->filename,
            status: self::STATUS_FAILED,
            sizeMb: $this->sizeMb,
            taskId: $this->taskId,
            progress: $this->progress,
            removeOnRestore: $this->removeOnRestore,
            notes: $this->notes,
            createdAt: $this->createdAt,
            completedAt: new \DateTimeImmutable(),
            metadata: array_merge($this->metadata, ['error' => $error]),
        );
    }

    /**
     * Validate configuration
     *
     * @throws \InvalidArgumentException
     */
    private function validate(): void
    {
        $validModes = [self::MODE_SNAPSHOT, self::MODE_SUSPEND, self::MODE_STOP];
        if (!in_array($this->mode, $validModes, true)) {
            throw new \InvalidArgumentException("Invalid mode: {$this->mode}");
        }

        $validCompress = [self::COMPRESS_NONE, self::COMPRESS_LZO, self::COMPRESS_GZIP, self::COMPRESS_ZSTD];
        if (!in_array($this->compress, $validCompress, true)) {
            throw new \InvalidArgumentException("Invalid compress: {$this->compress}");
        }

        $validStatuses = [self::STATUS_PENDING, self::STATUS_RUNNING, self::STATUS_COMPLETED, self::STATUS_FAILED];
        if (!in_array($this->status, $validStatuses, true)) {
            throw new \InvalidArgumentException("Invalid status: {$this->status}");
        }

        if ($this->progress < 0 || $this->progress > 100) {
            throw new \InvalidArgumentException("Progress must be between 0 and 100, got {$this->progress}");
        }
    }

    /**
     * Check if backup is in progress
     *
     * @return bool
     */
    public function isInProgress(): bool
    {
        return in_array($this->status, [self::STATUS_PENDING, self::STATUS_RUNNING], true);
    }

    /**
     * Check if backup is completed
     *
     * @return bool
     */
    public function isCompleted(): bool
    {
        return $this->status === self::STATUS_COMPLETED;
    }

    /**
     * Check if backup failed
     *
     * @return bool
     */
    public function isFailed(): bool
    {
        return $this->status === self::STATUS_FAILED;
    }

    /**
     * Get duration in seconds
     *
     * @return int|null
     */
    public function getDurationSeconds(): ?int
    {
        if (!$this->createdAt || !$this->completedAt) {
            return null;
        }

        return $this->completedAt->getTimestamp() - $this->createdAt->getTimestamp();
    }

    /**
     * Get backup speed in MB/s
     *
     * @return float|null
     */
    public function getBackupSpeed(): ?float
    {
        if (!$this->sizeMb || !$this->getDurationSeconds()) {
            return null;
        }

        return $this->sizeMb / $this->getDurationSeconds();
    }
}

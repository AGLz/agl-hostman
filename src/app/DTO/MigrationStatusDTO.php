<?php

declare(strict_types=1);

namespace App\DTO;

/**
 * Container Migration Status DTO
 *
 * Immutable data transfer object for migration progress tracking.
 *
 * @package App\DTO
 */
readonly class MigrationStatusDTO
{
    public const STATUS_PENDING = 'pending';
    public const STATUS_PREPARING = 'preparing';
    public const STATUS_SYNCING = 'syncing';
    public const STATUS_MIGRATING = 'migrating';
    public const STATUS_COMPLETING = 'completing';
    public const STATUS_COMPLETED = 'completed';
    public const STATUS_FAILED = 'failed';

    /**
     * @param int $vmid Container VMID
     * @param string $sourceNode Source Proxmox node
     * @param string $targetNode Target Proxmox node
     * @param string $status Current migration status
     * @param int $progress Progress percentage (0-100)
     * @param bool $online Online (live) migration
     * @param string|null $taskId Proxmox task UPID
     * @param float|null $transferredMb Data transferred in MB
     * @param float|null $totalMb Total data size in MB
     * @param int|null $estimatedSecondsRemaining Estimated time remaining
     * @param string|null $error Error message if failed
     * @param \DateTimeImmutable|null $startedAt Migration start time
     * @param \DateTimeImmutable|null $completedAt Migration completion time
     * @param array<string, mixed> $metadata Additional metadata
     */
    public function __construct(
        public int $vmid,
        public string $sourceNode,
        public string $targetNode,
        public string $status,
        public int $progress = 0,
        public bool $online = false,
        public ?string $taskId = null,
        public ?float $transferredMb = null,
        public ?float $totalMb = null,
        public ?int $estimatedSecondsRemaining = null,
        public ?string $error = null,
        public ?\DateTimeImmutable $startedAt = null,
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
            sourceNode: $data['source_node'] ?? throw new \InvalidArgumentException('source_node is required'),
            targetNode: $data['target_node'] ?? throw new \InvalidArgumentException('target_node is required'),
            status: $data['status'] ?? self::STATUS_PENDING,
            progress: (int)($data['progress'] ?? 0),
            online: (bool)($data['online'] ?? false),
            taskId: $data['task_id'] ?? $data['task'] ?? null,
            transferredMb: isset($data['transferred_mb']) ? (float)$data['transferred_mb'] : null,
            totalMb: isset($data['total_mb']) ? (float)$data['total_mb'] : null,
            estimatedSecondsRemaining: isset($data['estimated_seconds']) ? (int)$data['estimated_seconds'] : null,
            error: $data['error'] ?? null,
            startedAt: isset($data['started_at']) ? new \DateTimeImmutable($data['started_at']) : null,
            completedAt: isset($data['completed_at']) ? new \DateTimeImmutable($data['completed_at']) : null,
            metadata: $data['metadata'] ?? [],
        );
    }

    /**
     * Create pending status
     *
     * @param int $vmid
     * @param string $sourceNode
     * @param string $targetNode
     * @param bool $online
     * @return self
     */
    public static function pending(int $vmid, string $sourceNode, string $targetNode, bool $online = false): self
    {
        return new self(
            vmid: $vmid,
            sourceNode: $sourceNode,
            targetNode: $targetNode,
            status: self::STATUS_PENDING,
            online: $online,
            startedAt: new \DateTimeImmutable(),
        );
    }

    /**
     * Update progress
     *
     * @param int $progress
     * @param string $status
     * @param float|null $transferredMb
     * @param float|null $totalMb
     * @return self
     */
    public function withProgress(int $progress, string $status, ?float $transferredMb = null, ?float $totalMb = null): self
    {
        return new self(
            vmid: $this->vmid,
            sourceNode: $this->sourceNode,
            targetNode: $this->targetNode,
            status: $status,
            progress: $progress,
            online: $this->online,
            taskId: $this->taskId,
            transferredMb: $transferredMb ?? $this->transferredMb,
            totalMb: $totalMb ?? $this->totalMb,
            estimatedSecondsRemaining: $this->calculateEstimatedTime($progress),
            error: $this->error,
            startedAt: $this->startedAt,
            completedAt: $progress >= 100 ? new \DateTimeImmutable() : null,
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
            sourceNode: $this->sourceNode,
            targetNode: $this->targetNode,
            status: self::STATUS_FAILED,
            progress: $this->progress,
            online: $this->online,
            taskId: $this->taskId,
            transferredMb: $this->transferredMb,
            totalMb: $this->totalMb,
            estimatedSecondsRemaining: null,
            error: $error,
            startedAt: $this->startedAt,
            completedAt: new \DateTimeImmutable(),
            metadata: $this->metadata,
        );
    }

    /**
     * Convert to array
     *
     * @return array<string, mixed>
     */
    public function toArray(): array
    {
        return [
            'vmid' => $this->vmid,
            'source_node' => $this->sourceNode,
            'target_node' => $this->targetNode,
            'status' => $this->status,
            'progress' => $this->progress,
            'online' => $this->online,
            'task_id' => $this->taskId,
            'transferred_mb' => $this->transferredMb,
            'total_mb' => $this->totalMb,
            'estimated_seconds' => $this->estimatedSecondsRemaining,
            'error' => $this->error,
            'started_at' => $this->startedAt?->format('c'),
            'completed_at' => $this->completedAt?->format('c'),
            'metadata' => $this->metadata,
        ];
    }

    /**
     * Validate configuration
     *
     * @throws \InvalidArgumentException
     */
    private function validate(): void
    {
        $validStatuses = [
            self::STATUS_PENDING,
            self::STATUS_PREPARING,
            self::STATUS_SYNCING,
            self::STATUS_MIGRATING,
            self::STATUS_COMPLETING,
            self::STATUS_COMPLETED,
            self::STATUS_FAILED,
        ];

        if (!in_array($this->status, $validStatuses, true)) {
            throw new \InvalidArgumentException("Invalid status: {$this->status}");
        }

        if ($this->progress < 0 || $this->progress > 100) {
            throw new \InvalidArgumentException("Progress must be between 0 and 100, got {$this->progress}");
        }

        if ($this->sourceNode === $this->targetNode) {
            throw new \InvalidArgumentException("Source and target node cannot be the same: {$this->sourceNode}");
        }
    }

    /**
     * Calculate estimated time remaining
     *
     * @param int $progress
     * @return int|null
     */
    private function calculateEstimatedTime(int $progress): ?int
    {
        if (!$this->startedAt || $progress <= 0 || $progress >= 100) {
            return null;
        }

        $elapsed = (new \DateTimeImmutable())->getTimestamp() - $this->startedAt->getTimestamp();
        $rate = $progress / $elapsed;
        $remaining = (100 - $progress) / $rate;

        return (int)$remaining;
    }

    /**
     * Check if migration is in progress
     *
     * @return bool
     */
    public function isInProgress(): bool
    {
        return in_array($this->status, [
            self::STATUS_PENDING,
            self::STATUS_PREPARING,
            self::STATUS_SYNCING,
            self::STATUS_MIGRATING,
            self::STATUS_COMPLETING,
        ], true);
    }

    /**
     * Check if migration is completed
     *
     * @return bool
     */
    public function isCompleted(): bool
    {
        return $this->status === self::STATUS_COMPLETED;
    }

    /**
     * Check if migration failed
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
        if (!$this->startedAt) {
            return null;
        }

        $end = $this->completedAt ?? new \DateTimeImmutable();
        return $end->getTimestamp() - $this->startedAt->getTimestamp();
    }

    /**
     * Get transfer rate in MB/s
     *
     * @return float|null
     */
    public function getTransferRate(): ?float
    {
        if (!$this->transferredMb || !$this->startedAt) {
            return null;
        }

        $duration = $this->getDurationSeconds();
        if (!$duration || $duration <= 0) {
            return null;
        }

        return $this->transferredMb / $duration;
    }
}

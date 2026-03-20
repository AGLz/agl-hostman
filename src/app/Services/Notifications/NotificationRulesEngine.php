<?php

namespace App\Services\Notifications;

use App\Models\NotificationChannel;
use App\Models\NotificationRule;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Log;

class NotificationRulesEngine
{
    /**
     * Regras embutidas (inicializadas no construtor: PHP 8.4 não permite closures em propriedades estáticas/padrão).
     *
     * @var array<int, array<string, mixed>>
     */
    protected array $noiseReductionRules;

    public function __construct()
    {
        $this->noiseReductionRules = [
            [
                'name' => 'suppress_info_business_hours',
                'condition' => fn ($type, $data) => $type === 'alert'
                    && $data->type === 'info'
                    && $this->isBusinessHours(),
                'action' => 'suppress',
            ],
            [
                'name' => 'group_container_restarts',
                'condition' => fn ($type, $data) => $type === 'alert'
                    && $data->source === 'container'
                    && str_contains($data->message ?? '', 'restart'),
                'action' => 'group',
                'window' => 300,
            ],
            [
                'name' => 'escalate_critical_production',
                'condition' => fn ($type, $data) => $type === 'alert'
                    && $data->type === 'critical'
                    && ($data->metadata['environment'] ?? '') === 'production',
                'action' => 'escalate',
                'channels' => ['slack', 'pagerduty', 'email'],
            ],
            [
                'name' => 'suppress_duplicates',
                'condition' => fn ($type, $data) => $type === 'alert'
                    && $this->hasDuplicateRecently($data, 600),
                'action' => 'suppress',
            ],
        ];
    }

    /**
     * Get channels that should receive the notification
     */
    public function getChannelsForNotification(string $type, mixed $data, array $options = []): Collection
    {
        // Get all active notification channels
        $allChannels = NotificationChannel::where('enabled', true)->get();

        // Get applicable rules
        $rules = $this->getApplicableRules($type, $data);

        // If no rules match, use default channels
        if ($rules->isEmpty()) {
            return $this->getDefaultChannels($type, $allChannels);
        }

        // Apply rules in priority order
        $channels = collect();
        $suppressRules = $rules->where('action', 'suppress');
        $routeRules = $rules->where('action', 'route');
        $escalateRules = $rules->where('action', 'escalate');

        // Check for suppression first
        if ($suppressRules->isNotEmpty()) {
            return collect(); // No channels
        }

        // Check for escalation
        if ($escalateRules->isNotEmpty()) {
            $escalateRule = $escalateRules->first();
            $channelTypes = $escalateRule->config['channels'] ?? ['slack', 'pagerduty'];

            foreach ($channelTypes as $channelType) {
                $channel = $allChannels->firstWhere('type', $channelType);
                if ($channel) {
                    $channels->push($channel);
                }
            }

            return $channels;
        }

        // Apply routing rules
        foreach ($routeRules as $rule) {
            $channelTypes = $rule->config['channels'] ?? [];

            foreach ($channelTypes as $channelType) {
                $channel = $allChannels->firstWhere('type', $channelType);
                if ($channel && ! $channels->contains('id', $channel->id)) {
                    $channels->push($channel);
                }
            }
        }

        // If no channels selected, use defaults
        if ($channels->isEmpty()) {
            return $this->getDefaultChannels($type, $allChannels);
        }

        return $channels;
    }

    /**
     * Check if notification should be suppressed
     */
    public function shouldSuppress(string $type, mixed $data): bool
    {
        // Check built-in noise reduction rules
        foreach ($this->noiseReductionRules as $rule) {
            if ($rule['action'] === 'suppress' &&
                isset($rule['condition']) &&
                call_user_func($rule['condition'], $type, $data)) {

                Log::info('Notification suppressed by built-in rule', [
                    'rule' => $rule['name'] ?? 'unknown',
                    'type' => $type,
                ]);

                return true;
            }
        }

        // Check custom suppression rules
        $suppressRules = NotificationRule::where('enabled', true)
            ->where('action', 'suppress')
            ->orderBy('priority', 'desc')
            ->get();

        foreach ($suppressRules as $rule) {
            if ($this->ruleMatches($rule, $type, $data)) {
                Log::info('Notification suppressed by custom rule', [
                    'rule_id' => $rule->id,
                    'rule_name' => $rule->name,
                ]);

                return true;
            }
        }

        return false;
    }

    /**
     * Get applicable rules for notification
     */
    protected function getApplicableRules(string $type, mixed $data): Collection
    {
        $rules = NotificationRule::where('enabled', true)
            ->orderBy('priority', 'desc')
            ->get();

        return $rules->filter(function ($rule) use ($type, $data) {
            return $this->ruleMatches($rule, $type, $data);
        });
    }

    /**
     * Check if rule matches notification
     */
    protected function ruleMatches(NotificationRule $rule, string $type, mixed $data): bool
    {
        $conditions = $rule->conditions ?? [];

        // Check notification type
        if (isset($conditions['notification_type']) &&
            $conditions['notification_type'] !== $type) {
            return false;
        }

        // Check alert severity (for alert notifications)
        if ($type === 'alert' && isset($conditions['severity'])) {
            if (is_array($conditions['severity'])) {
                if (! in_array($data->type, $conditions['severity'])) {
                    return false;
                }
            } else {
                if ($data->type !== $conditions['severity']) {
                    return false;
                }
            }
        }

        // Check source (for alert notifications)
        if ($type === 'alert' && isset($conditions['source'])) {
            if (is_array($conditions['source'])) {
                if (! in_array($data->source, $conditions['source'])) {
                    return false;
                }
            } else {
                if ($data->source !== $conditions['source']) {
                    return false;
                }
            }
        }

        // Check environment
        if (isset($conditions['environment'])) {
            $environment = $this->getEnvironment($type, $data);
            if (is_array($conditions['environment'])) {
                if (! in_array($environment, $conditions['environment'])) {
                    return false;
                }
            } else {
                if ($environment !== $conditions['environment']) {
                    return false;
                }
            }
        }

        // Check time window
        if (isset($conditions['time_window'])) {
            if (! $this->isInTimeWindow($conditions['time_window'])) {
                return false;
            }
        }

        // Check physical location
        if (isset($conditions['location'])) {
            $location = $this->getLocation($type, $data);
            if (is_array($conditions['location'])) {
                if (! in_array($location, $conditions['location'])) {
                    return false;
                }
            } else {
                if ($location !== $conditions['location']) {
                    return false;
                }
            }
        }

        // Check custom metadata conditions
        if (isset($conditions['metadata'])) {
            foreach ($conditions['metadata'] as $key => $value) {
                $dataValue = $this->getMetadataValue($data, $key);
                if ($dataValue !== $value) {
                    return false;
                }
            }
        }

        return true;
    }

    /**
     * Get default channels for notification type
     */
    protected function getDefaultChannels(string $type, Collection $allChannels): Collection
    {
        $defaults = config('notifications.defaults', [
            'deployment' => ['slack'],
            'alert' => ['slack', 'pagerduty'],
            'pr' => ['slack'],
            'custom' => ['slack'],
        ]);

        $channelTypes = $defaults[$type] ?? ['slack'];

        return $allChannels->filter(function ($channel) use ($channelTypes) {
            return in_array($channel->type, $channelTypes);
        });
    }

    /**
     * Get environment from notification data
     */
    protected function getEnvironment(string $type, mixed $data): ?string
    {
        if ($type === 'deployment') {
            return $data->environment->name ?? null;
        }

        if ($type === 'alert') {
            return $data->metadata['environment'] ?? null;
        }

        return null;
    }

    /**
     * Get location from notification data
     */
    protected function getLocation(string $type, mixed $data): ?string
    {
        if ($type === 'alert') {
            return $data->metadata['host'] ?? $data->metadata['location'] ?? null;
        }

        return null;
    }

    /**
     * Get metadata value
     */
    protected function getMetadataValue(mixed $data, string $key): mixed
    {
        if (isset($data->metadata[$key])) {
            return $data->metadata[$key];
        }

        if (isset($data->$key)) {
            return $data->$key;
        }

        return null;
    }

    /**
     * Check if current time is within time window
     */
    protected function isInTimeWindow(array $window): bool
    {
        $now = now();

        // Check day of week
        if (isset($window['days'])) {
            $currentDay = strtolower($now->format('l'));
            if (! in_array($currentDay, array_map('strtolower', $window['days']))) {
                return false;
            }
        }

        // Check time range
        if (isset($window['start_time']) && isset($window['end_time'])) {
            $currentTime = $now->format('H:i');
            $startTime = $window['start_time'];
            $endTime = $window['end_time'];

            if ($currentTime < $startTime || $currentTime > $endTime) {
                return false;
            }
        }

        // Check timezone
        if (isset($window['timezone'])) {
            // Convert to specified timezone before checking
            $now = $now->setTimezone($window['timezone']);
        }

        return true;
    }

    /**
     * Check if it's business hours
     */
    protected function isBusinessHours(): bool
    {
        $now = now();
        $dayOfWeek = $now->dayOfWeek;
        $hour = $now->hour;

        // Monday-Friday
        if ($dayOfWeek >= 1 && $dayOfWeek <= 5) {
            // 9 AM - 5 PM
            return $hour >= 9 && $hour < 17;
        }

        return false;
    }

    /**
     * Check for duplicate alerts recently
     */
    protected function hasDuplicateRecently(mixed $alert, int $windowSeconds): bool
    {
        if (! isset($alert->source) || ! isset($alert->source_id)) {
            return false;
        }

        $since = now()->subSeconds($windowSeconds);

        $count = \App\Models\Alert::where('source', $alert->source)
            ->where('source_id', $alert->source_id)
            ->where('type', $alert->type)
            ->where('created_at', '>=', $since)
            ->where('id', '!=', $alert->id ?? 0)
            ->count();

        return $count > 0;
    }

    /**
     * Evaluate custom rule condition
     */
    public function evaluateCondition(string $condition, string $type, mixed $data): bool
    {
        // This could support custom PHP expressions or a DSL
        // For now, we'll use a simple eval (in production, use a proper expression evaluator)

        try {
            // Build context for evaluation
            $context = [
                'type' => $type,
                'data' => $data,
                'now' => now(),
                'is_business_hours' => $this->isBusinessHours(),
            ];

            // Simple variable replacement
            $expression = $condition;
            foreach ($context as $key => $value) {
                $expression = str_replace('$'.$key, var_export($value, true), $expression);
            }

            // For safety, only allow specific functions
            $allowedFunctions = ['in_array', 'str_contains', 'isset', 'empty'];
            // In production, use a proper expression parser instead of eval

            return false; // Disabled for security
        } catch (\Exception $e) {
            Log::error('Failed to evaluate rule condition', [
                'condition' => $condition,
                'error' => $e->getMessage(),
            ]);

            return false;
        }
    }

    /**
     * Create rule from array
     */
    public function createRule(array $ruleData): NotificationRule
    {
        return NotificationRule::create([
            'name' => $ruleData['name'],
            'description' => $ruleData['description'] ?? null,
            'conditions' => $ruleData['conditions'] ?? [],
            'action' => $ruleData['action'],
            'config' => $ruleData['config'] ?? [],
            'priority' => $ruleData['priority'] ?? 0,
            'enabled' => $ruleData['enabled'] ?? true,
        ]);
    }

    /**
     * Update rule
     */
    public function updateRule(NotificationRule $rule, array $updates): bool
    {
        return $rule->update($updates);
    }

    /**
     * Delete rule
     */
    public function deleteRule(NotificationRule $rule): bool
    {
        return $rule->delete();
    }

    /**
     * Test rule against sample data
     */
    public function testRule(NotificationRule $rule, string $type, mixed $sampleData): array
    {
        $matches = $this->ruleMatches($rule, $type, $sampleData);

        return [
            'matches' => $matches,
            'rule' => $rule->toArray(),
            'type' => $type,
            'data' => $sampleData,
            'channels' => $matches ? $this->getChannelsForNotification($type, $sampleData) : [],
        ];
    }
}

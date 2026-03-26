<?php

namespace App\Services\Notifications;

use App\Models\Alert;
use App\Models\NotificationChannel;
use App\Models\NotificationHistory;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class PagerDutyService
{
    protected array $config;

    protected ?NotificationChannel $channel = null;

    public function __construct()
    {
        $this->config = config('notifications.pagerduty', []);
    }

    /**
     * Set the notification channel configuration
     */
    public function setChannel(NotificationChannel $channel): self
    {
        $this->channel = $channel;

        return $this;
    }

    /**
     * Create incident from alert
     */
    public function createIncident(Alert $alert): ?array
    {
        $severity = match ($alert->type) {
            'critical' => 'critical',
            'warning' => 'warning',
            'info' => 'info',
            default => 'info'
        };

        $urgency = $severity === 'critical' ? 'high' : 'low';

        $payload = [
            'incident' => [
                'type' => 'incident',
                'title' => $alert->title,
                'service' => [
                    'id' => $this->getServiceId(),
                    'type' => 'service_reference',
                ],
                'urgency' => $urgency,
                'body' => [
                    'type' => 'incident_body',
                    'details' => $this->formatIncidentDetails($alert),
                ],
                'incident_key' => "alert-{$alert->id}",
            ],
        ];

        // Add escalation policy if configured
        $escalationPolicyId = $this->getEscalationPolicyId();
        if ($escalationPolicyId) {
            $payload['incident']['escalation_policy'] = [
                'id' => $escalationPolicyId,
                'type' => 'escalation_policy_reference',
            ];
        }

        $historyId = $this->createHistory($payload, 'incident', $alert->id);

        try {
            $response = Http::timeout(10)
                ->withHeaders([
                    'Authorization' => 'Token token='.$this->getApiKey(),
                    'Content-Type' => 'application/json',
                    'Accept' => 'application/vnd.pagerduty+json;version=2',
                    'From' => $this->config['from_email'] ?? 'alerts@aglz.io',
                ])
                ->retry(3, 1000)
                ->post($this->getApiUrl('/incidents'), $payload);

            if ($response->successful()) {
                $incident = $response->json('incident');

                // Save PagerDuty incident ID to alert
                $alert->update([
                    'metadata' => array_merge($alert->metadata ?? [], [
                        'pagerduty_incident_id' => $incident['id'],
                        'pagerduty_incident_number' => $incident['incident_number'],
                        'pagerduty_html_url' => $incident['html_url'],
                    ]),
                ]);

                $this->updateHistory($historyId, true, $response->json());

                Log::info('PagerDuty incident created', [
                    'alert_id' => $alert->id,
                    'incident_id' => $incident['id'],
                ]);

                return $incident;
            }

            $this->updateHistory($historyId, false, $response->json());

            Log::error('Failed to create PagerDuty incident', [
                'status' => $response->status(),
                'response' => $response->json(),
            ]);

            return null;

        } catch (\Exception $e) {
            $this->updateHistory($historyId, false, $e->getMessage());

            Log::error('PagerDuty incident creation exception', [
                'error' => $e->getMessage(),
                'alert_id' => $alert->id,
            ]);

            return null;
        }
    }

    /**
     * Acknowledge incident
     */
    public function acknowledgeIncident(Alert $alert, string $userId): bool
    {
        $incidentId = $alert->metadata['pagerduty_incident_id'] ?? null;

        if (! $incidentId) {
            Log::warning('No PagerDuty incident ID found for alert', ['alert_id' => $alert->id]);

            return false;
        }

        $payload = [
            'incidents' => [
                [
                    'id' => $incidentId,
                    'type' => 'incident_reference',
                    'status' => 'acknowledged',
                ],
            ],
        ];

        try {
            $response = Http::timeout(10)
                ->withHeaders([
                    'Authorization' => 'Token token='.$this->getApiKey(),
                    'Content-Type' => 'application/json',
                    'Accept' => 'application/vnd.pagerduty+json;version=2',
                    'From' => $userId,
                ])
                ->put($this->getApiUrl('/incidents'), $payload);

            $success = $response->successful();

            if (! $success) {
                Log::error('Failed to acknowledge PagerDuty incident', [
                    'status' => $response->status(),
                    'response' => $response->json(),
                ]);
            }

            return $success;

        } catch (\Exception $e) {
            Log::error('PagerDuty acknowledgment exception', [
                'error' => $e->getMessage(),
                'incident_id' => $incidentId,
            ]);

            return false;
        }
    }

    /**
     * Resolve incident
     */
    public function resolveIncident(Alert $alert, string $userId): bool
    {
        $incidentId = $alert->metadata['pagerduty_incident_id'] ?? null;

        if (! $incidentId) {
            Log::warning('No PagerDuty incident ID found for alert', ['alert_id' => $alert->id]);

            return false;
        }

        $payload = [
            'incidents' => [
                [
                    'id' => $incidentId,
                    'type' => 'incident_reference',
                    'status' => 'resolved',
                ],
            ],
        ];

        try {
            $response = Http::timeout(10)
                ->withHeaders([
                    'Authorization' => 'Token token='.$this->getApiKey(),
                    'Content-Type' => 'application/json',
                    'Accept' => 'application/vnd.pagerduty+json;version=2',
                    'From' => $userId,
                ])
                ->put($this->getApiUrl('/incidents'), $payload);

            $success = $response->successful();

            if (! $success) {
                Log::error('Failed to resolve PagerDuty incident', [
                    'status' => $response->status(),
                    'response' => $response->json(),
                ]);
            }

            return $success;

        } catch (\Exception $e) {
            Log::error('PagerDuty resolution exception', [
                'error' => $e->getMessage(),
                'incident_id' => $incidentId,
            ]);

            return false;
        }
    }

    /**
     * Get incident details
     */
    public function getIncident(string $incidentId): ?array
    {
        try {
            $response = Http::timeout(10)
                ->withHeaders([
                    'Authorization' => 'Token token='.$this->getApiKey(),
                    'Accept' => 'application/vnd.pagerduty+json;version=2',
                ])
                ->get($this->getApiUrl("/incidents/{$incidentId}"));

            if ($response->successful()) {
                return $response->json('incident');
            }

            Log::error('Failed to get PagerDuty incident', [
                'status' => $response->status(),
                'incident_id' => $incidentId,
            ]);

            return null;

        } catch (\Exception $e) {
            Log::error('PagerDuty get incident exception', [
                'error' => $e->getMessage(),
                'incident_id' => $incidentId,
            ]);

            return null;
        }
    }

    /**
     * List on-call users
     */
    public function getOnCallUsers(?string $escalationPolicyId = null): array
    {
        $policyId = $escalationPolicyId ?? $this->getEscalationPolicyId();

        if (! $policyId) {
            return [];
        }

        try {
            $response = Http::timeout(10)
                ->withHeaders([
                    'Authorization' => 'Token token='.$this->getApiKey(),
                    'Accept' => 'application/vnd.pagerduty+json;version=2',
                ])
                ->get($this->getApiUrl('/oncalls'), [
                    'escalation_policy_ids[]' => $policyId,
                ]);

            if ($response->successful()) {
                return $response->json('oncalls', []);
            }

            return [];

        } catch (\Exception $e) {
            Log::error('PagerDuty get on-call users exception', [
                'error' => $e->getMessage(),
            ]);

            return [];
        }
    }

    /**
     * Format incident details
     */
    protected function formatIncidentDetails(Alert $alert): string
    {
        $details = 'Source: '.ucfirst($alert->source)."\n";
        $details .= 'Severity: '.ucfirst($alert->type)."\n";
        $details .= "Message: {$alert->message}\n\n";

        if (! empty($alert->metadata)) {
            $details .= "Additional Information:\n";
            foreach ($alert->metadata as $key => $value) {
                if (! in_array($key, ['pagerduty_incident_id', 'pagerduty_incident_number', 'pagerduty_html_url'])) {
                    $details .= '- '.ucfirst(str_replace('_', ' ', $key)).': '.(is_array($value) ? json_encode($value) : $value)."\n";
                }
            }
        }

        $details .= "\nView in AGL-HOSTMAN: ".route('alerts.show', $alert->id);

        return $details;
    }

    /**
     * Get API URL
     */
    protected function getApiUrl(string $endpoint): string
    {
        $baseUrl = $this->config['api_url'] ?? 'https://api.pagerduty.com';

        return rtrim($baseUrl, '/').$endpoint;
    }

    /**
     * Get API key
     */
    protected function getApiKey(): string
    {
        if ($this->channel) {
            return $this->channel->config['api_key'] ?? '';
        }

        return $this->config['api_key'] ?? '';
    }

    /**
     * Get service ID
     */
    protected function getServiceId(): string
    {
        if ($this->channel) {
            return $this->channel->config['service_id'] ?? '';
        }

        return $this->config['service_id'] ?? '';
    }

    /**
     * Get escalation policy ID
     */
    protected function getEscalationPolicyId(): ?string
    {
        if ($this->channel) {
            return $this->channel->config['escalation_policy_id'] ?? null;
        }

        return $this->config['escalation_policy_id'] ?? null;
    }

    /**
     * Create notification history record
     */
    protected function createHistory(array $payload, string $type, mixed $sourceId): ?int
    {
        try {
            $history = NotificationHistory::create([
                'channel_type' => 'pagerduty',
                'notification_type' => $type,
                'source_id' => $sourceId,
                'payload' => $payload,
                'status' => 'pending',
                'attempts' => 1,
            ]);

            return $history->id;
        } catch (\Exception $e) {
            Log::error('Failed to create notification history', [
                'error' => $e->getMessage(),
            ]);

            return null;
        }
    }

    /**
     * Update notification history record
     */
    protected function updateHistory(?int $historyId, bool $success, mixed $response): void
    {
        if (! $historyId) {
            return;
        }

        try {
            NotificationHistory::where('id', $historyId)->update([
                'status' => $success ? 'sent' : 'failed',
                'response' => is_array($response) ? $response : ['error' => $response],
                'sent_at' => $success ? now() : null,
                'failed_at' => ! $success ? now() : null,
            ]);
        } catch (\Exception $e) {
            Log::error('Failed to update notification history', [
                'error' => $e->getMessage(),
                'history_id' => $historyId,
            ]);
        }
    }

    /**
     * Test PagerDuty connection
     */
    public function test(): array
    {
        $apiKey = $this->getApiKey();

        if (! $apiKey) {
            return [
                'success' => false,
                'message' => 'API key not configured',
            ];
        }

        try {
            $response = Http::timeout(10)
                ->withHeaders([
                    'Authorization' => 'Token token='.$apiKey,
                    'Accept' => 'application/vnd.pagerduty+json;version=2',
                ])
                ->get($this->getApiUrl('/abilities'));

            return [
                'success' => $response->successful(),
                'message' => $response->successful()
                    ? 'PagerDuty connection successful'
                    : 'Failed to connect to PagerDuty',
                'status' => $response->status(),
                'abilities' => $response->json('abilities', []),
            ];
        } catch (\Exception $e) {
            return [
                'success' => false,
                'message' => 'Exception occurred',
                'error' => $e->getMessage(),
            ];
        }
    }
}

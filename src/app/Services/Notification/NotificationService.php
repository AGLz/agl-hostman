<?php

declare(strict_types=1);

namespace App\Services\Notification;

use App\Models\Promotion;
use App\Models\User;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Log;

/**
 * Notification Service
 *
 * Multi-channel notifications for promotion workflow
 */
class NotificationService
{
    /**
     * Notify that a promotion has been requested
     */
    public function notifyPromotionRequested(Promotion $promotion): void
    {
        $message = sprintf(
            "🚀 Promotion Requested: %s → %s (v%s)\nRequested by: %s",
            $promotion->sourceEnvironment->type,
            $promotion->targetEnvironment->type,
            $promotion->source_version,
            $promotion->requested_by
        );

        $this->sendToAllChannels($message, 'info', [
            'promotion_id' => $promotion->id,
            'requires_approvals' => $promotion->requires_approvals,
        ]);
    }

    /**
     * Notify that a promotion has been approved
     */
    public function notifyPromotionApproved(Promotion $promotion, User $approver): void
    {
        $message = sprintf(
            "✅ Promotion Approved by %s: %s → %s (v%s)\nRemaining approvals: %d",
            $approver->name,
            $promotion->sourceEnvironment->type,
            $promotion->targetEnvironment->type,
            $promotion->source_version,
            $promotion->getRemainingApprovals()
        );

        $this->sendToAllChannels($message, 'success', [
            'promotion_id' => $promotion->id,
            'approver' => $approver->email,
        ]);
    }

    /**
     * Notify that a promotion is being deployed
     */
    public function notifyPromotionDeploying(Promotion $promotion): void
    {
        $message = sprintf(
            "⚙️ Deploying: %s → %s (v%s)",
            $promotion->sourceEnvironment->type,
            $promotion->targetEnvironment->type,
            $promotion->source_version
        );

        $this->sendToAllChannels($message, 'info', [
            'promotion_id' => $promotion->id,
            'status' => 'deploying',
        ]);
    }

    /**
     * Notify that a promotion has completed
     */
    public function notifyPromotionCompleted(Promotion $promotion): void
    {
        $testSummary = $promotion->getSmokeTestSummary();

        $message = sprintf(
            "🎉 Promotion Completed: %s → %s (v%s)\nTests: %d passed, %d failed\nDuration: %ds",
            $promotion->sourceEnvironment->type,
            $promotion->targetEnvironment->type,
            $promotion->target_version,
            $testSummary['passed'] ?? 0,
            $testSummary['failed'] ?? 0,
            $promotion->getDuration() ?? 0
        );

        $this->sendToAllChannels($message, 'success', [
            'promotion_id' => $promotion->id,
            'test_summary' => $testSummary,
        ]);
    }

    /**
     * Notify that a promotion has failed
     */
    public function notifyPromotionFailed(Promotion $promotion, string $reason): void
    {
        $message = sprintf(
            "❌ Promotion Failed: %s → %s (v%s)\nReason: %s",
            $promotion->sourceEnvironment->type,
            $promotion->targetEnvironment->type,
            $promotion->source_version,
            $reason
        );

        $this->sendToAllChannels($message, 'error', [
            'promotion_id' => $promotion->id,
            'reason' => $reason,
        ]);
    }

    /**
     * Notify that a rollback has been initiated
     */
    public function notifyRollbackInitiated(Promotion $promotion): void
    {
        $message = sprintf(
            "🔄 Rollback Initiated: %s (v%s)\nReason: %s",
            $promotion->targetEnvironment->type,
            $promotion->source_version,
            $promotion->rollback_reason ?? 'Unknown'
        );

        $this->sendToAllChannels($message, 'warning', [
            'promotion_id' => $promotion->id,
            'rollback_reason' => $promotion->rollback_reason,
        ]);
    }

    /**
     * Send notification to all enabled channels
     */
    private function sendToAllChannels(
        string $message,
        string $level = 'info',
        array $context = []
    ): void {
        // Send to Slack
        if (config('alerts.slack.enabled')) {
            $this->sendSlackNotification($message, $level, $context);
        }

        // Send to Discord
        if (config('alerts.discord.enabled')) {
            $this->sendDiscordNotification($message, $level, $context);
        }

        // Send to Email
        if (config('alerts.email.enabled')) {
            $this->sendEmailNotification($message, $level, $context);
        }

        // Log notification
        Log::info('Notification sent', [
            'message' => $message,
            'level' => $level,
            'context' => $context,
        ]);
    }

    /**
     * Send Slack notification
     */
    private function sendSlackNotification(
        string $message,
        string $level,
        array $context
    ): void {
        try {
            $webhookUrl = config('alerts.slack.webhook_url');

            if (!$webhookUrl) {
                Log::warning('Slack webhook URL not configured');
                return;
            }

            $color = match($level) {
                'success' => '#36a64f',
                'error' => '#d73a49',
                'warning' => '#fbca04',
                default => '#0366d6',
            };

            $response = Http::post($webhookUrl, [
                'attachments' => [[
                    'color' => $color,
                    'text' => $message,
                    'fields' => array_map(fn($k, $v) => [
                        'title' => $k,
                        'value' => is_array($v) ? json_encode($v) : $v,
                        'short' => true,
                    ], array_keys($context), $context),
                    'footer' => 'AGL Deployment System',
                    'ts' => time(),
                ]],
            ]);

            if (!$response->successful()) {
                Log::error('Slack notification failed', [
                    'status' => $response->status(),
                    'body' => $response->body(),
                ]);
            }
        } catch (\Exception $e) {
            Log::error('Slack notification error', [
                'error' => $e->getMessage(),
            ]);
        }
    }

    /**
     * Send Discord notification
     */
    private function sendDiscordNotification(
        string $message,
        string $level,
        array $context
    ): void {
        try {
            $webhookUrl = config('alerts.discord.webhook_url');

            if (!$webhookUrl) {
                Log::warning('Discord webhook URL not configured');
                return;
            }

            $color = match($level) {
                'success' => 0x36a64f,
                'error' => 0xd73a49,
                'warning' => 0xfbca04,
                default => 0x0366d6,
            };

            $response = Http::post($webhookUrl, [
                'embeds' => [[
                    'description' => $message,
                    'color' => $color,
                    'timestamp' => now()->toIso8601String(),
                    'footer' => [
                        'text' => 'AGL Deployment System',
                    ],
                ]],
            ]);

            if (!$response->successful()) {
                Log::error('Discord notification failed', [
                    'status' => $response->status(),
                    'body' => $response->body(),
                ]);
            }
        } catch (\Exception $e) {
            Log::error('Discord notification error', [
                'error' => $e->getMessage(),
            ]);
        }
    }

    /**
     * Send email notification
     */
    private function sendEmailNotification(
        string $message,
        string $level,
        array $context
    ): void {
        try {
            $recipients = config('alerts.email.recipients', []);

            if (empty($recipients)) {
                Log::warning('Email recipients not configured');
                return;
            }

            // TODO: Implement email notification with proper mail class
            Log::info('Email notification would be sent', [
                'recipients' => $recipients,
                'message' => $message,
            ]);
        } catch (\Exception $e) {
            Log::error('Email notification error', [
                'error' => $e->getMessage(),
            ]);
        }
    }

    /**
     * Test notification channel
     */
    public function testChannel(string $channel): array
    {
        $message = "Test notification from AGL Deployment System";

        try {
            switch ($channel) {
                case 'slack':
                    $this->sendSlackNotification($message, 'info', [
                        'test' => 'true',
                        'timestamp' => now()->toIso8601String(),
                    ]);
                    break;

                case 'discord':
                    $this->sendDiscordNotification($message, 'info', [
                        'test' => 'true',
                        'timestamp' => now()->toIso8601String(),
                    ]);
                    break;

                case 'email':
                    $this->sendEmailNotification($message, 'info', [
                        'test' => 'true',
                        'timestamp' => now()->toIso8601String(),
                    ]);
                    break;

                default:
                    return [
                        'success' => false,
                        'message' => 'Invalid channel',
                    ];
            }

            return [
                'success' => true,
                'message' => 'Test notification sent',
                'channel' => $channel,
            ];
        } catch (\Exception $e) {
            return [
                'success' => false,
                'message' => $e->getMessage(),
                'channel' => $channel,
            ];
        }
    }
}

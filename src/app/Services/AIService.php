<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\AIModelUsage;
use Exception;
use Generator;
use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * AI Integration Service
 *
 * Provides unified integration with multiple AI providers:
 * - OpenAI (GPT-4, GPT-3.5)
 * - Claude (Anthropic)
 * - Ollama (Local LLMs)
 *
 * Features:
 * - Streaming response support
 * - Usage tracking and logging
 * - Automatic failover
 * - Prediction and analysis methods
 */
class AIService
{
    protected array $config;

    protected array $providers;

    /**
     * Available model configurations
     */
    protected const MODELS = [
        'openai' => [
            'gpt-4-turbo' => ['max_tokens' => 128000, 'supports_streaming' => true],
            'gpt-4' => ['max_tokens' => 8192, 'supports_streaming' => true],
            'gpt-3.5-turbo' => ['max_tokens' => 4096, 'supports_streaming' => true],
        ],
        'claude' => [
            'claude-3-opus-20240229' => ['max_tokens' => 200000, 'supports_streaming' => true],
            'claude-3-sonnet-20240229' => ['max_tokens' => 200000, 'supports_streaming' => true],
            'claude-3-haiku-20240307' => ['max_tokens' => 200000, 'supports_streaming' => true],
        ],
        'ollama' => [
            'llama2' => ['max_tokens' => 4096, 'supports_streaming' => true],
            'mistral' => ['max_tokens' => 8192, 'supports_streaming' => true],
            'codellama' => ['max_tokens' => 4096, 'supports_streaming' => true],
            'neural-chat' => ['max_tokens' => 4096, 'supports_streaming' => true],
        ],
    ];

    public function __construct()
    {
        $this->config = config('ai', []);
        $this->providers = [
            'openai' => $this->config['providers']['openai'] ?? [],
            'claude' => $this->config['providers']['claude'] ?? [],
            'ollama' => $this->config['providers']['ollama'] ?? [],
        ];
    }

    /**
     * Generate predictions based on historical data
     *
     * @param  array  $data  Historical metrics/data
     * @param  string  $type  Prediction type (capacity, performance, failure, etc.)
     * @param  string|null  $model  Specific model to use
     * @return array Prediction results with confidence scores
     */
    public function generatePrediction(array $data, string $type = 'performance', ?string $model = null): array
    {
        $model = $model ?? $this->selectBestModelForTask('prediction');
        $provider = $this->getProviderForModel($model);

        $prompt = $this->buildPredictionPrompt($data, $type);

        $result = $this->executeQuery($provider, $model, $prompt, [
            'temperature' => 0.3,
            'max_tokens' => 2000,
            'response_format' => 'json',
        ]);

        if ($result['success']) {
            $this->trackUsage($provider, $model, 'prediction', $result['usage'] ?? []);

            return [
                'success' => true,
                'predictions' => $this->parsePredictionResponse($result['content']),
                'model_used' => $model,
                'confidence' => $result['confidence'] ?? 0.85,
                'timestamp' => now()->toIso8601String(),
            ];
        }

        return $result;
    }

    /**
     * Analyze system logs and metrics
     *
     * @param  array  $logs  Log entries to analyze
     * @param  array  $metrics  System metrics
     * @param  string|null  $model  Specific model to use
     * @return array Analysis results with insights and recommendations
     */
    public function analyzeLogsAndMetrics(array $logs, array $metrics, ?string $model = null): array
    {
        $model = $model ?? $this->selectBestModelForTask('analysis');
        $provider = $this->getProviderForModel($model);

        $prompt = $this->buildAnalysisPrompt($logs, $metrics);

        $result = $this->executeQuery($provider, $model, $prompt, [
            'temperature' => 0.4,
            'max_tokens' => 3000,
        ]);

        if ($result['success']) {
            $this->trackUsage($provider, $model, 'analysis', $result['usage'] ?? []);

            return [
                'success' => true,
                'analysis' => $this->parseAnalysisResponse($result['content']),
                'model_used' => $model,
                'timestamp' => now()->toIso8601String(),
            ];
        }

        return $result;
    }

    /**
     * Generate recommendations based on analysis
     *
     * @param  array  $context  Current system state/context
     * @param  string  $category  Recommendation category
     * @param  string|null  $model  Specific model to use
     * @return array Recommendations with priority and action items
     */
    public function generateRecommendations(array $context, string $category = 'optimization', ?string $model = null): array
    {
        $model = $model ?? $this->selectBestModelForTask('recommendations');
        $provider = $this->getProviderForModel($model);

        $prompt = $this->buildRecommendationPrompt($context, $category);

        $result = $this->executeQuery($provider, $model, $prompt, [
            'temperature' => 0.5,
            'max_tokens' => 2500,
        ]);

        if ($result['success']) {
            $this->trackUsage($provider, $model, 'recommendation', $result['usage'] ?? []);

            return [
                'success' => true,
                'recommendations' => $this->parseRecommendationResponse($result['content']),
                'model_used' => $model,
                'timestamp' => now()->toIso8601String(),
            ];
        }

        return $result;
    }

    /**
     * Interactive chat with AI
     *
     * @param  string  $message  User message
     * @param  array  $history  Conversation history
     * @param  string|null  $model  Specific model to use
     * @param  bool  $stream  Enable streaming response
     * @return array|string Response array or generator for streaming
     */
    public function chat(string $message, array $history = [], ?string $model = null, bool $stream = false): array|string|Generator
    {
        $model = $model ?? $this->config['default_model'] ?? 'gpt-4-turbo';
        $provider = $this->getProviderForModel($model);

        $messages = $this->buildChatMessages($message, $history);

        if ($stream) {
            return $this->streamChat($provider, $model, $messages);
        }

        $result = $this->executeQuery($provider, $model, $messages, [
            'temperature' => 0.7,
            'max_tokens' => 2000,
        ]);

        if ($result['success']) {
            $this->trackUsage($provider, $model, 'chat', $result['usage'] ?? []);

            return [
                'success' => true,
                'message' => $result['content'],
                'model_used' => $model,
                'timestamp' => now()->toIso8601String(),
            ];
        }

        return $result;
    }

    /**
     * Stream chat response
     */
    protected function streamChat(string $provider, string $model, array $messages): Generator
    {
        try {
            match ($provider) {
                'openai' => yield from $this->streamOpenAI($model, $messages),
                'claude' => yield from $this->streamClaude($model, $messages),
                'ollama' => yield from $this->streamOllama($model, $messages),
                default => throw new Exception("Streaming not supported for provider: {$provider}"),
            };
        } catch (Exception $e) {
            Log::error('AI streaming error', ['error' => $e->getMessage()]);
            yield ['error' => $e->getMessage()];
        }
    }

    /**
     * Stream OpenAI response
     */
    protected function streamOpenAI(string $model, array $messages): Generator
    {
        $apiKey = $this->providers['openai']['api_key'] ?? null;
        if (! $apiKey) {
            throw new Exception('OpenAI API key not configured');
        }

        $response = Http::withHeaders([
            'Authorization' => 'Bearer '.$apiKey,
            'Content-Type' => 'application/json',
        ])->withOptions([
            'stream' => true,
        ])->post('https://api.openai.com/v1/chat/completions', [
            'model' => $model,
            'messages' => $messages,
            'stream' => true,
            'temperature' => 0.7,
        ]);

        foreach ($this->readStream($response) as $chunk) {
            if (isset($chunk['choices'][0]['delta']['content'])) {
                yield [
                    'content' => $chunk['choices'][0]['delta']['content'],
                    'done' => $chunk['choices'][0]['finish_reason'] !== null,
                ];
            }
        }
    }

    /**
     * Stream Claude response
     */
    protected function streamClaude(string $model, array $messages): Generator
    {
        $apiKey = $this->providers['claude']['api_key'] ?? null;
        if (! $apiKey) {
            throw new Exception('Claude API key not configured');
        }

        $response = Http::withHeaders([
            'x-api-key' => $apiKey,
            'anthropic-version' => '2023-06-01',
            'content-type' => 'application/json',
        ])->withOptions([
            'stream' => true,
        ])->post('https://api.anthropic.com/v1/messages', [
            'model' => $model,
            'messages' => $messages,
            'max_tokens' => 4096,
            'stream' => true,
        ]);

        foreach ($this->readStream($response) as $chunk) {
            if ($chunk['type'] === 'content_block_delta') {
                yield [
                    'content' => $chunk['delta']['text'] ?? '',
                    'done' => false,
                ];
            } elseif ($chunk['type'] === 'message_stop') {
                yield ['done' => true];
            }
        }
    }

    /**
     * Stream Ollama response
     */
    protected function streamOllama(string $model, array $messages): Generator
    {
        $endpoint = $this->providers['ollama']['endpoint'] ?? 'http://localhost:11434';

        $prompt = $this->messagesToString($messages);

        $response = Http::timeout(120)->withOptions([
            'stream' => true,
        ])->post("{$endpoint}/api/generate", [
            'model' => $model,
            'prompt' => $prompt,
            'stream' => true,
        ]);

        foreach ($this->readStream($response) as $chunk) {
            if (isset($chunk['response'])) {
                yield [
                    'content' => $chunk['response'],
                    'done' => $chunk['done'] ?? false,
                ];
            }
        }
    }

    /**
     * Read stream line by line
     */
    protected function readStream($response): Generator
    {
        $handle = fopen($response->toPsrResponse()->getBody(), 'r');

        while ($line = fgets($handle)) {
            if (str_starts_with($line, 'data: ')) {
                $data = substr($line, 6);
                if ($data === '[DONE]') {
                    break;
                }
                $parsed = json_decode($data, true);
                if ($parsed) {
                    yield $parsed;
                }
            }
        }

        fclose($handle);
    }

    /**
     * Execute query against provider
     */
    protected function executeQuery(string $provider, string $model, string|array $input, array $options = []): array
    {
        try {
            return match ($provider) {
                'openai' => $this->queryOpenAI($model, $input, $options),
                'claude' => $this->queryClaude($model, $input, $options),
                'ollama' => $this->queryOllama($model, $input, $options),
                default => throw new Exception("Unknown provider: {$provider}"),
            };
        } catch (Exception $e) {
            Log::error('AI query error', [
                'provider' => $provider,
                'model' => $model,
                'error' => $e->getMessage(),
            ]);

            return [
                'success' => false,
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * Query OpenAI API
     */
    protected function queryOpenAI(string $model, string|array $input, array $options): array
    {
        $apiKey = $this->providers['openai']['api_key'] ?? null;
        if (! $apiKey) {
            throw new Exception('OpenAI API key not configured');
        }

        $messages = is_string($input) ? [['role' => 'user', 'content' => $input]] : $input;

        $response = Http::withHeaders([
            'Authorization' => 'Bearer '.$apiKey,
            'Content-Type' => 'application/json',
        ])->post('https://api.openai.com/v1/chat/completions', [
            'model' => $model,
            'messages' => $messages,
            'temperature' => $options['temperature'] ?? 0.7,
            'max_tokens' => $options['max_tokens'] ?? 4096,
        ]);

        if ($response->successful()) {
            $data = $response->json();

            return [
                'success' => true,
                'content' => $data['choices'][0]['message']['content'] ?? '',
                'usage' => $data['usage'] ?? [],
            ];
        }

        throw new Exception('OpenAI API error: '.$response->body());
    }

    /**
     * Query Claude API
     */
    protected function queryClaude(string $model, string|array $input, array $options): array
    {
        $apiKey = $this->providers['claude']['api_key'] ?? null;
        if (! $apiKey) {
            throw new Exception('Claude API key not configured');
        }

        $messages = is_string($input) ? [['role' => 'user', 'content' => $input]] : $input;

        $response = Http::withHeaders([
            'x-api-key' => $apiKey,
            'anthropic-version' => '2023-06-01',
            'content-type' => 'application/json',
        ])->post('https://api.anthropic.com/v1/messages', [
            'model' => $model,
            'messages' => $messages,
            'max_tokens' => $options['max_tokens'] ?? 4096,
            'temperature' => $options['temperature'] ?? 0.7,
        ]);

        if ($response->successful()) {
            $data = $response->json();

            return [
                'success' => true,
                'content' => $data['content'][0]['text'] ?? '',
                'usage' => $data['usage'] ?? [],
            ];
        }

        throw new Exception('Claude API error: '.$response->body());
    }

    /**
     * Query Ollama API
     */
    protected function queryOllama(string $model, string|array $input, array $options): array
    {
        $endpoint = $this->providers['ollama']['endpoint'] ?? 'http://localhost:11434';

        $prompt = is_string($input) ? $input : $this->messagesToString($input);

        $response = Http::timeout(120)->post("{$endpoint}/api/generate", [
            'model' => $model,
            'prompt' => $prompt,
            'stream' => false,
            'options' => [
                'temperature' => $options['temperature'] ?? 0.7,
                'num_predict' => $options['max_tokens'] ?? 2048,
            ],
        ]);

        if ($response->successful()) {
            $data = $response->json();

            return [
                'success' => true,
                'content' => $data['response'] ?? '',
                'usage' => [
                    'prompt_tokens' => $data['prompt_eval_count'] ?? 0,
                    'completion_tokens' => $data['eval_count'] ?? 0,
                ],
            ];
        }

        throw new Exception('Ollama API error: '.$response->body());
    }

    /**
     * Get list of available models
     */
    public function getAvailableModels(): array
    {
        $models = [];

        foreach (self::MODELS as $provider => $providerModels) {
            foreach ($providerModels as $model => $config) {
                $models[] = [
                    'id' => $model,
                    'provider' => $provider,
                    'max_tokens' => $config['max_tokens'],
                    'supports_streaming' => $config['supports_streaming'],
                    'available' => $this->isModelAvailable($provider, $model),
                ];
            }
        }

        return $models;
    }

    /**
     * Check if model is available
     */
    protected function isModelAvailable(string $provider, string $model): bool
    {
        return match ($provider) {
            'openai' => ! empty($this->providers['openai']['api_key']),
            'claude' => ! empty($this->providers['claude']['api_key']),
            'ollama' => $this->checkOllamaConnection(),
            default => false,
        };
    }

    /**
     * Check Ollama connection
     */
    protected function checkOllamaConnection(): bool
    {
        try {
            $endpoint = $this->providers['ollama']['endpoint'] ?? 'http://localhost:11434';
            $response = Http::timeout(5)->get("{$endpoint}/api/tags");

            return $response->successful();
        } catch (Exception) {
            return false;
        }
    }

    /**
     * Select best model for task type
     */
    protected function selectBestModelForTask(string $task): string
    {
        $preferences = [
            'prediction' => ['claude', 'claude-3-opus-20240229'],
            'analysis' => ['claude', 'claude-3-sonnet-20240229'],
            'recommendations' => ['openai', 'gpt-4-turbo'],
            'chat' => ['claude', 'claude-3-opus-20240229'],
        ];

        $preferred = $preferences[$task] ?? ['claude', 'claude-3-opus-20240229'];
        $provider = $preferred[0];
        $model = $preferred[1];

        if ($this->isModelAvailable($provider, $model)) {
            return $model;
        }

        // Fallback to first available model
        foreach ($this->getAvailableModels() as $modelInfo) {
            if ($modelInfo['available']) {
                return $modelInfo['id'];
            }
        }

        return $this->config['default_model'] ?? 'gpt-4-turbo';
    }

    /**
     * Get provider for model
     */
    protected function getProviderForModel(string $model): string
    {
        foreach (self::MODELS as $provider => $models) {
            if (isset($models[$model])) {
                return $provider;
            }
        }

        // Default to OpenAI for unknown models
        return 'openai';
    }

    /**
     * Track API usage
     */
    protected function trackUsage(string $provider, string $model, string $task, array $usage): void
    {
        try {
            AIModelUsage::create([
                'provider' => $provider,
                'model' => $model,
                'task_type' => $task,
                'prompt_tokens' => $usage['prompt_tokens'] ?? 0,
                'completion_tokens' => $usage['completion_tokens'] ?? 0,
                'total_tokens' => $usage['total_tokens'] ?? ($usage['prompt_tokens'] ?? 0) + ($usage['completion_tokens'] ?? 0),
                'user_id' => auth()->id(),
            ]);
        } catch (Exception $e) {
            Log::warning('Failed to track AI usage', ['error' => $e->getMessage()]);
        }
    }

    /**
     * Build prediction prompt
     */
    protected function buildPredictionPrompt(array $data, string $type): string
    {
        return 'You are a predictive analytics system for infrastructure management. '.
               "Analyze the following data and provide predictions for {$type}.\n\n".
               "Data:\n".json_encode($data, JSON_PRETTY_PRINT)."\n\n".
               "Provide your response as JSON with this structure:\n".
               "{\n  \"predictions\": [...],\n  \"confidence\": 0.0-1.0,\n  \"reasoning\": \"...\",\n  \"timeframe\": \"...\"\n}";
    }

    /**
     * Build analysis prompt
     */
    protected function buildAnalysisPrompt(array $logs, array $metrics): string
    {
        return "You are a system analysis expert. Analyze the following logs and metrics.\n\n".
               "Logs:\n".json_encode(array_slice($logs, 0, 50), JSON_PRETTY_PRINT)."\n\n".
               "Metrics:\n".json_encode($metrics, JSON_PRETTY_PRINT)."\n\n".
               "Provide:\n1. Key findings\n2. Anomalies detected\n3. Root causes (if applicable)\n4. Recommendations\n\n".
               'Format as JSON.';
    }

    /**
     * Build recommendation prompt
     */
    protected function buildRecommendationPrompt(array $context, string $category): string
    {
        return "You are an infrastructure optimization expert. Provide recommendations for {$category}.\n\n".
               "Context:\n".json_encode($context, JSON_PRETTY_PRINT)."\n\n".
               "Provide prioritized recommendations as JSON:\n".
               "{\n  \"recommendations\": [{\n    \"priority\": \"high|medium|low\",\n    \"action\": \"...\",\n    \"expected_impact\": \"...\",\n    \"effort\": \"...\"\n  }]\n}";
    }

    /**
     * Build chat messages
     */
    protected function buildChatMessages(string $message, array $history): array
    {
        $messages = [];

        foreach ($history as $item) {
            $messages[] = [
                'role' => $item['role'] ?? 'user',
                'content' => $item['content'] ?? '',
            ];
        }

        $messages[] = ['role' => 'user', 'content' => $message];

        return $messages;
    }

    /**
     * Convert messages array to string
     */
    protected function messagesToString(array $messages): string
    {
        $result = '';
        foreach ($messages as $msg) {
            $role = $msg['role'] ?? 'user';
            $content = $msg['content'] ?? '';
            $result .= "{$role}: {$content}\n\n";
        }

        return $result;
    }

    /**
     * Parse prediction response
     */
    protected function parsePredictionResponse(string $content): array
    {
        $jsonStart = strpos($content, '{');
        $jsonEnd = strrpos($content, '}');

        if ($jsonStart !== false && $jsonEnd !== false) {
            $json = substr($content, $jsonStart, $jsonEnd - $jsonStart + 1);
            $parsed = json_decode($json, true);

            if (json_last_error() === JSON_ERROR_NONE) {
                return $parsed;
            }
        }

        return [
            'predictions' => [],
            'raw_response' => $content,
        ];
    }

    /**
     * Parse analysis response
     */
    protected function parseAnalysisResponse(string $content): array
    {
        $jsonStart = strpos($content, '{');
        $jsonEnd = strrpos($content, '}');

        if ($jsonStart !== false && $jsonEnd !== false) {
            $json = substr($content, $jsonStart, $jsonEnd - $jsonStart + 1);
            $parsed = json_decode($json, true);

            if (json_last_error() === JSON_ERROR_NONE) {
                return $parsed;
            }
        }

        return [
            'findings' => $content,
            'raw_response' => $content,
        ];
    }

    /**
     * Parse recommendation response
     */
    protected function parseRecommendationResponse(string $content): array
    {
        $jsonStart = strpos($content, '{');
        $jsonEnd = strrpos($content, '}');

        if ($jsonStart !== false && $jsonEnd !== false) {
            $json = substr($content, $jsonStart, $jsonEnd - $jsonStart + 1);
            $parsed = json_decode($json, true);

            if (json_last_error() === JSON_ERROR_NONE) {
                return $parsed['recommendations'] ?? [];
            }
        }

        return [
            ['recommendation' => $content],
        ];
    }
}

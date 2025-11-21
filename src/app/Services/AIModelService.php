<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Http\Client\Pool;
use Illuminate\Http\Client\Response;
use Exception;

class AIModelService
{
    protected array $models = [];
    protected array $config = [];

    public function __construct()
    {
        $this->config = config('services.ai', []);
        $this->initializeModels();
    }

    /**
     * Initialize available AI models
     */
    protected function initializeModels(): void
    {
        $this->models = [
            'claude' => [
                'name' => 'Claude',
                'provider' => 'Anthropic',
                'capabilities' => ['text', 'code', 'analysis', 'reasoning'],
                'max_tokens' => 100000,
            ],
            'gemini' => [
                'name' => 'Gemini',
                'provider' => 'Google',
                'capabilities' => ['text', 'code', 'multimodal', 'reasoning'],
                'max_tokens' => 32768,
            ],
            'openai' => [
                'name' => 'GPT-4',
                'provider' => 'OpenAI',
                'capabilities' => ['text', 'code', 'analysis', 'function_calling'],
                'max_tokens' => 128000,
            ],
            'abacusai' => [
                'name' => 'AbacusAI',
                'provider' => 'AbacusAI',
                'capabilities' => ['text', 'code', 'data_analysis', 'ml_ops'],
                'max_tokens' => 32768,
            ],
            'ollama' => [
                'name' => 'Ollama',
                'provider' => 'Local',
                'capabilities' => ['text', 'code', 'offline'],
                'max_tokens' => 4096,
            ],
        ];
    }

    /**
     * Send a prompt to a specific AI model
     */
    public function query(string $model, string $prompt, array $options = []): array
    {
        if (!isset($this->models[$model])) {
            return [
                'success' => false,
                'error' => "Model {$model} not found",
            ];
        }

        try {
            switch ($model) {
                case 'claude':
                    return $this->queryClaude($prompt, $options);
                case 'gemini':
                    return $this->queryGemini($prompt, $options);
                case 'openai':
                    return $this->queryOpenAI($prompt, $options);
                case 'abacusai':
                    return $this->queryAbacusAI($prompt, $options);
                case 'ollama':
                    return $this->queryOllama($prompt, $options);
                default:
                    throw new Exception("Handler not implemented for {$model}");
            }
        } catch (Exception $e) {
            Log::error("AI Model query error", [
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
     * Query Claude API
     */
    protected function queryClaude(string $prompt, array $options = []): array
    {
        $apiKey = $this->config['claude']['api_key'] ?? null;
        if (!$apiKey) {
            throw new Exception('Claude API key not configured');
        }

        $response = Http::withHeaders([
            'x-api-key' => $apiKey,
            'anthropic-version' => '2023-06-01',
            'content-type' => 'application/json',
        ])->post('https://api.anthropic.com/v1/messages', [
            'model' => $this->config['claude']['model'] ?? 'claude-3-opus-20240229',
            'max_tokens' => $options['max_tokens'] ?? 4096,
            'messages' => [
                ['role' => 'user', 'content' => $prompt]
            ],
            'temperature' => $options['temperature'] ?? 0.7,
        ]);

        if ($response->successful()) {
            $data = $response->json();
            return [
                'success' => true,
                'content' => $data['content'][0]['text'] ?? '',
                'model' => 'claude',
                'usage' => $data['usage'] ?? [],
            ];
        }

        throw new Exception('Claude API request failed: ' . $response->body());
    }

    /**
     * Query Gemini API
     */
    protected function queryGemini(string $prompt, array $options = []): array
    {
        $apiKey = $this->config['gemini']['api_key'] ?? null;
        if (!$apiKey) {
            throw new Exception('Gemini API key not configured');
        }

        $model = $this->config['gemini']['model'] ?? 'gemini-pro';
        $response = Http::post(
            "https://generativelanguage.googleapis.com/v1beta/models/{$model}:generateContent?key={$apiKey}",
            [
                'contents' => [
                    ['parts' => [['text' => $prompt]]]
                ],
                'generationConfig' => [
                    'temperature' => $options['temperature'] ?? 0.7,
                    'maxOutputTokens' => $options['max_tokens'] ?? 2048,
                ],
            ]
        );

        if ($response->successful()) {
            $data = $response->json();
            return [
                'success' => true,
                'content' => $data['candidates'][0]['content']['parts'][0]['text'] ?? '',
                'model' => 'gemini',
                'usage' => [],
            ];
        }

        throw new Exception('Gemini API request failed: ' . $response->body());
    }

    /**
     * Query OpenAI API
     */
    protected function queryOpenAI(string $prompt, array $options = []): array
    {
        $apiKey = $this->config['openai']['api_key'] ?? null;
        if (!$apiKey) {
            throw new Exception('OpenAI API key not configured');
        }

        $response = Http::withHeaders([
            'Authorization' => 'Bearer ' . $apiKey,
            'Content-Type' => 'application/json',
        ])->post('https://api.openai.com/v1/chat/completions', [
            'model' => $this->config['openai']['model'] ?? 'gpt-4-turbo-preview',
            'messages' => [
                ['role' => 'user', 'content' => $prompt]
            ],
            'temperature' => $options['temperature'] ?? 0.7,
            'max_tokens' => $options['max_tokens'] ?? 4096,
        ]);

        if ($response->successful()) {
            $data = $response->json();
            return [
                'success' => true,
                'content' => $data['choices'][0]['message']['content'] ?? '',
                'model' => 'openai',
                'usage' => $data['usage'] ?? [],
            ];
        }

        throw new Exception('OpenAI API request failed: ' . $response->body());
    }

    /**
     * Query AbacusAI API
     */
    protected function queryAbacusAI(string $prompt, array $options = []): array
    {
        $apiKey = $this->config['abacusai']['api_key'] ?? null;
        $endpoint = $this->config['abacusai']['endpoint'] ?? null;

        if (!$apiKey || !$endpoint) {
            throw new Exception('AbacusAI configuration incomplete');
        }

        $response = Http::withHeaders([
            'Authorization' => 'Bearer ' . $apiKey,
            'Content-Type' => 'application/json',
        ])->post($endpoint, [
            'prompt' => $prompt,
            'max_tokens' => $options['max_tokens'] ?? 2048,
            'temperature' => $options['temperature'] ?? 0.7,
        ]);

        if ($response->successful()) {
            $data = $response->json();
            return [
                'success' => true,
                'content' => $data['response'] ?? '',
                'model' => 'abacusai',
                'usage' => $data['usage'] ?? [],
            ];
        }

        throw new Exception('AbacusAI API request failed: ' . $response->body());
    }

    /**
     * Query Ollama (local)
     */
    protected function queryOllama(string $prompt, array $options = []): array
    {
        $endpoint = $this->config['ollama']['endpoint'] ?? 'http://ollama:11434';
        $model = $this->config['ollama']['model'] ?? 'llama2';

        $response = Http::timeout(60)->post("{$endpoint}/api/generate", [
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
                'model' => 'ollama',
                'usage' => [
                    'prompt_tokens' => $data['prompt_eval_count'] ?? 0,
                    'completion_tokens' => $data['eval_count'] ?? 0,
                ],
            ];
        }

        throw new Exception('Ollama API request failed: ' . $response->body());
    }

    /**
     * Multi-agent orchestration - query multiple models concurrently
     *
     * FIXED: Proper async execution using Http::pool()
     *
     * @param array<string> $models List of models to query
     * @param string $prompt The prompt to send
     * @param array $options Query options
     * @return array Results from all models
     */
    public function multiAgentQuery(array $models, string $prompt, array $options = []): array
    {
        $startTime = microtime(true);
        $results = [];

        // Use HTTP pool for true concurrent requests
        $responses = Http::pool(function (Pool $pool) use ($models, $prompt, $options) {
            $requests = [];

            foreach ($models as $model) {
                if (!isset($this->models[$model])) {
                    continue;
                }

                // Build request for each model
                $requests[$model] = match($model) {
                    'claude' => $this->buildClaudePoolRequest($pool, $prompt, $options),
                    'gemini' => $this->buildGeminiPoolRequest($pool, $prompt, $options),
                    'openai' => $this->buildOpenAIPoolRequest($pool, $prompt, $options),
                    'abacusai' => $this->buildAbacusAIPoolRequest($pool, $prompt, $options),
                    'ollama' => $this->buildOllamaPoolRequest($pool, $prompt, $options),
                    default => null,
                };
            }

            return $requests;
        });

        // Process responses
        foreach ($responses as $model => $response) {
            try {
                if ($response instanceof Response && $response->successful()) {
                    $results[$model] = $this->parseModelResponse($model, $response);
                } elseif ($response instanceof Exception) {
                    $results[$model] = [
                        'success' => false,
                        'error' => $response->getMessage(),
                    ];
                    Log::warning("Multi-agent query failed for {$model}", [
                        'error' => $response->getMessage(),
                    ]);
                } else {
                    $results[$model] = [
                        'success' => false,
                        'error' => 'Request failed',
                    ];
                }
            } catch (Exception $e) {
                $results[$model] = [
                    'success' => false,
                    'error' => $e->getMessage(),
                ];
            }
        }

        $executionTime = microtime(true) - $startTime;

        Log::info('Multi-agent query completed', [
            'models' => array_keys($results),
            'execution_time' => round($executionTime, 3),
            'success_count' => count(array_filter($results, fn($r) => $r['success'] ?? false)),
        ]);

        return [
            'success' => true,
            'results' => $results,
            'models' => array_keys($results),
            'execution_time' => round($executionTime, 3),
            'timestamp' => now()->toIso8601String(),
        ];
    }

    /**
     * Build Claude request for pool
     */
    private function buildClaudePoolRequest(Pool $pool, string $prompt, array $options)
    {
        $apiKey = $this->config['claude']['api_key'] ?? null;
        if (!$apiKey) {
            return null;
        }

        return $pool->withHeaders([
            'x-api-key' => $apiKey,
            'anthropic-version' => '2023-06-01',
            'content-type' => 'application/json',
        ])->post('https://api.anthropic.com/v1/messages', [
            'model' => $this->config['claude']['model'] ?? 'claude-3-opus-20240229',
            'max_tokens' => $options['max_tokens'] ?? 4096,
            'messages' => [['role' => 'user', 'content' => $prompt]],
            'temperature' => $options['temperature'] ?? 0.7,
        ]);
    }

    /**
     * Build Gemini request for pool
     */
    private function buildGeminiPoolRequest(Pool $pool, string $prompt, array $options)
    {
        $apiKey = $this->config['gemini']['api_key'] ?? null;
        if (!$apiKey) {
            return null;
        }

        $model = $this->config['gemini']['model'] ?? 'gemini-pro';
        return $pool->post(
            "https://generativelanguage.googleapis.com/v1beta/models/{$model}:generateContent?key={$apiKey}",
            [
                'contents' => [['parts' => [['text' => $prompt]]]],
                'generationConfig' => [
                    'temperature' => $options['temperature'] ?? 0.7,
                    'maxOutputTokens' => $options['max_tokens'] ?? 2048,
                ],
            ]
        );
    }

    /**
     * Build OpenAI request for pool
     */
    private function buildOpenAIPoolRequest(Pool $pool, string $prompt, array $options)
    {
        $apiKey = $this->config['openai']['api_key'] ?? null;
        if (!$apiKey) {
            return null;
        }

        return $pool->withHeaders([
            'Authorization' => 'Bearer ' . $apiKey,
            'Content-Type' => 'application/json',
        ])->post('https://api.openai.com/v1/chat/completions', [
            'model' => $this->config['openai']['model'] ?? 'gpt-4-turbo-preview',
            'messages' => [['role' => 'user', 'content' => $prompt]],
            'temperature' => $options['temperature'] ?? 0.7,
            'max_tokens' => $options['max_tokens'] ?? 4096,
        ]);
    }

    /**
     * Build AbacusAI request for pool
     */
    private function buildAbacusAIPoolRequest(Pool $pool, string $prompt, array $options)
    {
        $apiKey = $this->config['abacusai']['api_key'] ?? null;
        $endpoint = $this->config['abacusai']['endpoint'] ?? null;

        if (!$apiKey || !$endpoint) {
            return null;
        }

        return $pool->withHeaders([
            'Authorization' => 'Bearer ' . $apiKey,
            'Content-Type' => 'application/json',
        ])->post($endpoint, [
            'prompt' => $prompt,
            'max_tokens' => $options['max_tokens'] ?? 2048,
            'temperature' => $options['temperature'] ?? 0.7,
        ]);
    }

    /**
     * Build Ollama request for pool
     */
    private function buildOllamaPoolRequest(Pool $pool, string $prompt, array $options)
    {
        $endpoint = $this->config['ollama']['endpoint'] ?? 'http://ollama:11434';
        $model = $this->config['ollama']['model'] ?? 'llama2';

        return $pool->timeout(60)->post("{$endpoint}/api/generate", [
            'model' => $model,
            'prompt' => $prompt,
            'stream' => false,
            'options' => [
                'temperature' => $options['temperature'] ?? 0.7,
                'num_predict' => $options['max_tokens'] ?? 2048,
            ],
        ]);
    }

    /**
     * Parse model-specific response
     */
    private function parseModelResponse(string $model, Response $response): array
    {
        $data = $response->json();

        return match($model) {
            'claude' => [
                'success' => true,
                'content' => $data['content'][0]['text'] ?? '',
                'model' => 'claude',
                'usage' => $data['usage'] ?? [],
            ],
            'gemini' => [
                'success' => true,
                'content' => $data['candidates'][0]['content']['parts'][0]['text'] ?? '',
                'model' => 'gemini',
                'usage' => [],
            ],
            'openai' => [
                'success' => true,
                'content' => $data['choices'][0]['message']['content'] ?? '',
                'model' => 'openai',
                'usage' => $data['usage'] ?? [],
            ],
            'abacusai' => [
                'success' => true,
                'content' => $data['response'] ?? '',
                'model' => 'abacusai',
                'usage' => $data['usage'] ?? [],
            ],
            'ollama' => [
                'success' => true,
                'content' => $data['response'] ?? '',
                'model' => 'ollama',
                'usage' => [
                    'prompt_tokens' => $data['prompt_eval_count'] ?? 0,
                    'completion_tokens' => $data['eval_count'] ?? 0,
                ],
            ],
            default => ['success' => false, 'error' => 'Unknown model'],
        };
    }

    /**
     * Get available models
     */
    public function getAvailableModels(): array
    {
        $available = [];

        foreach ($this->models as $key => $model) {
            $configured = false;

            switch ($key) {
                case 'claude':
                    $configured = !empty($this->config['claude']['api_key']);
                    break;
                case 'gemini':
                    $configured = !empty($this->config['gemini']['api_key']);
                    break;
                case 'openai':
                    $configured = !empty($this->config['openai']['api_key']);
                    break;
                case 'abacusai':
                    $configured = !empty($this->config['abacusai']['api_key']);
                    break;
                case 'ollama':
                    $configured = true; // Always available if endpoint is reachable
                    break;
            }

            $available[$key] = array_merge($model, [
                'configured' => $configured,
                'key' => $key,
            ]);
        }

        return $available;
    }

    /**
     * Intelligent model selection based on task type
     */
    public function selectBestModel(string $taskType): string
    {
        $taskModelMap = [
            'code_generation' => 'claude',
            'data_analysis' => 'abacusai',
            'multimodal' => 'gemini',
            'function_calling' => 'openai',
            'offline' => 'ollama',
            'reasoning' => 'claude',
            'quick_response' => 'gemini',
        ];

        $selectedModel = $taskModelMap[$taskType] ?? 'claude';

        // Check if selected model is configured
        $available = $this->getAvailableModels();
        if (!$available[$selectedModel]['configured']) {
            // Fallback to first configured model
            foreach ($available as $key => $model) {
                if ($model['configured']) {
                    return $key;
                }
            }
        }

        return $selectedModel;
    }
}

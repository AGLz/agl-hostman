# Ollama API Guide - CT200 (192.168.0.200)

**Last Updated**: 2025-10-27
**Ollama Version**: 0.12.2
**Base URL**: http://192.168.0.200:11434

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Available Models](#available-models)
3. [API Endpoints](#api-endpoints)
4. [Code Examples](#code-examples)
5. [Performance Tips](#performance-tips)
6. [Troubleshooting](#troubleshooting)

---

## Quick Start

### Test API Availability
```bash
curl http://192.168.0.200:11434/api/tags
```

### Quick Inference
```bash
curl -X POST http://192.168.0.200:11434/api/generate \
  -d '{"model": "phi3:mini", "prompt": "Hello!", "stream": false}'
```

---

## Available Models

### Currently Installed

| Model | Size | Parameters | Quantization | Use Case |
|-------|------|------------|--------------|----------|
| **phi3:mini** | 2.2 GB | 3.8B | Q4_0 | Fast, general purpose, efficient |
| **llama3.2:1b** | 1.3 GB | 1.2B | Q8_0 | Ultra-fast, basic tasks |

### Models Being Installed

| Model | Size | Parameters | Use Case |
|-------|------|------------|----------|
| **mistral:7b-instruct-q4_0** | ~4 GB | 7B | High quality reasoning |
| **codellama:7b-code-q4_0** | ~4 GB | 7B | Code generation/completion |
| **llama3.2:3b** | ~2 GB | 3B | Better than 1B, still fast |

### Model Selection Guide

- **Ultra Fast** (< 1s response): `llama3.2:1b`
- **Balanced** (2-3s response): `phi3:mini`, `llama3.2:3b`
- **High Quality** (4-6s response): `mistral:7b-instruct-q4_0`
- **Code Tasks**: `codellama:7b-code-q4_0`

---

## API Endpoints

### 1. List Models
**GET** `/api/tags`

```bash
curl http://192.168.0.200:11434/api/tags
```

**Response**:
```json
{
  "models": [
    {
      "name": "phi3:mini",
      "model": "phi3:mini",
      "size": 2176178913,
      "digest": "4f222292793889a9a40a020799cfd28d53f3e01af25d48e06c5e708610fc47e9",
      "details": {
        "parameter_size": "3.8B",
        "quantization_level": "Q4_0"
      }
    }
  ]
}
```

---

### 2. Generate Completion (No Streaming)
**POST** `/api/generate`

```bash
curl -X POST http://192.168.0.200:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "phi3:mini",
    "prompt": "Explain quantum computing in simple terms",
    "stream": false
  }'
```

**Response**:
```json
{
  "model": "phi3:mini",
  "created_at": "2025-10-27T17:00:00.000Z",
  "response": "Quantum computing uses quantum mechanics...",
  "done": true,
  "total_duration": 2341234567,
  "load_duration": 123456789,
  "prompt_eval_count": 15,
  "eval_count": 87,
  "eval_duration": 1234567890
}
```

---

### 3. Generate Completion (Streaming)
**POST** `/api/generate`

```bash
curl -X POST http://192.168.0.200:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "phi3:mini",
    "prompt": "Write a haiku about AI",
    "stream": true
  }'
```

**Response** (NDJSON stream):
```json
{"model":"phi3:mini","created_at":"2025-10-27T17:00:00.000Z","response":"Silicon","done":false}
{"model":"phi3:mini","created_at":"2025-10-27T17:00:00.001Z","response":" minds","done":false}
{"model":"phi3:mini","created_at":"2025-10-27T17:00:00.002Z","response":" awakening","done":false}
...
{"model":"phi3:mini","created_at":"2025-10-27T17:00:00.100Z","response":"","done":true,"total_duration":...}
```

---

### 4. Chat Completion
**POST** `/api/chat`

```bash
curl -X POST http://192.168.0.200:11434/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model": "phi3:mini",
    "messages": [
      {"role": "system", "content": "You are a helpful assistant."},
      {"role": "user", "content": "What is the capital of France?"}
    ],
    "stream": false
  }'
```

**Response**:
```json
{
  "model": "phi3:mini",
  "created_at": "2025-10-27T17:00:00.000Z",
  "message": {
    "role": "assistant",
    "content": "The capital of France is Paris."
  },
  "done": true
}
```

---

### 5. Create Model (Pull from Registry)
**POST** `/api/pull`

```bash
curl -X POST http://192.168.0.200:11434/api/pull \
  -d '{"name": "phi3:mini"}'
```

---

### 6. Delete Model
**DELETE** `/api/delete`

```bash
curl -X DELETE http://192.168.0.200:11434/api/delete \
  -d '{"name": "llama3.2:1b"}'
```

---

### 7. Show Model Info
**POST** `/api/show`

```bash
curl -X POST http://192.168.0.200:11434/api/show \
  -d '{"name": "phi3:mini"}'
```

---

### 8. Embeddings
**POST** `/api/embeddings`

```bash
curl -X POST http://192.168.0.200:11434/api/embeddings \
  -d '{
    "model": "phi3:mini",
    "prompt": "This is a test sentence"
  }'
```

**Response**:
```json
{
  "embedding": [0.123, -0.456, 0.789, ...]
}
```

---

## Code Examples

### Python

#### Simple Completion
```python
import requests
import json

def ask_ollama(prompt, model="phi3:mini"):
    url = "http://192.168.0.200:11434/api/generate"
    payload = {
        "model": model,
        "prompt": prompt,
        "stream": False
    }

    response = requests.post(url, json=payload)
    return response.json()["response"]

# Usage
answer = ask_ollama("What is Python?")
print(answer)
```

#### Streaming Response
```python
import requests
import json

def stream_ollama(prompt, model="phi3:mini"):
    url = "http://192.168.0.200:11434/api/generate"
    payload = {
        "model": model,
        "prompt": prompt,
        "stream": True
    }

    response = requests.post(url, json=payload, stream=True)

    for line in response.iter_lines():
        if line:
            data = json.loads(line)
            if not data.get("done"):
                print(data["response"], end="", flush=True)
    print()

# Usage
stream_ollama("Write a story about AI")
```

#### Chat Conversation
```python
import requests

def chat_ollama(messages, model="phi3:mini"):
    url = "http://192.168.0.200:11434/api/chat"
    payload = {
        "model": model,
        "messages": messages,
        "stream": False
    }

    response = requests.post(url, json=payload)
    return response.json()["message"]["content"]

# Usage
conversation = [
    {"role": "system", "content": "You are a coding assistant."},
    {"role": "user", "content": "How do I reverse a list in Python?"}
]

answer = chat_ollama(conversation)
print(answer)
```

---

### JavaScript (Node.js)

#### Simple Completion
```javascript
const axios = require('axios');

async function askOllama(prompt, model = "phi3:mini") {
    const response = await axios.post('http://192.168.0.200:11434/api/generate', {
        model: model,
        prompt: prompt,
        stream: false
    });

    return response.data.response;
}

// Usage
askOllama("What is JavaScript?").then(console.log);
```

#### Streaming Response
```javascript
const axios = require('axios');

async function streamOllama(prompt, model = "phi3:mini") {
    const response = await axios.post(
        'http://192.168.0.200:11434/api/generate',
        {
            model: model,
            prompt: prompt,
            stream: true
        },
        { responseType: 'stream' }
    );

    response.data.on('data', (chunk) => {
        const data = JSON.parse(chunk.toString());
        if (!data.done) {
            process.stdout.write(data.response);
        }
    });
}

// Usage
streamOllama("Explain async/await in JavaScript");
```

---

### Bash/cURL

#### Quick Test
```bash
# Simple question
curl -X POST http://192.168.0.200:11434/api/generate \
  -d '{"model": "phi3:mini", "prompt": "Hello!", "stream": false}' \
  | jq -r '.response'

# Chat with context
curl -X POST http://192.168.0.200:11434/api/chat \
  -d '{
    "model": "phi3:mini",
    "messages": [
      {"role": "user", "content": "What is 2+2?"}
    ],
    "stream": false
  }' | jq -r '.message.content'
```

#### Batch Processing
```bash
#!/bin/bash
# Process multiple prompts

prompts=(
    "What is AI?"
    "What is ML?"
    "What is DL?"
)

for prompt in "${prompts[@]}"; do
    echo "Q: $prompt"
    response=$(curl -s -X POST http://192.168.0.200:11434/api/generate \
        -d "{\"model\": \"phi3:mini\", \"prompt\": \"$prompt\", \"stream\": false}" \
        | jq -r '.response')
    echo "A: $response"
    echo "---"
done
```

---

## Performance Tips

### 1. Model Selection
- Use smaller models for simple tasks (llama3.2:1b)
- Use larger models only when quality matters (mistral:7b)
- Match model to task (codellama for code)

### 2. GPU Memory Management
```bash
# Check GPU usage
ssh root@192.168.0.245 'pct exec 200 -- nvidia-smi'

# If memory issues, use smaller models or lower quantization
```

### 3. Batch Requests
- Reuse same model for multiple requests (stays loaded)
- Wait 5 minutes between different models (auto-unload)

### 4. Temperature & Parameters
```json
{
  "model": "phi3:mini",
  "prompt": "Your prompt here",
  "options": {
    "temperature": 0.7,  // Lower = more deterministic
    "top_p": 0.9,        // Nucleus sampling
    "top_k": 40,         // Top-k sampling
    "num_predict": 100   // Max tokens to generate
  }
}
```

### 5. Streaming for Long Responses
- Always use `"stream": true` for responses > 100 tokens
- Reduces perceived latency
- Better user experience

---

## Troubleshooting

### API Not Responding
```bash
# Check Ollama service
ssh root@192.168.0.245 'pct exec 200 -- systemctl status ollama'

# Check if port is listening
curl http://192.168.0.200:11434/api/tags

# Restart if needed
ssh root@192.168.0.245 'pct exec 200 -- systemctl restart ollama'
```

### Slow Responses
```bash
# Check GPU temperature
/mnt/overpower/apps/dev/agl/agl-hostman/scripts/monitor-gpu-ct200.sh once

# Check GPU usage
ssh root@192.168.0.245 'pct exec 200 -- nvidia-smi'

# If temp > 85°C, models will throttle
```

### Model Not Found
```bash
# List available models
curl http://192.168.0.200:11434/api/tags | jq -r '.models[].name'

# Pull model if missing
curl -X POST http://192.168.0.200:11434/api/pull -d '{"name": "phi3:mini"}'
```

### Out of Memory
```bash
# Check available GPU memory
ssh root@192.168.0.245 'pct exec 200 -- nvidia-smi --query-gpu=memory.free --format=csv,noheader'

# Use smaller model or restart Ollama
ssh root@192.168.0.245 'pct exec 200 -- systemctl restart ollama'
```

---

## API Rate Limits

- **No hard limits** currently configured
- **Concurrent requests**: Up to 4-5 simultaneous (GPU limited)
- **Queue size**: 512 requests (see OLLAMA_MAX_QUEUE)
- **Timeout**: 5 minutes per request

---

## Security Notes

⚠️ **IMPORTANT**:
- API is **NOT authenticated** by default
- Only accessible from **local network** (192.168.0.x)
- **DO NOT** expose port 11434 to the internet without authentication

To restrict access, configure firewall rules on AGLSRV1 host.

---

## Environment Variables

Current configuration (see `/etc/systemd/system/ollama.service.d/override.conf`):

```ini
OLLAMA_HOST=0.0.0.0:11434
OLLAMA_DEBUG=INFO
OLLAMA_CONTEXT_LENGTH=4096
OLLAMA_MAX_LOADED_MODELS=0  # Auto-unload after 5min
OLLAMA_MAX_QUEUE=512
OLLAMA_NUM_PARALLEL=1
```

---

## Monitoring

### Real-time GPU Monitor
```bash
# Watch mode (updates every 5s)
/mnt/overpower/apps/dev/agl/agl-hostman/scripts/monitor-gpu-ct200.sh watch

# One-time check
/mnt/overpower/apps/dev/agl/agl-hostman/scripts/monitor-gpu-ct200.sh once
```

### Ollama Logs
```bash
ssh root@192.168.0.245 'pct exec 200 -- journalctl -u ollama -f'
```

---

## Additional Resources

- **Ollama Documentation**: https://github.com/ollama/ollama/blob/main/docs/api.md
- **Model Library**: https://ollama.com/library
- **GPU Setup Guide**: `/mnt/overpower/apps/dev/agl/agl-hostman/docs/ct200-gpu-setup-summary.md`

---

**Last Updated**: 2025-10-27
**Maintained By**: AGL Infrastructure Team

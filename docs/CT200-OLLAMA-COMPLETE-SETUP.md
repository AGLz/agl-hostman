# CT200 Ollama Complete Setup Guide
## Professional AI Infrastructure on AGLSRV1

> **Last Updated**: 2025-11-05
> **Status**: Production-Ready Implementation
> **Container**: CT200 (AGLSRV1)
> **GPU**: NVIDIA RTX 3060 12GB

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Core Components](#core-components)
4. [Installation Guide](#installation-guide)
5. [Best Practices](#best-practices)
6. [Performance Optimization](#performance-optimization)
7. [Security](#security)
8. [Monitoring](#monitoring)
9. [Use Cases](#use-cases)
10. [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

### What We're Building

Complete AI infrastructure stack on CT200 with:

- **Ollama**: Local LLM runtime with GPU acceleration
- **Open WebUI**: Modern ChatGPT-like interface
- **LiteLLM Proxy**: Unified API for multiple LLM providers
- **LangChain Integration**: RAG and agent frameworks
- **Performance Monitoring**: Real-time metrics and optimization
- **Production Security**: Network isolation and access control

### Why This Stack?

✅ **Privacy**: All models run locally - no data leaves your infrastructure
✅ **Performance**: Direct GPU access with NVIDIA RTX 3060 12GB
✅ **Cost**: No API fees - unlimited inference
✅ **Flexibility**: Switch between models instantly
✅ **Integration**: Compatible with OpenAI API format
✅ **Scalability**: Ready for multi-container deployment

---

## 🏗️ Architecture

### System Design

```
┌─────────────────────────────────────────────────────────┐
│ CT200 (AGLSRV1) - AI Infrastructure                     │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────┐    ┌─────────────┐   ┌──────────────┐│
│  │  Open WebUI  │───▶│   Ollama    │◀──│  LiteLLM     ││
│  │  Port 3000   │    │  Port 11434 │   │  Port 4000   ││
│  └──────────────┘    └─────────────┘   └──────────────┘│
│         │                    │                   │       │
│         │                    ▼                   │       │
│         │            ┌──────────────┐            │       │
│         └───────────▶│  NVIDIA GPU  │◀───────────┘       │
│                      │  RTX 3060    │                    │
│                      │  12GB VRAM   │                    │
│                      └──────────────┘                    │
│                                                           │
│  ┌─────────────────────────────────────────────────────┐│
│  │ Network Access Points                               ││
│  ├─────────────────────────────────────────────────────┤│
│  │ • LAN: 192.168.0.200                               ││
│  │ • WireGuard: 10.6.0.17                             ││
│  │ • Tailscale: 100.x.x.x                             ││
│  └─────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────┘
```

### Data Flow

1. **User** → Open WebUI (Web Interface)
2. **Open WebUI** → Ollama API (Model Inference)
3. **Ollama** → GPU (Computation)
4. **LiteLLM** → Ollama (API Abstraction Layer)
5. **External Apps** → LiteLLM → Ollama (Unified Access)

---

## 🧩 Core Components

### 1. Ollama - LLM Runtime

**Purpose**: Run large language models locally with GPU acceleration

**Features**:
- Model library: Llama 3.3, Qwen2.5, DeepSeek, Mistral, etc.
- GPU acceleration with CUDA
- OpenAI-compatible API
- Automatic model management
- Multi-model scheduling

**Installation**: Already installed on CT200
```bash
# Verify installation
ollama --version
ollama list  # Show installed models
```

**Current Models**:
```
MODEL                  SIZE    MODIFIED
qwen2.5:32b           19.0 GB  3 weeks ago
llama3.3:latest       43.0 GB  4 weeks ago
deepseek-r1:32b       19.0 GB  2 weeks ago
```

---

### 2. Open WebUI - User Interface

**Purpose**: ChatGPT-like web interface for Ollama

**Features**:
- Modern, responsive UI
- Multi-user support with authentication
- Conversation history
- Document upload and RAG
- Model switching
- API key management
- Admin dashboard

**Access**:
- URL: `http://10.6.0.17:3000` (WireGuard)
- URL: `http://192.168.0.200:3000` (LAN)

**Key Capabilities**:
- Chat with any Ollama model
- Upload documents for context
- Save and organize conversations
- Create custom prompts
- Share conversations
- Dark/light themes

---

### 3. LiteLLM Proxy - API Gateway

**Purpose**: Unified API layer for multiple LLM providers

**Features**:
- Single API for 100+ LLM providers
- OpenAI-compatible endpoints
- Load balancing across models
- Request logging and monitoring
- Rate limiting and quotas
- API key management
- Cost tracking

**Why Use LiteLLM**:
```python
# Without LiteLLM - different APIs
ollama_client = OllamaClient(...)
openai_client = OpenAI(...)
anthropic_client = Anthropic(...)

# With LiteLLM - unified interface
from litellm import completion

# Local Ollama
response = completion(model="ollama/llama3.3", messages=[...])

# OpenAI (if needed)
response = completion(model="gpt-4", messages=[...])

# Anthropic (if needed)
response = completion(model="claude-3", messages=[...])
```

**Deployment**: Docker container on CT200
```bash
# Port: 4000
# Endpoint: http://10.6.0.17:4000
```

---

### 4. LangChain Integration - AI Frameworks

**Purpose**: Build RAG systems and AI agents

**Features**:
- Document loaders and text splitters
- Vector stores (Chroma, FAISS, Pinecone)
- Embeddings (Ollama, OpenAI, HuggingFace)
- Chain orchestration
- Agent frameworks
- Memory systems

**Use Cases**:
- **RAG Systems**: Chat with your documents
- **Agents**: Multi-step reasoning with tools
- **Chains**: Complex LLM workflows
- **Memory**: Conversational context

**Example Setup**:
```python
from langchain_community.llms import Ollama
from langchain_community.embeddings import OllamaEmbeddings
from langchain_community.vectorstores import Chroma
from langchain.chains import RetrievalQA

# Initialize Ollama
llm = Ollama(
    base_url="http://10.6.0.17:11434",
    model="qwen2.5:32b"
)

# Initialize embeddings
embeddings = OllamaEmbeddings(
    base_url="http://10.6.0.17:11434",
    model="nomic-embed-text"
)

# Create vector store
vectorstore = Chroma(
    embedding_function=embeddings,
    persist_directory="./chroma_db"
)

# Build RAG chain
qa_chain = RetrievalQA.from_chain_type(
    llm=llm,
    retriever=vectorstore.as_retriever()
)
```

---

## 📦 Installation Guide

### Prerequisites

**On CT200**:
```bash
# Verify GPU
nvidia-smi

# Verify Docker
docker --version
docker compose version

# Verify Ollama
ollama --version
curl http://localhost:11434/api/tags
```

### Quick Start - All Components

**1. Create Docker Compose Stack**

```bash
# Create directory
mkdir -p /opt/ollama-stack
cd /opt/ollama-stack

# Create docker-compose.yml (see file below)
```

**2. Deploy Stack**

```bash
# Start all services
docker compose up -d

# Verify deployment
docker compose ps
docker compose logs -f
```

**3. Access Services**

- **Open WebUI**: http://10.6.0.17:3000
- **Ollama API**: http://10.6.0.17:11434
- **LiteLLM Proxy**: http://10.6.0.17:4000

---

### Docker Compose Configuration

**File**: `/opt/ollama-stack/docker-compose.yml`

```yaml
version: '3.8'

services:
  # Ollama - LLM Runtime (host network for GPU)
  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    network_mode: host
    volumes:
      - ollama_data:/root/.ollama
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
    environment:
      - OLLAMA_HOST=0.0.0.0:11434
      - OLLAMA_MAX_LOADED_MODELS=3
      - OLLAMA_NUM_PARALLEL=4
      - OLLAMA_GPU_MEMORY_FRACTION=0.9
    restart: unless-stopped

  # Open WebUI - User Interface
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui
    ports:
      - "3000:8080"
    volumes:
      - open_webui_data:/app/backend/data
    environment:
      - OLLAMA_BASE_URL=http://host.docker.internal:11434
      - WEBUI_SECRET_KEY=${WEBUI_SECRET_KEY:-secret-key-change-me}
      - WEBUI_AUTH=true
    extra_hosts:
      - host.docker.internal:host-gateway
    restart: unless-stopped
    depends_on:
      - ollama

  # LiteLLM Proxy - API Gateway
  litellm:
    image: ghcr.io/berriai/litellm:main-latest
    container_name: litellm
    ports:
      - "4000:4000"
    volumes:
      - ./litellm-config.yaml:/app/config.yaml
      - litellm_data:/app/data
    environment:
      - LITELLM_MASTER_KEY=${LITELLM_MASTER_KEY:-sk-1234}
      - DATABASE_URL=sqlite:////app/data/litellm.db
    command: ["--config", "/app/config.yaml", "--port", "4000", "--num_workers", "4"]
    restart: unless-stopped
    depends_on:
      - ollama

volumes:
  ollama_data:
  open_webui_data:
  litellm_data:
```

**LiteLLM Configuration**: `/opt/ollama-stack/litellm-config.yaml`

```yaml
model_list:
  - model_name: llama3.3
    litellm_params:
      model: ollama/llama3.3
      api_base: http://host.docker.internal:11434

  - model_name: qwen2.5-32b
    litellm_params:
      model: ollama/qwen2.5:32b
      api_base: http://host.docker.internal:11434

  - model_name: deepseek-r1-32b
    litellm_params:
      model: ollama/deepseek-r1:32b
      api_base: http://host.docker.internal:11434

general_settings:
  master_key: ${LITELLM_MASTER_KEY}
  database_url: ${DATABASE_URL}

litellm_settings:
  drop_params: true
  set_verbose: true
  num_workers: 4
```

**Environment Variables**: `/opt/ollama-stack/.env`

```bash
# Security
WEBUI_SECRET_KEY=change-this-to-random-secret-key
LITELLM_MASTER_KEY=sk-your-master-key-here

# Database
DATABASE_URL=sqlite:////app/data/litellm.db

# Ollama
OLLAMA_MAX_LOADED_MODELS=3
OLLAMA_NUM_PARALLEL=4
OLLAMA_GPU_MEMORY_FRACTION=0.9
```

---

## 🎯 Best Practices for Production

### 1. Model Management

**Choosing Models**:
```bash
# For general tasks (8-16GB VRAM)
ollama pull qwen2.5:14b
ollama pull mistral:7b

# For coding (12-24GB VRAM)
ollama pull deepseek-coder:33b
ollama pull qwen2.5-coder:7b

# For reasoning (requires more VRAM)
ollama pull qwen2.5:32b
ollama pull llama3.3:70b  # Quantized
```

**Model Quantization**:
- `Q8_0`: 8-bit quantization (best quality, more memory)
- `Q4_K_M`: 4-bit quantization (balanced, recommended)
- `Q4_0`: 4-bit quantization (fastest, less memory)

**Loading Strategy**:
```bash
# Keep 3 models loaded simultaneously
export OLLAMA_MAX_LOADED_MODELS=3

# Allow 4 parallel requests
export OLLAMA_NUM_PARALLEL=4
```

---

### 2. GPU Memory Optimization

**Configuration**:
```bash
# Use 90% of GPU memory (safe for dedicated GPU)
export OLLAMA_GPU_MEMORY_FRACTION=0.9

# Use 80% if sharing GPU with other workloads
export OLLAMA_GPU_MEMORY_FRACTION=0.8
```

**Memory Mapping (mmap)**:
- Ollama automatically uses mmap for large models
- Reduces RAM usage by 70%
- Improves performance by 300%
- Files are mapped directly from disk to memory

**Multi-GPU Setup** (future expansion):
```bash
# Automatically distributes across GPUs
export CUDA_VISIBLE_DEVICES=0,1

# Ollama handles scheduling
```

---

### 3. Concurrency Handling

**Problem**: Ollama processes requests sequentially by default

**Solutions**:

**Option A: Multiple Ollama Instances** (recommended for CT200)
```bash
# Run multiple Ollama containers on different ports
# Load balancing with LiteLLM
```

**Option B: Request Queuing**
```python
# Implement async queue in application layer
import asyncio
from typing import List

class OllamaQueue:
    def __init__(self, max_concurrent=4):
        self.semaphore = asyncio.Semaphore(max_concurrent)

    async def generate(self, prompt: str):
        async with self.semaphore:
            # Make request to Ollama
            return await ollama_client.generate(prompt)
```

**Option C: LiteLLM Load Balancing**
```yaml
# litellm-config.yaml
router_settings:
  routing_strategy: simple-shuffle
  num_retries: 3

model_list:
  - model_name: qwen2.5
    litellm_params:
      model: ollama/qwen2.5:32b
      api_base: http://10.6.0.17:11434

  - model_name: qwen2.5
    litellm_params:
      model: ollama/qwen2.5:32b
      api_base: http://10.6.0.17:11435  # Second instance
```

---

### 4. Security Hardening

**Network Isolation**:
```bash
# Bind Ollama to specific interface
export OLLAMA_HOST=10.6.0.17:11434  # WireGuard only

# Or use firewall rules
ufw allow from 10.6.0.0/24 to any port 11434
ufw deny 11434  # Block all other access
```

**Authentication**:
```yaml
# Open WebUI - enable auth
environment:
  - WEBUI_AUTH=true
  - WEBUI_SECRET_KEY=<strong-random-key>

# LiteLLM - require API key
environment:
  - LITELLM_MASTER_KEY=sk-<your-key>
```

**Model Integrity**:
```bash
# Verify model checksums
ollama show qwen2.5:32b --modelfile

# Use signed models only
# Keep models in version-controlled images
```

**Audit Logging**:
```yaml
# LiteLLM logging
litellm_settings:
  success_callback: ["langfuse"]
  failure_callback: ["langfuse"]
  set_verbose: true
```

---

### 5. Monitoring and Observability

**GPU Monitoring**:
```bash
# Real-time GPU stats
watch -n 1 nvidia-smi

# Log GPU metrics
nvidia-smi --query-gpu=timestamp,name,utilization.gpu,memory.used,memory.total \
  --format=csv -l 5 > /var/log/gpu-metrics.csv
```

**Ollama Metrics**:
```bash
# API health check
curl http://10.6.0.17:11434/api/tags

# List loaded models
curl http://10.6.0.17:11434/api/ps

# Generation metrics (tokens/sec, latency)
# Available in response headers
```

**LiteLLM Dashboard**:
```bash
# Access at http://10.6.0.17:4000
# Shows:
# - Request rate
# - Token usage
# - Model performance
# - Error rates
# - Cost tracking
```

---

## ⚡ Performance Optimization

### 1. Model Selection

**For Chat/General (12GB VRAM)**:
```bash
ollama pull qwen2.5:32b      # Best reasoning, 19GB
ollama pull mistral:7b       # Fast, efficient
ollama pull llama3.3:latest  # Large but powerful
```

**For Coding (12GB VRAM)**:
```bash
ollama pull deepseek-coder:33b  # Best for code
ollama pull qwen2.5-coder:7b    # Fast coding
```

**For Specialized Tasks**:
```bash
ollama pull nomic-embed-text    # Embeddings for RAG
ollama pull all-minilm:22m      # Ultra-fast embeddings
```

---

### 2. Context Window Management

```bash
# Adjust context size based on use case
ollama run qwen2.5:32b --num-ctx 4096   # Default
ollama run qwen2.5:32b --num-ctx 8192   # More context
ollama run qwen2.5:32b --num-ctx 32768  # Maximum (slower)
```

**Trade-offs**:
- Larger context = more memory + slower
- Smaller context = less memory + faster
- Ollama automatically manages based on VRAM

---

### 3. Batch Processing

```python
# Process multiple requests in parallel
import asyncio
from litellm import acompletion

async def batch_generate(prompts: List[str]):
    tasks = [
        acompletion(
            model="ollama/qwen2.5:32b",
            messages=[{"role": "user", "content": p}]
        )
        for p in prompts
    ]
    return await asyncio.gather(*tasks)

# Usage
prompts = ["What is AI?", "Explain LLMs", "What is RAG?"]
results = await batch_generate(prompts)
```

---

### 4. Caching Strategies

**Prompt Caching**:
```python
# Cache system prompts
system_prompt = "You are a helpful AI assistant..."

# Reuse across requests (Ollama handles internally)
response = ollama.chat(
    model="qwen2.5:32b",
    messages=[
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_query}
    ]
)
```

**Response Caching**:
```python
# Application-level cache
from functools import lru_cache

@lru_cache(maxsize=1000)
def cached_generate(prompt: str):
    return ollama.generate(model="qwen2.5:32b", prompt=prompt)
```

---

## 🔐 Security

### Access Control

**1. Network Level**:
```bash
# WireGuard only access
ufw allow from 10.6.0.0/24 to any port 11434
ufw allow from 10.6.0.0/24 to any port 3000
ufw allow from 10.6.0.0/24 to any port 4000
ufw deny 11434
ufw deny 3000
ufw deny 4000
```

**2. Application Level**:
- Open WebUI: User authentication required
- LiteLLM: API key required
- Ollama: Behind proxy (LiteLLM)

**3. Data Privacy**:
- All inference happens locally
- No data sent to external APIs
- Conversation history stored locally
- Full control over data retention

---

### Prompt Injection Protection

```python
# Validate and sanitize user inputs
import re

def sanitize_prompt(user_input: str) -> str:
    # Remove system prompt injections
    dangerous_patterns = [
        r"ignore previous",
        r"disregard",
        r"forget everything",
        r"new instructions"
    ]

    for pattern in dangerous_patterns:
        if re.search(pattern, user_input, re.IGNORECASE):
            raise ValueError("Potentially malicious input detected")

    return user_input

# Use with Ollama
safe_prompt = sanitize_prompt(user_input)
response = ollama.generate(model="qwen2.5:32b", prompt=safe_prompt)
```

---

## 📊 Monitoring

### GPU Monitoring Script

**File**: `/opt/ollama-stack/monitor-gpu.sh`

```bash
#!/bin/bash
# GPU monitoring for Ollama workloads

LOG_FILE="/var/log/ollama-gpu-monitor.log"
INTERVAL=10  # seconds

while true; do
    echo "=== $(date) ===" >> "$LOG_FILE"

    # GPU utilization
    nvidia-smi --query-gpu=utilization.gpu,utilization.memory \
      --format=csv,noheader >> "$LOG_FILE"

    # Memory usage
    nvidia-smi --query-gpu=memory.used,memory.total \
      --format=csv,noheader >> "$LOG_FILE"

    # Temperature
    nvidia-smi --query-gpu=temperature.gpu \
      --format=csv,noheader >> "$LOG_FILE"

    # Power draw
    nvidia-smi --query-gpu=power.draw \
      --format=csv,noheader >> "$LOG_FILE"

    echo "" >> "$LOG_FILE"
    sleep $INTERVAL
done
```

---

### Ollama Health Check

**File**: `/opt/ollama-stack/health-check.sh`

```bash
#!/bin/bash
# Health check for Ollama services

OLLAMA_URL="http://10.6.0.17:11434"
WEBUI_URL="http://10.6.0.17:3000"
LITELLM_URL="http://10.6.0.17:4000"

# Check Ollama
if curl -sf "$OLLAMA_URL/api/tags" > /dev/null; then
    echo "✅ Ollama: OK"
else
    echo "❌ Ollama: FAILED"
fi

# Check Open WebUI
if curl -sf "$WEBUI_URL" > /dev/null; then
    echo "✅ Open WebUI: OK"
else
    echo "❌ Open WebUI: FAILED"
fi

# Check LiteLLM
if curl -sf "$LITELLM_URL/health" > /dev/null; then
    echo "✅ LiteLLM: OK"
else
    echo "❌ LiteLLM: FAILED"
fi

# Check GPU
if nvidia-smi > /dev/null 2>&1; then
    echo "✅ GPU: OK"
    nvidia-smi --query-gpu=memory.used --format=csv,noheader
else
    echo "❌ GPU: FAILED"
fi
```

---

## 🎯 Use Cases

### 1. Interactive Chat (Open WebUI)

**Access**: http://10.6.0.17:3000

**Features**:
- Chat with any loaded model
- Upload documents for context
- Save conversation history
- Switch models mid-conversation
- Create custom prompts

**Example**:
```
User: Explain RAG systems
Model: Retrieval Augmented Generation (RAG) combines...
```

---

### 2. RAG System (LangChain)

**Python Example**:
```python
from langchain_community.llms import Ollama
from langchain_community.embeddings import OllamaEmbeddings
from langchain_community.vectorstores import Chroma
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.chains import RetrievalQA
from langchain_community.document_loaders import DirectoryLoader

# Initialize Ollama
llm = Ollama(
    base_url="http://10.6.0.17:11434",
    model="qwen2.5:32b",
    temperature=0.7
)

embeddings = OllamaEmbeddings(
    base_url="http://10.6.0.17:11434",
    model="nomic-embed-text"
)

# Load documents
loader = DirectoryLoader("./docs", glob="**/*.md")
documents = loader.load()

# Split text
text_splitter = RecursiveCharacterTextSplitter(
    chunk_size=1000,
    chunk_overlap=200
)
texts = text_splitter.split_documents(documents)

# Create vector store
vectorstore = Chroma.from_documents(
    documents=texts,
    embedding=embeddings,
    persist_directory="./chroma_db"
)

# Create RAG chain
qa_chain = RetrievalQA.from_chain_type(
    llm=llm,
    chain_type="stuff",
    retriever=vectorstore.as_retriever(search_kwargs={"k": 5}),
    return_source_documents=True
)

# Query
result = qa_chain({"query": "What is the WireGuard configuration?"})
print(result["result"])
print(f"Sources: {result['source_documents']}")
```

---

### 3. API Integration (LiteLLM)

**Unified API**:
```python
from litellm import completion

# Using Ollama
response = completion(
    model="ollama/qwen2.5:32b",
    messages=[
        {"role": "system", "content": "You are a helpful assistant"},
        {"role": "user", "content": "Explain Docker"}
    ],
    api_base="http://10.6.0.17:4000",
    api_key="sk-1234"
)

print(response.choices[0].message.content)
```

**OpenAI Compatible**:
```python
import openai

# Point to LiteLLM proxy
openai.api_base = "http://10.6.0.17:4000"
openai.api_key = "sk-1234"

# Use like OpenAI API
response = openai.ChatCompletion.create(
    model="qwen2.5-32b",  # Maps to ollama/qwen2.5:32b
    messages=[
        {"role": "user", "content": "Hello!"}
    ]
)
```

---

### 4. Agent Framework (LangChain Agents)

**Python Example**:
```python
from langchain.agents import AgentExecutor, create_react_agent
from langchain_community.llms import Ollama
from langchain.tools import Tool
from langchain import hub

# Initialize LLM
llm = Ollama(
    base_url="http://10.6.0.17:11434",
    model="qwen2.5:32b"
)

# Define tools
def search_docs(query: str) -> str:
    """Search documentation"""
    # Implement search logic
    return f"Found information about: {query}"

def execute_command(cmd: str) -> str:
    """Execute system command"""
    # Implement with safety checks
    return f"Executed: {cmd}"

tools = [
    Tool(
        name="SearchDocs",
        func=search_docs,
        description="Search documentation for information"
    ),
    Tool(
        name="ExecuteCommand",
        func=execute_command,
        description="Execute system commands safely"
    )
]

# Create agent
prompt = hub.pull("hwchase17/react")
agent = create_react_agent(llm, tools, prompt)
agent_executor = AgentExecutor(agent=agent, tools=tools, verbose=True)

# Run agent
result = agent_executor.invoke({
    "input": "Find information about Docker and check if it's installed"
})
print(result)
```

---

### 5. Code Generation

**Python Example**:
```python
def generate_code(description: str, language: str = "python"):
    """Generate code using Ollama"""

    prompt = f"""Generate {language} code for the following task:

Task: {description}

Requirements:
- Include docstrings
- Add error handling
- Follow best practices
- Add example usage

Code:"""

    response = ollama.generate(
        model="deepseek-coder:33b",
        prompt=prompt,
        options={
            "temperature": 0.2,  # Lower for code generation
            "top_p": 0.9
        }
    )

    return response["response"]

# Usage
code = generate_code("Create a REST API endpoint with FastAPI")
print(code)
```

---

### 6. Document Summarization

**Python Example**:
```python
def summarize_document(file_path: str) -> str:
    """Summarize large documents"""

    # Load document
    with open(file_path, 'r') as f:
        content = f.read()

    # Split if too large
    max_tokens = 4000
    if len(content) > max_tokens:
        chunks = [content[i:i+max_tokens]
                 for i in range(0, len(content), max_tokens)]
    else:
        chunks = [content]

    # Summarize each chunk
    summaries = []
    for chunk in chunks:
        response = ollama.generate(
            model="qwen2.5:32b",
            prompt=f"Summarize the following text:\n\n{chunk}"
        )
        summaries.append(response["response"])

    # Combine summaries
    if len(summaries) > 1:
        combined = "\n\n".join(summaries)
        final_response = ollama.generate(
            model="qwen2.5:32b",
            prompt=f"Create a final summary from these summaries:\n\n{combined}"
        )
        return final_response["response"]
    else:
        return summaries[0]
```

---

## 🔧 Troubleshooting

### Common Issues

#### 1. Ollama Not Responding

**Symptoms**:
```bash
curl: (7) Failed to connect to localhost port 11434
```

**Solutions**:
```bash
# Check Ollama status
systemctl status ollama

# Restart Ollama
systemctl restart ollama

# Check logs
journalctl -u ollama -f

# Verify GPU
nvidia-smi
```

---

#### 2. Out of Memory (OOM)

**Symptoms**:
```
Error: failed to allocate memory
CUDA out of memory
```

**Solutions**:
```bash
# Reduce GPU memory fraction
export OLLAMA_GPU_MEMORY_FRACTION=0.7

# Use smaller model
ollama run qwen2.5:14b  # Instead of 32b

# Use quantized model
ollama run qwen2.5:32b-q4  # 4-bit quantization

# Reduce context window
ollama run qwen2.5:32b --num-ctx 2048
```

---

#### 3. Slow Generation

**Symptoms**:
- Less than 10 tokens/second
- High latency

**Solutions**:
```bash
# Check GPU utilization
nvidia-smi

# Enable GPU offloading
export OLLAMA_NUM_GPU=999  # Use all GPU layers

# Reduce parallel requests
export OLLAMA_NUM_PARALLEL=2

# Use faster model
ollama run mistral:7b  # Instead of larger models
```

---

#### 4. Open WebUI Connection Failed

**Symptoms**:
```
Connection to Ollama API failed
```

**Solutions**:
```bash
# Check Ollama is running
curl http://10.6.0.17:11434/api/tags

# Verify Open WebUI env
docker exec open-webui env | grep OLLAMA_BASE_URL

# Restart Open WebUI
docker restart open-webui

# Check logs
docker logs open-webui
```

---

#### 5. LiteLLM Proxy Errors

**Symptoms**:
```
Model not found
Authentication failed
```

**Solutions**:
```bash
# Verify configuration
cat /opt/ollama-stack/litellm-config.yaml

# Check API key
echo $LITELLM_MASTER_KEY

# Restart LiteLLM
docker restart litellm

# Check logs
docker logs litellm
```

---

### Performance Debugging

**Check GPU Performance**:
```bash
# Monitor in real-time
watch -n 1 'nvidia-smi --query-gpu=timestamp,utilization.gpu,utilization.memory,memory.used --format=csv'

# Log to file
nvidia-smi --query-gpu=timestamp,utilization.gpu,memory.used \
  --format=csv -l 5 > gpu-metrics.csv
```

**Check Ollama Performance**:
```bash
# Test generation speed
time ollama run qwen2.5:32b "Count from 1 to 100"

# Monitor loaded models
watch -n 2 'curl -s http://10.6.0.17:11434/api/ps'

# Check token generation speed
ollama run qwen2.5:32b --verbose "Tell me a story"
```

---

## 📚 Additional Resources

### Official Documentation

- **Ollama**: https://ollama.ai/docs
- **Open WebUI**: https://docs.openwebui.com
- **LiteLLM**: https://docs.litellm.ai
- **LangChain**: https://python.langchain.com/docs

### Community Resources

- **Ollama Models**: https://ollama.ai/library
- **Open WebUI Community**: https://github.com/open-webui/open-webui
- **LiteLLM Examples**: https://github.com/BerriAI/litellm

### Related Documentation

- `docs/CT200-Instructions.md` - Basic CT200 setup
- `docs/INFRA.md` - Infrastructure overview
- `docs/DOCKER-DEPLOYMENT.md` - Docker best practices

---

## 🚀 Next Steps

### Immediate Actions

1. **Deploy Stack**:
   ```bash
   cd /opt/ollama-stack
   docker compose up -d
   ```

2. **Access Open WebUI**:
   - Navigate to http://10.6.0.17:3000
   - Create admin account
   - Test chat with installed models

3. **Test LiteLLM**:
   ```bash
   curl -X POST http://10.6.0.17:4000/chat/completions \
     -H "Authorization: Bearer sk-1234" \
     -H "Content-Type: application/json" \
     -d '{
       "model": "qwen2.5-32b",
       "messages": [{"role": "user", "content": "Hello!"}]
     }'
   ```

### Future Enhancements

- [ ] Add more specialized models
- [ ] Implement RAG system for documentation
- [ ] Create custom agents for infrastructure management
- [ ] Set up monitoring dashboards
- [ ] Integrate with Archon for task automation
- [ ] Deploy LangFlow/Flowise for visual workflows
- [ ] Add API rate limiting and quotas
- [ ] Implement model A/B testing

---

## 📝 Changelog

### 2025-11-05 - Initial Release
- Complete setup guide with all components
- Best practices from web research
- Production-ready Docker Compose stack
- Security and performance optimization
- Multiple use case examples
- Comprehensive troubleshooting

---

**Document Maintainer**: AGL Infrastructure Team
**Last Updated**: 2025-11-05
**Version**: 1.0.0

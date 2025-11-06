# Ollama Stack Examples

Complete examples for using Ollama, Open WebUI, LiteLLM, and LangChain on CT200.

---

## 📁 Files

### Python Examples

| File | Description | Features |
|------|-------------|----------|
| `rag-system-example.py` | Complete RAG system | LangChain, Chroma, Embeddings |
| `litellm-api-example.py` | API usage patterns | Multiple clients, Streaming, Batch |

### Shell Scripts

| File | Description | Purpose |
|------|-------------|---------|
| `../scripts/ollama-stack/deploy.sh` | Deployment script | One-command setup |
| `../scripts/ollama-stack/monitor.sh` | Real-time monitoring | GPU, Containers, Services |
| `../scripts/ollama-stack/optimize.sh` | Performance tuning | GPU memory, Concurrency |

---

## 🚀 Quick Start

### 1. RAG System

Build a document Q&A system:

```bash
# Install dependencies
pip install langchain langchain-community chromadb

# Run example
python rag-system-example.py
```

**What it does**:
- Loads documents from `../../docs`
- Creates vector embeddings with Ollama
- Stores in Chroma database
- Answers questions using RAG

**Example queries**:
- "What is the WireGuard configuration?"
- "How do I access Archon MCP?"
- "Explain the network topology"

---

### 2. LiteLLM API

Test different API patterns:

```bash
# Install dependencies
pip install litellm requests openai

# Run example
python litellm-api-example.py
```

**Features**:
1. Direct API calls
2. OpenAI SDK compatibility
3. LiteLLM SDK usage
4. Streaming responses
5. Multi-model comparison
6. Text embeddings
7. Batch requests

---

## 📚 Example Use Cases

### Use Case 1: Documentation Q&A

**Scenario**: Ask questions about your infrastructure documentation

```python
from rag-system-example import OllamaRAGSystem

# Initialize RAG
rag = OllamaRAGSystem()

# Ingest docs
rag.ingest_documents(docs_path="../../docs")

# Query
result = rag.query("How do I connect to CT200?")
print(result["answer"])
```

**Output**:
```
You can connect to CT200 using:
- WireGuard: ssh root@10.6.0.17
- LAN: ssh root@192.168.0.200
- Tailscale: ssh root@100.x.x.x
```

---

### Use Case 2: Code Generation

**Scenario**: Generate code using DeepSeek Coder

```python
import requests

response = requests.post(
    "http://10.6.0.17:4000/chat/completions",
    headers={"Authorization": "Bearer sk-1234"},
    json={
        "model": "deepseek-coder-33b",
        "messages": [{
            "role": "user",
            "content": "Write a Python function to calculate Fibonacci"
        }],
        "temperature": 0.2
    }
)

code = response.json()["choices"][0]["message"]["content"]
print(code)
```

---

### Use Case 3: Batch Processing

**Scenario**: Process multiple requests in parallel

```python
import concurrent.futures
import requests

def query_model(question):
    response = requests.post(
        "http://10.6.0.17:4000/chat/completions",
        headers={"Authorization": "Bearer sk-1234"},
        json={
            "model": "qwen2.5-32b",
            "messages": [{"role": "user", "content": question}]
        }
    )
    return response.json()["choices"][0]["message"]["content"]

questions = [
    "What is Docker?",
    "Explain Kubernetes",
    "What is CI/CD?"
]

with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
    answers = list(executor.map(query_model, questions))

for q, a in zip(questions, answers):
    print(f"Q: {q}\nA: {a}\n")
```

---

### Use Case 4: Streaming Chat

**Scenario**: Stream responses token-by-token

```python
import requests
import json

def stream_chat(prompt):
    response = requests.post(
        "http://10.6.0.17:4000/chat/completions",
        headers={"Authorization": "Bearer sk-1234"},
        json={
            "model": "qwen2.5-32b",
            "messages": [{"role": "user", "content": prompt}],
            "stream": True
        },
        stream=True
    )

    for line in response.iter_lines():
        if line:
            line_text = line.decode("utf-8")
            if line_text.startswith("data: "):
                data = line_text[6:]
                if data != "[DONE]":
                    try:
                        chunk = json.loads(data)
                        content = chunk["choices"][0]["delta"].get("content", "")
                        print(content, end="", flush=True)
                    except:
                        pass

stream_chat("Write a haiku about AI")
```

---

### Use Case 5: Embeddings for Similarity

**Scenario**: Find similar documents using embeddings

```python
import requests
import numpy as np

def get_embedding(text):
    response = requests.post(
        "http://10.6.0.17:4000/embeddings",
        headers={"Authorization": "Bearer sk-1234"},
        json={
            "model": "nomic-embed-text",
            "input": text
        }
    )
    return response.json()["data"][0]["embedding"]

def cosine_similarity(a, b):
    return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))

# Documents
docs = [
    "Docker is a containerization platform",
    "Kubernetes orchestrates containers",
    "Python is a programming language",
]

# Query
query = "What is container orchestration?"

# Get embeddings
query_emb = get_embedding(query)
doc_embs = [get_embedding(doc) for doc in docs]

# Calculate similarities
similarities = [cosine_similarity(query_emb, doc_emb) for doc_emb in doc_embs]

# Find most similar
best_idx = np.argmax(similarities)
print(f"Most similar: {docs[best_idx]}")
print(f"Similarity: {similarities[best_idx]:.4f}")
```

---

## 🔧 Configuration

### Environment Variables

Create `.env` file:

```bash
# LiteLLM
LITELLM_BASE_URL=http://10.6.0.17:4000
LITELLM_API_KEY=sk-1234

# Ollama
OLLAMA_BASE_URL=http://10.6.0.17:11434
LLM_MODEL=qwen2.5:32b
EMBEDDING_MODEL=nomic-embed-text

# Paths
CHROMA_DB_PATH=./chroma_db
DOCS_PATH=../../docs
```

### Install Dependencies

```bash
# Core
pip install requests

# LiteLLM
pip install litellm

# OpenAI SDK (optional)
pip install openai

# LangChain & RAG
pip install langchain langchain-community chromadb

# Utilities
pip install numpy python-dotenv
```

---

## 📊 Performance Tips

### 1. Model Selection

| Model | Size | Speed | Quality | Use Case |
|-------|------|-------|---------|----------|
| mistral:7b | 4GB | Fast | Good | General chat |
| qwen2.5:14b | 8GB | Medium | Better | Reasoning |
| qwen2.5:32b | 19GB | Slower | Best | Complex tasks |
| deepseek-coder:33b | 19GB | Slower | Best | Code generation |

### 2. Context Window

```python
# Faster (2K context)
ollama.generate(model="qwen2.5:32b", prompt=query, options={"num_ctx": 2048})

# Slower but more context (8K)
ollama.generate(model="qwen2.5:32b", prompt=query, options={"num_ctx": 8192})
```

### 3. Temperature Settings

```python
# Deterministic (code, facts)
options = {"temperature": 0.1}

# Balanced (default)
options = {"temperature": 0.7}

# Creative (stories, poems)
options = {"temperature": 0.9}
```

### 4. Batch Processing

```python
# Bad: Sequential
for item in items:
    result = process(item)  # Slow

# Good: Parallel
with ThreadPoolExecutor(max_workers=4) as executor:
    results = list(executor.map(process, items))  # Fast
```

---

## 🐛 Troubleshooting

### Connection Refused

```bash
# Check if services are running
docker compose ps

# Restart if needed
docker compose restart
```

### Out of Memory

```python
# Use smaller model
model = "mistral:7b"  # Instead of qwen2.5:32b

# Reduce context
options = {"num_ctx": 2048}  # Instead of 4096
```

### Slow Generation

```bash
# Check GPU utilization
nvidia-smi

# Optimize settings
./scripts/ollama-stack/optimize.sh

# Use quantized model
ollama pull qwen2.5:32b-q4  # 4-bit quantization
```

### Import Errors

```bash
# Install missing packages
pip install langchain langchain-community chromadb litellm
```

---

## 📖 Additional Resources

### Documentation
- **Ollama API**: https://github.com/ollama/ollama/blob/main/docs/api.md
- **LangChain**: https://python.langchain.com/docs
- **LiteLLM**: https://docs.litellm.ai
- **Chroma**: https://docs.trychroma.com

### Examples
- **Ollama Python**: https://github.com/ollama/ollama-python
- **LangChain Templates**: https://github.com/langchain-ai/langchain/tree/master/templates
- **RAG Examples**: https://python.langchain.com/docs/use_cases/question_answering

### Models
- **Model Library**: https://ollama.ai/library
- **Model Cards**: https://huggingface.co/models

---

## 🎯 Next Steps

1. **Try Examples**: Run `rag-system-example.py` and `litellm-api-example.py`
2. **Build Your App**: Use examples as starting point
3. **Read Docs**: Check `../docs/CT200-OLLAMA-COMPLETE-SETUP.md`
4. **Optimize**: Run `../scripts/ollama-stack/optimize.sh`
5. **Monitor**: Use `../scripts/ollama-stack/monitor.sh`

---

**Questions?**
- Check full documentation: `../docs/CT200-OLLAMA-COMPLETE-SETUP.md`
- View configuration: `../config/ollama-stack/`
- Join Ollama Discord: https://discord.gg/ollama

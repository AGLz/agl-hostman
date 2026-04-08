# CT200 Ollama Stack - Quick Start Guide
## Deploy in 5 Minutes

> **GPU**: CT200 — GeForce GTX 1650, **4096 MiB (4GB VRAM)**
> **Time**: 5-10 minutes
> **Difficulty**: Easy

---

## 🚀 One-Command Deployment

```bash
# SSH to CT200
ssh root@10.6.0.17  # or ssh root@192.168.0.200

# Run deployment script
cd /mnt/overpower/apps/dev/agl/agl-hostman
./scripts/ollama-stack/deploy.sh
```

That's it! The script will:
- ✅ Check all requirements
- ✅ Create directory structure
- ✅ Copy configurations
- ✅ Generate secure keys
- ✅ Pull Docker images
- ✅ Deploy all services
- ✅ Verify deployment

---

## 📍 Access Your Stack

After deployment completes:

### Web Interfaces

**Ollama API (CT200)** — usar o que tiveres roteado; ordem típica AGL:

| Caminho | Base URL |
|---------|----------|
| **Tailscale** (recomendado remoto) | `http://100.116.57.111:11434` — hostname TS `aglsrv1-ollama-gpu` |
| **LAN** | `http://192.168.0.200:11434` |
| **WireGuard** (mesh) | `http://10.6.0.17:11434` |

| Service | URL | Purpose |
|---------|-----|---------|
| **Open WebUI** | http://10.6.0.17:3000 (WG) ou via IP TS/LAN do CT | ChatGPT-like interface |
| **Ollama API** | ver tabela acima | LLM API endpoint |
| **LiteLLM Proxy** | http://10.6.0.17:4000 (stack no CT; ajustar se outro host) | Unified API gateway |

### First Steps

1. **Open WebUI**:
   - Go to http://10.6.0.17:3000
   - Create admin account
   - Start chatting!

2. **Test API**:
   ```bash
   curl http://100.116.57.111:11434/api/tags   # Tailscale
   # curl http://192.168.0.200:11434/api/tags # LAN
   ```

3. **Check Status**:
   ```bash
   /opt/ollama-stack/status.sh
   ```

---

## 🎯 Quick Commands

```bash
# Monitor in real-time
/opt/ollama-stack/monitor.sh

# View logs
/opt/ollama-stack/logs.sh         # All containers
/opt/ollama-stack/logs.sh ollama  # Specific container

# Restart stack
/opt/ollama-stack/restart.sh

# Check GPU
nvidia-smi

# List models
ollama list

# Verificar API (version + tags) — Tailscale primeiro
OLLAMA_HOST=100.116.57.111:11434 ./scripts/ollama-stack/verify-ollama.sh
# ./scripts/ollama-stack/verify-ollama.sh http://192.168.0.200:11434
# ./scripts/ollama-stack/verify-ollama.sh http://10.6.0.17:11434
```

### Modelos recomendados (2026)

**Qwen3** — [library](https://ollama.com/library/qwen3) do Ollama inclui desde **0.6B (~523MB)** até 235B.
**Gemma 4** — [library](https://ollama.com/library/gemma4) (Google, 2026-03-31); E2B/E4B/26B-MoE/31B.

Para **GTX 1650 4GB** (CT200) — só modelos que caibam em VRAM:

| Tag | Tamanho aprox. | Notas |
|-----|----------------|--------|
| `qwen3:0.6b` | **~523 MB** | ✅ Mínima latência |
| `gemma4:e2b` | **~1.5 GB** | ✅ **Melhor qualidade vs Qwen3 0.6B** |
| `qwen3:1.7b` | ~1.4 GB | ✅ Passo intermédio |
| `qwen3:4b` | ~2.5 GB | ⚠️ Borderline; ok se modelo único carregado |

> **Excluídos (excedem 4GB VRAM da GTX 1650):**
> `gemma4:e4b` (~2.8GB), `qwen3:8b` (~5.2GB), `gemma2:9b` (~5.5GB),
> `qwen2.5-coder:7b` (~4.5GB), `gemma4:26b-a4b` (~15GB), `qwen2.5:32b` (~19GB fp16), `gemma4:31b` (~19GB).

Referência projeto: `config/ollama-stack/litellm-config.yaml` expõe aliases `ollama-gemma4-e2b`, `ollama-qwen3-1.7b`, etc. Para puxar os blobs no host:

```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman
./scripts/ollama-stack/pull-small-qwen-models.sh          # qwen3 0.6b/1.7b + gemma4:e2b + (opcional qwen3:4b)
./scripts/ollama-stack/pull-small-qwen-models.sh --minimal # só 0.6b + 1.7b + gemma4:e2b
```

---

## 💡 Quick Examples

### Chat via CLI

```bash
ollama run qwen2.5:32b "Explain Docker in one sentence"
```

### Chat via API

```bash
curl http://100.116.57.111:11434/api/generate -d '{
  "model": "qwen3:4b",
  "prompt": "What is Kubernetes?",
  "stream": false
}'
```

### Python Example

```python
import requests

response = requests.post(
    "http://10.6.0.17:4000/chat/completions",
    headers={"Authorization": "Bearer sk-1234"},
    json={
        "model": "qwen2.5-32b",
        "messages": [{"role": "user", "content": "Hello!"}]
    }
)

print(response.json()["choices"][0]["message"]["content"])
```

---

## 📊 Performance Optimization

After deployment, run optimization:

```bash
./scripts/ollama-stack/optimize.sh
```

This applies:
- ✅ GPU memory optimization (90% usage)
- ✅ Ollama concurrency settings
- ✅ Docker container tuning
- ✅ Kernel network parameters
- ✅ Log rotation
- ✅ Monitoring cron jobs

---

## 🔧 Management

### View Status

```bash
cd /opt/ollama-stack
./status.sh
```

Output:
```
=== Ollama Stack Status ===

Containers:
✅ ollama      - Up 2 hours
✅ open-webui  - Up 2 hours
✅ litellm     - Up 2 hours

GPU Status:
NVIDIA RTX 3060, 8192 MB, 6144 MB

Service Health:
✅ Ollama: OK
✅ Open WebUI: OK
✅ LiteLLM: OK
```

### Restart Services

```bash
docker compose restart           # All services
docker compose restart ollama    # Specific service
```

### View Logs

```bash
docker compose logs -f           # All logs
docker compose logs -f ollama    # Ollama logs only
```

---

## 🎓 Next Steps

### 1. Try Advanced Features

**RAG System**:
```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman/examples/ollama-stack
python rag-system-example.py
```

**API Examples**:
```bash
python litellm-api-example.py
```

### 2. Read Full Documentation

- **Complete Guide**: `docs/CT200-OLLAMA-COMPLETE-SETUP.md`
- **Infrastructure**: `docs/INFRA.md`
- **Docker Compose**: `config/ollama-stack/docker-compose.yml`

### 3. Install More Models

```bash
# Coding models
ollama pull deepseek-coder:33b
ollama pull qwen2.5-coder:7b

# Fast models
ollama pull mistral:7b
ollama pull phi3:latest

# Embeddings
ollama pull nomic-embed-text
```

### 4. Build Your First RAG App

See `examples/ollama-stack/rag-system-example.py` for complete code.

---

## 🆘 Troubleshooting

### Ollama Not Responding

```bash
systemctl restart ollama
docker compose restart ollama
```

### Out of GPU Memory

```bash
# Use smaller model
ollama run mistral:7b

# Or adjust GPU fraction
export OLLAMA_GPU_MEMORY_FRACTION=0.7
systemctl restart ollama
```

### Containers Not Starting

```bash
# Check logs
docker compose logs

# Rebuild
docker compose down
docker compose up -d
```

### Open WebUI Connection Failed

```bash
# Check Ollama is running
curl http://localhost:11434/api/tags

# Restart Open WebUI
docker restart open-webui
```

---

## 📚 Resources

### Documentation
- **Complete Setup**: `docs/CT200-OLLAMA-COMPLETE-SETUP.md`
- **Ollama Docs**: https://ollama.ai/docs
- **Open WebUI**: https://docs.openwebui.com
- **LiteLLM**: https://docs.litellm.ai
- **LangChain**: https://python.langchain.com/docs

### Model Library
- **Ollama Models**: https://ollama.ai/library
- **Recommended**: Qwen 2.5, Llama 3.3, DeepSeek Coder

### Community
- **Ollama Discord**: https://discord.gg/ollama
- **GitHub**: https://github.com/ollama/ollama

---

## ✅ Verification Checklist

After deployment, verify:

- [ ] All 3 containers running: `docker compose ps`
- [ ] Ollama API responsive: `curl http://100.116.57.111:11434/api/tags` (ou LAN `192.168.0.200`)
- [ ] Open WebUI accessible: http://10.6.0.17:3000
- [ ] LiteLLM proxy working: `curl http://10.6.0.17:4000/health`
- [ ] GPU detected: `nvidia-smi`
- [ ] Models loaded: `ollama list`
- [ ] Can generate text: `ollama run qwen2.5:32b "test"`

If all checks pass: **🎉 Your Ollama stack is ready!**

---

## 💡 Pro Tips

1. **Performance**: Use quantized models (Q4_K_M) for 2-3x faster inference
2. **Memory**: Keep context window under 4096 tokens for better speed
3. **Monitoring**: Run `monitor.sh` in a tmux session for persistent monitoring
4. **Backups**: Models stored in `/opt/ollama-stack/data/ollama`
5. **Security**: Change default API keys in `/opt/ollama-stack/.env`

---

**Need Help?**
- Complete documentation: `docs/CT200-OLLAMA-COMPLETE-SETUP.md`
- Check logs: `/opt/ollama-stack/logs.sh`
- Monitor GPU: `nvidia-smi`
- View status: `/opt/ollama-stack/status.sh`

**Ready to Deploy?**
```bash
./scripts/ollama-stack/deploy.sh
```

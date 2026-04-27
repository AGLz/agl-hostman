#!/bin/bash
# Diagnóstico GPU + Ollama no CT200 (executar no host: pct exec 200 -- bash /path/...)
# Reason: sem cgroup 509 (nvidia-uvm) no 200.conf, CUDA pode falhar mesmo com nvidia-smi OK.
set -u
echo "=== /dev/nvidia* ==="
ls -la /dev/nvidia* 2>&1 || true
echo "=== /dev/nvidia-caps ==="
ls -la /dev/nvidia-caps 2>&1 | head -8 || true
echo "=== ldconfig libcuda / nvml ==="
ldconfig -p 2>/dev/null | grep -E 'libcuda\.so|libnvidia-ml' | head -20 || true
echo "=== Ollama lib dir ==="
ls -la /usr/local/lib/ollama/*.so 2>/dev/null | head -8 || true
ls /usr/local/lib/ollama/cuda_v12 2>/dev/null | head -10 || true
echo "=== ldd ggml-cuda (com LD_LIBRARY_PATH como no systemd) ==="
export LD_LIBRARY_PATH="/usr/local/lib/ollama:/usr/local/lib/ollama/cuda_v12:/lib/x86_64-linux-gnu:/usr/lib/x86_64-linux-gnu"
GG=$(ls /usr/local/lib/ollama/cuda_v12/libggml-cuda.so 2>/dev/null | head -1)
if [[ -n "${GG}" ]]; then
  ldd "${GG}" 2>&1 | head -25
else
  echo "sem libggml-cuda em cuda_v12"
fi
echo "=== nvidia-smi ==="
nvidia-smi -L 2>&1 || true
echo "=== ollama version ==="
ollama --version 2>&1 || true

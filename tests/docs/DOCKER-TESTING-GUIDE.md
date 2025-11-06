# Docker Testing Guide

> **Document Version**: 1.0.0
> **Last Updated**: 2025-10-28
> **Author**: Tester Agent - Hive Mind Collective

---

## Table of Contents

1. [Overview](#overview)
2. [Dockerfile Testing](#dockerfile-testing)
3. [Container Image Testing](#container-image-testing)
4. [Docker Compose Testing](#docker-compose-testing)
5. [Container Runtime Testing](#container-runtime-testing)
6. [Security Testing](#security-testing)
7. [Performance Testing](#performance-testing)
8. [Test Automation](#test-automation)

---

## Overview

### Testing Philosophy

Docker container testing follows a multi-layered approach:

```
┌─────────────────────────────────┐
│  Dockerfile Syntax & Lint       │  ← Static analysis
├─────────────────────────────────┤
│  Image Build Validation         │  ← Build-time checks
├─────────────────────────────────┤
│  Container Structure Tests      │  ← Image inspection
├─────────────────────────────────┤
│  Runtime Behavior Tests         │  ← Container execution
├─────────────────────────────────┤
│  Security & Vulnerability Scans │  ← Security validation
├─────────────────────────────────┤
│  Performance & Resource Tests   │  ← Load testing
└─────────────────────────────────┘
```

### Test Objectives

1. ✅ **Build Quality**: Ensure Dockerfiles follow best practices
2. ✅ **Image Security**: No critical vulnerabilities
3. ✅ **Runtime Stability**: Containers start and run correctly
4. ✅ **Resource Efficiency**: Containers use resources appropriately
5. ✅ **Integration**: Services communicate correctly

---

## Dockerfile Testing

### 1. Dockerfile Linting (Hadolint)

**Purpose**: Enforce Dockerfile best practices

```bash
# tests/docker/dockerfile-lint.sh
#!/bin/bash

echo "🔍 Dockerfile Linting"

# Find all Dockerfiles
dockerfiles=$(find . -name "Dockerfile*" -not -path "./node_modules/*")

for dockerfile in $dockerfiles; do
  echo "Linting $dockerfile..."

  hadolint "$dockerfile" || {
    echo "❌ $dockerfile failed lint check"
    exit 1
  }
done

echo "✅ All Dockerfiles pass lint check"
```

**Install Hadolint**:
```bash
# Linux
wget -O /usr/local/bin/hadolint \
  https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-x86_64
chmod +x /usr/local/bin/hadolint

# macOS
brew install hadolint

# Docker
docker pull hadolint/hadolint:latest
```

**Run**:
```bash
# Direct
hadolint Dockerfile

# Via Docker
docker run --rm -i hadolint/hadolint < Dockerfile
```

### 2. Dockerfile Best Practices Check

```python
# tests/docker/test_dockerfile_best_practices.py
import re
import pytest

def test_dockerfile_uses_specific_base_image_tag():
    """Base images should use specific tags, not 'latest'"""
    with open('Dockerfile') as f:
        content = f.read()

    # Check FROM statements
    from_lines = re.findall(r'^FROM\s+(\S+)', content, re.MULTILINE)

    for image in from_lines:
        assert ':latest' not in image, \
            f"Dockerfile uses 'latest' tag: {image}"
        assert ':' in image, \
            f"Dockerfile missing tag: {image}"

def test_dockerfile_has_healthcheck():
    """Dockerfile should include HEALTHCHECK instruction"""
    with open('Dockerfile') as f:
        content = f.read()

    assert 'HEALTHCHECK' in content, \
        "Dockerfile missing HEALTHCHECK instruction"

def test_dockerfile_runs_as_non_root():
    """Dockerfile should specify non-root USER"""
    with open('Dockerfile') as f:
        content = f.read()

    assert re.search(r'^USER\s+(?!root)', content, re.MULTILINE), \
        "Dockerfile should run as non-root user"

def test_dockerfile_minimizes_layers():
    """Dockerfile should combine RUN commands to minimize layers"""
    with open('Dockerfile') as f:
        content = f.read()

    run_count = len(re.findall(r'^RUN\s+', content, re.MULTILINE))

    assert run_count <= 5, \
        f"Dockerfile has too many RUN commands ({run_count}), consider combining"

def test_dockerfile_cleans_up_apt_cache():
    """Dockerfile should clean up apt cache after installs"""
    with open('Dockerfile') as f:
        content = f.read()

    if 'apt-get install' in content:
        assert 'rm -rf /var/lib/apt/lists/*' in content, \
            "Dockerfile should clean up apt cache"
```

**Run**:
```bash
pytest tests/docker/test_dockerfile_best_practices.py -v
```

---

## Container Image Testing

### 1. Container Structure Tests

**Purpose**: Validate container image structure

**Install**:
```bash
# Download container-structure-test
curl -LO https://storage.googleapis.com/container-structure-test/latest/container-structure-test-linux-amd64
chmod +x container-structure-test-linux-amd64
sudo mv container-structure-test-linux-amd64 /usr/local/bin/container-structure-test
```

**Test Configuration**:
```yaml
# tests/docker/archon-mcp-structure-test.yaml
schemaVersion: '2.0.0'

metadataTest:
  # Image metadata validation
  exposedPorts: ['8051/tcp', '8052/tcp']
  volumes: ['/data', '/config']
  workdir: '/app'
  env:
    - key: 'NODE_ENV'
      value: 'production'
  user: 'archon'  # Non-root user
  labels:
    - key: 'maintainer'
      value: 'AGL Infrastructure Team'

fileExistenceTests:
  # Verify required files exist
  - name: 'Application entrypoint exists'
    path: '/app/server.js'
    shouldExist: true
    permissions: '-rw-r--r--'

  - name: 'Health check script exists'
    path: '/usr/local/bin/healthcheck.sh'
    shouldExist: true
    permissions: '-rwxr-xr-x'

  - name: 'Configuration directory exists'
    path: '/config'
    shouldExist: true
    isDirectory: true

  - name: 'No root-writable directories'
    path: '/usr'
    shouldExist: true
    permissions: 'drwxr-xr-x'

fileContentTests:
  # Verify file contents
  - name: 'Health check script contains expected command'
    path: '/usr/local/bin/healthcheck.sh'
    expectedContents: ['curl -f http://localhost:8051/health']

  - name: 'Package.json has correct version'
    path: '/app/package.json'
    expectedContents: ['"version": "1.0.0"']

commandTests:
  # Test command execution
  - name: 'Node.js installed'
    command: 'node'
    args: ['--version']
    expectedOutput: ['v20\\..*']

  - name: 'npm installed'
    command: 'npm'
    args: ['--version']
    expectedOutput: ['10\\..*']

  - name: 'Health check script executable'
    command: '/usr/local/bin/healthcheck.sh'
    exitCode: 0

  - name: 'Application can start'
    command: 'node'
    args: ['/app/server.js', '--help']
    expectedOutput: ['Usage:']

  - name: 'Non-root user'
    command: 'whoami'
    expectedOutput: ['archon']

licenseTests:
  # Validate licenses
  - debian: true
    files:
      - '/usr/share/doc/*/copyright'
```

**Run**:
```bash
# Test image
container-structure-test test \
  --image archon-mcp:latest \
  --config tests/docker/archon-mcp-structure-test.yaml
```

### 2. Image Build Tests

```python
# tests/docker/test_image_build.py
import docker
import pytest

@pytest.fixture
def docker_client():
    return docker.from_env()

def test_archon_mcp_image_builds(docker_client):
    """Archon MCP image builds successfully"""
    image, logs = docker_client.images.build(
        path="./docker/archon-mcp",
        tag="archon-mcp:test",
        rm=True,
        pull=True
    )

    assert image is not None
    assert "archon-mcp:test" in [tag for tag in image.tags]

def test_image_size_reasonable(docker_client):
    """Image size should be reasonable (<500MB)"""
    image = docker_client.images.get("archon-mcp:test")

    size_mb = image.attrs['Size'] / (1024 * 1024)

    assert size_mb < 500, f"Image too large: {size_mb:.2f}MB"

def test_image_has_labels(docker_client):
    """Image should have required labels"""
    image = docker_client.images.get("archon-mcp:test")
    labels = image.labels

    required_labels = ['maintainer', 'version', 'description']

    for label in required_labels:
        assert label in labels, f"Missing label: {label}"

def test_image_history_reasonable(docker_client):
    """Image should have reasonable number of layers"""
    image = docker_client.images.get("archon-mcp:test")
    history = image.history()

    # Exclude empty layers
    real_layers = [layer for layer in history if layer.get('Size', 0) > 0]

    assert len(real_layers) <= 15, \
        f"Too many image layers: {len(real_layers)}"
```

---

## Docker Compose Testing

### 1. Docker Compose Validation

```bash
# tests/docker/docker-compose-validation.sh
#!/bin/bash

echo "🐳 Docker Compose Validation"

compose_files=$(find . -name "docker-compose*.yml" -o -name "docker-compose*.yaml")

for compose_file in $compose_files; do
  echo "Validating $compose_file..."

  # Syntax validation
  docker-compose -f "$compose_file" config >/dev/null || {
    echo "❌ $compose_file has syntax errors"
    exit 1
  }

  # Check for common issues
  docker-compose -f "$compose_file" config | grep -q "latest" && {
    echo "⚠️  $compose_file uses 'latest' tags"
  }

  echo "✅ $compose_file valid"
done
```

### 2. Docker Compose Stack Tests

```python
# tests/docker/test_docker_compose.py
import subprocess
import time
import json
import pytest

@pytest.fixture(scope="module")
def compose_project():
    """Start docker-compose stack for testing"""
    # Start stack
    subprocess.run(
        ['docker-compose', '-f', 'docker-compose.test.yml', 'up', '-d'],
        check=True
    )

    # Wait for services to be healthy
    time.sleep(10)

    yield

    # Cleanup
    subprocess.run(
        ['docker-compose', '-f', 'docker-compose.test.yml', 'down', '-v'],
        check=True
    )

def test_all_services_started(compose_project):
    """All services should start successfully"""
    result = subprocess.run(
        ['docker-compose', '-f', 'docker-compose.test.yml', 'ps', '--format', 'json'],
        capture_output=True,
        text=True
    )

    services = json.loads(f"[{result.stdout.replace('\\n', ',')}]")

    for service in services:
        assert service['State'] == 'running', \
            f"Service {service['Service']} not running"

def test_all_services_healthy(compose_project):
    """All services should be healthy"""
    max_wait = 60
    elapsed = 0

    while elapsed < max_wait:
        result = subprocess.run(
            ['docker-compose', '-f', 'docker-compose.test.yml', 'ps', '--format', 'json'],
            capture_output=True,
            text=True
        )

        services = json.loads(f"[{result.stdout.replace('\\n', ',')}]")
        all_healthy = all(s.get('Health', 'healthy') == 'healthy' for s in services)

        if all_healthy:
            return

        time.sleep(5)
        elapsed += 5

    pytest.fail("Services not healthy within 60 seconds")

def test_service_networking(compose_project):
    """Services should be able to communicate"""
    # Test API can reach database
    result = subprocess.run(
        ['docker-compose', '-f', 'docker-compose.test.yml', 'exec', '-T', 'api',
         'curl', '-f', 'http://database:5432'],
        capture_output=True
    )

    assert result.returncode == 0, "API cannot reach database"

def test_volumes_mounted(compose_project):
    """Volumes should be mounted correctly"""
    result = subprocess.run(
        ['docker-compose', '-f', 'docker-compose.test.yml', 'exec', '-T', 'app',
         'ls', '/data'],
        capture_output=True
    )

    assert result.returncode == 0, "Volume not mounted"
```

---

## Container Runtime Testing

### 1. Container Lifecycle Tests

```python
# tests/docker/test_container_lifecycle.py
import docker
import time
import pytest

@pytest.fixture
def docker_client():
    return docker.from_env()

def test_container_starts_successfully(docker_client):
    """Container should start without errors"""
    container = docker_client.containers.run(
        "archon-mcp:latest",
        detach=True,
        name="test-archon-start"
    )

    # Wait for startup
    time.sleep(5)

    container.reload()
    assert container.status == "running"

    # Cleanup
    container.stop()
    container.remove()

def test_container_becomes_healthy(docker_client):
    """Container health check should pass"""
    container = docker_client.containers.run(
        "archon-mcp:latest",
        detach=True,
        name="test-archon-health",
        healthcheck={
            "test": ["CMD", "curl", "-f", "http://localhost:8051/health"],
            "interval": 10_000_000_000,  # 10s
            "timeout": 5_000_000_000,
            "retries": 3
        }
    )

    # Wait for health check
    max_wait = 60
    elapsed = 0

    while elapsed < max_wait:
        container.reload()
        if container.health == "healthy":
            break
        time.sleep(5)
        elapsed += 5

    assert container.health == "healthy", \
        f"Container not healthy after {max_wait}s"

    # Cleanup
    container.stop()
    container.remove()

def test_container_stops_gracefully(docker_client):
    """Container should stop gracefully on SIGTERM"""
    container = docker_client.containers.run(
        "archon-mcp:latest",
        detach=True,
        name="test-archon-stop"
    )

    time.sleep(5)

    # Measure stop time
    start = time.time()
    container.stop(timeout=10)
    stop_time = time.time() - start

    assert stop_time < 10, \
        f"Container took too long to stop: {stop_time:.2f}s"

    container.remove()

def test_container_restarts_on_failure(docker_client):
    """Container should restart on failure"""
    container = docker_client.containers.run(
        "archon-mcp:latest",
        detach=True,
        name="test-archon-restart",
        restart_policy={"Name": "on-failure", "MaximumRetryCount": 3}
    )

    # Kill container
    container.kill()

    # Wait for restart
    time.sleep(10)

    container.reload()
    assert container.status == "running", \
        "Container did not restart after failure"

    # Cleanup
    container.stop()
    container.remove()
```

### 2. Container Environment Tests

```bash
# tests/docker/container-environment-test.sh
#!/bin/bash

echo "🌍 Container Environment Tests"

# Test 1: Environment variables set correctly
test_env_vars() {
  local container="$1"

  echo "Testing environment variables..."

  # Check NODE_ENV
  node_env=$(docker exec "$container" printenv NODE_ENV)
  [ "$node_env" = "production" ] || {
    echo "❌ NODE_ENV not set correctly: $node_env"
    return 1
  }

  echo "✅ Environment variables correct"
}

# Test 2: User context correct
test_user_context() {
  local container="$1"

  echo "Testing user context..."

  user=$(docker exec "$container" whoami)
  [ "$user" != "root" ] || {
    echo "❌ Container running as root"
    return 1
  }

  echo "✅ Container running as non-root: $user"
}

# Test 3: File permissions correct
test_file_permissions() {
  local container="$1"

  echo "Testing file permissions..."

  # Check writable directories
  docker exec "$container" touch /data/test-file || {
    echo "❌ /data not writable"
    return 1
  }

  docker exec "$container" rm /data/test-file

  echo "✅ File permissions correct"
}

# Run tests
container_name="archon-mcp-test"

docker run -d --name "$container_name" archon-mcp:latest
sleep 5

test_env_vars "$container_name"
test_user_context "$container_name"
test_file_permissions "$container_name"

docker stop "$container_name"
docker rm "$container_name"

echo "✅ All container environment tests passed"
```

---

## Security Testing

### 1. Vulnerability Scanning (Trivy)

```bash
# tests/docker/vulnerability-scan.sh
#!/bin/bash

echo "🔒 Container Vulnerability Scanning"

images=(
  "archon-mcp:latest"
  "harbor:latest"
  "postgres:15"
)

for image in "${images[@]}"; do
  echo "Scanning $image..."

  # Scan for vulnerabilities
  trivy image \
    --severity HIGH,CRITICAL \
    --exit-code 1 \
    --no-progress \
    "$image" || {
      echo "❌ Vulnerabilities found in $image"
      exit 1
    }

  echo "✅ $image clean"
done

echo "✅ All images passed vulnerability scan"
```

**Install Trivy**:
```bash
# Linux
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install trivy

# macOS
brew install trivy

# Docker
docker pull aquasec/trivy:latest
```

### 2. Container Security Audit

```bash
# tests/docker/security-audit.sh
#!/bin/bash

echo "🔒 Container Security Audit"

audit_container() {
  local container="$1"

  echo "Auditing $container..."

  # Check 1: Not running as root
  user=$(docker inspect --format='{{.Config.User}}' "$container")
  if [ -z "$user" ] || [ "$user" = "root" ] || [ "$user" = "0" ]; then
    echo "❌ $container running as root"
    return 1
  fi

  # Check 2: Not privileged
  privileged=$(docker inspect --format='{{.HostConfig.Privileged}}' "$container")
  if [ "$privileged" = "true" ]; then
    echo "❌ $container running in privileged mode"
    return 1
  fi

  # Check 3: Read-only root filesystem (recommended)
  readonly_root=$(docker inspect --format='{{.HostConfig.ReadonlyRootfs}}' "$container")
  if [ "$readonly_root" != "true" ]; then
    echo "⚠️  $container root filesystem not read-only (recommended)"
  fi

  # Check 4: No sensitive capabilities
  capabilities=$(docker inspect --format='{{.HostConfig.CapAdd}}' "$container")
  for cap in SYS_ADMIN SYS_MODULE SYS_RAWIO; do
    if echo "$capabilities" | grep -q "$cap"; then
      echo "❌ $container has sensitive capability: $cap"
      return 1
    fi
  done

  echo "✅ $container security audit passed"
}

# Audit all running containers
for container in $(docker ps -q); do
  audit_container "$container"
done
```

### 3. Secret Detection

```bash
# tests/docker/secret-detection.sh
#!/bin/bash

echo "🔒 Secret Detection in Images"

detect_secrets_in_image() {
  local image="$1"

  echo "Scanning $image for secrets..."

  # Export image to tar
  docker save "$image" -o /tmp/image.tar

  # Scan with trufflehog
  trufflehog filesystem /tmp/image.tar --json > /tmp/secrets.json

  if [ -s /tmp/secrets.json ]; then
    echo "❌ Secrets detected in $image"
    cat /tmp/secrets.json
    rm /tmp/image.tar /tmp/secrets.json
    return 1
  fi

  rm /tmp/image.tar /tmp/secrets.json
  echo "✅ No secrets detected in $image"
}

images=("archon-mcp:latest" "harbor:latest")

for image in "${images[@]}"; do
  detect_secrets_in_image "$image"
done
```

---

## Performance Testing

### 1. Container Startup Performance

```python
# tests/docker/test_container_performance.py
import docker
import time
import pytest

@pytest.fixture
def docker_client():
    return docker.from_env()

def test_container_startup_time(docker_client):
    """Container should start in <10 seconds"""
    start = time.time()

    container = docker_client.containers.run(
        "archon-mcp:latest",
        detach=True,
        name="test-archon-perf"
    )

    # Wait for healthy status
    max_wait = 30
    elapsed = 0

    while elapsed < max_wait:
        container.reload()
        if container.status == "running":
            break
        time.sleep(1)
        elapsed += 1

    startup_time = time.time() - start

    # Cleanup
    container.stop()
    container.remove()

    assert startup_time < 10, \
        f"Container startup too slow: {startup_time:.2f}s"

def test_container_memory_usage(docker_client):
    """Container should use reasonable memory"""
    container = docker_client.containers.run(
        "archon-mcp:latest",
        detach=True,
        name="test-archon-memory"
    )

    time.sleep(10)  # Let it stabilize

    stats = container.stats(stream=False)
    memory_mb = stats['memory_stats']['usage'] / (1024 * 1024)

    # Cleanup
    container.stop()
    container.remove()

    assert memory_mb < 512, \
        f"Container using too much memory: {memory_mb:.2f}MB"

def test_container_cpu_usage(docker_client):
    """Container should not consume excessive CPU"""
    container = docker_client.containers.run(
        "archon-mcp:latest",
        detach=True,
        name="test-archon-cpu"
    )

    time.sleep(10)

    # Measure CPU usage over 10 seconds
    stats_samples = []
    for _ in range(5):
        stats = container.stats(stream=False)
        cpu_delta = stats['cpu_stats']['cpu_usage']['total_usage'] - \
                    stats['precpu_stats']['cpu_usage']['total_usage']
        system_delta = stats['cpu_stats']['system_cpu_usage'] - \
                       stats['precpu_stats']['system_cpu_usage']
        cpu_percent = (cpu_delta / system_delta) * 100 * \
                     len(stats['cpu_stats']['cpu_usage']['percpu_usage'])
        stats_samples.append(cpu_percent)
        time.sleep(2)

    avg_cpu = sum(stats_samples) / len(stats_samples)

    # Cleanup
    container.stop()
    container.remove()

    assert avg_cpu < 50, \
        f"Container using too much CPU: {avg_cpu:.2f}%"
```

### 2. Load Testing

```bash
# tests/docker/container-load-test.sh
#!/bin/bash

echo "⚡ Container Load Testing"

# Test concurrent container starts
test_concurrent_starts() {
  echo "Testing concurrent container starts..."

  count=10
  start=$(date +%s)

  for i in $(seq 1 $count); do
    docker run -d --name "load-test-$i" archon-mcp:latest &
  done

  wait

  end=$(date +%s)
  duration=$((end - start))

  echo "Started $count containers in ${duration}s"

  # Cleanup
  for i in $(seq 1 $count); do
    docker stop "load-test-$i" &
    docker rm "load-test-$i" &
  done

  wait

  [ "$duration" -lt 30 ] || {
    echo "❌ Container starts too slow: ${duration}s"
    return 1
  }

  echo "✅ Concurrent starts within acceptable time"
}

test_concurrent_starts
```

---

## Test Automation

### Complete Test Suite Runner

```bash
# tests/docker/run-all-docker-tests.sh
#!/bin/bash
set -e

echo "🐳 Running Complete Docker Test Suite"

START_TIME=$(date +%s)

# 1. Dockerfile Linting
echo ""
echo "═══════════════════════════════════════"
echo "1. Dockerfile Linting"
echo "═══════════════════════════════════════"
bash tests/docker/dockerfile-lint.sh

# 2. Dockerfile Best Practices
echo ""
echo "═══════════════════════════════════════"
echo "2. Dockerfile Best Practices"
echo "═══════════════════════════════════════"
pytest tests/docker/test_dockerfile_best_practices.py -v

# 3. Image Build Tests
echo ""
echo "═══════════════════════════════════════"
echo "3. Image Build Tests"
echo "═══════════════════════════════════════"
pytest tests/docker/test_image_build.py -v

# 4. Container Structure Tests
echo ""
echo "═══════════════════════════════════════"
echo "4. Container Structure Tests"
echo "═══════════════════════════════════════"
container-structure-test test \
  --image archon-mcp:latest \
  --config tests/docker/archon-mcp-structure-test.yaml

# 5. Docker Compose Validation
echo ""
echo "═══════════════════════════════════════"
echo "5. Docker Compose Validation"
echo "═══════════════════════════════════════"
bash tests/docker/docker-compose-validation.sh

# 6. Container Lifecycle Tests
echo ""
echo "═══════════════════════════════════════"
echo "6. Container Lifecycle Tests"
echo "═══════════════════════════════════════"
pytest tests/docker/test_container_lifecycle.py -v

# 7. Security Testing
echo ""
echo "═══════════════════════════════════════"
echo "7. Security Testing"
echo "═══════════════════════════════════════"
bash tests/docker/vulnerability-scan.sh
bash tests/docker/security-audit.sh

# 8. Performance Testing
echo ""
echo "═══════════════════════════════════════"
echo "8. Performance Testing"
echo "═══════════════════════════════════════"
pytest tests/docker/test_container_performance.py -v

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "═══════════════════════════════════════"
echo "✅ All Docker Tests Passed"
echo "═══════════════════════════════════════"
echo "Total Duration: ${DURATION}s"
```

**Run**:
```bash
bash tests/docker/run-all-docker-tests.sh
```

---

## Related Documentation

- **[COMPREHENSIVE-TEST-STRATEGY.md](./COMPREHENSIVE-TEST-STRATEGY.md)** - Overall testing strategy
- **[ENVIRONMENT-TEST-PLANS.md](./ENVIRONMENT-TEST-PLANS.md)** - Environment-specific tests
- **[CI-CD-INTEGRATION.md](./CI-CD-INTEGRATION.md)** - CI/CD pipeline integration

---

**Document Status**: ✅ Complete
**Maintained by**: Tester Agent - Hive Mind Collective
**Version**: 1.0.0

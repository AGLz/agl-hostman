# Hive Mind Worker Pool - Production Dockerfile
FROM node:18-alpine

# Metadata
LABEL maintainer="AGL Infrastructure Team"
LABEL description="Hive Mind Worker Pool - Multi-agent orchestration system"
LABEL version="2.0.0"

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apk add --no-cache \
    python3 \
    make \
    g++ \
    git \
    curl

# Copy package files
COPY package.json package-lock.json* pnpm-lock.yaml* ./

# Install Node.js dependencies
# Try pnpm first, fallback to npm
RUN if [ -f "pnpm-lock.yaml" ]; then \
      npm install -g pnpm && \
      pnpm install --frozen-lockfile --prod; \
    elif [ -f "package-lock.json" ]; then \
      npm ci --only=production; \
    else \
      npm install --only=production; \
    fi

# Copy source files
COPY src/hive-mind-integration ./src/hive-mind-integration
COPY src/performance ./src/performance
COPY tests ./tests
COPY examples ./examples

# Create directories for logs and data
RUN mkdir -p /app/logs /app/data /app/metrics

# Set environment variables
ENV NODE_ENV=production \
    LOG_LEVEL=info \
    WORKER_POOL_SIZE=4 \
    MAX_WORKERS=16 \
    ENABLE_MONITORING=true \
    METRICS_RETENTION_HOURS=24

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD node -e "require('./src/hive-mind-integration').HiveMindWorkerPool" || exit 1

# Expose monitoring port (if needed for future API)
EXPOSE 9090

# Default command - Run interactive node REPL with hive-mind preloaded
CMD ["node", "-i", "-e", "const { HiveMindWorkerPool, AgentTemplates, PerformanceMonitor } = require('./src/hive-mind-integration'); console.log('Hive Mind Worker Pool loaded. Example:\\nconst pool = new HiveMindWorkerPool();');"]

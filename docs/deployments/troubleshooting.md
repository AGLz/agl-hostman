# Deployment Troubleshooting Guide

## Overview

This guide provides solutions to common deployment issues in AGL Hostman, including error diagnosis, resolution steps, and preventive measures.

## Quick Diagnosis Flowchart

```
Deployment Failed?
│
├─ Check Logs → /storage/logs/deployment.log
│
├─ Check Container Status → docker ps -a
│
├─ Check Health Endpoint → curl https://app.agl.io/health
│
├─ Check Environment → php artisan env
│
└─ Check Dependencies → php artisan about
```

## Common Issues & Solutions

### Category 1: Build Failures

#### Issue 1.1: Docker Build Fails
**Symptoms:**
```
Error: Build failed with exit code 1
Step 5/8: RUN npm install
ERROR [builder] failed to compute cache key
```

**Diagnosis:**
```bash
# Check build logs
docker logs <container_id>

# Check Dockerfile syntax
docker build --no-cache -t test .

# Verify base image exists
docker pull <base_image>
```

**Solutions:**

**Solution A: Fix Dockerfile**
```dockerfile
# Add explicit version pinning
FROM node:18-alpine AS builder

# Add build dependencies
RUN apk add --no-cache python3 make g++

# Use npm ci for faster, reliable builds
COPY package*.json ./
RUN npm ci --only=production

# Copy source code
COPY . .

# Build application
RUN npm run build
```

**Solution B: Clear Build Cache**
```bash
# Clear Docker build cache
docker builder prune -a

# Clear specific image cache
docker rmi $(docker images -q -f 'dangling=true')

# Rebuild without cache
docker-compose build --no-cache
```

**Solution C: Increase Build Resources**
```yaml
# docker-compose.yml
version: '3.8'
services:
  app:
    build:
      context: .
      cache_from:
        - app:latest
      args:
        BUILDKIT_INLINE_CACHE: 1
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
```

**Prevention:**
- Pin dependency versions
- Use multi-stage builds
- Enable BuildKit caching
- Test builds in local environment first

---

#### Issue 1.2: Dependency Installation Fails
**Symptoms:**
```
Error: Cannot resolve dependency 'react@19'
npm ERR! code ERESOLVE
npm ERR! ERESOLVE unable to resolve dependency tree
```

**Diagnosis:**
```bash
# Check package.json conflicts
npm ls react

# Verify Node version
node --version

# Check for lockfile issues
npm ci --dry-run
```

**Solutions:**

**Solution A: Update Dependencies**
```bash
# Update all dependencies
npx npm-check-updates -u

# Install updated packages
npm install

# Test application
npm test
```

**Solution B: Force Resolution (Use with Caution)**
```bash
# Force legacy peer deps
npm install --legacy-peer-deps

# Or use --force flag
npm install --force
```

**Solution C: Use Exact Versions**
```json
// package.json
{
  "dependencies": {
    "react": "19.0.0",  // Use exact version
    "react-dom": "19.0.0"
  },
  "overrides": {
    "react": "19.0.0"
  }
}
```

**Prevention:**
- Use `package-lock.json` in version control
- Run `npm audit` regularly
- Test dependency updates in development first
- Use Dependabot for automated updates

---

#### Issue 1.3: Git Clone Fails During Build
**Symptoms:**
```
Error: Cloning into '/var/www/html'...
fatal: could not read Username for 'https://github.com'
```

**Diagnosis:**
```bash
# Test Git credentials
git ls-remote https://github.com/agl/myapp.git

# Check SSH key
ssh -T git@github.com
```

**Solutions:**

**Solution A: Use Deploy Keys**
```bash
# Add SSH key to container
# In Dokploy: Settings → Git → Deploy Key

# Or use personal access token
git clone https://TOKEN@github.com/agl/myapp.git
```

**Solution B: Use Git Credential Helper**
```bash
# Configure credential helper
git config --global credential.helper store

# Add credentials
echo "https://USERNAME:TOKEN@github.com" > ~/.git-credentials
```

**Solution C: Use Private Repository with Access Token**
```json
// composer.json (PHP)
{
  "repositories": [
    {
      "type": "vcs",
      "url": "https://TOKEN@github.com/agl/private-repo.git"
    }
  ]
}
```

**Prevention:**
- Use deploy keys instead of personal credentials
- Rotate access tokens regularly
- Use SSH for private repositories
- Store credentials in environment variables

---

### Category 2: Deployment Failures

#### Issue 2.1: Container Crashes Immediately
**Symptoms:**
```
Container exited with code 1
Restart policy: On failure
```

**Diagnosis:**
```bash
# Check container logs
docker logs <container_id>

# Check container status
docker inspect <container_id>

# Check exit code
docker ps -a --format "{{.Status}} {{.ExitCode}}"
```

**Solutions:**

**Solution A: Fix Application Entry Point**
```dockerfile
# Dockerfile
CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=80"]
```

**Solution B: Add Health Check**
```yaml
# docker-compose.yml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:80/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

**Solution C: Fix Environment Variables**
```bash
# Verify environment variables
docker exec <container_id> env | grep APP_

# Add missing variables
docker run -e APP_KEY=base64:... -e APP_ENV=production ...
```

**Prevention:**
- Always test container locally before deployment
- Use proper CMD/ENTRYPOINT
- Implement health checks
- Validate environment variables

---

#### Issue 2.2: Port Already in Use
**Symptoms:**
```
Error: bind: address already in use
Error: listen tcp 0.0.0.0:3000: bind: address already in use
```

**Diagnosis:**
```bash
# Check what's using the port
netstat -tulpn | grep :3000
# or
lsof -i :3000

# Check Docker networks
docker network ls
docker network inspect bridge
```

**Solutions:**

**Solution A: Stop Conflicting Container**
```bash
# Find and stop conflicting container
docker ps -a | grep :3000
docker stop <conflicting_container>
docker rm <conflicting_container>
```

**Solution B: Use Different Port**
```yaml
# docker-compose.yml
services:
  app:
    ports:
      - "3001:3000"  # Map container port 3000 to host port 3001
```

**Solution C: Use Traefik for Port Management**
```yaml
# docker-compose.yml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.myapp.rule=Host(`app.agl.io`)"
  - "traefik.http.services.myapp.loadbalancer.server.port=3000"
```

**Prevention:**
- Use Traefik for routing (no exposed ports needed)
- Document port allocations
- Use container networking
- Implement port conflict detection

---

#### Issue 2.3: Health Check Failures
**Symptoms:**
```
Health check failed after 3 retries
Container marked as unhealthy
```

**Diagnosis:**
```bash
# Manual health check
curl -v http://localhost:3000/health

# Check health check configuration
docker inspect --format='{{json .State.Health}}' <container_id>

# Check application logs
docker logs <container_id> | tail -100
```

**Solutions:**

**Solution A: Fix Health Check Endpoint**
```javascript
// Express.js health endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});
```

**Solution B: Increase Health Check Timeout**
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
  interval: 30s
  timeout: 10s  # Increase from 5s
  retries: 5    # Increase from 3
  start_period: 60s  # Give more time for startup
```

**Solution C: Fix Dependencies Blocking Startup**
```bash
# Check if database is reachable
docker exec <container_id> nc -zv db 5432

# Check if Redis is reachable
docker exec <container_id> nc -zv redis 6379

# Wait for dependencies before starting app
CMD ["sh", "-c", "wait-for-it db:5432 -- php artisan serve"]
```

**Prevention:**
- Keep health checks lightweight
- Return appropriate HTTP status codes
- Test health endpoint during development
- Monitor health check failures

---

### Category 3: Runtime Issues

#### Issue 3.1: Application Returns 500 Errors
**Symptoms:**
```
HTTP 500 Internal Server Error
Error log: Fatal error: Class 'App\\Models\\User' not found
```

**Diagnosis:**
```bash
# Check Laravel logs
tail -f storage/logs/laravel.log

# Check PHP errors
docker exec <container_id> php -l /var/www/html/artisan

# Check autoloader
docker exec <container_id> composer dump-autoload
```

**Solutions:**

**Solution A: Fix Missing Classes**
```bash
# Regenerate autoloader
docker exec <container_id> composer dump-autoload -o

# Clear opcache
docker exec <container_id> php artisan opcache:clear
```

**Solution B: Fix Configuration**
```bash
# Clear configuration cache
docker exec <container_id> php artisan config:clear

# Regenerate config
docker exec <container_id> php artisan config:cache
```

**Solution C: Fix Database Connection**
```bash
# Test database connection
docker exec <container_id> php artisan db:show

# Check database credentials
docker exec <container_id> env | grep DB_

# Fix .env file
echo "DB_CONNECTION=pgsql" >> .env
echo "DB_HOST=db" >> .env
```

**Prevention:**
- Run tests before deployment
- Use error tracking (Sentry, Bugsnag)
- Monitor application logs
- Implement graceful error handling

---

#### Issue 3.2: Slow Performance / High Response Time
**Symptoms:**
```
Response time: 15-20 seconds (normal: <1s)
CPU usage: 95%
Memory usage: 90%
```

**Diagnosis:**
```bash
# Check container stats
docker stats --no-stream

# Check CPU usage
docker exec <container_id> top

# Profile application
docker exec <container_id> php artisan tinker
# >>> $start = microtime(true); // your code; echo microtime(true) - $start;
```

**Solutions:**

**Solution A: Optimize Database Queries**
```php
// Before: N+1 queries
$users = User::all();
foreach ($users as $user) {
    echo $user->posts->count;  // Separate query for each user
}

// After: Eager loading
$users = User::with('posts')->get();
foreach ($users as $user) {
    echo $user->posts->count;  // No additional queries
}
```

**Solution B: Enable Caching**
```bash
# Enable Redis cache
docker exec <container_id> php artisan config:cache
docker exec <container_id> php artisan route:cache
docker exec <container_id> php artisan view:cache

# Use OPcache
docker exec <container_id> php -d opcache.enable=1 artisan serve
```

**Solution C: Scale Horizontally**
```yaml
# docker-compose.yml
services:
  app:
    deploy:
      replicas: 3  # Run 3 instances
      resources:
        limits:
          cpus: '1'
          memory: 1G
```

**Prevention:**
- Use query optimization
- Implement caching strategies
- Use connection pooling
- Monitor performance metrics

---

#### Issue 3.3: Memory Leaks
**Symptoms:**
```
Container memory usage grows continuously
Container gets killed (OOMKilled)
```

**Diagnosis:**
```bash
# Check memory usage over time
docker stats --format "table {{.Container}}\t{{.MemUsage}}"

# Check for memory leaks
docker exec <container_id> cat /sys/fs/cgroup/memory/memory.usage_in_bytes

# Profile memory
docker exec <container_id> php -d memory_limit=1G artisan tinker
# >>> memory_get_usage(true);
```

**Solutions:**

**Solution A: Fix Memory Leaks in Code**
```php
// Before: Potential leak
function processItems() {
    $items = [];
    while (true) {
        $items[] = loadData();  // Keeps growing
    }
}

// After: Proper cleanup
function processItems() {
    while (true) {
        $items = loadData();
        processData($items);
        unset($items);  // Explicit cleanup
        gc_collect_cycles();  // Force garbage collection
    }
}
```

**Solution B: Increase Memory Limit**
```yaml
# docker-compose.yml
services:
  app:
    deploy:
      resources:
        limits:
          memory: 2G  # Increase from 512M
```

**Solution C: Use Worker Processes**
```bash
# Restart workers periodically
docker exec <container_id> php artisan queue:restart

# Or use supervisor to auto-restart
# supervisor.conf
[program:laravel-worker]
process_name=%(program_name)s_%(process_num)02d
command=php artisan queue:work --sleep=3 --tries=3
autostart=true
autorestart=true
startretries=3
```

**Prevention:**
- Profile memory usage regularly
- Use proper cleanup in code
- Implement memory limits
- Use queue workers for background tasks

---

### Category 4: Network & Connectivity

#### Issue 4.1: Cannot Connect to Database
**Symptoms:**
```
SQLSTATE[HY000] [2002] Connection refused
Error: Could not connect to database server
```

**Diagnosis:**
```bash
# Test database connectivity
docker exec <container_id> nc -zv db 5432

# Check database container status
docker ps | grep postgres

# Check network
docker network inspect <network_name>
```

**Solutions:**

**Solution A: Fix Database Host**
```env
# .env
DB_HOST=db  # Use service name, not localhost
DB_PORT=5432
DB_DATABASE=hostman
DB_USERNAME=hostman
DB_PASSWORD=secret
```

**Solution B: Ensure Containers on Same Network**
```yaml
# docker-compose.yml
version: '3.8'
services:
  app:
    networks:
      - backend

  db:
    networks:
      - backend

networks:
  backend:
    driver: bridge
```

**Solution C: Check Database is Ready**
```bash
# Use wait-for-it script
CMD ["wait-for-it", "db:5432", "--", "php", "artisan", "serve"]

# Or use healthcheck
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U hostman -d hostman"]
  interval: 10s
  timeout: 5s
  retries: 5
```

**Prevention:**
- Use service names for inter-container communication
- Implement health checks
- Use proper networking
- Test database connections in development

---

#### Issue 4.2: SSL/TLS Certificate Errors
**Symptoms:**
```
SSL: certificate subject name does not match target host name
Error: unable to get local issuer certificate
```

**Diagnosis:**
```bash
# Check certificate
openssl s_client -connect app.agl.io:443 -servername app.agl.io

# Check certificate dates
openssl x509 -in /path/to/cert.pem -noout -dates

# Check Traefik configuration
docker exec traefik cat /etc/traefik/traefik.yml
```

**Solutions:**

**Solution A: Configure Traefik SSL**
```yaml
# docker-compose.yml for Traefik
services:
  traefik:
    command:
      - "--certificatesresolvers.myresolver.acme.tlschallenge=true"
      - "--certificatesresolvers.myresolver.acme.email=admin@agl.io"
      - "--certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json"

  app:
    labels:
      - "traefik.http.routers.myapp.tls=true"
      - "traefik.http.routers.myapp.tls.certresolver=myresolver"
```

**Solution B: Use Custom Certificate**
```yaml
# docker-compose.yml
services:
  traefik:
    volumes:
      - ./certs:/certs:ro
    command:
      - "--certificatesresolvers.myresolver.tls.certFile=/certs/cert.pem"
      - "--certificatesresolvers.myresolver.tls.keyFile=/certs/key.pem"
```

**Solution C: Disable SSL Verification (Development Only)
```php
// For development only
$context = [
    'ssl' => [
        'verify_peer' => false,
        'verify_peer_name' => false,
    ]
];
```

**Prevention:**
- Use Let's Encrypt for automatic certificates
- Monitor certificate expiration
- Test SSL configuration
- Use proper certificate chains

---

### Category 5: Environment-Specific Issues

#### Issue 5.1: Environment Variables Not Loading
**Symptoms:**
```
Error: APP_KEY not set
Configuration values are null
```

**Diagnosis:**
```bash
# Check if .env file exists
docker exec <container_id> ls -la /var/www/html/.env

# Check environment variables
docker exec <container_id> env | sort

# Test Laravel configuration
docker exec <container_id> php artisan config:cache
```

**Solutions:**

**Solution A: Add Environment Variables**
```yaml
# docker-compose.yml
services:
  app:
    environment:
      - APP_NAME=AGL_Hostman
      - APP_ENV=production
      - APP_DEBUG=false
      - APP_KEY=base64:...
    env_file:
      - .env.production
```

**Solution B: Use Docker Secrets**
```yaml
# docker-compose.yml
services:
  app:
    secrets:
      - app_key
      - db_password

secrets:
  app_key:
    file: ./secrets/app_key.txt
  db_password:
    file: ./secrets/db_password.txt
```

**Solution C: Generate Missing Keys**
```bash
# Generate Laravel app key
docker exec <container_id> php artisan key:generate

# Generate JWT secret
docker exec <container_id> php artisan jwt:secret
```

**Prevention:**
- Use environment-specific .env files
- Never commit .env to version control
- Use secrets management for sensitive data
- Validate environment variables on startup

---

#### Issue 5.2: Production-Specific Configuration Issues
**Symptoms:**
```
Debug mode enabled in production
Error messages exposed to users
Cache not configured
```

**Diagnosis:**
```bash
# Check APP_ENV
docker exec <container_id> php artisan env

# Check debug mode
docker exec <container_id> php artisan tinker
# >>> config('app.debug');

# Check cache
docker exec <container_id> php artisan cache:status
```

**Solutions:**

**Solution A: Set Production Environment**
```env
# .env.production
APP_ENV=production
APP_DEBUG=false
APP_KEY=base64:...
LOG_CHANNEL=daily
LOG_LEVEL=error
```

**Solution B: Optimize for Production**
```bash
# Clear all caches
docker exec <container_id> php artisan optimize:clear

# Optimize for production
docker exec <container_id> php artisan optimize

# Clear and cache config
docker exec <container_id> php artisan config:cache
```

**Solution C: Set Proper Logging**
```yaml
# config/logging.php
'production' => [
    'driver' => 'daily',
    'path' => storage_path('logs'),
    'level' => 'error',
    'days' => 14,
],
```

**Prevention:**
- Use environment-specific configuration
- Disable debug mode in production
- Implement proper error handling
- Use log aggregation

---

## Diagnostic Commands Reference

### Container Diagnostics
```bash
# List all containers with status
docker ps -a

# Show container details
docker inspect <container_id>

# Show container logs
docker logs -f --tail=100 <container_id>

# Show container resource usage
docker stats --no-stream

# Execute command in container
docker exec -it <container_id> sh

# Show container processes
docker top <container_id>
```

### Application Diagnostics
```bash
# Laravel version
php artisan --version

# Check Laravel configuration
php artisan config:cache
php artisan route:cache
php artisan view:cache

# Check database connection
php artisan db:show

# Check queue status
php artisan queue:failed

# Run diagnostics
php artisan about
```

### Network Diagnostics
```bash
# Show container networks
docker network ls

# Inspect network
docker network inspect <network_name>

# Test connectivity
docker exec <container_id> ping -c 3 google.com

# Test DNS
docker exec <container_id> nslookup google.com

# Test port connectivity
docker exec <container_id> nc -zv <host> <port>
```

### Log Files
```bash
# Laravel logs
tail -f storage/logs/laravel.log

# Deployment logs
tail -f storage/logs/deployment.log

# Queue worker logs
tail -f storage/logs/queue-worker.log

# Nginx logs
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log

# System logs
journalctl -u docker -f
```

## Getting Help

### Before Requesting Help
1. **Collect diagnostics:**
   ```bash
   # Run diagnostics script
   ./scripts/deploy-diagnostics.sh > diagnostics.txt
   ```

2. **Gather information:**
   - Environment (dev/qa/uat/production)
   - Deployment ID
   - Error messages
   - Container logs
   - Recent changes

3. **Check documentation:**
   - [Deployment Overview](./overview.md)
   - [Promotion Process](./promotion-process.md)
   - [Rollback Procedures](./rollbacks.md)

### Contact Channels
- **Slack:** #deployments (general), #production-incidents (urgent)
- **Email:** devops@agl.io
- **On-Call:** PagerDuty rotation
- **Create Ticket:** Linear (AGL Hostman project)

### Emergency Contacts
- **DevOps Lead:** devops-lead@agl.io
- **Technical Director:** tech-director@agl.io
- **On-Call Engineer:** oncall@agl.io (SMS + Phone)

## Related Documentation

- [Deployment Overview](./overview.md) - Understanding the deployment system
- [Promotion Process](./promotion-process.md) - Environment promotion workflow
- [Rollback Procedures](./rollbacks.md) - Rollback strategies and execution
- [WebSocket Events](../websocket/events.md) - Real-time deployment events
- [API Reference](../api/overview.md) - Deployment API endpoints

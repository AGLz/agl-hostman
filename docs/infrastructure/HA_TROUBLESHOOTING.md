# AGL Hostman HA Troubleshooting Guide

## Quick Reference

| Issue | First Check | Command |
|-------|-------------|----------|
| LB not responding | HAProxy status | `systemctl status haproxy` |
| Can't connect to DB | MySQL status | `mysqladmin -h db-host ping` |
| Cache errors | Redis status | `redis-cli ping` |
| Slow app response | Check logs | `tail -f /var/log/agl-hostman/laravel.log` |

## HAProxy Issues

### Backend Shows DOWN

**Symptoms:**
- HAProxy stats show red DOWN
- 503 errors in application logs

**Diagnosis:**
```bash
# Check if backend is accessible
curl -v http://backend-host:8080/health

# Check backend health endpoint response
curl http://backend-host:8080/health | jq .

# Check HAProxy configuration
haproxy -c -f /etc/haproxy/haproxy.cfg
```

**Solutions:**

1. **Backend service is down:**
   ```bash
   # Restart application
   systemctl restart agl-hostman
   # Or Docker
   docker restart app-container
   ```

2. **Health check failing:**
   ```bash
   # Check health endpoint logs
   tail -f /var/log/nginx/app-error.log
   ```

3. **Backend marked maintenance:**
   ```bash
   # Check HAProxy stats for admin status
   curl http://haproxy:8404/stats; echo
   ```

### High Response Times

**Symptoms:**
- p95 latency > 2 seconds
- HAProxy queue buildup

**Diagnosis:**
```bash
# Check backend queue sizes
echo "show stat" | nc -U /var/run/haproxy/admin.sock | grep app_backend

# Check connection counts
ss -ant | grep :8080 | wc -l
```

**Solutions:**

1. **Scale up backends:**
   ```bash
   # Add more servers to backend
   # Edit haproxy.cfg and add server lines
   ```

2. **Tune timeouts:**
   ```
   timeout connect 5s
   timeout server 30s
   ```

3. **Enable HTTP/2:**
   ```
   http-always h2c-setup
   ```

### SSL Certificate Issues

**Symptoms:**
- SSL handshake failures
- Certificate expired errors

**Diagnosis:**
```bash
# Check certificate expiry
openssl x509 -in /etc/haproxy/ssl/cert.pem -noout -dates

# Test SSL connection
openssl s_client -connect lb-hostname:443 -servername lb-hostname
```

**Solutions:**

1. **Renew certificate:**
   ```bash
   certbot certonly --standalone -d lb.example.com
   cat /etc/letsencrypt/live/lb.example.com/fullchain.pem > /etc/haproxy/ssl/cert.pem
   ```

2. **Reload HAProxy:**
   ```bash
   systemctl reload haproxy
   ```

## MySQL Replication Issues

### Replication Stopped

**Symptoms:**
- `Slave_IO_Running: No`
- `Slave_SQL_Running: No`

**Diagnosis:**
```bash
# Check slave status
mysql -e "SHOW SLAVE STATUS\G"

# Check error log
tail -f /var/log/mysql/error.log | grep -i error
```

**Solutions:**

1. **Start slave:**
   ```sql
   START SLAVE;
   ```

2. **Fix replication user:**
   ```sql
   -- On master
   CREATE USER IF NOT EXISTS 'repl_user'@'%';
   GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'%';
   FLUSH PRIVILEGES;
   ```

3. **Re-sync from master:**
   ```sql
   STOP SLAVE;
   RESET SLAVE;
   CHANGE MASTER TO
     MASTER_HOST='mysql-master',
     MASTER_USER='repl_user',
     MASTER_PASSWORD='password',
     MASTER_AUTO_POSITION=1;
   START SLAVE;
   ```

### High Replication Lag

**Symptoms:**
- `Seconds_Behind_Master` > 60
- Stale data in reads

**Diagnosis:**
```bash
# Check current lag
mysql -e "SHOW SLAVE STATUS\G" | grep Seconds_Behind_Master

# Check long-running queries
mysql -e "SHOW PROCESSLIST\G" | grep -v Sleep

# Check disk I/O
iostat -x 5
```

**Solutions:**

1. **Optimize slow queries:**
   ```sql
   -- Enable slow query log
   SET GLOBAL slow_query_log = 'ON';
   SET GLOBAL long_query_time = 2;
   ```

2. **Increase parallel workers:**
   ```ini
   # my.cnf
   slave_parallel_workers = 8
   slave_parallel_type = LOGICAL_CLOCK
   ```

3. **Add more slaves:**
   - Reduces read load per slave
   - Provides failover targets

### GTID Position Mismatch

**Symptoms:**
- Error: "The slave is connecting using another user that already has a different GTID"
- Replication breaks after failover

**Diagnosis:**
```bash
# Check executed GTIDs
mysql -e "SELECT @@gtid_executed";

# Check purged GTIDs
mysql -e "SELECT @@gtid_purged";
```

**Solutions:**

1. **Reset slave:**
   ```sql
   RESET MASTER;
   RESET SLAVE;
   ```

2. **Configure from scratch:**
   ```sql
   CHANGE MASTER TO
     MASTER_HOST='new-master',
     MASTER_USER='repl_user',
     MASTER_PASSWORD='password',
     MASTER_AUTO_POSITION=1;
   ```

## Redis Sentinel Issues

### Failover Not Triggering

**Symptoms:**
- Master down but no failover
- Sentinel shows master as ODOWN but no action

**Diagnosis:**
```bash
# Check sentinel state
redis-cli -p 26379 SENTINEL master mymaster

# Check quorum
redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster

# Check sentinel logs
tail -f /var/log/redis/sentinel.log
```

**Solutions:**

1. **Verify quorum configuration:**
   ```conf
   # sentinel.conf
   sentinel monitor mymaster <master-ip> 6379 2
   # Need 2 of 3 sentinels to agree
   ```

2. **Check sentinel connectivity:**
   ```bash
   # Test communication between sentinels
   for port in 26379; do
     nc -zv sentinel-host $port
   done
   ```

3. **Force failover:**
   ```bash
   redis-cli -p 26379 SENTINEL failover mymaster
   ```

### Split Brain (Multiple Masters)

**Symptoms:**
- Multiple masters in sentinel
- Data inconsistency

**Diagnosis:**
```bash
# Check each sentinel's view
for sentinel in sentinel-1 sentinel-2 sentinel-3; do
  redis-cli -h $sentinel -p 26379 SENTINEL masters
done
```

**Solutions:**

1. **Verify network:**
   ```bash
   # Check network partition
   ping -c 3 master-host
   ```

2. **Reset sentinel:**
   ```bash
   # On all sentinels
   redis-cli -p 26379 SENTINEL RESET mymaster
   # Sentinel will auto-rediscover
   ```

3. **Fix configuration:**
   ```conf
   # Ensure all sentinels have same config
   sentinel down-after-milliseconds mymaster 5000
   sentinel failover-timeout mymaster 10000
   ```

### Eviction Under Load

**Symptoms:**
- `evicted_keys` counter increasing
- Cache miss rate high

**Diagnosis:**
```bash
# Check eviction stats
redis-cli INFO stats | grep evicted

# Check memory usage
redis-cli INFO memory | grep used_memory_human
```

**Solutions:**

1. **Increase maxmemory:**
   ```conf
   maxmemory 4gb
   ```

2. **Change eviction policy:**
   ```conf
   maxmemory-policy allkeys-lru
   ```

3. **Add more Redis nodes:**
   - Distributes load
   - Increases total capacity

## Application Issues

### Queue Backing Up

**Symptoms:**
- Horizon shows >1000 pending jobs
- Jobs not processing

**Diagnosis:**
```bash
# Check horizon status
php artisan horizon:status

# Check redis queue length
redis-cli --csv LLEN queues:default

# Check worker processes
ps aux | grep horizon | wc -l
```

**Solutions:**

1. **Scale workers:**
   ```bash
   # Docker: scale up
   docker compose up -d --scale horizon=4
   ```

2. **Clear stuck jobs:**
   ```bash
   php artisan horizon:purge
   ```

3. **Check supervisor:**
   ```bash
   supervisorctl status horizon:*
   supervisorctl start horizon:*
   ```

### Health Check Failures

**Symptoms:**
- Load balancer marks backend DOWN
- Health endpoint timing out

**Diagnosis:**
```bash
# Test health endpoint
time curl http://app-host:8080/health

# Check response time
curl -w "@curl-format.txt" http://app-host:8080/health

# curl-format.txt contents:
#   time_namelookup:  %{time_namelookup}\n
#   time_connect:     %{time_connect}\n
#   time_appconnect:  %{time_appconnect}\n
#   time_pretransfer: %{time_pretransfer}\n
#   time_starttransfer: %{time_starttransfer}\n
#   time_total:       %{time_total}\n
```

**Solutions:**

1. **Optimize health check:**
   ```php
   // Remove heavy operations
   public function index()
   {
       // Quick DB check only
       DB::select('1');
       return response()->json(['status' => 'ok']);
   }
   ```

2. **Increase timeout:**
   ```
   # In HAProxy
   timeout check 10s
   ```

3. **Check database pool:**
   ```ini
   # .env
   DB_MAX_CONNECTIONS=100
   ```

### Session Persistence Issues

**Symptoms:**
- Users logged out randomly
- Shopping cart lost

**Diagnosis:**
```bash
# Check HAProxy stick table
echo "show table" | nc -U /var/run/haproxy/admin.sock | grep app_backend

# Check Redis sessions
redis-cli --scan --pattern "laravel_session*"
```

**Solutions:**

1. **Verify stick table configuration:**
   ```
   backend app_backend
       stick-table type ip size 1m expire 1h
       stick on dst
   ```

2. **Check Redis persistence:**
   ```bash
   redis-cli CONFIG GET save
   redis-cli CONFIG GET appendonly
   ```

## Network Issues

### DNS Resolution Failures

**Symptoms:**
- Backend not found errors
- DNS lookup delays

**Diagnosis:**
```bash
# Test DNS resolution
time nslookup mysql-master
time dig redis-master.example.com

# Check local cache
systemd-resolve --status
```

**Solutions:**

1. **Use IPs in configs:**
   ```
   server app-blue-1 10.0.1.10:80 check
   ```

2. **Configure local DNS:**
   ```bash
   # /etc/hosts
   10.0.1.10 mysql-master
   10.0.1.11 redis-master
   ```

3. **Use DNS cache:**
   ```bash
   # Install dnsmasq
   systemctl enable dnsmasq
   ```

### Firewall Blocking Connections

**Symptoms:**
- Connection timeouts
- "Connection refused" errors

**Diagnosis:**
```bash
# Check if ports are open
nc -zv mysql-master 3306
nc -zv redis-master 6379
nc -zv app-blue-1 8080

# Check firewall rules
iptables -L -n -v

# Check UFW
ufw status
ufw status numbered
```

**Solutions:**

1. **Open required ports:**
   ```bash
   # UFW
   ufw allow from lb-ip to any port 3306
   ufw allow from lb-ip to any port 6379
   ufw allow from lb-ip to any port 8080
   ```

2. **Proxmox firewall:**
   ```bash
   # In Proxmox GUI
   Datacenter > Firewall > Add Rule
   # Or via CLI
   pct exec <vmid> -- ufw allow 3306
   ```

## Emergency Procedures

### Complete Outage

**Severity: CRITICAL**

**Steps:**

1. **Assess scope:**
   ```bash
   # Check all services
   for host in mysql-master redis-master app-blue-1 app-blue-2; do
     curl -s http://$host:8080/health || echo "$host: DOWN"
   done
   ```

2. **Notify team:**
   ```bash
   # Send page
   curl -X POST $PAGERDUTY_API \
     -d '{"routing_key":"critical","event_action":"trigger"}'
   ```

3. **Check dashboards:**
   - Grafana: http://monitoring:3000
   - HAProxy: http://lb:8404/stats

4. **Begin recovery:**
   - Start with critical path: load balancer
   - Verify application servers
   - Check database connectivity
   - Verify cache/queue

### Data Corruption Detected

**Severity: CRITICAL**

**Steps:**

1. **Stop writes:**
   ```bash
   # Enable maintenance mode
   php artisan down --message="Emergency maintenance"
   ```

2. **Assess damage:**
   ```sql
   -- Check table consistency
   CHECK TABLE users;
   CHECK TABLE jobs;
   ```

3. **Restore from backup:**
   ```bash
   # Most recent backup
   gunzip < /backup/mysql-$(date +%Y%m%d).sql.gz | mysql -u root -p
   ```

4. **Verify and resume:**
   ```bash
   php artisan up
   ```

## Contact Escalation

| Time to Resolve | Action |
|-----------------|--------|
| 0-15 min | On-call engineer |
| 15-30 min | Engineering lead |
| 30-60 min | CTO notification |
| > 60 min | Incident post-mortem required |

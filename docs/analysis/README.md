# VPS Timeout Analysis Framework
**Created:** 2025-10-22
**Analyst:** Hive Mind Analyst Agent
**Status:** Ready for deployment

---

## Overview

This directory contains a comprehensive diagnostic framework for investigating timeout issues across three VPS hosts:
- **fgsrv3**: MySQL database server
- **fgsrv4**: nginx/PHP5 web server (https://falg.com.br)
- **fgsrv5**: nginx/Laravel API server (https://api.falg.com.br)

## Framework Components

### 1. Diagnostic Framework (`diagnostic-framework.md`)
**Purpose:** Complete methodology for systematic timeout investigation

**Contents:**
- 10 investigation phases with detailed procedures
- Cron job analysis strategies
- MySQL slow query investigation
- Nginx log analysis patterns
- PHP-FPM process monitoring
- Network latency measurement
- Resource utilization baselines
- Root cause analysis workflow
- Shared memory coordination keys

**When to use:** Primary reference document for the entire investigation process

---

### 2. Investigation Checklist (`timeout-investigation-checklist.md`)
**Purpose:** Task-by-task execution checklist with 138+ discrete tasks

**Contents:**
- 10 phases with checkbox tracking
- Pre-investigation setup tasks
- Phase-specific data collection procedures
- Correlation and pattern analysis tasks
- Hypothesis testing protocols
- Root cause confirmation steps
- Solution recommendations framework
- Post-investigation documentation tasks

**When to use:** Daily execution guide during active investigation

**Progress tracking:**
```bash
# Example: Mark tasks as completed
sed -i 's/- \[ \] Task 1.1:/- [x] Task 1.1:/' timeout-investigation-checklist.md
```

---

### 3. Log Analysis Script (`log-analysis-queries.sh`)
**Purpose:** Automated log collection and analysis across all hosts

**Features:**
- Analyzes 10 key diagnostic areas
- Generates structured output files
- Creates executive summary report
- Produces compressed tarball for easy transfer
- Color-coded terminal output
- No external dependencies (uses standard Linux tools)

**Usage:**
```bash
# Run on each host
ssh fgsrv3 'bash -s' < /mnt/overpower/apps/dev/agl/agl-hostman/docs/analysis/log-analysis-queries.sh
ssh fgsrv4 'bash -s' < /mnt/overpower/apps/dev/agl/agl-hostman/docs/analysis/log-analysis-queries.sh
ssh fgsrv5 'bash -s' < /mnt/overpower/apps/dev/agl/agl-hostman/docs/analysis/log-analysis-queries.sh

# Or copy and execute locally
scp /mnt/overpower/apps/dev/agl/agl-hostman/docs/analysis/log-analysis-queries.sh fgsrv3:/tmp/
ssh fgsrv3 "bash /tmp/log-analysis-queries.sh"
```

**Output structure:**
```
/tmp/log-analysis-YYYYMMDD-HHMMSS/
├── ANALYSIS_SUMMARY.txt          # Executive summary
├── cron-inventory.txt             # All cron jobs
├── cron-execution-history.txt     # Recent cron runs
├── cron-running-processes.txt     # Active cron processes
├── mysql-slow-queries.txt         # Slow query analysis
├── mysql-slow-recent.txt          # Recent slow queries
├── mysql-query-types.txt          # Query type distribution
├── mysql-processlist.txt          # Current connections
├── mysql-connections.txt          # Connection statistics
├── nginx-timeout-errors.txt       # Timeout-specific errors
├── nginx-error-types.txt          # Error categorization
├── nginx-5xx-errors.txt           # Server errors
├── nginx-upstream-errors.txt      # Backend failures
├── nginx-connection-errors.txt    # Connection issues
├── nginx-request-rate.txt         # Traffic patterns
├── nginx-status-codes.txt         # HTTP status distribution
├── nginx-top-ips.txt              # Top clients
├── nginx-top-urls.txt             # Most requested endpoints
├── nginx-slow-requests.txt        # Slow responses
├── nginx-4xx-errors.txt           # Client errors
├── nginx-5xx-access.txt           # 5xx from access log
├── phpfpm-max-children.txt        # Process pool warnings
├── phpfpm-memory-errors.txt       # Memory limit issues
├── phpfpm-timeouts.txt            # Script timeouts
├── phpfpm-slow-requests.txt       # Slow PHP execution
├── phpfpm-recent-errors.txt       # Recent PHP errors
├── system-resources.txt           # CPU/memory/disk snapshot
├── top-cpu-processes.txt          # CPU-intensive processes
├── top-mem-processes.txt          # Memory-intensive processes
├── network-status.txt             # Connection summary
├── syslog-critical.txt            # Critical system errors
├── syslog-oom.txt                 # Out of memory events
├── syslog-kernel.txt              # Kernel errors
└── syslog-services.txt            # Service failures
```

**Tarball:**
- Automatically created at `/tmp/log-analysis-HOSTNAME-YYYYMMDD-HHMMSS.tar.gz`
- Contains all analysis files
- Easy to download and share

---

## Investigation Workflow

### Phase 0: Preparation (15 minutes)
1. Read `diagnostic-framework.md` sections 1-6
2. Open `timeout-investigation-checklist.md` in editor
3. Copy `log-analysis-queries.sh` to all three hosts
4. Verify SSH access and tool availability

### Phase 1: Data Collection (2-4 hours)
1. Execute `log-analysis-queries.sh` on all hosts:
   ```bash
   for host in fgsrv3 fgsrv4 fgsrv5; do
     ssh $host 'bash /tmp/log-analysis-queries.sh'
   done
   ```

2. Download all tarballs to local analysis directory:
   ```bash
   mkdir -p /tmp/timeout-analysis-$(date +%Y%m%d)
   for host in fgsrv3 fgsrv4 fgsrv5; do
     scp $host:/tmp/log-analysis-*.tar.gz /tmp/timeout-analysis-$(date +%Y%m%d)/
   done
   ```

3. Extract and review summary reports:
   ```bash
   cd /tmp/timeout-analysis-$(date +%Y%m%d)
   for tarball in *.tar.gz; do
     mkdir ${tarball%.tar.gz}
     tar -xzf $tarball -C ${tarball%.tar.gz}
     cat ${tarball%.tar.gz}/ANALYSIS_SUMMARY.txt
   done
   ```

4. Check off Phase 1 tasks in checklist

### Phase 2: Pattern Analysis (4-8 hours)
1. Review all summary reports across hosts
2. Identify common error patterns
3. Build timeline of events
4. Correlate cron jobs with timeouts
5. Analyze MySQL slow queries
6. Document nginx error spikes
7. Check PHP-FPM process saturation
8. Update checklist Phase 2-7 tasks

### Phase 3: Hypothesis Formation (2-4 hours)
1. Use correlation matrix in checklist
2. Rank potential causes by evidence strength
3. Formulate top 3 hypotheses
4. Design tests for each hypothesis
5. Update checklist Phase 8 tasks

### Phase 4: Testing & Confirmation (8-24 hours)
1. Execute controlled tests
2. Monitor for timeout reproduction
3. Confirm or refute hypotheses
4. Document root cause with evidence
5. Complete checklist Phase 9 tasks

### Phase 5: Resolution & Documentation (4-8 hours)
1. Implement immediate fixes
2. Plan short and long-term improvements
3. Set up monitoring and alerting
4. Document lessons learned
5. Finalize checklist Phase 10 tasks

---

## Quick Start Commands

### Check Host Connectivity
```bash
for host in fgsrv3 fgsrv4 fgsrv5; do
  echo "=== $host ==="
  ping -c 3 $host
  ssh $host "uptime && free -h"
done
```

### Deploy Analysis Script
```bash
for host in fgsrv3 fgsrv4 fgsrv5; do
  scp /mnt/overpower/apps/dev/agl/agl-hostman/docs/analysis/log-analysis-queries.sh $host:/tmp/
  ssh $host "chmod +x /tmp/log-analysis-queries.sh"
done
```

### Run Analysis on All Hosts (Parallel)
```bash
for host in fgsrv3 fgsrv4 fgsrv5; do
  ssh $host 'bash /tmp/log-analysis-queries.sh' &
done
wait
echo "All analyses complete"
```

### Collect Results
```bash
ANALYSIS_DIR="/tmp/timeout-analysis-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$ANALYSIS_DIR"

for host in fgsrv3 fgsrv4 fgsrv5; do
  # Get latest tarball
  LATEST=$(ssh $host "ls -t /tmp/log-analysis-*.tar.gz 2>/dev/null | head -1")
  if [ -n "$LATEST" ]; then
    scp "$host:$LATEST" "$ANALYSIS_DIR/${host}-analysis.tar.gz"

    # Extract
    mkdir -p "$ANALYSIS_DIR/$host"
    tar -xzf "$ANALYSIS_DIR/${host}-analysis.tar.gz" -C "$ANALYSIS_DIR/$host"

    # Show summary
    echo "=== $host Summary ==="
    cat "$ANALYSIS_DIR/$host/ANALYSIS_SUMMARY.txt"
    echo ""
  fi
done

echo "All results collected in: $ANALYSIS_DIR"
```

### Real-Time Monitoring During Timeout
```bash
# Run this when timeout is occurring

# On fgsrv3 (MySQL)
ssh fgsrv3 "mysql -e 'SHOW FULL PROCESSLIST;' && ps aux | grep mysql"

# On fgsrv4 (nginx/PHP5)
ssh fgsrv4 "tail -50 /var/log/nginx/error.log && systemctl status php*-fpm"

# On fgsrv5 (Laravel)
ssh fgsrv5 "tail -50 /var/log/nginx/error.log && tail -50 /var/www/*/storage/logs/laravel.log"
```

---

## Hive Mind Coordination

### Memory Keys for Worker Coordination
```bash
# Store baseline metrics
npx claude-flow@alpha memory store \
  --key "hive/analyst/baseline-collected" \
  --value "$(date -Iseconds)"

# Store analysis results
for host in fgsrv3 fgsrv4 fgsrv5; do
  npx claude-flow@alpha memory store \
    --key "hive/analyst/${host}/summary" \
    --value "$(cat /tmp/timeout-analysis-*/${host}/ANALYSIS_SUMMARY.txt)"
done

# Store correlations
npx claude-flow@alpha memory store \
  --key "hive/analyst/correlation-matrix" \
  --value "$(cat /tmp/correlation-findings.txt)"

# Store hypotheses
npx claude-flow@alpha memory store \
  --key "hive/analyst/hypotheses" \
  --value "$(cat /tmp/working-hypotheses.txt)"

# Store root cause (once confirmed)
npx claude-flow@alpha memory store \
  --key "hive/analyst/root-cause-confirmed" \
  --value "$(cat /tmp/root-cause-report.txt)"
```

### Retrieve Shared Knowledge
```bash
# Check what other workers have found
npx claude-flow@alpha memory retrieve --key "hive/analyst/baseline-collected"
npx claude-flow@alpha memory retrieve --key "hive/analyst/mysql-slow-queries"
npx claude-flow@alpha memory retrieve --key "hive/analyst/nginx-error-patterns"
```

### Notify Workers
```bash
# Alert when analysis completes
npx claude-flow@alpha hooks notify \
  --message "Log analysis complete for fgsrv3/4/5. Results in hive/analyst/*/summary"

# Signal root cause found
npx claude-flow@alpha hooks notify \
  --message "ROOT CAUSE CONFIRMED: [brief description]. See hive/analyst/root-cause-confirmed"
```

---

## Expected Deliverables

### Intermediate Deliverables (During Investigation)
1. **Baseline Metrics Report** (Phase 1)
   - System resource snapshots from all hosts
   - Service status and configuration
   - Network connectivity baselines

2. **Log Analysis Report** (Phase 2)
   - Parsed and categorized logs
   - Error pattern identification
   - Timeline of events

3. **Correlation Analysis** (Phase 3)
   - Event correlation matrix
   - Pattern identification
   - Working hypotheses

### Final Deliverables (End of Investigation)
1. **Root Cause Analysis Report**
   - Executive summary
   - Detailed timeline
   - Evidence and correlation data
   - Root cause statement with confidence level
   - Impact assessment

2. **Remediation Plan**
   - Immediate fixes (24 hours)
   - Short-term improvements (1 week)
   - Long-term solutions (1 month)
   - Monitoring and alerting strategy

3. **Runbook and Documentation**
   - Step-by-step troubleshooting guide
   - Monitoring dashboard specifications
   - Alert thresholds and escalation procedures
   - Lessons learned

4. **Knowledge Base Article**
   - Problem description
   - Root cause explanation
   - Solution implementation
   - Prevention measures

---

## Tools and Dependencies

### Required on All Hosts
```bash
# Check tool availability
for tool in mysql mysqldumpslow awk sed grep tail head sort uniq wc ps top free df iostat ss netstat lsof; do
  command -v $tool >/dev/null 2>&1 && echo "✓ $tool" || echo "✗ $tool (missing)"
done
```

### Optional (Enhanced Analysis)
```bash
apt-get install -y \
  sysstat \        # sar, iostat, mpstat
  iotop \          # I/O monitoring
  htop \           # Better top
  atop \           # Advanced system monitor
  mtr \            # Network diagnostics
  percona-toolkit  # pt-query-digest for MySQL
```

---

## Troubleshooting the Framework

### Script Fails to Run
```bash
# Check permissions
ls -l /tmp/log-analysis-queries.sh
chmod +x /tmp/log-analysis-queries.sh

# Check shell compatibility
bash -n /tmp/log-analysis-queries.sh  # Syntax check

# Run with debugging
bash -x /tmp/log-analysis-queries.sh 2>&1 | tee debug.log
```

### Missing Log Files
```bash
# Find nginx logs
find /var/log -name "*nginx*" -type f

# Find PHP-FPM logs
find /var/log -name "*php*fpm*" -type f

# Find MySQL logs
mysql -e "SHOW VARIABLES LIKE '%log%';"
```

### Insufficient Permissions
```bash
# Run script as root or with sudo
sudo bash /tmp/log-analysis-queries.sh

# Or fix permissions on specific logs
sudo chmod 644 /var/log/nginx/*.log
sudo chmod 644 /var/log/mysql/*.log
```

---

## Contact and Support

**Primary Analyst:** Hive Mind Analyst Agent
**Coordination:** Shared memory namespace `hive/analyst/*`
**Status Updates:** Via `npx claude-flow@alpha hooks notify`
**Documentation:** `/mnt/overpower/apps/dev/agl/agl-hostman/docs/analysis/`

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-22 | Analyst Agent | Initial framework creation |

---

## Next Steps

1. **Immediate:** Review this README and framework documents
2. **Within 1 hour:** Deploy scripts to all hosts
3. **Within 2 hours:** Execute first round of data collection
4. **Within 4 hours:** Begin correlation analysis
5. **Within 24 hours:** Formulate initial hypotheses
6. **Within 48 hours:** Complete root cause analysis

**Status:** Framework ready for deployment ✅

---

*Last updated: 2025-10-22*
*Framework version: 1.0*
*Hive Mind coordination: ACTIVE*

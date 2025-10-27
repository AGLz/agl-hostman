# Network Diagnostics Testing Suite

## Overview

Comprehensive network performance testing to identify latency, bandwidth saturation, packet loss, and connectivity issues that may contribute to timeout conditions.

## Test Scenarios

### NT-001: Network Latency Baseline

**Objective:** Establish baseline network latency for critical paths

**Test Steps:**
```bash
# 1. Create network latency monitoring script
cat > /tmp/network-latency-baseline.sh << 'EOF'
#!/bin/bash

echo "Network Latency Baseline Measurement"
echo "===================================="
echo "Timestamp: $(date)"
echo ""

# Define test targets
TARGETS=(
    "8.8.8.8|Google DNS"
    "1.1.1.1|Cloudflare DNS"
    "localhost|Localhost"
    # Add your upstream servers, CDN endpoints, etc.
)

echo "=== ICMP Ping Tests ==="
for TARGET in "${TARGETS[@]}"; do
    IP="${TARGET%%|*}"
    NAME="${TARGET##*|}"

    echo -e "\nTarget: $NAME ($IP)"
    ping -c 10 -i 0.2 $IP | grep -E "(rtt|transmitted)"
done

echo -e "\n=== TCP Connection Tests ==="
# Test HTTP/HTTPS latency
for URL in "http://localhost" "https://www.google.com"; do
    echo -e "\nTesting: $URL"
    curl -w "DNS: %{time_namelookup}s\nConnect: %{time_connect}s\nTTFB: %{time_starttransfer}s\nTotal: %{time_total}s\n" \
        -o /dev/null -s "$URL"
done

echo -e "\n=== Traceroute Analysis ==="
# Identify network hops to key destinations
for TARGET in "8.8.8.8" "1.1.1.1"; do
    echo -e "\nTraceroute to $TARGET:"
    traceroute -n -m 15 $TARGET 2>&1 | head -20
done

echo -e "\n=== MTR (Combined Ping/Traceroute) ==="
# More detailed path analysis
mtr -r -c 10 8.8.8.8

EOF

chmod +x /tmp/network-latency-baseline.sh
/tmp/network-latency-baseline.sh > /tmp/network-latency-baseline.txt

cat /tmp/network-latency-baseline.txt
```

**Success Criteria:**
- Localhost latency <1ms
- External DNS latency <50ms
- No packet loss to stable targets
- Consistent latency (low jitter)

**Failure Indicators:**
- Packet loss >1%
- Latency spikes >200ms
- High jitter (stddev >20ms)
- Intermittent connectivity

**Remediation Actions:**
1. Investigate network path issues
2. Check for bandwidth saturation
3. Verify DNS resolver performance
4. Contact hosting provider for network issues

---

### NT-002: Bandwidth Saturation Detection

**Objective:** Identify network bandwidth limits and saturation conditions

**Test Steps:**
```bash
# 1. Check current network interface statistics
ip -s link show

# 2. Monitor real-time bandwidth usage
cat > /tmp/bandwidth-monitor.sh << 'EOF'
#!/bin/bash

DURATION=300  # 5 minutes
INTERVAL=5

echo "Network Bandwidth Monitoring"
echo "============================"
echo "Duration: ${DURATION}s, Interval: ${INTERVAL}s"
echo "Interface,Timestamp,RX_bytes,TX_bytes,RX_packets,TX_packets" > /tmp/bandwidth-data.csv

END_TIME=$(($(date +%s) + DURATION))

while [ $(date +%s) -lt $END_TIME ]; do
    for IFACE in $(ip -o link show | awk -F': ' '{print $2}' | grep -v lo); do
        STATS=$(ip -s link show $IFACE | grep -A 1 "RX:" | tail -1)
        RX_BYTES=$(echo $STATS | awk '{print $1}')
        RX_PACKETS=$(echo $STATS | awk '{print $2}')

        STATS=$(ip -s link show $IFACE | grep -A 1 "TX:" | tail -1)
        TX_BYTES=$(echo $STATS | awk '{print $1}')
        TX_PACKETS=$(echo $STATS | awk '{print $2}')

        echo "$IFACE,$(date +%s),$RX_BYTES,$TX_BYTES,$RX_PACKETS,$TX_PACKETS" >> /tmp/bandwidth-data.csv
    done

    sleep $INTERVAL
done

echo "Monitoring complete. Analyzing data..."

# Calculate bandwidth usage
python3 << 'PYTHON'
import csv
from collections import defaultdict

interface_data = defaultdict(list)

with open('/tmp/bandwidth-data.csv', 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        interface_data[row['Interface']].append({
            'timestamp': int(row['Timestamp']),
            'rx_bytes': int(row['RX_bytes']),
            'tx_bytes': int(row['TX_bytes'])
        })

print("\n=== Bandwidth Usage Analysis ===")
for iface, data in interface_data.items():
    if len(data) < 2:
        continue

    total_rx = data[-1]['rx_bytes'] - data[0]['rx_bytes']
    total_tx = data[-1]['tx_bytes'] - data[0]['tx_bytes']
    duration = data[-1]['timestamp'] - data[0]['timestamp']

    rx_mbps = (total_rx * 8) / (duration * 1000000)
    tx_mbps = (total_tx * 8) / (duration * 1000000)

    print(f"\nInterface: {iface}")
    print(f"  RX: {rx_mbps:.2f} Mbps ({total_rx / 1024 / 1024:.2f} MB)")
    print(f"  TX: {tx_mbps:.2f} Mbps ({total_tx / 1024 / 1024:.2f} MB)")

    # Calculate peak usage (between intervals)
    max_rx_rate = 0
    max_tx_rate = 0

    for i in range(1, len(data)):
        interval_rx = (data[i]['rx_bytes'] - data[i-1]['rx_bytes']) * 8 / 5 / 1000000
        interval_tx = (data[i]['tx_bytes'] - data[i-1]['tx_bytes']) * 8 / 5 / 1000000

        max_rx_rate = max(max_rx_rate, interval_rx)
        max_tx_rate = max(max_tx_rate, interval_tx)

    print(f"  Peak RX: {max_rx_rate:.2f} Mbps")
    print(f"  Peak TX: {max_tx_rate:.2f} Mbps")
PYTHON

EOF

chmod +x /tmp/bandwidth-monitor.sh

# 3. Run baseline monitoring
/tmp/bandwidth-monitor.sh &
MONITOR_PID=$!

# 4. Generate network load (optional, for stress testing)
# Uncomment to test bandwidth limits:
# wget -O /dev/null http://speedtest.tele2.net/100MB.zip &

sleep 300  # Let monitoring complete
wait $MONITOR_PID

# 5. Check for dropped packets
netstat -i | grep -v "Iface\|lo"

# 6. Monitor network errors
cat /proc/net/dev | grep -v "Inter-|face" | awk '{print $1, "RX errors:", $4, "TX errors:", $12}'
```

**Success Criteria:**
- Bandwidth usage <70% of capacity
- No dropped packets
- No network interface errors
- Consistent throughput

**Failure Indicators:**
- Bandwidth usage consistently >90%
- Increasing dropped packets
- RX/TX errors accumulating
- Intermittent connectivity during high load

**Remediation Actions:**
1. Implement traffic shaping/QoS
2. Upgrade network capacity
3. Identify and throttle bandwidth-intensive processes
4. Optimize application to reduce bandwidth usage

---

### NT-003: DNS Resolution Performance

**Objective:** Measure DNS lookup times and identify resolution issues

**Test Steps:**
```bash
# 1. Test DNS resolution performance
cat > /tmp/dns-performance-test.sh << 'EOF'
#!/bin/bash

echo "DNS Resolution Performance Test"
echo "==============================="
echo ""

# Test domains (mix of local and external)
DOMAINS=(
    "localhost"
    "google.com"
    "cloudflare.com"
    # Add your application's external dependencies
)

# Test resolvers
RESOLVERS=(
    "127.0.0.1|Local"
    "8.8.8.8|Google"
    "1.1.1.1|Cloudflare"
    "208.67.222.222|OpenDNS"
)

for RESOLVER in "${RESOLVERS[@]}"; do
    IP="${RESOLVER%%|*}"
    NAME="${RESOLVER##*|}"

    echo "=== Testing Resolver: $NAME ($IP) ==="

    for DOMAIN in "${DOMAINS[@]}"; do
        echo -e "\nDomain: $DOMAIN"

        # Time the DNS lookup
        START=$(date +%s%N)
        dig @$IP $DOMAIN +short > /dev/null 2>&1
        END=$(date +%s%N)
        DURATION=$(( (END - START) / 1000000 ))

        echo "  Lookup time: ${DURATION}ms"

        # Detailed query
        dig @$IP $DOMAIN | grep "Query time"
    done

    echo ""
done

# Check /etc/resolv.conf configuration
echo "=== Current DNS Configuration ==="
cat /etc/resolv.conf

# Test DNS cache hit rate (if using nscd or systemd-resolved)
if systemctl is-active --quiet systemd-resolved; then
    echo -e "\n=== systemd-resolved Statistics ==="
    resolvectl statistics
fi

EOF

chmod +x /tmp/dns-performance-test.sh
/tmp/dns-performance-test.sh

# 2. Monitor DNS queries during application load
sudo tcpdump -i any -n port 53 -c 100 > /tmp/dns-queries.txt 2>&1 &
TCPDUMP_PID=$!

# Generate application load
ab -n 1000 -c 50 http://localhost/

# Stop packet capture
sleep 10
sudo kill $TCPDUMP_PID 2>/dev/null

# Analyze DNS query patterns
echo "=== DNS Query Analysis ==="
grep "query" /tmp/dns-queries.txt | awk '{print $NF}' | sort | uniq -c | sort -rn
```

**Success Criteria:**
- DNS lookup time <50ms
- High cache hit rate (>80%)
- No DNS timeout errors
- Consistent resolution times

**Failure Indicators:**
- Lookup times >200ms
- Frequent DNS failures
- Low cache hit rate
- Queries to unexpected domains (DNS leak)

**Remediation Actions:**
1. Configure local DNS caching (dnsmasq, systemd-resolved)
2. Switch to faster DNS resolvers
3. Implement application-level DNS caching
4. Reduce DNS query volume (connection pooling)

---

### NT-004: Connection Timeout Detection

**Objective:** Identify TCP connection timeout issues

**Test Steps:**
```bash
# 1. Monitor TCP connection states
cat > /tmp/tcp-connection-monitor.sh << 'EOF'
#!/bin/bash

echo "TCP Connection State Monitoring"
echo "==============================="
echo ""

# Monitor connection states over time
DURATION=300
INTERVAL=10

echo "Timestamp,ESTABLISHED,TIME_WAIT,CLOSE_WAIT,SYN_SENT,SYN_RECV,FIN_WAIT1,FIN_WAIT2,CLOSING,LAST_ACK" > /tmp/tcp-states.csv

END_TIME=$(($(date +%s) + DURATION))

while [ $(date +%s) -lt $END_TIME ]; do
    TIMESTAMP=$(date +%s)

    # Count connections by state
    ESTABLISHED=$(ss -tan | grep ESTAB | wc -l)
    TIME_WAIT=$(ss -tan | grep TIME-WAIT | wc -l)
    CLOSE_WAIT=$(ss -tan | grep CLOSE-WAIT | wc -l)
    SYN_SENT=$(ss -tan | grep SYN-SENT | wc -l)
    SYN_RECV=$(ss -tan | grep SYN-RECV | wc -l)
    FIN_WAIT1=$(ss -tan | grep FIN-WAIT-1 | wc -l)
    FIN_WAIT2=$(ss -tan | grep FIN-WAIT-2 | wc -l)
    CLOSING=$(ss -tan | grep CLOSING | wc -l)
    LAST_ACK=$(ss -tan | grep LAST-ACK | wc -l)

    echo "$TIMESTAMP,$ESTABLISHED,$TIME_WAIT,$CLOSE_WAIT,$SYN_SENT,$SYN_RECV,$FIN_WAIT1,$FIN_WAIT2,$CLOSING,$LAST_ACK" >> /tmp/tcp-states.csv

    sleep $INTERVAL
done

echo "Monitoring complete. Summary:"
echo ""
echo "=== Connection State Statistics ==="
cat /tmp/tcp-states.csv | awk -F',' '
    NR>1 {
        established+=$2;
        time_wait+=$3;
        close_wait+=$4;
        count++
    }
    END {
        print "Average ESTABLISHED:", established/count;
        print "Average TIME_WAIT:", time_wait/count;
        print "Average CLOSE_WAIT:", close_wait/count;
    }
'

EOF

chmod +x /tmp/tcp-connection-monitor.sh

# 2. Generate application load while monitoring
/tmp/tcp-connection-monitor.sh &
MONITOR_PID=$!

ab -n 10000 -c 100 http://localhost/

wait $MONITOR_PID

# 3. Check for connection timeouts in logs
echo -e "\n=== Connection Timeout Errors ==="
sudo grep -i "timeout\|timed out" /var/log/nginx/error.log | tail -20
sudo grep -i "timeout\|timed out" /var/log/php*-fpm.log | tail -20

# 4. Check TCP retransmissions and failures
echo -e "\n=== TCP Statistics ==="
ss -s

echo -e "\n=== TCP Retransmission Rate ==="
netstat -s | grep -iE "segment|retransmit"

# 5. Test specific endpoint timeout behavior
cat > /tmp/connection-timeout-test.sh << 'EOF'
#!/bin/bash

echo "Connection Timeout Behavior Test"
echo "================================="

# Test with different timeout values
for TIMEOUT in 1 5 10 30 60; do
    echo -e "\nTesting with ${TIMEOUT}s timeout:"

    START=$(date +%s%N)
    curl --connect-timeout $TIMEOUT --max-time $(($TIMEOUT + 5)) \
        -w "\nHTTP Code: %{http_code}\nConnect time: %{time_connect}s\nTotal time: %{time_total}s\n" \
        -o /dev/null -s http://localhost/
    END=$(date +%s%N)

    ACTUAL_TIME=$(( (END - START) / 1000000000 ))
    echo "Actual time: ${ACTUAL_TIME}s"
done

EOF

chmod +x /tmp/connection-timeout-test.sh
/tmp/connection-timeout-test.sh
```

**Success Criteria:**
- No SYN retransmissions
- CLOSE_WAIT connections cleaned up quickly
- Retransmission rate <1%
- Connections complete within timeout

**Failure Indicators:**
- Accumulating CLOSE_WAIT connections
- High SYN_SENT (connection attempts failing)
- Retransmission rate >5%
- Frequent connection timeouts

**Remediation Actions:**
1. Tune TCP keepalive settings
2. Adjust application timeout values
3. Implement connection pooling
4. Check for network path MTU issues
5. Investigate application-level connection leaks

---

### NT-005: Firewall and Packet Filtering Impact

**Objective:** Identify firewall rules causing connection issues

**Test Steps:**
```bash
# 1. Review current firewall configuration
sudo iptables -L -n -v --line-numbers
sudo ip6tables -L -n -v --line-numbers

# 2. Check for packet drops
cat > /tmp/firewall-impact-test.sh << 'EOF'
#!/bin/bash

echo "Firewall Packet Drop Analysis"
echo "============================="
echo ""

# Capture initial packet counts
echo "=== Initial iptables Counters ==="
sudo iptables -L -n -v | grep -E "(Chain|pkts)"

# Generate test traffic
echo -e "\n=== Generating Test Traffic ==="
ab -n 5000 -c 50 http://localhost/ > /dev/null 2>&1

# Check final packet counts
echo -e "\n=== Final iptables Counters ==="
sudo iptables -L -n -v | grep -E "(Chain|pkts)"

# Identify DROP/REJECT rules with hits
echo -e "\n=== Rules with Drops/Rejects ==="
sudo iptables -L -n -v | grep -E "(DROP|REJECT)" | grep -v "0     0"

# Check conntrack table utilization
echo -e "\n=== Connection Tracking Status ==="
sudo cat /proc/sys/net/netfilter/nf_conntrack_count
sudo cat /proc/sys/net/netfilter/nf_conntrack_max

USAGE=$(sudo cat /proc/sys/net/netfilter/nf_conntrack_count)
MAX=$(sudo cat /proc/sys/net/netfilter/nf_conntrack_max)
PCT=$(( USAGE * 100 / MAX ))

echo "Connection tracking usage: $PCT% ($USAGE / $MAX)"

if [ $PCT -gt 80 ]; then
    echo "⚠️  WARNING: Connection tracking table near capacity!"
fi

# Check for conntrack errors
echo -e "\n=== Conntrack Errors ==="
dmesg | grep -i "conntrack" | tail -20

EOF

chmod +x /tmp/firewall-impact-test.sh
sudo /tmp/firewall-impact-test.sh

# 3. Test with firewall temporarily disabled (CAUTION!)
# Only run in controlled environment
# sudo iptables -P INPUT ACCEPT
# sudo iptables -P FORWARD ACCEPT
# sudo iptables -P OUTPUT ACCEPT
# sudo iptables -F
# ab -n 1000 -c 50 http://localhost/
# Then restore firewall rules

# 4. Monitor for rate limiting impacts
sudo iptables -L -n -v | grep -i limit
```

**Success Criteria:**
- No unexpected packet drops
- Conntrack table usage <80%
- No rate limit triggering on legitimate traffic
- Firewall rules optimized (specific, not broad)

**Failure Indicators:**
- Packet drops on legitimate traffic
- Conntrack table at capacity
- Rate limiting during normal operations
- Overly broad DROP rules

**Remediation Actions:**
1. Increase nf_conntrack_max if needed
2. Optimize firewall rules (remove redundant rules)
3. Implement connection tracking timeout tuning
4. Use connection limit instead of rate limit where appropriate
5. Whitelist known good IPs/networks

---

### NT-006: Network Monitoring During Backup Window

**Objective:** Correlate network usage with backup operations

**Test Steps:**
```bash
# 1. Create comprehensive network monitoring script
cat > /tmp/backup-window-network-monitor.sh << 'EOF'
#!/bin/bash

echo "Backup Window Network Monitoring"
echo "================================"
echo "Start time: $(date)"
echo ""

# Create monitoring directory
MONITOR_DIR="/tmp/backup-network-monitor-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$MONITOR_DIR"

# Start packet capture (limited size)
echo "Starting packet capture..."
sudo tcpdump -i any -w "$MONITOR_DIR/packets.pcap" -C 100 -W 5 &
TCPDUMP_PID=$!

# Monitor bandwidth usage
echo "Starting bandwidth monitor..."
iftop -t -s 60 > "$MONITOR_DIR/iftop.log" 2>&1 &
IFTOP_PID=$!

# Monitor connections
echo "Monitoring connections..."
while true; do
    echo "$(date +%s),$(ss -tan | wc -l)" >> "$MONITOR_DIR/connection-count.csv"
    sleep 5
done &
CONN_PID=$!

# Wait for backup to complete or timeout
echo "Monitoring for 30 minutes or until stopped..."
sleep 1800

# Stop monitoring
echo "Stopping monitors..."
sudo kill $TCPDUMP_PID $IFTOP_PID $CONN_PID 2>/dev/null

# Analyze results
echo -e "\n=== Analysis Results ==="

echo -e "\n Top Network Conversations:"
sudo tcpdump -r "$MONITOR_DIR/packets.pcap" -n | \
    awk '{print $3, $5}' | \
    sort | uniq -c | sort -rn | head -20

echo -e "\n Connection Count Over Time:"
cat "$MONITOR_DIR/connection-count.csv" | \
    awk -F',' '{sum+=$2; count++} END {print "Average connections:", sum/count}'

echo -e "\nResults saved to: $MONITOR_DIR"

EOF

chmod +x /tmp/backup-window-network-monitor.sh

# 2. Schedule to run during backup window
# Or run manually:
sudo /tmp/backup-window-network-monitor.sh

# 3. Compare with normal operation network profile
diff /tmp/network-latency-baseline.txt /tmp/backup-network-monitor-*/analysis.txt
```

**Success Criteria:**
- Network latency increase <50ms during backup
- No packet loss during backup transfer
- Bandwidth usage <80% of capacity
- Application traffic not significantly impacted

**Failure Indicators:**
- Latency spikes >200ms during backup
- Packet loss >1%
- Bandwidth saturation
- Connection timeouts during backup window

**Remediation Actions:**
1. Implement QoS to prioritize application traffic
2. Schedule backups during off-peak hours
3. Throttle backup transfer rate (rsync --bwlimit)
4. Use dedicated backup network interface
5. Implement incremental/differential backups

---

## Automated Test Suite

```bash
#!/bin/bash
# Network diagnostics test suite runner

TESTS_DIR="/mnt/overpower/apps/dev/agl/agl-hostman/tests/vps-timeout-testing"
RESULTS_DIR="${TESTS_DIR}/results/network-tests-$(date +%Y%m%d_%H%M%S)"

mkdir -p "$RESULTS_DIR"

echo "Starting Network Diagnostics Test Suite - $(date)"
echo "Results directory: $RESULTS_DIR"

# Run tests sequentially
TESTS=("NT-001" "NT-002" "NT-003" "NT-004" "NT-005" "NT-006")

for TEST in "${TESTS[@]}"; do
    echo "====================================="
    echo "Running Test: $TEST"
    echo "====================================="

    # Test execution logic
    # (Implementation details here)

    echo "$TEST completed at $(date)" | tee -a "$RESULTS_DIR/execution.log"

    sleep 30  # Cooldown
done

echo "Network diagnostics suite completed - $(date)"
echo "Review results in: $RESULTS_DIR"
```

---

**Version:** 1.0
**Last Updated:** 2025-10-22
**Test Count:** 6 comprehensive network scenarios
**Estimated Duration:** 3-5 hours

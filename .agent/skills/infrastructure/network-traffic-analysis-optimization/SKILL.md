---
name: network-traffic-analysis-optimization
description: "Network traffic monitoring, bandwidth optimization, traffic shaping, and performance analysis using tcpdump, ntopng, and Netdata for Proxmox and Docker networks. Use when diagnosing network issues, optimizing bandwidth, or implementing traffic policies."
category: infrastructure
priority: P2
tags: [network, monitoring, bandwidth, optimization, tcpdump]
---

# Network Traffic Analysis & Optimization

## Overview

This skill provides comprehensive network traffic monitoring, analysis, and optimization capabilities for the AGL infrastructure. It covers packet capture, bandwidth monitoring, protocol analysis, bottleneck identification, traffic shaping (QoS), DNS optimization, and TCP tuning for Proxmox hosts, LXC containers, and Docker networks.

### Network Architecture Context

```
                    AGL Infrastructure Network Stack

    WireGuard Mesh (10.6.0.0/24)         LAN (192.168.0.0/24)         Tailscale (100.x.x.x)
           Primary                          Secondary                     Fallback
    ┌─────────────────────┐         ┌─────────────────────┐         ┌─────────────────────┐
    │    FGSRV6 (Hub)     │         │   AGLSRV1 (HQ)      │         │  All Remote Nodes   │
    │    10.6.0.5         │────────▶│   192.168.0.245     │────────▶│   100.x.x.x         │
    │    :51823/UDP       │         │   :22, :8006        │         │   :41641 (TS)       │
    └─────────────────────┘         └─────────────────────┘         └─────────────────────┘
             │                                │                                │
             └────────────────────────────────┴────────────────────────────────┘
                                      AGL Network Mesh
```

### Key Monitoring Points

| Location | Interface | Purpose | Tools |
|----------|-----------|---------|-------|
| **FGSRV6** | wg0, vmbr0 | Hub traffic, VPN routing | tcpdump, ntopng, Netdata |
| **AGLSRV1** | wg0, vmbr0 | HQ routing, NFS storage | vnstat, iftop |
| **AGLSRV6** | wg0, vmbr0 | Remote storage routing | iperf3, mtr |
| **CT111** | eth0, wg0 | NFS server monitoring | nfsstat, iostat |
| **CT183** | eth0, wg0 | Archon AI traffic | docker stats |

---

## Traffic Capture & Analysis

### Packet Capture with tcpdump

tcpdump is the primary tool for capturing and analyzing network packets at the packet level.

#### Basic Capture Commands

```bash
# Capture all packets on WireGuard interface
tcpdump -i wg0 -w /tmp/wg0-capture.pcap

# Capture with verbose output
tcpdump -i wg0 -v -n

# Capture specific number of packets
tcpdump -i wg0 -c 1000

# Capture in ASCII mode (for HTTP headers)
tcpdump -i wg0 -A -n

# Capture with timestamps
tcpdump -i wg0 -t -n
```

#### Filtered Captures

```bash
# Capture specific host traffic
tcpdump -i wg0 host 10.6.0.5

# Capture specific port
tcpdump -i wg0 port 2049  # NFS
tcpdump -i wg0 port 51823 # WireGuard
tcpdump -i wg0 port 8006  # Proxmox API

# Capture TCP or UDP
tcpdump -i wg0 tcp
tcpdump -i wg0 udp

# Capture specific network
tcpdump -i wg0 net 10.6.0.0/24

# Exclude traffic (NOT)
tcpdump -i wg0 not port 22

# Complex filters
tcpdump -i wg0 "(tcp port 2049 or 2049) and host 10.6.0.20"

# Capture NFS traffic analysis
tcpdump -i wg0 -w nfs-trace.pcap port 2049 -s 0

# Capture WireGuard handshake
tcpdump -i wg0 -w wg-handshake.pcap udp port 51823
```

#### Advanced Capture Options

```bash
# Capture full packets (don't truncate)
tcpdump -i wg0 -s 0 -w full-packets.pcap

# Rotate capture files (every 100MB, max 5 files)
tcpdump -i wg0 -C 100 -W 5 -w rotating-capture.pcap

# Capture with ring buffer
tcpdump -i wg0 -C 50 -W 10 -w /tmp/capture-%Y%m%d-%H%M%S.pcap

# Capture from multiple interfaces
tcpdump -i wg0 -i eth0 -w multi-interface.pcap

# Capture with buffer size increase
tcpdump -i wg0 -B 4096 -w high-buffer.pcap
```

#### Real-Time Traffic Analysis

```bash
# Display packet summary in real-time
tcpdump -i wg0 -n -t

# Count packets by type
tcpdump -i wg0 -n | awk '{print $1}' | sort | uniq -c

# Monitor bandwidth usage in real-time
tcpdump -i wg0 -n | awk '{print $5}' | cut -d'.' -f1-3 | sort | uniq -c

# Track top talkers
tcpdump -i wg0 -n | awk '{print $3}' | cut -d'.' -f1-3 | sort | uniq -c | sort -rn | head -10
```

### Wireshark Integration

```bash
# Capture for Wireshark analysis
tcpdump -i wg0 -w /tmp/analysis-$(date +%Y%m%d-%H%M%S).pcap

# Remote capture with Wireshark
ssh root@10.6.0.5 "tcpdump -i wg0 -U -w -" | wireshark -k -i -

# Filter capture for specific protocol
tcpdump -i wg0 -y 'ipv4' -w filtered.pcap
```

---

## Bandwidth Monitoring

### Real-Time Bandwidth Tools

#### iftop (Interactive Bandwidth Monitor)

```bash
# Monitor WireGuard interface
iftop -i wg0

# Show specific host pairs
iftop -i wg0 -f "host 10.6.0.20"

# Display in different formats
iftop -i wg0 -n  # Don't resolve hostnames
iftop -i wg0 -P  # Show port numbers
iftop -i wg0 -B  # Display in bytes/sec

# Custom display
iftop -i wg0 -nPB -f "port 2049"
```

#### bmon (Bandwidth Monitor)

```bash
# Monitor all interfaces
bmon

# Monitor specific interface
bmon -p wg0

# Output as HTML
bmon -o html:path=/var/www/html/bmon

# ASCII output for scripts
bmon -o ascii -p wg0
```

#### nload (Network Load Monitor)

```bash
# Simple bandwidth display
nload wg0

# Show multiple interfaces
nload -m

# Update interval (milliseconds)
nload -t 500 wg0
```

### Historical Bandwidth Data

#### vnstat (Network Traffic Logger)

```bash
# Install vnstat
apt install vnstat

# Initialize database for interface
vnstat -i wg0 --create

# Real-time traffic
vnstat -l -i wg0

# Daily statistics
vnstat -d -i wg0

# Monthly statistics
vnstat -m -i wg0

# Hourly statistics
vnstat -h -i wg0

# Top days
vnstat -t -i wg0

# Live traffic in terminal
vnstat -l -i wg0 --style 0
```

#### Custom vnstat Setup

```bash
# /etc/vnstat.conf
Interface "wg0"
# WireGuard VPN traffic

Interface "vmbr0"
# Physical bridge traffic

Interface "docker0"
# Docker container traffic
```

### Netdata Integration

```bash
# Install Netdata
bash <(curl -Ss https://my-netdata.io/kickstart.sh)

# Access web dashboard
http://10.6.0.5:19999

# Network metrics available:
# - Interface bandwidth (rx/tx)
# - Packet rates
# - Error rates
# - Connection tracking
# - TCP/UDP statistics

# Configure Netdata for custom interfaces
# /etc/netdata/netdata.conf
[plugin:proc:net]
  # Netclass network interfaces
  # WireGuard, physical, Docker, etc.
```

### Docker Network Monitoring

```bash
# Container network stats
docker stats

# Specific container stats
docker stats ct111-archon

# Stream stats (non-interactive)
docker stats --no-stream

# Get network metrics for all containers
for container in $(docker ps -q); do
    name=$(docker inspect --format '{{.Name}}' $container)
    echo "Container: $name"
    docker exec $container cat /proc/net/dev | grep eth
done
```

---

## Protocol Analysis

### Protocol Breakdown by Port

```bash
# Analyze protocols on WireGuard
tcpdump -i wg0 -n | awk '{print $1}' | sort | uniq -c

# Count by protocol type
tcpdump -i wg0 -n | \
    awk '{for(i=1;i<=NF;i++) if($i ~ /TCP|UDP/) print $i}' | \
    sort | uniq -c

# Top ports by traffic
tcpdump -i wg0 -n -c 10000 | \
    awk -F'[ .:]' '{print $(NF-2)}' | \
    sort | uniq -c | sort -rn | head -20
```

### NFS Traffic Analysis

```bash
# Capture NFS operations
tcpdump -i wg0 -w nfs-trace.pcap port 2049 -s 0

# Analyze with nfsstat
nfsstat -c
nfsstat -s

# Monitor NFS RPC calls
rpcdebug -m nfs -c

# NFS client statistics
nfsstat -c | grep 'calls'

# Monitor NFS throughput
iotop -oP -a
```

### HTTP/HTTPS Traffic

```bash
# Capture HTTP headers
tcpdump -i wg0 -A -s 0 'tcp port 80 and (((ip[2:2] - ((ip[0]&0xf)<<2)) - ((tcp[12]&0xf0)>>2)) != 0)'

# Capture HTTP POST data
tcpdump -i wg0 -A -s 0 'tcp port 80 and (((ip[2:2] - ((ip[0]&0xf)<<2)) - ((tcp[12]&0xf0)>>2)) != 0)' | grep -i 'POST'

# Capture HTTPS (SNI only, encrypted)
tcpdump -i wg0 -n -s 1500 'tcp port 443' -A | grep -i 'Server Name'

# Full TLS handshake analysis
tcpdump -i wg0 -w tls-handshake.pcap -s 0 'tcp port 443 and (((ip[2:2] - ((ip[0]&0xf)<<2)) - ((tcp[12]&0xf0)>>2)) != 0)'
```

### WireGuard Traffic Analysis

```bash
# Monitor WireGuard handshakes
tcpdump -i wg0 -n 'udp port 51823'

# Count WireGuard packets
tcpdump -i wg0 -n -c 10000 'udp port 51823' | wc -l

# Analyze packet sizes
tcpdump -i wg0 -n -c 10000 'udp port 51823' | \
    awk '{print $NF}' | \
    awk -F'length' '{print $2}' | \
    sort | uniq -c

# WireGuard transfer statistics
wg show wg0 transfer
wg show wg0 dump
```

### Docker Container Traffic

```bash
# Capture container traffic by name
docker run --rm --net=container:ct111-archon \
    alpine tcpdump -i eth0 -w /tmp/capture.pcap

# Analyze container DNS queries
docker exec ct111-archon tcpdump -i eth0 -n port 53

# Bridge network analysis
tcpdump -i docker0 -n
tcpdump -i br+ -n  # All bridges
```

---

## Bottleneck Identification

### Network Latency Analysis

```bash
# Ping with detailed timing
ping -i 0.1 -c 100 10.6.0.5 | tail -n 5

# MTR (traceroute + ping)
mtr -r -c 100 10.6.0.20

# Detailed latency histogram
ping -i 0.01 -c 10000 10.6.0.5 | \
    grep 'time=' | \
    awk '{print $7}' | \
    cut -d'=' -f2 | \
    sort -n | \
    awk '{a[i++]=$1} END {print "Min:", a[0], "Max:", a[i-1], "Median:", a[int(i/2)]}'
```

### Throughput Testing

```bash
# iperf3 server (on receiver)
iperf3 -s

# iperf3 client (test bandwidth)
iperf3 -c 10.6.0.5 -t 60

# Parallel streams
iperf3 -c 10.6.0.5 -P 8 -t 60

# Reverse test (upload)
iperf3 -c 10.6.0.5 -R

# UDP test
iperf3 -c 10.6.0.5 -u -b 1G

# Window size tuning
iperf3 -c 10.6.0.5 -w 1M
```

### Congestion Detection

```bash
# Check for packet loss
ping -c 1000 -s 1400 10.6.0.5 | grep 'packet loss'

# Check TCP retransmissions
ss -ti | grep retrans

# Netstat for retransmissions
netstat -s | grep 'retransmitted'

# Check interface errors
ip -s link show wg0

# Check queue lengths (tc)
tc -s qdisc show dev wg0
```

### Interface Statistics

```bash
# Detailed interface stats
ethtool -S wg0

# Interface errors
ip -s -s link show wg0

# Connection tracking table size
conntrack -L | wc -l
conntrack -S

# Socket statistics
ss -s
ss -a | grep -E 'ESTAB|TIME-WAIT'

# Network buffer usage
cat /proc/net/softnet_stat
```

### Storage Network Bottlenecks

```bash
# NFS performance
nfsiostat 10 5

# iSCSI statistics
cat /proc/scsi/iscsi/

# Block I/O wait
iostat -x 10 5

# Disk latency during network I/O
ioping -c 10 /mnt/aglsrv1/data
```

---

## Traffic Shaping (QoS)

### tc (Traffic Control) Basics

```bash
# Check current qdisc
tc qdisc show dev wg0

# Show detailed statistics
tc -s qdisc show dev wg0

# Show classes
tc class show dev wg0

# Show filters
tc filter show dev wg0
```

### Rate Limiting

```bash
# Rate limit WireGuard to 100 Mbps
tc qdisc add dev wg0 root handle 1: htb default 10
tc class add dev wg0 parent 1: classid 1:1 htb rate 100mbit
tc class add dev wg0 parent 1:1 classid 1:10 htb rate 100mbit ceil 100mbit

# Prioritize NFS traffic (port 2049)
tc qdisc add dev wg0 handle ffff: prio
tc filter add dev wg0 protocol ip parent ffff: pref 1 u32 match ip dport 2049 0xffff flowid 1:1

# Rate limit specific host
tc filter add dev wg0 protocol ip parent 1:0 prio 1 u32 match ip dst 10.6.0.20 flowid 1:10
```

### Priority Queueing

```bash
# Create priority queue (PRIO)
tc qdisc add dev wg0 root handle 1: prio bands 3

# Map NFS to highest priority
tc filter add dev wg0 protocol ip parent 1:0 prio 1 u32 match ip dport 2049 0xffffffff flowid 1:1

# Map SSH to medium priority
tc filter add dev wg0 protocol ip parent 1:0 prio 1 u32 match ip dport 22 0xffffffff flowid 1:2

# Everything else to lowest priority
tc filter add dev wg0 protocol ip parent 1:0 prio 2 u32 match ip dst 0.0.0.0/0 flowid 1:3
```

### Traffic Shaping for Docker

```bash
# Container bandwidth limit
docker run --rm --net=bridge \
    --network-opt=driver-opt=tc.root=1:htb \
    --network-opt=driver-opt=tc.1.rate=50mbit \
    nginx

# Using tc directly on docker0
tc qdisc add dev docker0 root handle 1: htb default 10
tc class add dev docker0 parent 1: classid 1:1 htb rate 1gbit
tc class add dev docker0 parent 1:1 classid 1:10 htb rate 100mbit ceil 500mbit
```

---

## DNS Optimization

### DNS Resolution Analysis

```bash
# Measure DNS resolution time
time dig google.com

# Query specific DNS server
dig @1.1.1.1 google.com

# Trace DNS path
dig +trace google.com

# Check DNS cache hit rate
systemd-resolve --statistics

# dnsmasq statistics
kill -USR1 $(cat /var/run/dnsmasq/dnsmasq.pid)
cat /var/run/dnsmasq/dnsmasq.leases
```

### DNS Caching Setup

```bash
# Install dnsmasq
apt install dnsmasq

# Configure cache
# /etc/dnsmasq.conf
cache-size=10000
server=1.1.1.1
server=8.8.8.8
interface=wg0

# Start service
systemctl enable dnsmasq
systemctl start dnsmasq

# Test cache
dig google.com | grep 'Query time'
dig google.com | grep 'Query time'  # Should be cached (~0ms)
```

### Unbound (Recursive DNS)

```bash
# Install Unbound
apt install unbound

# Configure for caching
# /etc/unbound/unbound.conf.d/cache.conf
server:
    interface: 10.6.0.21
    access-control: 10.6.0.0/24 allow
    cache-size: 100mb
    prefetch: yes
    prefetch-key: yes

# Enable and start
systemctl enable unbound
systemctl start unbound
```

---

## Network Tuning

### TCP Parameters Optimization

```bash
# /etc/sysctl.conf for network tuning
# TCP window scaling
net.ipv4.tcp_window_scaling = 1

# TCP selective ACKs
net.ipv4.tcp_sack = 1

# TCP timestamps
net.ipv4.tcp_timestamps = 1

# TCP FIN timeout
net.ipv4.tcp_fin_timeout = 30

# TCP keepalive
net.ipv4.tcp_keepalive_time = 120
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 3

# TCP buffers
net.ipv4.tcp_rmem = 4096 131072 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.netdev_max_backlog = 5000

# Congestion control (BBR is recommended for VPN)
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# Apply settings
sysctl -p
```

### WireGuard-Specific Tuning

```bash
# /etc/wireguard/wg0.conf
# Increase MTU for better throughput
MTU = 1420  # Optimal for most paths

# Persistent keepalive (NAT traversal)
PersistentKeepalive = 25

# Socket buffer
# /etc/sysctl.conf
net.core.rmem_max = 2500000
net.core.wmem_max = 2500000
```

### Kernel Network Buffers

```bash
# Increase socket buffer
sysctl -w net.core.rmem_max=134217728
sysctl -w net.core.wmem_max=134217728

# Increase TCP buffer
sysctl -w net.ipv4.tcp_rmem="4096 87380 67108864"
sysctl -w net.ipv4.tcp_wmem="4096 65536 67108864"

# Increase backlog
sysctl -w net.core.netdev_max_backlog=10000
```

---

## Troubleshooting

### Common Network Issues

#### High Latency on WireGuard

```bash
# Check MTU issues
ping -M do -s 1472 10.6.0.5  # Test MTU
# If fails, reduce MTU on WireGuard interface

# Check for packet loss
ping -c 1000 -s 1400 10.6.0.5 | grep 'packet loss'

# Check interface errors
ip -s link show wg0

# Check path MTU
tracepath 10.6.0.5
```

#### Low NFS Throughput

```bash
# Check NFS mount options
mount | grep nfs

# Optimize NFS mount options
# /etc/fstab
10.6.0.20:/mnt/data /mnt/aglsrv1/data nfs \
    rw,hard,intr,rsize=1048576,wsize=1048576,timeo=600,retrans=5,noatime,nodiratime 0 0

# Check NFS statistics
nfsstat -c

# Monitor NFS I/O
nfsiostat 10 5
```

#### Connection Drops

```bash
# Check TCP retransmissions
ss -ti | grep retrans

# Check for connection tracking issues
conntrack -L | wc -l

# Increase connection tracking table
sysctl -w net.netfilter.nf_conntrack_max=2097152

# Check for network congestion
tc -s qdisc show dev wg0
```

#### DNS Resolution Failures

```bash
# Test DNS directly
dig @1.1.1.1 google.com
dig @8.8.8.8 google.com

# Check local DNS cache
systemd-resolve --statistics

# Test with nslookup
nslookup google.com

# Check DNS server connectivity
ping 1.1.1.1
```

### Diagnostic Scripts

See `scripts/` directory for automated diagnostics:
- `net-capture.sh` - Automated packet capture
- `net-bandwidth.sh` - Bandwidth monitoring
- `net-protocols.sh` - Protocol analysis
- `net-optimize-tcp.sh` - TCP optimization
- `net-qos.sh` - Traffic shaping configuration

---

## Monitoring Integration

### Netdata Dashboard

Access Netdata for real-time monitoring:
- URL: `http://<host>:19999`
- Sections: Network Interface, IPv4, TCP, UDP, Netfilter

### Prometheus Integration

```bash
# Install node_exporter with network collector
apt install prometheus-node-exporter

# Enable network collector
# /etc/default/prometheus-node-exporter
ARGS="--collector.network"

# Metrics available:
# - node_network_receive_bytes_total
# - node_network_transmit_bytes_total
# - node_network_receive_errs_total
# - node_network_transmit_errs_total
```

### Custom Metrics

```bash
# Export custom network metrics
# /usr/local/bin/network-metrics.sh
#!/bin/bash
echo "network_latency_ms $(ping -c 1 10.6.0.5 | grep 'time=' | cut -d'=' -f2 | cut -d' ' -f1)"
echo "wireguard_handshake_age $(($(date +%s) - $(wg show wg0 latest-handshakes | head -1 | awk '{print $2}')))"
echo "nfs_connections $(netstat -an | grep ':2049' | grep ESTAB | wc -l)"
```

---

## Best Practices

1. **Baseline First**: Establish normal traffic patterns before optimization
2. **Monitor Continuously**: Use vnstat/Netdata for historical data
3. **Test Incrementally**: Apply one change at a time, measure impact
4. **Document Changes**: Record all network tuning for rollback
5. **Use QoS**: Prioritize critical traffic (NFS, SSH, VPN)
6. **Optimize MTU**: Find optimal MTU for each path
7. **Monitor Errors**: Track packet loss, retransmissions, errors
8. **Scale Buffers**: Adjust TCP buffers based on bandwidth*delay product

---

## Related Skills

- `wireguard-network-management` - WireGuard VPN configuration
- `proxmox-infrastructure-management` - Proxmox networking
- `harbor-registry-operations` - Docker container networking
- `performance-monitoring` - Application-level monitoring

---

**Version**: 1.0.0
**Last Updated**: 2026-02-07
**Maintainer**: AGL Infrastructure Team

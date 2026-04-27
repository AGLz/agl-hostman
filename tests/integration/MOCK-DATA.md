# Mock Data Documentation

Comprehensive guide to mock data structures and test fixtures used in integration tests.

## 📋 Overview

This document details all mock data structures used for testing, including:
- Proxmox API responses
- Network command outputs
- Docker container data
- Test fixtures

## 🖥️ Proxmox API Mocks

### Authentication

#### API Token Authentication

```json
{
  "headers": {
    "Authorization": "PVEAPIToken=test@pam!test-token=test-secret"
  }
}
```

#### Password Authentication

**Request:**
```json
{
  "username": "test@pam",
  "password": "test-password"
}
```

**Response:**
```json
{
  "data": {
    "ticket": "PVE:test@pam:12345678::abcdef123456",
    "CSRFPreventionToken": "12345678:abcdef123456",
    "username": "test@pam",
    "cap": {
      "access": {
        "check": 1
      }
    }
  }
}
```

### Node Information

#### GET /api2/json/nodes

```json
{
  "data": [
    {
      "node": "aglsrv1",
      "status": "online",
      "uptime": 864000,
      "maxcpu": 32,
      "maxmem": 137438953472,
      "cpu": 0.25,
      "mem": 68719476736,
      "disk": 0,
      "maxdisk": 1099511627776,
      "type": "node",
      "id": "node/aglsrv1",
      "level": ""
    },
    {
      "node": "aglsrv6",
      "status": "online",
      "uptime": 432000,
      "maxcpu": 16,
      "maxmem": 68719476736,
      "cpu": 0.15,
      "mem": 34359738368,
      "disk": 0,
      "maxdisk": 549755813888,
      "type": "node",
      "id": "node/aglsrv6",
      "level": ""
    }
  ]
}
```

### Node Status

#### GET /api2/json/nodes/{node}/status

```json
{
  "data": {
    "uptime": 864000,
    "cpu": 0.25,
    "memory": {
      "used": 68719476736,
      "total": 137438953472,
      "free": 68719476736
    },
    "swap": {
      "used": 0,
      "total": 8589934592,
      "free": 8589934592
    },
    "loadavg": [1.5, 1.3, 1.2],
    "cpuinfo": {
      "model": "Intel(R) Xeon(R) CPU E5-2680 v4 @ 2.40GHz",
      "cores": 32,
      "sockets": 2,
      "threads": 64,
      "mhz": "2400.000",
      "flags": "fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov"
    },
    "kversion": "Linux 6.8.4-2-pve #1 SMP PREEMPT_DYNAMIC PMX 6.8.4-2",
    "pveversion": "pve-manager/8.2.2/9355359cd7afbae4"
  }
}
```

### Containers

#### GET /api2/json/nodes/{node}/lxc

```json
{
  "data": [
    {
      "vmid": "179",
      "name": "agldv03",
      "status": "running",
      "cpus": 16,
      "maxmem": 51539607552,
      "maxdisk": 107374182400,
      "uptime": 432000,
      "netin": 1234567890,
      "netout": 9876543210,
      "diskread": 123456789,
      "diskwrite": 987654321,
      "cpu": 0.42,
      "mem": 25769803776,
      "disk": 53687091200,
      "type": "lxc",
      "template": 0
    },
    {
      "vmid": "183",
      "name": "archon",
      "status": "running",
      "cpus": 4,
      "maxmem": 8589934592,
      "maxdisk": 21474836480,
      "uptime": 345600,
      "netin": 987654321,
      "netout": 1234567890,
      "diskread": 98765432,
      "diskwrite": 123456789,
      "cpu": 0.15,
      "mem": 4294967296,
      "disk": 10737418240,
      "type": "lxc",
      "template": 0
    },
    {
      "vmid": "108",
      "name": "agldv06",
      "status": "stopped",
      "cpus": 8,
      "maxmem": 17179869184,
      "maxdisk": 53687091200,
      "uptime": 0,
      "netin": 0,
      "netout": 0,
      "diskread": 0,
      "diskwrite": 0,
      "cpu": 0,
      "mem": 0,
      "disk": 0,
      "type": "lxc",
      "template": 0
    }
  ]
}
```

### Virtual Machines

#### GET /api2/json/nodes/{node}/qemu

```json
{
  "data": [
    {
      "vmid": "100",
      "name": "ubuntu-22.04",
      "status": "running",
      "cpus": 4,
      "maxmem": 8589934592,
      "maxdisk": 53687091200,
      "uptime": 259200,
      "netin": 456789012,
      "netout": 234567890,
      "diskread": 45678901,
      "diskwrite": 23456789,
      "cpu": 0.08,
      "mem": 4294967296,
      "disk": 26843545600,
      "qmpstatus": "running",
      "pid": 12345
    }
  ]
}
```

### Storage

#### GET /api2/json/nodes/{node}/storage

```json
{
  "data": [
    {
      "storage": "local",
      "type": "dir",
      "content": "vztmpl,iso,backup",
      "active": 1,
      "enabled": 1,
      "used": 549755813888,
      "avail": 549755813888,
      "total": 1099511627776,
      "shared": 0
    },
    {
      "storage": "fgsrv6-wg",
      "type": "nfs",
      "content": "images,rootdir",
      "active": 1,
      "enabled": 1,
      "used": 2199023255552,
      "avail": 3298534883328,
      "total": 5497558138880,
      "shared": 1,
      "server": "10.6.0.5",
      "export": "/tank/proxmox"
    },
    {
      "storage": "local-lvm",
      "type": "lvmthin",
      "content": "images,rootdir",
      "active": 1,
      "enabled": 1,
      "used": 274877906944,
      "avail": 824633720832,
      "total": 1099511627776,
      "shared": 0
    }
  ]
}
```

## 🌐 Network Command Mocks

### WireGuard

#### Command: `wg show`

```
interface: wg0
  public key: mockPublicKey1234567890abcdefghijklmnopqrstuv=
  private key: (hidden)
  listening port: 51820

peer: peerPublicKey1234567890abcdefghijklmnopqrstuv=
  endpoint: 10.6.0.5:51820
  allowed ips: 10.6.0.5/32
  latest handshake: 1 minute, 23 seconds ago
  transfer: 123.45 MiB received, 67.89 MiB sent

peer: peerPublicKey2345678901bcdefghijklmnopqrstuvwx=
  endpoint: 10.6.0.12:51820
  allowed ips: 10.6.0.12/32
  latest handshake: 2 minutes, 15 seconds ago
  transfer: 234.56 MiB received, 89.01 MiB sent

peer: peerPublicKey3456789012cdefghijklmnopqrstuvwxy=
  endpoint: 192.168.0.245:51820
  allowed ips: 10.6.0.1/32
  latest handshake: 45 seconds ago
  transfer: 345.67 MiB received, 90.12 MiB sent
```

### Tailscale

#### Command: `tailscale status --json`

```json
{
  "Self": {
    "ID": "node-id-12345678",
    "PublicKey": "nodekey:1234567890abcdefghijklmnopqrstuvwxyz123456",
    "HostName": "agldv03",
    "DNSName": "agldv03.tail-scale.ts.net",
    "OS": "linux",
    "UserID": 123456789,
    "TailscaleIPs": ["100.94.221.87"],
    "Online": true,
    "LastSeen": "2025-10-28T10:30:00Z"
  },
  "Peer": {
    "peer1": {
      "ID": "peer-id-abcdef123",
      "PublicKey": "nodekey:abcdef1234567890ghijklmnopqrstuvwxyz12345",
      "HostName": "aglsrv1",
      "DNSName": "aglsrv1.tail-scale.ts.net",
      "OS": "linux",
      "TailscaleIPs": ["100.107.113.33"],
      "Online": true,
      "LastSeen": "2025-10-28T10:29:45Z"
    },
    "peer2": {
      "ID": "peer-id-xyz789456",
      "PublicKey": "nodekey:xyz789456abcdefghijklmnopqrstuvwxyz1234",
      "HostName": "aglhq11",
      "DNSName": "aglhq11.tail-scale.ts.net",
      "OS": "windows",
      "TailscaleIPs": ["100.75.205.122"],
      "Online": true,
      "LastSeen": "2025-10-28T10:28:30Z"
    }
  }
}
```

### Network Interfaces

#### Command: `ip -j addr show`

```json
[
  {
    "ifindex": 1,
    "ifname": "lo",
    "flags": ["LOOPBACK", "UP", "LOWER_UP"],
    "mtu": 65536,
    "qdisc": "noqueue",
    "operstate": "UNKNOWN",
    "linkmode": "DEFAULT",
    "group": "default",
    "txqlen": 1000,
    "link_type": "loopback",
    "address": "00:00:00:00:00:00",
    "broadcast": "00:00:00:00:00:00",
    "addr_info": [
      {
        "family": "inet",
        "local": "127.0.0.1",
        "prefixlen": 8,
        "scope": "host",
        "label": "lo"
      },
      {
        "family": "inet6",
        "local": "::1",
        "prefixlen": 128,
        "scope": "host"
      }
    ]
  },
  {
    "ifindex": 2,
    "ifname": "eth0",
    "flags": ["BROADCAST", "MULTICAST", "UP", "LOWER_UP"],
    "mtu": 1500,
    "qdisc": "fq_codel",
    "operstate": "UP",
    "linkmode": "DEFAULT",
    "group": "default",
    "txqlen": 1000,
    "link_type": "ether",
    "address": "bc:24:11:ab:cd:ef",
    "broadcast": "ff:ff:ff:ff:ff:ff",
    "addr_info": [
      {
        "family": "inet",
        "local": "192.168.0.179",
        "prefixlen": 24,
        "broadcast": "192.168.0.255",
        "scope": "global",
        "label": "eth0"
      },
      {
        "family": "inet6",
        "local": "fe80::be24:11ff:feab:cdef",
        "prefixlen": 64,
        "scope": "link"
      }
    ]
  },
  {
    "ifindex": 3,
    "ifname": "wg0",
    "flags": ["POINTOPOINT", "NOARP", "UP", "LOWER_UP"],
    "mtu": 1420,
    "qdisc": "noqueue",
    "operstate": "UP",
    "linkmode": "DEFAULT",
    "group": "default",
    "txqlen": 1000,
    "link_type": "none",
    "addr_info": [
      {
        "family": "inet",
        "local": "10.6.0.19",
        "prefixlen": 24,
        "scope": "global",
        "label": "wg0"
      }
    ]
  },
  {
    "ifindex": 4,
    "ifname": "tailscale0",
    "flags": ["POINTOPOINT", "MULTICAST", "NOARP", "UP", "LOWER_UP"],
    "mtu": 1280,
    "qdisc": "fq_codel",
    "operstate": "UP",
    "linkmode": "DEFAULT",
    "group": "default",
    "txqlen": 500,
    "link_type": "none",
    "addr_info": [
      {
        "family": "inet",
        "local": "100.94.221.87",
        "prefixlen": 32,
        "scope": "global",
        "label": "tailscale0"
      }
    ]
  }
]
```

## 🐳 Docker Mocks

### Container Inspect

```json
{
  "Id": "abc123def456",
  "Created": "2025-10-28T10:00:00.000000000Z",
  "Path": "sleep",
  "Args": ["300"],
  "State": {
    "Status": "running",
    "Running": true,
    "Paused": false,
    "Restarting": false,
    "OOMKilled": false,
    "Dead": false,
    "Pid": 12345,
    "ExitCode": 0,
    "Error": "",
    "StartedAt": "2025-10-28T10:00:01.000000000Z",
    "FinishedAt": "0001-01-01T00:00:00Z"
  },
  "Image": "sha256:alpine123456789",
  "Name": "/test-container",
  "RestartCount": 0,
  "HostConfig": {
    "Memory": 52428800,
    "NanoCpus": 1000000000,
    "AutoRemove": false
  },
  "NetworkSettings": {
    "Networks": {
      "bridge": {
        "IPAddress": "172.17.0.2",
        "Gateway": "172.17.0.1",
        "MacAddress": "02:42:ac:11:00:02"
      }
    }
  }
}
```

### Container Stats

```json
{
  "read": "2025-10-28T10:30:00.000000000Z",
  "preread": "2025-10-28T10:29:59.000000000Z",
  "pids_stats": {
    "current": 5
  },
  "blkio_stats": {
    "io_service_bytes_recursive": []
  },
  "cpu_stats": {
    "cpu_usage": {
      "total_usage": 123456789,
      "usage_in_kernelmode": 12345678,
      "usage_in_usermode": 23456789
    },
    "system_cpu_usage": 987654321098,
    "online_cpus": 16
  },
  "precpu_stats": {
    "cpu_usage": {
      "total_usage": 123450000
    },
    "system_cpu_usage": 987650000000
  },
  "memory_stats": {
    "usage": 52428800,
    "max_usage": 104857600,
    "stats": {
      "cache": 10485760
    },
    "limit": 209715200
  },
  "networks": {
    "eth0": {
      "rx_bytes": 1234567,
      "rx_packets": 1234,
      "tx_bytes": 7654321,
      "tx_packets": 4321
    }
  }
}
```

## 📦 Test Fixtures

### Container Test Data

```javascript
// tests/integration/fixtures/containers.js
module.exports = {
  running: {
    vmid: '179',
    name: 'agldv03',
    status: 'running',
    cpus: 16,
    maxmem: 51539607552,
    uptime: 432000,
  },
  stopped: {
    vmid: '108',
    name: 'agldv06',
    status: 'stopped',
    cpus: 8,
    maxmem: 17179869184,
    uptime: 0,
  },
};
```

### Network Test Data

```javascript
// tests/integration/fixtures/network.js
module.exports = {
  wireguard: {
    interface: 'wg0',
    peers: 3,
    status: 'active',
  },
  tailscale: {
    online: true,
    peers: 5,
    ip: '100.94.221.87',
  },
  interfaces: [
    {
      name: 'eth0',
      ip: '192.168.0.179',
      state: 'UP',
    },
    {
      name: 'wg0',
      ip: '10.6.0.19',
      state: 'UP',
    },
  ],
};
```

## 🎨 Custom Test Data Generators

### Generate Random Container

```javascript
function generateContainer(overrides = {}) {
  return {
    vmid: String(Math.floor(Math.random() * 900) + 100),
    name: `test-ct${Math.floor(Math.random() * 1000)}`,
    status: 'running',
    cpus: Math.floor(Math.random() * 16) + 1,
    maxmem: (Math.floor(Math.random() * 64) + 1) * 1024 * 1024 * 1024,
    uptime: Math.floor(Math.random() * 86400),
    ...overrides,
  };
}
```

### Generate Random IP

```javascript
function generateIP(subnet = '192.168.0') {
  const lastOctet = Math.floor(Math.random() * 254) + 1;
  return `${subnet}.${lastOctet}`;
}
```

## 🔗 Related Documentation

- [Integration Tests README](README.md)
- [CI/CD Integration](CI-CD-INTEGRATION.md)
- [Testing Strategy](../TESTING-DELIVERABLES-SUMMARY.md)

---

**Last Updated:** 2025-10-28
**Maintainer:** AGL Infrastructure Team

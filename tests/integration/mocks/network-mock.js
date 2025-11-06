/**
 * Network Command Mocks
 * Mock system commands for network testing
 */

const { EventEmitter } = require('events');

class NetworkMock extends EventEmitter {
  constructor() {
    super();
    this.commandMocks = new Map();
  }

  /**
   * Mock WireGuard output
   */
  mockWireGuard(peersCount = 3) {
    const peers = [];
    for (let i = 0; i < peersCount; i++) {
      peers.push(`
peer: mock${i}PublicKey${this.randomString(43 - i.toString().length - 4)}=
  endpoint: 10.6.0.${i + 1}:51820
  allowed ips: 10.6.0.${i + 1}/32
  latest handshake: ${i} minutes, ${i * 10} seconds ago
  transfer: ${i * 100} MiB received, ${i * 50} MiB sent`);
    }

    this.commandMocks.set('wg show', peers.join('\n'));
    return this;
  }

  /**
   * Mock WireGuard error
   */
  mockWireGuardError() {
    this.commandMocks.set('wg show', { error: 'Unable to access WireGuard interface' });
    return this;
  }

  /**
   * Mock Tailscale output
   */
  mockTailscale(peersCount = 5) {
    const peers = {};
    for (let i = 0; i < peersCount; i++) {
      peers[`peer${i}`] = {
        ID: `mock-peer-id-${i}`,
        PublicKey: this.randomString(44),
        HostName: `host${i}.tail-scale.ts.net`,
        DNSName: `host${i}.tail-scale.ts.net`,
        OS: 'linux',
        TailscaleIPs: [`100.${100 + i}.${200 + i}.${i}`],
        Online: i % 2 === 0,
      };
    }

    const status = {
      Self: {
        ID: 'mock-self-id',
        PublicKey: this.randomString(44),
        HostName: 'test-host.tail-scale.ts.net',
        DNSName: 'test-host.tail-scale.ts.net',
        OS: 'linux',
        TailscaleIPs: ['100.100.100.100'],
        Online: true,
      },
      Peer: peers,
    };

    this.commandMocks.set('tailscale status --json', JSON.stringify(status));
    return this;
  }

  /**
   * Mock Tailscale error
   */
  mockTailscaleError() {
    this.commandMocks.set('tailscale status --json', {
      error: 'Tailscale is not running'
    });
    return this;
  }

  /**
   * Mock network interfaces
   */
  mockInterfaces() {
    const interfaces = [
      {
        ifindex: 1,
        ifname: 'lo',
        operstate: 'UNKNOWN',
        addr_info: [
          { family: 'inet', local: '127.0.0.1', prefixlen: 8 },
          { family: 'inet6', local: '::1', prefixlen: 128 },
        ],
      },
      {
        ifindex: 2,
        ifname: 'eth0',
        operstate: 'UP',
        addr_info: [
          { family: 'inet', local: '192.168.0.179', prefixlen: 24 },
          { family: 'inet6', local: 'fe80::1', prefixlen: 64 },
        ],
      },
      {
        ifindex: 3,
        ifname: 'wg0',
        operstate: 'UP',
        addr_info: [
          { family: 'inet', local: '10.6.0.19', prefixlen: 24 },
        ],
      },
      {
        ifindex: 4,
        ifname: 'tailscale0',
        operstate: 'UP',
        addr_info: [
          { family: 'inet', local: '100.94.221.87', prefixlen: 32 },
        ],
      },
    ];

    this.commandMocks.set('ip -j addr show', JSON.stringify(interfaces));
    return this;
  }

  /**
   * Mock ping success
   */
  mockPing(host, success = true) {
    if (success) {
      this.commandMocks.set(`ping -c 1 -W 1 ${host}`,
        `PING ${host} 56(84) bytes of data.\n64 bytes from ${host}: icmp_seq=1 ttl=64 time=0.5 ms`);
    } else {
      this.commandMocks.set(`ping -c 1 -W 1 ${host}`,
        { error: `ping: ${host}: Name or service not known` });
    }
    return this;
  }

  /**
   * Mock DNS resolution
   */
  mockDNS(hostname, ip) {
    this.commandMocks.set(`host ${hostname}`,
      `${hostname} has address ${ip}`);
    return this;
  }

  /**
   * Get mock command output
   */
  getMockOutput(command) {
    return this.commandMocks.get(command) || { error: 'Command not found' };
  }

  /**
   * Setup all network mocks
   */
  setupAll() {
    this.mockWireGuard();
    this.mockTailscale();
    this.mockInterfaces();
    this.mockPing('10.6.0.5', true);
    this.mockPing('8.8.8.8', true);
    this.mockDNS('aglsrv1.local', '192.168.0.245');
    return this;
  }

  /**
   * Clear all mocks
   */
  cleanup() {
    this.commandMocks.clear();
  }

  /**
   * Helper: Generate random string
   */
  randomString(length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    let result = '';
    for (let i = 0; i < length; i++) {
      result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return result;
  }
}

module.exports = NetworkMock;

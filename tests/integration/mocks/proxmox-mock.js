/**
 * Proxmox API Mock Server
 * Mock implementation for testing Proxmox integration
 */

const nock = require('nock');

class ProxmoxMock {
  constructor(baseURL = 'https://mock-proxmox.test:8006') {
    this.baseURL = baseURL;
    this.scope = null;
  }

  /**
   * Setup mock server
   */
  setup() {
    this.scope = nock(this.baseURL)
      .persist() // Keep mocks active for multiple requests
      .replyContentLength();

    return this;
  }

  /**
   * Mock authentication
   */
  mockAuth() {
    // API token authentication
    this.scope
      .get(/\/api2\/json\/.*/)
      .matchHeader('Authorization', /^PVEAPIToken=.*/)
      .reply(200, (uri, _requestBody) => {
        return this.getMockResponse(uri);
      });

    // Password authentication
    this.scope
      .post('/api2/json/access/ticket')
      .reply(200, {
        data: {
          ticket: 'PVE:mock-ticket:12345',
          CSRFPreventionToken: 'mock-csrf-token',
          username: 'test@pam',
        },
      });

    return this;
  }

  /**
   * Mock nodes endpoint
   */
  mockNodes() {
    this.scope
      .get('/api2/json/nodes')
      .reply(200, {
        data: [
          {
            node: 'aglsrv1',
            status: 'online',
            uptime: 864000,
            maxcpu: 32,
            maxmem: 137438953472,
            cpu: 0.25,
            mem: 68719476736,
            disk: 0,
            maxdisk: 1099511627776,
          },
          {
            node: 'aglsrv6',
            status: 'online',
            uptime: 432000,
            maxcpu: 16,
            maxmem: 68719476736,
            cpu: 0.15,
            mem: 34359738368,
            disk: 0,
            maxdisk: 549755813888,
          },
        ],
      });

    return this;
  }

  /**
   * Mock node status
   */
  mockNodeStatus(nodeName = 'aglsrv1') {
    this.scope
      .get(`/api2/json/nodes/${nodeName}/status`)
      .reply(200, {
        data: {
          uptime: 864000,
          cpu: 0.25,
          memory: {
            used: 68719476736,
            total: 137438953472,
            free: 68719476736,
          },
          swap: {
            used: 0,
            total: 8589934592,
            free: 8589934592,
          },
          loadavg: [1.5, 1.3, 1.2],
          cpuinfo: {
            model: 'Intel(R) Xeon(R) CPU E5-2680 v4',
            cores: 32,
            sockets: 2,
          },
        },
      });

    return this;
  }

  /**
   * Mock containers list
   */
  mockContainers(nodeName = 'aglsrv1') {
    this.scope
      .get(`/api2/json/nodes/${nodeName}/lxc`)
      .reply(200, {
        data: [
          {
            vmid: '179',
            name: 'agldv03',
            status: 'running',
            cpus: 16,
            maxmem: 51539607552,
            maxdisk: 107374182400,
            uptime: 432000,
            netin: 1234567890,
            netout: 9876543210,
            diskread: 123456789,
            diskwrite: 987654321,
          },
          {
            vmid: '183',
            name: 'archon',
            status: 'running',
            cpus: 4,
            maxmem: 8589934592,
            maxdisk: 21474836480,
            uptime: 345600,
            netin: 987654321,
            netout: 1234567890,
            diskread: 98765432,
            diskwrite: 123456789,
          },
        ],
      });

    return this;
  }

  /**
   * Mock VMs list
   */
  mockVMs(nodeName = 'aglsrv1') {
    this.scope
      .get(`/api2/json/nodes/${nodeName}/qemu`)
      .reply(200, {
        data: [
          {
            vmid: '100',
            name: 'ubuntu-22.04',
            status: 'running',
            cpus: 4,
            maxmem: 8589934592,
            maxdisk: 53687091200,
            uptime: 259200,
          },
        ],
      });

    return this;
  }

  /**
   * Mock storage list
   */
  mockStorage(nodeName = 'aglsrv1') {
    this.scope
      .get(`/api2/json/nodes/${nodeName}/storage`)
      .reply(200, {
        data: [
          {
            storage: 'local',
            type: 'dir',
            content: 'vztmpl,iso,backup',
            active: 1,
            enabled: 1,
            used: 549755813888,
            avail: 549755813888,
            total: 1099511627776,
          },
          {
            storage: 'fgsrv6-wg',
            type: 'nfs',
            content: 'images,rootdir',
            active: 1,
            enabled: 1,
            used: 2199023255552,
            avail: 3298534883328,
            total: 5497558138880,
          },
        ],
      });

    return this;
  }

  /**
   * Mock API errors
   */
  mockError(endpoint, statusCode = 500, message = 'Internal Server Error') {
    this.scope
      .get(new RegExp(endpoint))
      .reply(statusCode, {
        errors: message,
      });

    return this;
  }

  /**
   * Mock timeout
   */
  mockTimeout(endpoint) {
    this.scope
      .get(new RegExp(endpoint))
      .delayConnection(11000) // Longer than default timeout
      .reply(200);

    return this;
  }

  /**
   * Get appropriate mock response based on URI
   */
  getMockResponse(uri) {
    if (uri.includes('/nodes') && !uri.includes('/lxc') && !uri.includes('/qemu')) {
      return {
        data: [
          {
            node: 'aglsrv1',
            status: 'online',
          },
        ],
      };
    }
    return { data: [] };
  }

  /**
   * Setup all mocks at once
   */
  setupAll() {
    this.setup();
    this.mockAuth();
    this.mockNodes();
    this.mockNodeStatus('aglsrv1');
    this.mockNodeStatus('aglsrv6');
    this.mockContainers('aglsrv1');
    this.mockContainers('aglsrv6');
    this.mockVMs('aglsrv1');
    this.mockVMs('aglsrv6');
    this.mockStorage('aglsrv1');
    this.mockStorage('aglsrv6');
    return this;
  }

  /**
   * Clear all mocks
   */
  cleanup() {
    if (this.scope) {
      nock.cleanAll();
    }
  }

  /**
   * Verify all mocks were called
   */
  verify() {
    if (this.scope) {
      this.scope.done();
    }
  }
}

module.exports = ProxmoxMock;

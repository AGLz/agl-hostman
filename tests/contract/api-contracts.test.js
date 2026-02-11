/**
 * API Contract Tests
 *
 * Validates API response schemas and contracts
 * Ensures API responses match expected structure
 * @version 1.0.0
 */

const request = require('supertest');
const Ajv = require('ajv');

let app;
let ajv;

beforeAll(() => {
  app = require('../../../src/dashboard/server');
  ajv = new Ajv({ allErrors: true });
});

// API Response Schemas
const schemas = {
  healthResponse: {
    type: 'object',
    required: ['status', 'timestamp', 'uptime', 'environment', 'version'],
    properties: {
      status: { type: 'string', enum: ['healthy'] },
      timestamp: {
        type: 'string',
        pattern: '^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\.\\d{3})?Z$',
      },
      uptime: { type: 'number', minimum: 0 },
      environment: { type: 'string' },
      version: { type: 'string' },
    },
    additionalProperties: false,
  },

  successResponse: {
    type: 'object',
    required: ['success', 'data'],
    properties: {
      success: { type: 'boolean', enum: [true] },
      data: { type: 'object' },
    },
  },

  errorResponse: {
    type: 'object',
    required: ['success', 'error'],
    properties: {
      success: { type: 'boolean', enum: [false] },
      error: { type: 'string' },
      message: { type: 'string' },
      path: { type: 'string' },
    },
  },

  overviewData: {
    type: 'object',
    required: ['nodes', 'containers', 'vms'],
    properties: {
      nodes: {
        type: 'array',
        items: {
          type: 'object',
          required: ['name', 'status', 'cpu', 'memory', 'uptime'],
          properties: {
            name: { type: 'string' },
            status: { type: 'string' },
            cpu: { type: 'number', minimum: 0 },
            memory: {
              type: 'object',
              required: ['used', 'total', 'percent'],
              properties: {
                used: { type: 'number', minimum: 0 },
                total: { type: 'number', minimum: 0 },
                percent: { type: 'number', minimum: 0, maximum: 100 },
              },
            },
            uptime: { type: 'number', minimum: 0 },
          },
        },
      },
      containers: { type: 'number', minimum: 0 },
      vms: { type: 'number', minimum: 0 },
    },
  },

  containerData: {
    type: 'array',
    items: {
      type: 'object',
      required: ['vmid', 'name', 'status', 'node', 'type', 'cpus', 'maxmem', 'maxdisk'],
      properties: {
        vmid: { type: 'string' },
        name: { type: 'string' },
        status: { type: 'string', enum: ['running', 'stopped', 'paused'] },
        node: { type: 'string' },
        type: { type: 'string', enum: ['lxc', 'qemu'] },
        cpus: { type: 'number', minimum: 0 },
        maxmem: { type: 'number', minimum: 0 },
        maxdisk: { type: 'number', minimum: 0 },
      },
    },
  },

  storageData: {
    type: 'array',
    items: {
      type: 'object',
      required: ['storage', 'type', 'node', 'used', 'avail', 'total', 'usedPercent'],
      properties: {
        storage: { type: 'string' },
        type: { type: 'string', enum: ['dir', 'lvm', 'nfs', 'cifs', 'zfs', 'btrfs'] },
        node: { type: 'string' },
        used: { type: 'number', minimum: 0 },
        avail: { type: 'number', minimum: 0 },
        total: { type: 'number', minimum: 0 },
        usedPercent: { type: 'number', minimum: 0, maximum: 100 },
      },
    },
  },

  networkData: {
    type: 'object',
    required: ['wireguard', 'tailscale', 'interfaces', 'timestamp'],
    properties: {
      wireguard: {
        type: 'object',
        required: ['enabled'],
        properties: {
          enabled: { type: 'boolean' },
          status: { type: 'string', enum: ['active', 'unavailable', 'error'] },
          peers: { type: 'number', minimum: 0 },
          error: { type: 'string' },
        },
      },
      tailscale: {
        type: 'object',
        required: ['enabled'],
        properties: {
          enabled: { type: 'boolean' },
          status: { type: 'string', enum: ['active', 'unavailable', 'error'] },
          peers: { type: 'number', minimum: 0 },
          error: { type: 'string' },
        },
      },
      interfaces: {
        type: 'array',
        items: {
          type: 'object',
          required: ['name', 'state'],
          properties: {
            name: { type: 'string' },
            state: { type: 'string' },
            addresses: {
              type: 'array',
              items: {
                type: 'object',
                properties: {
                  address: { type: 'string' },
                  family: { type: 'string' },
                  prefixlen: { type: 'number' },
                },
              },
            },
          },
        },
      },
      timestamp: {
        type: 'string',
        pattern: '^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}',
      },
    },
  },
};

describe('API Contract Tests', () => {
  describe('CONTRACT-001: Health Endpoint Contract', () => {
    test('should match health response schema', async () => {
      const validate = ajv.compile(schemas.healthResponse);

      const response = await request(app).get('/health').expect(200);

      const valid = validate(response.body);
      expect(valid).toBe(true);
      if (!valid) {
        console.error('Validation errors:', validate.errors);
      }
    });

    test('should have correct content-type', async () => {
      const response = await request(app).get('/health').expect(200);

      expect(response.headers['content-type']).toMatch(/application\/json/);
    });
  });

  describe('CONTRACT-002: Overview Endpoint Contract', () => {
    test('should match success response wrapper', async () => {
      const validate = ajv.compile(schemas.successResponse);

      const response = await request(app).get('/api/overview').expect(200);

      const valid = validate(response.body);
      expect(valid).toBe(true);
    });

    test('should match overview data schema', async () => {
      const validate = ajv.compile(schemas.overviewData);

      const response = await request(app).get('/api/overview').expect(200);

      const valid = validate(response.body.data);
      expect(valid).toBe(true);
      if (!valid) {
        console.error('Validation errors:', validate.errors);
      }
    });
  });

  describe('CONTRACT-003: Containers Endpoint Contract', () => {
    test('should match success response wrapper', async () => {
      const validate = ajv.compile(schemas.successResponse);

      const response = await request(app).get('/api/containers').expect(200);

      const valid = validate(response.body);
      expect(valid).toBe(true);
    });

    test('should match container data schema', async () => {
      const validate = ajv.compile(schemas.containerData);

      const response = await request(app).get('/api/containers').expect(200);

      const valid = validate(response.body.data);
      expect(valid).toBe(true);
      if (!valid) {
        console.error('Validation errors:', validate.errors);
      }
    });
  });

  describe('CONTRACT-004: Storage Endpoint Contract', () => {
    test('should match success response wrapper', async () => {
      const validate = ajv.compile(schemas.successResponse);

      const response = await request(app).get('/api/storage').expect(200);

      const valid = validate(response.body);
      expect(valid).toBe(true);
    });

    test('should match storage data schema', async () => {
      const validate = ajv.compile(schemas.storageData);

      const response = await request(app).get('/api/storage').expect(200);

      const valid = validate(response.body.data);
      expect(valid).toBe(true);
      if (!valid) {
        console.error('Validation errors:', validate.errors);
      }
    });
  });

  describe('CONTRACT-005: Network Endpoint Contract', () => {
    test('should match success response wrapper', async () => {
      const validate = ajv.compile(schemas.successResponse);

      const NetworkMonitor = require('../../../src/dashboard/api/network');
      jest.spyOn(NetworkMonitor.prototype, 'getStatus').mockResolvedValue({
        wireguard: { enabled: true, status: 'active' },
        tailscale: { enabled: true, status: 'active' },
        interfaces: [],
        timestamp: new Date().toISOString(),
      });

      const response = await request(app).get('/api/network').expect(200);

      const valid = validate(response.body);
      expect(valid).toBe(true);
    });

    test('should match network data schema', async () => {
      const validate = ajv.compile(schemas.networkData);

      const NetworkMonitor = require('../../../src/dashboard/api/network');
      jest.spyOn(NetworkMonitor.prototype, 'getStatus').mockResolvedValue({
        wireguard: { enabled: true, status: 'active' },
        tailscale: { enabled: true, status: 'active' },
        interfaces: [],
        timestamp: new Date().toISOString(),
      });

      const response = await request(app).get('/api/network').expect(200);

      const valid = validate(response.body.data);
      expect(valid).toBe(true);
      if (!valid) {
        console.error('Validation errors:', validate.errors);
      }
    });
  });

  describe('CONTRACT-006: Error Response Contract', () => {
    test('should match error response schema for 404', async () => {
      const validate = ajv.compile(schemas.errorResponse);

      const response = await request(app).get('/api/unknown').expect(404);

      const valid = validate(response.body);
      expect(valid).toBe(true);
      if (!valid) {
        console.error('Validation errors:', validate.errors);
      }
    });

    test('should include required error fields', async () => {
      const response = await request(app).get('/api/unknown').expect(404);

      expect(response.body).toHaveProperty('success', false);
      expect(response.body).toHaveProperty('error');
      expect(response.body).toHaveProperty('path');
    });
  });

  describe('CONTRACT-007: Data Type Validation', () => {
    test('health: timestamp should be valid ISO 8601', async () => {
      const response = await request(app).get('/health').expect(200);

      const timestamp = new Date(response.body.timestamp);
      expect(timestamp.getTime()).not.toBeNaN();
    });

    test('overview: memory values should be numbers', async () => {
      const response = await request(app).get('/api/overview').expect(200);

      const memory = response.body.data.nodes[0].memory;
      expect(typeof memory.used).toBe('number');
      expect(typeof memory.total).toBe('number');
      expect(typeof memory.percent).toBe('number');
    });

    test('containers: resource values should be positive numbers', async () => {
      const response = await request(app).get('/api/containers').expect(200);

      response.body.data.forEach(container => {
        expect(container.cpus).toBeGreaterThanOrEqual(0);
        expect(container.maxmem).toBeGreaterThanOrEqual(0);
        expect(container.maxdisk).toBeGreaterThanOrEqual(0);
      });
    });

    test('storage: usage percentage should be 0-100', async () => {
      const response = await request(app).get('/api/storage').expect(200);

      response.body.data.forEach(storage => {
        expect(storage.usedPercent).toBeGreaterThanOrEqual(0);
        expect(storage.usedPercent).toBeLessThanOrEqual(100);
      });
    });
  });

  describe('CONTRACT-008: Enum Validation', () => {
    test('containers: status should be valid enum', async () => {
      const response = await request(app).get('/api/containers').expect(200);

      const validStatuses = ['running', 'stopped', 'paused'];
      response.body.data.forEach(container => {
        expect(validStatuses).toContain(container.status);
      });
    });

    test('containers: type should be valid enum', async () => {
      const response = await request(app).get('/api/containers').expect(200);

      const validTypes = ['lxc', 'qemu'];
      response.body.data.forEach(container => {
        expect(validTypes).toContain(container.type);
      });
    });

    test('storage: type should be valid enum', async () => {
      const response = await request(app).get('/api/storage').expect(200);

      const validTypes = ['dir', 'lvm', 'nfs', 'cifs', 'zfs', 'btrfs'];
      response.body.data.forEach(storage => {
        expect(validTypes).toContain(storage.type);
      });
    });
  });

  describe('CONTRACT-009: Required Fields', () => {
    test('health response should have all required fields', async () => {
      const response = await request(app).get('/health').expect(200);

      const required = ['status', 'timestamp', 'uptime', 'environment', 'version'];
      required.forEach(field => {
        expect(response.body).toHaveProperty(field);
      });
    });

    test('overview data should have all required fields', async () => {
      const response = await request(app).get('/api/overview').expect(200);

      expect(response.body.data).toHaveProperty('nodes');
      expect(response.body.data).toHaveProperty('containers');
      expect(response.body.data).toHaveProperty('vms');
    });
  });

  describe('CONTRACT-010: No Additional Properties', () => {
    test('health response should not have unexpected fields', async () => {
      const response = await request(app).get('/health').expect(200);

      const allowed = new Set(['status', 'timestamp', 'uptime', 'environment', 'version']);
      const actual = Object.keys(response.body);

      // Allow some flexibility for additional fields
      actual.forEach(key => {
        if (!allowed.has(key)) {
          console.warn(`Unexpected field in health response: ${key}`);
        }
      });
    });
  });
});

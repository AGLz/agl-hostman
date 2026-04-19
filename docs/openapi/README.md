# AGL Hostman API Documentation

Welcome to the AGL Hostman API documentation. This comprehensive API provides access to infrastructure management, deployment pipelines, monitoring, automation, and more.

## 📚 Documentation Overview

### Core Documentation

- **[OpenAPI Specification](./agl-hostman-v3.0.yaml)** - Complete OpenAPI 3.0 specification
- **[Quick Start Guide](./quick-start.md)** - Get up and running quickly
- **[Authentication Guide](./authentication-guide.md)** - Authentication and security
- **[cURL Examples](./curl-examples.md)** - Practical cURL command examples
- **[Error Codes Reference](./error-codes-reference.md)** - All error codes and handling

### API Explorer

Interactive documentation is available at:
- **Swagger UI**: `https://api.agl.hostman/api-docs`
- **ReDoc**: `https://api.agl.hostman/redoc`

## 🚀 Key Features

### Infrastructure Management
- **Physical Locations**: Track and manage data centers and remote locations
- **Container Lifecycle**: Create, clone, migrate, backup, and restore containers
- **Server Management**: Monitor and manage server resources
- **Backup System**: Automated backup and restore operations

### Deployment Pipelines
- **Multi-Environment Deployments**: QA, UAT, and Production environments
- **Promotion Workflows**: Promote changes between environments
- **Rollback Support**: Quick rollback capabilities
- **Build Metrics**: Track build performance and trends

### Automation & Integration
- **N8N Workflows**: Robust workflow automation
- **Harbor Registry**: Container registry management
- **Dokploy Applications**: Application deployment platform
- **Webhook Support**: GitHub, Harbor, PagerDuty integrations

### Monitoring & Alerting
- **Real-time Monitoring**: System and application metrics
- **Alert Management**: Alert rules and notifications
- **Health Checks**: Service health monitoring
- **Performance Analytics**: Trends and predictions

### Security & Access Control
- **RBAC**: Role-Based Access Control
- **WorkOS Integration**: Enterprise authentication
- **Audit Logging**: Complete audit trail
- **Permission Management**: Fine-grained permissions

## 📋 API Endpoints by Category

### Authentication (6 endpoints)
- User profile retrieval
- WorkOS authentication flow
- Logout functionality

### N8N Workflow Automation (12 endpoints)
- Workflow CRUD operations
- Execution management
- Statistics and monitoring

### Infrastructure Management (8 endpoints)
- Physical locations
- Server status and metrics
- Infrastructure analytics

### AI Integration (6 endpoints)
- AI queries
- Multi-agent processing
- Model management

### Scrum Board Management (14 endpoints)
- Sprint management
- Task management
- Story tracking
- Bug tracking

### Container Lifecycle (6 endpoints)
- Container creation and cloning
- Backup and snapshot operations
- Migration management

### Backup Management (5 endpoints)
- Backup listing and creation
- Restore operations
- Download capabilities

### Harbor Registry (11 endpoints)
- Project and repository management
- Artifact operations
- Vulnerability scanning

### Dokploy Integration (12 endpoints)
- Application management
- Deployment operations
- Domain management
- Environment configuration

### Alert Management (8 endpoints)
- Active alerts
- Alert rules
- Alert lifecycle management

### Network Topology (5 endpoints)
- Network graph data
- Health monitoring
- Issue detection

### Deployment Pipeline (9 endpoints)
- Multi-environment deployments
- Promotion workflows
- Deployment status and logs

### Build Metrics (5 endpoints)
- Metric recording
- Historical data
- Trend analysis

### Monitoring (7 endpoints)
- System metrics
- Health checks
- Alert management
- Metric collection

### RBAC (9 endpoints)
- Role and permission management
- User access control
- System overview

### Webhooks (7 endpoints)
- GitHub integration
- Harbor events
- PagerDuty incidents
- Deployment notifications

## 🔐 Authentication

The API uses JWT tokens obtained through WorkOS authentication:

```bash
# 1. Redirect to WorkOS
curl -I https://api.agl.hostman/api/auth/workos/redirect

# 2. Get token after authentication
curl "https://api.agl.hostman/api/auth/workos/callback?code=YOUR_CODE"

# 3. Use token for API requests
curl -H "Authorization: Bearer YOUR_TOKEN" https://api.agl.hostman/api/user
```

## 📊 Rate Limiting

### Endpoint Categories
- **General API**: 100 requests/minute
- **Deployments**: 10 requests/minute
- **Backup Operations**: 10 requests/minute
- **Webhooks**: 60 requests/minute

### Rate Limit Headers
```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 99
X-RateLimit-Reset: 1645824000
```

## 🛠️ SDKs and Clients

### Official SDKs
- **Node.js**: `@agl/hostman-node-sdk`
- **Python**: `agl-hostman-python-sdk`
- **Go**: `agl-hostman-go-sdk`

### Example Usage

```javascript
const AGLHostman = require('@agl/hostman-node-sdk');

const client = new AGLHostman({
  baseUrl: 'https://api.agl.hostman/api',
  token: process.env.API_TOKEN
});

// Create container
const container = await client.containers.create({
  name: 'my-app',
  template: 'ubuntu-22.04',
  config: { cpu: 4, memory: 8192 }
});

// Deploy to QA
const deployment = await client.deployments.deployToQA({
  branch: 'main',
  environment: { NODE_ENV: 'production' }
});
```

## 🔄 Webhooks

### Supported Webhooks
- **GitHub**: Push events, workflow runs
- **Harbor**: Container push events
- **PagerDuty**: Incident notifications
- **Deployment**: Deployment status updates
- **N8N**: Workflow execution events

### Webhook Security
Webhooks are secured by:
- Shared secrets
- IP whitelisting
- Signature verification
- Rate limiting

## 📈 Monitoring and Observability

### Metrics Available
- **System Metrics**: CPU, memory, disk, network
- **Application Metrics**: Response times, error rates
- **Business Metrics**: Deployments, alerts, incidents
- **Custom Metrics**: User-defined metrics

### Alert Rules
Configure alerts based on:
- Metric thresholds
- Error rates
- Resource utilization
- Business logic conditions

## 🔧 API Versioning

### Current Version
- **v3.0.0**: Current stable release

### Version Support
- **v3.x**: Fully supported
- **v2.x**: Maintenance mode (deprecated 2024-06-30)
- **v1.x**: End of life

### Version Headers
```http
Accept: application/vnd.agl.hostman.v3+json
```

## 🐛 Troubleshooting

### Common Issues

1. **Authentication Issues**
   - Verify JWT token is valid
   - Check WorkOS integration status
   - Validate user permissions

2. **Rate Limiting**
   - Implement exponential backoff
   - Use pagination for large datasets
   - Cache frequent requests

3. **Integration Errors**
   - Check external service status
   - Verify API credentials
   - Review webhook configurations

### Debug Mode
Enable debug logging:
```bash
curl -H "X-Debug: true" https://api.agl.hostman/api/user
```

## 📞 Support

### Documentation
- **Full API Docs**: https://docs.agl.hostman
- **Release Notes**: https://docs.agl.hostman/releases
- **Changelog**: https://docs.agl.hostman/changelog

### Community Support
- **GitHub Issues**: https://github.com/agl/hostman/issues
- **Discord**: https://discord.gg/agl-hostman
- **Stack Overflow**: Use `agl-hostman` tag

### Enterprise Support
For enterprise customers:
- **Support Portal**: https://enterprise.agl.hostman/support
- **Dedicated Slack**: Contact account team
- **24/7 Support**: Available on enterprise plans

## 📝 Contributing

### API Guidelines
1. **RESTful Design**: Follow REST principles
2. **Consistent Naming**: Use clear, consistent endpoint names
3. **Error Handling**: Provide detailed error responses
4. **Documentation**: Update docs with every change

### How to Contribute
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add/update tests
5. Submit a pull request

### OpenAPI Contribution
When modifying the API:
1. Update the OpenAPI spec
2. Update all documentation
3. Add examples
4. Update SDKs

---

**Last Updated**: February 11, 2024
**API Version**: v3.0.0
**Next Review**: June 30, 2024
# Dokploy Dashboard - Usage Guide

**Last Updated**: 2025-11-12
**Version**: 1.0.0
**Location**: `/dokploy` route in AGL Infrastructure Admin

---

## Overview

The Dokploy Dashboard provides a comprehensive interface for managing Docker applications deployed via Dokploy (https://dok.aglz.io) and Harbor Registry (harbor.aglz.io:5000).

### Features

- **Application Management**: Create, edit, start, stop, redeploy, and delete Docker applications
- **Real-time Monitoring**: Track deployment status with auto-refresh (5-second polling)
- **Harbor Webhook Integration**: Automatic redeployment when images are pushed to Harbor registry
- **Project Organization**: Organize applications by Dokploy projects
- **Status Tracking**: Visual indicators for application states (running, idle, done, error)

---

## Navigation

Access the Dokploy Dashboard from the main navigation:
- **URL**: `/dokploy`
- **Navigation Link**: "Dokploy" in the top navigation bar
- **Authentication**: Requires WorkOS authentication

The dashboard has three main tabs:

### 1. Applications Tab

**Purpose**: Manage all Dokploy applications

**Features**:
- **List View**: Grid display of all applications with status badges
- **Search**: Filter applications by name or Docker image
- **Status Filter**: Filter by application status (all, running, idle, done, error)
- **Actions**:
  - **Create**: Launch modal form to create new application
  - **Start**: Start a stopped application
  - **Stop**: Stop a running application
  - **Redeploy**: Trigger redeployment of application
  - **Edit**: Open edit modal (under development)
  - **Delete**: Remove application (with confirmation)

**Creating an Application**:
1. Click "New Application" button
2. Fill in required fields:
   - **Name**: Display name for the application
   - **App Name**: Internal identifier (used in Docker)
   - **Project**: Select Dokploy project from dropdown
   - **Description**: Optional application description
   - **Source Type**: Choose deployment method:
     - **Docker**: Use pre-built Docker image from registry
     - **GitHub**: Deploy from GitHub repository
     - **GitLab**: Deploy from GitLab repository
     - **Git**: Deploy from custom Git repository
3. Source-specific fields:
   - **Docker**: Enter full image path (e.g., `harbor.aglz.io:5000/agl/my-app:latest`)
   - **Git**: Enter repository URL, branch, and build path
4. Click "Create Application"

### 2. Monitor Tab

**Purpose**: Real-time monitoring of individual application deployments

**Features**:
- **Application Selector**: Choose which application to monitor
- **Status Display**: Large, color-coded status card
- **Deployment Details**:
  - Docker image
  - Source type
  - Number of replicas
  - Creation date
- **Recent Activity**: Timeline of deployment events
- **Auto-refresh**: Status updates every 5 seconds

**How to Use**:
1. Navigate to "Monitor" tab
2. Select an application from the grid
3. View real-time status and deployment details
4. Monitor will automatically refresh every 5 seconds

**Status Indicators**:
- 🟢 **Running**: Application is deployed and running
- ⚪ **Idle**: Application is stopped or not deployed
- 🔵 **Done**: Deployment completed successfully
- 🔴 **Error**: Deployment failed or application error

### 3. Webhooks Tab

**Purpose**: Configure Harbor registry webhooks for automatic deployments

**Features**:
- **Webhook URL Display**: Copy-ready webhook endpoint URL
- **Setup Instructions**: 6-step guide for Harbor configuration
- **Event Types**: Documentation of supported webhook events
- **Image Matching**: Guide for matching Harbor images to Dokploy applications
- **Test Functionality**: Manual webhook testing

**Harbor Webhook Setup**:
1. Copy the webhook URL from the dashboard
2. Go to Harbor (https://harbor.aglz.io:5000)
3. Navigate to your project → Webhooks
4. Click "+ New Webhook"
5. Configure:
   - **Name**: Dokploy Auto Deploy
   - **Notify Type**: http
   - **Endpoint URL**: Paste the copied URL
   - **Event Type**: Check "Artifact pushed"
   - **Enabled**: Check the box
6. Click "Test Endpoint" to verify connectivity
7. Click "Continue" to save

**Webhook Flow**:
1. Developer pushes Docker image to Harbor registry
2. Harbor sends PUSH_ARTIFACT webhook to AGL Infrastructure Admin
3. System matches image name to Dokploy applications
4. Triggers automatic redeployment on matching applications
5. Monitor deployment status in real-time on Monitor tab

**Supported Events**:
- ✅ **PUSH_ARTIFACT**: Triggers automatic redeployment (active)
- ⚪ **DELETE_ARTIFACT**: Ignored, no action taken
- ⚪ **Other events**: Logged but no action taken

**Image Matching**:
The webhook system matches Harbor image names to Dokploy application's `dockerImage` field.

Example:
- **Harbor image**: `harbor.aglz.io:5000/agl/my-app:latest`
- **Dokploy config**: Application `dockerImage` must be `harbor.aglz.io:5000/agl/my-app:latest`

---

## API Integration

### Backend Endpoints

All API calls use Laravel Sanctum authentication with Bearer tokens stored in `localStorage`.

**Applications**:
- `GET /api/dokploy/applications` - List all applications
- `GET /api/dokploy/applications/{id}` - Get single application
- `POST /api/dokploy/applications` - Create application
- `POST /api/dokploy/applications/{id}/start` - Start application
- `POST /api/dokploy/applications/{id}/stop` - Stop application
- `POST /api/dokploy/applications/{id}/redeploy` - Redeploy application
- `DELETE /api/dokploy/applications/{id}` - Delete application

**Projects**:
- `GET /api/dokploy/projects` - List all Dokploy projects

**Webhooks**:
- `POST /api/dokploy/webhooks/harbor` - Harbor webhook receiver (public)
- `POST /api/dokploy/webhooks/harbor/test` - Test webhook endpoint

**Connection**:
- `GET /api/dokploy/test-connection` - Test Dokploy API connectivity

### Authentication

Frontend components automatically include authentication:
```javascript
headers: {
    'Accept': 'application/json',
    'Authorization': `Bearer ${localStorage.getItem('api_token')}`,
}
```

---

## Components Architecture

### Main Dashboard
**File**: `resources/js/pages/DokployDashboard.jsx`
**Purpose**: Main dashboard page with tab navigation
**State Management**: Manages active tab, form visibility, selected application

### Application List
**File**: `resources/js/components/Dokploy/DokployApplicationList.jsx`
**Purpose**: Display and manage applications
**Features**: CRUD operations, search, filter, grid layout

### Application Form
**File**: `resources/js/components/Dokploy/DokployApplicationForm.jsx`
**Purpose**: Create/edit application modal
**Features**: Validation, conditional fields, project dropdown

### Deployment Status Monitor
**File**: `resources/js/components/Dokploy/DeploymentStatusMonitor.jsx`
**Purpose**: Real-time status monitoring
**Features**: Auto-refresh (5s), status indicators, activity timeline

### Harbor Webhook Config
**File**: `resources/js/components/Dokploy/HarborWebhookConfig.jsx`
**Purpose**: Webhook setup documentation
**Features**: Copy URL, instructions, test functionality

### Navigation
**File**: `resources/js/components/Navigation.jsx`
**Purpose**: Top navigation bar with routing
**Links**:
- `/` - Infrastructure Dashboard
- `/dokploy` - Dokploy Dashboard

---

## Development

### Running Locally

```bash
# Install dependencies
npm install

# Start development server (hot reload)
npm run dev

# Build for production
npm run build
```

### Testing

Backend tests cover:
- DokployApiClient service (17 tests)
- DokployApplicationController (11 tests)
- DokployWebhookController (7 tests)
- Circuit breaker functionality (1 test)

Run tests:
```bash
php artisan test --filter=Dokploy
```

### Adding New Features

1. **New Component**: Add to `resources/js/components/Dokploy/`
2. **New Page**: Add to `resources/js/pages/`
3. **New Route**: Update `resources/js/app.jsx` and `routes/web.php`
4. **New API Endpoint**: Add to `routes/api.php` and controller

---

## Troubleshooting

### Applications Not Loading
- Check browser console for API errors
- Verify authentication token in localStorage
- Test Dokploy API connection: `/api/dokploy/test-connection`
- Check Laravel logs: `storage/logs/laravel.log`

### Webhook Not Triggering
- Verify webhook URL is correct (copy from dashboard)
- Check Harbor webhook configuration matches instructions
- Test webhook manually: Harbor → Webhooks → Test Endpoint
- Check webhook logs in Laravel (search for "Harbor webhook")
- Verify image name matches exactly between Harbor and Dokploy

### Status Not Updating
- Check network tab for polling requests every 5 seconds
- Verify application ID is valid
- Check Dokploy API is accessible: `curl https://dok.aglz.io/api`

### Form Validation Errors
- Ensure all required fields are filled
- Verify project exists in Dokploy
- Check Docker image format: `registry/namespace/image:tag`

### Build Errors
- Clear npm cache: `npm cache clean --force`
- Delete node_modules and reinstall: `rm -rf node_modules && npm install`
- Check Vite logs during build
- Verify all imports are correct

---

## Security Considerations

- ✅ **Authentication**: All routes require WorkOS authentication
- ✅ **Authorization**: API uses Laravel Sanctum tokens
- ✅ **CSRF Protection**: Enabled for state-changing operations
- ✅ **Input Validation**: All form inputs validated server-side
- ✅ **Webhook Security**: Harbor webhooks don't require authentication (by design)
- ⚠️ **Token Storage**: API tokens stored in localStorage (consider HttpOnly cookies for production)

---

## Performance

- **Auto-refresh Interval**: 5 seconds (configurable via `refreshInterval` prop)
- **Search**: Client-side filtering (consider server-side for large datasets)
- **Lazy Loading**: Components load on tab activation
- **Build Size**: ~337KB JavaScript (compressed: ~107KB gzip)

---

## Future Enhancements

### Planned Features
- [ ] Application logs viewer
- [ ] Deployment history timeline
- [ ] Resource usage metrics (CPU, memory)
- [ ] Domain management
- [ ] Environment variables editor
- [ ] Bulk operations (start/stop multiple)
- [ ] Export configuration as YAML
- [ ] Integration with CI/CD pipelines

### Optimization Opportunities
- [ ] Implement WebSocket for real-time updates (replace polling)
- [ ] Add caching layer for application list
- [ ] Implement virtual scrolling for large application lists
- [ ] Server-side search and pagination
- [ ] Progressive Web App (PWA) support
- [ ] Dark mode

---

## Related Documentation

- **Backend API**: `/docs/DOKPLOY.md` - Complete Dokploy integration guide
- **Infrastructure**: `/docs/INFRA.md` - Infrastructure overview
- **Testing**: `/tests/Feature/DokployIntegrationTest.php` - Test suite

---

## Support

For issues or feature requests:
1. Check Laravel logs: `storage/logs/laravel.log`
2. Review browser console for frontend errors
3. Test Dokploy API connectivity
4. Verify Harbor webhook configuration
5. Contact infrastructure team

---

**Version**: 1.0.0
**Maintainer**: AGL Infrastructure Team
**Last Updated**: 2025-11-12

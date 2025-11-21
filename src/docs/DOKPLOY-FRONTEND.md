# Dokploy Integration Frontend Documentation

> **Version**: 1.0.0
> **Last Updated**: 2025-01-20
> **Status**: Production Ready

## Overview

Comprehensive React/Inertia.js frontend for managing Dokploy deployments across multiple environments (dev, qa, uat, prod). Provides real-time deployment monitoring, pipeline visualization, log streaming, and rollback capabilities.

## Architecture

### Technology Stack

- **Frontend Framework**: React 18+ with hooks
- **Routing**: Inertia.js (server-side routing)
- **Styling**: TailwindCSS + custom components
- **Icons**: Lucide React
- **Date Handling**: date-fns
- **State Management**: React hooks + custom hooks
- **Real-time**: Server-Sent Events (SSE) for log streaming
- **Testing**: Vitest + React Testing Library (components), Pest (backend)

### Directory Structure

```
src/
├── resources/js/
│   ├── Pages/Dokploy/              # Inertia.js pages
│   │   ├── Index.jsx               # Main dashboard
│   │   ├── ProjectShow.jsx         # Project details
│   │   ├── ApplicationShow.jsx     # Application details
│   │   └── DeploymentHistory.jsx   # Deployment timeline
│   ├── Components/Dokploy/         # Reusable components
│   │   ├── ProjectCard.jsx         # Project summary card
│   │   ├── ApplicationCard.jsx     # Application status card
│   │   ├── DeploymentPipeline.jsx  # Visual pipeline (dev→qa→uat→prod)
│   │   ├── DeploymentTimeline.jsx  # Timeline visualization
│   │   ├── DeploymentLogs.jsx      # Live log streaming
│   │   ├── EnvironmentBadge.jsx    # Environment status indicator
│   │   ├── RollbackButton.jsx      # Rollback to previous deployment
│   │   ├── DeployButton.jsx        # Trigger new deployment
│   │   └── DomainManager.jsx       # Domain configuration panel
│   └── hooks/
│       ├── useDokploy.js           # Fetch Dokploy data
│       ├── useDeployment.js        # Deploy/rollback operations
│       └── useDeploymentLogs.js    # Live log streaming
├── app/Http/Controllers/
│   ├── DokployController.php               # Main dashboard & projects
│   ├── DokployApplicationController.php    # Application management
│   └── DokployDeploymentController.php     # Deployment operations
├── routes/
│   └── dokploy.php                 # All Dokploy routes
└── tests/
    ├── Feature/DokployControllerTest.php   # Controller tests (90%+ coverage)
    └── JavaScript/Dokploy/                 # Component tests (70%+ coverage)
        ├── ProjectCard.test.jsx
        └── DeploymentPipeline.test.jsx
```

## Pages

### 1. Dashboard (Index.jsx)

**Route**: `/dokploy`

**Purpose**: Main overview showing all projects with stats and filters

**Features**:
- Grid/List view toggle
- Search projects by name
- Filter by environment (dev/qa/uat/prod)
- Sort by last deployment, status, name
- Project stats (total projects, applications, active deployments, success rate)

**Props**:
```javascript
{
  projects: Array<Project>,
  stats: {
    total_projects: number,
    total_applications: number,
    active_deployments: number,
    success_rate: number
  }
}
```

### 2. Project Show (ProjectShow.jsx)

**Route**: `/dokploy/projects/{id}`

**Purpose**: Single project view with all applications and deployment pipeline

**Features**:
- Deployment pipeline visualization (dev → qa → uat → prod)
- Filter applications by environment
- Application cards with status indicators
- Quick actions (New Application, Settings)

**Props**:
```javascript
{
  project: Project,
  applications: Array<Application>,
  deployments: Array<Deployment>
}
```

### 3. Application Show (ApplicationShow.jsx)

**Route**: `/dokploy/applications/{id}`

**Purpose**: Detailed application view with deployments, logs, and domains

**Features**:
- Tabs: Deployments, Logs, Domains, Settings
- Control buttons: Deploy, Stop, Start, Restart
- Deployment history with rollback
- Live log streaming
- Domain management panel

**Props**:
```javascript
{
  application: Application,
  deployments: Array<Deployment>,
  domains: Array<Domain>,
  project: Project
}
```

### 4. Deployment History (DeploymentHistory.jsx)

**Route**: `/dokploy/deployments/history`

**Purpose**: Complete deployment timeline across all projects

**Features**:
- Filter by environment, status, date range
- Export to CSV
- Deployment stats (total, successful, failed, in progress, success rate)
- Timeline visualization

**Props**:
```javascript
{
  deployments: PaginatedCollection<Deployment>,
  filters: {
    environment: string | null,
    status: string | null,
    dateRange: string | null
  }
}
```

## Components API

### ProjectCard

**Purpose**: Display project summary with applications count and status

**Props**:
```javascript
{
  project: {
    id: number,
    name: string,
    description?: string,
    status: 'active' | 'inactive',
    applications: Array<Application>,
    updated_at: string
  },
  viewMode: 'grid' | 'list' // default: 'grid'
}
```

**Features**:
- Responsive design (mobile-first)
- Two view modes (grid/list)
- Environment badges
- Active/total applications count
- Links to project detail page

### ApplicationCard

**Purpose**: Display application status with deployment info

**Props**:
```javascript
{
  application: {
    id: number,
    name: string,
    app_name: string,
    status: 'running' | 'stopped' | 'error',
    environment: 'dev' | 'qa' | 'uat' | 'prod',
    build_type?: string,
    docker_image?: string,
    last_deployment?: string
  }
}
```

### DeploymentPipeline

**Purpose**: Visual pipeline showing deployment status across environments

**Props**:
```javascript
{
  projectId: string,
  deployments: Array<Deployment>
}
```

**Features**:
- Visual flow: dev → qa → uat → prod
- Color-coded status (green=success, red=failed, yellow=in progress, gray=not deployed)
- Timestamps for each environment
- Animated spinner for in-progress deployments
- Legend with status indicators

### DeploymentTimeline

**Purpose**: Chronological timeline of deployments

**Props**:
```javascript
{
  deployments: Array<Deployment>
}
```

**Features**:
- Timeline visualization with connector lines
- Status icons (CheckCircle, XCircle, Clock, AlertCircle)
- Relative timestamps (formatDistanceToNow)
- Deployment metadata (version, duration, commit SHA)
- Environment badges

### DeploymentLogs

**Purpose**: Live log streaming with filtering and search

**Props**:
```javascript
{
  applicationId: string
}
```

**Features**:
- Live log streaming via SSE
- Auto-scroll to bottom (pause/resume)
- Search logs by keyword
- Filter by level (info/warning/error/debug)
- ANSI color support
- Download logs as .txt file
- Fullscreen mode

### RollbackButton

**Purpose**: Rollback to previous deployment with confirmation

**Props**:
```javascript
{
  applicationId: string,
  deployments: Array<Deployment>, // Previous 10 deployments
  currentDeployment: Deployment
}
```

**Features**:
- Modal dialog with deployment selection
- Shows current deployment highlighted
- Displays deployment details (version, date, status)
- Confirmation before rollback
- Estimated rollback time

### DeployButton

**Purpose**: Trigger new deployment with confirmation

**Props**:
```javascript
{
  applicationId: string,
  onDeploy: () => Promise<void>,
  disabled?: boolean,
  variant?: 'primary' | 'success' | 'secondary'
}
```

**Features**:
- Two-step confirmation
- Loading state with spinner
- Optimistic UI updates
- Variant support for different contexts

### DomainManager

**Purpose**: Manage domain configurations for applications

**Props**:
```javascript
{
  applicationId: string,
  domains: Array<Domain>
}
```

**Features**:
- Add/Edit/Delete domains
- SSL certificate configuration (Let's Encrypt, Custom, None)
- Port and path configuration
- Domain validation
- HTTPS toggle

### EnvironmentBadge

**Purpose**: Color-coded environment indicator

**Props**:
```javascript
{
  environment: 'dev' | 'qa' | 'uat' | 'prod' | 'staging',
  size?: 'xs' | 'sm' | 'md' | 'lg', // default: 'md'
  showBorder?: boolean // default: false
}
```

**Features**:
- Consistent color scheme:
  - dev: blue
  - qa: purple
  - uat: yellow
  - prod: red
  - staging: orange
- Dark mode support
- Multiple sizes

## Custom Hooks

### useDokploy()

**Purpose**: Fetch and manage projects data

**Returns**:
```javascript
{
  projects: Array<Project>,
  loading: boolean,
  error: string | null,
  refresh: () => void
}
```

**Usage**:
```javascript
const { projects, loading, error, refresh } = useDokploy();

useEffect(() => {
  refresh();
}, [someCondition]);
```

### useProject(projectId)

**Purpose**: Fetch single project with applications

**Returns**:
```javascript
{
  project: Project | null,
  applications: Array<Application>,
  loading: boolean,
  error: string | null,
  refresh: () => void
}
```

### useApplication(applicationId)

**Purpose**: Fetch single application with deployments and domains

**Returns**:
```javascript
{
  application: Application | null,
  deployments: Array<Deployment>,
  domains: Array<Domain>,
  loading: boolean,
  error: string | null,
  refresh: () => void
}
```

### useDeployment(applicationId)

**Purpose**: Deploy, stop, restart, rollback operations

**Returns**:
```javascript
{
  deploy: (title?: string, description?: string) => Promise<void>,
  stop: () => Promise<void>,
  restart: () => Promise<void>,
  rollback: (deploymentId: string) => Promise<void>,
  isLoading: boolean,
  error: string | null,
  status: 'deploying' | 'stopped' | 'restarting' | 'rolling_back' | null
}
```

**Usage**:
```javascript
const { deploy, stop, restart, isLoading } = useDeployment(appId);

const handleDeploy = async () => {
  await deploy('New feature', 'Deploy latest changes');
};
```

### useDeploymentStatus(applicationId)

**Purpose**: Poll deployment status every 5 seconds

**Returns**:
```javascript
{
  status: string | null,
  loading: boolean,
  refresh: () => void
}
```

### useDeploymentLogs(applicationId)

**Purpose**: Live log streaming via SSE

**Returns**:
```javascript
{
  logs: Array<LogEntry>,
  isConnected: boolean,
  error: string | null
}
```

**LogEntry**:
```javascript
{
  timestamp: string,
  level: 'info' | 'warn' | 'error' | 'debug',
  message: string
}
```

## Routes

### Inertia Routes (Page Rendering)

```php
GET  /dokploy                       # Dashboard
GET  /dokploy/projects/{id}         # Project details
GET  /dokploy/applications/{id}     # Application details
GET  /dokploy/deployments/history   # Deployment history
```

### API Routes (JSON Responses)

```php
# Application Operations
POST /api/dokploy/applications/{id}/deploy      # Deploy application
POST /api/dokploy/applications/{id}/stop        # Stop application
POST /api/dokploy/applications/{id}/restart     # Restart application
GET  /api/dokploy/applications/{id}/status      # Get status

# Logs
GET  /api/dokploy/applications/{id}/logs        # Get logs (paginated)
GET  /api/dokploy/applications/{id}/logs/stream # Stream logs (SSE)

# Deployments
POST /api/dokploy/deployments/{id}/rollback     # Rollback deployment
POST /api/dokploy/deployments/{id}/cancel       # Cancel deployment
GET  /api/dokploy/deployments/{id}              # Get deployment details
GET  /api/dokploy/deployments/{id}/logs         # Get deployment logs
GET  /api/dokploy/deployments/timeline          # Get timeline
```

## Testing

### Component Tests (Vitest)

**Location**: `tests/JavaScript/Dokploy/`

**Run Tests**:
```bash
npm run test              # Run all tests
npm run test:coverage     # With coverage report
npm run test:watch        # Watch mode
```

**Example**:
```javascript
import { render, screen } from '@testing-library/react';
import ProjectCard from '@/Components/Dokploy/ProjectCard';

test('renders project name', () => {
  render(<ProjectCard project={mockProject} />);
  expect(screen.getByText('Test Project')).toBeInTheDocument();
});
```

**Coverage Target**: 70%+ for components

### Feature Tests (Pest)

**Location**: `tests/Feature/DokployControllerTest.php`

**Run Tests**:
```bash
php artisan test --filter=Dokploy
./vendor/bin/pest --filter=Dokploy
```

**Example**:
```php
test('dashboard renders successfully', function () {
    actingAs($this->user);
    get(route('dokploy.index'))
        ->assertOk()
        ->assertInertia(fn($page) => $page
            ->component('Dokploy/Index')
            ->has('projects')
        );
});
```

**Coverage Target**: 90%+ for controllers

## Styling

### Tailwind Configuration

**Color Scheme**:
- Primary: Blue (blue-600)
- Success: Green (green-600)
- Warning: Yellow (yellow-600)
- Error: Red (red-600)
- Info: Blue (blue-500)

**Dark Mode**: Fully supported via `dark:` prefix

**Responsive Breakpoints**:
- sm: 640px
- md: 768px
- lg: 1024px
- xl: 1280px

### Custom Classes

**Status Badges**:
```javascript
// Success
<span className="bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200 px-3 py-1 rounded-full text-xs font-medium">
  Success
</span>

// Error
<span className="bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200 px-3 py-1 rounded-full text-xs font-medium">
  Error
</span>
```

## Real-time Features

### WebSocket Events (Laravel Reverb)

**Channel**: `deployment.{applicationId}`

**Events**:
```javascript
// Deployment started
{
  event: 'deployment.started',
  data: {
    applicationId: string,
    deploymentId: string,
    timestamp: string
  }
}

// Deployment completed
{
  event: 'deployment.completed',
  data: {
    applicationId: string,
    deploymentId: string,
    status: 'done' | 'error',
    duration: number
  }
}

// Deployment failed
{
  event: 'deployment.failed',
  data: {
    applicationId: string,
    deploymentId: string,
    error: string
  }
}
```

### Server-Sent Events (SSE)

**Endpoint**: `GET /api/dokploy/applications/{id}/logs/stream`

**Usage**:
```javascript
const eventSource = new EventSource(`/api/dokploy/applications/${appId}/logs/stream`);

eventSource.onmessage = (event) => {
  const logEntry = JSON.parse(event.data);
  console.log(logEntry);
};
```

## Performance Optimizations

1. **Lazy Loading**: Pages loaded on-demand via Inertia.js
2. **Memoization**: React.useMemo for expensive computations
3. **Pagination**: Deployments paginated (50 per page)
4. **Debouncing**: Search inputs debounced (300ms)
5. **Caching**: API responses cached (5 minutes)
6. **Code Splitting**: Components loaded asynchronously
7. **Optimistic Updates**: UI updates before API confirmation

## Accessibility

- **ARIA Labels**: All interactive elements
- **Keyboard Navigation**: Full keyboard support
- **Screen Reader**: Proper semantic HTML
- **Focus Management**: Tab order and focus rings
- **Color Contrast**: WCAG 2.1 AA compliant

## Browser Support

- Chrome/Edge: 90+
- Firefox: 88+
- Safari: 14+
- Mobile: iOS 14+, Android 10+

## Troubleshooting

### Common Issues

**1. Logs not streaming**
```javascript
// Check SSE connection
const eventSource = new EventSource(url);
eventSource.onerror = (err) => console.error('SSE error:', err);
```

**2. Deployment not updating**
```javascript
// Force refresh
router.reload({ only: ['deployments'] });
```

**3. Dark mode not working**
```html
<!-- Ensure html has dark class -->
<html class="dark">
```

## Future Enhancements

- [ ] WebSocket-based log streaming (replace SSE)
- [ ] Deployment metrics (CPU, memory, network)
- [ ] Automated rollback on failure
- [ ] Multi-stage deployments (canary, blue-green)
- [ ] Deployment approval workflow
- [ ] Slack/Discord notifications
- [ ] Deployment templates
- [ ] Cost tracking per environment

## Contributing

**Code Style**: Follow existing patterns
**Testing**: Add tests for new features
**Documentation**: Update this file for changes
**Pull Requests**: Include screenshots for UI changes

## Support

**Issues**: GitHub Issues
**Slack**: #dokploy-frontend
**Email**: support@example.com

---

**Last Updated**: 2025-01-20
**Maintainer**: Development Team
**Version**: 1.0.0

/**
 * API Explorer Configuration
 *
 * Customize the API Explorer appearance and behavior
 * by modifying these settings.
 */

// API Configuration
export const apiConfig = {
  // OpenAPI spec URL (relative to this file)
  specUrl: '/api/openapi.yaml',

  // Alternative: Use full spec URL
  // specUrl: 'https://api.agl.com/api/openapi.json',

  // Default server URL
  defaultServer: 'https://api.agl.com/api',

  // Available environments
  servers: [
    {
      url: 'https://api.agl.com/api',
      description: 'Production API'
    },
    {
      url: 'https://api-staging.agl.com/api',
      description: 'Staging API'
    },
    {
      url: 'http://localhost:8000/api',
      description: 'Local Development'
    }
  ]
};

// Swagger UI Configuration
export const swaggerConfig = {
  // DOM element ID
  domId: '#swagger-ui',

  // Layout options
  layout: 'StandaloneLayout',

  // Feature flags
  deepLinking: true,
  showExtensions: true,
  showCommonExtensions: true,

  // Default expansion state
  docExpansion: 'list', // 'list', 'full', 'none'
  defaultModelExpandDepth: 1,
  defaultModelRendering: 'example', // 'example' or 'model'

  // Try It Out
  tryItOutEnabled: true,
  persistAuthorization: true,

  // Syntax highlighting
  syntaxHighlight: {
    activate: true,
    theme: 'monokai'
  },

  // Request/Response
  displayRequestDuration: true,
  displayOperationId: false,
  filter: true,
  maxDisplayedTags: 10,

  // Supported HTTP methods
  supportedSubmitMethods: ['get', 'post', 'put', 'delete', 'patch'],

  // OAuth2
  oauth2RedirectUrl: window.location.origin + '/api-explorer/oauth2-receiver.html',

  // Validation
  validatorUrl: null, // Set to null to disable online validation

  // Plugins
  plugins: [],

  // Presets
  presets: []
};

// ReDoc Configuration
export const redocConfig = {
  // Theme customization
  theme: {
    colors: {
      primary: {
        main: '#3b82f6',
        light: '#60a5fa',
        dark: '#2563eb'
      },
      success: {
        main: '#10b981'
      },
      warning: {
        main: '#f59e0b'
      },
      error: {
        main: '#ef4444'
      },
      text: {
        primary: '#f8fafc',
        secondary: '#94a3b8'
      },
      bg: {
        default: '#0f172a',
        surface: '#1e293b'
      },
      border: {
        light: '#475569',
        dark: '#334155'
      }
    },
    typography: {
      fontFamily: 'Inter, system-ui, -apple-system, sans-serif',
      fontSize: '14px',
      lineHeight: '1.5',
      code: {
        fontFamily: 'JetBrains Mono, monospace',
        fontSize: '13px',
        fontWeight: '400',
        color: '#f8fafc',
        backgroundColor: '#0f172a'
      }
    },
    sidebar: {
      backgroundColor: '#1e293b',
      textColor: '#f8fafc',
      activeTextColor: '#3b82f6',
      width: '280px'
    },
    rightPanel: {
      backgroundColor: '#1e293b'
    },
    codeSample: {
      backgroundColor: '#0f172a'
    },
    http: {
      badgeBackgroundColor: '#334155'
    },
    components: {
      OperationBadge: {
        variant: 'light', // 'light' or 'dark'
      }
    },
    schemaDefinitionsOrder: ['first', 'required']
  },

  // Scroll offset
  scrollYOffset: 80,

  // Expand responses
  expandResponses: 'all', // 'all', 'success', or a status code like '200'

  // Required properties first
  requiredPropsFirst: true,

  // Sort tags alphabetically
  sortTagsAlphabetically: false,

  // Sort operations alphabetically
  sortOperationsAlphabetically: false,

  // Hide hostname
  hideHostname: false,

  // Hide download button
  hideDownloadButton: false,

  // Hide loading
  hideLoading: false,

  // Expand single schema field
  expandSingleSchemaField: false,

  // Native scrollbars
  nativeScrollbars: false,

  // Show extensions
  showObjectSchemaExamples: true,

  // JSON Sample Expand Level
  jsonSampleExpandLevel: 3,

  // Labels for auth operations
  label: 'API Documentation'
};

// Authentication Configuration
export const authConfig = {
  // Storage keys
  storageKeys: {
    apiKey: 'agl_api_key',
    jwtToken: 'agl_jwt_token',
    serverUrl: 'agl_server_url'
  },

  // Session timeout in milliseconds (24 hours)
  sessionTimeout: 24 * 60 * 60 * 1000,

  // Auto-refresh token before expiry
  tokenRefreshThreshold: 5 * 60 * 1000, // 5 minutes

  // Default token header
  tokenHeader: 'Authorization',
  tokenPrefix: 'Bearer',

  // API key header
  apiKeyHeader: 'X-API-Key'
};

// Code Examples Configuration
export const codeExamplesConfig = {
  // Supported languages
  languages: ['curl', 'javascript', 'python', 'php', 'go', 'ruby', 'java'],

  // Default language
  defaultLanguage: 'curl',

  // Include imports
  includeImports: true,

  // Use async/await for JavaScript
  useAsyncAwait: true,

  // Add error handling examples
  includeErrorHandling: true,

  // Add comments
  includeComments: true
};

// Analytics Configuration
export const analyticsConfig = {
  // Enable analytics tracking
  enabled: false,

  // Google Analytics ID
  googleAnalyticsId: '',

  // Track API usage
  trackApiCalls: false,

  // Track endpoint clicks
  trackEndpointClicks: false
};

// UI Configuration
export const uiConfig = {
  // Theme
  theme: 'dark', // 'light' or 'dark'

  // Primary color
  primaryColor: '#3b82f6',

  // Accent color
  accentColor: '#8b5cf6',

  // Font families
  fonts: {
    sans: 'Inter, system-ui, -apple-system, sans-serif',
    mono: 'JetBrains Mono, monospace'
  },

  // Border radius
  borderRadius: {
    sm: '4px',
    md: '8px',
    lg: '12px'
  },

  // Shadows
  shadows: {
    sm: '0 1px 2px rgba(0, 0, 0, 0.3)',
    md: '0 4px 6px rgba(0, 0, 0, 0.4)',
    lg: '0 10px 15px rgba(0, 0, 0, 0.5)'
  },

  // Transitions
  transition: 'all 0.2s cubic-bezier(0.4, 0, 0.2, 1)',

  // Show quick stats
  showStats: true,

  // Show footer
  showFooter: true,

  // Responsive breakpoints
  breakpoints: {
    mobile: 480,
    tablet: 768,
    desktop: 1024
  }
};

// Development Configuration
export const devConfig = {
  // Enable debug mode
  debug: false,

  // Log API requests to console
  logRequests: false,

  // Show performance metrics
  showPerformance: false,

  // Enable hot reload for spec changes
  hotReload: false,

  // Hot reload interval in milliseconds
  hotReloadInterval: 5000
};

// Export all configs
export default {
  api: apiConfig,
  swagger: swaggerConfig,
  redoc: redocConfig,
  auth: authConfig,
  codeExamples: codeExamplesConfig,
  analytics: analyticsConfig,
  ui: uiConfig,
  dev: devConfig
};

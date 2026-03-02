/**
 * Agent Templates and Capability Definitions
 * Expanded agent types with specialized capabilities
 */

class AgentTemplates {
  constructor() {
    this.templates = this.initializeTemplates();
    this.capabilities = this.initializeCapabilities();
  }

  /**
   * Initialize all agent templates
   */
  initializeTemplates() {
    return {
      // Core agents
      researcher: {
        type: 'researcher',
        role: 'Research and Analysis',
        capabilities: ['web-search', 'analysis', 'data-collection', 'fact-checking'],
        baseComplexity: 1,
        resourceRequirements: { cpu: 'low', memory: 'medium' },
        description: 'Specialized in research, data gathering, and analysis'
      },
      coder: {
        type: 'coder',
        role: 'Code Development',
        capabilities: ['coding', 'testing', 'debugging', 'refactoring', 'code-review'],
        baseComplexity: 2,
        resourceRequirements: { cpu: 'medium', memory: 'high' },
        description: 'Expert in software development and code quality'
      },
      analyst: {
        type: 'analyst',
        role: 'Data Analysis',
        capabilities: ['data-analysis', 'visualization', 'statistics', 'reporting'],
        baseComplexity: 1,
        resourceRequirements: { cpu: 'medium', memory: 'medium' },
        description: 'Specialized in data analysis and insights'
      },
      tester: {
        type: 'tester',
        role: 'Quality Assurance',
        capabilities: ['testing', 'qa', 'test-automation', 'validation'],
        baseComplexity: 1,
        resourceRequirements: { cpu: 'low', memory: 'low' },
        description: 'Focused on testing and quality assurance'
      },
      coordinator: {
        type: 'coordinator',
        role: 'Task Coordination',
        capabilities: ['task-distribution', 'monitoring', 'orchestration', 'planning'],
        baseComplexity: 1,
        resourceRequirements: { cpu: 'low', memory: 'medium' },
        description: 'Coordinates and orchestrates multi-agent tasks'
      },

      // Specialized agents (NEW)
      optimizer: {
        type: 'optimizer',
        role: 'Performance Optimization',
        capabilities: ['performance-tuning', 'profiling', 'benchmarking', 'optimization'],
        baseComplexity: 2,
        resourceRequirements: { cpu: 'high', memory: 'high' },
        description: 'Specialized in performance optimization and profiling'
      },
      validator: {
        type: 'validator',
        role: 'Validation and Verification',
        capabilities: ['validation', 'verification', 'compliance', 'audit'],
        baseComplexity: 1,
        resourceRequirements: { cpu: 'low', memory: 'medium' },
        description: 'Ensures compliance and validates system behavior'
      },
      security: {
        type: 'security',
        role: 'Security Analysis',
        capabilities: ['security-scan', 'vulnerability-check', 'penetration-test', 'encryption'],
        baseComplexity: 2,
        resourceRequirements: { cpu: 'medium', memory: 'medium' },
        description: 'Security-focused analysis and vulnerability detection'
      },
      documenter: {
        type: 'documenter',
        role: 'Documentation',
        capabilities: ['documentation', 'api-docs', 'code-comments', 'technical-writing'],
        baseComplexity: 1,
        resourceRequirements: { cpu: 'low', memory: 'low' },
        description: 'Creates and maintains comprehensive documentation'
      },
      devops: {
        type: 'devops',
        role: 'DevOps Engineering',
        capabilities: ['ci-cd', 'deployment', 'infrastructure', 'monitoring'],
        baseComplexity: 2,
        resourceRequirements: { cpu: 'medium', memory: 'high' },
        description: 'DevOps automation and infrastructure management'
      },
      architect: {
        type: 'architect',
        role: 'System Architecture',
        capabilities: ['architecture', 'design-patterns', 'scalability', 'system-design'],
        baseComplexity: 3,
        resourceRequirements: { cpu: 'medium', memory: 'high' },
        description: 'High-level system architecture and design'
      },
      database: {
        type: 'database',
        role: 'Database Specialist',
        capabilities: ['database-design', 'query-optimization', 'migrations', 'data-modeling'],
        baseComplexity: 2,
        resourceRequirements: { cpu: 'medium', memory: 'high' },
        description: 'Database design and optimization specialist'
      },
      frontend: {
        type: 'frontend',
        role: 'Frontend Development',
        capabilities: ['ui-development', 'responsive-design', 'accessibility', 'ux'],
        baseComplexity: 2,
        resourceRequirements: { cpu: 'medium', memory: 'medium' },
        description: 'Frontend development and UI/UX specialist'
      },
      backend: {
        type: 'backend',
        role: 'Backend Development',
        capabilities: ['api-development', 'microservices', 'caching', 'message-queues'],
        baseComplexity: 2,
        resourceRequirements: { cpu: 'medium', memory: 'high' },
        description: 'Backend services and API development'
      },
      ml: {
        type: 'ml',
        role: 'Machine Learning',
        capabilities: ['ml-modeling', 'training', 'inference', 'feature-engineering'],
        baseComplexity: 3,
        resourceRequirements: { cpu: 'high', memory: 'high' },
        description: 'Machine learning and AI model development'
      }
    };
  }

  /**
   * Initialize capability registry
   */
  initializeCapabilities() {
    return {
      // Research capabilities
      'web-search': { category: 'research', priority: 'medium', async: true },
      'analysis': { category: 'research', priority: 'high', async: false },
      'data-collection': { category: 'research', priority: 'medium', async: true },
      'fact-checking': { category: 'research', priority: 'high', async: false },

      // Development capabilities
      'coding': { category: 'development', priority: 'high', async: false },
      'testing': { category: 'development', priority: 'high', async: false },
      'debugging': { category: 'development', priority: 'high', async: false },
      'refactoring': { category: 'development', priority: 'medium', async: false },
      'code-review': { category: 'development', priority: 'medium', async: false },

      // Analysis capabilities
      'data-analysis': { category: 'analysis', priority: 'high', async: false },
      'visualization': { category: 'analysis', priority: 'medium', async: false },
      'statistics': { category: 'analysis', priority: 'medium', async: false },
      'reporting': { category: 'analysis', priority: 'low', async: false },

      // QA capabilities
      'qa': { category: 'quality', priority: 'high', async: false },
      'test-automation': { category: 'quality', priority: 'medium', async: true },
      'validation': { category: 'quality', priority: 'high', async: false },

      // Coordination capabilities
      'task-distribution': { category: 'coordination', priority: 'high', async: false },
      'monitoring': { category: 'coordination', priority: 'medium', async: true },
      'orchestration': { category: 'coordination', priority: 'high', async: false },
      'planning': { category: 'coordination', priority: 'medium', async: false },

      // Performance capabilities (NEW)
      'performance-tuning': { category: 'performance', priority: 'high', async: false },
      'profiling': { category: 'performance', priority: 'medium', async: true },
      'benchmarking': { category: 'performance', priority: 'medium', async: true },
      'optimization': { category: 'performance', priority: 'high', async: false },

      // Validation capabilities (NEW)
      'verification': { category: 'validation', priority: 'high', async: false },
      'compliance': { category: 'validation', priority: 'medium', async: false },
      'audit': { category: 'validation', priority: 'medium', async: true },

      // Security capabilities (NEW)
      'security-scan': { category: 'security', priority: 'high', async: true },
      'vulnerability-check': { category: 'security', priority: 'high', async: true },
      'penetration-test': { category: 'security', priority: 'high', async: true },
      'encryption': { category: 'security', priority: 'high', async: false },

      // Documentation capabilities (NEW)
      'documentation': { category: 'documentation', priority: 'medium', async: false },
      'api-docs': { category: 'documentation', priority: 'medium', async: false },
      'code-comments': { category: 'documentation', priority: 'low', async: false },
      'technical-writing': { category: 'documentation', priority: 'medium', async: false },

      // DevOps capabilities (NEW)
      'ci-cd': { category: 'devops', priority: 'high', async: true },
      'deployment': { category: 'devops', priority: 'high', async: true },
      'infrastructure': { category: 'devops', priority: 'high', async: false },

      // Architecture capabilities (NEW)
      'architecture': { category: 'design', priority: 'high', async: false },
      'design-patterns': { category: 'design', priority: 'medium', async: false },
      'scalability': { category: 'design', priority: 'high', async: false },
      'system-design': { category: 'design', priority: 'high', async: false },

      // Database capabilities (NEW)
      'database-design': { category: 'database', priority: 'high', async: false },
      'query-optimization': { category: 'database', priority: 'high', async: false },
      'migrations': { category: 'database', priority: 'medium', async: false },
      'data-modeling': { category: 'database', priority: 'high', async: false },

      // Frontend capabilities (NEW)
      'ui-development': { category: 'frontend', priority: 'high', async: false },
      'responsive-design': { category: 'frontend', priority: 'medium', async: false },
      'accessibility': { category: 'frontend', priority: 'medium', async: false },
      'ux': { category: 'frontend', priority: 'medium', async: false },

      // Backend capabilities (NEW)
      'api-development': { category: 'backend', priority: 'high', async: false },
      'microservices': { category: 'backend', priority: 'high', async: false },
      'caching': { category: 'backend', priority: 'medium', async: false },
      'message-queues': { category: 'backend', priority: 'medium', async: true },

      // ML capabilities (NEW)
      'ml-modeling': { category: 'ml', priority: 'high', async: false },
      'training': { category: 'ml', priority: 'high', async: true },
      'inference': { category: 'ml', priority: 'high', async: true },
      'feature-engineering': { category: 'ml', priority: 'medium', async: false }
    };
  }

  /**
   * Get agent template by type
   */
  getTemplate(type) {
    return this.templates[type] || null;
  }

  /**
   * Get all available agent types
   */
  getAvailableTypes() {
    return Object.keys(this.templates);
  }

  /**
   * Get agents by capability
   */
  getAgentsByCapability(capability) {
    return Object.entries(this.templates)
      .filter(([_, template]) => template.capabilities.includes(capability))
      .map(([type, template]) => ({ type, ...template }));
  }

  /**
   * Get capability information
   */
  getCapability(capability) {
    return this.capabilities[capability] || null;
  }

  /**
   * Recommend agents for a task based on required capabilities
   */
  recommendAgents(requiredCapabilities, maxAgents = 5) {
    const scores = new Map();

    // Score each agent type
    for (const [type, template] of Object.entries(this.templates)) {
      let score = 0;
      let matchCount = 0;

      for (const reqCap of requiredCapabilities) {
        if (template.capabilities.includes(reqCap)) {
          matchCount++;
          const capInfo = this.capabilities[reqCap];

          // Higher priority capabilities contribute more to score
          switch (capInfo.priority) {
            case 'high': score += 3; break;
            case 'medium': score += 2; break;
            case 'low': score += 1; break;
          }
        }
      }

      // Calculate match percentage
      const matchPercentage = matchCount / requiredCapabilities.length;
      score *= matchPercentage;

      if (score > 0) {
        scores.set(type, { score, matchCount, matchPercentage, template });
      }
    }

    // Sort by score and return top recommendations
    return Array.from(scores.entries())
      .sort((a, b) => b[1].score - a[1].score)
      .slice(0, maxAgents)
      .map(([type, data]) => ({
        type,
        score: data.score,
        matchCount: data.matchCount,
        matchPercentage: (data.matchPercentage * 100).toFixed(1) + '%',
        capabilities: data.template.capabilities,
        description: data.template.description
      }));
  }

  /**
   * Validate agent configuration
   */
  validateAgentConfig(config) {
    const errors = [];

    if (!config.type) {
      errors.push('Agent type is required');
    } else if (!this.templates[config.type]) {
      errors.push(`Unknown agent type: ${config.type}`);
    }

    if (!config.name) {
      errors.push('Agent name is required');
    }

    if (config.capabilities) {
      const template = this.templates[config.type];
      for (const cap of config.capabilities) {
        if (!this.capabilities[cap]) {
          errors.push(`Unknown capability: ${cap}`);
        } else if (template && !template.capabilities.includes(cap)) {
          errors.push(`Capability ${cap} not supported by ${config.type} agent`);
        }
      }
    }

    return {
      valid: errors.length === 0,
      errors
    };
  }

  /**
   * Get resource requirements for agent configuration
   */
  getResourceRequirements(agentConfigs) {
    let totalCpu = 0;
    let totalMemory = 0;

    const cpuMap = { low: 1, medium: 2, high: 4 };
    const memMap = { low: 256, medium: 512, high: 1024 }; // MB

    for (const config of agentConfigs) {
      const template = this.templates[config.type];
      if (template) {
        totalCpu += cpuMap[template.resourceRequirements.cpu] || 1;
        totalMemory += memMap[template.resourceRequirements.memory] || 256;
      }
    }

    return {
      cpu: totalCpu,
      memory: totalMemory,
      estimatedWorkers: Math.min(agentConfigs.length, Math.ceil(totalCpu / 2))
    };
  }
}

module.exports = AgentTemplates;

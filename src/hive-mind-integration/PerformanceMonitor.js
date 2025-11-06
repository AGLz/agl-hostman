/**
 * Performance Monitoring and Dashboard System
 * Real-time metrics collection, visualization, and alerting
 */

const EventEmitter = require('events');
const os = require('os');

class PerformanceMonitor extends EventEmitter {
  constructor(options = {}) {
    super();

    this.options = {
      enableRealtime: options.enableRealtime !== false,
      metricsInterval: options.metricsInterval || 1000, // 1 second
      retentionPeriod: options.retentionPeriod || 3600000, // 1 hour
      alertThresholds: options.alertThresholds || this.getDefaultThresholds(),
      ...options
    };

    this.metrics = {
      system: [],
      agents: new Map(),
      tasks: [],
      neural: [],
      swarms: new Map()
    };

    this.alerts = [];
    this.isMonitoring = false;
    this.metricsTimer = null;
  }

  /**
   * Get default alert thresholds
   */
  getDefaultThresholds() {
    return {
      cpu: {
        warning: 70,  // 70% CPU usage
        critical: 90  // 90% CPU usage
      },
      memory: {
        warning: 75,  // 75% memory usage
        critical: 90  // 90% memory usage
      },
      taskFailureRate: {
        warning: 5,   // 5% failure rate
        critical: 10  // 10% failure rate
      },
      responseTime: {
        warning: 1000,  // 1 second
        critical: 5000  // 5 seconds
      },
      queueDepth: {
        warning: 50,
        critical: 100
      }
    };
  }

  /**
   * Start monitoring
   */
  start() {
    if (this.isMonitoring) {
      return;
    }

    this.isMonitoring = true;

    if (this.options.enableRealtime) {
      this.metricsTimer = setInterval(() => {
        this.collectMetrics();
      }, this.options.metricsInterval);
    }

    this.emit('monitor:started');
  }

  /**
   * Stop monitoring
   */
  stop() {
    if (!this.isMonitoring) {
      return;
    }

    this.isMonitoring = false;

    if (this.metricsTimer) {
      clearInterval(this.metricsTimer);
      this.metricsTimer = null;
    }

    this.emit('monitor:stopped');
  }

  /**
   * Collect system metrics
   */
  collectMetrics() {
    const timestamp = Date.now();

    // System metrics
    const cpuUsage = this.getCpuUsage();
    const memUsage = this.getMemoryUsage();

    const systemMetric = {
      timestamp,
      cpu: cpuUsage,
      memory: memUsage,
      loadAvg: os.loadavg(),
      uptime: os.uptime()
    };

    this.metrics.system.push(systemMetric);
    this.cleanOldMetrics('system');

    // Check thresholds
    this.checkThreshold('cpu', cpuUsage);
    this.checkThreshold('memory', memUsage);

    this.emit('metrics:collected', systemMetric);
  }

  /**
   * Get CPU usage percentage
   */
  getCpuUsage() {
    const cpus = os.cpus();
    let totalIdle = 0;
    let totalTick = 0;

    cpus.forEach(cpu => {
      for (const type in cpu.times) {
        totalTick += cpu.times[type];
      }
      totalIdle += cpu.times.idle;
    });

    const idle = totalIdle / cpus.length;
    const total = totalTick / cpus.length;
    const usage = 100 - ~~(100 * idle / total);

    return usage;
  }

  /**
   * Get memory usage percentage
   */
  getMemoryUsage() {
    const total = os.totalmem();
    const free = os.freemem();
    const used = total - free;
    return (used / total) * 100;
  }

  /**
   * Record agent spawn event
   */
  recordAgentSpawn(agentId, type, duration, success = true) {
    const timestamp = Date.now();

    if (!this.metrics.agents.has(agentId)) {
      this.metrics.agents.set(agentId, {
        id: agentId,
        type,
        spawnedAt: timestamp,
        spawnDuration: duration,
        success,
        tasks: [],
        status: 'active'
      });
    }

    this.emit('agent:spawned', { agentId, type, duration, success });
  }

  /**
   * Record task execution
   */
  recordTaskExecution(taskId, agentId, duration, success = true, error = null) {
    const timestamp = Date.now();

    const taskMetric = {
      taskId,
      agentId,
      timestamp,
      duration,
      success,
      error
    };

    this.metrics.tasks.push(taskMetric);
    this.cleanOldMetrics('tasks');

    // Update agent metrics
    if (agentId && this.metrics.agents.has(agentId)) {
      this.metrics.agents.get(agentId).tasks.push(taskMetric);
    }

    // Check response time threshold
    this.checkThreshold('responseTime', duration);

    this.emit('task:executed', taskMetric);
  }

  /**
   * Record neural training event
   */
  recordNeuralTraining(sessionId, epochs, accuracy, duration) {
    const timestamp = Date.now();

    const neuralMetric = {
      sessionId,
      timestamp,
      epochs,
      accuracy,
      duration
    };

    this.metrics.neural.push(neuralMetric);
    this.cleanOldMetrics('neural');

    this.emit('neural:trained', neuralMetric);
  }

  /**
   * Record swarm activity
   */
  recordSwarmActivity(swarmId, agentCount, activity, metadata = {}) {
    const timestamp = Date.now();

    if (!this.metrics.swarms.has(swarmId)) {
      this.metrics.swarms.set(swarmId, {
        id: swarmId,
        createdAt: timestamp,
        agentCount,
        activities: []
      });
    }

    const swarm = this.metrics.swarms.get(swarmId);
    swarm.activities.push({
      timestamp,
      activity,
      metadata
    });

    this.emit('swarm:activity', { swarmId, activity, metadata });
  }

  /**
   * Check threshold and generate alerts
   */
  checkThreshold(metric, value) {
    if (!this.options.alertThresholds || !this.options.alertThresholds[metric]) {
      return;
    }

    const thresholds = this.options.alertThresholds[metric];
    if (!thresholds) return;

    let level = null;

    if (value >= thresholds.critical) {
      level = 'critical';
    } else if (value >= thresholds.warning) {
      level = 'warning';
    }

    if (level) {
      this.createAlert(metric, value, level);
    }
  }

  /**
   * Create alert
   */
  createAlert(metric, value, level) {
    const alert = {
      id: `alert-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      timestamp: Date.now(),
      metric,
      value,
      level,
      threshold: this.options.alertThresholds[metric][level],
      acknowledged: false
    };

    this.alerts.push(alert);
    this.emit('alert:created', alert);

    // Keep only last 100 alerts
    if (this.alerts.length > 100) {
      this.alerts = this.alerts.slice(-100);
    }
  }

  /**
   * Get dashboard data
   */
  getDashboard() {
    const now = Date.now();
    const last5Min = now - 300000; // 5 minutes
    const last1Hour = now - 3600000; // 1 hour

    // Recent system metrics
    const recentSystemMetrics = this.metrics.system.filter(m => m.timestamp > last5Min);

    // Agent statistics
    const activeAgents = Array.from(this.metrics.agents.values())
      .filter(a => a.status === 'active');

    const agentsByType = {};
    activeAgents.forEach(agent => {
      agentsByType[agent.type] = (agentsByType[agent.type] || 0) + 1;
    });

    // Task statistics
    const recentTasks = this.metrics.tasks.filter(t => t.timestamp > last1Hour);
    const successfulTasks = recentTasks.filter(t => t.success).length;
    const failedTasks = recentTasks.length - successfulTasks;
    const avgTaskDuration = recentTasks.length > 0
      ? recentTasks.reduce((sum, t) => sum + t.duration, 0) / recentTasks.length
      : 0;

    // Neural training statistics
    const recentNeural = this.metrics.neural.filter(n => n.timestamp > last1Hour);
    const avgAccuracy = recentNeural.length > 0
      ? recentNeural.reduce((sum, n) => sum + n.accuracy, 0) / recentNeural.length
      : 0;

    // Active alerts
    const activeAlerts = this.alerts.filter(a => !a.acknowledged);
    const criticalAlerts = activeAlerts.filter(a => a.level === 'critical');
    const warningAlerts = activeAlerts.filter(a => a.level === 'warning');

    return {
      timestamp: now,
      system: {
        current: recentSystemMetrics[recentSystemMetrics.length - 1] || null,
        history: recentSystemMetrics,
        averages: this.calculateAverages(recentSystemMetrics)
      },
      agents: {
        total: this.metrics.agents.size,
        active: activeAgents.length,
        byType: agentsByType,
        topPerformers: this.getTopPerformingAgents(5)
      },
      tasks: {
        total: recentTasks.length,
        successful: successfulTasks,
        failed: failedTasks,
        failureRate: recentTasks.length > 0 ? (failedTasks / recentTasks.length * 100).toFixed(2) : 0,
        avgDuration: avgTaskDuration.toFixed(2)
      },
      neural: {
        sessions: recentNeural.length,
        avgAccuracy: (avgAccuracy * 100).toFixed(2),
        totalEpochs: recentNeural.reduce((sum, n) => sum + n.epochs, 0)
      },
      swarms: {
        total: this.metrics.swarms.size,
        active: Array.from(this.metrics.swarms.values()).filter(s => s.activities.length > 0).length
      },
      alerts: {
        total: activeAlerts.length,
        critical: criticalAlerts.length,
        warning: warningAlerts.length,
        recent: activeAlerts.slice(-10)
      }
    };
  }

  /**
   * Calculate averages for metrics
   */
  calculateAverages(metrics) {
    if (metrics.length === 0) return null;

    const avg = {
      cpu: 0,
      memory: 0,
      loadAvg: [0, 0, 0]
    };

    metrics.forEach(m => {
      avg.cpu += m.cpu;
      avg.memory += m.memory;
      avg.loadAvg[0] += m.loadAvg[0];
      avg.loadAvg[1] += m.loadAvg[1];
      avg.loadAvg[2] += m.loadAvg[2];
    });

    const count = metrics.length;
    return {
      cpu: (avg.cpu / count).toFixed(2),
      memory: (avg.memory / count).toFixed(2),
      loadAvg: [
        (avg.loadAvg[0] / count).toFixed(2),
        (avg.loadAvg[1] / count).toFixed(2),
        (avg.loadAvg[2] / count).toFixed(2)
      ]
    };
  }

  /**
   * Get top performing agents
   */
  getTopPerformingAgents(limit = 5) {
    return Array.from(this.metrics.agents.values())
      .filter(a => a.tasks.length > 0)
      .map(a => ({
        id: a.id,
        type: a.type,
        tasksCompleted: a.tasks.filter(t => t.success).length,
        tasksFailed: a.tasks.filter(t => !t.success).length,
        avgDuration: (a.tasks.reduce((sum, t) => sum + t.duration, 0) / a.tasks.length).toFixed(2),
        successRate: ((a.tasks.filter(t => t.success).length / a.tasks.length) * 100).toFixed(2)
      }))
      .sort((a, b) => b.successRate - a.successRate)
      .slice(0, limit);
  }

  /**
   * Clean old metrics beyond retention period
   */
  cleanOldMetrics(type) {
    const cutoff = Date.now() - this.options.retentionPeriod;

    if (Array.isArray(this.metrics[type])) {
      this.metrics[type] = this.metrics[type].filter(m => m.timestamp > cutoff);
    }
  }

  /**
   * Acknowledge alert
   */
  acknowledgeAlert(alertId) {
    const alert = this.alerts.find(a => a.id === alertId);
    if (alert) {
      alert.acknowledged = true;
      alert.acknowledgedAt = Date.now();
      this.emit('alert:acknowledged', alert);
    }
  }

  /**
   * Get metrics summary
   */
  getSummary() {
    const dashboard = this.getDashboard();

    return {
      status: dashboard.alerts.critical > 0 ? 'critical' :
              dashboard.alerts.warning > 0 ? 'warning' : 'healthy',
      uptime: os.uptime(),
      monitoring: this.isMonitoring,
      agents: {
        total: dashboard.agents.total,
        active: dashboard.agents.active
      },
      tasks: {
        completed: dashboard.tasks.successful,
        failureRate: dashboard.tasks.failureRate + '%'
      },
      performance: {
        cpu: dashboard.system.current?.cpu.toFixed(2) + '%',
        memory: dashboard.system.current?.memory.toFixed(2) + '%'
      },
      alerts: {
        critical: dashboard.alerts.critical,
        warning: dashboard.alerts.warning
      }
    };
  }

  /**
   * Export metrics data
   */
  exportMetrics(format = 'json') {
    const data = {
      exportedAt: Date.now(),
      system: this.metrics.system,
      agents: Array.from(this.metrics.agents.entries()),
      tasks: this.metrics.tasks,
      neural: this.metrics.neural,
      swarms: Array.from(this.metrics.swarms.entries()),
      alerts: this.alerts
    };

    if (format === 'json') {
      return JSON.stringify(data, null, 2);
    }

    return data;
  }

  /**
   * Reset all metrics
   */
  reset() {
    this.metrics = {
      system: [],
      agents: new Map(),
      tasks: [],
      neural: [],
      swarms: new Map()
    };
    this.alerts = [];
    this.emit('metrics:reset');
  }
}

module.exports = PerformanceMonitor;

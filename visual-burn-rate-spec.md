# Visual Burn Rate Feature Specification

## Overview

The Visual Burn Rate feature provides real-time visual indicators of system resource utilization directly in statuslines across multiple environments (vim, tmux, shell, custom applications). It transforms raw system metrics into intuitive visual representations that help users understand system load at a glance.

## Core Concept

**Burn Rate** = Weighted average of system resource utilization over a configurable time window, expressed as a percentage from 0-100%.

### Key Principles

1. **Real-time Visualization**: Updates continuously with minimal performance impact
2. **Universal Integration**: Works across vim, tmux, shell prompts, and custom applications
3. **Intuitive Design**: Visual indicators that immediately convey system state
4. **Configurable Thresholds**: User-defined levels for different alert states
5. **Performance Conscious**: Minimal overhead on system resources

## Technical Specification

### Data Collection Engine

```python
class BurnRateCalculator:
    def __init__(self, config):
        self.config = config
        self.history = deque(maxlen=config.history_length)
        self.weights = config.calculation.weights
        self.smoothing = SmoothingFilter(config.smoothing)

    def collect_metrics(self):
        """Collect system metrics based on configuration"""
        metrics = {}

        if self.config.metrics.cpu_enabled:
            metrics['cpu'] = psutil.cpu_percent(interval=None)

        if self.config.metrics.memory_enabled:
            mem = psutil.virtual_memory()
            metrics['memory'] = mem.percent

        if self.config.metrics.disk_io_enabled:
            disk = psutil.disk_io_counters()
            metrics['disk_io'] = self.calculate_disk_usage(disk)

        if self.config.metrics.network_enabled:
            net = psutil.net_io_counters()
            metrics['network'] = self.calculate_network_usage(net)

        return metrics

    def calculate_burn_rate(self):
        """Calculate weighted burn rate from collected metrics"""
        metrics = self.collect_metrics()

        # Apply weights and calculate weighted average
        weighted_sum = 0
        total_weight = 0

        for metric, value in metrics.items():
            if metric in self.weights:
                weight = self.weights[metric]
                weighted_sum += value * weight
                total_weight += weight

        raw_burn_rate = weighted_sum / total_weight if total_weight > 0 else 0

        # Apply smoothing
        smoothed_rate = self.smoothing.apply(raw_burn_rate)

        # Store in history
        self.history.append({
            'timestamp': time.time(),
            'raw_rate': raw_burn_rate,
            'smoothed_rate': smoothed_rate,
            'metrics': metrics
        })

        return smoothed_rate
```

### Visual Indicator Generator

```python
class VisualIndicatorGenerator:
    def __init__(self, config):
        self.config = config
        self.style = config.indicators.style
        self.width = config.indicators.width
        self.colors = config.indicators.colors

    def generate_indicator(self, burn_rate):
        """Generate visual indicator based on burn rate and style"""

        # Determine color based on thresholds
        color = self.get_color(burn_rate)

        # Generate indicator based on style
        if self.style == "bar":
            return self.generate_bar(burn_rate, color)
        elif self.style == "dots":
            return self.generate_dots(burn_rate, color)
        elif self.style == "blocks":
            return self.generate_blocks(burn_rate, color)
        elif self.style == "ascii":
            return self.generate_ascii(burn_rate, color)

    def generate_bar(self, burn_rate, color):
        """Generate horizontal bar indicator"""
        filled_width = int((burn_rate / 100) * self.width)
        empty_width = self.width - filled_width

        filled_bar = "█" * filled_width
        empty_bar = "░" * empty_width

        return f"{color}{filled_bar}{empty_bar}"

    def generate_dots(self, burn_rate, color):
        """Generate dot pattern indicator"""
        dots_count = int((burn_rate / 100) * self.width)
        dots = "●" * dots_count
        spaces = " " * (self.width - dots_count)

        return f"{color}{dots}{spaces}"

    def get_color(self, burn_rate):
        """Determine color based on burn rate thresholds"""
        thresholds = self.config.thresholds

        if burn_rate >= thresholds.critical:
            return self.colors.critical
        elif burn_rate >= thresholds.high:
            return self.colors.high
        elif burn_rate >= thresholds.medium:
            return self.colors.medium
        else:
            return self.colors.low
```

### Environment Integration Adapters

#### Vim Integration

```python
class VimStatuslineAdapter:
    def __init__(self, config, burn_rate_engine):
        self.config = config.environments.vim
        self.engine = burn_rate_engine

    def generate_statusline(self):
        """Generate vim-compatible statusline string"""
        if not self.config.enabled:
            return ""

        burn_rate = self.engine.get_current_burn_rate()
        visual_indicator = self.engine.get_visual_indicator(burn_rate)

        components = {}

        # Build component dictionary
        if self.config.components.burn_rate.enabled:
            components['burn_rate'] = self.format_burn_rate_component(
                burn_rate, visual_indicator
            )

        # Format according to template
        return self.config.format.format(**components)

    def format_burn_rate_component(self, burn_rate, visual_indicator):
        """Format burn rate component for vim statusline"""
        format_str = self.config.components.burn_rate.format

        return format_str.format(
            visual_indicator=visual_indicator,
            percentage=int(burn_rate)
        )
```

#### Tmux Integration

```python
class TmuxStatuslineAdapter:
    def __init__(self, config, burn_rate_engine):
        self.config = config.environments.tmux
        self.engine = burn_rate_engine

    def generate_status_segments(self):
        """Generate tmux status segments"""
        if not self.config.enabled:
            return {}, {}

        burn_rate = self.engine.get_current_burn_rate()
        visual_indicator = self.engine.get_visual_indicator(burn_rate)

        left_segment = self.format_left_segment(burn_rate, visual_indicator)
        right_segment = self.format_right_segment(burn_rate, visual_indicator)

        return left_segment, right_segment
```

### Performance Optimization

```python
class PerformanceOptimizer:
    def __init__(self, config):
        self.config = config.performance
        self.cache = {}
        self.last_update = 0

    def should_update(self):
        """Determine if update is needed based on cache duration"""
        now = time.time()
        return (now - self.last_update) * 1000 >= self.config.cache_duration

    def get_cached_or_calculate(self, calculator_func):
        """Get cached result or calculate new one"""
        if not self.should_update():
            return self.cache.get('burn_rate', 0)

        result = calculator_func()
        self.cache['burn_rate'] = result
        self.last_update = time.time()

        return result
```

## Implementation Phases

### Phase 1: Core Engine (Week 1)
- [ ] Data collection system
- [ ] Burn rate calculation algorithm
- [ ] Basic visual indicator generation
- [ ] Configuration parser
- [ ] Unit tests for core functionality

### Phase 2: Environment Integration (Week 2)
- [ ] Vim statusline integration
- [ ] Tmux statusline integration
- [ ] Shell prompt integration
- [ ] Basic error handling

### Phase 3: Advanced Features (Week 3)
- [ ] Animation and transitions
- [ ] Alert system
- [ ] Custom themes
- [ ] Performance optimization
- [ ] Configuration validation

### Phase 4: Polish and Distribution (Week 4)
- [ ] Documentation
- [ ] Installation scripts
- [ ] User customization system
- [ ] Testing across different environments
- [ ] Package for distribution

## API Specifications

### Configuration API
```yaml
# Minimal configuration
visual_burn_rate:
  enabled: true
  update_interval: 1000

# Full configuration
visual_burn_rate:
  enabled: true
  update_interval: 1000
  history_length: 60
  thresholds:
    low: 30
    medium: 70
    high: 90
    critical: 95
  indicators:
    style: "bar"
    width: 10
    colors:
      low: "#00ff00"
      medium: "#ffff00"
      high: "#ff8800"
      critical: "#ff0000"
```

### Runtime API
```python
# Python API
from statusline import BurnRateEngine

engine = BurnRateEngine(config)
burn_rate = engine.get_current_burn_rate()  # Returns: 0-100
visual = engine.get_visual_indicator()      # Returns: "████░░░░░░"
color = engine.get_current_color()         # Returns: "#ffff00"

# Shell API (via command line tool)
$ statusline --burn-rate
75

$ statusline --visual-indicator
████████░░

$ statusline --format "🔥{visual} {percentage}%"
🔥████████░░ 75%
```

### Integration Hooks
```python
# Pre/post update hooks
def on_burn_rate_update(burn_rate, visual_indicator):
    # Custom logic when burn rate updates
    pass

def on_critical_threshold(burn_rate):
    # Alert logic when critical threshold reached
    notify_user(f"High system load: {burn_rate}%")

def on_recovery(burn_rate):
    # Logic when system recovers from high load
    log_recovery_event(burn_rate)
```

## Error Handling Strategy

### Graceful Degradation
1. **Missing Dependencies**: Fall back to basic CPU monitoring if advanced metrics unavailable
2. **Permission Issues**: Reduce to user-space metrics only
3. **Configuration Errors**: Use safe defaults with warning messages
4. **Resource Constraints**: Reduce update frequency automatically

### Error Categories
- **Configuration Errors**: Invalid YAML, missing required fields
- **System Errors**: Permission denied, missing tools (psutil, etc.)
- **Integration Errors**: Vim/tmux compatibility issues
- **Performance Errors**: High CPU usage from monitoring itself

## Security Considerations

### Resource Access
- Read-only access to system metrics
- No privileged operations required
- Optional metrics require appropriate permissions

### Configuration Security
- Validate all configuration inputs
- Sanitize script paths and commands
- Restrict file access to user's home directory

### Performance Security
- Memory usage limits
- CPU usage monitoring of self
- Automatic throttling under high system load

## Testing Strategy

### Unit Tests
- Burn rate calculation accuracy
- Visual indicator generation
- Configuration parsing
- Error handling

### Integration Tests
- Vim statusline rendering
- Tmux status bar updates
- Shell prompt integration
- Cross-platform compatibility

### Performance Tests
- Resource usage under various loads
- Update frequency optimization
- Memory leak detection
- Long-running stability

### User Acceptance Tests
- Visual clarity across different terminals
- Responsiveness to system changes
- Configuration ease of use
- Documentation completeness
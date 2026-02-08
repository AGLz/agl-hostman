# Statusline Customization Guide

## Overview

The AGL HostMan Statusline is a comprehensive real-time display system that provides visibility into your development environment, project status, system metrics, and AI/ML capabilities. This guide covers how to customize every aspect of the statusline to match your preferences and workflow needs.

## Quick Start

```bash
# View current statusline configuration
echo $STATUSLINE_CONFIG

# Apply a custom theme
echo 'theme="dark"' > ~/.claude/statusline.conf

# Test new configuration
./statusline-command.sh
```

## 1. Color Scheme Customization

### Pre-defined Color Themes

The statusline includes several built-in themes that you can apply:

#### Light Theme
```json
{
  "colors": {
    "primary": "#2c3e50",
    "secondary": "#34495e",
    "accent": "#3498db",
    "success": "#27ae60",
    "warning": "#f39c12",
    "error": "#e74c3c",
    "background": "#ecf0f1",
    "text": "#2c3e50"
  }
}
```

#### Dark Theme
```json
{
  "colors": {
    "primary": "#34495e",
    "secondary": "#2c3e50",
    "accent": "#3498db",
    "success": "#27ae60",
    "warning": "#f39c12",
    "error": "#e74c3c",
    "background": "#1a1a1a",
    "text": "#ecf0f1"
  }
}
```

#### Solarized Dark
```json
{
  "colors": {
    "primary": "#657b83",
    "secondary": "#93a1a1",
    "accent": "#268bd2",
    "success": "#2aa198",
    "warning": "#cb4b16",
    "error": "#dc322f",
    "background": "#002b36",
    "text": "#839496"
  }
}
```

### Custom Color Creation

Create your own color scheme by modifying the color mapping in the statusline script:

```bash
# Edit the color mapping section
nano /mnt/overpower/apps/dev/agl/agl-hostman/.claude/statusline-command.sh

# Find and modify these sections:
# Line 67: Model name color
# Line 70: Environment color
# Line 74: Project name color
# Line 75: Branch color
# Line 108-111: Git status colors
# Line 243-253: Zone indicator colors
```

### ANSI Color Reference

The statusline uses ANSI escape codes for colors:

```bash
# Text Colors
30m  Black
31m  Red
32m  Green
33m  Yellow
34m  Blue
35m  Magenta
36m  Cyan
37m  White
90m  Bright Black (Gray)
91m  Bright Red
92m  Bright Green
93m  Bright Yellow
94m  Bright Blue
95m  Bright Magenta
96m  Bright Cyan
97m  Bright White

# Text Styles
1m   Bold
0m   Reset
2m   Dim
```

## 2. Emoji Customization

### Default Emoji Set

The statusline uses these emojis by default:

| Component | Emoji | Purpose |
|-----------|-------|---------|
| Model | 🤖 | AI/Model indicator |
| Branch | ⎇ | Git branch |
| Environment | 🐳 | Container |
| Smart Zone | ✓ | Optimal token usage |
| Dumb Zone | ⚠ | Caution needed |
| Wrap Zone | ⚠⚠ | Critical zone |
| DDD Progress | 🏗️ | Domain-driven design |
| Swarm | 🤖 | Agent coordination |
| Intelligence | 🧠 | Learning progress |
| Security | 🟢/🟡/🔴 | Security status |
| Memory | 💾 | Memory usage |
| Cost | 💰 | Token cost estimate |
| MCP | 🔌 | MCP connections |
| GitHub | 📋 | PR count |
| Reset | ⏰ | Time until reset |

### Custom Emoji Replacement

To change emojis, edit the emoji mappings:

```bash
# In statusline-command.sh:
# Line 46-50: Special project branding
case "$PROJECT_NAME" in
  "claude-code-flow") PROJECT_NAME="🌊 Claude Flow" ;;
  "agl-hostman") PROJECT_NAME="🚀 AGL HostMan" ;;
  "gemini-flow") PROJECT_NAME="💎 Gemini Flow" ;;
esac

# Add your custom mappings:
case "$PROJECT_NAME" in
  "my-project") PROJECT_NAME="⭐ My Project" ;;
  "webapp") PROJECT_NAME="🌐 Web App" ;;
esac
```

### Emoji Theme Sets

Create different emoji themes for various contexts:

#### Minimal Theme
```json
{
  "emojis": {
    "model": "C",
    "branch": "B",
    "environment": "E",
    "smart": "+",
    "dumb": "-",
    "wrap": "!!",
    "ddd": "D",
    "swarm": "A",
    "intelligence": "Q",
    "security": "S",
    "memory": "M",
    "cost": "$",
    "mcp": "P",
    "github": "G",
    "reset": "R"
  }
}
```

#### Modern Theme
```json
{
  "emojis": {
    "model": "🔮",
    "branch": "🌿",
    "environment": "🏠",
    "smart": "✨",
    "dumb": "⚡",
    "wrap": "🚨",
    "ddd": "🏛️",
    "swarm": "🦋",
    "intelligence": "🎯",
    "security": "🔒",
    "memory": "💿",
    "cost": "💵",
    "mcp": "🔌",
    "github": "🔗",
    "reset": "⏳"
  }
}
```

## 3. Metric Display Options

### Metric Visibility Control

Control which metrics are displayed by setting environment variables:

```bash
# Show/hide specific metrics
export STATUSLINE_SHOW_TOKENS=true
export STATUSLINE_SHOW_GIT=true
export STATUSLINE_SHOW_SWARM=true
export STATUSLINE_SHOW_INTELLIGENCE=true
export STATUSLINE_SHOW_SECURITY=true
export STATUSLINE_SHOW_COST=true
export STATUSLINE_SHOW_MCP=true
export STATUSLINE_SHOW_GITHUB=true

# Compact mode (fewer metrics)
export STATUSLINE_COMPACT=true

# Verbose mode (more metrics)
export STATUSLINE_VERBOSE=true
```

### Metric Format Customization

Customize how metrics are displayed:

```bash
# Token format (default: K for thousands)
export STATUSLINE_TOKEN_FORMAT="K"  # K for thousands, M for millions
export STATUSLINE_TOKEN_PRECISION="1"  # Decimal places

# Memory format
export STATUSLINE_MEMORY_FORMAT="MB"  # MB or GB

# Time format
export STATUSLINE_TIME_FORMAT="HM"  # H:MM or HH:MM
```

### Custom Metrics

Add your own custom metrics by extending the statusline script:

```bash
# Add custom metric section in statusline-command.sh:
# After line 381, add:

# Custom metrics example
if [ -f "/tmp/my-custom-metric.json" ]; then
  CUSTOM_METRIC=$(cat /tmp/my-custom-metric.json | jq -r '.value // "N/A"')
  printf " \033[36m⭐${CUSTOM_METIC}\033[0m"
fi
```

## 4. Environment-Specific Configurations

### Development Environment

```json
{
  "environment": "development",
  "colors": {
    "primary": "#16a085",
    "accent": "#3498db"
  },
  "metrics": {
    "show_tokens": true,
    "show_git": true,
    "show_tests": true
  },
  "emojis": {
    "environment": "💻"
  }
}
```

### Production Environment

```json
{
  "environment": "production",
  "colors": {
    "primary": "#c0392b",
    "accent": "#e74c3c"
  },
  "metrics": {
    "show_tokens": false,
    "show_git": false,
    "show_security": true,
    "show_performance": true
  },
  "emojis": {
    "environment": "🚀"
  }
}
```

### Local Development

```json
{
  "environment": "local",
  "colors": {
    "primary": "#2c3e50",
    "accent": "#27ae60"
  },
  "metrics": {
    "show_tokens": true,
    "show_git": true,
    "show_swarm": false
  },
  "emojis": {
    "environment": "💻"
  }
}
```

### Container/Docker Environment

```json
{
  "environment": "docker",
  "colors": {
    "primary": "#3498db",
    "accent": "#2980b9"
  },
  "metrics": {
    "show_tokens": true,
    "show_git": true,
    "show_environment": true
  },
  "emojis": {
    "environment": "🐳"
  }
}
```

### WSL Environment

```json
{
  "environment": "wsl",
  "colors": {
    "primary": "#8e44ad",
    "accent": "#9b59b6"
  },
  "metrics": {
    "show_tokens": true,
    "show_git": true,
    "show_performance": true
  },
  "emojis": {
    "environment": "🌐"
  }
}
```

## 5. Configuration Files

### Global Configuration (`~/.claude/statusline.conf`)

```bash
# Create global configuration
cat > ~/.claude/statusline.conf << 'EOF'
# Statusline Configuration
theme=dark
emoji_theme=modern
environment=development
show_tokens=true
show_git=true
show_swarm=true
show_intelligence=true
show_security=true
compact=false
verbose=false
EOF
```

### Project Configuration (`.claude/statusline.json`)

```json
{
  "project": {
    "name": "My Project",
    "environment": "development",
    "theme": "dark"
  },
  "display": {
    "metrics": ["tokens", "git", "swarm", "intelligence", "security"],
    "compact": false,
    "order": ["model", "environment", "project", "git", "tokens", "swarm", "intelligence"]
  },
  "colors": {
    "primary": "#3498db",
    "success": "#27ae60",
    "warning": "#f39c12",
    "error": "#e74c3c"
  },
  "emojis": {
    "model": "🤖",
    "environment": "💻",
    "project": "🚀"
  }
}
```

### Environment Variable Configuration

```bash
# Set environment variables for current session
export STATUSLINE_THEME="solarized"
export STATUSLINE_EMOJI_THEME="minimal"
export STATUSLINE_ENVIRONMENT="production"

# Or create an environment file
# .env.statusline
STATUSLINE_THEME=solarized
STATUSLINE_EMOJI_THEME=minimal
STATUSLINE_ENVIRONMENT=production
```

## 6. Advanced Customization

### Custom Scripts Integration

Integrate custom metrics by creating script hooks:

```bash
# Create custom metrics script
mkdir -p ~/.claude/statusline.d

# ~/.claude/statusline.d/custom-metrics.sh
#!/bin/bash

# Custom metric: Build status
if [ -f "package.json" ] && command -v npm >/dev/null 2>&1; then
  if npm test >/dev/null 2>&1; then
    echo "🟢"
  else
    echo "🔴"
  fi
fi

# Custom metric: Docker status
if command -v docker >/dev/null 2>&1; then
  if docker ps >/dev/null 2>&1; then
    echo "🐳 $(docker ps -q | wc -l)"
  fi
fi
```

### Template System

Create templates for different project types:

```bash
# Project templates directory
mkdir -p ~/.claude/statusline/templates

# React template
cat > ~/.claude/statusline/templates/react.json << 'EOF'
{
  "name": "React",
  "patterns": ["*.jsx", "*.tsx", "package.json"],
  "metrics": ["tokens", "git", "tests", "bundle"],
  "colors": {
    "primary": "#61dafb",
    "accent": "#282c34"
  },
  "emojis": {
    "environment": "⚛️",
    "tests": "🧪"
  }
}
EOF

# Node.js template
cat > ~/.claude/statusline/templates/node.json << 'EOF'
{
  "name": "Node.js",
  "patterns": ["package.json", "*.js", "*.ts"],
  "metrics": ["tokens", "git", "deps", "node"],
  "colors": {
    "primary": "#339933",
    "accent": "#68a063"
  },
  "emojis": {
    "environment": "🟢",
    "deps": "📦"
  }
}
EOF
```

### Auto-detection Rules

Set up automatic theme selection based on context:

```bash
# Create auto-detection script
cat > ~/.claude/statusline/auto-detect.sh << 'EOF'
#!/bin/bash

# Auto-detect project type
if [ -f "package.json" ]; then
  if grep -q "react" package.json; then
    STATUSLINE_TEMPLATE="react"
  elif grep -q "node" package.json; then
    STATUSLINE_TEMPLATE="node"
  fi
fi

# Auto-detect environment
if grep -q microsoft /proc/version 2>/dev/null; then
  STATUSLINE_ENVIRONMENT="wsl"
elif [ -f /.dockerenv ]; then
  STATUSLINE_ENVIRONMENT="docker"
fi

# Auto-select theme
if [ "$STATUSLINE_ENVIRONMENT" = "production" ]; then
  STATUSLINE_THEME="dark"
else
  STATUSLINE_THEME="light"
fi
EOF
```

## 7. Performance Optimization

### Refresh Rate Control

Control how often the statusline updates:

```bash
# Set refresh interval (in seconds)
export STATUSLINE_REFRESH_INTERVAL=5

# Disable auto-refresh (manual refresh only)
export STATUSLINE_REFRESH_INTERVAL=0
```

### Caching Mechanism

Enable caching for frequently accessed data:

```bash
# Enable caching
export STATUSLINE_CACHE=true
export STATUSLINE_CACHE_TTL=30  # Cache TTL in seconds

# Disable caching
export STATUSLINE_CACHE=false
```

### Lightweight Mode

Reduce resource usage with lightweight mode:

```bash
# Enable lightweight mode
export STATUSLINE_LIGHTWEIGHT=true

# Lightweight mode disables:
# - Complex calculations
# - Detailed git status
# - System metrics
# - Intelligence calculations
```

## 8. Troubleshooting

### Common Issues

**Colors not showing:**
```bash
# Check terminal color support
tput colors

# Force color mode
export CLICOLOR=1
export CLICOLOR_FORCE=1
```

**Emojis appearing as squares:**
```bash
# Check font support
echo "🚀" | wc -c

# Use terminal that supports emojis
# Recommended: iTerm2, Windows Terminal, modern GNOME Terminal
```

**Slow performance:**
```bash
# Check refresh interval
echo $STATUSLINE_REFRESH_INTERVAL

# Enable lightweight mode
export STATUSLINE_LIGHTWEIGHT=true

# Disable verbose output
export STATUSLINE_VERBOSE=false
```

### Debug Mode

Enable debug mode for troubleshooting:

```bash
# Enable debug output
export STATUSLINE_DEBUG=true

# Run with debug info
./statusline-command.sh 2> debug.log
```

### Log Files

Check statusline logs for issues:

```bash
# View statusline logs
tail -f ~/.claude/statusline.log

# Clear logs
> ~/.claude/statusline.log
```

## 9. Best Practices

### Color Usage Guidelines

- **High contrast**: Ensure text is readable against background
- **Consistency**: Use consistent colors across similar metrics
- **Accessibility**: Consider colorblind-friendly color schemes
- **Grouping**: Use related colors for related metrics

### Emoji Usage Guidelines

- **Meaningful**: Choose emojis that clearly represent the metric
- **Consistency**: Use the same emoji for the same concept
- **Minimal**: Don't overuse emojis - keep it readable
- **Context-aware**: Adjust emojis based on environment

### Performance Best Practices

- **Cache frequently accessed data**
- **Limit complex calculations**
- **Update at reasonable intervals**
- **Provide lightweight options**

### Configuration Management

- **Use environment variables for quick changes**
- **Store custom configurations in version control**
- **Document custom metrics and scripts**
- **Test configurations before deployment**

## 10. Examples

### Example 1: Developer Workflow

```bash
# ~/.claude/statusline.conf
theme=dark
emoji_theme=minimal
environment=development
show_tokens=true
show_git=true
show_swarm=true
show_intelligence=true
compact=false
```

### Example 2: Production Monitoring

```bash
# ~/.claude/statusline.conf
theme=light
emoji_theme=minimal
environment=production
show_tokens=false
show_git=false
show_security=true
show_performance=true
compact=true
```

### Example 3: Container Environment

```bash
# ~/.claude/statusline.conf
theme=solarized-dark
emoji_theme=modern
environment=docker
show_tokens=true
show_git=true
show_environment=true
show_memory=true
compact=false
```

## Custom Templates Repository

Explore and share custom configurations:

```bash
# Browse templates
ls ~/.claude/statusline/templates/

# Add your own template
cp ~/.claude/statusline/templates/react.json ~/.claude/statusline/templates/my-project.json

# Share with community
# GitHub: https://github.com/your-org/statusline-templates
```

## Support

For issues and feature requests:
- Create an issue: [GitHub Issues]
- Documentation: [Statusline Wiki]
- Community: [Discord Channel]

---

*Last Updated: 2026-02-08*
*Version: 2.0.0*

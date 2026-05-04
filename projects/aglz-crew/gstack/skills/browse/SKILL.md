---
name: browse
description: |
  Fast headless browser automation for AGLz AI Agency. Navigate pages, interact with
  elements, verify state, take screenshots, and perform QA testing. Optimized for
  Jarvis O (CEO/COO) and Jarvis H (CPO/CRO) executive agents.
triggers:
  - browse this page
  - take a screenshot
  - navigate to url
  - inspect the page
  - test this site
allowed-tools:
  - Bash
  - Read
  - AskUserQuestion
---

## Quick Start

```bash
# Navigate to a page
$gb goto https://aglz.ai

# Get interactive elements with refs
$gb snapshot -i

# Click by ref
$gb click @e3

# Take screenshot
$gb screenshot /tmp/page.png
```

## Command Reference

### Navigation
| Command | Description |
|---------|-------------|
| `goto <url>` | Navigate to URL |
| `back` | History back |
| `forward` | History forward |
| `reload` | Reload page |
| `url` | Show current URL |

### Reading
| Command | Description |
|---------|-------------|
| `text` | Clean page text |
| `html` | Page HTML |
| `links` | All links as "text → href" |
| `forms` | Form fields as JSON |
| `js <expression>` | Execute JavaScript |

### Interaction
| Command | Description |
|---------|-------------|
| `click <@ref\|selector>` | Click element |
| `fill <@ref> <value>` | Fill input field |
| `select <@ref> <value>` | Select dropdown option |
| `upload <@ref> <file>` | Upload file |
| `type <text>` | Type into focused element |
| `press <key>` | Press key (Enter, Tab, Escape, etc) |
| `scroll [<@ref>]` | Scroll element into view |
| `wait <ms\|selector\|--networkidle>` | Wait for condition |

### Snapshot System
| Command | Description |
|---------|-------------|
| `snapshot [-i]` | Get accessibility tree with @refs |
| `snapshot -i` | Interactive elements only |
| `snapshot -D` | Diff against previous snapshot |
| `snapshot -a` | Annotated screenshot |
| `snapshot -C` | Cursor-interactive elements (@c refs) |

### Visual
| Command | Description |
|---------|-------------|
| `screenshot [path]` | Full page screenshot |
| `pdf [path]` | Save as PDF |
| `responsive [prefix]` | Screenshots at multiple viewports |

### Server
| Command | Description |
|---------|-------------|
| `status` | Show server status |
| `stop` | Stop server |
| `restart` | Restart server |

## A2A Integration

Jarvis O can control Jarvis H's browser:
```bash
# Send browser command to peer agent
/a2a message jarvis-h --type command --content "browse goto https://docs.aglz.ai"

# Query peer's browser status
/a2a query jarvis-h --type browser_status
```

## Examples

### Test Login Flow
```bash
$gb goto https://app.aglz.ai/login
$gb snapshot -i
$gb fill @e3 "admin@aglz.ai"
$gb fill @e4 "password"
$gb click @e5
$gb wait --networkidle
$gb is visible ".dashboard"
$gb screenshot /tmp/login-success.png
```

### QA Check
```bash
$gb goto https://aglz.ai
$gb console
$gb network
$gb screenshot /tmp/homepage.png
$gb responsive /tmp/layout
```

### Multi-step Flow
```bash
# Navigate and interact
$gb goto https://aglz.ai/pricing
$gb snapshot -i
$gb click @e8  # Pricing button
$gb snapshot -D  # See what changed
$gb screenshot /tmp/pricing.png
```

## Ref System

Refs are assigned sequentially during snapshot:
- `@e1`, `@e2`, ... - ARIA tree elements
- `@c1`, `@c2`, ... - Cursor-interactive elements (with -C flag)

Use refs instead of CSS selectors for reliability:
```bash
# Good - uses ref
$gb click @e3

# Avoid - brittle selector
$gb click "button.primary:nth-child(3)"
```

Refs are cleared on navigation. Always run `snapshot` after `goto`.

## Tips

1. **Start with snapshot -i** to see all interactive elements
2. **Use snapshot -D** to verify changes after actions
3. **Check console** after interactions for JS errors
4. **Use wait** after clicks that trigger navigation
5. **Take screenshots** for bug reports and documentation

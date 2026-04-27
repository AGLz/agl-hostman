# GStack Integration for AGLz AI Agency

## Overview

This document describes how the **gstack** methodology from Garry Tan's repository is adapted and applied to the **agl-hostman** project for the AGLz AI Agency.

## What is GStack

GStack is a fast headless browser automation system with the following key components:

1. **Compiled CLI Binary** (~58MB) - Bun-compiled executable
2. **Persistent Browser Daemon** - Long-lived Chromium process
3. **Ref-based Element Selection** - @e1, @e2, @c1 references instead of CSS selectors
4. **HTTP API** - Localhost server with Bearer token auth
5. **Skills System** - Markdown-based skill definitions

## Adaptation for AGLz AI Agency

### 1. Browser Daemon for Jarvis O & H

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         AGLz AI Agency - GStack Layer                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────┐         HTTP/API          ┌─────────────────────────────┐ │
│  │  Jarvis O   │ ◄───────────────────────► │   Browser Daemon (CT-203)   │ │
│  │  (CT-203)   │   localhost:random_port   │   • Chromium (headless)     │ │
│  │             │   Bearer Token Auth       │   • Playwright API          │ │
│  │  gstack CLI │                           │   • Ref mapping (@e1,@e2)   │ │
│  └─────────────┘                           │   • Cookie persistence      │ │
│                                            └─────────────────────────────┘ │
│                                                                             │
│  ┌─────────────┐         HTTP/API          ┌─────────────────────────────┐ │
│  │  Jarvis H   │ ◄───────────────────────► │   Browser Daemon (CT-204)   │ │
│  │  (CT-204)   │   localhost:random_port   │   • Chromium (headless)     │ │
│  │             │   Bearer Token Auth       │   • Playwright API          │ │
│  │  gstack CLI │                           │   • Ref mapping (@e1,@e2)   │ │
│  └─────────────┘                           │   • Cookie persistence      │ │
│                                            └─────────────────────────────┘ │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2. Directory Structure

```
agl-hostman/
├── gstack/                          # GStack integration
│   ├── bin/
│   │   ├── gstack-browser          # Compiled CLI binary
│   │   ├── gstack-ctl              # Control utility
│   │   └── gstack-update-check     # Update checker
│   ├── src/
│   │   ├── cli.ts                  # CLI entry point
│   │   ├── server.ts               # HTTP server (Bun.serve)
│   │   ├── browser-manager.ts      # Chromium lifecycle
│   │   ├── snapshot.ts             # Ref system (@e1, @e2)
│   │   ├── read-commands.ts        # Read operations
│   │   ├── write-commands.ts       # Write operations
│   │   ├── meta-commands.ts        # Meta operations
│   │   └── a2a-protocol.ts         # A2A integration
│   ├── skills/
│   │   ├── browse/
│   │   │   └── SKILL.md            # Browser automation skill
│   │   ├── qa/
│   │   │   └── SKILL.md            # QA testing skill
│   │   ├── ship/
│   │   │   └── SKILL.md            # Deployment skill
│   │   └── investigate/
│   │       └── SKILL.md            # Bug investigation skill
│   ├── config/
│   │   ├── jarvis-o.yaml           # Jarvis O config
│   │   └── jarvis-h.yaml           # Jarvis H config
│   └── docs/
│       └── ARCHITECTURE.md         # This document
├── .gstack/                         # Runtime state (gitignored)
│   ├── browse.json                 # Server state file
│   ├── browse-console.log          # Console logs
│   ├── browse-network.log          # Network logs
│   └── sessions/                   # Session tracking
└── CLAUDE.md                        # Skill routing rules
```

### 3. Key Components

#### 3.1 CLI Binary (gstack-browser)

```typescript
// gstack/src/cli.ts
// Thin client - reads state file, sends HTTP, prints response

import { readFileSync, existsSync } from 'fs';
import { spawn } from 'child_process';

const STATE_FILE = '.gstack/browse.json';
const SERVER_SCRIPT = 'gstack/src/server.ts';

interface ServerState {
  pid: number;
  port: number;
  token: string;
  startedAt: string;
  binaryVersion: string;
}

async function main() {
  const command = process.argv.slice(2);
  
  // Check for running server
  let state: ServerState | null = null;
  if (existsSync(STATE_FILE)) {
    try {
      state = JSON.parse(readFileSync(STATE_FILE, 'utf-8'));
      // Health check
      const healthy = await healthCheck(state.port, state.token);
      if (!healthy) state = null;
    } catch {
      state = null;
    }
  }
  
  // Start server if needed
  if (!state) {
    state = await startServer();
  }
  
  // Send command
  const response = await sendCommand(state, command);
  console.log(response);
}

async function sendCommand(state: ServerState, command: string[]): Promise<string> {
  const response = await fetch(`http://localhost:${state.port}/command`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${state.token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ command })
  });
  return response.text();
}
```

#### 3.2 HTTP Server (server.ts)

```typescript
// gstack/src/server.ts
// Bun.serve HTTP server - routes commands to Playwright

import { serve } from 'bun';
import { BrowserManager } from './browser-manager';
import { handleReadCommand } from './read-commands';
import { handleWriteCommand } from './write-commands';
import { handleMetaCommand } from './meta-commands';

const READ_COMMANDS = new Set([
  'text', 'html', 'links', 'forms', 'accessibility',
  'console', 'network', 'dialog', 'cookies', 'storage',
  'js', 'eval', 'css', 'attrs', 'is', 'perf'
]);

const WRITE_COMMANDS = new Set([
  'goto', 'click', 'fill', 'select', 'hover', 
  'type', 'press', 'scroll', 'wait', 'upload',
  'dialog-accept', 'dialog-dismiss'
]);

const META_COMMANDS = new Set([
  'snapshot', 'screenshot', 'tabs', 'chain',
  'status', 'restart', 'stop', 'handoff', 'resume'
]);

export function startServer(port: number, token: string) {
  const browserManager = new BrowserManager();
  
  serve({
    port,
    async fetch(request) {
      // Auth check
      const auth = request.headers.get('Authorization');
      if (auth !== `Bearer ${token}`) {
        return new Response('Unauthorized', { status: 401 });
      }
      
      const url = new URL(request.url);
      
      if (url.pathname === '/health') {
        return Response.json({ status: 'healthy' });
      }
      
      if (url.pathname === '/command' && request.method === 'POST') {
        const { command } = await request.json();
        const [cmd, ...args] = command;
        
        try {
          let result: string;
          
          if (READ_COMMANDS.has(cmd)) {
            result = await handleReadCommand(cmd, args, browserManager);
          } else if (WRITE_COMMANDS.has(cmd)) {
            result = await handleWriteCommand(cmd, args, browserManager);
          } else if (META_COMMANDS.has(cmd)) {
            result = await handleMetaCommand(cmd, args, browserManager);
          } else {
            return new Response(`Unknown command: ${cmd}`, { status: 400 });
          }
          
          return new Response(result);
        } catch (error) {
          return new Response(`Error: ${error.message}`, { status: 500 });
        }
      }
      
      return new Response('Not Found', { status: 404 });
    }
  });
}
```

#### 3.3 Browser Manager

```typescript
// gstack/src/browser-manager.ts
// Chromium lifecycle - launch, tabs, ref map, crash handling

import { chromium, Browser, Page, BrowserContext } from 'playwright';

export interface RefEntry {
  role: string;
  name: string;
  locator: any; // Playwright Locator
}

export class BrowserManager {
  private browser: Browser | null = null;
  private context: BrowserContext | null = null;
  private pages: Map<number, Page> = new Map();
  private refMap: Map<string, RefEntry> = new Map();
  private currentTabId = 1;
  
  async launch() {
    this.browser = await chromium.launch({
      headless: true,
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage'
      ]
    });
    
    this.context = await this.browser.newContext({
      viewport: { width: 1920, height: 1080 }
    });
    
    // Create initial page
    const page = await this.context.newPage();
    this.pages.set(this.currentTabId, page);
    
    // Setup event handlers
    this.setupEventHandlers(page);
  }
  
  private setupEventHandlers(page: Page) {
    // Clear refs on navigation
    page.on('framenavigated', () => {
      this.refMap.clear();
    });
    
    // Crash handling
    this.browser?.on('disconnected', () => {
      console.error('Browser crashed - exiting');
      process.exit(1);
    });
  }
  
  getPage(tabId?: number): Page {
    const id = tabId || this.currentTabId;
    const page = this.pages.get(id);
    if (!page) throw new Error(`Tab ${id} not found`);
    return page;
  }
  
  setRef(id: string, entry: RefEntry) {
    this.refMap.set(id, entry);
  }
  
  getRef(id: string): RefEntry | undefined {
    return this.refMap.get(id);
  }
  
  clearRefs() {
    this.refMap.clear();
  }
  
  async close() {
    await this.browser?.close();
  }
}
```

#### 3.4 Snapshot System (Ref-based)

```typescript
// gstack/src/snapshot.ts
// Accessibility tree → @ref assignment → Locator map

import { Page } from 'playwright';
import { BrowserManager } from './browser-manager';

interface SnapshotOptions {
  interactive?: boolean;  // -i flag
  compact?: boolean;      // -c flag
  depth?: number;         // -d flag
  selector?: string;      // -s flag
  diff?: boolean;         // -D flag
  annotate?: boolean;     // -a flag
  cursorInteractive?: boolean; // -C flag
}

export async function snapshot(
  page: Page, 
  browserManager: BrowserManager,
  options: SnapshotOptions = {}
): Promise<string> {
  
  // Get accessibility snapshot
  const snapshot = await page.accessibility.snapshot({
    interestingOnly: options.interactive
  });
  
  // Parse and assign refs
  let refCounter = 1;
  const lines: string[] = [];
  
  function traverse(node: any, depth = 0) {
    if (options.depth && depth > options.depth) return;
    
    const indent = '  '.repeat(depth);
    const role = node.role || 'generic';
    const name = node.name || '';
    
    // Assign ref
    const refId = `@e${refCounter++}`;
    
    // Build Playwright locator
    const locator = page.getByRole(role, { name }).nth(0);
    browserManager.setRef(refId.slice(1), { role, name, locator });
    
    // Format output
    const line = `${indent}${refId} [${role}] "${name}"`;
    lines.push(line);
    
    // Traverse children
    if (node.children) {
      for (const child of node.children) {
        traverse(child, depth + 1);
      }
    }
  }
  
  traverse(snapshot);
  
  return lines.join('\n');
}

// Resolve ref to locator with staleness check
export async function resolveRef(
  browserManager: BrowserManager,
  ref: string
): Promise<any> {
  const entry = browserManager.getRef(ref);
  if (!entry) {
    throw new Error(`Ref ${ref} not found. Run 'snapshot' to get fresh refs.`);
  }
  
  // Staleness check
  const count = await entry.locator.count();
  if (count === 0) {
    throw new Error(
      `Ref @${ref} is stale — element no longer exists. ` +
      `Run 'snapshot' to get fresh refs.`
    );
  }
  
  return entry.locator;
}
```

#### 3.5 A2A Protocol Integration

```typescript
// gstack/src/a2a-protocol.ts
// Agent-to-Agent protocol for Jarvis O ↔ Jarvis H communication

import { serve } from 'bun';

interface A2AMessage {
  message_id: string;
  from_agent: string;
  to_agent: string;
  message_type: 'text' | 'task' | 'query' | 'command';
  content: string;
  timestamp: string;
  metadata?: Record<string, any>;
}

interface A2AQuery {
  query_id: string;
  from_agent: string;
  query_type: string;
  parameters: Record<string, any>;
  timestamp: string;
}

export class A2AProtocol {
  private agentId: string;
  private port: number;
  private peers: Map<string, string> = new Map(); // id -> endpoint
  
  constructor(agentId: string, port: number) {
    this.agentId = agentId;
    this.port = port;
  }
  
  registerPeer(id: string, endpoint: string) {
    this.peers.set(id, endpoint);
  }
  
  startServer() {
    serve({
      port: this.port,
      async fetch(request) {
        const url = new URL(request.url);
        
        if (url.pathname === '/a2a/message' && request.method === 'POST') {
          const message: A2AMessage = await request.json();
          return this.handleMessage(message);
        }
        
        if (url.pathname === '/a2a/query' && request.method === 'POST') {
          const query: A2AQuery = await request.json();
          return this.handleQuery(query);
        }
        
        if (url.pathname === '/a2a/status') {
          return Response.json({
            agent: this.agentId,
            status: 'operational',
            peers: Array.from(this.peers.keys())
          });
        }
        
        return new Response('Not Found', { status: 404 });
      }
    });
  }
  
  async sendMessage(toAgent: string, message: A2AMessage): Promise<any> {
    const endpoint = this.peers.get(toAgent);
    if (!endpoint) {
      throw new Error(`Peer ${toAgent} not registered`);
    }
    
    const response = await fetch(`${endpoint}/a2a/message`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(message)
    });
    
    return response.json();
  }
  
  private handleMessage(message: A2AMessage): Response {
    // Log message
    console.log(`[A2A] ${message.from_agent} -> ${message.to_agent}: ${message.content}`);
    
    // Process based on type
    switch (message.message_type) {
      case 'command':
        // Execute browser command
        return this.handleBrowserCommand(message.content);
      case 'task':
        // Queue task
        return Response.json({ status: 'accepted', task_id: message.message_id });
      default:
        return Response.json({ status: 'received' });
    }
  }
  
  private handleBrowserCommand(content: string): Response {
    // Parse command and execute via browser manager
    // This allows one agent to control another's browser
    return Response.json({ status: 'executed' });
  }
}
```

### 4. Skills for AGLz

#### 4.1 Browse Skill

```markdown
---
name: browse
description: |
  Fast headless browser for QA testing and site automation. Navigate pages, 
  interact with elements, verify state, diff before/after, take annotated 
  screenshots. Use when asked to open or test a site, verify a deployment, 
  or file a bug with screenshots.
allowed-tools:
  - Bash
  - Read
  - AskUserQuestion
triggers:
  - browse this page
  - take a screenshot
  - navigate to url
  - inspect the page
---

## Quick Start

```bash
# Navigate to a page
$g goto https://example.com

# Get interactive elements
$g snapshot -i

# Click by ref
$g click @e3

# Take screenshot
$g screenshot /tmp/page.png
```

## Commands

### Navigation
- `goto <url>` - Navigate to URL
- `back`, `forward`, `reload` - Browser navigation
- `url` - Show current URL

### Reading
- `text` - Clean page text
- `html` - Page HTML
- `links` - All links
- `forms` - Form fields

### Interaction
- `click <@ref|selector>` - Click element
- `fill <@ref> <value>` - Fill input
- `select <@ref> <value>` - Select dropdown
- `upload <@ref> <file>` - Upload file

### Snapshot
- `snapshot -i` - Interactive elements with @refs
- `snapshot -D` - Diff against previous
- `snapshot -a -o file.png` - Annotated screenshot

## A2A Integration

Jarvis O can command Jarvis H's browser:
```bash
/a2a message jarvis-h "browse goto https://dashboard.aglz.ai"
```
```

#### 4.2 QA Skill

```markdown
---
name: qa
description: |
  Comprehensive QA testing skill. Test user flows, verify functionality,
  catch regressions. Generates test reports with evidence.
triggers:
  - test this
  - does this work
  - qa check
---

## QA Methodology

1. **Navigate** to starting page
2. **Snapshot** to understand current state
3. **Execute** test steps
4. **Verify** with assertions
5. **Document** with screenshots

## Example Flow

```bash
# 1. Navigate
$g goto https://app.aglz.ai/login

# 2. Baseline snapshot
$g snapshot -i

# 3. Execute login
$g fill @e3 "test@aglz.ai"
$g fill @e4 "password"
$g click @e5

# 4. Verify
$g is visible ".dashboard"
$g snapshot -D  # Diff shows what changed

# 5. Document
$g screenshot /tmp/login-success.png
```

## A2A Distributed QA

Jarvis O can coordinate QA across agents:
```bash
# Delegate to Jarvis H
/a2a delegate jarvis-h "qa test https://api.aglz.ai/health"

# Check all team agents
/a2a broadcast "qa status"
```
```

### 5. Configuration Files

#### 5.1 Jarvis O Config

```yaml
# gstack/config/jarvis-o.yaml
agent:
  name: "Jarvis O"
  codename: "OpenClaw"
  role: "CEO/COO"
  ct_id: "CT-203"
  
browser:
  headless: true
  viewport: { width: 1920, height: 1080 }
  
a2a:
  port: 8080
  peers:
    - id: "jarvis-h"
      endpoint: "http://192.168.0.204:8080"
      role: "cpo_cro"
    - id: "agl-crew"
      endpoint: "http://192.168.0.205:8080"
      role: "scrum_teams"

skills:
  - browse
  - qa
  - ship
  - investigate
```

#### 5.2 Jarvis H Config

```yaml
# gstack/config/jarvis-h.yaml
agent:
  name: "Jarvis H"
  codename: "Hermes"
  role: "CPO/CRO"
  ct_id: "CT-204"
  
browser:
  headless: true
  viewport: { width: 1920, height: 1080 }
  
a2a:
  port: 8080
  peers:
    - id: "jarvis-o"
      endpoint: "http://192.168.0.203:8080"
      role: "ceo_coo"
    - id: "agl-crew"
      endpoint: "http://192.168.0.205:8080"
      role: "scrum_teams"

skills:
  - browse
  - qa
  - research
  - design-review
```

### 6. Installation

```bash
#!/bin/bash
# install-gstack.sh

set -e

echo "=== Installing GStack for AGLz AI Agency ==="

# Install Bun
curl -fsSL https://bun.sh/install | bash
export PATH="$HOME/.bun/bin:$PATH"

# Clone gstack
git clone https://github.com/aglz-ai/gstack.git ~/.claude/skills/gstack
cd ~/.claude/skills/gstack

# Install dependencies
bun install

# Compile binary
bun run build

# Setup directories
mkdir -p ~/.gstack/sessions
mkdir -p ~/.gstack/analytics

# Install Playwright browsers
bunx playwright install chromium

echo "GStack installed successfully!"
echo "Run 'gstack-browser --help' to get started"
```

### 7. Usage Examples

#### 7.1 Jarvis O Testing AGLz Dashboard

```bash
# Jarvis O on CT-203
$g goto https://dashboard.aglz.ai
$g snapshot -i
$g click @e5  # Login button
$g fill @e3 "admin@aglz.ai"
$g fill @e4 "password"
$g click @e7  # Submit
$g wait --networkidle
$g is visible ".admin-panel"
$g screenshot /tmp/admin-dashboard.png
```

#### 7.2 Jarvis O Delegating to Jarvis H

```bash
# Jarvis O sends command to Jarvis H
/a2a message jarvis-h --type command --content "browse goto https://api.aglz.ai/docs"

# Jarvis H executes and returns result
# Response: { "status": "success", "page_title": "AGLz API Documentation" }
```

#### 7.3 Coordinated QA Across Agents

```bash
# Jarvis O broadcasts QA task to all peers
/a2a broadcast --type task --content "qa verify https://aglz.ai checkout flow"

# Each peer (Jarvis H, AGLz Crew agents) runs QA independently
# Results aggregated back to Jarvis O
```

### 8. Key Differences from Original GStack

| Feature | Original GStack | AGLz Adaptation |
|---------|-----------------|-----------------|
| **Scope** | Single developer | Multi-agent AI agency |
| **A2A** | Not included | Core feature for agent communication |
| **Personas** | Generic | Jarvis O (CEO) & Jarvis H (CPO) |
| **Deployment** | Local dev | CT-based (CT-203, CT-204) |
| **Skills** | General | Agency-specific (QA, Ship, Investigate) |
| **Browser** | Single instance | Multiple isolated instances |

### 9. Security Model

```yaml
# Security considerations

authentication:
  - Bearer token per server session
  - Token stored in .gstack/browse.json (mode 0600)
  - Localhost-only HTTP server
  
a2a_security:
  - Mutual TLS between CTs
  - Agent identity verification
  - Command whitelisting
  
browser_isolation:
  - Each agent has separate Chromium process
  - Cookie jars isolated per agent
  - No shared state between agents
```

### 10. Next Steps

1. **Implement Core** - Build gstack-browser binary
2. **Deploy to CTs** - Install on CT-203 and CT-204
3. **Configure A2A** - Setup peer communication
4. **Create Skills** - Build agency-specific skills
5. **Test Integration** - End-to-end QA workflows

---

*Document Version: 1.0.0*
*Based on: gstack by Garry Tan (https://github.com/garrytan/gstack)*

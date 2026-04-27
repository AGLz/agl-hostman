#!/bin/bash
# install-gstack-aglz.sh
# Instalação do GStack adaptado para AGLz AI Agency
# Executar em CT-203 (Jarvis O) e CT-204 (Jarvis H)

set -e

AGENT_NAME="${1:-jarvis-o}"
CT_ID="${2:-203}"
GSTACK_HOME="/opt/gstack"
CONFIG_DIR="/etc/gstack"
LOG_DIR="/var/log/gstack"

echo "=== GStack Installation for AGLz AI Agency ==="
echo "Agent: $AGENT_NAME"
echo "CT: CT-$CT_ID"
echo ""

# 1. Instalar dependências
echo "[1/8] Instalando dependências..."
apt-get update
apt-get install -y \
    curl unzip git jq \
    libnss3 libatk-bridge2.0-0 libxcomposite1 \
    libxdamage1 libxrandr2 libgbm1 libasound2 \
    libpangocairo-1.0-0 libxshmfence1

# 2. Instalar Bun
echo "[2/8] Instalando Bun..."
if ! command -v bun &> /dev/null; then
    curl -fsSL https://bun.sh/install | bash
    export PATH="$HOME/.bun/bin:$PATH"
fi

# 3. Criar diretórios
echo "[3/8] Criando diretórios..."
mkdir -p "$GSTACK_HOME"/{bin,src,skills,config}
mkdir -p "$CONFIG_DIR"
mkdir -p "$LOG_DIR"
mkdir -p "/var/lib/gstack"/{sessions,cookies,screenshots}
mkdir -p "$HOME/.gstack/sessions"

# 4. Copiar source files
echo "[4/8] Instalando GStack source..."
cd "$GSTACK_HOME"

# Criar package.json
cat > package.json << 'EOF'
{
  "name": "gstack-aglz",
  "version": "1.0.0",
  "description": "GStack for AGLz AI Agency",
  "main": "src/server.ts",
  "scripts": {
    "build": "bun build --compile src/cli.ts --outfile bin/gstack-browser",
    "dev": "bun run src/cli.ts",
    "server": "bun run src/server.ts",
    "test": "bun test"
  },
  "dependencies": {
    "playwright": "^1.40.0"
  },
  "devDependencies": {
    "@types/bun": "latest"
  }
}
EOF

# 5. Instalar dependências
echo "[5/8] Instalando dependências npm..."
bun install

# 6. Instalar Playwright browsers
echo "[6/8] Instalando Chromium..."
bunx playwright install chromium

# 7. Criar arquivos source
echo "[7/8] Criando arquivos source..."

# CLI TypeScript
cat > src/cli.ts << 'EOF'
#!/usr/bin/env bun
import { readFileSync, writeFileSync, existsSync, chmodSync } from 'fs';
import { spawn, execSync } from 'child_process';
import { join } from 'path';

const STATE_FILE = '.gstack/browse.json';
const PID_FILE = '.gstack/browser.pid';

interface ServerState {
  pid: number;
  port: number;
  token: string;
  startedAt: string;
  binaryVersion: string;
}

const VERSION = '1.0.0-aglz';

async function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0 || args[0] === '--help' || args[0] === '-h') {
    showHelp();
    return;
  }
  
  const command = args[0];
  const commandArgs = args.slice(1);
  
  // Special commands
  switch (command) {
    case 'status':
      await showStatus();
      return;
    case 'stop':
      await stopServer();
      return;
    case 'restart':
      await restartServer();
      return;
    case 'version':
      console.log(`gstack-browser ${VERSION}`);
      return;
  }
  
  // Ensure server is running
  let state = await ensureServer();
  
  // Send command to server
  try {
    const result = await sendCommand(state, command, commandArgs);
    console.log(result);
  } catch (error) {
    console.error(`Error: ${error.message}`);
    process.exit(1);
  }
}

function showHelp() {
  console.log(`
GStack Browser for AGLz AI Agency v${VERSION}

Usage: gstack-browser <command> [args...]

Navigation:
  goto <url>              Navigate to URL
  back, forward, reload   Browser navigation
  url                     Show current URL

Reading:
  text                    Clean page text
  html                    Page HTML
  links                   All links
  forms                   Form fields

Interaction:
  click <@ref|selector>   Click element
  fill <@ref> <value>     Fill input
  select <@ref> <value>   Select dropdown
  upload <@ref> <file>    Upload file

Snapshot:
  snapshot [-i] [-D] [-a] Get page snapshot with optional refs
    -i  Interactive elements only
    -D  Diff against previous
    -a  Annotated screenshot
    -C  Cursor-interactive elements

Visual:
  screenshot [path]       Take screenshot
  pdf [path]              Save as PDF

Server:
  status                  Show server status
  stop                    Stop server
  restart                 Restart server
  version                 Show version

A2A Protocol:
  a2a message <agent> <msg>   Send message to agent
  a2a query <agent> <type>    Query agent status
  a2a broadcast <msg>         Broadcast to all peers

Examples:
  gstack-browser goto https://example.com
  gstack-browser snapshot -i
  gstack-browser click @e3
  gstack-browser screenshot /tmp/page.png
`);
}

async function ensureServer(): Promise<ServerState> {
  // Check for existing server
  if (existsSync(STATE_FILE)) {
    try {
      const state: ServerState = JSON.parse(readFileSync(STATE_FILE, 'utf-8'));
      const healthy = await healthCheck(state.port, state.token);
      if (healthy) {
        return state;
      }
    } catch {
      // Server dead, start new one
    }
  }
  
  // Start new server
  return await startServer();
}

async function startServer(): Promise<ServerState> {
  const port = await findFreePort();
  const token = generateToken();
  
  const state: ServerState = {
    pid: 0, // Will be set after spawn
    port,
    token,
    startedAt: new Date().toISOString(),
    binaryVersion: VERSION
  };
  
  // Write state file early so server can read it
  writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
  chmodSync(STATE_FILE, 0o600);
  
  // Spawn server
  const serverProcess = spawn('bun', ['run', join(__dirname, 'server.ts')], {
    detached: true,
    stdio: 'ignore',
    env: {
      ...process.env,
      GSTACK_PORT: port.toString(),
      GSTACK_TOKEN: token,
      GSTACK_STATE_FILE: STATE_FILE
    }
  });
  
  state.pid = serverProcess.pid || 0;
  writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
  
  // Wait for server to be ready
  await waitForServer(port, token);
  
  return state;
}

async function findFreePort(): Promise<number> {
  // Random port between 10000-60000
  return Math.floor(Math.random() * 50000) + 10000;
}

function generateToken(): string {
  return crypto.randomUUID();
}

async function waitForServer(port: number, token: string, maxAttempts = 30): Promise<void> {
  for (let i = 0; i < maxAttempts; i++) {
    try {
      const healthy = await healthCheck(port, token);
      if (healthy) return;
    } catch {
      // Not ready yet
    }
    await new Promise(r => setTimeout(r, 100));
  }
  throw new Error('Server failed to start');
}

async function healthCheck(port: number, token: string): Promise<boolean> {
  try {
    const response = await fetch(`http://localhost:${port}/health`, {
      headers: { 'Authorization': `Bearer ${token}` },
      signal: AbortSignal.timeout(1000)
    });
    return response.ok;
  } catch {
    return false;
  }
}

async function sendCommand(state: ServerState, command: string, args: string[]): Promise<string> {
  const response = await fetch(`http://localhost:${state.port}/command`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${state.token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ command, args })
  });
  
  if (!response.ok) {
    const error = await response.text();
    throw new Error(error);
  }
  
  return response.text();
}

async function showStatus() {
  if (!existsSync(STATE_FILE)) {
    console.log('Server: not running');
    return;
  }
  
  try {
    const state: ServerState = JSON.parse(readFileSync(STATE_FILE, 'utf-8'));
    const healthy = await healthCheck(state.port, state.token);
    
    console.log(`Server: ${healthy ? 'running' : 'dead'}`);
    console.log(`Port: ${state.port}`);
    console.log(`PID: ${state.pid}`);
    console.log(`Version: ${state.binaryVersion}`);
    console.log(`Started: ${state.startedAt}`);
  } catch {
    console.log('Server: error reading state');
  }
}

async function stopServer() {
  if (!existsSync(STATE_FILE)) {
    console.log('Server not running');
    return;
  }
  
  try {
    const state: ServerState = JSON.parse(readFileSync(STATE_FILE, 'utf-8'));
    process.kill(state.pid, 'SIGTERM');
    
    // Wait for process to exit
    await new Promise(r => setTimeout(r, 1000));
    
    // Clean up state file
    try {
      execSync(`rm -f ${STATE_FILE}`);
    } catch {}
    
    console.log('Server stopped');
  } catch (error) {
    console.error(`Error stopping server: ${error}`);
  }
}

async function restartServer() {
  await stopServer();
  await new Promise(r => setTimeout(r, 1000));
  const state = await ensureServer();
  console.log(`Server restarted on port ${state.port}`);
}

main().catch(console.error);
EOF

# Server TypeScript
cat > src/server.ts << 'EOF'
#!/usr/bin/env bun
import { serve } from 'bun';
import { chromium, Browser, BrowserContext, Page } from 'playwright';

const PORT = parseInt(process.env.GSTACK_PORT || '0');
const TOKEN = process.env.GSTACK_TOKEN || '';
const STATE_FILE = process.env.GSTACK_STATE_FILE || '.gstack/browse.json';

// Command categories
const READ_COMMANDS = new Set([
  'text', 'html', 'links', 'forms', 'accessibility',
  'console', 'network', 'dialog', 'cookies', 'storage',
  'js', 'eval', 'css', 'attrs', 'is', 'perf', 'url'
]);

const WRITE_COMMANDS = new Set([
  'goto', 'click', 'fill', 'select', 'hover', 
  'type', 'press', 'scroll', 'wait', 'upload',
  'back', 'forward', 'reload',
  'dialog-accept', 'dialog-dismiss'
]);

const META_COMMANDS = new Set([
  'snapshot', 'screenshot', 'tabs', 'chain', 'pdf',
  'status', 'restart', 'stop', 'handoff', 'resume'
]);

// Browser state
let browser: Browser | null = null;
let context: BrowserContext | null = null;
let pages: Map<number, Page> = new Map();
let currentTabId = 1;
let refMap: Map<string, { role: string; name: string; locator: any }> = new Map();
let lastSnapshot = '';

async function main() {
  // Launch browser
  await launchBrowser();
  
  // Start HTTP server
  serve({
    port: PORT,
    async fetch(request) {
      const url = new URL(request.url);
      
      // Health check (no auth required)
      if (url.pathname === '/health') {
        return Response.json({ status: 'healthy', version: '1.0.0-aglz' });
      }
      
      // Auth check
      const auth = request.headers.get('Authorization');
      if (auth !== `Bearer ${TOKEN}`) {
        return new Response('Unauthorized', { status: 401 });
      }
      
      // Routes
      if (url.pathname === '/command' && request.method === 'POST') {
        return handleCommand(request);
      }
      
      if (url.pathname === '/a2a/message' && request.method === 'POST') {
        return handleA2AMessage(request);
      }
      
      return new Response('Not Found', { status: 404 });
    }
  });
  
  console.log(`GStack server running on port ${PORT}`);
  
  // Keep alive
  setInterval(() => {}, 1000);
}

async function launchBrowser() {
  browser = await chromium.launch({
    headless: true,
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-gpu'
    ]
  });
  
  context = await browser.newContext({
    viewport: { width: 1920, height: 1080 }
  });
  
  const page = await context.newPage();
  pages.set(currentTabId, page);
  
  // Setup event handlers
  page.on('framenavigated', () => {
    refMap.clear();
  });
  
  browser.on('disconnected', () => {
    console.error('Browser disconnected - exiting');
    process.exit(1);
  });
}

async function handleCommand(request: Request): Promise<Response> {
  try {
    const { command, args } = await request.json();
    
    let result: string;
    
    if (READ_COMMANDS.has(command)) {
      result = await handleReadCommand(command, args);
    } else if (WRITE_COMMANDS.has(command)) {
      result = await handleWriteCommand(command, args);
    } else if (META_COMMANDS.has(command)) {
      result = await handleMetaCommand(command, args);
    } else {
      return new Response(`Unknown command: ${command}`, { status: 400 });
    }
    
    return new Response(result);
  } catch (error: any) {
    return new Response(`Error: ${error.message}`, { status: 500 });
  }
}

async function handleReadCommand(command: string, args: string[]): Promise<string> {
  const page = getCurrentPage();
  
  switch (command) {
    case 'text':
      return await page.evaluate(() => document.body.innerText);
    
    case 'html':
      return await page.content();
    
    case 'url':
      return page.url();
    
    case 'links':
      return await page.evaluate(() => {
        const links = Array.from(document.querySelectorAll('a'));
        return links.map(l => `${l.textContent?.trim() || ''} → ${l.href}`).join('\n');
      });
    
    case 'js':
      const jsResult = await page.evaluate(args[0]);
      return String(jsResult);
    
    case 'console':
      return 'Console log capture not implemented';
    
    default:
      return `Command ${command} not fully implemented`;
  }
}

async function handleWriteCommand(command: string, args: string[]): Promise<string> {
  const page = getCurrentPage();
  
  switch (command) {
    case 'goto':
      await page.goto(args[0], { waitUntil: 'networkidle' });
      refMap.clear();
      return `Navigated to ${args[0]}`;
    
    case 'click':
      const clickLocator = resolveSelector(args[0]);
      await clickLocator.click();
      return `Clicked ${args[0]}`;
    
    case 'fill':
      const fillLocator = resolveSelector(args[0]);
      await fillLocator.fill(args[1] || '');
      return `Filled ${args[0]}`;
    
    case 'back':
      await page.goBack();
      return 'Went back';
    
    case 'forward':
      await page.goForward();
      return 'Went forward';
    
    case 'reload':
      await page.reload();
      return 'Reloaded';
    
    default:
      return `Command ${command} not fully implemented`;
  }
}

async function handleMetaCommand(command: string, args: string[]): Promise<string> {
  const page = getCurrentPage();
  
  switch (command) {
    case 'snapshot':
      return await handleSnapshot(page, args);
    
    case 'screenshot':
      const path = args[0] || `/tmp/screenshot-${Date.now()}.png`;
      await page.screenshot({ path, fullPage: true });
      return `Screenshot saved to ${path}`;
    
    case 'status':
      return JSON.stringify({
        status: 'running',
        url: page.url(),
        tabs: pages.size,
        refs: refMap.size
      }, null, 2);
    
    default:
      return `Command ${command} not fully implemented`;
  }
}

async function handleSnapshot(page: Page, args: string[]): Promise<string> {
  const options = {
    interactive: args.includes('-i'),
    compact: args.includes('-c'),
    diff: args.includes('-D'),
    annotate: args.includes('-a'),
    cursorInteractive: args.includes('-C')
  };
  
  // Get accessibility snapshot
  const snapshot = await page.accessibility.snapshot({
    interestingOnly: options.interactive
  });
  
  // Build ref map and output
  let refCounter = 1;
  const lines: string[] = [];
  
  function traverse(node: any, depth = 0) {
    if (!node) return;
    
    const role = node.role || 'generic';
    const name = node.name || '';
    
    // Skip non-interactive if -i flag
    if (options.interactive && !isInteractive(role)) {
      // Still traverse children
      if (node.children) {
        for (const child of node.children) {
          traverse(child, depth);
        }
      }
      return;
    }
    
    const indent = '  '.repeat(depth);
    const refId = `e${refCounter++}`;
    
    // Build locator
    const locator = page.getByRole(role, { name: name || undefined }).nth(0);
    refMap.set(refId, { role, name, locator });
    
    lines.push(`${indent}@${refId} [${role}] "${name}"`);
    
    if (node.children) {
      for (const child of node.children) {
        traverse(child, depth + 1);
      }
    }
  }
  
  traverse(snapshot);
  
  const output = lines.join('\n');
  
  // Handle diff
  if (options.diff && lastSnapshot) {
    // Simple line diff
    const diff = generateDiff(lastSnapshot, output);
    lastSnapshot = output;
    return diff;
  }
  
  lastSnapshot = output;
  return output;
}

function isInteractive(role: string): boolean {
  const interactiveRoles = new Set([
    'button', 'link', 'textbox', 'checkbox', 'radio',
    'combobox', 'menuitem', 'tab', 'treeitem'
  ]);
  return interactiveRoles.has(role);
}

function generateDiff(oldStr: string, newStr: string): string {
  const oldLines = oldStr.split('\n');
  const newLines = newStr.split('\n');
  const result: string[] = [];
  
  // Simple diff - show removed and added
  for (const line of oldLines) {
    if (!newLines.includes(line)) {
      result.push(`- ${line}`);
    }
  }
  
  for (const line of newLines) {
    if (!oldLines.includes(line)) {
      result.push(`+ ${line}`);
    } else {
      result.push(`  ${line}`);
    }
  }
  
  return result.join('\n');
}

function getCurrentPage(): Page {
  const page = pages.get(currentTabId);
  if (!page) throw new Error('No page available');
  return page;
}

function resolveSelector(selector: string): any {
  const page = getCurrentPage();
  
  // Check if it's a ref
  if (selector.startsWith('@')) {
    const refId = selector.slice(1);
    const entry = refMap.get(refId);
    if (!entry) {
      throw new Error(`Ref ${selector} not found. Run 'snapshot' to get fresh refs.`);
    }
    return entry.locator;
  }
  
  // Otherwise treat as CSS selector
  return page.locator(selector);
}

async function handleA2AMessage(request: Request): Promise<Response> {
  const message = await request.json();
  
  console.log(`[A2A] ${message.from_agent} -> ${message.to_agent}: ${message.content}`);
  
  // Handle browser commands from peers
  if (message.message_type === 'command') {
    const parts = message.content.split(' ');
    const command = parts[0];
    const args = parts.slice(1);
    
    try {
      let result: string;
      
      if (READ_COMMANDS.has(command)) {
        result = await handleReadCommand(command, args);
      } else if (WRITE_COMMANDS.has(command)) {
        result = await handleWriteCommand(command, args);
      } else {
        result = `Unknown command: ${command}`;
      }
      
      return Response.json({ status: 'success', result });
    } catch (error: any) {
      return Response.json({ status: 'error', error: error.message });
    }
  }
  
  return Response.json({ status: 'received' });
}

main().catch(console.error);
EOF

# 8. Compilar e instalar
echo "[8/8] Compilando binário..."
bun run build

# Criar symlink
ln -sf "$GSTACK_HOME/bin/gstack-browser" /usr/local/bin/gstack-browser
ln -sf "$GSTACK_HOME/bin/gstack-browser" /usr/local/bin/gb

# Criar systemd service
cat > /etc/systemd/system/gstack-browser.service << EOF
[Unit]
Description=GStack Browser Daemon for $AGENT_NAME
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$GSTACK_HOME
Environment=PATH=$PATH
ExecStart=/usr/local/bin/gstack-browser status
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable gstack-browser

echo ""
echo "=== Instalação Completa ==="
echo "Agente: $AGENT_NAME (CT-$CT_ID)"
echo "Binário: /usr/local/bin/gstack-browser"
echo "Alias: gb"
echo ""
echo "Comandos disponíveis:"
echo "  gstack-browser goto https://example.com"
echo "  gstack-browser snapshot -i"
echo "  gstack-browser click @e1"
echo "  gstack-browser status"
echo ""
echo "Iniciar servidor:"
echo "  gstack-browser status  # Auto-inicia na primeira chamada"

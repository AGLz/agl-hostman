#!/usr/bin/env node

/**
 * API Explorer Build Script
 *
 * Validates OpenAPI spec and builds the API Explorer
 */

import { readFileSync, writeFileSync, existsSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

// ANSI color codes
const colors = {
  reset: '\x1b[0m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m'
};

function log(message, color = 'reset') {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

function error(message) {
  log(`ERROR: ${message}`, 'red');
}

function success(message) {
  log(message, 'green');
}

function warn(message) {
  log(message, 'yellow');
}

// Validate OpenAPI spec
function validateOpenAPISpec(specPath) {
  log('\n========================================', 'cyan');
  log('Validating OpenAPI Specification', 'cyan');
  log('========================================\n', 'cyan');

  if (!existsSync(specPath)) {
    error(`OpenAPI spec not found at: ${specPath}`);
    return false;
  }

  try {
    const spec = readFileSync(specPath, 'utf8');
    const openApi = JSON.parse(spec.replace(/\.ya?ml$/i, ''));

    // Basic validation
    const requiredFields = ['openapi', 'info', 'paths'];
    for (const field of requiredFields) {
      if (!openApi[field]) {
        error(`Missing required field: ${field}`);
        return false;
      }
    }

    // Check info
    if (!openApi.info.title || !openApi.info.version) {
      error('info.title and info.version are required');
      return false;
    }

    // Count endpoints
    const paths = Object.keys(openApi.paths || {});
    const endpointCount = paths.reduce((count, path) => {
      const methods = Object.keys(openApi.paths[path]).filter(
        key => ['get', 'post', 'put', 'delete', 'patch', 'options', 'head', 'trace'].includes(key.toLowerCase())
      );
      return count + methods.length;
    }, 0);

    success(`OpenAPI v${openApi.openapi} specification is valid`);
    success(`API: ${openApi.info.title} v${openApi.info.version}`);
    success(`Endpoints: ${endpointCount} across ${paths.length} paths`);

    // Check for security
    if (openApi.components?.securitySchemes) {
      const schemes = Object.keys(openApi.components.securitySchemes);
      success(`Authentication methods: ${schemes.join(', ')}`);
    }

    // Check for servers
    if (openApi.servers && openApi.servers.length > 0) {
      success(`Servers defined: ${openApi.servers.length}`);
      openApi.servers.forEach(server => {
        log(`  - ${server.url} (${server.description || 'No description'})`, 'blue');
      });
    }

    return true;
  } catch (err) {
    if (err.message.includes('JSON')) {
      // Try YAML validation
      try {
        const yaml = readFileSync(specPath, 'utf8');
        if (yaml.includes('openapi:') && yaml.includes('info:') && yaml.includes('paths:')) {
          success(`YAML specification appears valid (basic check passed)`);
          return true;
        }
      } catch {
        error('Failed to parse YAML specification');
        return false;
      }
    }
    error(`Failed to validate specification: ${err.message}`);
    return false;
  }
}

// Validate API Explorer files
function validateExplorerFiles(explorerDir) {
  log('\n========================================', 'cyan');
  log('Validating API Explorer Files', 'cyan');
  log('========================================\n', 'cyan');

  const requiredFiles = [
    'index.html',
    'config.js',
    'README.md',
    'oauth2-receiver.html'
  ];

  let allValid = true;

  for (const file of requiredFiles) {
    const filePath = resolve(explorerDir, file);
    if (!existsSync(filePath)) {
      error(`Missing required file: ${file}`);
      allValid = false;
    } else {
      success(`Found: ${file}`);
    }
  }

  return allValid;
}

// Generate stats
function generateStats(explorerDir) {
  log('\n========================================', 'cyan');
  log('API Explorer Statistics', 'cyan');
  log('========================================\n', 'cyan');

  const indexHtml = readFileSync(resolve(explorerDir, 'index.html'), 'utf8');

  // Count endpoints referenced
  const stats = {
    htmlSize: indexHtml.length,
    cssSize: (indexHtml.match(/<style[^>]*>([\s\S]*?)<\/style>/gi) || [''])[0].length,
    jsSize: (indexHtml.match(/<script[^>]*>([\s\S]*?)<\/script>/gi) || [''])[0].length,
    codeExamples: (indexHtml.match(/class="code-example"/g) || []).length,
    supportedLanguages: (indexHtml.match(/data-lang="(\w+)"/g) || []).length
  };

  success(`HTML size: ${(stats.htmlSize / 1024).toFixed(2)} KB`);
  success(`CSS size: ${(stats.cssSize / 1024).toFixed(2)} KB`);
  success(`JS size: ${(stats.jsSize / 1024).toFixed(2)} KB`);
  success(`Code examples: ${stats.codeExamples}`);
  success(`Supported languages: ${stats.supportedLanguages}`);

  return stats;
}

// Main build process
async function build() {
  const explorerDir = resolve(__dirname, '..');
  const specPath = resolve(explorerDir, '../api/openapi.yaml');

  log('\n🚀 AGL Hostman API Explorer - Build', 'cyan');
  log('================================================\n', 'cyan');

  // Validate OpenAPI spec
  const specValid = validateOpenAPISpec(specPath);
  if (!specValid) {
    error('\nBuild failed: OpenAPI spec validation failed');
    process.exit(1);
  }

  // Validate explorer files
  const filesValid = validateExplorerFiles(explorerDir);
  if (!filesValid) {
    error('\nBuild failed: Required files missing');
    process.exit(1);
  }

  // Generate stats
  const stats = generateStats(explorerDir);

  // Summary
  log('\n========================================', 'cyan');
  log('Build Summary', 'cyan');
  log('========================================\n', 'cyan');

  success('✓ OpenAPI specification validated');
  success('✓ API Explorer files validated');
  success('✓ Build complete!');

  log('\n📦 Output:', 'cyan');
  log(`  ${resolve(explorerDir, 'index.html')}`, 'blue');

  log('\n🔗 To use the API Explorer:', 'cyan');
  log('  1. Serve the /site directory with a web server', 'blue');
  log('  2. Navigate to: http://localhost:8000/api-explorer/', 'blue');
  log('  3. Set your API credentials using the auth button', 'blue');

  log('\n📚 Documentation: /site/api-explorer/README.md\n', 'cyan');
}

// Run build
build().catch(err => {
  error(err.message);
  process.exit(1);
});

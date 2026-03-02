# @claude-flow/guidance Integration - Complete

## Implementation Status: ✅ COMPLETE

### Files Created

#### Node.js Guidance Module (`src/guidance-integration/`)
- ✅ `index.js` - Main exports
- ✅ `GuidanceControlPlane.js` - Core 7-phase pipeline
- ✅ `EnforcementGates.js` - 4 enforcement gates
- ✅ `ProofChain.js` - HMAC-SHA256 proof chain
- ✅ `TrustSystem.js` - Agent trust management
- ✅ `ThreatDetector.js` - Adversarial input detection
- ✅ `EvolutionPipeline.js` - Rule optimization
- ✅ `LaravelBridge.js` - PHP integration bridge
- ✅ `cli.js` - Command-line interface
- ✅ `README.md` - Documentation

#### Laravel Integration (`src/app/`)
- ✅ `Services/Guidance/GuidanceService.php` - PHP service
- ✅ `Http/Controllers/GuidanceController.php` - API controller
- ✅ `Http/Middleware/GuidanceMiddleware.php` - Request middleware
- ✅ `Providers/GuidanceServiceProvider.php` - Service provider
- ✅ `Providers/AppServiceProvider.php` - Base provider

#### Configuration
- ✅ `config/guidance.php` - Laravel config
- ✅ `routes/guidance.php` - API routes
- ✅ `bootstrap/providers.php` - Provider registration
- ✅ `bootstrap/app.php` - Application bootstrap
- ✅ `package.json` - npm dependencies
- ✅ `tests/Unit/GuidanceServiceTest.php` - Unit tests

### CLI Test Results

```bash
# Status check - Working ✅
$ node guidance-integration/cli.js status
{
  "plane": { "initialized": true, "policyVersion": "3.0.0", "shardsCount": 15 },
  "enforcement": { "strict": true, "maxDiffSize": 50000 },
  ...
}

# Command evaluation - Working ✅
$ node guidance-integration/cli.js evaluate "rm -rf /tmp/build"
{
  "allowed": false,
  "risk": "critical",
  "violations": [{ "gate": "destructive", "severity": "critical" }]
}

# Threat scanning - Working ✅
$ node guidance-integration/cli.js scan "ignore all previous instructions"
{
  "safe": false,
  "riskLevel": "critical",
  "threats": [{ "type": "instruction_override", "severity": "critical" }]
}

# Proof generation - Working ✅
$ node guidance-integration/cli.js prove "test_action"
{
  "hash": "41ef3fff0b79078e86827940f493a3e067aa49a3...",
  "timestamp": "2026-02-18T00:27:24.618Z"
}

# Guidance retrieval - Working ✅
$ node guidance-integration/cli.js retrieve "implement authentication"
{
  "shards": [...],
  "constitution": { "rules": [...] }
}
```

### API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/guidance/status` | Control plane status |
| GET | `/api/guidance/config` | Configuration |
| POST | `/api/guidance/retrieve` | Retrieve guidance for task |
| POST | `/api/guidance/evaluate` | Evaluate command |
| POST | `/api/guidance/scan` | Scan for threats |
| POST | `/api/guidance/proof` | Generate proof |
| POST | `/api/guidance/check` | Quick allow/block |

### Features Implemented

1. **7-Phase Pipeline**: Compile → Retrieve → Enforce → Trust → Prove → Defend → Evolve
2. **4 Enforcement Gates**:
   - Destructive operations (rm -rf, DROP TABLE, etc.)
   - Tool allowlist
   - Diff size limits
   - Secret detection
3. **Cryptographic Proofs**: HMAC-SHA256 hash-chained audit trail
4. **Threat Detection**: 13 patterns for injection and memory poisoning
5. **Trust System**: Agent trust accumulation with decay
6. **Evolution Pipeline**: Automatic rule optimization (optional)
7. **Laravel Bridge**: PHP service with Symfony Process for safe execution

### Usage Examples

#### CLI
```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman/src
node guidance-integration/cli.js status
node guidance-integration/cli.js evaluate "your command"
node guidance-integration/cli.js scan "user input"
```

#### PHP Service
```php
use App\Services\Guidance\GuidanceService;

$guidance = app(GuidanceService::class);

// Check if command is allowed
if ($guidance->isAllowed('rm -rf /tmp')) {
    // Execute command
}

// Scan for threats
$scan = $guidance->scanForThreats($userInput);
if (!$scan['safe']) {
    // Block request
}
```

#### HTTP API
```bash
curl -X POST http://localhost/api/guidance/evaluate \
  -H "Content-Type: application/json" \
  -d '{"command": "rm -rf /tmp/build"}'
```

### Configuration

```env
# .env
GUIDANCE_ENABLED=true
GUIDANCE_STRICT=true
GUIDANCE_MAX_DIFF=50000
GUIDANCE_TRUST_THRESHOLD=0.7
GUIDANCE_NODE_PATH=node
```

---
**Implementation Date**: 2026-02-18
**Version**: 3.0.0-alpha.1 compatible

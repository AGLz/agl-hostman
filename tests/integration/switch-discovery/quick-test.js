#!/usr/bin/env node
/**
 * Quick Test Script for OMAY Switch Discovery
 *
 * Quick verification of a single switch candidate
 * Usage: node quick-test.js <ip> [location] [priority]
 *
 * Example:
 *   node quick-test.js 192.168.0.1 AGLHQ high
 */

const {
  SwitchVerificationRunner
} = require('./switch-verification-tests.js');

// Parse command line arguments
const args = process.argv.slice(2);

if (args.length === 0) {
  console.error('ERROR: IP address required');
  console.log('\nUsage: node quick-test.js <ip> [location] [priority]');
  console.log('\nExamples:');
  console.log('  node quick-test.js 192.168.0.1');
  console.log('  node quick-test.js 192.168.0.1 AGLHQ high');
  console.log('  node quick-test.js 192.168.15.100 AGLFG medium');
  process.exit(1);
}

const candidate = {
  ip: args[0],
  network: 'LAN',
  location: args[1] || 'Unknown',
  priority: args[2] || 'medium'
};

console.log('╔══════════════════════════════════════════════════════════════╗');
console.log('║       OMAY OM-S107C-62TS Switch Quick Verification          ║');
console.log('╚══════════════════════════════════════════════════════════════╝\n');

console.log('Target Information:');
console.log(`  IP:       ${candidate.ip}`);
console.log(`  Location: ${candidate.location}`);
console.log(`  Priority: ${candidate.priority}`);
console.log(`  Network:  ${candidate.network}\n`);

// Create runner and execute tests
const runner = new SwitchVerificationRunner();

async function runQuickTest() {
  try {
    const report = await runner.testCandidate(candidate);

    console.log('\n╔══════════════════════════════════════════════════════════════╗');
    console.log('║                     VERIFICATION RESULTS                     ║');
    console.log('╚══════════════════════════════════════════════════════════════╝\n');

    // Connectivity
    console.log('📡 CONNECTIVITY:');
    if (report.tests.ping?.reachable) {
      console.log(`  ✅ Reachable (${report.tests.ping.latency}ms latency)`);
    } else {
      console.log('  ❌ Not reachable');
    }

    if (report.mac) {
      console.log(`  🔍 MAC: ${report.mac}`);
      if (report.vendor) {
        console.log(`  🏭 Vendor: ${report.vendor}`);
      }
    }

    // Open Ports
    if (report.openPorts && report.openPorts.length > 0) {
      console.log(`  🔓 Open ports: ${report.openPorts.join(', ')}`);
    }

    // Model Verification
    console.log('\n🔍 MODEL VERIFICATION:');
    if (report.modelMatch) {
      console.log(`  ✅ Model confirmed (${report.modelConfidence}% confidence)`);
    } else if (report.modelConfidence) {
      console.log(`  ⚠️  Possible match (${report.modelConfidence}% confidence)`);
    } else {
      console.log('  ❌ Model not verified');
    }

    // Access Method
    if (report.recommendation?.accessMethod) {
      console.log('\n🌐 ACCESS:');
      console.log(`  ✅ ${report.recommendation.accessMethod}`);
    }

    // Security
    if (report.securityConcerns && report.securityConcerns.length > 0) {
      console.log('\n🚨 SECURITY CONCERNS:');
      report.securityConcerns.forEach(concern => {
        console.log(`  ⚠️  ${concern}`);
      });
    }

    console.log(`\n🛡️  Security Level: ${report.securityLevel || 'UNKNOWN'}`);

    // Recommendation
    console.log('\n📋 RECOMMENDATION:');
    if (report.recommendation) {
      console.log(`  Status: ${report.recommendation.verified ? '✅ VERIFIED' : '⚠️  UNVERIFIED'}`);
      console.log(`  Confidence: ${report.recommendation.confidence}%`);

      if (report.recommendation.nextSteps && report.recommendation.nextSteps.length > 0) {
        console.log('\n  Next steps:');
        report.recommendation.nextSteps.forEach((step, i) => {
          console.log(`    ${i + 1}. ${step}`);
        });
      }
    }

    // Save results
    const fs = require('fs');
    const outputPath = `/mnt/overpower/apps/dev/agl/agl-hostman/tests/integration/switch-discovery/quick-test-${candidate.ip.replace(/\./g, '-')}.json`;
    fs.writeFileSync(outputPath, JSON.stringify(report, null, 2));

    console.log(`\n💾 Full results saved to: ${outputPath}\n`);

    // Exit with appropriate code
    process.exit(report.recommendation?.verified ? 0 : 1);

  } catch (error) {
    console.error('\n❌ FATAL ERROR:', error.message);
    console.error(error.stack);
    process.exit(2);
  }
}

runQuickTest();

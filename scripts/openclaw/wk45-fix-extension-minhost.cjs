#!/usr/bin/env node
// Corrige openclaw.install.minHostVersion em extensions (wk45).
const fs = require('fs');
const path = require('path');

const extDir = 'C:\\Users\\Administrator\\src\\openclaw\\extensions';
const FLOOR = '>=2026.5.0';
const semverFloor = /^>=\d+\.\d+\.\d+$/;

function patchInstall(install, label) {
  if (!install || typeof install.minHostVersion !== 'string') {
    return false;
  }
  if (semverFloor.test(install.minHostVersion)) {
    return false;
  }
  const before = install.minHostVersion;
  install.minHostVersion = FLOOR;
  console.log(`fixed ${label}: ${before} -> ${FLOOR}`);
  return true;
}

let fixed = 0;
for (const name of fs.readdirSync(extDir, { withFileTypes: true })) {
  if (!name.isDirectory()) {
    continue;
  }
  const dir = path.join(extDir, name.name);
  const pkgPath = path.join(dir, 'package.json');
  if (fs.existsSync(pkgPath)) {
    const j = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
    if (patchInstall(j.openclaw && j.openclaw.install, `${name.name}/package.json`)) {
      fs.writeFileSync(pkgPath, `${JSON.stringify(j, null, 2)}\n`, 'utf8');
      fixed += 1;
    }
  }
  const manifestPath = path.join(dir, 'openclaw.plugin.json');
  if (fs.existsSync(manifestPath)) {
    const m = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
    if (patchInstall(m.install, `${name.name}/openclaw.plugin.json`)) {
      fs.writeFileSync(manifestPath, `${JSON.stringify(m, null, 2)}\n`, 'utf8');
      fixed += 1;
    }
  }
}
console.log(`OK fix-minhost count=${fixed}`);

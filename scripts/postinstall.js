#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// ── Make all bash scripts executable ──

const scriptsDir = path.join(__dirname);
const helpersDir = path.join(__dirname, '..', 'helpers');

function makeExecutable(dir) {
  if (!fs.existsSync(dir)) return;
  const files = fs.readdirSync(dir);
  for (const file of files) {
    if (file.endsWith('.sh')) {
      try {
        fs.chmodSync(path.join(dir, file), '755');
      } catch (e) {}
    }
  }
}

makeExecutable(scriptsDir);
makeExecutable(helpersDir);

// ── Dependency checks ──

const platform = process.platform; // 'darwin' | 'linux'

function hasBin(name) {
  try {
    execSync(`command -v ${name}`, { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}

function tryInstall(name, { brew, apt, npm: npmPkg } = {}) {
  // Try brew on macOS
  if (platform === 'darwin' && brew && hasBin('brew')) {
    try {
      console.log(`  Installing ${name} via brew...`);
      execSync(`brew install ${brew}`, { stdio: 'inherit' });
      return true;
    } catch { return false; }
  }
  // Try apt on Linux
  if (platform === 'linux' && apt && hasBin('apt-get')) {
    try {
      console.log(`  Installing ${name} via apt...`);
      execSync(`sudo apt-get install -y ${apt}`, { stdio: 'inherit' });
      return true;
    } catch { return false; }
  }
  // Try npm
  if (npmPkg) {
    try {
      console.log(`  Installing ${name} via npm...`);
      execSync(`npm install -g ${npmPkg}`, { stdio: 'inherit' });
      return true;
    } catch { return false; }
  }
  return false;
}

// Dependencies: what ralph needs on the host for `ralph loop`
const deps = [
  {
    bin: 'jq',
    label: 'jq (JSON processor)',
    required: true,
    install: { brew: 'jq', apt: 'jq' },
    manual: 'brew install jq  OR  apt-get install jq',
  },
  {
    bin: 'bc',
    label: 'bc (calculator)',
    required: true,
    install: { brew: 'bc', apt: 'bc' },
    manual: 'brew install bc  OR  apt-get install bc',
  },
  {
    bin: 'claude',
    label: 'Claude Code CLI',
    required: true,
    install: { npm: '@anthropic-ai/claude-code' },
    manual: 'npm install -g @anthropic-ai/claude-code',
  },
  {
    bin: 'gh',
    label: 'GitHub CLI (for PR features)',
    required: false,
    install: { brew: 'gh', apt: 'gh' },
    manual: 'brew install gh  OR  https://cli.github.com',
  },
];

console.log('');
console.log('Checking dependencies...');
console.log('');

const missing = [];

for (const dep of deps) {
  if (hasBin(dep.bin)) {
    console.log(`  ✓ ${dep.label}`);
  } else {
    console.log(`  ✗ ${dep.label} — not found, attempting install...`);
    const installed = tryInstall(dep.bin, dep.install);
    if (installed && hasBin(dep.bin)) {
      console.log(`  ✓ ${dep.label} — installed`);
    } else {
      missing.push(dep);
    }
  }
}

console.log('');

if (missing.length > 0) {
  const required = missing.filter(d => d.required);
  const optional = missing.filter(d => !d.required);

  if (required.length > 0) {
    console.log('⚠  Missing required dependencies (ralph loop will not work without these):');
    console.log('');
    for (const dep of required) {
      console.log(`   ${dep.label}`);
      console.log(`     → ${dep.manual}`);
    }
    console.log('');
  }

  if (optional.length > 0) {
    console.log('ℹ  Missing optional dependencies:');
    console.log('');
    for (const dep of optional) {
      console.log(`   ${dep.label}`);
      console.log(`     → ${dep.manual}`);
    }
    console.log('');
  }
}

console.log('Ralph tool installed successfully!');
console.log('');
console.log('Usage:');
console.log('  ralph init     - Initialize Ralph in current directory');
console.log('  ralph start    - Start Ralph in Docker sandbox');
console.log('  ralph loop     - Run Ralph loop directly');
console.log('  ralph status   - Check task status');
console.log('  ralph --help   - Show all commands');
console.log('');

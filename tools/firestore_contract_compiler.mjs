import fs from 'node:fs';
import path from 'node:path';

const repoRoot = process.cwd();
const targetRoots = [
  'lib/services',
  'lib/features',
];

const manifestPath = path.join(repoRoot, 'tools', 'firestore_contract_manifest.json');
const artifactsDir = path.join(repoRoot, 'artifacts');
const surfaceOutput = path.join(artifactsDir, 'firestore_write_surface.json');

function walk(dir) {
  if (!fs.existsSync(dir)) return [];
  const out = [];
  for (const entry of fs.readdirSync(dir, {withFileTypes: true})) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      out.push(...walk(full));
      continue;
    }
    if (entry.isFile() && full.endsWith('.dart')) {
      out.push(full);
    }
  }
  return out;
}

function lineOfIndex(text, index) {
  let line = 1;
  for (let i = 0; i < index && i < text.length; i++) {
    if (text.charCodeAt(i) === 10) line++;
  }
  return line;
}

function extractWrites(filePath) {
  const text = fs.readFileSync(filePath, 'utf8');
  const writeRegex = /\.(set|update|add|delete)\s*\(/g;
  const collectionRegex = /\.collection\('([^']+)'\)/g;
  const writes = [];

  for (const m of text.matchAll(writeRegex)) {
    const op = m[1];
    const idx = m.index ?? 0;
    const start = Math.max(0, idx - 900);
    const ctx = text.slice(start, idx);

    const collections = [];
    for (const c of ctx.matchAll(collectionRegex)) {
      collections.push(c[1]);
    }

    writes.push({
      file: path.relative(repoRoot, filePath).replace(/\\/g, '/'),
      line: lineOfIndex(text, idx),
      operation: op,
      collections,
      inferredPath: collections.length
        ? collections.map((name) => `${name}/{id}`).join('/')
        : '(unknown)',
    });
  }

  return writes;
}

function loadManifest() {
  if (!fs.existsSync(manifestPath)) {
    throw new Error(`Missing manifest: ${manifestPath}`);
  }
  return JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
}

function ensureArtifactsDir() {
  if (!fs.existsSync(artifactsDir)) {
    fs.mkdirSync(artifactsDir, {recursive: true});
  }
}

function extractTestBlock(specText, title) {
  const marker = `it("${title}",`;
  const start = specText.indexOf(marker);
  if (start === -1) {
    return null;
  }

  // Use the next top-level test declaration as the block boundary.
  const next = specText.indexOf('\n  it("', start + marker.length);
  if (next === -1) {
    return specText.slice(start);
  }
  return specText.slice(start, next);
}

function run() {
  const files = targetRoots.flatMap((p) => walk(path.join(repoRoot, p)));
  const writes = files.flatMap((f) => extractWrites(f));

  ensureArtifactsDir();
  // Keep artifact deterministic so CI drift checks only capture contract changes.
  fs.writeFileSync(surfaceOutput, JSON.stringify({writes}, null, 2));

  const manifest = loadManifest();
  const specFile = path.join(repoRoot, manifest.specFile);
  const specText = fs.readFileSync(specFile, 'utf8');
  const allCodeText = files.map((f) => fs.readFileSync(f, 'utf8')).join('\n');

  const failures = [];

  for (const contract of manifest.requiredContracts) {
    const includeAll = contract.codeSignals?.includeAll ?? [];
    const missingSignals = includeAll.filter((signal) => !allCodeText.includes(signal));
    if (missingSignals.length) {
      failures.push({
        type: 'code-signal-missing',
        contract: contract.id,
        path: contract.path,
        details: `Missing code signals: ${missingSignals.join(', ')}`,
      });
    }

    for (const title of contract.tests?.allow ?? []) {
      const block = extractTestBlock(specText, title);
      if (!block) {
        failures.push({
          type: 'allow-test-missing',
          contract: contract.id,
          path: contract.path,
          details: `Missing allow test: ${title}`,
        });
        continue;
      }
      if (!block.includes('assertSucceeds')) {
        failures.push({
          type: 'allow-assert-missing',
          contract: contract.id,
          path: contract.path,
          details: `Allow test does not assert success: ${title}`,
        });
      }
    }

    for (const title of contract.tests?.deny ?? []) {
      const block = extractTestBlock(specText, title);
      if (!block) {
        failures.push({
          type: 'deny-test-missing',
          contract: contract.id,
          path: contract.path,
          details: `Missing deny test: ${title}`,
        });
        continue;
      }
      if (!block.includes('assertFails')) {
        failures.push({
          type: 'deny-assert-missing',
          contract: contract.id,
          path: contract.path,
          details: `Deny test does not assert failure: ${title}`,
        });
      }
    }
  }

  if (failures.length) {
    console.error('Firestore contract coverage gate failed.');
    for (const f of failures) {
      console.error(`- [${f.type}] ${f.contract} (${f.path}): ${f.details}`);
    }
    process.exit(1);
  }

  console.log(`Firestore contract coverage gate passed. Writes discovered: ${writes.length}`);
  console.log(`Write surface artifact: ${path.relative(repoRoot, surfaceOutput).replace(/\\/g, '/')}`);
}

run();

#!/usr/bin/env node
/**
 * Proves the public documentation boundary (N85-42 AC1, N85-50 AC5 and AC6).
 *
 * It scans both the source tree and, when present, the built output. Scanning
 * the build matters as much as the source: a private hostname could arrive
 * through a component, a config value or a generated index rather than through
 * a Markdown page.
 *
 * Exit code 0 means clean. Any finding exits 1 and blocks deployment.
 */
import { readdir, readFile, stat } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const root = path.resolve(import.meta.dirname, '..');

/** Directories never worth scanning. */
const SKIP_DIRS = new Set(['node_modules', '.git', '.astro', '.vercel']);

/** Binary-ish extensions whose bytes are not text to scan. */
const SKIP_EXTENSIONS = new Set([
  '.png', '.jpg', '.jpeg', '.gif', '.webp', '.avif', '.ico',
  '.woff', '.woff2', '.ttf', '.otf', '.eot',
  '.mp4', '.webm', '.mp3', '.zip', '.gz', '.pdf',
]);

/**
 * Each rule states what must never appear in the public build and why, so a
 * failure explains itself rather than printing a bare regular expression.
 */
const RULES = [
  {
    id: 'private-docs-hostname',
    pattern: /docs\.n85\.dev/gi,
    reason:
      'docs.n85.dev is the private documentation service. No public page, asset, index or sitemap may reference it.',
  },
  {
    id: 'internal-only-marker',
    pattern: /\b(INTERNAL[ -]ONLY|CONFIDENTIAL|DO NOT PUBLISH|NOT FOR PUBLICATION)\b/gi,
    reason: 'Content marked internal must live in the private repository.',
  },
  {
    id: 'private-address-space',
    pattern: /\b(?:10\.\d{1,3}\.\d{1,3}\.\d{1,3}|192\.168\.\d{1,3}\.\d{1,3}|172\.(?:1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3})\b/g,
    reason:
      'A private IP address describes internal infrastructure. Use a reserved example range instead.',
  },
  {
    id: 'chatwoot-access-token',
    // Chatwoot personal access tokens are long opaque strings. This catches an
    // assignment shape rather than trying to recognise the token itself.
    pattern: /\b(?:access[_-]?token|api[_-]?key|secret[_-]?key|password)\s*[:=]\s*["']?[A-Za-z0-9_\-]{16,}["']?/gi,
    reason: 'This looks like a real credential. Public documentation must never carry one.',
  },
  {
    id: 'private-key-block',
    pattern: /-----BEGIN (?:RSA |EC |OPENSSH |PGP )?PRIVATE KEY-----/g,
    reason: 'A private key must never enter a public build.',
  },
  {
    id: 'apple-auth-key',
    pattern: /\bAuthKey_[A-Z0-9]{10}\b/g,
    reason: 'An Apple APNs authentication key filename suggests a real signing key.',
  },
  {
    id: 'aws-access-key',
    pattern: /\bAKIA[0-9A-Z]{16}\b/g,
    reason: 'An AWS access key ID must never enter a public build.',
  },
];

/**
 * Lines that legitimately name a forbidden pattern in order to forbid it.
 * Only this file and the boundary decision record may do so.
 */
const ALLOWED_FILES = new Set([
  path.join(root, 'scripts', 'check-content-boundary.mjs'),
]);

async function* walk(dir) {
  let entries;
  try {
    entries = await readdir(dir, { withFileTypes: true });
  } catch {
    return;
  }
  for (const entry of entries) {
    if (entry.name.startsWith('.') && entry.name !== '.well-known') continue;
    if (SKIP_DIRS.has(entry.name)) continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      yield* walk(full);
    } else if (entry.isFile()) {
      if (SKIP_EXTENSIONS.has(path.extname(entry.name).toLowerCase())) continue;
      yield full;
    }
  }
}

async function scan(targets) {
  const findings = [];
  for (const target of targets) {
    for await (const file of walk(target)) {
      if (ALLOWED_FILES.has(file)) continue;
      let text;
      try {
        text = await readFile(file, 'utf8');
      } catch {
        continue;
      }
      for (const rule of RULES) {
        rule.pattern.lastIndex = 0;
        let match;
        while ((match = rule.pattern.exec(text)) !== null) {
          const line = text.slice(0, match.index).split('\n').length;
          findings.push({
            file: path.relative(root, file),
            line,
            rule: rule.id,
            reason: rule.reason,
            excerpt: match[0].slice(0, 80),
          });
        }
      }
    }
  }
  return findings;
}

const targets = [path.join(root, 'src'), path.join(root, 'public')];
const dist = path.join(root, 'dist');
if (existsSync(dist)) {
  targets.push(dist);
} else {
  console.log('Note: dist/ is absent, so only the source tree was scanned.');
  console.log('Run "npm run build" first to scan the generated output too.\n');
}

const findings = await scan(targets);

if (findings.length === 0) {
  console.log(`Content boundary: clean. Scanned ${targets.map((t) => path.relative(root, t) || '.').join(', ')}.`);
  process.exit(0);
}

console.error(`Content boundary: ${findings.length} finding(s).\n`);
for (const finding of findings) {
  console.error(`  ${finding.file}:${finding.line}  [${finding.rule}]`);
  console.error(`    ${finding.reason}`);
  console.error(`    Found: ${finding.excerpt}\n`);
}
process.exit(1);

#!/usr/bin/env node
//
// check-tokens.mjs — the VS Code semantic-token correspondence, both directions.
//
// EHP P3. `semanticTokenScopes` was a legacy of the TextMate-first design and
// nobody revisited it when the query changed, so it had drifted into holding
// three entries nothing produced (`function.defaultLibrary`, `macro`, `label`)
// — the same rot as the nine dead capture entries P0 deleted, one layer along.
//
// Asserts:
//   1. every token type CAPTURE_MAP produces is declared in the LEGEND
//   2. every token type+modifier CAPTURE_MAP produces has a semanticTokenScopes
//      entry — otherwise the capture is computed and then painted by nothing
//   3. no semanticTokenScopes entry is dead (nothing produces it)
//   4. no LEGEND type is dead
//
// (2) is the one that matters: an unmapped token type fails SILENTLY. VS Code
// emits the token, no theme rule matches, and the text falls through to
// whatever TextMate said — which looks like working syntax highlighting.
//
// Usage: node parity/check-tokens.mjs        (exit 1 on any violation)

import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const EXT  = join(HERE, '..', '..', 'vscode-prologos');

const src = readFileSync(join(EXT, 'src', 'semanticTokens.ts'), 'utf8');
const pkg = JSON.parse(readFileSync(join(EXT, 'package.json'), 'utf8'));

// --- what the extension PRODUCES ---
const produced = new Set();   // "type" or "type.modifier..."
const baseTypes = new Set();
for (const m of src.matchAll(/\['([\w.]+)',\s*\['(\w+)',\s*\[([^\]]*)\]\]\]/g)) {
  const mods = m[3].split(',').map(x => x.trim().replace(/'/g, '')).filter(Boolean);
  produced.add([m[2], ...mods].join('.'));
  baseTypes.add(m[2]);
}

const legendMatch = src.match(/SemanticTokensLegend\(\s*(?:\/\/[^\n]*\n\s*)*\[([^\]]*)\]/s);
if (!legendMatch) throw new Error('could not parse the LEGEND — checker is broken, not the data');
const legend = legendMatch[1].split(',')
  .map(x => x.replace(/\/\/[^\n]*/g, '').trim().replace(/'/g, ''))
  .filter(Boolean);

// --- what the extension DECLARES a colour for ---
const scopes = {};
for (const e of pkg.contributes.semanticTokenScopes || []) {
  if (e.language === 'prologos') Object.assign(scopes, e.scopes);
}

// Vacuity guards: each parser above could silently yield nothing and make every
// assertion below trivially true.
for (const [name, coll] of [['produced', produced], ['legend', legend],
                            ['scopes', Object.keys(scopes)]]) {
  if (!coll.length && !coll.size) {
    console.error(`FATAL: parsed ZERO ${name} entries — the checker is broken, not the data`);
    process.exit(2);
  }
}

const fails = [];
for (const t of [...baseTypes].sort())
  if (!legend.includes(t)) fails.push(`CAPTURE_MAP produces token type '${t}' but the LEGEND omits it`);
for (const p of [...produced].sort())
  if (!(p in scopes)) fails.push(`'${p}' is produced but has NO semanticTokenScopes entry — VS Code would paint it with nothing`);
for (const s of Object.keys(scopes).sort())
  if (!produced.has(s)) fails.push(`semanticTokenScopes declares '${s}' but nothing produces it (dead entry)`);
for (const l of legend)
  if (!baseTypes.has(l)) fails.push(`LEGEND declares '${l}' but nothing produces it (dead type)`);

console.log(`  produced ${produced.size} · legend ${legend.length} · scoped ${Object.keys(scopes).length}`);
if (fails.length) {
  console.error('\nFAIL — semantic-token correspondence is broken:');
  for (const f of fails) console.error(`  ✗ ${f}`);
  process.exit(1);
}
console.log('\nPASS — every produced token type is in the legend and has a colour; no dead entries');

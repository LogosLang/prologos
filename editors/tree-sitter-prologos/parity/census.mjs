// census.mjs — EHP P2. Who paints what, with nothing removed.
//
// Emits a per-span census over the parity fixture: for every character span,
// which TextMate scope claims it, which highlights.scm capture claims it, and
// whether the two AGREE.
//
// Per §7.5 of the EHP design: we do not have to STRIP to SEE. Stripping first
// gives a period of visibly worse highlighting with no instrument to say whether
// it got worse — the same shape as every other trap this project has hit.
// Census first, then cut with evidence.
//
// FIDELITY MATTERS HERE. This uses `vscode-textmate` + `vscode-oniguruma` — the
// actual engine VS Code runs — not a JS-RegExp approximation. TextMate patterns
// are Oniguruma, a different dialect, and approximating it would produce a
// census that is wrong in exactly the way that then drives a product decision.
// (The same class of bug already cost us once on this track: the P1 harness
// evaluated `#match?` in the wrong dialect and would have blamed the correct
// editor.)
//
// Usage:  node census.mjs [fixture.prologos]

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const EXT  = join(HERE, '..', '..', 'vscode-prologos');
const FIX  = process.argv[2] || join(HERE, 'fixture.prologos');

// Both ship CommonJS; imported from ESM their API lands under `.default`.
const oniguruma = (await import(join(EXT, 'node_modules', 'vscode-oniguruma', 'release', 'main.js'))).default;
const vsctm     = (await import(join(EXT, 'node_modules', 'vscode-textmate', 'release', 'main.js'))).default;

// --- Oniguruma (wasm) ---
const wasmBin = readFileSync(join(EXT, 'node_modules', 'vscode-oniguruma', 'release', 'onig.wasm')).buffer;
await oniguruma.loadWASM(wasmBin);
const onigLib = Promise.resolve({
  createOnigScanner: (s) => new oniguruma.OnigScanner(s),
  createOnigString:  (s) => new oniguruma.OnigString(s),
});

// --- TextMate grammar ---
const registry = new vsctm.Registry({
  onigLib,
  loadGrammar: async (scopeName) =>
    scopeName === 'source.prologos'
      ? vsctm.parseRawGrammar(
          readFileSync(join(EXT, 'syntaxes', 'prologos.tmLanguage.json'), 'utf8'),
          'prologos.tmLanguage.json')
      : null,
});
const grammar = await registry.loadGrammar('source.prologos');

const source = readFileSync(FIX, 'utf8');
const lines  = source.split('\n');

// TextMate: the MOST SPECIFIC scope wins (last in the stack), which is what the
// theme colours. `source.prologos` alone means "unpainted by TextMate".
const tm = new Map();  // "line:col" -> scope
let ruleStack = vsctm.INITIAL;
lines.forEach((line, i) => {
  const r = grammar.tokenizeLine(line, ruleStack);
  ruleStack = r.ruleStack;
  for (const t of r.tokens) {
    const scope = t.scopes[t.scopes.length - 1];
    if (scope === 'source.prologos') continue;
    for (let c = t.startIndex; c < t.endIndex; c++) tm.set(`${i + 1}:${c}`, scope);
  }
});

// tree-sitter captures, from the committed golden (already agreed by BOTH
// consumers in P1 — so "what the query paints" is not in question here).
const ts = new Map();  // "line:col" -> capture
for (const l of readFileSync(join(HERE, 'golden.tsv'), 'utf8').split('\n')) {
  if (!l.trim()) continue;
  const [line, col, cap, text] = l.split('\t');
  const n = text.replace(/\\n/g, '\n').length;
  for (let c = 0; c < n; c++) ts.set(`${+line}:${+col + c}`, cap);
}

// --- Report ---
const both = [], tmOnly = new Map(), tsOnly = new Map();
const pairs = new Map();  // "capture -> scope" -> count

for (const [k, scope] of tm) {
  const cap = ts.get(k);
  if (cap === undefined) tmOnly.set(scope, (tmOnly.get(scope) || 0) + 1);
  else { both.push(k); const p = `${cap}\t${scope}`; pairs.set(p, (pairs.get(p) || 0) + 1); }
}
for (const [k, cap] of ts) if (!tm.has(k)) tsOnly.set(cap, (tsOnly.get(cap) || 0) + 1);

const totalChars = [...tm.keys()].length + [...ts.keys()].filter(k => !tm.has(k)).length;
console.log(`fixture: ${FIX.split('/').pop()}  (${lines.length} lines)`);
console.log(`painted chars — TextMate ${tm.size} · tree-sitter ${ts.size} · union ${totalChars}\n`);

console.log('=== OVERLAP: both layers paint it (capture ↔ scope pairing) ===');
[...pairs.entries()].sort((a, b) => b[1] - a[1]).forEach(([p, n]) => {
  const [cap, scope] = p.split('\t');
  console.log(`  ${String(n).padStart(5)}  @${cap.padEnd(22)} ${scope}`);
});

console.log('\n=== TEXTMATE ONLY: the permanent, sole authority for these ===');
[...tmOnly.entries()].sort((a, b) => b[1] - a[1]).forEach(([s, n]) =>
  console.log(`  ${String(n).padStart(5)}  ${s}`));

console.log('\n=== TREE-SITTER ONLY: TextMate leaves these to semantic tokens ===');
[...tsOnly.entries()].sort((a, b) => b[1] - a[1]).forEach(([c, n]) =>
  console.log(`  ${String(n).padStart(5)}  @${c}`));

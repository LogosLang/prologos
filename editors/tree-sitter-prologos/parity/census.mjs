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
// `--gate` additionally enforces the D3 AGREEMENT invariant: where both layers
// paint the same span, the TextMate scope must correspond to the capture, per
// queries/textmate-agreement.tsv. Exits non-zero on disagreement.
//
// Usage:  node census.mjs [fixture.prologos] [--gate]

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const EXT  = join(HERE, '..', '..', 'vscode-prologos');
const ARGV = process.argv.slice(2);
const GATE = ARGV.includes('--gate');
const FIX  = ARGV.find(a => !a.startsWith('--')) || join(HERE, 'fixture.prologos');

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

// tree-sitter captures — RESOLVED the way src/semanticTokens.ts resolves them:
// `query.captures()` order, FIRST MATCH PER START OFFSET wins, multi-line
// captures skipped (they cannot be one semantic token).
//
// ⚠ NOT the committed golden.  The golden is deliberately RAW — every match,
// canonically sorted — because that is the right contract for comparing two
// ENGINES.  It is the wrong input for this question: it still contains the
// `(identifier) @variable` fallback rows that first-match-wins discards, so
// comparing TextMate against it reports disagreements at spans where the
// consumer paints something else entirely.  Measured: doing that flagged `Int`
// as @variable-vs-support.type when the consumer actually paints @type.builtin,
// and the two layers agree.
const wasmPath = join(HERE, '..', 'tree-sitter-prologos.wasm');
const tsmod = await import(join(EXT, 'node_modules', 'web-tree-sitter', 'tree-sitter.js'));
await tsmod.Parser.init();
const lang   = await tsmod.Language.load(wasmPath);
const parser = new tsmod.Parser(); parser.setLanguage(lang);
const query  = new tsmod.Query(lang, readFileSync(join(HERE, '..', 'queries', 'highlights.scm'), 'utf8'));
const tree   = parser.parse(source);

const ts = new Map();  // "line:col" -> capture (resolved)
const claimed = new Set();
for (const cap of query.captures(tree.rootNode)) {
  const start = cap.node.startIndex;
  if (claimed.has(start)) continue;
  claimed.add(start);
  if (cap.node.startPosition.row !== cap.node.endPosition.row) continue;
  const row = cap.node.startPosition.row + 1;
  for (let c = cap.node.startPosition.column; c < cap.node.endPosition.column; c++) {
    ts.set(`${row}:${c}`, cap.name);
  }
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

// --- D3 AGREEMENT INVARIANT ---
const agree = new Map();
for (const line of readFileSync(join(HERE, '..', 'queries', 'textmate-agreement.tsv'), 'utf8').split('\n')) {
  if (!line.trim() || line.startsWith('#')) continue;
  const [cap, prefixes] = line.split('\t');
  agree.set(cap.trim(), prefixes.trim().split(/\s+/));
}
if (agree.size === 0) throw new Error('parsed ZERO agreement rows — checker is broken, not the data');

const GENERIC = agree.get('*GENERIC*') || [];
function isGeneric(scope) {
  return GENERIC.some(x => scope === x || scope.startsWith(x + '.'));
}

function allowed(cap, scope) {
  // TextMate having nothing specific to say is not a disagreement.
  if (isGeneric(scope)) return true;
  // dotted-prefix fallback on the CAPTURE, same as the consumers use
  let parts = cap.split('.');
  while (parts.length) {
    const p = agree.get(parts.join('.'));
    if (p) return p.some(x => scope === x || scope.startsWith(x + '.'));
    parts.pop();
  }
  return false;   // capture with no correspondence declared
}

const bad = [...pairs.entries()]
  .map(([p, n]) => { const [cap, scope] = p.split('\t'); return { cap, scope, n }; })
  .filter(e => !allowed(e.cap, e.scope))
  .sort((a, b) => b.n - a.n);

console.log('\n=== D3 AGREEMENT: overlapping spans where the two layers DISAGREE ===');
if (bad.length === 0) {
  console.log('  none — every overlap agrees');
} else {
  for (const e of bad) console.log(`  ${String(e.n).padStart(5)}  @${e.cap.padEnd(22)} ${e.scope}`);
  console.log(`\n  ${bad.length} disagreeing pair(s), ${bad.reduce((s, e) => s + e.n, 0)} chars`);
}
if (GATE && bad.length) process.exit(1);

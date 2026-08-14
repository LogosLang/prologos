// dump-captures.mjs — VS Code side of the EHP parity harness.
//
// Prints one TSV line per capture:  LINE <TAB> COL <TAB> CAPTURE <TAB> TEXT
// identical in format to dump-captures.el, over the SAME queries/highlights.scm.
//
// Deliberately goes through `web-tree-sitter` — the same library and the same
// .wasm that src/semanticTokens.ts loads at runtime. Reading the query with a
// different engine would test nothing: the point is that the path VS Code
// ACTUALLY renders through agrees with the path Emacs actually renders through.
//
// Note there is no predicate-translation step here, and that asymmetry is the
// finding rather than an oversight: web-tree-sitter evaluates `#match?` with
// JS RegExp, which already speaks the PCRE-ish dialect highlights.scm is
// written in. Emacs does not, which is why its side needs a translator. Same
// query, two dialects, one of which needs a bridge.
//
// Usage:  node dump-captures.mjs fixture.prologos

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const WASM = join(HERE, '..', 'tree-sitter-prologos.wasm');
const QUERY = join(HERE, '..', 'queries', 'highlights.scm');

const file = process.argv[2];
if (!file) {
  console.error('usage: node dump-captures.mjs FILE.prologos');
  process.exit(2);
}

// Resolve web-tree-sitter from the extension, so we use the SAME version the
// extension ships rather than whatever a hoisted install provides.
const { Parser, Language, Query } = await import(
  join(HERE, '..', '..', 'vscode-prologos', 'node_modules', 'web-tree-sitter', 'tree-sitter.js')
);

await Parser.init();
const lang = await Language.load(WASM);
const parser = new Parser();
parser.setLanguage(lang);

const source = readFileSync(file, 'utf8');
const tree = parser.parse(source);
const query = new Query(lang, readFileSync(QUERY, 'utf8'));

const rows = [];
for (const cap of query.captures(tree.rootNode)) {
  rows.push([
    cap.node.startPosition.row + 1,      // 1-based line, matching Emacs
    cap.node.startPosition.column,       // 0-based column, matching Emacs
    cap.name,
    cap.node.text.replace(/\n/g, '\\n'), // one capture is always one line
  ]);
}

// Canonical order — must match dump-captures.el exactly, so the comparison
// never depends on either engine's traversal order.
rows.sort((a, b) =>
  a[0] !== b[0] ? a[0] - b[0]
  : a[1] !== b[1] ? a[1] - b[1]
  : a[2] < b[2] ? -1 : a[2] > b[2] ? 1 : 0);

for (const r of rows) process.stdout.write(r.join('\t') + '\n');

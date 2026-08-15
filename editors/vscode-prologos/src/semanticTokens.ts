import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';
import { Parser, Language, Query, Node } from 'web-tree-sitter';

/**
 * Tree-sitter-driven semantic highlighting.
 *
 * The TextMate grammar in `syntaxes/prologos.tmLanguage.json` is regex-based:
 * it colours tokens, but it cannot tell a parameter from a call, a type from a
 * value, or a binding occurrence from a use — none of that is expressible
 * without a parse. This provider runs the SAME grammar Emacs uses, compiled to
 * wasm, and drives VS Code's semantic-token layer from `queries/highlights.scm`.
 *
 * Semantic tokens LAYER OVER TextMate rather than replacing it: anything we do
 * not capture keeps its TextMate colour, so this degrades to the status quo
 * instead of to nothing.
 */

/** Capture name -> [VS Code token type, ...modifiers].
 *
 * A Map, not an object literal: capture names come from the grammar, and a
 * plain-object lookup on names like `constructor` or `__proto__` returns
 * PROTOTYPE members rather than undefined. (TypeScript flagged the
 * `constructor` key, which is how this surfaced.) */
/* ⭐ SCOPE-FALLBACK PRINCIPLE — CONVENTION PARITY (owner ruling, 2026-08-15).
 *
 * The semanticTokenScopes fallbacks in package.json must resolve each concept
 * to the scope the ecosystem's MOST-THEMED grammar uses for the SAME concept:
 * map keys -> `support.type.property-name' (what JSON keys are), definitions
 * -> `meta.definition.variable' / `entity.name.variable' (what TS/JS emit),
 * parameters -> `variable.parameter'.  NEVER a Prologos-private scope
 * (`variable.other.property.prologos' etc.) — no theme has heard of those, so
 * every theme resolves them by accident, and FOUR paint attempts failed that
 * way in one day (attribute-name, constant.language, constant.other, and a
 * shipped colour override, all retired).  Under convention parity a theme
 * renders Prologos exactly as it renders its JSON and its TypeScript — which
 * is the theme's own coherent aesthetic, the maximum achievable without
 * painting over anyone's theme, and instantly checkable: open a .json file
 * beside a .prologos file and the keys must match. */
const CAPTURE_MAP = new Map<string, [string, string[]]>([
  ['keyword', ['keyword', []]],
  ['function', ['function', []]],
  // The bare `variable' catch-all is DELIBERATELY UNMAPPED.  It claims every
  // otherwise-unmatched identifier — 6123 winning spans in core/, 79.3% of
  // them plain `atom' references — so assigning it a semantic role paints
  // over half the buffer.  Emacs has always left it nil; this is the same
  // restraint on this side.  Recorded in parity/known-gaps.tsv.
  // ⚠ Visually inert: TextMate's own identifier rule already paints these
  // `variable.other.prologos', the SAME scope this token resolved to.
  ['variable.definition', ['variable', ['declaration']]],
  ['variable.parameter', ['parameter', []]],
  ['type', ['type', []]],
  ['type.builtin', ['type', ['defaultLibrary']]],
  ['type.definition', ['type', ['declaration']]],
  ['constant', ['variable', ['readonly']]],
  ['constant.builtin', ['variable', ['readonly', 'defaultLibrary']]],
  ['constructor', ['enumMember', []]],
  ['number', ['number', []]],
  ['string', ['string', []]],
  // Char literals are string-like; mapping them to an EXISTING legend type
  // needs no protocol change.  Was dropped entirely before 2026-08-14.
  ['character', ['string', []]],
  // `@attribute' — multiplicities (`:0' `:1' `:w') and the keyword in a
  // metadata / trait-metadata / law entry.  `decorator' is the standard VS Code
  // type for annotations.  The COLOUR is not a fresh choice: TextMate already
  // paints multiplicities `storage.modifier.multiplicity.prologos', so the
  // semanticTokenScopes entry points at the same `storage.modifier' family and
  // the two layers land on one colour (EHP P3, closing the last known gap).
  ['attribute', ['decorator', []]],
  ['comment', ['comment', []]],
  ['operator', ['operator', []]],
  ['module', ['namespace', []]],
  // `:foo' — the Neovim standard capture for symbols/atoms (what Clojure and
  // Elixir keywords use).  Mapped EXPLICITLY rather than left to the
  // `string.special.symbol' -> `string.special' -> `string' fallback, which
  // would have silently recoloured every keyword literal as a string: the
  // rename is a vocabulary change, and the colour decision belongs to EHP P3.
  // A keyword VALUE is a constant-family thing, and stays one.  The 2026-08-15
  // chrome chase ended when DEFERRED 142 gave layout-map KEYS real structure:
  // keys are @property nodes now, so the key/value distinction lives in the
  // GRAMMAR and flows through the shared pipeline — the shipped colour
  // override (custom token + configurationDefaults) was retired the same day,
  // per the owner: an extension must not paint over other people's themes.
  ['string.special.symbol', ['variable', ['readonly']]],
  ['variable.logic', ['variable', []]],
  // An unsolved hole is not an ordinary variable — it is the one thing in the
  // buffer that WANTS attention.  Emacs has said so since the start
  // (prologos-hole-face = font-lock-warning-face + box); VS Code rendered it
  // identically to every other variable until 2026-08-15, when
  // check-families.sh made the disagreement visible.  The `unsolved' modifier
  // exists so semanticTokenScopes can point it somewhere themes actually paint.
  ['variable.hole', ['variable', ['unsolved']]],
  ['property', ['property', []]],
]);

export const LEGEND = new vscode.SemanticTokensLegend(
  // Every entry here is produced by CAPTURE_MAP above; parity/check-tokens.mjs
  // gates that in both directions.  `macro' and `label' were removed in EHP P3:
  // nothing emitted them and captures.md never declared them.
  ['keyword', 'function', 'variable', 'parameter', 'type', 'enumMember',
   'number', 'string', 'comment', 'operator', 'namespace', 'property',
   'decorator'],
  ['declaration', 'readonly', 'defaultLibrary', 'unsolved'],
);

/**
 * True when NODE sits inside (or is) an ERROR subtree.
 *
 * Where the parse is known-wrong, trusting it produces *confidently wrong*
 * colour, which is worse than none: TextMate still covers the region, so
 * suppressing here degrades to the status quo rather than to nothing.
 *
 * The concrete case (TSG T1 §9.3): a doubled `]` in `foray.prologos` puts the
 * region in ERROR, and `type_application` — `prec.left(2, seq(identifier,
 * repeat1(...)))`, with no extent bound — then absorbs every identifier-shaped
 * token across SIX lines, including a `def` keyword. The query faithfully
 * painted all of it `@type`. Note the multi-line guard below does not catch
 * this: the runaway node is multi-line, but the captures are its single-line
 * identifier children.
 *
 * This bounds the blast radius of every future grammar gap, not just that one.
 *
 * ⚠ `isError`, walking ANCESTORS — deliberately not `hasError`, which is true
 * for any node with a bad descendant and would therefore be true at the root of
 * every imperfect file, suppressing the entire document.
 */
function insideErrorSubtree(node: Node): boolean {
  for (let n: Node | null = node; n; n = n.parent) {
    if (n.isError) return true;
  }
  return false;
}

export class PrologosSemanticTokens implements vscode.DocumentSemanticTokensProvider {
  private parser: Parser | undefined;
  private query: Query | undefined;
  private ready: Promise<void>;

  constructor(private extensionPath: string, private channel: vscode.OutputChannel) {
    this.ready = this.init();
  }

  private async init(): Promise<void> {
    try {
      await Parser.init();
      const wasmPath = path.join(this.extensionPath, 'grammars', 'tree-sitter-prologos.wasm');
      const queryPath = path.join(this.extensionPath, 'queries', 'highlights.scm');
      if (!fs.existsSync(wasmPath)) {
        this.channel.appendLine(`semantic tokens: grammar wasm not found at ${wasmPath}`);
        this.channel.appendLine('  build it: cd editors/tree-sitter-prologos && tree-sitter build --wasm');
        return;
      }
      const lang = await Language.load(wasmPath);
      this.parser = new Parser();
      this.parser.setLanguage(lang);
      this.query = new Query(lang, fs.readFileSync(queryPath, 'utf8'));
      this.channel.appendLine('semantic tokens: tree-sitter grammar loaded');
    } catch (err: any) {
      // Never let this take the extension down — TextMate highlighting stays.
      this.channel.appendLine(`semantic tokens: disabled (${err?.message ?? err})`);
    }
  }

  async provideDocumentSemanticTokens(
    document: vscode.TextDocument,
    _token: vscode.CancellationToken,
  ): Promise<vscode.SemanticTokens | undefined> {
    await this.ready;
    if (!this.parser || !this.query) return undefined;

    const tree = this.parser.parse(document.getText());
    if (!tree) return undefined;

    const builder = new vscode.SemanticTokensBuilder(LEGEND);

    // FIRST MATCH WINS, which is tree-sitter's own convention and matters
    // here: `add-ten` is captured as both @function (specific, listed first)
    // and @variable (the catch-all). Emitting both would let the generic one
    // win in the editor. Keyed by start offset so a later, broader capture at
    // the same position is dropped.
    const claimed = new Set<number>();

    for (const cap of this.query.captures(tree.rootNode)) {
      const mapping = CAPTURE_MAP.get(cap.name)
        // `foo.bar.baz` falls back to `foo.bar`, then `foo`.
        ?? CAPTURE_MAP.get(cap.name.split('.').slice(0, -1).join('.'))
        ?? CAPTURE_MAP.get(cap.name.split('.')[0]);
      if (!mapping) continue;

      // Known-wrong parse: leave the region to TextMate rather than colouring
      // it confidently wrong.  Checked BEFORE claiming, so a suppressed capture
      // does not block a later valid one at the same offset.
      if (insideErrorSubtree(cap.node)) continue;

      const start = cap.node.startIndex;
      if (claimed.has(start)) continue;
      claimed.add(start);

      // Multi-line captures cannot be expressed as one token; skip rather than
      // emit a wrong range (comments and strings are TextMate's job anyway).
      if (cap.node.startPosition.row !== cap.node.endPosition.row) continue;

      builder.push(
        cap.node.startPosition.row,
        cap.node.startPosition.column,
        cap.node.endPosition.column - cap.node.startPosition.column,
        LEGEND.tokenTypes.indexOf(mapping[0]),
        mapping[1].reduce((acc, m) => acc | (1 << LEGEND.tokenModifiers.indexOf(m)), 0),
      );
    }

    tree.delete();
    return builder.build();
  }
}

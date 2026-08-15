/**
 * External scanner for tree-sitter-prologos.
 *
 * Emits INDENT, DEDENT, and NEWLINE tokens based on indentation changes,
 * following the same logic as reader.rkt (lines 40-280).
 *
 * Key rules (from reader.rkt):
 *   - INDENT/DEDENT/NEWLINE only emitted when bracket_depth == 0
 *   - Blank lines and comment-only lines are skipped
 *   - Tabs are forbidden (spaces only)
 *   - Multiple DEDENTs can be emitted when dedenting past several levels
 *   - At EOF, remaining DEDENTs are emitted to close all open levels
 *
 * Important: Newline characters must be consumed with advance() (not skip())
 * so that the resulting tokens have non-zero size. Tree-sitter ignores
 * zero-width external tokens to prevent infinite loops.
 */

#include "tree_sitter/parser.h"
#include <string.h>
#include <stdlib.h>
#include <stdbool.h>

/* Token types — must match the order in grammar.js externals array.
 * APPEND ONLY: the correspondence is positional, so inserting in the middle
 * silently renumbers every token after it. */
enum TokenType {
  INDENT,
  DEDENT,
  NEWLINE,
  SAME_LINE_BODY,
  MAP_OPEN,
  ARM_LPAREN,
  LET_OPEN,
  LET_ALIGN,
  KV_KEY,
  INFIX_CMP,
};

/* Scanner state */
#define MAX_INDENT_STACK 128
#define MAX_LET_STACK 32

typedef struct {
  int indent_stack[MAX_INDENT_STACK];
  int stack_size;
  /* Number of pending DEDENT tokens to emit before the next NEWLINE.
   * When we dedent past multiple levels, we emit one DEDENT per level.
   * The NEWLINE that follows the dedents is also tracked separately. */
  int pending_dedents;
  bool pending_newline_after_dedents;
  /* Column of the FIRST BINDING of each currently-open layout `let`.
   *
   * This is the discriminator the LR state cannot have.  Nested and aligned
   * `let`s are the SAME token sequence — `let`, binding, INDENT — differing
   * only in how deep the indent is RELATIVE TO THIS COLUMN:
   *
   *     let y 4              let y 4
   *       let z 5                z 5
   *       ^ shallower  =>        ^ equal  =>
   *         the BODY               a CONTINUATION BINDING
   *
   * Per-`let` rather than per-line: a `let` whose body is another `let` at the
   * same column is a sibling chain, not a continuation (design §5.2). */
  int let_col_stack[MAX_LET_STACK];
  int let_depth;
} Scanner;

/* ============================================================
 * Lifecycle
 * ============================================================ */

void *tree_sitter_prologos_external_scanner_create(void) {
  Scanner *s = calloc(1, sizeof(Scanner));
  s->indent_stack[0] = 0;
  s->stack_size = 1;
  s->pending_dedents = 0;
  s->pending_newline_after_dedents = false;
  return s;
}

void tree_sitter_prologos_external_scanner_destroy(void *payload) {
  free(payload);
}

/* ============================================================
 * Serialization (for incremental re-parsing)
 * ============================================================ */

unsigned tree_sitter_prologos_external_scanner_serialize(
    void *payload, char *buffer) {
  Scanner *s = (Scanner *)payload;
  unsigned offset = 0;

  /* pending_dedents (1 byte) */
  if (offset + 1 > TREE_SITTER_SERIALIZATION_BUFFER_SIZE) return offset;
  buffer[offset++] = (char)s->pending_dedents;

  /* pending_newline_after_dedents (1 byte) */
  if (offset + 1 > TREE_SITTER_SERIALIZATION_BUFFER_SIZE) return offset;
  buffer[offset++] = s->pending_newline_after_dedents ? 1 : 0;

  /* stack_size (1 byte, max 128) */
  if (offset + 1 > TREE_SITTER_SERIALIZATION_BUFFER_SIZE) return offset;
  buffer[offset++] = (char)s->stack_size;

  /* indent levels (2 bytes each — levels are small) */
  for (int i = 0; i < s->stack_size; i++) {
    if (offset + 2 > TREE_SITTER_SERIALIZATION_BUFFER_SIZE) break;
    int16_t level = (int16_t)s->indent_stack[i];
    memcpy(buffer + offset, &level, 2);
    offset += 2;
  }

  /* let-column stack, APPENDED AFTER the variable-length indent array.
   *
   * The position matters.  The indent array has no terminator and its length
   * is implied by stack_size, so anything new has to go after it.  Putting it
   * here also makes the format backward-compatible in the direction that can
   * actually happen: state written by a parser without this field simply runs
   * out of bytes, and `deserialize` leaves let_depth at 0 — "no open lets" —
   * rather than reading indent levels as columns. */
  if (offset + 1 <= TREE_SITTER_SERIALIZATION_BUFFER_SIZE) {
    buffer[offset++] = (char)s->let_depth;
    for (int i = 0; i < s->let_depth; i++) {
      if (offset + 2 > TREE_SITTER_SERIALIZATION_BUFFER_SIZE) break;
      int16_t col = (int16_t)s->let_col_stack[i];
      memcpy(buffer + offset, &col, 2);
      offset += 2;
    }
  }

  return offset;
}

void tree_sitter_prologos_external_scanner_deserialize(
    void *payload, const char *buffer, unsigned length) {
  Scanner *s = (Scanner *)payload;
  s->pending_dedents = 0;
  s->pending_newline_after_dedents = false;
  s->indent_stack[0] = 0;
  s->stack_size = 1;
  /* Reset here, not after the reads: every short-buffer path below returns
   * early, and each one must leave "no open lets" rather than stale columns. */
  s->let_depth = 0;

  if (length == 0) return;

  unsigned offset = 0;

  if (offset + 1 > length) return;
  s->pending_dedents = (unsigned char)buffer[offset++];

  if (offset + 1 > length) return;
  s->pending_newline_after_dedents = buffer[offset++] != 0;

  if (offset + 1 > length) return;
  s->stack_size = (unsigned char)buffer[offset++];

  for (int i = 0; i < s->stack_size; i++) {
    if (offset + 2 > length) {
      s->stack_size = i;
      break;
    }
    int16_t level;
    memcpy(&level, buffer + offset, 2);
    s->indent_stack[i] = level;
    offset += 2;
  }

  if (s->stack_size == 0) {
    s->indent_stack[0] = 0;
    s->stack_size = 1;
  }

  /* let-column stack — only if bytes remain.  Older state stops here. */
  if (offset + 1 <= length) {
    int depth = (unsigned char)buffer[offset++];
    for (int i = 0; i < depth; i++) {
      if (offset + 2 > length) break;
      int16_t col;
      memcpy(&col, buffer + offset, 2);
      offset += 2;
      if (s->let_depth < MAX_LET_STACK) s->let_col_stack[s->let_depth++] = col;
    }
  }
}

/* ============================================================
 * Scan logic
 * ============================================================ */

static inline void advance_ch(TSLexer *lexer) {
  lexer->advance(lexer, false);
}

static inline void skip_ch(TSLexer *lexer) {
  lexer->advance(lexer, true);
}

bool tree_sitter_prologos_external_scanner_scan(
    void *payload, TSLexer *lexer, const bool *valid_symbols) {
  Scanner *s = (Scanner *)payload;

  /* During ERROR RECOVERY tree-sitter calls the scanner with EVERY symbol
   * valid — a state no grammar rule can produce, since LET_OPEN (only after
   * the `let` keyword) and SAME_LINE_BODY (only after a defn param list) have
   * no legitimate common position.  The let tokens must sit out recovery:
   * LET_OPEN would push a bogus column inside any broken region (and never
   * pop it), and LET_ALIGN fires on coincidental column matches against that
   * stale stack — measured as +23 ERROR churn in track7-acceptance and +2 in
   * ppn-track4, files whose only `let` is in a COMMENT.  The pre-existing
   * tokens are left as they were: they are content-gated, their recovery
   * behaviour is part of the committed baseline, and changing it here would
   * make this change unattributable. */
  bool in_error_recovery =
      valid_symbols[SAME_LINE_BODY] && valid_symbols[LET_OPEN] &&
      valid_symbols[ARM_LPAREN] && valid_symbols[MAP_OPEN];

  /* --- Emit pending DEDENTs from a multi-level dedent --- */
  if (s->pending_dedents > 0 && valid_symbols[DEDENT]) {
    s->pending_dedents--;
    lexer->result_symbol = DEDENT;
    return true;
  }

  /* --- After a multi-level dedent, a continuation binding may land EXACTLY
   *     on the open let's binding column --- the multi-line-value case:
   *
   *         let k : Int := match a
   *                          | 1 -> 10
   *             j 5                     <- dedents from the arms to col of k
   *
   * The dedent scan already consumed the newline and positioned the lexer at
   * the line's first content character, so its column IS the line's indent.
   * When it equals the top of the let stack, this line is a binding, and the
   * queued NEWLINE would end the binding phase instead --- so LET_ALIGN takes
   * priority over the pending NEWLINE, and only over that. */
  if (s->pending_newline_after_dedents && s->pending_dedents == 0
      && valid_symbols[LET_ALIGN] && !in_error_recovery && s->let_depth > 0
      && (int)lexer->get_column(lexer) == s->let_col_stack[s->let_depth - 1]) {
    s->pending_newline_after_dedents = false;
    lexer->result_symbol = LET_ALIGN;
    return true;
  }

  /* --- Emit pending NEWLINE after all dedents are done --- */
  if (s->pending_newline_after_dedents && s->pending_dedents == 0
      && valid_symbols[NEWLINE]) {
    s->pending_newline_after_dedents = false;
    lexer->result_symbol = NEWLINE;
    return true;
  }

  /* --- At EOF, emit DEDENTs to close all open indent levels --- */
  if (lexer->eof(lexer)) {
    if (s->stack_size > 1 && valid_symbols[DEDENT]) {
      s->stack_size--;
      lexer->result_symbol = DEDENT;
      return true;
    }
    return false;
  }

  /* --- Only process indentation at the start of a line ---
   *
   * The tree-sitter convention: the scanner is called when the
   * parser needs a token. If the parser expects INDENT/DEDENT/NEWLINE,
   * we look at the current line's indentation.
   */

  /* --- SAME_LINE_BODY: a zero-width marker meaning "the body is on THIS
   *     line, not on an indented line below".
   *
   * This exists so the SCANNER decides `defn f [x] body` vs `defn f [x]` +
   * indented body, instead of the parser.  Rule-shaping cannot do it: `[x]`
   * and `[body]` are both bracket groups, so the parser cannot tell a second
   * param list from a body, and every grammar-level formulation of the choice
   * degraded tree-sitter's ERROR RECOVERY badly (measured: swallows 6 -> 24).
   *
   * Here the branch is chosen by ONE token on ONE character of lookahead, so
   * it is an ordinary shift, not an ambiguity.
   *
   * Correctness rests on the grammar making this token valid ONLY after a
   * param list (the same-line branch requires params).  Otherwise it would
   * fire immediately after `defn NAME`, swallow `[x]` as the body, and leave
   * the real body stranded. */
  if (valid_symbols[SAME_LINE_BODY]) {
    /* Mark the end BEFORE looking ahead, so the token stays zero-width at the
     * current position no matter how much whitespace we consume peeking. */
    lexer->mark_end(lexer);

    while (!lexer->eof(lexer) &&
           (lexer->lookahead == ' ' || lexer->lookahead == '\t' ||
            lexer->lookahead == '\r')) {
      skip_ch(lexer);
    }

    /* Content on this line that is not a newline, EOF or a comment means the
     * body starts here.  A comment does NOT count: `defn f [x]  ;; note` has
     * its body below.
     *
     * `<` and `:` are ALSO excluded, and that is not cosmetic: they begin a
     * RETURN TYPE (`defn f [x] <Bool>` / `defn f [x] : Bool`).  Without this
     * the marker fires before the return type, the parser takes `<Bool>` as
     * the same-line BODY, and the indented real body is swallowed into it —
     * measured as a 3-error, whole-body ERROR node.  GLR hides it when the
     * body is simple, so it surfaces only on complex bodies, which is exactly
     * the shape `lattices.prologos` is full of.
     *
     * Suppressing here is correct rather than a workaround: a body genuinely
     * starting with `<` would be an angle GROUP, which is type-level syntax by
     * the delimiter convention, and one starting with `:` would be a bare
     * keyword literal.  Neither is a real defn body.  After the parser consumes
     * the return type the scanner is asked again, and decides properly then. */
    if (!lexer->eof(lexer) && lexer->lookahead != '\n' &&
        lexer->lookahead != ';' && lexer->lookahead != '<' &&
        lexer->lookahead != ':') {
      lexer->result_symbol = SAME_LINE_BODY;
      return true;
    }
    /* Otherwise fall through to the ordinary INDENT/DEDENT/NEWLINE handling.
     * Falling through is safe: the whitespace we skipped above is exactly what
     * that path skips first anyway. */
  }

  /* --- LET_OPEN: a zero-width marker after `let`, recording the COLUMN of the
   *     first binding.
   *
   * That column is the whole point.  It is the only thing separating an
   * ALIGNED continuation binding from the BODY of the `let`, and the LR state
   * does not have it: both are `let`, binding, INDENT, and differ only in the
   * indent's depth relative to this column.  `prologos-syntax.md` states the
   * rule directly — the body "sits strictly between the `let` column and the
   * binding column".
   *
   * Two grammar-only formulations were built and measured before falling back
   * here (design §2).  Both made the aligned block bind correctly and both
   * regressed the shapes they were NOT about: the sibling chain gained an
   * ERROR and the nested form bound the literal `let` AS A NAME.
   *
   * Declining on `[` is what leaves the BRACKET branch reachable: at this
   * point the parser has not chosen between `let [x 4 y 5]` and the layout
   * form, so the scanner refusing the token is what selects bracket.
   *
   * Per design §5.1 and the `_same_line_body` precedent, correctness also
   * rests on the GRAMMAR making this token valid only in the layout branch —
   * a token that can fire a position early strands the thing it was meant to
   * introduce. */
  if (valid_symbols[LET_OPEN] && !in_error_recovery) {
    /* Mark first: the token stays zero-width wherever the peek ends up. */
    lexer->mark_end(lexer);

    while (!lexer->eof(lexer) &&
           (lexer->lookahead == ' ' || lexer->lookahead == '\t' ||
            lexer->lookahead == '\r')) {
      skip_ch(lexer);
    }

    if (!lexer->eof(lexer) && lexer->lookahead != '\n' &&
        lexer->lookahead != ';' && lexer->lookahead != '[') {
      if (s->let_depth < MAX_LET_STACK) {
        s->let_col_stack[s->let_depth++] = (int)lexer->get_column(lexer);
      }
      lexer->result_symbol = LET_OPEN;
      return true;
    }
    /* Fall through — do NOT `return false' here.
     *
     * LET_OPEN can be valid AT THE SAME TIME as INDENT/DEDENT/NEWLINE, and
     * returning would suppress the layout tokens the parser was also asking
     * for.  Measured: the returning version scored 8 files better, 15 WORSE,
     * with foray.prologos going E122 -> E170 — damage concentrated in files
     * containing no aligned `let` at all, which is the error-recovery churn
     * signature.  `_same_line_body' falls through for exactly this reason and
     * says so.
     *
     * Safe for the same reason it is safe there: the only thing consumed above
     * is horizontal whitespace, which the layout path skips first anyway. */
  }

  /* --- KV_KEY: a zero-width marker before a keyword literal that OPENS A
   *     LAYOUT-MAP ENTRY, as opposed to a keyword that IS a value.
   *
   * The compiler's contract (census, 2026-08-15): an entry REQUIRES a
   * payload — a same-line value, or an INDENT block below.  A bare `:foo`
   * body is the VALUE :foo (`x : Keyword`), so `kv_entry` vs `atom` at a
   * keyword_literal is undecidable in the LR state — the payload sits after
   * the keyword — but decidable HERE with lookahead, which makes the branch
   * an ordinary shift.  Emitting KV_KEY also severs the application-glom:
   * an expression value cannot absorb the next entry's keyword, because that
   * keyword now arrives behind a token application cannot consume.
   *
   * Stateless: nothing to serialize. */
  if (valid_symbols[KV_KEY] && !in_error_recovery) {
    lexer->mark_end(lexer);   /* zero-width, wherever the peek wanders */

    while (!lexer->eof(lexer) &&
           (lexer->lookahead == ' ' || lexer->lookahead == '\t' ||
            lexer->lookahead == '\r')) {
      skip_ch(lexer);
    }

    if (lexer->lookahead == ':') {
      int key_col = (int)lexer->get_column(lexer);
      advance_ch(lexer);
      /* Must be a KEYWORD (`:name`), not `:=` / `:0` / a lone colon. */
      if ((lexer->lookahead >= 'a' && lexer->lookahead <= 'z') ||
          (lexer->lookahead >= 'A' && lexer->lookahead <= 'Z') ||
          lexer->lookahead == '_') {
        /* Consume the keyword body (the grammar's own charset). */
        while (!lexer->eof(lexer) &&
               ((lexer->lookahead >= 'a' && lexer->lookahead <= 'z') ||
                (lexer->lookahead >= 'A' && lexer->lookahead <= 'Z') ||
                (lexer->lookahead >= '0' && lexer->lookahead <= '9') ||
                lexer->lookahead == '_' || lexer->lookahead == '?' ||
                lexer->lookahead == '!' || lexer->lookahead == '-' ||
                lexer->lookahead == '\'')) {
          advance_ch(lexer);
        }
        while (!lexer->eof(lexer) &&
               (lexer->lookahead == ' ' || lexer->lookahead == '\t' ||
                lexer->lookahead == '\r')) {
          skip_ch(lexer);
        }
        if (!lexer->eof(lexer) && lexer->lookahead != '\n' &&
            lexer->lookahead != ';') {
          /* Same-line payload — this keyword is a KEY. */
          lexer->result_symbol = KV_KEY;
          return true;
        }
        /* No same-line payload: a key iff an INDENT BLOCK follows.  Peek the
         * next real line's indent (skipping blanks and comment-only lines,
         * as the layout path does) and compare against the key's column. */
        {
          int indent = 0;
          bool found_line = false;
          while (!lexer->eof(lexer) && !found_line) {
            if (lexer->lookahead == '\n') { indent = 0; advance_ch(lexer); }
            else if (lexer->lookahead == ' ') { indent++; advance_ch(lexer); }
            else if (lexer->lookahead == '\t' || lexer->lookahead == '\r') {
              advance_ch(lexer);
            } else if (lexer->lookahead == ';') {
              while (!lexer->eof(lexer) && lexer->lookahead != '\n')
                advance_ch(lexer);
            } else {
              found_line = true;
            }
          }
          if (found_line && indent > key_col) {
            lexer->result_symbol = KV_KEY;
            return true;
          }
        }
      }
    }
    /* Fall through — the whitespace consumed above is what every later
     * branch skips first anyway (the LET_OPEN lesson: never return false
     * from a shared position). */
  }

  /* --- INFIX_CMP: `<' `<=' `>' `>=' inside a `.( ... )' infix group.
   *
   * The bare `<' is a SHARED TERMINAL with the angle-group open, and the
   * expression grammar is greedy: application absorbs `< 5' as an angle
   * argument and error recovery invents the closing `>' (measured: MISSING
   * rose at every `.(3 < 5)' site).  External tokens PREEMPT the internal
   * lexer, so where the grammar declares this token valid — operand position
   * inside a dot group, and nowhere else — a comparison char is an OPERATOR
   * by construction and the angle reading never starts.  Stateless. */
  if (valid_symbols[INFIX_CMP] && !in_error_recovery) {
    while (!lexer->eof(lexer) &&
           (lexer->lookahead == ' ' || lexer->lookahead == '\t' ||
            lexer->lookahead == '\r')) {
      skip_ch(lexer);
    }
    if (lexer->lookahead == '<' || lexer->lookahead == '>') {
      advance_ch(lexer);
      if (lexer->lookahead == '=') advance_ch(lexer);
      lexer->mark_end(lexer);
      lexer->result_symbol = INFIX_CMP;
      return true;
    }
  }

  /* --- ARM_LPAREN: a `(` that opens a MATCH ARM, not a paren expression.
   *
   * `match h (mk-handle idx -> …)` writes arms inline in parens.  At the `(`
   * the parser cannot tell an arm from a `paren_expr`, because the only
   * distinguisher — the `->` — is arbitrarily far ahead, and inside the group
   * `true` is ambiguous between `atom` and `literal_pattern`.  That is an
   * LR(1) problem and precedence cannot fix it; the earlier grammar-level
   * attempts produced a cascading conflict family.
   *
   * The scanner has UNBOUNDED lookahead, so it settles it here: scan to the
   * matching `)` and emit ARM_LPAREN only if a `->` occurs at depth 0 inside.
   * `paren_expr` then starts with a DIFFERENT TOKEN and the ambiguity is gone
   * by construction rather than by precedence.
   *
   * Strings and comments are skipped so an `->` inside them cannot decide it. */
  if (valid_symbols[ARM_LPAREN]) {
    /* The scanner is entered wherever the parser stopped, which for
     * `match h (arm)` is the SPACE before the paren — not the paren.  Skip
     * horizontal whitespace first, with skip_ch so it stays out of the token. */
    while (!lexer->eof(lexer) &&
           (lexer->lookahead == ' ' || lexer->lookahead == '\t' ||
            lexer->lookahead == '\r')) {
      skip_ch(lexer);
    }
    if (lexer->lookahead != '(') goto not_an_arm;
    advance_ch(lexer);
    lexer->mark_end(lexer);   /* the token is exactly the `(` */

    int depth = 0;
    bool found_arrow = false;
    while (!lexer->eof(lexer)) {
      int32_t c = lexer->lookahead;
      if (c == '"') {                       /* skip a string literal */
        advance_ch(lexer);
        while (!lexer->eof(lexer) && lexer->lookahead != '"') advance_ch(lexer);
        if (!lexer->eof(lexer)) advance_ch(lexer);
        continue;
      }
      if (c == ';') {                       /* skip a comment to end of line */
        while (!lexer->eof(lexer) && lexer->lookahead != '\n') advance_ch(lexer);
        continue;
      }
      if (c == '(' || c == '[' || c == '{') { depth++; advance_ch(lexer); continue; }
      if (c == ')' && depth == 0) break;    /* matching close — decision made */
      if (c == ')' || c == ']' || c == '}') { depth--; advance_ch(lexer); continue; }
      if (c == '-' && depth == 0) {
        advance_ch(lexer);
        if (lexer->lookahead == '>') { found_arrow = true; break; }
        continue;
      }
      advance_ch(lexer);
    }

    if (found_arrow) {
      lexer->result_symbol = ARM_LPAREN;
      return true;   /* extent is the mark: just the `(` */
    }
    return false;    /* not an arm — let `(` lex normally */
  }
  not_an_arm:;

  /* --- MAP_OPEN: the `{` of a MAP LITERAL, as a token distinct from the `{`
   *     of implicit params.
   *
   * `{` is contested: `{A : Type}` is implicit params, `{:k v}` and `{}` are
   * map literals.  Adding a plain `map_literal` rule alongside `implicit_params`
   * measured CATASTROPHIC — not a local failure but a recovery collapse, with
   * arithmetic.prologos going 28 B -> 2894 B and equality.prologos 26 B ->
   * 1779 B, and two files becoming swallows.  Same signature as the rejected
   * same-line-defn rules.
   *
   * So the two `{`s become two TOKENS, and no parser state has to choose: a
   * map literal's brace is one whose next non-space character is `:` (a
   * keyword key) or `}` (empty map).  Implicit params never start that way —
   * they open with an identifier. */
  if (valid_symbols[MAP_OPEN]) {
    /* The scanner runs BEFORE `extras' are skipped, so the lookahead here is
     * usually the space after `:=', not the brace.  Skip spaces/tabs first.
     *
     * NEWLINES are skipped only when no layout token is expected.  That
     * condition is the proxy for "we are inside a bracket group", where
     * brackets span lines freely and a newline carries no layout meaning;
     * outside one, a newline belongs to the INDENT/DEDENT logic below and
     * eating it here would break every block.
     *
     * Without this, a `{` that OPENS A CONTINUATION LINE was never seen as a
     * map: lookahead was `\n', the skip loop stopped, MAP_OPEN was not emitted,
     * and the brace lexed as implicit-params — so
     *
     *     @[{:name "Frodo"}
     *       {:name "Gimli"}]     <-- this one failed
     *
     * errored while the same maps on ONE line parsed. Reported 2026-08-14 as
     * spurious painting on foray.prologos:963-965 and :976-978; it is not
     * `@[`-specific — plain `[' and `'[' failed identically. */
    bool layout_expected = valid_symbols[INDENT] ||
                           valid_symbols[DEDENT] ||
                           valid_symbols[NEWLINE];
    while (!lexer->eof(lexer) &&
           (lexer->lookahead == ' ' || lexer->lookahead == '\t' ||
            lexer->lookahead == '\r' ||
            (!layout_expected && lexer->lookahead == '\n'))) {
      skip_ch(lexer);
    }
  }
  if (valid_symbols[MAP_OPEN] && lexer->lookahead == '{') {
    advance_ch(lexer);
    lexer->mark_end(lexer);          /* the token is exactly the `{` */
    while (!lexer->eof(lexer) &&
           (lexer->lookahead == ' ' || lexer->lookahead == '\t' ||
            lexer->lookahead == '\r' || lexer->lookahead == '\n')) {
      skip_ch(lexer);
    }
    if (lexer->lookahead == ':' || lexer->lookahead == '}') {
      lexer->result_symbol = MAP_OPEN;
      return true;
    }
    return false;                    /* not a map — let `{` lex normally */
  }

  /* If none of our tokens are valid, bail out immediately */
  if (!valid_symbols[INDENT] && !valid_symbols[DEDENT] && !valid_symbols[NEWLINE]) {
    return false;
  }

  /* --- Consume any newlines and leading whitespace to find the
   *     next non-blank, non-comment line's indentation level ---
   *
   * CRITICAL: We use advance() (not skip()) for newline characters.
   * This ensures the resulting token has non-zero size, preventing
   * tree-sitter from ignoring it as an empty external token.
   * Leading spaces on the destination line are consumed with skip()
   * so they don't appear in the token. */

  bool found_newline = false;
  int indent = 0;

  /* Set when we look PAST a comment-only line.  The indentation decision still
   * uses the next REAL line (a comment's own indentation must not decide block
   * structure — that is why this loop skips them at all), but the emitted token
   * must END BEFORE the comment so the normal lexer can tokenize it as the
   * `extras` comment the grammar declares.
   *
   * Without this the scanner consumed the comment characters as part of its
   * lookahead and the parser never saw them: `(comment) @comment' covered ~1%
   * of the library's comment lines (EHP P2, 2026-08-14).  Both editors hid it —
   * Emacs paints comments from its syntax table, VS Code from TextMate — so it
   * was invisible to every consumer-comparison we had. */
  bool marked_before_comment = false;

  /* Skip any spaces/tabs before the first newline (trailing whitespace) */
  while (!lexer->eof(lexer) && (lexer->lookahead == ' ' || lexer->lookahead == '\t' || lexer->lookahead == '\r')) {
    skip_ch(lexer);
  }

  /* Now consume newlines. The first \n we see must use advance() to give
   * the token non-zero width. Subsequent \n also use advance(). */
  while (!lexer->eof(lexer)) {
    if (lexer->lookahead == '\n') {
      found_newline = true;
      indent = 0;
      advance_ch(lexer);
      /* After advancing past \n, mark the end here. Further skipping of
       * spaces and blank lines will extend the token via more advance/mark_end. */
    } else if (lexer->lookahead == '\r') {
      advance_ch(lexer);
    } else if (lexer->lookahead == ' ') {
      if (found_newline) {
        indent++;
      }
      /* Spaces after the last newline are part of indentation — skip them
       * so they aren't included in the token range for the next real token. */
      skip_ch(lexer);
    } else if (lexer->lookahead == '\t') {
      skip_ch(lexer);
    } else if (lexer->lookahead == ';' && found_newline) {
      /* Comment-only line.  End the TOKEN here, before the comment, so the
       * parser resumes at it and lexes it as an `extras' comment; then keep
       * looking ahead (consuming) for the next real line's indentation, which
       * is what the layout decision below is actually based on.
       *
       * We have advanced past at least one '\n' to get here, so the token has
       * non-zero width and tree-sitter will not discard it as empty. */
      if (!marked_before_comment) {
        lexer->mark_end(lexer);
        marked_before_comment = true;
      }
      while (!lexer->eof(lexer) && lexer->lookahead != '\n') {
        skip_ch(lexer);
      }
      /* The loop will continue and advance past the next \n */
    } else {
      break;
    }
  }

  /* If we didn't cross a newline, this isn't a line boundary */
  if (!found_newline) {
    return false;
  }

  /* Mark token end AFTER consuming newlines with advance().
   * The token now covers the newline character(s), giving it non-zero size.
   *
   * Unless we already marked it before a comment — everything consumed since
   * then was pure lookahead to find the next real line's indentation, and must
   * stay OUTSIDE the token so the comment remains lexable. */
  if (!marked_before_comment) {
    lexer->mark_end(lexer);
  }

  /* At EOF after newlines — emit DEDENTs for remaining levels */
  if (lexer->eof(lexer)) {
    if (s->stack_size > 1 && valid_symbols[DEDENT]) {
      s->stack_size--;
      lexer->result_symbol = DEDENT;
      return true;
    }
    if (valid_symbols[NEWLINE]) {
      lexer->result_symbol = NEWLINE;
      return true;
    }
    return false;
  }

  /* --- LET_ALIGN: is this line a CONTINUATION BINDING of an open layout
   *     `let`, or something else?  The column decides, and only the column:
   *
   *       indent == first binding's column  ->  another binding (LET_ALIGN)
   *       indent  < that column             ->  the binding phase is OVER;
   *                                             pop, fall through, and the
   *                                             normal INDENT/DEDENT path
   *                                             makes this line the body
   *       indent  > that column             ->  the previous binding's VALUE
   *                                             continues (multi-line value);
   *                                             no pop, fall through
   *
   * This runs BEFORE the INDENT/NEWLINE/DEDENT branches because the aligned
   * line would otherwise be an INDENT (deeper than the enclosing block) and
   * the value-extension rules would absorb it --- which is precisely the
   * baseline failure: ONE binding whose value swallows the rest of the form.
   *
   * The pop lives HERE and not on DEDENT: a value deeper than the binding
   * column dedents back without ending the binding phase, so popping on
   * DEDENT would close the let under its own multi-line value (the pinned
   * `match`-value shape).  Popping when a SHALLOWER line arrives while the
   * parser still expects a binding is the one moment "this let takes no more
   * bindings" is actually known. */
  if (valid_symbols[LET_ALIGN] && !in_error_recovery && s->let_depth > 0) {
    int col = s->let_col_stack[s->let_depth - 1];
    if (indent == col) {
      lexer->result_symbol = LET_ALIGN;   /* token spans the crossed newline */
      return true;
    }
    if (indent < col) {
      s->let_depth--;
      /* fall through --- INDENT/DEDENT/NEWLINE below handles the line */
    }
  }

  int current_indent = s->indent_stack[s->stack_size - 1];

  /* --- INDENT: new indentation level is deeper --- */
  if (indent > current_indent) {
    if (valid_symbols[INDENT]) {
      if (s->stack_size < MAX_INDENT_STACK) {
        s->indent_stack[s->stack_size] = indent;
        s->stack_size++;
      }
      lexer->result_symbol = INDENT;
      return true;
    }
    return false;
  }

  /* --- NEWLINE: same indentation level --- */
  if (indent == current_indent) {
    if (valid_symbols[NEWLINE]) {
      lexer->result_symbol = NEWLINE;
      return true;
    }
    return false;
  }

  /* --- DEDENT: indentation decreased ---
   * Pop levels until we find a match (mirrors reader.rkt lines 184-202).
   * First DEDENT emitted immediately; remaining queued as pending. */
  if (indent < current_indent) {
    if (valid_symbols[DEDENT]) {
      int dedent_count = 0;
      while (s->stack_size > 1 &&
             s->indent_stack[s->stack_size - 1] > indent) {
        s->stack_size--;
        dedent_count++;
      }

      /* If we have more than one DEDENT, queue the extras */
      if (dedent_count > 1) {
        s->pending_dedents = dedent_count - 1;
        /* After all dedents, emit a NEWLINE (mirrors reader.rkt line 194) */
        s->pending_newline_after_dedents = true;
      } else if (dedent_count == 1) {
        /* Single dedent — the NEWLINE comes next naturally */
        s->pending_newline_after_dedents = true;
      }

      lexer->result_symbol = DEDENT;
      return true;
    }
    return false;
  }

  return false;
}

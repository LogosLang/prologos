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

/* Token types — must match the order in grammar.js externals array */
enum TokenType {
  INDENT,
  DEDENT,
  NEWLINE,
  SAME_LINE_BODY,
  ARM_LPAREN,
};

/* Scanner state */
#define MAX_INDENT_STACK 128

typedef struct {
  int indent_stack[MAX_INDENT_STACK];
  int stack_size;
  /* Number of pending DEDENT tokens to emit before the next NEWLINE.
   * When we dedent past multiple levels, we emit one DEDENT per level.
   * The NEWLINE that follows the dedents is also tracked separately. */
  int pending_dedents;
  bool pending_newline_after_dedents;
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

  return offset;
}

void tree_sitter_prologos_external_scanner_deserialize(
    void *payload, const char *buffer, unsigned length) {
  Scanner *s = (Scanner *)payload;
  s->pending_dedents = 0;
  s->pending_newline_after_dedents = false;
  s->indent_stack[0] = 0;
  s->stack_size = 1;

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

  /* --- Emit pending DEDENTs from a multi-level dedent --- */
  if (s->pending_dedents > 0 && valid_symbols[DEDENT]) {
    s->pending_dedents--;
    lexer->result_symbol = DEDENT;
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
      /* Comment-only line — skip to end of line, then continue
       * looking for the next non-blank line. */
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
   * The token now covers the newline character(s), giving it non-zero size. */
  lexer->mark_end(lexer);

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

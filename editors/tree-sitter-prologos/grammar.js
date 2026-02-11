/**
 * Tree-sitter grammar for Prologos (whitespace-significant syntax).
 *
 * Phase 1: Parses ns, provide, defn, match, and basic expressions.
 * Targets: nat.prologos (full coverage).
 *
 * The external scanner (src/scanner.c) emits INDENT, DEDENT, and NEWLINE
 * tokens based on indentation changes, following the same logic as reader.rkt.
 */

/// <reference types="tree-sitter-cli/dsl" />
// @ts-check

module.exports = grammar({
  name: 'prologos',

  externals: $ => [
    $._indent,
    $._dedent,
    $._newline,
  ],

  extras: $ => [
    /[ \t\r]/,
    $.comment,
  ],

  word: $ => $.identifier,

  rules: {
    // ============================================================
    // Top level
    // ============================================================

    source_file: $ => repeat(choice(
      $.top_level,
      $._newline,
    )),

    top_level: $ => choice(
      $.ns_declaration,
      $.provide_declaration,
      $.defn_form,
    ),

    // ============================================================
    // Declarations
    // ============================================================

    ns_declaration: $ => seq(
      'ns',
      field('name', $.qualified_name),
    ),

    provide_declaration: $ => seq(
      'provide',
      repeat1($.identifier),
    ),

    // ============================================================
    // Function definitions
    // ============================================================

    defn_form: $ => seq(
      'defn',
      field('name', $.identifier),
      field('params', $.param_list),
      ':',
      field('return_type', $.type_expr),
      $._indent,
      field('body', $.block_body),
      $._dedent,
    ),

    param_list: $ => seq(
      '[',
      commaSep1($.typed_param),
      ']',
    ),

    typed_param: $ => seq(
      field('name', $.identifier),
      ':',
      field('type', $.type_expr),
    ),

    // ============================================================
    // Block body (indentation-delimited)
    // ============================================================

    block_body: $ => repeat1(choice(
      $.match_expr,
      $._expression_line,
      $._newline,
    )),

    _expression_line: $ => $.expression,

    // ============================================================
    // Match expressions
    // ============================================================

    match_expr: $ => seq(
      'match',
      field('scrutinee', $.expression),
      $._indent,
      repeat1($.match_arm),
      $._dedent,
    ),

    match_arm: $ => seq(
      '|',
      field('pattern', $.pattern),
      '->',
      field('body', $.expression),
      optional($._newline),
    ),

    // ============================================================
    // Patterns
    // ============================================================

    pattern: $ => choice(
      $.wildcard_pattern,
      $.constructor_pattern,
      $.identifier_pattern,
    ),

    wildcard_pattern: $ => '_',

    constructor_pattern: $ => prec.left(2, seq(
      $.identifier,
      repeat1($.pattern_arg),
    )),

    identifier_pattern: $ => $.identifier,

    pattern_arg: $ => choice(
      $.identifier,
      '_',
    ),

    // ============================================================
    // Expressions
    // ============================================================

    expression: $ => choice(
      $.paren_expr,
      $.application,
      $.atom,
    ),

    paren_expr: $ => seq(
      '(',
      repeat1($.expression),
      ')',
    ),

    // Application by juxtaposition: f x y
    // Must be lower precedence than atoms to avoid ambiguity
    application: $ => prec.left(1, seq(
      $.expression,
      $.expression,
    )),

    atom: $ => choice(
      $.identifier,
      $.number,
      $.string,
    ),

    // ============================================================
    // Types
    // ============================================================

    type_expr: $ => choice(
      $.arrow_type,
      $.type_application,
      $.paren_type,
      $.identifier,
    ),

    arrow_type: $ => prec.right(1, seq(
      $.type_expr,
      '->',
      $.type_expr,
    )),

    type_application: $ => prec.left(2, seq(
      $.identifier,
      repeat1(choice($.identifier, $.paren_type)),
    )),

    paren_type: $ => seq('(', $.type_expr, ')'),

    // ============================================================
    // Atoms and terminals
    // ============================================================

    // Qualified name for ns declarations (includes dots)
    qualified_name: $ => /[a-zA-Z_][a-zA-Z0-9_.]+/,

    // Regular identifier
    identifier: $ => /[a-zA-Z_][a-zA-Z0-9_!?*+\-]*/,

    number: $ => /[0-9]+/,

    string: $ => seq('"', /[^"]*/, '"'),

    comment: $ => token(seq(';', /.*/)),

    // Comments are handled via extras — they're automatically consumed
    // between any tokens. No explicit comment_block rule needed.
  },
});

/**
 * Comma-separated list with at least one element.
 */
function commaSep1(rule) {
  return seq(rule, repeat(seq(',', rule)));
}

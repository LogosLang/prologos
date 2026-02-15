/**
 * Tree-sitter grammar for Prologos (whitespace-significant syntax).
 *
 * Phase 1+2: Parses all stdlib constructs including ns, provide, require,
 * defn, def, data, deftype, match, fn, multiplicity annotations, and
 * basic expressions.
 *
 * Bracket convention: [] is the primary grouping delimiter. () is reserved
 * for future tuple syntax and produces errors in the WS reader.
 * deftype still uses sexp-style () since its patterns are s-expressions.
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
    /[ \t\r\n]/,
    $.comment,
  ],

  word: $ => $.identifier,

  conflicts: $ => [
    // fn_param vs fn_body: an identifier before a bracket expr could be
    // either the last param or the body.
    [$.fn_param, $.fn_body],
  ],

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
      $.require_declaration,
      $.defn_form,
      $.def_form,
      $.data_form,
      $.deftype_form,
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

    require_declaration: $ => seq(
      'require',
      '[',
      field('module', $.qualified_name),
      optional(seq(
        ':refer',
        '[',
        repeat1($.identifier),
        ']',
      )),
      ']',
    ),

    // ============================================================
    // Function definitions
    // ============================================================

    defn_form: $ => seq(
      'defn',
      field('name', $.identifier),
      optional(field('implicit_params', $.implicit_params)),
      field('params', $.param_list),
      ':',
      field('return_type', $.type_expr),
      $._indent,
      field('body', $.block_body),
      $._dedent,
    ),

    // Value definitions (no params)
    def_form: $ => seq(
      'def',
      field('name', $.identifier),
      optional(seq(':', field('type', $.type_expr))),
      $._indent,
      field('body', $.block_body),
      $._dedent,
    ),

    // ============================================================
    // Data declarations
    // ============================================================

    data_form: $ => seq(
      'data',
      field('name', $.identifier),
      optional(field('type_params', $.implicit_params)),
      $._indent,
      repeat1($.data_constructor),
      $._dedent,
    ),

    data_constructor: $ => seq(
      field('name', $.identifier),
      optional(seq(':', field('type', $.type_expr))),
      optional($._newline),
    ),

    // ============================================================
    // Deftype declarations (type aliases)
    // ============================================================

    deftype_form: $ => seq(
      'deftype',
      field('signature', $.sexp),
      field('body', $.sexp),
    ),

    // S-expression: used in deftype which uses sexp-style syntax
    // Handles forms like (Eq $A), (-> $A (-> $A Bool))
    // deftype still uses () since it's sexp-mode syntax
    sexp: $ => choice(
      $.sexp_list,
      $.identifier,
    ),

    sexp_list: $ => seq('(', repeat1(choice($.sexp, '->')), ')'),

    // ============================================================
    // Shared syntax
    // ============================================================

    // Implicit type parameters: {A B C}
    implicit_params: $ => seq('{', repeat1($.identifier), '}'),

    param_list: $ => seq(
      '[',
      commaSep1($.typed_param),
      ']',
    ),

    typed_param: $ => seq(
      field('name', $.identifier),
      optional(field('multiplicity', $.multiplicity)),
      ':',
      field('type', $.type_expr),
    ),

    // QTT multiplicity annotations: :0, :1, :w
    multiplicity: $ => choice(':0', ':1', ':w'),

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
      field('body', $.match_arm_body),
      optional($._newline),
    ),

    // Match arm body can be a plain expression or a nested match
    match_arm_body: $ => choice(
      $.match_expr,
      $.expression,
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
      $.fn_expr,
      $.grouped_expr,
      $.application,
      $.atom,
    ),

    // Grouped expression: [expr1 expr2 ...] — primary grouping delimiter
    // Replaces the old paren_expr which used (), and subsumes the old bracket_expr.
    // Used for function application: [add x k], [inc zero]
    // and for Sigma binders: [x <A>]
    grouped_expr: $ => seq('[', repeat1($.expression), ']'),

    // List literal: '[expr1 expr2 ...] — linked list literal
    // '[1 2 3] → (cons 1 (cons 2 (cons 3 nil)))
    // '[1 2 | xs] → (cons 1 (cons 2 xs))
    list_literal: $ => seq(
      "'[",
      repeat(choice(
        $.expression,
        seq('|', $.expression),
        ',',
      )),
      ']',
    ),

    // Anonymous lambda: fn x y _ expr
    // Appears inside brackets: [fn x y _ [Eq A y x]]
    fn_expr: $ => prec.right(seq(
      'fn',
      repeat1($.fn_param),
      $.fn_body,
    )),

    fn_param: $ => choice(
      $.identifier,
      '_',
    ),

    fn_body: $ => choice(
      $.grouped_expr,
      $.identifier,
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
      $.arrow_op,
      $.list_literal,
    ),

    // Arrow operator as an expression: used in dependent types where
    // [-> A B] appears in expression/term position
    arrow_op: $ => '->',

    // ============================================================
    // Types
    // ============================================================

    type_expr: $ => choice(
      $.arrow_type,
      $.type_application,
      $.grouped_type,
      $.identifier,
    ),

    arrow_type: $ => prec.right(1, seq(
      $.type_expr,
      '->',
      $.type_expr,
    )),

    // Type application by juxtaposition: List A, Result A E, Eq A
    type_application: $ => prec.left(2, seq(
      $.identifier,
      repeat1(choice($.identifier, $.grouped_type)),
    )),

    // Grouped type expression: [Eq A a b], [Sigma [_ <A>] B], [-> A B]
    // Replaces old paren_type and bracket_type which used () and [] respectively.
    // Now [] is the universal grouping delimiter for both types and expressions.
    grouped_type: $ => seq('[', repeat1($.type_expr), ']'),

    // Angle-bracket type annotation: <A>
    angle_type: $ => seq('<', $.identifier, '>'),

    // ============================================================
    // Atoms and terminals
    // ============================================================

    // Qualified name for ns declarations and require paths (includes dots)
    qualified_name: $ => /[a-zA-Z_][a-zA-Z0-9_.\-]+/,

    // Regular identifier (includes $-prefixed type vars for deftype, :: qualified names)
    identifier: $ => /\$?[a-zA-Z_][a-zA-Z0-9_!?*+\-']*(::[\$a-zA-Z_][a-zA-Z0-9_!?*+\-']*)*/,

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

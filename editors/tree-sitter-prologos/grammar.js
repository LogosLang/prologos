/**
 * Tree-sitter grammar for Prologos (whitespace-significant syntax).
 *
 * Phase 1+2: Parses all stdlib constructs including ns, provide, require,
 * defn, def, data, deftype, match, fn, multiplicity annotations, and
 * basic expressions.
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
    // fn_param vs fn_body: an identifier before a paren expr could be
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
      $.paren_expr,
      $.bracket_expr,
      $.application,
      $.atom,
    ),

    // Bracket expression: [_ <A>] — used for Sigma binders in expression context
    bracket_expr: $ => seq('[', repeat1($.bracket_elem), ']'),

    bracket_elem: $ => choice(
      $.angle_type,
      $.identifier,
      '_',
    ),

    // Anonymous lambda: fn x y _ expr
    // Appears inside parentheses: (fn x y _ (Eq A y x))
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
      $.paren_expr,
      $.identifier,
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
      $.arrow_op,
    ),

    // Arrow operator as an expression: used in dependent types where
    // (-> A B) appears in expression/term position
    arrow_op: $ => '->',

    // ============================================================
    // Types
    // ============================================================

    type_expr: $ => choice(
      $.arrow_type,
      $.type_application,
      $.paren_type,
      $.bracket_type,
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
      repeat1(choice($.identifier, $.paren_type)),
    )),

    // Parenthesized type expressions — handles multi-arg type application:
    //   (Eq A a b), (Sigma [_ <A>] B), (-> A B)
    paren_type: $ => seq('(', repeat1($.type_expr), ')'),

    // Bracket type expressions — used in Sigma binders: [_ <A>]
    bracket_type: $ => seq('[', repeat1($.type_expr_inner), ']'),

    // Inner type expression elements that can appear inside bracket types
    type_expr_inner: $ => choice(
      $.arrow_type_inner,
      $.paren_type,
      $.angle_type,
      $.identifier,
      '_',
    ),

    arrow_type_inner: $ => prec.right(1, seq(
      $.type_expr_inner,
      '->',
      $.type_expr_inner,
    )),

    // Angle-bracket type annotation: <A>
    angle_type: $ => seq('<', $.identifier, '>'),

    // ============================================================
    // Atoms and terminals
    // ============================================================

    // Qualified name for ns declarations and require paths (includes dots)
    qualified_name: $ => /[a-zA-Z_][a-zA-Z0-9_.\-]+/,

    // Regular identifier (includes $-prefixed type vars for deftype)
    identifier: $ => /\$?[a-zA-Z_][a-zA-Z0-9_!?*+\-]*/,

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

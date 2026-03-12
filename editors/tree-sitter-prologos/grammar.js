/**
 * Tree-sitter grammar for Prologos (whitespace-significant syntax).
 *
 * Refreshed 2026-03-11: Covers all current top-level forms including
 * spec, trait, impl, bundle, property, functor, foreign, defmacro,
 * check/eval/infer, imports/exports, subtype, capability, let, and
 * multi-arity defn. Expression coverage includes let, if, cond, do,
 * the, pipe, quote/quasiquote, typed holes, logic variables, and
 * all numeric literal forms (Nat, Rat, approx, char, keyword).
 *
 * Bracket convention: [] is the primary grouping delimiter. () is reserved
 * for parser keywords: (match ...), (fn ...), (the ...), (let ...), etc.
 * Angle brackets <> for Pi/Sigma type syntax.
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
    [$.fn_param, $.fn_body],
    [$.type_application, $.expression],
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
      $.imports_declaration,
      $.exports_declaration,
      $.spec_form,
      $.defn_form,
      $.def_form,
      $.data_form,
      $.deftype_form,
      $.trait_form,
      $.impl_form,
      $.bundle_form,
      $.property_form,
      $.functor_form,
      $.defmacro_form,
      $.foreign_form,
      $.subtype_declaration,
      $.capability_declaration,
      $.relation_form,
      $.clause_form,
      $.check_form,
      $.eval_form,
      $.infer_form,
      $.let_top_level,
      $.expression,
    ),

    // ============================================================
    // Module declarations
    // ============================================================

    ns_declaration: $ => seq(
      'ns',
      field('name', $.qualified_name),
      optional(':no-prelude'),
    ),

    provide_declaration: $ => seq(
      'provide',
      repeat1($.identifier),
    ),

    require_declaration: $ => seq(
      'require',
      '[',
      field('module', $.qualified_name),
      optional($.require_clause),
      ']',
    ),

    require_clause: $ => choice(
      seq(':refer', '[', repeat1($.identifier), ']'),
      seq(':refer', ':all'),
      seq(':as', $.identifier),
      seq(':refer', '[', ']'),  // side-effect import
    ),

    imports_declaration: $ => seq(
      'imports',
      '[',
      field('module', $.qualified_name),
      optional($.require_clause),
      ']',
    ),

    exports_declaration: $ => seq(
      'exports',
      '[',
      repeat1($.identifier),
      ']',
    ),

    // ============================================================
    // Type specifications
    // ============================================================

    spec_form: $ => seq(
      'spec',
      field('name', $.identifier),
      optional(field('implicit_params', $.implicit_params)),
      field('type', $.type_expr),
      optional($.spec_metadata),
    ),

    spec_metadata: $ => seq(
      $._indent,
      repeat1($.metadata_entry),
      $._dedent,
    ),

    metadata_entry: $ => seq(
      $.keyword_literal,
      $.expression,
      optional($._newline),
    ),

    // ============================================================
    // Function definitions
    // ============================================================

    // Multi-arity defn with | arms, or single-arity
    defn_form: $ => seq(
      'defn',
      field('name', $.identifier),
      optional(field('implicit_params', $.implicit_params)),
      choice(
        // Single-arity: defn name [params] body
        seq(
          field('params', $.param_list),
          optional(seq(':', field('return_type', $.type_expr))),
          $._indent,
          field('body', $.block_body),
          $._dedent,
        ),
        // Multi-arity: defn name | [p1] body1 | [p2] body2
        seq(
          $._indent,
          repeat1($.defn_arm),
          $._dedent,
        ),
      ),
    ),

    defn_arm: $ => seq(
      '|',
      field('params', $.param_list),
      optional(seq(':', field('return_type', $.type_expr))),
      field('body', $.expression),
      optional($._newline),
    ),

    // Value definitions
    def_form: $ => seq(
      'def',
      field('name', $.identifier),
      optional(seq(':', field('type', $.type_expr))),
      optional(seq(':=', field('value', $.expression))),
      optional(seq(
        $._indent,
        field('body', $.block_body),
        $._dedent,
      )),
    ),

    // ============================================================
    // Data declarations
    // ============================================================

    data_form: $ => seq(
      'data',
      field('name', $.identifier),
      optional(field('type_params', $.data_params)),
      optional(seq(':', field('type', $.type_expr))),
      optional('where'),
      $._indent,
      repeat1($.data_constructor),
      $._dedent,
    ),

    data_params: $ => choice(
      $.implicit_params,
      seq('[', repeat1($.typed_param_or_bare), ']'),
    ),

    data_constructor: $ => seq(
      optional('|'),
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

    sexp: $ => choice(
      $.sexp_list,
      $.identifier,
    ),

    sexp_list: $ => seq('(', repeat1(choice($.sexp, '->')), ')'),

    // ============================================================
    // Trait system
    // ============================================================

    trait_form: $ => seq(
      'trait',
      field('name', $.identifier),
      optional(field('params', $.implicit_params)),
      optional($.where_clause),
      $._indent,
      repeat1(choice($.spec_form, $.defn_form, $.def_form, $._newline)),
      $._dedent,
    ),

    impl_form: $ => seq(
      'impl',
      field('trait_name', $.identifier),
      field('type', repeat1(choice($.identifier, $.grouped_type))),
      optional($.where_clause),
      $._indent,
      repeat1(choice($.defn_form, $.def_form, $._newline)),
      $._dedent,
    ),

    bundle_form: $ => seq(
      'bundle',
      field('name', $.identifier),
      ':=',
      '(',
      repeat1($.identifier),
      ')',
    ),

    where_clause: $ => seq(
      'where',
      repeat1($.constraint),
    ),

    constraint: $ => choice(
      seq('(', $.identifier, repeat1(choice($.identifier, $.grouped_type)), ')'),
      seq('[', $.identifier, repeat1(choice($.identifier, $.grouped_type)), ']'),
    ),

    // ============================================================
    // Properties, functors, macros, foreign
    // ============================================================

    property_form: $ => seq(
      'property',
      field('name', $.identifier),
      optional(field('params', $.implicit_params)),
      optional($.where_clause),
      $._indent,
      repeat1(choice($.metadata_entry, $.expression, $._newline)),
      $._dedent,
    ),

    functor_form: $ => seq(
      'functor',
      field('name', $.identifier),
      optional(field('params', $.implicit_params)),
      $._indent,
      repeat1(choice($.metadata_entry, $.expression, $._newline)),
      $._dedent,
    ),

    defmacro_form: $ => seq(
      'defmacro',
      field('name', $.identifier),
      field('pattern', $.expression),
      field('template', $.expression),
    ),

    foreign_form: $ => seq(
      'foreign',
      $._indent,
      field('body', $.block_body),
      $._dedent,
    ),

    // ============================================================
    // Subtype, capability, logic
    // ============================================================

    subtype_declaration: $ => seq(
      'subtype',
      field('sub', $.identifier),
      field('super', $.identifier),
      optional(seq('via', field('coerce', $.identifier))),
    ),

    capability_declaration: $ => seq(
      'capability',
      field('name', $.identifier),
      optional(seq(
        $._indent,
        repeat1(choice($.expression, $._newline)),
        $._dedent,
      )),
    ),

    relation_form: $ => seq(
      'relation',
      field('name', $.identifier),
      optional(field('params', $.param_list)),
      $._indent,
      field('body', $.block_body),
      $._dedent,
    ),

    clause_form: $ => seq(
      'clause',
      field('head', $.expression),
      optional(seq(
        $._indent,
        field('body', $.block_body),
        $._dedent,
      )),
    ),

    // ============================================================
    // Check / eval / infer (top-level commands)
    // ============================================================

    check_form: $ => seq('check', $.expression, optional(seq(':', $.type_expr))),
    eval_form: $ => seq('eval', $.expression),
    infer_form: $ => seq('infer', $.expression),

    let_top_level: $ => seq(
      'let',
      field('name', $.identifier),
      optional(seq(':', field('type', $.type_expr))),
      ':=',
      field('value', $.expression),
    ),

    // ============================================================
    // Shared syntax
    // ============================================================

    implicit_params: $ => seq(
      '{',
      repeat1(choice(
        $.typed_binder,
        $.identifier,
      )),
      '}',
    ),

    typed_binder: $ => seq(
      $.identifier,
      ':',
      $.type_expr,
    ),

    param_list: $ => seq(
      '[',
      repeat($.typed_param_or_bare),
      ']',
    ),

    typed_param_or_bare: $ => choice(
      $.typed_param,
      $.bare_param,
    ),

    typed_param: $ => prec(2, seq(
      field('name', $.identifier),
      optional(field('multiplicity', $.multiplicity)),
      ':',
      field('type', $.type_expr),
    )),

    bare_param: $ => $.identifier,

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
      optional(seq('when', field('guard', $.expression))),
      '->',
      field('body', $.match_arm_body),
      optional($._newline),
    ),

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
      $.literal_pattern,
      $.head_tail_pattern,
      $.identifier_pattern,
    ),

    wildcard_pattern: $ => '_',

    constructor_pattern: $ => prec.left(2, seq(
      $.identifier,
      repeat1($.pattern_arg),
    )),

    identifier_pattern: $ => $.identifier,

    literal_pattern: $ => choice(
      $.number,
      $.nat_literal,
      $.string,
      'true',
      'false',
    ),

    head_tail_pattern: $ => seq(
      '[',
      repeat1($.pattern),
      '|',
      $.pattern,
      ']',
    ),

    pattern_arg: $ => choice(
      $.identifier,
      '_',
      $.number,
      $.nat_literal,
      seq('[', repeat1($.pattern), ']'),
    ),

    // ============================================================
    // Expressions
    // ============================================================

    expression: $ => choice(
      $.fn_expr,
      $.let_expr,
      $.if_expr,
      $.cond_expr,
      $.do_expr,
      $.the_expr,
      $.pipe_expr,
      $.grouped_expr,
      $.paren_expr,
      $.angle_expr,
      $.application,
      $.atom,
    ),

    // Grouped expression: [expr1 expr2 ...] — primary grouping
    grouped_expr: $ => seq('[', repeat1($.expression), ']'),

    // Parenthesized expression: (keyword expr ...)
    paren_expr: $ => seq('(', repeat1($.expression), ')'),

    // Angle bracket expression: <(x : A) -> B>
    angle_expr: $ => seq('<', repeat1(choice($.expression, '->', '*', $.typed_binder_paren)), '>'),

    typed_binder_paren: $ => seq('(', $.identifier, ':', $.type_expr, ')'),

    // List literal: '[expr1 expr2 ...]
    list_literal: $ => seq(
      "'[",
      repeat(choice(
        $.expression,
        seq('|', $.expression),
      )),
      ']',
    ),

    // Anonymous lambda: fn [params] body
    fn_expr: $ => prec.right(seq(
      'fn',
      repeat1($.fn_param),
      $.fn_body,
    )),

    fn_param: $ => choice(
      $.identifier,
      '_',
      $.param_list,  // [x : Type] binder group
    ),

    fn_body: $ => choice(
      $.grouped_expr,
      $.paren_expr,
      $.identifier,
    ),

    // Let expression: (let name := expr body) or let name := expr (WS)
    let_expr: $ => prec.right(seq(
      'let',
      field('name', $.identifier),
      optional(seq(':', field('type', $.type_expr))),
      ':=',
      field('value', $.expression),
      optional(field('body', $.expression)),
    )),

    // If expression: (if cond then else) or if cond then else (WS 3-arg)
    if_expr: $ => prec.right(seq(
      'if',
      field('condition', $.expression),
      field('then', $.expression),
      optional(field('else', $.expression)),
    )),

    // Cond expression: (cond [pred1 body1] [pred2 body2] ...)
    cond_expr: $ => seq(
      'cond',
      repeat1($.cond_clause),
    ),

    cond_clause: $ => seq('[', $.expression, $.expression, ']'),

    // Do expression: (do expr1 expr2 ...)
    do_expr: $ => seq(
      'do',
      repeat1($.expression),
    ),

    // The (type annotation): (the Type expr)
    the_expr: $ => seq(
      'the',
      field('type', $.type_expr),
      field('expr', $.expression),
    ),

    // Pipe expression: expr |> f |> g
    pipe_expr: $ => prec.left(1, seq(
      $.expression,
      '|>',
      $.expression,
    )),

    // Application by juxtaposition
    application: $ => prec.left(2, seq(
      $.expression,
      $.expression,
    )),

    atom: $ => choice(
      $.identifier,
      $.nat_literal,
      $.rat_literal,
      $.approx_literal,
      $.number,
      $.string,
      $.char_literal,
      $.keyword_literal,
      $.logic_variable,
      $.typed_hole,
      $.arrow_op,
      $.compose_op,
      $.list_literal,
      $.quote_expr,
      $.quasiquote_expr,
      $.unquote_expr,
      'true',
      'false',
    ),

    // ============================================================
    // Quote / quasiquote
    // ============================================================

    quote_expr: $ => seq("'", $.expression),
    quasiquote_expr: $ => seq('`', $.expression),
    unquote_expr: $ => seq(',', $.expression),

    // ============================================================
    // Literals
    // ============================================================

    nat_literal: $ => /[0-9]+N/,
    rat_literal: $ => /[0-9]+\/[0-9]+/,
    approx_literal: $ => /~[0-9]+(?:\.[0-9]+)?(?:\/[0-9]+)?/,
    char_literal: $ => /\\(?:newline|space|tab|return|backspace|nul|alarm|escape|delete|[a-zA-Z0-9]|u[0-9a-fA-F]{1,6})/,
    keyword_literal: $ => /:[a-zA-Z_][a-zA-Z0-9_?!\-']*/,
    logic_variable: $ => /\?[a-zA-Z_][a-zA-Z0-9_?!\-']*/,
    typed_hole: $ => choice('??', /\?\?[a-zA-Z_][a-zA-Z0-9_?!\-']*/),

    // Operators as tokens
    arrow_op: $ => '->',
    compose_op: $ => '>>',

    // ============================================================
    // Types
    // ============================================================

    type_expr: $ => choice(
      $.arrow_type,
      $.union_type,
      $.product_type,
      $.type_application,
      $.grouped_type,
      $.identifier,
    ),

    arrow_type: $ => prec.right(1, seq(
      $.type_expr,
      '->',
      $.type_expr,
    )),

    union_type: $ => prec.left(0, seq(
      $.type_expr,
      '|',
      $.type_expr,
    )),

    product_type: $ => prec.left(0, seq(
      $.type_expr,
      '*',
      $.type_expr,
    )),

    type_application: $ => prec.left(2, seq(
      $.identifier,
      repeat1(choice($.identifier, $.grouped_type)),
    )),

    grouped_type: $ => seq('[', repeat1($.type_expr), ']'),

    // ============================================================
    // Atoms and terminals
    // ============================================================

    qualified_name: $ => /[a-zA-Z_][a-zA-Z0-9_.\-]+/,

    identifier: $ => /\$?[a-zA-Z_][a-zA-Z0-9_!?*+\-']*(::[\$a-zA-Z_][a-zA-Z0-9_!?*+\-']*)*/,

    number: $ => /[0-9]+(?:\.[0-9]+)?/,

    string: $ => seq('"', /[^"]*/, '"'),

    comment: $ => token(seq(';', /.*/)),
  },
});

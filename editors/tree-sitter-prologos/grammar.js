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
      $.defr_form,
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

    provide_declaration: $ => prec.right(seq(
      'provide',
      repeat1($.identifier),
    )),

    // `require' takes ONE OR MORE bracket groups, and each group may carry
    // SEVERAL clauses — `[m :as x :refer [a b]]' is the ordinary spelling.
    //
    // The pre-2026-08-14 rule allowed exactly one group and one clause, so a
    // real multi-module require failed from its first line.  In foray.prologos
    // that produced a SINGLE ERROR node of 19,280 bytes — 67% of the file, and
    // the whole of the `ns' 16.9% cluster, which had nothing to do with `ns'.
    require_declaration: $ => prec.right(seq(
      'require',
      repeat1($.require_group),
    )),

    require_group: $ => seq(
      '[',
      field('module', $.qualified_name),
      repeat($.require_clause),
      ']',
    ),

    require_clause: $ => choice(
      seq(':refer', '[', repeat1($.identifier), ']'),
      seq(':refer', ':all'),
      seq(':as', $.identifier),
      seq(':refer', '[', ']'),  // side-effect import
    ),

    imports_declaration: $ => prec.right(seq(
      'imports',
      repeat1($.require_group),
    )),

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

    metadata_entry: $ => prec.right(10, seq(
      $.keyword_literal,
      $.expression,
      optional($._newline),
    )),

    // ============================================================
    // Function definitions
    // ============================================================

    // Single-arity defn, or multi-clause defn with | arms.
    //
    // The param list is OPTIONAL and independent of which body form
    // follows, because both of these are legal:
    //
    //   defn is-zero            defn nth [n xs]
    //     | zero  -> true         | n nil -> [none Int]
    //     | suc _ -> false        | n [cons h t] -> ...
    //
    // The pre-2026-08-14 rule tied "has params" to "single-arity" and so
    // could not parse the second, which is the common shape in the corpus.
    defn_form: $ => seq(
      'defn',
      field('name', $.identifier),
      optional(field('implicit_params', $.implicit_params)),
      optional(field('params', $.param_list)),
      optional(choice(
        seq(':', field('return_type', $.type_expr)),
        field('return_type', $.angle_type),
      )),
      $._indent,
      choice(
        repeat1($.defn_arm),
        field('body', $.block_body),
      ),
      $._dedent,
    ),

    // `| pattern... -> body`, mirroring `match_arm`.
    //
    // Two corrections over the pre-2026-08-14 rule, which was written as
    // `| param_list body` and therefore matched nothing the language emits:
    //   1. the arrow is REQUIRED and was absent entirely;
    //   2. clause heads are PATTERNS, not a bracketed param list — one per
    //      parameter, so `| n nil -> …` carries two.
    defn_arm: $ => prec.right(5, seq(
      '|',
      repeat1(field('pattern', $.pattern)),
      optional(seq('when', field('guard', $.expression))),
      '->',
      field('body', $.defn_arm_body),
      optional($._newline),
    )),

    // A clause body is inline after `->`, or indented on the lines below —
    // the latter is how a nested `match` is written in a clause.
    defn_arm_body: $ => choice(
      $.match_expr,
      $.expression,
      seq($._indent, $.block_body, $._dedent),
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
      repeat1(choice(
        $.trait_method,
        $.trait_metadata,
        $.spec_form, $.defn_form, $.def_form,
        $._newline,
      )),
      $._dedent,
    ),

    // A trait method signature is BARE — `eq? : A A -> Bool`, with no `spec`
    // keyword.  The pre-2026-08-14 body accepted only spec/defn/def forms, so
    // the one thing every trait actually contains could not parse.
    trait_method: $ => prec(3, seq(
      field('name', $.identifier),
      ':',
      field('type', $.type_expr),
    )),

    // `:doc "..."`, and `:laws` followed by an indented list of `- :name ...`
    // law entries.  This is also the home of the `:forall` error cluster.
    trait_metadata: $ => prec.right(seq(
      $.keyword_literal,
      optional(choice($.expression, $.implicit_params)),
      optional(seq($._indent, repeat1(choice($.law_entry, $._newline)), $._dedent)),
    )),

    law_entry: $ => prec.right(seq(
      '-',
      repeat1(seq(
        $.keyword_literal,
        optional(choice($.expression, $.implicit_params)),
      )),
    )),

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

    // `defr` — relational definitions (Rel Track 1, 2026-07-25).
    //
    // Absent from the grammar ENTIRELY: `defr` appeared zero times, while the
    // corpus carries 207 such lines.  Body is either a `||` FACT block (rows of
    // terms, one row per line, optionally `|`-separated on a line) or a `&>`
    // RULE clause (a conjunction of goals).
    defr_form: $ => seq(
      'defr',
      field('name', $.identifier),
      optional(field('params', $.relation_params)),
      $._indent,
      repeat1(choice($.defr_facts, $.defr_rule, $._newline)),
      $._dedent,
    ),

    relation_params: $ => seq(
      '[',
      repeat1(choice($.logic_variable, $.identifier)),
      ']',
    ),

    // Rows continue across lines until the block dedents; `|` separates rows
    // written on one line.
    defr_facts: $ => prec.right(seq(
      '||',
      repeat1(choice($.expression, '|')),
    )),

    defr_rule: $ => prec.right(seq(
      '&>',
      repeat1($.expression),
    )),

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

    let_top_level: $ => prec(5, seq(
      'let',
      field('name', $.identifier),
      optional(seq(':', field('type', $.type_expr))),
      ':=',
      field('value', $.expression),
    )),

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

    bare_param: $ => prec(3, $.identifier),

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

    match_arm: $ => prec.right(5, seq(
      '|',
      field('pattern', $.pattern),
      optional(seq('when', field('guard', $.expression))),
      '->',
      field('body', $.match_arm_body),
      optional($._newline),
    )),

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
    angle_expr: $ => seq('<', repeat1(choice($.expression, token.immediate('->'), token.immediate('*'), $.typed_binder_paren)), '>'),

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
    // `let` after the LET track (2026-07-31).
    //
    // Three things the pre-2026-08-14 rule got wrong, all of them making the
    // COMMON spellings unparseable while the rare one worked:
    //   1. `:=' was REQUIRED.  It is optional everywhere — `let x 4' is the
    //      ordinary form and `let x := 4' the emphatic one.
    //   2. exactly ONE binding was allowed.  Aligned blocks and sibling
    //      chains bind several in one scope.
    //   3. the bracket form `let [x 5 y 6] body' did not exist at all.
    //
    // Binder shape is `typed_param_or_bare', which already handles both the
    // spaced `x : Int' and the fused `x:Int' the params rule accepts — the
    // lexer does not care about the spaces, so one rule covers both.
    let_expr: $ => prec.right(seq(
      'let',
      choice(
        seq('[', repeat1($.let_binding), ']'),
        repeat1($.let_binding),
      ),
      optional(field('body', $.expression)),
    )),

    let_binding: $ => prec.right(seq(
      field('name', $.typed_param_or_bare),
      optional(':='),
      field('value', $.expression),
      optional($._newline),
    )),

    // If expression: (if cond then else) or if cond then else (WS 3-arg)
    if_expr: $ => prec.right(seq(
      'if',
      field('condition', $.expression),
      field('then', $.expression),
      optional(field('else', $.expression)),
    )),

    // Cond expression: (cond [pred1 body1] [pred2 body2] ...)
    cond_expr: $ => prec.right(seq(
      'cond',
      repeat1($.cond_clause),
    )),

    cond_clause: $ => seq('[', $.expression, $.expression, ']'),

    // Do expression: (do expr1 expr2 ...)
    do_expr: $ => prec.right(seq(
      'do',
      repeat1($.expression),
    )),

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
      $.operator,
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

    // Bare arithmetic/pipeline operators.
    //
    // `identifier' requires a leading [a-zA-Z_], so `+' `-' `*' `/' could not
    // be identifiers, and there was no token for them anywhere — which made
    // `[+ a b]' unparseable.  Since Numerics N6e-E2 these are FIRST-CLASS
    // VALUES (`reduce + 0 xs'), so they are atoms, not just heads.
    //
    // Counts in the corpus at the time of adding: + 257, * 100, - 39, / 23.
    // `->' is deliberately absent — it is already `arrow_op' above.
    //
    // Longest-match keeps these from stealing other syntax: `->' beats `-',
    // `>>' beats `>', `|>' beats `|', and `int*' / `p8+' still lex as
    // identifiers because those DO start with a letter.
    operator: $ => choice('+', '-', '*', '/', '|>'),

    // ============================================================
    // Types
    // ============================================================

    type_expr: $ => choice(
      $.arrow_type,
      $.type_application,
      $.grouped_type,
      $.angle_type,
      $.identifier,
    ),

    arrow_type: $ => prec.right(1, seq(
      $.type_expr,
      '->',
      $.type_expr,
    )),

    type_application: $ => prec.left(2, seq(
      $.identifier,
      repeat1(choice($.identifier, $.grouped_type)),
    )),

    grouped_type: $ => seq('[', repeat1($.type_expr), ']'),

    // <Type> — the angle-delimited type annotation.
    //
    // Absent from the grammar entirely before 2026-08-14, while the corpus
    // writes it on 394 `defn` lines: `defn eq? [x y] <Bool>`.  Only the colon
    // form `: Bool` was accepted, so essentially every method inside every
    // `impl` failed to parse — which is why `impl` and `defn` between them held
    // 59% of the remaining error mass.
    angle_type: $ => seq('<', repeat1($.type_expr), '>'),

    // ============================================================
    // Atoms and terminals
    // ============================================================

    // Supports both dot-separated (prologos.data.nat) and :: separated (prologos::data::nat)
    qualified_name: $ => /[a-zA-Z_][a-zA-Z0-9_.\-]+(::[\$a-zA-Z_][a-zA-Z0-9_.\-]*)*/,

    identifier: $ => /\$?[a-zA-Z_][a-zA-Z0-9_!?*+\-']*(::[\$a-zA-Z_][a-zA-Z0-9_!?*+\-']*)*/,

    number: $ => /[0-9]+(?:\.[0-9]+)?/,

    string: $ => seq('"', /[^"]*/, '"'),

    comment: $ => token(seq(';', /.*/)),
  },
});

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
    $._same_line_body,
    $._map_open,
    $._arm_lparen,
    // APPEND ONLY — the correspondence with scanner.c's enum is POSITIONAL.
    $._let_open,
    $._let_align,
    $._kv_key,
    $._infix_cmp,
  ],

  extras: $ => [
    /[ \t\r\n]/,
    $.comment,
  ],

  word: $ => $.identifier,

  conflicts: $ => [
    [$.fn_param, $.fn_body],
    // A `,` after `[` is a param separator, but `unquote_expr` also opens on
    // `,`.  They cannot be told apart by the LR state — a param list is never
    // inside a quasiquote, and only the surrounding context knows that.  GLR
    // carries both and the valid parse wins.  tree-sitter names this pair
    // itself when the conflict is left undeclared.
    [$.param_list, $.unquote_expr],
    // An identifier can open a path (`x.y`) or stand alone as an atom, and the
    // parser must choose BEFORE seeing whether a step follows. Surfaced inside
    // angle types, where `<A *` is the Sigma `*` and `<A*` would be a flatten
    // step — the tokens differ only by adjacency, which the LEXER knows and the
    // LR state does not. Declaring it lets tree-sitter carry both and settle it
    // on the actual token.
    [$._path_base, $.atom],
    [$._path_base, $.expression],
    // A `name : Type` binder is shared by PARAM LISTS and `let` bindings, and
    // the two want DIFFERENT types: a param's is atomic (`[p1:Point p2:Point]`
    // is two params — see `_param_type`), while a let's may be multi-token
    // (`let f : Int -> Bool := v`, which the syntax rules require `:=` for).
    // At `let x : Int • ->` the parser cannot yet know which it is in, so it
    // carries both and settles on the tokens that actually follow.
    [$._param_type, $.type_expr],

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
      choice(
        // Body (or clauses) on indented lines below.
        seq(
          optional(field('params', $.param_list)),
          optional($._defn_return_type),
          $._indent,
          choice(
            repeat1($.defn_arm),
            field('body', $.block_body),
          ),
          $._dedent,
        ),
        // Body on the SAME line: `defn add-ten [x] [int+ x 10]` (255 corpus
        // lines).  `_same_line_body` is a ZERO-WIDTH scanner token; the lexer
        // picks the branch on one character of lookahead, so this is a plain
        // shift rather than an ambiguity.
        //
        // The param list is REQUIRED here, and that is load-bearing rather
        // than a description of the syntax: it is what keeps
        // `_same_line_body` out of `valid_symbols` until the params have been
        // consumed.  Make it optional and the scanner fires right after
        // `defn NAME`, takes `[x]` as the body, and strands the real one.
        seq(
          field('params', $.param_list),
          optional($._defn_return_type),
          $._same_line_body,
          field('body', $.expression),
        ),
      ),
    ),

    _defn_return_type: $ => choice(
      seq(':', field('return_type', $.type_expr)),
      field('return_type', $.angle_group),
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

    // ⚠ The type position accepts a PARENTHESISED argument group —
    // `impl Lattice (Map K V)`.  Only 8 corpus lines use it, but one of them
    // detonated an 8,024-byte swallow (31% of lattices.prologos): the ERROR
    // surfaced 260 lines LATER, at line 524, so neither the leading-token
    // clustering nor reading the error site could find it.  Delete-window
    // bisection on the full file did.
    //
    // Deliberately NOT added to `type_expr` generally: a broad `paren_type`
    // was tried earlier, failed to fix its target, and measured worse.
    impl_form: $ => seq(
      'impl',
      field('trait_name', $.identifier),
      field('type', repeat1(choice($.identifier, $.grouped_type, $.type_arg_group))),
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
      // Commas are OPTIONAL separators: the corpus writes both
      // `(Add Sub Mul)` and `(Seqable, Buildable, ...)`, and the compiler
      // accepts both at 0 errors (measured 2026-08-15).  Without this the
      // comma spelling was a permanent error-recovery zone — `,` lexed as
      // UNQUOTE, the close paren went MISSING, and the region churned under
      // every unrelated lexer change, which is how it kept showing up in
      // per-file A/Bs as damage from changes that never touched it.
      $.identifier,
      repeat(seq(optional(','), $.identifier)),
      ')',
    ),

    type_arg_group: $ => seq(
      '(',
      repeat1(choice($.identifier, $.grouped_type)),
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

    // Map literals — `{:name "alice"}` and `{}`.  644 corpus lines.
    //
    // Opens with `_map_open`, a SCANNER token, not a bare `{`: see scanner.c.
    // A plain rule competing with `implicit_params` for `{` collapsed error
    // recovery across the corpus, so the disambiguation is lexical and the
    // parser never has to choose.
    // A map VALUE is a single term, never a bare application.
    //
    // It used to be `$.expression`, which includes `application` — and
    // juxtaposition IS application, so the value ran greedily to the closing
    // brace: `{:a 1 :b 2}` parsed as ONE pair with value `1 :b 2`.
    //
    // ⚠ That emitted NO `ERROR` and no `MISSING` node. The parse succeeded and
    // was merely wrong, so swallow-count and unparsed-% — the metrics this
    // whole track was gated on — could not see it (TSG T1 §9.4). It was found
    // by inspecting field structure, not by the gate.
    //
    // Excluding `application` loses nothing real: every corpus value is a
    // literal, identifier, keyword, quoted list or bracketed group, and an
    // application is always written bracketed (`{:f [dbl 2]}`).
    _map_value: $ => choice(
      $.atom,
      $.grouped_expr,
      $.paren_expr,
      $.angle_group,
    ),

    map_literal: $ => seq(
      $._map_open,
      repeat(seq(
        field('key', $.keyword_literal),
        field('value', $._map_value),
        // `,` between entries is legal — verified against the COMPILER, which
        // typechecks `{:to "b", :w 3, :from "a"}` at 0 errors. It is not in
        // `extras` because in Prologos `,` is unquote, not whitespace; it is
        // accepted here specifically, where no unquote can begin.
        optional(','),
      )),
      '}',
    ),

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
      // The COMMA is a separator and the compiler accepts it: `[x : A,
      // xs : [List A]]` compiles at 0 errors, as do `[+ 1, 2]` and `'[1, 2, 3]`.
      // parse-reader.rkt:4484 is explicit — at qq-depth 0 a comma IS a
      // separator, and only inside a quasiquote does it mean unquote.
      //
      // It cannot go in `extras` (global — it would eat the comma
      // `unquote_expr` needs), and `seq(param, optional(','))` adds a choice
      // point after every param that destabilises the table far away.  As a
      // repeat ALTERNATIVE it competes with `unquote_expr` head-on, which is
      // declared below rather than hidden.
      repeat(choice($.typed_param_or_bare, ',')),
      ']',
    ),

    typed_param_or_bare: $ => choice(
      $.typed_param,
      $.angle_param,
      $.bare_param,
    ),

    // `[iv <Interval>]` — a parameter typed with an ANGLE GROUP and NO colon.
    //
    // `typed_param` requires the colon (`[iv : Interval]`), so this spelling —
    // 136 corpus lines — could not parse.  It fails as `MISSING "]"`, because
    // the parser closes the param list early and then hunts for a bracket that
    // is already spent; recovery then swallows forward.  In lattices.prologos
    // that one line cost an 8,024-byte ERROR spanning 216 lines (31% of the
    // file), attributed by the tooling to a `defn` 30 lines above it.
    angle_param: $ => prec(2, seq(
      field('name', $.identifier),
      optional(field('multiplicity', $.multiplicity)),
      field('type', $.angle_group),
    )),

    typed_param: $ => prec(2, seq(
      field('name', $.identifier),
      optional(field('multiplicity', $.multiplicity)),
      // The colon of a FUSED annotation (`x:Int`) must out-lex
      // `keyword_literal`, which matches the longer `:Int` at the same
      // position.  Where both are valid — a let binding's name position, where
      // a keyword could also begin the VALUE — longest-match takes the keyword
      // and produces a binding whose value is `:Int` with the real value
      // swallowed: E0/M0, a parse that SUCCEEDS with the wrong tree, invisible
      // to the corpus gate (§9.4 class; `broadcast_step` below is the same fix
      // for the same thief).  Lexical precedence beats match length, and
      // `token.immediate` keeps the win adjacency-only, so the SPACED
      // `let k := :foo` (compiler-valid) still lexes as a keyword.  The plain
      // `':'` alternative keeps the spaced type form (`x : Int := 4`) working.
      choice(alias(token.immediate(prec(1, ':')), ':'), ':'),
      field('type', $._param_type),
    )),

    // The type of a `name:Type` parameter is ATOMIC — NOT a full `type_expr`.
    //
    // `type_expr` admits `type_application` (`prec.left(2, seq(identifier,
    // repeat1(...)))`, unbounded) and `arrow_type`, both of which are GREEDY and
    // absorb the NEXT PARAMETER: `[p1:Point p2:Point]` parsed as
    // `p1 : (Point p2)` with `:Point` stranded as an ERROR, on code the compiler
    // accepts at 0 errors (DEFERRED 134).
    //
    // The COMPILER is the authority here and treats a fused type as atomic —
    // measured: `[xs:List Int]` elaborates to TWO parameters,
    // `xs : List` and a bare `Int`, not to one parameter typed `List Int`.
    //
    // The alternatives kept are exactly those that CANNOT absorb what follows:
    // a single identifier, and the two self-delimiting bracket forms. Dropping
    // `arrow_type` costs nothing real — a fused `Int->Bool` lexes as ONE
    // identifier anyway, since `->` is an ident-continue sequence (ARROW T1).
    _param_type: $ => choice(
      $.grouped_type,
      $.angle_group,
      $.identifier,
    ),

    bare_param: $ => prec(3, $.identifier),

    multiplicity: $ => choice(':0', ':1', ':w'),

    // ============================================================
    // Block body (indentation-delimited)
    // ============================================================

    block_body: $ => repeat1(choice(
      $.layout_map,
      $.match_expr,
      $._expression_line,
      $._newline,
    )),

    // ============================================================
    // Layout map — DEFERRED 142
    // ============================================================
    //
    // The indentation kv form (`def business` + `:name "JMZI"` lines).  Until
    // 2026-08-15 this had NO grammar structure: it parsed as ONE nested
    // application glom of keyword atoms, at E0 — so no query could tell a KEY
    // from a VALUE, and every consumer saw a silently wrong tree.
    //
    // The compiler (flatten-ws-kv-pairs) is the authority, and the census
    // pinned the shape:
    //   · one entry per LINE (`:x 1 :y 2` on one line: REJECTED)
    //   · an entry REQUIRES a payload — same-line value or INDENT block; a
    //     bare `:foo` body is a keyword VALUE (`x : Keyword`), and a
    //     payload-less key with siblings is an ERROR.  Payload-ness is what
    //     separates entry from bare-keyword expression, and it is visible in
    //     ONE token of lookahead (NEWLINE/DEDENT vs anything else).
    //   · `-` items: `- :n "a"` + siblings at the KEY's column; the dash's
    //     2-column offset means the machinery sees a plain INDENT block —
    //     UNLIKE the aligned let, no column stack is needed, every nesting
    //     level here is a real indent-stack level.  Scalar items (`- 1`) are
    //     one value on the dash line.
    //   · NOT legal as a `let` block value (compiler: "let block binding
    //     must be `name value`") — so the rule lives in block_body only.
    // No `_newline' alternative of its own: each kv_entry consumes its
    // trailing newline, so a blank line between entries is block_body's — the
    // overlap was an unresolvable block_body/layout_map conflict otherwise.
    layout_map: $ => prec.right(repeat1($.kv_entry)),

    kv_entry: $ => prec.right(seq(
      // The scanner decides key-vs-value by PAYLOAD lookahead and the entry
      // starts with a token `atom` cannot consume — the kv_entry/atom
      // conflict dissolves, and an expression value cannot glom the next
      // entry's keyword.
      $._kv_key,
      field('key', alias($.keyword_literal, $.map_key)),
      field('value', choice(
        $.expression,
        $._kv_block,
      )),
      optional($._newline),
    )),

    // A nested payload: either a deeper map, or a run of `-` items.
    _kv_block: $ => seq(
      $._indent,
      choice($.layout_map, repeat1(choice($.kv_item, $._newline))),
      $._dedent,
    ),

    // `- :n "a"` + sibling entries arrive as an INDENT block relative to the
    // dash line; `- 1` is a scalar item.
    kv_item: $ => prec.right(seq(
      '-',
      choice(
        seq($.kv_entry, optional(seq($._indent, $.layout_map, $._dedent))),
        $.expression,
      ),
      optional($._newline),
    )),

    _expression_line: $ => $.expression,

    // ============================================================
    // Match expressions
    // ============================================================

    // `match` takes arms either on INDENTED lines (`| pat -> body`) or inline
    // in PARENS on the same line (`match h (mk-handle idx -> …)`) — the sexp
    // arm spelling, used inside WS files.
    //
    // The inline form is why fio.prologos was a 51% swallow.
    match_expr: $ => prec.right(seq(
      'match',
      field('scrutinee', $.expression),
      choice(
        seq($._indent, repeat1($.match_arm), $._dedent),
        repeat1($.match_paren_arm),
      ),
    )),

    // Outranks `paren_expr`, which also matches `( … )` and would happily read
    // `(zero -> true)` as three expressions — `->` is an atom.  The precedence
    // is what settles that, and what stops the SCRUTINEE from swallowing the
    // arm as an application argument.
    // prec(10) settles arm-arrow vs `arrow_op`-as-atom after the `->`.  Safe to
    // state as a precedence now that `_arm_lparen` has removed the real
    // ambiguity; on the plain `'('` spelling this same prec did NOT help,
    // because the undecidable part was the interior, not the arrow.
    match_paren_arm: $ => prec(10, seq(
      $._arm_lparen,
      field('pattern', $.pattern),
      optional(seq('when', field('guard', $.expression))),
      '->',
      field('body', $.expression),
      ')',
    )),

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
      $.grouped_pattern,
      $.identifier_pattern,
    ),

    // `[ pattern… ]` — a bracketed pattern.
    //
    // This shape was already accepted as an ARGUMENT (inline in `pattern_arg`)
    // but not as a pattern in its own right, so a clause head like
    // `| [zero] -> zero` could not parse.  Defined ONCE here and shared with
    // `pattern_arg`, rather than spelled out in both: two rules over one shape
    // is what made `<…>` ambiguous for four rounds (§7.0.2).
    grouped_pattern: $ => seq('[', repeat1($.pattern), ']'),

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
      $.grouped_pattern,
    ),

    // ============================================================
    // Expressions
    // ============================================================

    expression: $ => choice(
      $.path_expr,
      $.fn_expr,
      $.let_expr,
      $.if_expr,
      $.cond_expr,
      $.do_expr,
      $.the_expr,
      $.pipe_expr,
      $.grouped_expr,
      $.paren_expr,
      $.angle_group,
      $.application,
      $.atom,
    ),

    // Grouped expression: [expr1 expr2 ...] — primary grouping
    grouped_expr: $ => seq('[', repeat1($.expression), ']'),

    // Parenthesized expression: (keyword expr ...)
    paren_expr: $ => seq('(', repeat1($.expression), ')'),

    // Angle bracket expression: <(x : A) -> B>
    // ONE rule for every `<…>` group, in expression AND type position.
    //
    // There used to be two DIFFERENT rules matching the same delimiters — one
    // for expressions, one for types — which made every `<` after a defn's
    // params genuinely ambiguous.  That is the conflict that blocked same-line
    // bodies through four rounds (§7.0) and reappeared each time the other
    // conflict was addressed (§7.0.1).
    //
    // Unifying dissolves it at the source: there is nothing to decide between,
    // because there is only one rule.  POSITION decides the LABEL (a group
    // after params is a return type) rather than the parse.
    angle_group: $ => seq('<', repeat1(choice($.expression, token.immediate('->'), token.immediate('*'), $.typed_binder_paren)), '>'),

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

    // Persistent-vector literal: `@[1 2 3]`, typing as `[PVec Int]`.
    //
    // The grammar knew `@` NOT AT ALL — zero occurrences — while the corpus has
    // 252 `@[` across 13 files, so every one produced an ERROR node that then
    // swallowed the maps written inside it. That is the reported "spurious
    // painting" on foray.prologos:963-965 and :976-978: the maps parse fine,
    // but they sit inside the ERROR the unknown `@` opens.
    //
    // `@[` is ONE token, following `'[` for list_literal directly above — a
    // separate `@` would also admit `@ [1 2]`, which is not the syntax.
    pvec_literal: $ => seq(
      '@[',
      repeat($.expression),
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
      // `.( … )` is a legal fn body — `(fn [x : Int] .(x * x))` is corpus
      // spelling; without this the parser INVENTED an identifier for the
      // body and dumped the group outside as an application argument.
      $.infix_group,
    ),

    // `.( … )` — the INFIX ESCAPE group, named so fn_body can share it with
    // atom.  See the comment at its atom usage for the full story.
    infix_group: $ => seq(
      alias(token(seq('.', '(')), '.('),
      repeat(choice($.expression,
                    alias($._infix_cmp, $.operator),
                    alias(choice('==', '!='), $.operator))),
      ')',
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
        seq('[', repeat1(alias($._bracket_let_binding, $.let_binding)), ']'),
        // `_let_open' is zero-width and carries no shape of its own; it exists
        // so the SCANNER records the first binding's column.  Requiring it here
        // (rather than making it optional) is what keeps it from firing in the
        // bracket branch — the `_same_line_body' precedent, where an optional
        // predecessor let the token fire one position early.
        // One binding, then aligned continuations, each introduced by the
        // scanner's column test.  The structure the tokens enforce IS the
        // documented layout rule: bindings share the first binding's column,
        // the body sits shallower.
        seq($._let_open, $.let_binding,
            repeat(seq($._let_align, $.let_binding))),
      ),
      optional(field('body', $.expression)),
    )),

    // The LAYOUT binding.  Its value is a full expression: it may be an
    // application, and it may continue onto deeper-indented lines.
    let_binding: $ => prec.right(seq(
      field('name', $.typed_param_or_bare),
      optional(':='),
      field('value', $.expression),
      optional($._newline),
    )),

    // The BRACKET binding — flat name/value pairs on ONE line, so the value is
    // exactly one datum.
    //
    // A full `$.expression' here is GREEDY and that is DEFERRED 140: in
    // `let [y 4 z 5]' it takes `4 z 5' as a single application, the form
    // collapses to ONE binding, and it does so with ZERO error nodes — the
    // second name simply never becomes a binding site.  With `:=' spelled out
    // (`let [y := 4 z := 5]', which the compiler accepts at 0 errors) the same
    // greed produced an ERROR node instead.
    //
    // `application' is deliberately absent from the choice below: juxtaposition
    // is precisely what must not cross a binding boundary here.  A value that
    // needs juxtaposition is written bracketed — `let [y [+ 1 2] z 5]' — which
    // `grouped_expr' covers.
    //
    // ⚠ `angle_group' is NOT a value here, and leaving it in cost a real
    // regression the per-file A/B caught: in `(let [x <Nat> (inc zero)]' the
    // parser then read `x' as a bare name and `<Nat>' as its VALUE, stranding
    // `(inc zero)' with no name — MISSING 0 -> 1 in sample.prologos while the
    // ERROR count did not move at all.  An angle group after a binder name is
    // that binder's TYPE (`angle_param'), never its value.
    //
    // Aliased to `let_binding' so the node type queries match stays ONE name:
    // highlights.scm:202-203 select `(let_binding name: …)' and must keep
    // painting both shapes.
    _bracket_let_binding: $ => seq(
      field('name', $.typed_param_or_bare),
      optional(':='),
      field('value', choice(
        $.path_expr,
        $.grouped_expr,
        $.paren_expr,
        $.atom,
      )),
    ),

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
    // ============================================================
    // Path selection  (spec: docs/tracking/tracks/CIU/CIU_6/2026-07-28_path-selection-spec.md §2)
    // ============================================================
    //
    // A postfix chain of steps on a focus: `record.orders:items*:sku`,
    // `party:name{1 0}`, `app-config.database.pool-size`.
    //
    // ⭐ EVERY step opener is `token.immediate`, and that is the whole design.
    // Spec §2.2: three characters are JUXTAPOSITION-SENSITIVE — whitespace
    // decides the reading.
    //
    //     x:k   broadcast step        x :k   application to a keyword literal
    //     x{…}  select block          x {…}  a map/block literal
    //     a^b   rename                a^ b   keyless leaf, then sibling `b`
    //
    // `token.immediate` matches only when NO extra was skipped, which is
    // exactly "adjacent". It needs no scanner token — unlike `_map_open`,
    // which must look FORWARD past spaces to classify a brace; here the
    // decision is about what came immediately BEFORE, and the lexer already
    // knows that.
    //
    // Binds tighter than `application` (prec 3 vs 2): `[f x.y]` applies `f` to
    // `x.y`, not `f.y` to anything.
    path_expr: $ => prec.left(3, seq(
      field('base', $._path_base),
      repeat1($.path_step),
    )),

    // Only a self-delimiting focus can carry a path — an identifier, a
    // literal, or a bracketed group. Not a bare application: `f x.y` paths off
    // `x`, not off `f x`.
    _path_base: $ => choice(
      $.identifier,
      $.grouped_expr,
      $.paren_expr,
      $.map_literal,
      $.pvec_literal,
      $.list_literal,
    ),

    path_step: $ => choice(
      $.row_splat,
      $.nominal_step,
      $.ordinal_step,
      $.broadcast_step,
      $.flatten_step,
      $.select_block,
      $.key_op,
      $.block_descend,
    ),

    // `.*` — row-splat. MUST precede `.k`, or `.` + `*` wins and splits it.
    row_splat: $ => token.immediate('.*'),

    nominal_step: $ => seq(token.immediate('.'), field('key', $.identifier)),
    ordinal_step: $ => seq(token.immediate('.'), field('index', $.number)),

    // `:s` broadcast — grade ω, maps one step over the level, shape preserved.
    // Without the immediacy this is `application(r, :items)`: a parse that
    // SUCCEEDS with the wrong tree and emits no ERROR, so the corpus gate
    // cannot see it (the §9.4 class).
    // Matches the WHOLE `:name` shape, not `:` + identifier.
    //
    // ⚠ The split version PARSED AT ZERO ERRORS AND NEVER FIRED:
    // `keyword_literal` is one token `/:[a-zA-Z_]…/`, so the lexer took it and
    // `admins:name` stayed `application(admins, :name)` — a rule that compiles,
    // matches nothing, and reports success. Third instance this session of
    // "parses" not meaning "works"; only dumping the tree shows it.
    //
    // Same shape as `keyword_literal`, but `token.immediate`, so adjacency
    // alone separates `x:k` (broadcast) from `x :k` (keyword literal) — which
    // is exactly what spec §2.2 asks for.
    broadcast_step: $ => field('step',
      alias(token.immediate(/:[a-zA-Z_][a-zA-Z0-9_?!\-']*/), $.identifier)),

    // `*` flatten, postfix and adjacent — `…:diags*:msg`. Adjacency is what
    // separates it from the spaced binary `*` (Sigma / multiplication).
    //
    // ⭐ THE WHOLE STAR FAMILY IS ONE TOKEN (DEFERRED 144; CIU 6 1b-vi close):
    // `*` flatten, `*_` with provenance, `*-` total collapse, `*-_` total
    // collapse with provenance. The bare `'*'` it replaced parsed `cfg{db}*_`
    // as an APPLICATION of the path to the identifier `_`, and `cfg{db}*-` as
    // an application to the operator `-` — wrong trees with NO ERROR and NO
    // MISSING, so the corpus gate could not see it (only test/corpus does).
    // A SUPERSET of the family on purpose (Q_U53's containment rule): a token
    // that is exactly the mint table re-blinds itself when the table grows, and
    // a grammar that accepts more than the compiler is the harmless direction.
    // The FUSED band (`x{a*_ b}`) needs nothing: `*`, `-`, `_` continue an
    // identifier here exactly as in the compiler's `ident-continue?`.
    //
    // ⚠ `prec(1, …)` IS LOAD-BEARING. `operator` contains the STRING `'*'`, and
    // tree-sitter breaks a same-length tie in favour of a string token over a
    // regex token — so without the precedence a bare `*` after a step lexed as
    // `operator`, and `record.orders:items*:sku` became an application (caught by
    // test/corpus 54). The old string token `'*'` won that tie by being a string;
    // the regex needs the precedence spelled out (same remedy as `:` at line 657).
    flatten_step: $ => token.immediate(prec(1, /\*[-_]*/)),

    // `{a b}` nominal / `{N M}` ordinal n-ary selection.
    //
    // ⚠ Block contents are BRANCHES, and a branch is itself a path — not the
    // bare identifier/number the first cut assumed. The corpus writes
    // `app-config{server.host^ database.url^}` and even nests blocks through
    // `^.{…}`. The narrow version mis-fired on exactly those, inserting a
    // MISSING `}` (+26 across the corpus) — caught by differentially comparing
    // the MISSING breakdown against the pre-change grammar, since the ERROR
    // count went DOWN over the same change and hid it.
    select_block: $ => seq(
      token.immediate('{'),
      repeat($._select_branch),
      '}',
    ),

    _select_branch: $ => choice(
      $.path_expr,
      $.identifier,
      $.number,
    ),

    // `^` key operator: `k^` dissolve · `k^k'` rename · `p^_` synth,
    // plus the `-` COLLAPSE family (Q_T7) and the parent collapse `^..` (Q_T8).
    // The continuation is `token.immediate` too, which is what distinguishes
    // `a^b` (rename) from `a^ b` (dissolve, then a sibling branch).
    //
    // The full continuation grammar, per D4 Q_T7, is `-`? · {ε | label | `_`},
    // plus `..`.  Until 2026-08-15 this rule implemented the MIDDLE of that and
    // neither edge: the rename alternative must start with `[a-zA-Z_]`, so
    // every `-` form was unparseable and `^..` had no alternative at all —
    // `^-`, `^-_`, `^-label` and `^..` each produced an ERROR node while the
    // COMPILER accepted them at 0 errors (DEFERRED 136).
    //
    // ⚠ The rename regex EXCLUDES a bare `_`. It used to start `[a-zA-Z_]`, so
    // it matched `_` and won — which made `field('synth', …)` DEAD in the
    // ORIGINAL rule too: `^_` parsed as a rename to a field literally called
    // `_`. Surfaced 2026-08-15 only because DEFERRED 135 started painting the
    // rename identifier, and the census then disagreed with TextMate over it.
    // `_abc` is still a rename (longest match), `_` alone is the synth marker.
    //
    // Spelled out rather than nested-optional so no branch can match empty:
    // `optional(seq(optional('-'), optional(...)))` is ambiguous with the outer
    // `optional`, and the `-` branch here always consumes its `-`.
    key_op: $ => seq(
      token.immediate('^'),
      optional(choice(
        // Q_T8 — parent-key collapse.  `..`, NOT `.`: `a.b^.c` would read
        // identically to the legitimate mid-path dissolve `a`·`b^`·`.c`, a
        // silent one-space meaning flip between two well-typed forms.
        field('parent', token.immediate('..')),
        // Q_T7 — `^-` collapses the branch flat; the continuation is the same
        // {ε | label | `_`} as without the dash.  ⚠ Eyes-open per Q_T7: after
        // `^` a leading `-` IS the collapse marker, so a rename target that
        // literally begins with `-` is unsupported by construction.
        seq(
          field('collapse', token.immediate('-')),
          optional(choice(
            field('rename', alias(token.immediate(/[a-zA-Z][a-zA-Z0-9_?!-]*|_[a-zA-Z0-9_?!-]+/), $.identifier)),
            field('synth', token.immediate('_')),
          )),
        ),
        field('rename', alias(token.immediate(/[a-zA-Z][a-zA-Z0-9_?!-]*|_[a-zA-Z0-9_?!-]+/), $.identifier)),
        field('synth', token.immediate('_')),
      )),
    ),

    // `.{…}` — descend into a nested selection block, as in
    // `database^.{url pool-size}`. Distinct from `nominal_step`, which takes an
    // identifier after the dot.
    block_descend: $ => seq(token.immediate('.'), $.select_block),

    // `<` disclose is spec'd but NOT IMPLEMENTED in the language (owner,
    // 2026-08-14), so the grammar deliberately does not accept it.

    application: $ => prec.left(2, seq(
      $.expression,
      $.expression,
    )),

    atom: $ => choice(
      // `.( … )` — the INFIX ESCAPE group (`.(3/4 + 10/8)`, `.(x - y)`,
      // `.([square x] + [square y])`).  Compiler-valid at 0 errors; the
      // grammar had NO rule for it, so every site was an ERROR region — and
      // the VS Code provider deliberately yields error regions to TextMate,
      // which is how `let` binders near one lost their semantic paint while
      // identical binders in clean regions kept it (owner report,
      // 2026-08-15: "toplevel vs defn" — really healthy-tree vs error-zone).
      // The token is the GLUED `.(` — corpus writes it glued, always — so it
      // cannot collide with `nominal_step`'s path-context immediate dot.
      // The interior rides the ordinary expression grammar: operators are
      // atoms, so infix spellings glom into one application, which is
      // lenient and exactly enough for an editor.
      // The interior mixes expressions with COMPARISON operators, and the
      // bare `<' / `>' would otherwise lex as ANGLE-GROUP delimiters — the
      // corpus's `.(3 < 5)` had the parser inventing a closing `>' (MISSING
      // rose while ERROR fell, the exact signal the A/B refuses to net).
      $.infix_group,
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
      $.pvec_literal,
      $.map_literal,
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
    // `=` is the UNIFY operator (reserved for it — never binding, which is
    // `:=`).  It had no token at all, so the 65 corpus lines writing narrowing
    // goals — `[add ?x ?y] = 7N`, `(= ?x 5)` — could not parse.
    //
    // Added as an operator atom rather than as a bespoke top-level goal rule:
    // that keeps `(= a b)` and `x = y` working through the ordinary
    // application path, and adds no new competition for any existing shape.
    // Longest-match keeps `:=` intact.
    operator: $ => choice('+', '-', '*', '/', '|>', '='),

    // ============================================================
    // Types
    // ============================================================

    type_expr: $ => choice(
      $.arrow_type,
      $.type_application,
      $.grouped_type,
      $.angle_group,
      $.identifier,
    ),

    // `->` and the QTT multiplicity arrows `-0>` / `-1>` (erased / linear).
    // Only `->` existed; `-1>` lexed as `-`, `1`, `>` and broke the spec.
    arrow_type: $ => prec.right(1, seq(
      $.type_expr,
      choice('->', $.linear_arrow),
      $.type_expr,
    )),

    linear_arrow: $ => token(/-[0-9]+>/),

    type_application: $ => prec.left(2, seq(
      $.identifier,
      repeat1(choice($.identifier, $.grouped_type)),
    )),

    grouped_type: $ => seq('[', repeat1($.type_expr), ']'),


    // ============================================================
    // Atoms and terminals
    // ============================================================

    // Supports both dot-separated (prologos.data.nat) and :: separated (prologos::data::nat)
    // NOTE the `*` on the first segment, not `+`.
    //
    // It was `+`, which requires a first char PLUS ONE MORE — so the FIRST
    // segment had to be at least two characters and `a::b` was unparseable
    // while `ab::c` parsed.  Nothing to do with how many segments there are,
    // which is what the deferred note recorded and what the original probe
    // (`a::b` vs `prologos::data::nat`) made it look like: those differ in
    // segment count AND in first-segment length, and only the latter mattered.
    // `identifier` right below already uses `*` correctly.
    qualified_name: $ => /[a-zA-Z_][a-zA-Z0-9_.\-]*(::[\$a-zA-Z_][a-zA-Z0-9_.\-]*)*/,

    identifier: $ => /\$?[a-zA-Z_][a-zA-Z0-9_!?*+\-']*(::[\$a-zA-Z_][a-zA-Z0-9_!?*+\-']*)*/,

    number: $ => /[0-9]+(?:\.[0-9]+)?/,

    // ONE TOKEN, not a seq.
    //
    // As `seq('"', /[^"]*/, '"')` the three pieces are separate tokens, so
    // `extras` — which includes `comment: token(seq(';', /.*/))` — could be
    // interleaved BETWEEN them.  A semicolon inside a string was therefore
    // lexed as a COMMENT, eating the closing quote and the rest of the line:
    // `[join "; " xs]` failed, `[join ", " xs]` parsed.  Wrapping in `token`
    // makes the string atomic so nothing can intrude.
    string: $ => token(seq('"', /[^"]*/, '"')),

    comment: $ => token(seq(';', /.*/)),
  },
});

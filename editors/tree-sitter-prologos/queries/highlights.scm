; Tree-sitter highlights for Prologos
;
; THE source of truth for Prologos syntax highlighting. Consumed by BOTH the
; VS Code semantic-token provider (src/semanticTokens.ts) and Emacs
; (prologos-ts-mode.el, since 2026-08-14) — neither carries its own copy.
;
; Capture names follow the Neovim standard vocabulary
; (`:help treesitter-highlight-groups`), verified against Neovim master
; 2026-08-14. Custom leaves are allowed where no standard one fits, but their
; ROOT must be standard so an unknown leaf still falls back to a sensible
; colour in a consumer that has never heard of it.
;
; ORDER IS SEMANTIC. The provider takes FIRST MATCH WINS, keyed by start
; offset, so specific captures must precede general ones and the bare
; `(identifier) @variable' fallback must stay LAST. Moving a rule below that
; fallback silently disables it.
;
; LEAF-ONLY. Capture leaves (identifiers, literals, operator tokens), never
; containers. Two reasons, both hard: VS Code's SemanticTokensBuilder requires
; NON-OVERLAPPING tokens, so capturing `(angle_group)` as well as the identifier
; inside it emits two overlapping ranges; and a container capture paints its
; whole extent one colour, which is exactly the runaway-`type_application` bug
; (§9.3) reproduced on purpose.
;
; Deliberately NOT captured: the ubiquitous `[` `]` `(` `)` `{` `}` brackets.
; They carry delimiter meaning in Prologos, but TextMate already colours them
; and capturing every one is the highest-noise/lowest-information addition
; available. Structure that TextMate CANNOT see is what belongs here.
;
; Refreshed 2026-08-14 (TSG T1 §9.1): 43 of 111 named node types -> see below.

; ============================================================
; Keywords (grammar tokens — reserved words in grammar.js)
; ============================================================

["defn" "def" "data" "deftype" "match" "fn" "spec" "trait" "impl"
 "bundle" "property" "functor" "defmacro" "foreign" "subtype"
 "capability" "relation" "clause" "check" "eval" "infer"
 "ns" "provide" "require" "imports" "exports"
 "let" "if" "cond" "do" "the" "where" "when" "via"
 ; Rel T1 (2026-07-25) — absent from the grammar until TSG T1 P5.
 "defr"] @keyword

; Keywords that appear as identifiers (not grammar tokens).
;
; Everything here is a real keyword the grammar does NOT tokenize, so it
; arrives as a plain `identifier' and can only be recognised by name.  Words
; the grammar DOES tokenize (def, defn, trait, impl, foreign, defr, ...) belong
; in the anonymous-token list above and must NOT be repeated here: in
; expression position they are ordinary identifiers, and `[trait x]' is a call
; to a variable named `trait', not a keyword.
;
; The relational + schema names were added 2026-08-14 when Emacs moved onto this
; file: its retired inline rules matched them and this list did not, so adopting
; the shared query would have silently dropped them. VS Code never had them.
((identifier) @keyword
  (#match? @keyword "^(forall|exists|solve|solver|solve-one|solve-with|explain|explain-with|rel|schema|query|expand|expand-1|expand-full|parse|elaborate|with-transient|transient|reduce)$"))

":no-prelude" @keyword
":refer" @keyword
":as" @keyword
":all" @keyword

; ============================================================
; Definition names
; ============================================================

(defn_form name: (identifier) @function)
(def_form name: (identifier) @function)
(spec_form name: (identifier) @function)
(data_form name: (identifier) @type.definition)
(data_constructor name: (identifier) @constructor)
(trait_form name: (identifier) @type.definition)
(impl_form trait_name: (identifier) @type)
(bundle_form name: (identifier) @type.definition)
(property_form name: (identifier) @type.definition)
(functor_form name: (identifier) @type.definition)
(defmacro_form name: (identifier) @function)
(relation_form name: (identifier) @function)
(ns_declaration name: (qualified_name) @module)
(subtype_declaration sub: (identifier) @type)
(subtype_declaration super: (identifier) @type)
(capability_declaration name: (identifier) @type.definition)

; A trait's method names are declarations, not calls — the distinction is
; exactly what a regex grammar cannot make.
(trait_method name: (identifier) @function)

; ============================================================
; Relational forms (Rel T1)
; ============================================================

(defr_form name: (identifier) @function)

; `&>` introduces a rule body, `||` a fact block, `=` is the unify goal.
; Goal-position `=` is NOT equality — worth its own colour, not an identifier's.
["&>" "||" "="] @operator

; ============================================================
; Module system
; ============================================================

; `module:` is a field of require_group, not of the declaration —
; require/imports take one or more groups since TSG T1 P3c.
(require_group module: (qualified_name) @module)

; ============================================================
; Built-in types (identifier-matched)
; ============================================================

((identifier) @type.builtin
  (#match? @type.builtin "^(Pi|Sigma|Type|Nat|Bool|Int|Rat|List|Vec|Fin|Eq|Chan|Session|Option|Result|Pair|String|Char|Symbol|Datum|Keyword|Set|Map|PVec|LSeq|Nil|Posit8|Posit16|Posit32|Posit64|TVec|TMap|TSet)$"))

; Types from grammar nodes
(type_application (identifier) @type)
(implicit_params (identifier) @type)
(typed_binder (identifier) @variable.parameter)

; Angle-delimited types: `<Bool>` return annotations (P3b) and
; `[iv <Interval>]` params (P5d).
;
; NOTE the shape: `angle_param`'s NAME only, plus identifiers inside
; `type_arg_group`. Not `(angle_group)` or `(grouped_type)` as a whole — those
; are containers, and per the leaf-only rule at the top of this file capturing
; them would overlap the identifiers within. Identifiers inside an angle group
; are reached by the builtin-type match and the fallback instead.
(angle_param name: (identifier) @variable.parameter)
(type_arg_group (identifier) @type)

; ============================================================
; Path selection (spec §2.1)
; ============================================================
;
; A path STEP names a field, so its identifier is `@property`, not a variable —
; the distinction TextMate cannot make, since `admins:name` and `admins :name`
; differ only by a space. Placed before the builtin/constant matches below so a
; step whose name happens to collide with a builtin still reads as a step.

(nominal_step key: (identifier) @property)
(broadcast_step step: (identifier) @property)
(ordinal_step index: (number) @number)

; A SELECT-BLOCK BRANCH names a field too, and until 2026-08-15 only the dotted
; step above was chromed as one — so `cfg{server^.{ssl^.enabled^ssl port}}` gave
; `enabled` key colour and left `server`, `port` and the `^ssl` rename target as
; plain variables. One concept, two renderings (DEFERRED 135).
;
; ⚠ The `select_block` ancestor is LOAD-BEARING, not decoration. A `path_expr`
; head is a key only INSIDE a select block: the OUTER `path_expr` of
; `cfg{...}` has head `cfg`, which is the SUBJECT and must stay a variable.
; `(path_expr . (identifier) @property)` on its own would recolour every path
; subject in the corpus.
(select_block (path_expr . (identifier) @property))
(select_block (identifier) @property)

; The `^` rename TARGET is a key being CREATED. Captured as @property like every
; other key — the vocabulary draws no read/write distinction for a field name,
; and having the new name read differently from the old one is the very
; inconsistency this block removes.
;
; ⚠ MUST precede `(key_op) @operator` below, which spans the whole `^ssl`
; including the identifier: first match wins by FILE ORDER.
(key_op (identifier) @property)

; The step OPERATORS themselves.
(flatten_step) @operator
(row_splat) @operator
(key_op) @operator

; ============================================================
; Built-in constants (identifier-matched)
; ============================================================

((identifier) @constant.builtin
  (#match? @constant.builtin "^(zero|refl|nil|cons|nothing|just|pair|ok|err|inc|suc|vnil|vcons|fzero|fsuc|natrec|finrec|listrec|vecrec|vhead|vtail|first|snd|fst)$"))

; ============================================================
; Patterns
; ============================================================

; A pattern binder is a BINDING SITE, not a reference — `| z -> ...' introduces
; `z'.  It was @variable, which is the catch-all every unmatched identifier
; falls to, so a binder was indistinguishable from a use.  Measured 2026-08-15:
; 6123 spans in core/ win as bare @variable and 79.3% of them are plain `atom'
; references, so the catch-all is correctly NEUTRAL and the binders had to move
; out of it rather than the catch-all becoming loud.
(identifier_pattern (identifier) @variable.definition)
(constructor_pattern (identifier) @constructor)
(wildcard_pattern) @comment

; ============================================================
; Parameters and bindings
; ============================================================

; A `let` binding NAME is a binding SITE — like a match binder, and unlike a
; use.  `@variable.definition` is the capture the vocabulary already has for
; that (see `identifier_pattern` above); `bare_param` serves let names AND
; params, so only the enclosing node tells them apart.
;
; ⚠ These two rules said `@variable` (inert-by-design) until 2026-08-15, and
; that intent was enforced by NEITHER consumer, each for its own reason:
; Emacs DROPS a nil-mapped capture's rule entirely (prologos-ts-mode's
; "Deliberately unpainted" arm), so the @variable.parameter rules below
; painted let names; VS Code has no map entry for `variable` and skips it
; BEFORE claiming the span, so the same later capture claimed it there too.
; Both editors rendered "parameter" against the query's stated design, the
; parity golden recorded all three captures on the span (raw lists match ->
; green), and no gate asks which capture WINS.  A capture whose meaning is
; "paint nothing" is only real if every consumer both maps it and claims with
; it — otherwise it is a comment wearing a capture's clothes.
;
; MUST precede the `bare_param` rule below: first match wins by file order, so
; placing it after made these two rules VACUOUS — they compiled, and never
; fired. Caught by testing that captures actually appear, not that they parse.
(let_binding name: (typed_param_or_bare (bare_param (identifier) @variable.definition)))
(let_binding name: (typed_param_or_bare (typed_param name: (identifier) @variable.definition)))

(fn_param (identifier) @variable.parameter)
(typed_param name: (identifier) @variable.parameter)
; The TYPE of a fused param. Needed from 2026-08-15: the type used to be a
; `type_application`, which carried its own @type capture, and bounding it to a
; bare identifier (DEFERRED 134) left a USER type with no type rule at all —
; `Point` fell to @variable. `Int` did not, because the builtin rule above
; matches it by name, which is exactly what made the loss easy to miss.
(typed_param type: (identifier) @type)
(bare_param (identifier) @variable.parameter)


; ============================================================
; Operators
; ============================================================

["->" "|" "|>" ":=" "*" "via"] @operator

; Bare operators are first-class VALUES since Numerics N6e-E2 (`reduce + 0 xs`)
; and became atoms in TSG T1 P1b — so they are an `operator` node, not an
; identifier, wherever they appear.
(operator) @operator
(arrow_op) @operator
(compose_op) @operator
(linear_arrow) @operator

; ============================================================
; Multiplicity annotations
; ============================================================

(multiplicity) @attribute

; ============================================================
; Literals
; ============================================================

(nat_literal) @number
(rat_literal) @number
(approx_literal) @number
(number) @number
(string) @string
(char_literal) @character
; A map key is a field name, not a free-standing keyword literal. This MUST
; precede the generic `(keyword_literal)` below: first match wins by FILE ORDER,
; not by specificity, so placing it after would silently never fire.
(map_literal key: (keyword_literal) @property)
; Same rule, and it was VIOLATED here until EHP P3 (2026-08-15): these three sat
; ~20 lines BELOW the generic rule, under a "Constraints and metadata" heading,
; and were therefore vacuous — 158 of @attribute's 176 corpus occurrences (90%)
; painted as @string.special.symbol instead. check-reachability passed
; @attribute the whole time, because `(multiplicity)` above DOES fire; "fires
; somewhere" is not coverage.
(metadata_entry (keyword_literal) @attribute)
(trait_metadata (keyword_literal) @attribute)
(law_entry (keyword_literal) @attribute)
(keyword_literal) @string.special.symbol
(logic_variable) @variable.logic
(typed_hole) @variable.hole
["true" "false"] @constant.builtin
(comment) @comment

; ============================================================
; Quote / quasiquote
; ============================================================

(quote_expr "'" @operator)
(quasiquote_expr "`" @operator)
(unquote_expr "," @operator)

; ============================================================
; Constraints and metadata
; ============================================================

(where_clause "where" @keyword)

; ============================================================
; Identifiers (fallback — must be last)
; ============================================================

(identifier) @variable

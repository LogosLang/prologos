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

(identifier_pattern (identifier) @variable)
(constructor_pattern (identifier) @constructor)
(wildcard_pattern) @comment

; ============================================================
; Parameters and bindings
; ============================================================

; A `let` binding NAME is a local binding, not a parameter — and `bare_param`
; serves BOTH, so only the enclosing node tells them apart. That is precisely
; what a regex grammar cannot see.
;
; MUST precede the `bare_param` rule below: first match wins by file order, so
; placing it after made these two rules VACUOUS — they compiled, and never
; fired. Caught by testing that captures actually appear, not that they parse.
(let_binding name: (typed_param_or_bare (bare_param (identifier) @variable)))
(let_binding name: (typed_param_or_bare (typed_param name: (identifier) @variable)))

(fn_param (identifier) @variable.parameter)
(typed_param name: (identifier) @variable.parameter)
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

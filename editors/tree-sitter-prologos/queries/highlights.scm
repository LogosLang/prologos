; Tree-sitter highlights for Prologos
; Refreshed 2026-03-11: Covers all current language constructs.

; ============================================================
; Keywords (grammar tokens — reserved words in grammar.js)
; ============================================================

["defn" "def" "data" "deftype" "match" "fn" "spec" "trait" "impl"
 "bundle" "property" "functor" "defmacro" "foreign" "subtype"
 "capability" "relation" "clause" "check" "eval" "infer"
 "ns" "provide" "require" "imports" "exports"
 "let" "if" "cond" "do" "the" "where" "when" "via"] @keyword

; Keywords that appear as identifiers (not grammar tokens)
((identifier) @keyword
  (#match? @keyword "^(forall|exists|solve|query|expand|expand-1|expand-full|parse|elaborate|with-transient|transient|reduce)$"))

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
(ns_declaration name: (qualified_name) @namespace)
(subtype_declaration sub: (identifier) @type)
(subtype_declaration super: (identifier) @type)
(capability_declaration name: (identifier) @type.definition)

; ============================================================
; Module system
; ============================================================

(require_declaration module: (qualified_name) @namespace)
(imports_declaration module: (qualified_name) @namespace)

; ============================================================
; Built-in types (identifier-matched)
; ============================================================

((identifier) @type.builtin
  (#match? @type.builtin "^(Pi|Sigma|Type|Nat|Bool|Int|Rat|List|Vec|Fin|Eq|Chan|Session|Option|Result|Pair|String|Char|Symbol|Datum|Keyword|Set|Map|PVec|LSeq|Nil|Posit8|Posit16|Posit32|Posit64|TVec|TMap|TSet)$"))

; Types from grammar nodes
(type_application (identifier) @type)
(implicit_params (identifier) @type)
(typed_binder (identifier) @variable.parameter)

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
; Parameters
; ============================================================

(fn_param (identifier) @variable.parameter)
(typed_param name: (identifier) @variable.parameter)
(bare_param (identifier) @variable.parameter)

; ============================================================
; Operators
; ============================================================

["->" "|" "|>" ">>" ":=" "*" "via"] @operator

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
(keyword_literal) @constant.other
(logic_variable) @variable.other
(typed_hole) @variable.other.hole
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
(metadata_entry (keyword_literal) @attribute)

; ============================================================
; Identifiers (fallback — must be last)
; ============================================================

(identifier) @variable

; Tree-sitter highlights for Prologos
; Used by editors (Neovim, Helix, etc.) and as reference for Emacs treesit rules.

; ============================================================
; Keywords (grammar tokens)
; ============================================================

["defn" "def" "data" "deftype" "match" "fn"
 "ns" "provide" "require" ":refer"] @keyword

; Keywords (identifier-matched — not grammar tokens)
((identifier) @keyword
  (#match? @keyword "^(the|let|do|if|forall|exists|check|eval|infer|defmacro|relation|clause|query)$"))

; ============================================================
; Definition names
; ============================================================

(defn_form name: (identifier) @function)
(def_form name: (identifier) @function)
(data_form name: (identifier) @type.definition)
(data_constructor name: (identifier) @constructor)
(ns_declaration name: (qualified_name) @namespace)

; ============================================================
; Built-in types (identifier-matched)
; ============================================================

((identifier) @type.builtin
  (#match? @type.builtin "^(Pi|Sigma|Type|Nat|Bool|Posit8|Vec|Fin|Eq|Chan|Session)$"))

; Types from grammar nodes
(type_expr (identifier) @type)
(type_application (identifier) @type)
(implicit_params (identifier) @type)

; ============================================================
; Built-in constants (identifier-matched)
; ============================================================

((identifier) @constant.builtin
  (#match? @constant.builtin "^(zero|true|false|refl|pair|inc|vnil|vcons|fzero|fsuc|nil|cons|nothing|just|posit8)$"))

; ============================================================
; Patterns
; ============================================================

(identifier_pattern (identifier) @variable)
(constructor_pattern (identifier) @constructor)
(wildcard_pattern) @comment

; ============================================================
; Expressions
; ============================================================

(fn_param (identifier) @variable.parameter)

; ============================================================
; Operators
; ============================================================

["->" "|"] @operator

; ============================================================
; Multiplicity annotations
; ============================================================

(multiplicity) @attribute

; ============================================================
; Literals
; ============================================================

(number) @number
(string) @string
(comment) @comment

; ============================================================
; Identifiers (fallback)
; ============================================================

(identifier) @variable

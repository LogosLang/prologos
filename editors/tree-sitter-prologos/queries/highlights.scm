; Tree-sitter highlights for Prologos
; Used by editors (Neovim, Helix, etc.) and as reference for Emacs treesit rules.

; ============================================================
; Keywords
; ============================================================

["defn" "def" "data" "deftype" "match" "fn"
 "ns" "provide" "require" ":refer"] @keyword

; ============================================================
; Definition names
; ============================================================

(defn_form name: (identifier) @function)
(def_form name: (identifier) @function)
(data_form name: (identifier) @type)
(data_constructor name: (identifier) @constructor)
(ns_declaration name: (qualified_name) @namespace)

; ============================================================
; Types
; ============================================================

(type_expr (identifier) @type)
(type_application (identifier) @type)
(implicit_params (identifier) @type)

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

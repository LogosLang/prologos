; Phase 4 placeholder — syntax highlighting queries for Prologos.
; Will be populated after grammar stabilizes.

; Keywords
["defn" "match" "ns" "provide"] @keyword

; Definition names
(defn_form name: (identifier) @function)

; Arrow operator
"->" @operator

; Match pipe
"|" @punctuation.delimiter

; Types (in type positions)
(type_expr (identifier) @type)

; Comments
(comment) @comment

; Strings
(string) @string

; Numbers
(number) @number

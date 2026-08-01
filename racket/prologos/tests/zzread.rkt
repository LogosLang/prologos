#lang racket/base
;; Reader-only dump: show the datums the WS reader produces for a snippet.
(require racket/file racket/pretty "../parse-reader.rkt")
(define src (vector-ref (current-command-line-arguments) 0))
(define txt (file->string src))
(define forms (compat-read-all-forms-string txt))
(for ([f (in-list forms)] [i (in-naturals)])
  (printf "=== form ~a ===\n" i)
  (pretty-write f))

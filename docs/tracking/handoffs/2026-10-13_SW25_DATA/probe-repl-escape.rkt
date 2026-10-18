#lang racket/base
;; Follow-on to DEFERRED 160 / SW-27: does an LSP REPL session's registration escape the session?
;; eval-in-session-raw! (lsp/server.rkt:206) binds 6 of the 24 registry parameters per session; the
;; ctor registry is not one of them. Measure where session A's `data Color` constructor is visible.
;; Run: timeout -k 10 300 racket probe-repl-escape.rkt <racket/prologos>
(require racket/file racket/port)
(define root (vector-ref (current-command-line-arguments) 0))
(define (dr mod sym) (dynamic-require (string->path (string-append root "/" mod)) sym))
(define make-initial-state (dr "lsp/server.rkt" 'make-initial-state))
(define get-or-create-session! (dr "lsp/server.rkt" 'get-or-create-session!))
(define eval-in-session-raw! (dr "lsp/server.rkt" 'eval-in-session-raw!))
(define process-file (dr "driver.rkt" 'process-file))
(define current-ctor-registry (dr "macros.rkt" 'current-ctor-registry))
(define current-file-module-network-ref (dr "namespace.rkt" 'current-file-module-network-ref))
(define st (make-initial-state))
(define a (get-or-create-session! st "file:///repl-a.prologos"))
(define b (get-or-create-session! st "file:///repl-b.prologos"))
(define (has-red?) (hash-has-key? (current-ctor-registry) 'Red))
(printf "0. process root before any eval:              Red registered? ~a\n" (has-red?))
(printf "   session A: data Color := Red | Green  ->  ~s\n"
        (eval-in-session-raw! st a "data Color := Red | Green\n"))
(printf "1. process root after session A's eval:       Red registered? ~a\n" (has-red?))
(define in-b #f)
(eval-in-session-raw! st b "def probe := 1\n")
(printf "2. (session B shares the root binding for ctors; see 1)\n")
(define dir (make-temporary-file "repl-escape-~a" 'directory))
(define doc (build-path dir "doc.prologos"))
(call-with-output-file doc #:exists 'truncate (λ (o) (display "ns doc\ndef z := 1\n" o)))
(define in-doc #f)
(parameterize ([current-file-module-network-ref #f] [current-output-port (open-output-nowhere)] [current-error-port (open-output-nowhere)])
  (process-file doc #:evaluate? #f #:before-unit-exit (λ () (set! in-doc (has-red?)))))
(printf "3. inside a later document check (process-file): Red registered? ~a\n" in-doc)
(delete-directory/files dir)

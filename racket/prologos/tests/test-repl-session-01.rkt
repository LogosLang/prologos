#lang racket/base

;;; test-repl-session-01.rkt — gh #73
;;;
;;; Cross-input session-persistence guard for the Emacs REPL (repl.rkt).
;;;
;;; Before the fix, repl.rkt's process-ws-input called process-command per-form
;;; with no persisted context (Bug A: `:load`/`def` then a later eval → Unbound),
;;; and used the single-form preparse-expand-form which never consumes `ns`
;;; (Bug B: a bare `ns foo` errored "ns should have been processed before
;;; parsing"). The fix mirrors lsp/server.rkt eval-in-session-raw!: a persistent
;;; session + process-string-ws + snapshot-back.
;;;
;;; This is the FIRST suite coverage of the repl.rkt eval path (complements
;;; test-lsp-repl-01.rkt, which covers the LSP eval path).

(require rackunit
         "../errors.rkt"
         (only-in "../repl.rkt"
                  make-repl-session
                  repl-eval!))

(define (has-error? results) (ormap prologos-error? results))
;; a multi-form input yields one result string per form, so match across ALL.
(define (any-match? results rx)
  (ormap (lambda (s) (and (string? s) (regexp-match? rx s))) results))

;; Shared session: prelude loads once (~3s) via make-repl-session, then reused.
(define session (make-repl-session))

;; ---- Bug B: a bare `ns` at the REPL must be consumed, not error ----
(let ([r (repl-eval! session "ns reptest")])
  (check-false (has-error? r)
               (format "bare `ns reptest` should be consumed, not error (Bug B); got ~a" r)))

;; ---- Bug A: the prelude persists after `ns` — a prelude name resolves ----
(let ([r (repl-eval! session "[add 3N 4N]")])
  (check-false (has-error? r)
               (format "`[add 3N 4N]` should resolve prelude `add` (Bug A/persistence); got ~a" r))
  (check-true (any-match? r #rx"7N")
              (format "`[add 3N 4N]` should evaluate to 7N; got ~a" r)))

;; ---- Bug A: a `def` in one input is visible in a later input ----
(check-false (has-error? (repl-eval! session "def x := 42")) "def x := 42 should succeed")
(let ([r (repl-eval! session "x")])
  (check-false (has-error? r)
               (format "`x` should resolve the prior-input def (Bug A); got ~a" r))
  (check-true (any-match? r #rx"42")
              (format "`x` should evaluate to 42; got ~a" r)))

;; ---- Multi-form single input (def then use) still works ----
(let ([r (repl-eval! session "def y := 5\n\n[int+ x y]")])
  (check-false (has-error? r)
               (format "multi-form input (def y; use x+y) should succeed; got ~a" r))
  (check-true (any-match? r #rx"47")
              (format "`[int+ x y]` should be 47 (x=42, y=5); got ~a" r)))

;; ---- Session isolation: a fresh session does NOT see the first session's defs ----
(let ([s2 (make-repl-session)])
  (define r (repl-eval! s2 "x"))
  (check-true (has-error? r)
              (format "`x` should be UNBOUND in a fresh session (no cross-session leak); got ~a" r)))

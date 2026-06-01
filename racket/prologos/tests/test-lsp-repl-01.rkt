#lang racket/base

;;; test-lsp-repl-01.rkt — PPN 4C Addendum Phase 4A.c-iii-d
;;;
;;; Cross-command interactive-editing regression guard for the LSP REPL.
;;;
;;; The 4A.b read-flip (global-env-add → mnr-only) broke cross-command def
;;; persistence: eval-in-session-raw! bound a FRESH module-network-ref per
;;; command and discarded it (the repl-session had no mnr field), so `def x`
;;; in command 1 was invisible in command 2 ("Unbound variable x"). The
;;; vestigial param-snapshot it persisted (current-prelude-env /
;;; current-definition-cells-content) went dead when global-env-add flipped
;;; to write only the mnr. 4A.c-iii-d persists the mnr in the repl-session
;;; (inherit-or-create + writeback, mirroring process-file's lifecycle).
;;;
;;; This is the suite's FIRST LSP-eval-path coverage — closing the Level-3
;;; "not suite-tested" gap (lsp/server.rkt TODO) that let the regression land
;;; invisibly.

(require rackunit
         "../errors.rkt"
         (only-in "../lsp/server.rkt"
                  make-initial-state
                  get-or-create-session!
                  eval-in-session-raw!))

;; Shared fixture: ONE lsp-state at module level. The prelude loads once on
;; the first get-or-create-session! (~3s); subsequent sessions reuse the cache.
(define st (make-initial-state))

;; eval-in-session-raw! returns a list of strings / prologos-error structs.
(define (eval-line session code)
  (eval-in-session-raw! st session (string-append code "\n")))

(define (no-error? results)
  (and (pair? results) (not (ormap prologos-error? results))))

(define (result-text results)
  (and (pair? results) (string? (car results)) (car results)))

;; ---- The regression: cross-command def persistence ----
;; cmd1 `def x := 42` then cmd2 `x` must resolve (was "Unbound variable x").
(let ([session (get-or-create-session! st "file:///test-repl-crosscmd.prologos")])
  (define r1 (eval-line session "def x := 42"))
  (check-true (no-error? r1)
              (format "cmd1 `def x := 42` should succeed; got ~a" r1))
  (define r2 (eval-line session "x"))
  (check-true (no-error? r2)
              (format "cmd2 `x` should resolve cmd1's def (4A.c-iii-d regression guard); got ~a"
                      r2))
  (check-true (and (result-text r2) (regexp-match? #rx"42" (result-text r2)))
              (format "cmd2 `x` should evaluate to 42; got ~a" r2)))

;; ---- Multi-command accumulation: a later command sees ALL prior defs ----
(let ([session (get-or-create-session! st "file:///test-repl-accum.prologos")])
  (check-true (no-error? (eval-line session "def a := 10")) "def a")
  (check-true (no-error? (eval-line session "def b := 20")) "def b")
  (define r (eval-line session "[int+ a b]"))
  (check-true (no-error? r)
              (format "`[int+ a b]` should resolve both prior cross-command defs; got ~a" r))
  (check-true (and (result-text r) (regexp-match? #rx"30" (result-text r)))
              (format "`[int+ a b]` should be 30; got ~a" r)))

;; ---- Per-session isolation: a def in URI-A is NOT visible in URI-B ----
;; (each session owns its own mnr; the fix must not leak defs across sessions).
(let ([sa (get-or-create-session! st "file:///test-repl-iso-a.prologos")]
      [sb (get-or-create-session! st "file:///test-repl-iso-b.prologos")])
  (check-true (no-error? (eval-line sa "def only-in-a := 1")) "def only-in-a in session A")
  (define rb (eval-line sb "only-in-a"))
  (check-true (ormap prologos-error? rb)
              (format "only-in-a should be UNBOUND in session B (per-session mnr isolation); got ~a"
                      rb)))

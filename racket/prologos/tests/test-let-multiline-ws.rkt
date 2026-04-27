#lang racket/base

;;;
;;; Regression tests for multi-line `let` forms in WS mode.
;;;
;;; Background — the eigentrust pitfalls doc (2026-04-23) #5 reported that
;;; a multi-line `let` like
;;;
;;;     (let [x := 1]
;;;       match x | _ -> x)
;;;
;;; failed with
;;;
;;;     let: let with bracket bindings requires: (let [bindings...] body)
;;;
;;; The bracket form `(let [bindings] body)` is the multi-binding shape;
;;; for a single binding the inline form `(let x := 1 body)` is also
;;; available. The bug surfaces specifically with the bracket form because
;;; that branch was the one that didn't re-group post-bindings tokens.
;;;
;;; Root cause — when the whole let form is wrapped in an explicit `(...)`,
;;; the WS reader's group-items applies its "brackets win" rule and DROPS
;;; the indent-open / indent-close markers around the body. The body's
;;; tokens (`match x | _ -> x`) end up spliced flat into the let's
;;; argument list, so `expand-let` saw `((x := 1) match x ...)` instead of
;;; the expected `((x := 1) <body>)` shape. The bracket-bindings branch
;;; rejected anything other than rest-length 2, hence the error.
;;;
;;; Fix — `expand-let`'s bracket-bindings branch treats any post-bindings
;;; tokens beyond the first as an implicit body application, matching the
;;; usual "continuation lines are indented further than `let`" rule that
;;; defn / match honour at the top level.
;;;

(require rackunit
         "../parse-reader.rkt"
         "test-support.rkt")

;; --- Level 1 (preparse / read) helpers ---------------------------------

(define (ws-read s)
  (define in (open-input-string s))
  (prologos-read in))

;; ========================================
;; Read-level: post-bindings tokens flow through
;; ========================================

(test-case "single-line let: unchanged read shape"
  (define d (ws-read "(let [x := 1] x)"))
  (check-equal? d '(let (x := 1) x)))

(test-case "let with newline-then-single-token body: unchanged"
  (define d (ws-read "(let [x := 1]\n  x)"))
  (check-equal? d '(let (x := 1) x)))

(test-case "let with bracket-grouped body: unchanged"
  (define d (ws-read "(let [x := 1]\n  [add x 1])"))
  (check-equal? d '(let (x := 1) (add x 1))))

(test-case "let with multi-token continuation body: tokens spliced flat"
  ;; This documents the (intentional) parser behavior — `(...)` makes
  ;; brackets win over indent grouping, so the body's continuation tokens
  ;; arrive flat in `expand-let`'s `rest`. The expand-let branch is
  ;; responsible for re-grouping them.
  (define d (ws-read "(let [x := 1]\n  match x | _ -> x)"))
  (check-equal? d '(let (x := 1) match x $pipe _ -> x)))

;; ========================================
;; Process-string-ws: end-to-end elaboration
;; ========================================
;;
;; We call run-ns-ws-last for its side effect of running the WS pipeline
;; (preparse + elaborate + type-check). Returning without raising is the
;; signal that the regression is fixed; the value isn't compared.

(define (ws-runs? src)
  (with-handlers ([exn:fail? (lambda (e) (raise e))])
    (run-ns-ws-last src)
    #t))

(test-case "single-line let elaborates"
  (check-true (ws-runs? "(let [x := 1] x)")))

(test-case "multi-line let with simple body elaborates"
  (check-true (ws-runs? "(let [x := 1]\n  x)")))

(test-case "multi-line let with application body elaborates"
  (check-true (ws-runs? "(let [x := 1]\n  [int+ x 2])")))

(test-case "multi-line let with multi-token application body elaborates"
  ;; `int+ x 2` arrives flat at expand-let; the fix wraps it as the body.
  (check-true (ws-runs? "(let [x := 1]\n  int+ x 2)")))

(test-case "eigentrust reproducer: multi-line let with nested match body elaborates"
  ;; The shape from the eigentrust pitfalls doc #5, scaled down to the
  ;; minimum that exercises the same parser path. This is the case that
  ;; previously failed with `let: let with bracket bindings requires...`.
  (define src
    (string-append
     "(let [tnew := [int+ 1 2]]\n"
     "  match [int- tnew 3]\n"
     "    | -1 -> tnew\n"
     "    | _  -> [int- tnew 1])\n"))
  (check-true (ws-runs? src)))

(test-case "let with two bindings and multi-token body elaborates"
  (define src
    (string-append
     "(let [x := 1  y := 2]\n"
     "  int+ x y)\n"))
  (check-true (ws-runs? src)))

;; ========================================
;; Empty / bare let still raise
;; ========================================

(test-case "let with bindings but no body still raises"
  (check-exn exn:fail?
             (lambda () (run-ns-ws-last "(let [x := 1])"))))

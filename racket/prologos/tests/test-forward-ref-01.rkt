#lang racket/base

;;;
;;; test-forward-ref-01.rkt — PPN 4C Addendum Phase 4B.3-b (§18.21.22)
;;;
;;; The ACTIVE flip: forward bare-ref residuation. `def x := a` where `a` is a
;;; not-yet-defined SAME-FILE def-head installs a δ residuation propagator on
;;; NET-1 (the per-file mnr) + defers the commit; the file-end drive fires the δ
;;; when `a` grounds; the DQ5 post-drive sweep finalizes the result.
;;;
;;; Residuation is process-file-GATED (DQ4 — only process-file runs the drive +
;;; the finalize sweep), so these MUST run via process-file (NOT process-string-ws,
;;; where a forward ref errors immediately, status quo).
;;;
;;; Boundary (DEF vs USE): the slice residuates DEF BODIES. A top-level EXPRESSION
;;; that USES a forward-def before the file-end drive sees it pending → errors;
;;; that is the 4C all-at-once / general-body (4B.5) territory the design deferred.
;;;

(require rackunit
         racket/list
         racket/file
         "../driver.rkt"
         "../namespace.rkt"
         "../errors.rkt")

;; process-file a fixture string under a fresh per-file mnr (isolation). The
;; simple Nat-literal fixtures need no prelude (5N is a built-in literal).
(define (run-file-fixture str)
  (define tmp (make-temporary-file "fwdref-~a.prologos"))
  (call-with-output-file tmp #:exists 'replace
    (lambda (out) (display str out)))
  (define result
    (parameterize ([current-file-module-network-ref (make-module-network)]
                   [current-ns-context #f])
      (process-file (path->string tmp))))
  (delete-file tmp)
  result)

;; does the results list contain an unbound-variable-error for `name`?
(define (unbound-for? results name)
  (for/or ([r (in-list results)])
    (and (unbound-variable-error? r)
         (eq? (unbound-variable-error-name r) name))))

(define (has? results s) (and (member s results) #t))

;; ① forward DEF — the slice's deliverable: `def x := a` resolves at file-end.
(test-case "4B.3-b: forward def resolves (def x := a; def a := 5N)"
  (define rs (run-file-fixture "ns tf1\ndef x := a\ndef a := 5N"))
  (check-true (has? rs "x : Nat defined."))
  (check-true (has? rs "a : Nat defined.")))

;; ② forward DEF-CHAIN — a residuates → x's δ → y's δ, all at the one drive.
(test-case "4B.3-b: forward def-chain resolves (def y := x; def x := a; def a := 5N)"
  (define rs (run-file-fixture "ns tf2\ndef y := x\ndef x := a\ndef a := 5N"))
  (check-true (has? rs "y : Nat defined."))
  (check-true (has? rs "x : Nat defined."))
  (check-true (has? rs "a : Nat defined.")))

;; backward control — x is ground before its use, so the use works (parity).
(test-case "4B.3-b: backward control (def a := 5N; def x := a; x ⇒ 5N)"
  (define rs (run-file-fixture "ns tf3\ndef a := 5N\ndef x := a\nx"))
  (check-true (has? rs "a : Nat defined."))
  (check-true (has? rs "x : Nat defined."))
  (check-true (has? rs "5N : Nat")))

;; DQ5 file-end shift — a is a def-head (seeded, pending) but its def FAILS, so
;; x's δ never fires → the post-drive sweep emits x's unbound error at file-end.
(test-case "4B.3-b: never-grounded forward def → file-end unbound (DQ5)"
  (define rs (run-file-fixture "ns tf4\ndef x := a\ndef a := badref"))
  (check-true (unbound-for? rs 'x))        ;; residuated, never grounded → file-end
  (check-true (unbound-for? rs 'badref)))  ;; absent typo → immediate

;; typo — `nonexistent` is never a def-head (Pass 1.5 never seeds it → absent,
;; not pending), so it is NOT residuated and errors immediately at the ref site.
(test-case "4B.3-b: typo (absent, never a def-head) → immediate unbound"
  (define rs (run-file-fixture "ns tf5\ndef x := nonexistent"))
  (check-true (unbound-for? rs 'nonexistent)))

;; ③ the DEF-vs-USE boundary — the forward DEF resolves, but a top-level EXPR
;; USE of x BEFORE the drive sees x pending → unbound (the documented 4C boundary).
(test-case "4B.3-b boundary: mid-file top-level use of a forward-def errors (4C territory)"
  (define rs (run-file-fixture "ns tf6\ndef x := a\ndef a := 5N\nx"))
  (check-true (has? rs "x : Nat defined."))  ;; the DEF resolves
  (check-true (unbound-for? rs 'x)))          ;; the premature USE errors

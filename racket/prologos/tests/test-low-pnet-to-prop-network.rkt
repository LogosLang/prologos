#lang racket/base

;; test-low-pnet-to-prop-network.rkt
;; kernel-pocket-universes Phase 4 Day 10.
;;
;; Round-trip gate: for every supported AST shape, lowering through
;; ast-to-low-pnet → low-pnet-to-prop-network → run-to-quiescence
;; produces the same result as the AST-direct LLVM pipeline.
;;
;; This decouples IR / lowering correctness from native-kernel correctness:
;; if the AST → IR → prop-network → run path produces the same value as
;; the AST → IR → LLVM → native-binary path, the IR shape is faithful.
;; If they diverge, the divergence localizes to either the LLVM emitter
;; or the kernel runtime.

(require rackunit
         "../syntax.rkt"
         "../low-pnet-ir.rkt"
         "../ast-to-low-pnet.rkt"
         "../low-pnet-to-prop-network.rkt"
         "../propagator.rkt")

;; Helper: lower an AST to Low-PNet, materialize, run, return the result.
(define (round-trip ast-type ast-body)
  (define lp (ast-to-low-pnet ast-type ast-body "test.prologos"))
  (run-low-pnet lp))

;; ============================================================
;; Smoke tests on AST shapes ast-to-low-pnet supports
;; ============================================================

(test-case "Day 10 round-trip: Int literal"
  (check-equal? (round-trip (expr-Int) (expr-int 42)) 42)
  (check-equal? (round-trip (expr-Int) (expr-int 0))  0)
  (check-equal? (round-trip (expr-Int) (expr-int -7)) -7))

(test-case "Day 10 round-trip: Bool literals (normalized to 0/1, like LLVM lowering)"
  ;; init-value-normalize matches low-pnet-to-llvm.rkt's i64 marshaling
  ;; (#t → 1, #f → 0) so kernel-int-{eq,lt,le} and kernel-select observe
  ;; the same values via the prop-network as via the native binary.
  (check-equal? (round-trip (expr-Bool) (expr-true))  1)
  (check-equal? (round-trip (expr-Bool) (expr-false)) 0))

(test-case "Day 10 round-trip: int-add"
  (check-equal? (round-trip (expr-Int) (expr-int-add (expr-int 1) (expr-int 2))) 3)
  (check-equal? (round-trip (expr-Int) (expr-int-add (expr-int -5) (expr-int 8))) 3))

(test-case "Day 10 round-trip: int-sub"
  (check-equal? (round-trip (expr-Int) (expr-int-sub (expr-int 10) (expr-int 3))) 7))

(test-case "Day 10 round-trip: int-mul"
  (check-equal? (round-trip (expr-Int) (expr-int-mul (expr-int 6) (expr-int 7))) 42))

(test-case "Day 10 round-trip: int-div (truncated)"
  (check-equal? (round-trip (expr-Int) (expr-int-div (expr-int 17) (expr-int 5))) 3)
  (check-equal? (round-trip (expr-Int) (expr-int-div (expr-int -17) (expr-int 5))) -3))

(test-case "lowering-yolo Phase A: int-mod (floored, sign-of-divisor)"
  ;; 100 mod 7 = 2 (positive)
  (check-equal? (round-trip (expr-Int) (expr-int-mod (expr-int 100) (expr-int 7))) 2)
  ;; 5040 mod 256 = 176 (used in fact-7 acceptance)
  (check-equal? (round-trip (expr-Int) (expr-int-mod (expr-int 5040) (expr-int 256))) 176)
  ;; -7 mod 3 = 2 with floored / sign-of-divisor semantics (matches Zig @mod
  ;; and Racket's `modulo`); contrast remainder which would give -1.
  (check-equal? (round-trip (expr-Int) (expr-int-mod (expr-int -7) (expr-int 3))) 2))

(test-case "lowering-yolo Phase A: int-neg (1,1) propagator"
  (check-equal? (round-trip (expr-Int) (expr-int-neg (expr-int 5))) -5)
  (check-equal? (round-trip (expr-Int) (expr-int-neg (expr-int -42))) 42)
  (check-equal? (round-trip (expr-Int) (expr-int-neg (expr-int 0))) 0))

(test-case "lowering-yolo Phase A: int-abs (1,1) propagator"
  (check-equal? (round-trip (expr-Int) (expr-int-abs (expr-int 99))) 99)
  (check-equal? (round-trip (expr-Int) (expr-int-abs (expr-int -99))) 99)
  ;; abs.prologos shape: [int-abs [int-neg 99]] = abs(-99) = 99
  (check-equal? (round-trip (expr-Int)
                            (expr-int-abs (expr-int-neg (expr-int 99))))
                99))

(test-case "Day 10 round-trip: nested arithmetic [int+ [int* 2 3] 4]"
  (define ast (expr-int-add (expr-int-mul (expr-int 2) (expr-int 3))
                            (expr-int 4)))
  (check-equal? (round-trip (expr-Int) ast) 10))

(test-case "Day 10 round-trip: deeply nested [int+ [int* 2 3] [int* 4 5]]"
  (define ast (expr-int-add (expr-int-mul (expr-int 2) (expr-int 3))
                            (expr-int-mul (expr-int 4) (expr-int 5))))
  (check-equal? (round-trip (expr-Int) ast) 26))

(test-case "Day 10 round-trip: 5-deep [int+ [int+ [int+ [int+ [int+ 1 2] 3] 4] 5] 6]"
  (define ast
    (expr-int-add
     (expr-int-add
      (expr-int-add
       (expr-int-add
        (expr-int-add (expr-int 1) (expr-int 2))
        (expr-int 3))
       (expr-int 4))
      (expr-int 5))
     (expr-int 6)))
  (check-equal? (round-trip (expr-Int) ast) 21))

;; ============================================================
;; Mode tag: V1.1 write-decl mode dispatch
;; ============================================================
;;
;; Materialization must dispatch on write-decl mode tag — 'merge calls
;; net-cell-write, 'reset calls net-cell-reset. We construct the IR
;; programmatically (not through ast-to-low-pnet) so we can exercise
;; both modes on the same cell.

(test-case "Day 10 mode tag: 'merge write goes through net-cell-write (LWW domain)"
  (define lp (parse-low-pnet
              '(low-pnet
                :version (1 1)
                (domain-decl 0 int kernel-merge-int 0 never)
                (cell-decl   0 0 0)              ; init=0
                (write-decl  0 99 0 merge)
                (entry-decl  0))))
  (check-equal? (run-low-pnet lp) 99))

(test-case "Day 10 mode tag: 'reset write goes through net-cell-reset (also LWW; observable equivalence)"
  (define lp (parse-low-pnet
              '(low-pnet
                :version (1 1)
                (domain-decl 0 int kernel-merge-int 0 never)
                (cell-decl   0 0 5)              ; init=5
                (write-decl  0 11 0 reset)
                (entry-decl  0))))
  (check-equal? (run-low-pnet lp) 11))

(test-case "Day 10 mode tag: mixed merge + reset on the same cell, last-write-wins"
  ;; Both modes ultimately leave the cell with the last-written value
  ;; under LWW semantics. The DIFFERENCE between modes (merge enqueues,
  ;; reset doesn't) only matters when the cell has subscribers; with no
  ;; downstream propagators there's no observable scheduling difference.
  (define lp (parse-low-pnet
              '(low-pnet
                :version (1 1)
                (domain-decl 0 int kernel-merge-int 0 never)
                (cell-decl   0 0 0)
                (write-decl  0 1 0)              ; merge default
                (write-decl  0 2 0 reset)        ; reset overwrites
                (write-decl  0 3 0 merge)        ; merge overwrites
                (entry-decl  0))))
  (check-equal? (run-low-pnet lp) 3))

;; ============================================================
;; Kernel parity: every fire-fn tag emitted by ast-to-low-pnet has
;; a Racket implementation in low-pnet-to-prop-network's table.
;; ============================================================

(test-case "Day 10 parity: kernel-int-eq emits 0/1 like the Zig kernel"
  (define lp-eq-true
    (parse-low-pnet
     '(low-pnet
       :version (1 1)
       (domain-decl 0 int kernel-merge-int 0 never)
       (cell-decl   0 0 7)
       (cell-decl   1 0 7)
       (cell-decl   2 0 0)
       (propagator-decl 0 (0 1) (2) kernel-int-eq 0)
       (entry-decl  2))))
  (check-equal? (run-low-pnet lp-eq-true) 1)

  (define lp-eq-false
    (parse-low-pnet
     '(low-pnet
       :version (1 1)
       (domain-decl 0 int kernel-merge-int 0 never)
       (cell-decl   0 0 7)
       (cell-decl   1 0 8)
       (cell-decl   2 0 0)
       (propagator-decl 0 (0 1) (2) kernel-int-eq 0)
       (entry-decl  2))))
  (check-equal? (run-low-pnet lp-eq-false) 0))

(test-case "Day 10 parity: kernel-select picks then-branch on cond=1"
  (define lp
    (parse-low-pnet
     '(low-pnet
       :version (1 1)
       (domain-decl 0 int kernel-merge-int 0 never)
       (cell-decl   0 0 1)              ; cond
       (cell-decl   1 0 100)            ; then
       (cell-decl   2 0 200)            ; else
       (cell-decl   3 0 0)              ; result
       (propagator-decl 0 (0 1 2) (3) kernel-select 0)
       (entry-decl  3))))
  (check-equal? (run-low-pnet lp) 100))

(test-case "Day 10 parity: kernel-select picks else-branch on cond=0"
  (define lp
    (parse-low-pnet
     '(low-pnet
       :version (1 1)
       (domain-decl 0 int kernel-merge-int 0 never)
       (cell-decl   0 0 0)              ; cond=false
       (cell-decl   1 0 100)
       (cell-decl   2 0 200)
       (cell-decl   3 0 0)
       (propagator-decl 0 (0 1 2) (3) kernel-select 0)
       (entry-decl  3))))
  (check-equal? (run-low-pnet lp) 200))

;; ============================================================
;; Failure paths
;; ============================================================

(test-case "Day 10 reject: unsupported fire-fn-tag"
  (define lp (parse-low-pnet
              '(low-pnet
                :version (1 1)
                (domain-decl 0 int kernel-merge-int 0 never)
                (cell-decl 0 0 0)
                (cell-decl 1 0 0)
                (propagator-decl 0 (0) (1) bogus-tag 0)
                (entry-decl 1))))
  (check-exn low-pnet-materialize-error?
    (lambda () (low-pnet-to-prop-network lp))))

(test-case "Day 13 reject: iter-block-decl IR node retired (now parse error)"
  ;; iter-block-decl was retired 2026-05-02 (kernel-PU Phase 6 Day 13,
  ;; § 9.1 Category B). The IR node itself is gone; programs that
  ;; declare it now fail at parse-low-pnet with "unknown decl head".
  (check-exn low-pnet-parse-error?
    (lambda ()
      (parse-low-pnet
       '(low-pnet
         :version (1 1)
         (domain-decl 0 int kernel-merge-int 0 never)
         (cell-decl 0 0 0)
         (cell-decl 1 0 0)
         (cell-decl 2 0 0)
         (iter-block-decl (0) (1) 2 #t)
         (entry-decl 0))))))

(test-case "Day 10 reject: stratum-decl"
  (define lp (parse-low-pnet
              '(low-pnet
                :version (1 1)
                (domain-decl 0 int kernel-merge-int 0 never)
                (cell-decl 0 0 0)
                (stratum-decl 0 my-stratum kernel-merge-int)
                (entry-decl 0))))
  (check-exn low-pnet-materialize-error?
    (lambda () (low-pnet-to-prop-network lp))))

(test-case "Day 10 reject: arity mismatch"
  (define lp (parse-low-pnet
              '(low-pnet
                :version (1 1)
                (domain-decl 0 int kernel-merge-int 0 never)
                (cell-decl 0 0 0)
                (cell-decl 1 0 0)
                ;; kernel-int-add wants 2 inputs; we give 1
                (propagator-decl 0 (0) (1) kernel-int-add 0)
                (entry-decl 1))))
  (check-exn low-pnet-materialize-error?
    (lambda () (low-pnet-to-prop-network lp))))

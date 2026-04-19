#lang racket/base

;;;
;;; test-elaboration-parity.rkt — PPN Track 4C Parity Regression Suite (SKELETON)
;;;
;;; Per PPN Track 4C Design D.3 §9 (parity skeleton as design artifact, M3).
;;; Each test encodes a DIVERGENCE CLASS — behavior where the pre-4C imperative
;;; elaboration path and the post-4C on-network elaboration path could produce
;;; different outputs during migration.
;;;
;;; STATUS: skeleton. Tests are SKIP'd until the relevant 4C phase completes
;;; the migration for that axis; enable per the mapping in D.3 §9.1.
;;;
;;; Harness design: each test runs the SAME input through both paths and
;;; asserts equivalent output. During early phases the harness stub is
;;; unwired (setup-parity-harness raises); it becomes real at Phase 3 when
;;; the first axis (A5 :type/:term split) produces a divergence class.
;;;
;;; Per-phase enablement:
;;;   Phase 3 (A5)        → enable axis 5 tests
;;;   Phase 4 (A2)        → enable axis 2 tests
;;;   Phase 5 (A6)        → enable axis 6 tests
;;;   Phase 6 (A3)        → enable axis 3 tests
;;;   Phase 7 (A1)        → enable axis 1 tests
;;;   Phase 8 (A4 Opt A)  → enable axis 4 Option-A tests
;;;   Phase 9b (γ)        → enable γ hole-fill tests
;;;   Phase 10 (union)    → enable union-type tests
;;;   Phase 11 (A7)       → enable axis 7 orchestration tests
;;;   Phase 12 (A4 Opt C) → enable axis 4 Option-C + cell-ref tests
;;;

(require rackunit
         "test-support.rkt")

;; ========================================
;; Harness stubs — wired at Phase 3 (first meaningful divergence class).
;; ========================================

;; setup-parity-harness returns (values baseline-process post-4c-process)
;; where each is (String -> ElaborationResult). The two paths run under
;; different flag configurations selecting pre-4C vs post-4C elaboration.
;; Until Phase 3, invoking this raises; each test-case wraps in with-skip.
(define (setup-parity-harness)
  (error 'setup-parity-harness
         "Parity harness not yet wired — enable at Phase 3 of PPN Track 4C"))

;; check-parity-equal? : sym String #:expected any -> void
;; Runs input through both paths; asserts equivalent output.
(define (check-parity-equal? tag input
                             #:expected [expected #f]
                             #:expected-type [expected-type #f]
                             #:expected-warnings [expected-warnings #f]
                             #:expected-shape [expected-shape #f])
  (error 'check-parity-equal? "Phase 3 wire-up pending"))

;; Skip wrapper: each test-case uses this to remain inert until its phase lands.
(define-syntax-rule (parity-test tag phase input body ...)
  (test-case (format "[~a] ~a (pending ~a)" tag input phase)
    ;; Intentionally SKIP. At phase enablement, replace with body ....
    (void)))

;; ========================================
;; Axis 1 — Parametric trait-resolution (Phase 7)
;; ========================================

(parity-test 'parametric-seqable-list "Phase 7"
             "[head '[1N 2N 3N]]"
  (check-parity-equal? 'parametric-seqable-list
                       "[head '[1N 2N 3N]]"
                       #:expected '(Just 1N)))

(parity-test 'parametric-foldable "Phase 7"
             "[foldr + 0N '[1N 2N 3N]]"
  (check-parity-equal? 'parametric-foldable
                       "[foldr + 0N '[1N 2N 3N]]"
                       #:expected '6N))

;; ========================================
;; Axis 2 — CHAMP retirement (Phase 4)
;; ========================================

(parity-test 'meta-solution-zonk "Phase 4"
             "let x := ?? in [+ x 1N]"
  (check-parity-equal? 'meta-solution-zonk
                       "let x := ?? in [+ x 1N]"
                       #:expected-shape '(expr-add ? 1N)))

;; ========================================
;; Axis 3 — Aspect coverage (Phase 6)
;; ========================================

(parity-test 'session-typing "Phase 6"
             "proc p { !! Nat ; end }"
  (check-parity-equal? 'session-typing
                       "proc p { !! Nat ; end }"
                       #:expected-type '(Session ...)))

;; ========================================
;; Axis 4 — Freeze/zonk (Option A at Phase 8, Option C at Phase 12)
;; ========================================

(parity-test 'freeze-option-a "Phase 8"
             "let x := 3N in x"
  (check-parity-equal? 'freeze-option-a
                       "let x := 3N in x"
                       #:expected '3N))

(parity-test 'cell-ref-option-c "Phase 12"
             "reading-expr-is-zonk"
  (check-parity-equal? 'cell-ref-option-c
                       "reading-expr-is-zonk"
                       #:expected 'zonk-equiv))

;; ========================================
;; Axis 5 — :type/:term facet split (Phase 3)
;; ========================================

(parity-test 'type-meta-split "Phase 3"
             "[id 'nat 3N]"   ; id : {A : Type 0} -> A -> A
  (check-parity-equal? 'type-meta-split
                       "[id 'nat 3N]"
                       #:expected '3N))

;; ========================================
;; Axis 6 — Warnings authority (Phase 5)
;; ========================================

(parity-test 'coercion-warning-facet "Phase 5"
             "[int+ 3 [p32->int 3.14p32]]"
  (check-parity-equal? 'coercion-warning-facet
                       "[int+ 3 [p32->int 3.14p32]]"
                       #:expected-warnings '(mixed-numeric ...)))

;; ========================================
;; Axis 7 — Elaborator strata → BSP (Phase 11)
;; Orchestration parity: behavior should be identical; ordering may differ.
;; ========================================

(parity-test 'orchestration-strata "Phase 11"
             "trait-resolution-then-checkQ"
  (check-parity-equal? 'orchestration-strata
                       "trait-resolution-then-checkQ"
                       #:expected 'unchanged))

;; ========================================
;; Phase 10 — Union types via ATMS (cell-based TMS)
;; ========================================

(parity-test 'union-narrow-by-constraint "Phase 10"
             "let x := (the <Int | String> 0) in [eq? x 0]"
  (check-parity-equal? 'union-narrow-by-constraint
                       "let x := (the <Int | String> 0) in [eq? x 0]"
                       #:expected-type 'Int))

;; ========================================
;; Phase 9b — γ hole-fill inhabitant synthesis
;; ========================================

(parity-test 'gamma-hole-fill "Phase 9b"
             "[id ?? 3N]"
  (check-parity-equal? 'gamma-hole-fill
                       "[id ?? 3N]"
                       #:expected '3N))

;; ========================================
;; Diagnostic (Phase 11b) — error-message equivalence
;; ========================================

(parity-test 'error-provenance-chain "Phase 11b"
             "[int+ \"a\" 3]"
  (check-parity-equal? 'error-provenance-chain
                       "[int+ \"a\" 3]"
                       #:expected-type 'type-top))

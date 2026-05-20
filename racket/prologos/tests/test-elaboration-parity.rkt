#lang racket/base

;;;
;;; test-elaboration-parity.rkt — PPN Track 4C Parity Regression Suite
;;;
;;; Per PPN Track 4C Design D.3 §9 (parity skeleton as design artifact, M3).
;;; Each test encodes a DIVERGENCE CLASS — behavior where the pre-4C imperative
;;; elaboration path and the post-4C on-network elaboration path could produce
;;; different outputs during migration.
;;;
;;; Harness design (Phase 3d, PPN 4C): approach C — expected-output assertions
;;; (no dual-path code, no git-checkout orchestration). Each test encodes the
;;; POST-4C behavior we expect. For cases where pre-4C and post-4C behavior
;;; should match, the expected value is what both produce. For cases where
;;; post-4C legitimately diverges (e.g., Option C skip dissolution), the
;;; expected value captures the new correct behavior. The design analysis
;;; in D.3 §6.15.8 justifies each divergence; these tests regression-gate
;;; that the tag-split path maintains the expected semantics.
;;;
;;; Rejected alternatives:
;;;   (A) Feature flag toggling pre-4C vs post-4C in production code — violates
;;;       workflow.md "belt-and-suspenders" rule; permanent dual-path debt.
;;;   (B) Git-checkout-based A/B orchestration — expensive and fragile.
;;;
;;; Per-phase enablement:
;;;   Phase 3 (A5)        → axis 5 tests ENABLED (3d, PPN 4C)
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
         racket/string
         "test-support.rkt")

;; ========================================
;; Harness — approach C (Phase 3d wire-up)
;; ========================================
;;
;; Parity harness returns a process function that runs an expression
;; through the post-4C pipeline (current code on main). Each test-case
;; asserts the expected behavior. There is no "baseline-process" — the
;; expected value IS the behavior both paths produce (matched cases) or
;; the new correct behavior post-Option-C-skip-dissolution (diverged
;; cases). The design analysis in D.3 §6.15.8 justifies each.
;;
;; setup-parity-harness returns a single process function
;; (string → string) that runs the input through the current elaboration
;; path and returns the last result string.

(define (setup-parity-harness)
  (lambda (input)
    ;; run-ns-last uses the shared test-support fixture (preloaded prelude,
    ;; isolated global state) and returns the last result of process-string.
    ;; String is the pretty-printed final form (e.g., "3N : Nat").
    (run-ns-last input)))

;; check-parity-equal? asserts expectations against a single pipeline run.
;;   #:expected       — expected final-value pattern (substring match)
;;   #:expected-type  — expected type annotation (substring after " : ")
;;   #:expected-shape — structural pattern (currently substring, future: sexp)
;;   #:expected-warnings — substring expected in warnings stream (future)
;;
;; One pattern at a time; mix at test author's discretion. Regexp-safe
;; substring matching keeps tests declarative without requiring exact
;; output formatting.
(define (check-parity-equal? tag input
                             #:expected [expected #f]
                             #:expected-type [expected-type #f]
                             #:expected-warnings [expected-warnings #f]
                             #:expected-shape [expected-shape #f])
  (define process (setup-parity-harness))
  (define result (process input))
  (define result-str (if (string? result) result (format "~a" result)))
  (when expected
    (define expected-str (format "~a" expected))
    (check-true (string-contains? result-str expected-str)
                (format "[~a] expected ~a in ~s" tag expected-str result-str)))
  (when expected-type
    (define type-str (format " : ~a" expected-type))
    (check-true (string-contains? result-str type-str)
                (format "[~a] expected type ~a in ~s" tag expected-type result-str)))
  (when expected-shape
    (define shape-str (format "~a" expected-shape))
    (check-true (string-contains? result-str shape-str)
                (format "[~a] expected shape ~a in ~s" tag expected-shape result-str)))
  (when expected-warnings
    ;; Warnings appear interleaved in the pretty-printed output stream.
    (define warn-str (format "~a" expected-warnings))
    (check-true (string-contains? result-str warn-str)
                (format "[~a] expected warning ~a in ~s" tag expected-warnings result-str))))

;; parity-test-skip: for axes whose phase hasn't landed yet. Leaves the
;; test-case body inert. When the phase lands, convert to parity-test.
(define-syntax-rule (parity-test-skip tag phase input body ...)
  (test-case (format "[~a] ~a (pending ~a)" tag input phase)
    (void)))

;; parity-test: active test-case. Wraps in rackunit test-case for isolation.
(define-syntax-rule (parity-test tag phase input body ...)
  (test-case (format "[~a] ~a (~a)" tag input phase)
    body ...))

;; ========================================
;; Axis 1 — Parametric trait-resolution (Phase 7)
;; ========================================

(parity-test-skip 'parametric-seqable-list "Phase 7"
                  "[head '[1N 2N 3N]]"
  (check-parity-equal? 'parametric-seqable-list
                       "[head '[1N 2N 3N]]"
                       #:expected '(Just 1N)))

(parity-test-skip 'parametric-foldable "Phase 7"
                  "[foldr + 0N '[1N 2N 3N]]"
  (check-parity-equal? 'parametric-foldable
                       "[foldr + 0N '[1N 2N 3N]]"
                       #:expected '6N))

;; ========================================
;; Axis 2 — CHAMP retirement (Phase 4)
;; ========================================

(parity-test-skip 'meta-solution-zonk "Phase 4"
                  "let x := ?? in [+ x 1N]"
  (check-parity-equal? 'meta-solution-zonk
                       "let x := ?? in [+ x 1N]"
                       #:expected-shape '(expr-add ? 1N)))

;; ========================================
;; Axis 3 — Aspect coverage (Phase 6)
;; ========================================

(parity-test-skip 'session-typing "Phase 6"
                  "proc p { !! Nat ; end }"
  (check-parity-equal? 'session-typing
                       "proc p { !! Nat ; end }"
                       #:expected-type '(Session ...)))

;; ========================================
;; Axis 4 — Freeze/zonk (Option A at Phase 8, Option C at Phase 12)
;; ========================================

(parity-test-skip 'freeze-option-a "Phase 8"
                  "let x := 3N in x"
  (check-parity-equal? 'freeze-option-a
                       "let x := 3N in x"
                       #:expected '3N))

(parity-test-skip 'cell-ref-option-c "Phase 12"
                  "reading-expr-is-zonk"
  (check-parity-equal? 'cell-ref-option-c
                       "reading-expr-is-zonk"
                       #:expected 'zonk-equiv))

;; ========================================
;; Axis 5 — :type/:term facet split (Phase 3) — ENABLED at PPN 4C Phase 3d
;; ========================================
;;
;; The tag-split was designed to retire the Option C skip (a Track 4B
;; workaround for the classifier/inhabitant conflation in the :type facet
;; per D.3 §6.1). Parity tests verify:
;;
;;   1. Polymorphic application produces the correct final type via
;;      meta-feedback → :term (inhabitant) write + residuation
;;      compatibility check.
;;   2. Literal values keep their classifier types through elaboration.
;;   3. Identity function application resolves meta-A's type parameter
;;      via the feedback path (now on the inhabitant layer).
;;

(parity-test 'type-meta-split/literal "Phase 3"
             "3N"
  ;; Baseline: literal typing rule writes classifier (expr-Nat) via :type.
  ;; Residuation propagator threshold not met (no inhabitant layer written
  ;; for a literal — only classifier). Result: 3N : Nat.
  (check-parity-equal? 'type-meta-split/literal
                       "3N"
                       #:expected-type 'Nat))

(parity-test 'type-meta-split/identity-app "Phase 3"
             "[(fn [x] x) 3N]"
  ;; Polymorphic identity application: inferred lambda's domain is a meta
  ;; metaA (classifier role: Type(0) for type vars). Meta-feedback writes
  ;; INHABITANT = (expr-Nat) via :term when arg's type becomes ground.
  ;; Residuation fires when both layers are populated: compatible
  ;; (type-of-expr((expr-Nat)) = Type(0) ≼ Type(0) classifier). Result
  ;; type: Nat. Pre-4C produced the same result but required Option C
  ;; skip to avoid merging Type(0) × Nat at the conflated :type facet.
  (check-parity-equal? 'type-meta-split/identity-app
                       "[(fn [x] x) 3N]"
                       #:expected-type 'Nat))

(parity-test 'type-meta-split/int-identity "Phase 3"
             "[(fn [x] x) 42]"
  ;; Same pattern with Int inhabitant. Residuation: type-of-expr((expr-Int))
  ;; = Type(0) ≼ Type(0); compatible. Result type: Int.
  (check-parity-equal? 'type-meta-split/int-identity
                       "[(fn [x] x) 42]"
                       #:expected-type 'Int))

;; ========================================
;; Axis 6 — Warnings authority (Phase 5)
;; ========================================

(parity-test-skip 'coercion-warning-facet "Phase 5"
                  "[int+ 3 [p32->int 3.14p32]]"
  (check-parity-equal? 'coercion-warning-facet
                       "[int+ 3 [p32->int 3.14p32]]"
                       #:expected-warnings '(mixed-numeric ...)))

;; ========================================
;; Axis 7 — Elaborator strata → BSP (Phase 11)
;; ========================================

(parity-test-skip 'orchestration-strata "Phase 11"
                  "trait-resolution-then-checkQ"
  (check-parity-equal? 'orchestration-strata
                       "trait-resolution-then-checkQ"
                       #:expected 'unchanged))

;; ========================================
;; PPN 4C 2A.a (2026-05-20) — retraction-parity axis
;; ========================================
;;
;; Verifies the cell-driven S(-1) retraction infrastructure (D.3 §8.7.a)
;; doesn't regress elaboration semantics relative to the pre-2A.a box-based
;; mechanism. The new path:
;;   record-assumption-retraction (pure) → retraction-stratum-request cell-13
;;   → BSP outer-loop's value-tier processing → process-retraction handler
;;   → scoped cells cleaned via net-cell-replace → S0 restart via worklist
;;
;; These integration smoke tests exercise expressions that traverse the
;; elaboration pipeline; if retraction infrastructure broke (handler not
;; firing, cell not auto-clearing, scoped-cell-replace not cascading), the
;; observable elaboration result would diverge. Direct mechanism tests live
;; in tests/test-retraction-stratum.rkt sections 7-9.

(parity-test 'retraction-baseline-simple "PPN 4C 2A.a"
             "[int+ 2 3]"
  ;; Baseline arithmetic — no speculation, no retraction. Verifies the new
  ;; infrastructure doesn't break basic flow (e.g., handler over-firing or
  ;; corrupting the prop-net on dormant retraction cell).
  (check-parity-equal? 'retraction-baseline-simple
                       "[int+ 2 3]"
                       #:expected '5))

(parity-test 'retraction-baseline-polymorphic "PPN 4C 2A.a"
             "[(fn [x] x) 3N]"
  ;; Polymorphic identity — exercises type-meta resolution + propagator
  ;; cascade. Stresses the same code path that with-speculative-rollback
  ;; touches (elab-net rewrap, prop-net snapshot semantics) without
  ;; actually triggering retraction. Verifies the rewrap pattern in
  ;; record-assumption-retraction's caller didn't introduce regressions.
  (check-parity-equal? 'retraction-baseline-polymorphic
                       "[(fn [x] x) 3N]"
                       #:expected '3N))

(parity-test 'retraction-baseline-annotation "PPN 4C 2A.a"
             "(the Int 42)"
  ;; Type ascription — exercises the typing path where with-speculative-rollback
  ;; can be invoked (typing-core.rkt:1205 area for map-assoc, etc.). Confirms
  ;; that elaboration still produces expected type post-2A.a.
  (check-parity-equal? 'retraction-baseline-annotation
                       "(the Int 42)"
                       #:expected-type 'Int))

;; ========================================
;; Phase 10 — Union types via ATMS (cell-based TMS)
;; ========================================

(parity-test-skip 'union-narrow-by-constraint "Phase 10"
                  "let x := (the <Int | String> 0) in [eq? x 0]"
  (check-parity-equal? 'union-narrow-by-constraint
                       "let x := (the <Int | String> 0) in [eq? x 0]"
                       #:expected-type 'Int))

;; ========================================
;; Phase 9b — γ hole-fill inhabitant synthesis
;; ========================================

(parity-test-skip 'gamma-hole-fill "Phase 9b"
                  "[id ?? 3N]"
  (check-parity-equal? 'gamma-hole-fill
                       "[id ?? 3N]"
                       #:expected '3N))

;; ========================================
;; Diagnostic (Phase 11b) — error-message equivalence
;; ========================================

(parity-test-skip 'error-provenance-chain "Phase 11b"
                  "[int+ \"a\" 3]"
  (check-parity-equal? 'error-provenance-chain
                       "[int+ \"a\" 3]"
                       #:expected-type 'type-top))

;; ========================================
;; Phase 1C-vi — tropical-fuel-counter-parity (D.4 reframed; §15 axis)
;; ========================================
;;
;; Per §15 (D.4 CANONICAL): tropical-fuel-counter-parity axis.
;; "OLD counter exhaustion (struct-field-based) vs NEW cell exhaustion (on-write
;; predicate at cell layer) at equivalent points for representative workloads."
;;
;; Under D.4 + 1C-iv-b retirement: OLD struct-field counter is RETIRED. "Parity"
;; reframes to regression-vs-historical-baseline (per §10.0.7 F9 + γ3-a
;; resolution): elaboration outputs for representative workloads should match
;; pre-Phase-1 baseline behavior, demonstrating that the cell-API substrate +
;; on-write predicate produce equivalent semantics to what the OLD counter +
;; inline-check produced.
;;
;; The Pre-0 S4 probe baseline (data/benchmarks/tropical-pre0-baseline-2026-04-26.txt
;; §S4) captured 28 commands across the probe workload. The probe is now run
;; under D.4 production code; if its output matches the baseline output, the
;; tropical-fuel-counter-parity axis holds.
;;
;; These tests assert SMALL representative elaboration outputs (single
;; expressions; NOT the full 28-command probe — that's handled at 1C-vi
;; Commit 2's probe + acceptance run). They demonstrate the on-network cell-
;; mechanism produces correct outputs across workloads that previously stressed
;; the OLD struct-field counter exhaustion path.

(parity-test 'tropical-fuel-simple-arithmetic "Phase 1C-vi"
             "[int+ 2 3]"
  (check-parity-equal? 'tropical-fuel-simple-arithmetic
                       "[int+ 2 3]"
                       #:expected '5))

(parity-test 'tropical-fuel-polymorphic-id "Phase 1C-vi"
             "[(fn [x] x) 3N]"
  ;; Polymorphic identity application — exercises type-meta resolution
  ;; (per axis 5 baseline); inheritable fuel-consumption pattern. Under
  ;; D.4: cell-API decrement at every reduce-step; on-write predicate
  ;; ensures exhaustion routes through cell layer if budget exceeded.
  (check-parity-equal? 'tropical-fuel-polymorphic-id
                       "[(fn [x] x) 3N]"
                       #:expected '3N))

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
;; PPN 4C 2A.b (2026-05-20) — resolution-parity axis
;; ========================================
;;
;; Verifies the cell-driven L2 resolution infrastructure (D.3 §8.7.b)
;; doesn't regress elaboration semantics relative to the pre-2A.b ready-queue
;; mechanism. The new path:
;;   readiness latch → resolution-stratum-request cell-14 (was per-command param)
;;   → BSP outer-loop's value-tier processing → process-resolution handler
;;   → executor (current-resolution-executor-pure) invokes resolution actions
;;   on enet via box-bridge → updated state in box
;;
;; Architectural-honesty framing (§8.7.b.3): unlike 2A.a's pure process-retraction,
;; this handler MUST box-bridge to elab-net. Parity tests verify the bridge
;; preserves semantics; box-bridge retirement gated on Parent Phase 4 + PM 12.
;;
;; FALSIFICATION COVERAGE: this axis intentionally uses only language-primitive
;; baseline cases (run-ns-last harness binds an empty prelude env, so prelude
;; functions like eq-check are unbound at the symbol-table layer). End-to-end
;; falsification — verifying process-resolution actually fires + the handler
;; reaches the executor + dict-meta solves + elaboration completes — is covered
;; by:
;;   (a) tests/test-readiness-propagator.rkt line 291 integration test —
;;       solves a dep meta and verifies actions appear in cell-14 via
;;       read-ready-queue-actions (exercises the full readiness latch → cell-14
;;       chain end-to-end at the API level).
;;   (b) tests/test-trait-resolution.rkt — broad trait dispatch coverage that
;;       inherently exercises process-resolution because trait resolution
;;       cascades through readiness latches.
;;   (c) The full suite — many tests exercise trait dispatch via process-string-ws
;;       which DOES bind the prelude env (unlike run-ns-last).
;; If process-resolution misfires (handler not registered, cell-14 not drained,
;; executor unset), (a) + (b) + (c) all fail visibly.

(parity-test 'resolution-baseline-arithmetic "PPN 4C 2A.b"
             "[int+ 1 2]"
  ;; Baseline arithmetic — primitive int+, no trait dispatch. Confirms the new
  ;; handler infrastructure doesn't break basic elaboration flow (e.g., handler
  ;; over-firing, polluting prop-net on dormant resolution cell, or causing
  ;; spurious value-tier work for non-trait-using expressions).
  (check-parity-equal? 'resolution-baseline-arithmetic
                       "[int+ 1 2]"
                       #:expected '3))

(parity-test 'resolution-baseline-polymorphic "PPN 4C 2A.b"
             "[(fn [x] x) 3N]"
  ;; Polymorphic identity — exercises type-meta resolution + propagator cascade.
  ;; Stresses the same elaboration codepath that constraint readiness latches
  ;; build atop, without requiring prelude-bound trait methods. Verifies the
  ;; resolution-stratum-request cell (cell-14) doesn't cause spurious value-tier
  ;; work on dormant constraints.
  (check-parity-equal? 'resolution-baseline-polymorphic
                       "[(fn [x] x) 3N]"
                       #:expected '3N))

(parity-test 'resolution-baseline-annotation "PPN 4C 2A.b"
             "(the Int 42)"
  ;; Type ascription — exercises check-path where readiness latches can fire
  ;; for inferred constraints. Confirms elaboration produces expected type
  ;; post-2A.b (mirror of retraction-baseline-annotation, axis above).
  (check-parity-equal? 'resolution-baseline-annotation
                       "(the Int 42)"
                       #:expected-type 'Int))

;; ========================================
;; PPN 4C 2A.c (2026-05-20) — orchestration-parity axis
;; ========================================
;;
;; Verifies the BSP outer-loop's value-tier orchestration (2A.a's
;; process-retraction + 2A.b's process-resolution + S1 NAF + classify-inhabit)
;; is observationally equivalent to the pre-2A sequential orchestrator
;; (run-stratified-resolution-pure) for RETRACTION-HEAVY workloads.
;;
;; THE FALSIFICATION TEST for D.3 §8.7.4's "S(-1) runs POST-S0" timing concern:
;;
;;   Pre-2A sequential loop:      cleanup → S0 → L2 → ...
;;                                (S(-1) runs BEFORE S0)
;;
;;   Post-2A BSP outer-loop:      S0 fires on potentially-stale state →
;;                                S(-1) cleans → restart-from-outer-loop →
;;                                S0 fires on cleaned state → ...
;;                                (S(-1) runs AFTER S0 quiescence)
;;
;; The 2A model adds one "extra round" of S0 firing on pre-cleanup state per
;; outer-loop iteration. Correctness argument (§8.7.4): worldview-filtering at
;; `net-cell-read` should hide stale entries from propagators firing under a
;; retracted assumption bitmask. S(-1)'s subsequent cleanup is COMPACTION (not
;; correctness). If worldview-filtering DOESN'T preserve correctness, these
;; tests fail because the "wrong" branch's stale entries contaminate the
;; correct branch's elaboration result.
;;
;; The retraction trigger: `def x : <T1 | T2> := value` invokes
;; `check ctx value (expr-union T1 T2)` at typing-core.rkt:2385, which uses
;; `with-speculative-rollback` to try T1 (registering hyp-id, writing under
;; hyp-bitmask), and on failure calls `record-assumption-retraction` (which
;; writes to cell-13 → process-retraction handler fires → S(-1) cleanup runs
;; POST-S0 per the 2A model). Then T2 is tried.
;;
;; Falsification posture: if the `(ns t)` bootstrap pattern works in the
;; run-ns-last harness, these tests serve as direct falsification of §8.7.4.
;; If not, the axis falls back to baseline + this NOTE pointing to
;; tests/test-punify-integration.rkt:228 (uses local run-last that DOES
;; bootstrap correctly; exercises `(def x : <Int | Bool> := "hello")`
;; contradiction-driven retraction path end-to-end).

(parity-test 'orchestration-union-no-retraction "PPN 4C 2A.c"
             "(ns t) (def x : <Int | String> := 42) x"
  ;; Baseline: Int branch of <Int | String> succeeds first; no retraction.
  ;; Confirms the union-check + speculation path produces correct elaboration
  ;; under 2A.b's handler-based orchestration without exercising the post-S0
  ;; S(-1) timing concern. (Compare with -with-retraction below.)
  (check-parity-equal? 'orchestration-union-no-retraction
                       "(ns t) (def x : <Int | String> := 42) x"
                       #:expected '42))

(parity-test 'orchestration-union-with-retraction "PPN 4C 2A.c"
             "(ns t) (def x : <Int | String> := \"hello\") x"
  ;; FALSIFICATION CASE for §8.7.4: Int branch fails (assigning "hello" to Int)
  ;; → `with-speculative-rollback` calls `record-assumption-retraction` (writes
  ;; to cell-13) → BSP outer-loop's value-tier processes process-retraction
  ;; AFTER S0 quiescence → restart-from-outer-loop → S0 fires again with
  ;; retracted bits filtered out via worldview → String branch succeeds.
  ;;
  ;; If S(-1) post-S0 timing is wrong (worldview-filtering doesn't hide stale
  ;; entries from the failed Int branch), the String branch elaboration could:
  ;;   - Pick up contaminating type information from the retracted Int hyp
  ;;   - Produce wrong final type for `x` (e.g., type-top contradiction)
  ;;   - Fail entirely with "type mismatch" error
  ;; Expected: `"hello"` value with String component of union type retained.
  (check-parity-equal? 'orchestration-union-with-retraction
                       "(ns t) (def x : <Int | String> := \"hello\") x"
                       #:expected "hello"))

(parity-test 'orchestration-union-flipped-with-retraction "PPN 4C 2A.c"
             "(ns t) (def x : <String | Int> := 42) x"
  ;; Symmetric variant of above: union order flipped so left branch is String
  ;; (fails for value 42) and right branch is Int (succeeds). Verifies the
  ;; retraction path doesn't have a left/right asymmetry. Together with the
  ;; pair above, this triangulates the BSP outer-loop's value-tier behavior
  ;; under retraction: works for both branch orderings, both successful and
  ;; retracted cases.
  (check-parity-equal? 'orchestration-union-flipped-with-retraction
                       "(ns t) (def x : <String | Int> := 42) x"
                       #:expected '42))

;; ========================================
;; PPN 4C 3A.c.3-R7 (2026-05-22) — union-inhabitation parity axis
;; ========================================
;;
;; Per addendum §9.3.5.5 Decision 2 (D' resolution: 4 active axes + 1
;; skip-gated) and §9.3.7 R7 mini-design. Validates the on-network
;; mechanism's user-facing behavior end-to-end:
;;
;;   R7's inline-emit at type-map-write detects union → emits cell-15
;;   request → process-fork-on-union handler decomposes via N branch
;;   propagators wrapped at per-branch worldview → contradictions
;;   narrow worldview-cache via S(-1) per 3A.b → surviving branches'
;;   bits remain → classifier PRESERVED as the original union
;;
;; Non-committing semantics: this is the LOAD-BEARING property. A sexp
;; first-success commit would return the value with the FIRST branch's
;; type only — narrowing the classifier away from the union. The R7
;; mechanism preserves the union as the classifier (only contradicted
;; branches narrow; multi-success branches coexist).
;;
;; Axes:
;;   - preserved:      single-success branch; classifier retained
;;   - flipped:        branch-order symmetry (left-fail-right-succeed)
;;   - multi-success:  LOAD-BEARING DISCRIMINATOR — sexp first-success
;;                     would FAIL this axis (narrows to first branch)
;;   - all-fail:       exhaustion produces type error
;;   - narrowing:      skip-gated → PPN Track 5 (occurrence typing)

(parity-test 'union-inhabitation-preserved "PPN 4C 3A.c.3-R7"
             "(ns t) (def x : <Int | String> := 42) x"
  ;; Int branch succeeds; non-committing preserves classifier as union.
  ;; Discriminating: a sexp first-success commit returns "42 : Int" only;
  ;; this axis requires "Int | String" substring to be present in the
  ;; pretty-printed type annotation.
  (check-parity-equal? 'union-inhabitation-preserved
                       "(ns t) (def x : <Int | String> := 42) x"
                       #:expected '42
                       #:expected-type "Int | String"))

(parity-test 'union-inhabitation-flipped "PPN 4C 3A.c.3-R7"
             "(ns t) (def x : <String | Int> := 42) x"
  ;; Branch-order symmetry: left-fail-right-succeed produces same shape.
  ;; pp-expr preserves SOURCE ORDER (pretty-print.rkt:632-633 emits
  ;; "~a | ~a" without sorting); expected type substring matches input
  ;; order "String | Int".
  (check-parity-equal? 'union-inhabitation-flipped
                       "(ns t) (def x : <String | Int> := 42) x"
                       #:expected '42
                       #:expected-type "String | Int"))

(parity-test 'union-inhabitation-multi-success "PPN 4C 3A.c.3-R7"
             "(ns t) (def x : <Nat | Int> := 0N) x"
  ;; LOAD-BEARING DISCRIMINATOR per §9.3.5.5. Value 0N is BOTH Nat (direct
  ;; literal) AND Int (via subtype Nat <: Int — established at SRE Track 2H).
  ;; Under R7's non-committing semantics, both branches succeed AND the
  ;; classifier remains "Nat | Int" (neither branch narrows). A sexp
  ;; first-success commit returns "0N : Nat" only — FAILS the "Nat | Int"
  ;; substring match. This axis is what proves on-network non-committing
  ;; vs any first-success-commit alternative.
  (check-parity-equal? 'union-inhabitation-multi-success
                       "(ns t) (def x : <Nat | Int> := 0N) x"
                       #:expected '0N
                       #:expected-type "Nat | Int"))

(parity-test 'union-inhabitation-all-fail "PPN 4C 3A.c.3-R7"
             "(ns t) (def x : <Int | Bool> := \"hello\") x"
  ;; All branches contradict ("hello" is neither Int nor Bool). Under R7's
  ;; non-committing semantics, both branch propagators write contradiction
  ;; sentinels; worldview-cache narrows away both branch bits via S(-1)
  ;; (3A.b's process-fork-contradiction); union exhaustion produces an
  ;; error via typing-errors.rkt:78 (the path that stays alive per
  ;; §9.3.5.4; Parent Phase 4 owns its retirement). x's def doesn't
  ;; complete; trailing reference surfaces as unbound-variable error
  ;; (run-ns-last returns the LAST expression's result; union-exhaustion
  ;; error appears earlier in the stream but is not the final result).
  ;;
  ;; The unbound-variable result is the downstream symptom of failed def
  ;; — IS the parity-test-observable proof that union exhaustion happened.
  ;; For direct union-exhaustion error-shape testing, see
  ;; test-union-types-atms.rkt mechanism tests (which assert on cell-16
  ;; narrowing + worldview-cache state directly, not surface result).
  (check-parity-equal? 'union-inhabitation-all-fail
                       "(ns t) (def x : <Int | Bool> := \"hello\") x"
                       #:expected "Unbound variable"))

;; ========================================
;; PPN Track 5 (occurrence typing) — narrowing axis (skip-gated)
;; ========================================
;;
;; Originally framed as `union-narrow-by-constraint` at Phase 10. Per
;; §9.3.5.5 Decision 2 reframing: narrowing of a union to a single
;; component via constraint propagation (`[int+ x 1]` constraining x to
;; Int when x : <Int | String>) IS occurrence typing — PPN Track 5
;; territory, NOT Phase 3A.c scope. The skip-gated entry preserves the
;; intent and points to the proper track for resurrection.

(parity-test-skip 'union-inhabitation-narrowing "PPN Track 5 (occurrence typing)"
                  "let x := (the <Int | String> 0) in [int+ x 1]"
  (check-parity-equal? 'union-inhabitation-narrowing
                       "let x := (the <Int | String> 0) in [int+ x 1]"
                       #:expected '1))

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

#lang racket/base

;;;
;;; test-punify-integration.rkt — Integration tests with current-punify-enabled? = #t
;;;
;;; Exercises the cell-tree code paths in System 1 (type-level unification,
;;; punify-dispatch-pi/binder/sub).
;;;
;;; Motivated by PUnify PIR §3, §9.3, §15.2: ZERO integration tests exercise
;;; the toggle-on path. This is the highest-risk gap identified in the PIR.
;;; Track 7's PIR-driven testing found the S(-1) retraction bug — same pattern.
;;;
;;; Pattern: Shared fixture from test-unify-propagator.rkt, with
;;; current-punify-enabled? = #t in the run helper's parameterize block.
;;;
;;; NOTE: Solver-env (System 2) tests are in test-relational-e2e.rkt.
;;; The solver uses WS-mode relational syntax (defr with || rows) which
;;; requires process-file, not process-string. Testing the cell-based solver
;;; path with punify ON requires adding the toggle to the e2e test harness.
;;;

(require rackunit
         racket/list
         racket/port
         "test-support.rkt"
         "../syntax.rkt"
         "../macros.rkt"
         "../errors.rkt"
         "../prelude.rkt"
         "../metavar-store.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         (only-in "../ctor-registry.rkt" current-punify-enabled?)
         "../elaborator-network.rkt"
         "../mult-lattice.rkt"
         "../champ.rkt"
         "../type-lattice.rkt")

;; ========================================
;; Shared fixture: prelude loaded ONCE (toggle OFF during prelude load)
;; ========================================

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-preparse-reg
                shared-cap-reg)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-capability-registry prelude-capability-registry])
    (install-module-loader!)
    (process-string "(ns test-punify-integ)\n")
    (values (current-prelude-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-preparse-registry)
            (current-capability-registry))))

;; Run code with punify ENABLED
(define (run code)
  (parameterize ([current-prelude-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-preparse-registry shared-preparse-reg]
                 [current-capability-registry shared-cap-reg]
                 [current-lib-paths (list prelude-lib-dir)]
                 ;; THE KEY: enable punify cell-tree path
                 [current-punify-enabled? #t])
    (install-module-loader!)
    (process-string code)))

(define (run-last code)
  (define results (run code))
  (if (null? results) #f (last results)))

;; Run with punify OFF (for parity comparison)
(define (run-off code)
  (parameterize ([current-prelude-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-preparse-registry shared-preparse-reg]
                 [current-capability-registry shared-cap-reg]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-punify-enabled? #f])
    (install-module-loader!)
    (process-string code)))

(define (run-off-last code)
  (define results (run-off code))
  (if (null? results) #f (last results)))

;; ========================================
;; Suite 1: Parity — punify ON produces same results as OFF
;; ========================================

(test-case "parity: implicit arg solved via cell path"
  (define code "(ns t) (def id : <{A : Type} -> (a : A) -> A> [fn [x] x]) [id 0N]")
  (define on-result (run-last code))
  (define off-result (run-off-last code))
  (check-false (prologos-error? on-result))
  (check-false (prologos-error? off-result)))

(test-case "parity: type annotation matching"
  (define code "(ns t) (def x : Int := 42)")
  (check-false (prologos-error? (run-last code)))
  (check-false (prologos-error? (run-off-last code))))

(test-case "parity: polymorphic function application"
  (define code "(ns t) (def id [fn [x : Int] x]) [id 42]")
  (check-false (prologos-error? (run-last code))))

(test-case "parity: higher-order function type — Pi decomposition"
  (define code "(ns t) (def apply : <{A B : Type} -> (f : <A -> B>) -> (a : A) -> B> [fn [f x] [f x]]) [apply [fn [x : Int] x] 42]")
  (check-false (prologos-error? (run-last code))))

(test-case "parity: nested Pi — Pi of Pi"
  (define code "(ns t) (def compose : <{A B C : Type} -> (f : <B -> C>) -> (g : <A -> B>) -> (a : A) -> C> [fn [f g x] [f [g x]]]) [compose [fn [x : Int] x] [fn [x : Int] x] 42]")
  (check-false (prologos-error? (run-last code))))

(test-case "parity: option type"
  (define code "(ns t) (def x : [Option Int] := [some 42])")
  (check-false (prologos-error? (run-last code))))

(test-case "parity: trait method dispatch"
  (define code "(ns t) [+ 1 2]")
  (define on-result (run-last code))
  (check-false (prologos-error? on-result)))

(test-case "parity: check command"
  (define code "(ns t) (check [fn [x : Int] x] : <Int -> Int>)")
  (check-false (prologos-error? (run-last code))))

(test-case "parity: def with type inference"
  (define code "(ns t) (def x := 42) (def y := [int+ x 1])")
  (check-false (prologos-error? (run-last code))))

;; ========================================
;; Suite 1b: Previously-broken parity tests (FIXED)
;;
;; These tests were broken with punify ON due to missing solve-meta!
;; bridge in punify-dispatch-sub/pi/binder. Fixed by Phase -1:
;; punify-bridge-cell-solves! now triggers stratified resolution
;; after cell-level meta solves during quiescence.
;; ========================================

(test-case "parity: list head — implicit type arg with punify ON"
  ;; Was KNOWN-BUG: punify-dispatch-sub solved ?A at cell level
  ;; but never called solve-meta!, so trait resolution never fired.
  (define code "(ns t) [head '[1 2 3]]")
  (define on-result (run-last code))
  (define off-result (run-off-last code))
  (check-false (prologos-error? on-result))
  (check-false (prologos-error? off-result)))

(test-case "parity: map with lambda — prelude polymorphic dispatch ON"
  ;; Was KNOWN-BUG: same root cause as head — Seqable/Reducible trait
  ;; constraints need solve-meta! → stratified resolution to resolve.
  (define code "(ns t) [map [fn [x : Int] [int+ x 1]] '[1 2 3]]")
  (define on-result (run-last code))
  (check-false (prologos-error? on-result)))

;; ========================================
;; Suite 1c: Fixture-gap tests (fail with BOTH ON and OFF)
;;
;; These were initially classified as KNOWN-BUG punify tests but
;; actually fail regardless of the toggle. They're fixture issues:
;; Pair/vnil are not in the shared test prelude env; match [some 42]
;; has a separate parsing issue with the pattern syntax in sexp mode.
;; Kept as regression canaries — if they start passing, something changed.
;; ========================================

(test-case "fixture-gap: pair type — errors both ON and OFF"
  (define code "(ns t) (def p : [Pair Int Bool] := [pair 42 true])")
  ;; Fails both ways — Pair/pair not in prelude fixture
  (check-true (prologos-error? (run-last code)))
  (check-true (prologos-error? (run-off-last code))))

(test-case "fixture-gap: option match — errors both ON and OFF"
  (define code "(ns t) (match [some 42] | [some x] -> x | none -> 0)")
  ;; Fails both ways — sexp-mode match syntax issue
  (check-true (prologos-error? (run-last code)))
  (check-true (prologos-error? (run-off-last code))))

(test-case "fixture-gap: Vec type — errors both ON and OFF"
  (define code "(ns t) (def v : [Vec Int 0N] := vnil)")
  ;; Fails both ways — vnil not in prelude fixture
  (check-true (prologos-error? (run-last code)))
  (check-true (prologos-error? (run-off-last code))))

(test-case "parity: Result type — compound constructor"
  (define code "(ns t) (def x : [Result Int String] := [ok 42])")
  (check-false (prologos-error? (run-last code))))

;; ========================================
;; Suite 2: Contradiction detection with punify ON
;; ========================================

(test-case "contradiction: type mismatch — Int ≠ Bool"
  (define code "(ns t) (def f [fn [x : Int] x]) [f true]")
  (define result (run-last code))
  (check-true (prologos-error? result)))

(test-case "contradiction: type mismatch — Int ≠ String"
  (define code "(ns t) (def x : Int := \"hello\")")
  (define result (run-last code))
  (check-true (prologos-error? result)))

(test-case "contradiction: union exhaustion — <Int | Bool> vs String"
  (define code "(ns t) (def x : <Int | Bool> := \"hello\")")
  (define result (run-last code))
  (check-true (prologos-error? result)))

(test-case "contradiction: Pi domain mismatch"
  (define code "(ns t) (def f : <Int -> Int> [fn [x : Bool] 0])")
  (define result (run-last code))
  (check-true (prologos-error? result)))

(test-case "contradiction: result type mismatch"
  (define code "(ns t) (def f : <Int -> Bool> [fn [x] [int+ x 1]])")
  (define result (run-last code))
  (check-true (prologos-error? result)))

(test-case "contradiction: arity mismatch"
  (define code "(ns t) (def f [fn [x : Int] x]) [f 1 2]")
  (define result (run-last code))
  (check-true (prologos-error? result)))

;; ========================================
;; Suite 3: Cell-tree decomposition exercises
;; ========================================

(test-case "decomp: polymorphic identity — flex-rigid cell write"
  ;; Forces ?A = Int through cell-write + propagation
  (define code "(ns t) (def id : <{A : Type} -> A -> A> [fn [x] x]) (check [id 42] : Int)")
  (check-false (prologos-error? (run-last code))))

(test-case "decomp: multiple implicit args — fan-in"
  (define code "(ns t) (def const : <{A B : Type} -> A -> B -> A> [fn [x y] x]) [const 42 true]")
  (check-false (prologos-error? (run-last code))))

(test-case "decomp: nested option — Option (Option Int)"
  (define code "(ns t) (def x : [Option [Option Int]] := [some [some 42]])")
  (check-false (prologos-error? (run-last code))))

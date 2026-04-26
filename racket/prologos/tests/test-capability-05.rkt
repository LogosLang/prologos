#lang racket/base

;;;
;;; Tests for Capabilities as Types — Phase 5: Capability Inference via Propagator Network
;;; Tests transitive capability closure computation, provenance tracking,
;;; authority root verification, and REPL commands.
;;;

(require rackunit
         racket/list
         racket/set
         racket/string
         "test-support.rkt"
         "../macros.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../source-location.rkt"
         "../surface-syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../pretty-print.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../multi-dispatch.rkt"
         "../capability-inference.rkt")

;; ========================================
;; Shared Fixture (modules loaded once)
;; ========================================

(define shared-preamble
  "(ns test-cap5)")

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-capability-reg
                shared-subtype-reg)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-multi-defn-registry (current-multi-defn-registry)]
                 [current-spec-store (hasheq)]
                 [current-capability-registry prelude-capability-registry])
    (install-module-loader!)
    (process-string shared-preamble)
    (values (global-env-snapshot)  ;; Phase 3a: merge both layers
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-capability-registry)
            (current-subtype-registry))))

;; Helper: run code and return list of result strings.
(define (run s)
  (parameterize ([current-prelude-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-capability-registry shared-capability-reg]
                 [current-subtype-registry shared-subtype-reg])
    (process-string s)))

(define (run-last s) (last (run s)))

;; ========================================
;; Unit Tests: CapabilitySet Lattice
;; ========================================

(test-case "lattice/bot-is-empty"
  (check-true (set-empty? (cap-set-members cap-set-bot))))

(test-case "lattice/join-union"
  (define a (cap-set (set (bare-cap 'ReadCap))))
  (define b (cap-set (set (bare-cap 'WriteCap))))
  (define j (cap-set-join a b))
  (check-equal? (set-count (cap-set-members j)) 2)
  (check-true (closure-has-cap-name? (cap-set-members j) 'ReadCap))
  (check-true (closure-has-cap-name? (cap-set-members j) 'WriteCap)))

(test-case "lattice/join-idempotent"
  (define a (cap-set (set (bare-cap 'ReadCap) (bare-cap 'WriteCap))))
  (define j (cap-set-join a a))
  (check-equal? (cap-set-members j) (cap-set-members a)))

(test-case "lattice/subsumes-exact"
  (define avail (cap-set (set (bare-cap 'ReadCap) (bare-cap 'WriteCap))))
  (define req (cap-set (set (bare-cap 'ReadCap))))
  (check-true (cap-set-subsumes? avail req)))

(test-case "lattice/subsumes-subtype"
  ;; ReadCap <: FsCap, so FsCap available should subsume ReadCap required
  (parameterize ([current-subtype-registry shared-subtype-reg])
    (define avail (cap-set (set (bare-cap 'FsCap))))
    (define req (cap-set (set (bare-cap 'ReadCap))))
    (check-true (cap-set-subsumes? avail req))))

(test-case "lattice/not-subsumes"
  ;; FsCap is NOT a subtype of ReadCap
  (parameterize ([current-subtype-registry shared-subtype-reg])
    (define avail (cap-set (set (bare-cap 'ReadCap))))
    (define req (cap-set (set (bare-cap 'FsCap))))
    (check-false (cap-set-subsumes? avail req))))

;; ========================================
;; Unit Tests: Expression Analysis
;; ========================================

(test-case "extract-fvars/simple"
  (define expr (expr-app (expr-fvar 'foo) (expr-fvar 'bar)))
  (define names (extract-fvar-names expr))
  (check-true (set-member? names 'foo))
  (check-true (set-member? names 'bar)))

(test-case "extract-fvars/nested"
  (define expr (expr-lam 'mw (expr-Nat)
                 (expr-app (expr-fvar 'add) (expr-bvar 0))))
  (define names (extract-fvar-names expr))
  (check-true (set-member? names 'add))
  (check-false (set-member? names 'x)))  ;; bvars don't appear

(test-case "extract-caps/pi-chain"
  (parameterize ([current-capability-registry shared-capability-reg])
    (define ty (expr-Pi 'm0 (expr-fvar 'ReadCap)
                 (expr-Pi 'mw (expr-fvar 'Nat)
                   (expr-fvar 'Nat))))
    (define caps (extract-capability-requirements ty))
    (check-true (closure-has-cap-name? caps 'ReadCap))
    (check-equal? (set-count caps) 1)))

(test-case "extract-caps/non-capability-m0"
  ;; A :0 Type binder is not a capability
  (parameterize ([current-capability-registry shared-capability-reg])
    (define ty (expr-Pi 'm0 (expr-Type 0)
                 (expr-Pi 'mw (expr-fvar 'Nat)
                   (expr-fvar 'Nat))))
    (define caps (extract-capability-requirements ty))
    (check-true (set-empty? caps))))

(test-case "extract-caps/multiple-caps"
  (parameterize ([current-capability-registry shared-capability-reg])
    (define ty (expr-Pi 'm0 (expr-fvar 'ReadCap)
                 (expr-Pi 'm0 (expr-fvar 'HttpCap)
                   (expr-Pi 'mw (expr-fvar 'Nat)
                     (expr-fvar 'Nat)))))
    (define caps (extract-capability-requirements ty))
    (check-equal? (set-count caps) 2)
    (check-true (closure-has-cap-name? caps 'ReadCap))
    (check-true (closure-has-cap-name? caps 'HttpCap))))

;; ========================================
;; Integration Tests: Inference Network
;; ========================================

(test-case "inference/pure-function"
  ;; A function with no capability requirements → empty closure
  (define result
    (run "(def pure-fn : (Pi (x :w Nat) Nat) := (fn (x :w Nat) x))"))
  (check-true (string? (last result)))
  (check-true (string-contains? (last result) "defined")))

(test-case "inference/cap-closure-pure"
  ;; cap-closure of a pure function shows "pure"
  (define result
    (run (string-append
          "(def my-id : (Pi (x :w Nat) Nat) := (fn (x :w Nat) x))\n"
          "(cap-closure my-id)")))
  (check-true (string? (last result)))
  (check-true (string-contains? (last result) "pure")))

(test-case "inference/cap-closure-direct"
  ;; cap-closure of a function that directly declares ReadCap
  (define result
    (run (string-append
          "(def read-fn : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
          " := (fn (c :0 ReadCap) (fn (x :w Nat) x)))\n"
          "(cap-closure read-fn)")))
  (check-true (string? (last result)))
  (check-true (string-contains? (last result) "ReadCap")))

(test-case "inference/cap-closure-transitive"
  ;; f calls g which declares ReadCap → f's closure includes ReadCap
  (define result
    (run (string-append
          "(def g-read : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
          " := (fn (c :0 ReadCap) (fn (x :w Nat) x)))\n"
          "(def f-caller : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
          " := (fn (c :0 ReadCap) (fn (x :w Nat) (g-read x))))\n"
          "(cap-closure f-caller)")))
  (check-true (string? (last result)))
  (check-true (string-contains? (last result) "ReadCap")))

(test-case "inference/cap-audit-direct"
  ;; cap-audit for a function that directly declares the capability
  (define result
    (run (string-append
          "(def audit-fn : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
          " := (fn (c :0 ReadCap) (fn (x :w Nat) x)))\n"
          "(cap-audit audit-fn ReadCap)")))
  (check-true (string? (last result)))
  (check-true (string-contains? (last result) "directly declares")))

(test-case "inference/cap-audit-not-required"
  ;; cap-audit for a capability the function doesn't require
  (define result
    (run (string-append
          "(def pure-fn2 : (Pi (x :w Nat) Nat) := (fn (x :w Nat) x))\n"
          "(cap-audit pure-fn2 ReadCap)")))
  (check-true (string? (last result)))
  (check-true (string-contains? (last result) "does not require")))

;; ========================================
;; Integration Tests: Subsumption
;; ========================================

(test-case "subsumption/sufficient"
  ;; Function declares FsCap, closure needs ReadCap — FsCap subsumes ReadCap
  (parameterize ([current-subtype-registry shared-subtype-reg]
                 [current-capability-registry shared-capability-reg])
    (define avail (cap-set (set (bare-cap 'FsCap))))
    (define req (cap-set (set (bare-cap 'ReadCap))))
    (check-true (cap-set-subsumes? avail req))))

(test-case "subsumption/insufficient"
  ;; Function declares ReadCap, needs FsCap — insufficient
  (parameterize ([current-subtype-registry shared-subtype-reg]
                 [current-capability-registry shared-capability-reg])
    (define avail (cap-set (set (bare-cap 'ReadCap))))
    (define req (cap-set (set (bare-cap 'FsCap))))
    (check-false (cap-set-subsumes? avail req))))

;; ========================================
;; Parse Tests: New REPL Commands
;; ========================================

(test-case "parse/cap-closure"
  (define result (parse-datum '(cap-closure foo)))
  (check-true (surf-cap-closure? result))
  (check-equal? (surf-cap-closure-name result) 'foo))

(test-case "parse/cap-audit"
  (define result (parse-datum '(cap-audit foo ReadCap)))
  (check-true (surf-cap-audit? result))
  (check-equal? (surf-cap-audit-name result) 'foo)
  (check-equal? (surf-cap-audit-cap-name result) 'ReadCap))

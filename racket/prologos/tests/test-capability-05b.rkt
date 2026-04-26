#lang racket/base

;;;
;;; Tests for Capabilities as Types — Phase 5 (deferred): ATMS Provenance
;;; Tests that capability audit trails use ATMS-backed provenance roots,
;;; including multi-root scenarios, transitive chains, and diamond call graphs.
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
         "../capability-inference.rkt"
         "../atms.rkt")

;; ========================================
;; Shared Fixture (modules loaded once)
;; ========================================

(define shared-preamble
  "(ns test-cap5b)")

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

;; Helper: run code and capture global-env, then run inference.
(define (run-and-infer s)
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
    (process-string s)
    (run-capability-inference)))

;; ========================================
;; Unit Tests: Provenance Roots
;; ========================================

(test-case "provenance/direct-declarer-is-own-root"
  ;; A function that directly declares ReadCap should be its own root
  (define result
    (run-and-infer
     "(def h : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))
        := (fn (c :0 ReadCap) (fn (x :w Nat) x)))"))
  (define roots (capability-audit-roots result 'h 'ReadCap))
  (check-true (set-member? roots 'h) "h should be its own root"))

(test-case "provenance/transitive-root"
  ;; f calls g which declares ReadCap → f's root for ReadCap should be g
  (define result
    (run-and-infer
     (string-append
      "(def g : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 ReadCap) (fn (x :w Nat) x)))\n"
      "(def f : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 ReadCap) (fn (x :w Nat) (g x))))")))
  (define roots (capability-audit-roots result 'f 'ReadCap))
  ;; f should have both f (if f declares it) and g as roots
  ;; f also declares ReadCap in its type, so both f and g are roots
  (check-true (set-member? roots 'f) "f declares ReadCap directly")
  (check-true (set-member? roots 'g) "g declares ReadCap and f calls g"))

(test-case "provenance/chain-root-propagation"
  ;; Chain: f → g → h, only h declares ReadCap
  ;; f and g should both have h as root
  (define result
    (run-and-infer
     (string-append
      "(def h : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 ReadCap) (fn (x :w Nat) x)))\n"
      "(def g2 : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 ReadCap) (fn (x :w Nat) (h x))))\n"
      "(def f2 : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 ReadCap) (fn (x :w Nat) (g2 x))))")))
  ;; f2 should have h as a root (the chain's ultimate declarer)
  (define f-roots (capability-audit-roots result 'f2 'ReadCap))
  (check-true (set-member? f-roots 'h) "h is the chain's root for f2")
  ;; g2 should also have h as a root
  (define g-roots (capability-audit-roots result 'g2 'ReadCap))
  (check-true (set-member? g-roots 'h) "h is the chain's root for g2"))

(test-case "provenance/diamond-call-graph"
  ;; Diamond: f → g1 → h, f → g2 → h, only h declares ReadCap
  ;; f should have h as root via both paths
  (define result
    (run-and-infer
     (string-append
      "(def hd : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 ReadCap) (fn (x :w Nat) x)))\n"
      "(def g1d : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 ReadCap) (fn (x :w Nat) (hd x))))\n"
      "(def g2d : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 ReadCap) (fn (x :w Nat) (hd x))))\n"
      "(def fd : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 ReadCap) (fn (x :w Nat) (g1d (g2d x)))))")))
  (define roots (capability-audit-roots result 'fd 'ReadCap))
  (check-true (set-member? roots 'hd) "hd is the root in the diamond"))

(test-case "provenance/multiple-roots"
  ;; f → g1 (declares ReadCap), f → g2 (also declares ReadCap)
  ;; f should have both g1 and g2 as roots
  (define result
    (run-and-infer
     (string-append
      "(def mr1 : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 ReadCap) (fn (x :w Nat) x)))\n"
      "(def mr2 : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 ReadCap) (fn (x :w Nat) x)))\n"
      "(def mr-caller : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 ReadCap) (fn (x :w Nat) (mr1 (mr2 x)))))")))
  (define roots (capability-audit-roots result 'mr-caller 'ReadCap))
  (check-true (set-member? roots 'mr1) "mr1 is a root")
  (check-true (set-member? roots 'mr2) "mr2 is a root"))

(test-case "provenance/pure-function-no-roots"
  ;; Pure function has no roots for any capability
  (define result
    (run-and-infer
     "(def pure-f : (Pi (x :w Nat) Nat) := (fn (x :w Nat) x))"))
  (define roots (capability-audit-roots result 'pure-f 'ReadCap))
  (check-true (set-empty? roots) "pure function has no ReadCap roots"))

;; ========================================
;; Unit Tests: ATMS Structure
;; ========================================

(test-case "atms/assumptions-created-for-direct-declarations"
  ;; ATMS should have assumptions for direct declarations
  (define result
    (run-and-infer
     "(def atms-fn : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))
        := (fn (c :0 ReadCap) (fn (x :w Nat) x)))"))
  (define prov-atms (cap-inference-result-provenance-atms result))
  ;; The solver-state should have at least one assumption
  (check-true (> (hash-count (solver-state-assumptions prov-atms)) 0)
              "ATMS should have assumptions"))

(test-case "atms/supported-values-for-direct-declarer"
  ;; Solver cell for (direct-declarer, cap) should have a value
  (define result
    (run-and-infer
     "(def sv-fn : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))
        := (fn (c :0 ReadCap) (fn (x :w Nat) x)))"))
  (define prov-atms (cap-inference-result-provenance-atms result))
  ;; Cell keys are interned symbols via atms-cell-key
  (define cell-k (atms-cell-key 'sv-fn 'ReadCap))
  (define val (solver-state-read-cell prov-atms cell-k))
  (check-true (not (eq? val 'bot))
              "Direct declarer should have a cell value"))

(test-case "atms/supported-values-for-transitive"
  ;; Solver cell for (caller, cap) should also have a value
  ;; when the cap is inherited transitively
  (define result
    (run-and-infer
     (string-append
      "(def sv-callee : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 ReadCap) (fn (x :w Nat) x)))\n"
      "(def sv-caller : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 ReadCap) (fn (x :w Nat) (sv-callee x))))")))
  (define prov-atms (cap-inference-result-provenance-atms result))
  (define cell-k (atms-cell-key 'sv-caller 'ReadCap))
  (define val (solver-state-read-cell prov-atms cell-k))
  (check-true (not (eq? val 'bot))
              "Transitive inheritor should have a cell value"))

(test-case "atms/support-set-traces-to-root"
  ;; The provenance roots for a transitive inheritor should include
  ;; the root declarer
  (define result
    (run-and-infer
     (string-append
      "(def root-fn : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 ReadCap) (fn (x :w Nat) x)))\n"
      "(def mid-fn : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 ReadCap) (fn (x :w Nat) (root-fn x))))\n"
      "(def top-fn : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 ReadCap) (fn (x :w Nat) (mid-fn x))))")))
  (define prov-atms (cap-inference-result-provenance-atms result))
  ;; Verify cell has a value via solver-state
  (define cell-k (atms-cell-key 'top-fn 'ReadCap))
  (define val (solver-state-read-cell prov-atms cell-k))
  (check-true (not (eq? val 'bot))
              "top-fn should have a cell value")
  ;; Check provenance roots directly — root-fn should be listed
  (define prov-roots (cap-inference-result-provenance-roots result))
  (define top-fn-roots (hash-ref prov-roots (cons 'top-fn 'ReadCap)
                                 (lambda ()
                                   ;; Try qualified name
                                   (for/first ([(k v) (in-hash prov-roots)]
                                               #:when (and (pair? k)
                                                           (let ([s (symbol->string (car k))])
                                                             (string-suffix? s "top-fn"))
                                                           (eq? (cdr k) 'ReadCap)))
                                     v))))
  (check-true (and top-fn-roots
                   (for/or ([r (in-set top-fn-roots)])
                     (or (eq? r 'root-fn)
                         (let ([s (symbol->string r)])
                           (string-suffix? s "root-fn")))))
              "Provenance roots should trace back to root-fn"))

;; ========================================
;; Integration Tests: Audit Trail with ATMS
;; ========================================

(test-case "audit-trail/direct-declares-via-atms"
  ;; Same test as Phase 5, but now backed by ATMS
  (define result
    (run (string-append
          "(def at-direct : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
          " := (fn (c :0 ReadCap) (fn (x :w Nat) x)))\n"
          "(cap-audit at-direct ReadCap)")))
  (check-true (string-contains? (last result) "directly declares")))

(test-case "audit-trail/transitive-via-atms"
  ;; Transitive audit trail should show the call chain
  (define result
    (run (string-append
          "(def at-leaf : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
          " := (fn (c :0 ReadCap) (fn (x :w Nat) x)))\n"
          "(def at-mid : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
          " := (fn (c :0 ReadCap) (fn (x :w Nat) (at-leaf x))))\n"
          "(def at-top : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
          " := (fn (c :0 ReadCap) (fn (x :w Nat) (at-mid x))))\n"
          "(cap-audit at-top ReadCap)")))
  ;; at-top itself declares ReadCap, so it reports "directly declares"
  (check-true (string-contains? (last result) "directly declares")))

(test-case "audit-trail/non-declaring-transitive"
  ;; A function that doesn't declare cap but calls one that does
  ;; (no cap in its own type) would show the call chain.
  ;; Currently hard to test because our functions all declare caps in their type.
  ;; This test verifies the cap-audit format works.
  (define result
    (run (string-append
          "(def nr-pure : (Pi (x :w Nat) Nat) := (fn (x :w Nat) x))\n"
          "(cap-audit nr-pure ReadCap)")))
  (check-true (string-contains? (last result) "does not require")))

(test-case "audit-trail/multiple-caps"
  ;; Function with multiple capabilities — audit each separately
  (define result-read
    (run (string-append
          "(def mc-fn : (Pi (c1 :0 ReadCap) (Pi (c2 :0 HttpCap) (Pi (x :w Nat) Nat)))"
          " := (fn (c1 :0 ReadCap) (fn (c2 :0 HttpCap) (fn (x :w Nat) x))))\n"
          "(cap-audit mc-fn ReadCap)")))
  (define result-http
    (run (string-append
          "(def mc-fn2 : (Pi (c1 :0 ReadCap) (Pi (c2 :0 HttpCap) (Pi (x :w Nat) Nat)))"
          " := (fn (c1 :0 ReadCap) (fn (c2 :0 HttpCap) (fn (x :w Nat) x))))\n"
          "(cap-audit mc-fn2 HttpCap)")))
  (check-true (string-contains? (last result-read) "directly declares"))
  (check-true (string-contains? (last result-http) "directly declares")))

;; ========================================
;; Unit Tests: Authority Root Verification
;; ========================================

;; Helper: run code, capture env, then verify authority root
(define (run-and-verify root-name s)
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
    (process-string s)
    (verify-authority-root root-name)))

(test-case "authority-root/passes-when-declared-covers-closure"
  ;; main declares ReadCap, only calls functions needing ReadCap
  (define vresult
    (run-and-verify 'ar-main
     (string-append
      "(def ar-helper : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 ReadCap) (fn (x :w Nat) x)))\n"
      "(def ar-main : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 ReadCap) (fn (x :w Nat) (ar-helper x))))")))
  (check-true (authority-root-ok? vresult)
              "Subsumption should pass when declared = closure"))

(test-case "authority-root/passes-for-pure-function"
  ;; Pure function has empty closure → trivially passes
  (define vresult
    (run-and-verify 'ar-pure
     "(def ar-pure : (Pi (x :w Nat) Nat) := (fn (x :w Nat) x))"))
  (check-true (authority-root-ok? vresult)
              "Pure function always passes authority root check"))

(test-case "authority-root/passes-when-supertype-covers"
  ;; main declares FsCap, closure needs ReadCap, ReadCap <: FsCap → covered
  (define vresult
    (run-and-verify 'ar-super
     (string-append
      "(def ar-reader : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 ReadCap) (fn (x :w Nat) x)))\n"
      "(def ar-super : (Pi (c :0 FsCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 FsCap) (fn (x :w Nat) (ar-reader x))))")))
  (check-true (authority-root-ok? vresult)
              "FsCap should cover ReadCap via subtyping"))

(test-case "authority-root/fails-when-cap-not-declared"
  ;; Construct env directly: f declares ReadCap, g declares HttpCap, f calls g.
  ;; f's closure should be {ReadCap, HttpCap}, declared = {ReadCap}, missing = {HttpCap}.
  ;; (Bypasses elaborator because lexical resolution prevents this from type-checking.)
  (parameterize ([current-capability-registry shared-capability-reg]
                 [current-subtype-registry shared-subtype-reg])
    (define g-type (expr-Pi 'm0 (expr-fvar 'HttpCap)
                     (expr-Pi 'mw (expr-fvar 'Nat) (expr-fvar 'Nat))))
    (define g-body (expr-lam 'mw #f (expr-lam 'mw #f (expr-fvar 'x))))
    (define f-type (expr-Pi 'm0 (expr-fvar 'ReadCap)
                     (expr-Pi 'mw (expr-fvar 'Nat) (expr-fvar 'Nat))))
    (define f-body (expr-lam 'mw #f
                     (expr-lam 'mw #f (expr-app (expr-fvar 'g) (expr-fvar 'x)))))
    (define env (hasheq 'f (cons f-type f-body)
                        'g (cons g-type g-body)))
    (define vresult (verify-authority-root 'f env))
    (check-true (authority-root-failure? vresult)
                "Should fail when closure contains uncovered capability")
    (check-true (closure-has-cap-name? (authority-root-failure-missing vresult) 'HttpCap)
                "HttpCap should be in missing set")))

(test-case "authority-root/failure-has-traces"
  ;; Chain: f → g → h, h declares HttpCap, f only declares ReadCap.
  ;; Failure should include traces with the call chain.
  (parameterize ([current-capability-registry shared-capability-reg]
                 [current-subtype-registry shared-subtype-reg])
    (define h-type (expr-Pi 'm0 (expr-fvar 'HttpCap)
                     (expr-Pi 'mw (expr-fvar 'Nat) (expr-fvar 'Nat))))
    (define h-body (expr-lam 'mw #f (expr-lam 'mw #f (expr-fvar 'x))))
    (define g-type (expr-Pi 'mw (expr-fvar 'Nat) (expr-fvar 'Nat)))
    (define g-body (expr-lam 'mw #f (expr-app (expr-fvar 'h) (expr-fvar 'x))))
    (define f-type (expr-Pi 'm0 (expr-fvar 'ReadCap)
                     (expr-Pi 'mw (expr-fvar 'Nat) (expr-fvar 'Nat))))
    (define f-body (expr-lam 'mw #f
                     (expr-lam 'mw #f (expr-app (expr-fvar 'g) (expr-fvar 'x)))))
    (define env (hasheq 'f (cons f-type f-body)
                        'g (cons g-type g-body)
                        'h (cons h-type h-body)))
    (define vresult (verify-authority-root 'f env))
    (check-true (authority-root-failure? vresult))
    (define traces (authority-root-failure-traces vresult))
    (check-true (pair? traces)
                "Failure should include traces for missing caps")
    ;; Each trace is (list cap-name trail)
    (define first-trace (first traces))
    (check-equal? (first first-trace) 'HttpCap
                  "Trace should identify HttpCap as missing")))

(test-case "authority-root/failure-declares-field-correct"
  ;; Verify the declared set in failure struct matches what's in the type
  (parameterize ([current-capability-registry shared-capability-reg]
                 [current-subtype-registry shared-subtype-reg])
    (define g-type (expr-Pi 'm0 (expr-fvar 'HttpCap)
                     (expr-Pi 'mw (expr-fvar 'Nat) (expr-fvar 'Nat))))
    (define g-body (expr-lam 'mw #f (expr-lam 'mw #f (expr-fvar 'x))))
    (define f-type (expr-Pi 'm0 (expr-fvar 'ReadCap)
                     (expr-Pi 'mw (expr-fvar 'Nat) (expr-fvar 'Nat))))
    (define f-body (expr-lam 'mw #f
                     (expr-lam 'mw #f (expr-app (expr-fvar 'g) (expr-fvar 'x)))))
    (define env (hasheq 'f (cons f-type f-body)
                        'g (cons g-type g-body)))
    (define vresult (verify-authority-root 'f env))
    (check-true (authority-root-failure? vresult))
    (check-true (closure-has-cap-name? (authority-root-failure-declared vresult) 'ReadCap)
                "Declared set should contain ReadCap")
    (check-false (closure-has-cap-name? (authority-root-failure-declared vresult) 'HttpCap)
                 "HttpCap should NOT be in declared set")))

(test-case "authority-root/multiple-missing-caps"
  ;; f declares nothing, calls g (ReadCap) and h (HttpCap)
  ;; Both should appear in missing set.
  (parameterize ([current-capability-registry shared-capability-reg]
                 [current-subtype-registry shared-subtype-reg])
    (define g-type (expr-Pi 'm0 (expr-fvar 'ReadCap)
                     (expr-Pi 'mw (expr-fvar 'Nat) (expr-fvar 'Nat))))
    (define g-body (expr-lam 'mw #f (expr-lam 'mw #f (expr-fvar 'x))))
    (define h-type (expr-Pi 'm0 (expr-fvar 'HttpCap)
                     (expr-Pi 'mw (expr-fvar 'Nat) (expr-fvar 'Nat))))
    (define h-body (expr-lam 'mw #f (expr-lam 'mw #f (expr-fvar 'x))))
    (define f-type (expr-Pi 'mw (expr-fvar 'Nat) (expr-fvar 'Nat)))
    (define f-body (expr-lam 'mw #f
                     (expr-app (expr-fvar 'g)
                       (expr-app (expr-fvar 'h) (expr-fvar 'x)))))
    (define env (hasheq 'f (cons f-type f-body)
                        'g (cons g-type g-body)
                        'h (cons h-type h-body)))
    (define vresult (verify-authority-root 'f env))
    (check-true (authority-root-failure? vresult))
    (define missing (authority-root-failure-missing vresult))
    (check-true (closure-has-cap-name? missing 'ReadCap) "ReadCap should be missing")
    (check-true (closure-has-cap-name? missing 'HttpCap) "HttpCap should be missing")))

;; ========================================
;; Integration Tests: cap-verify REPL Command
;; ========================================

(test-case "cap-verify/repl-passes"
  (define result
    (run (string-append
          "(def cv-helper : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
          " := (fn (c :0 ReadCap) (fn (x :w Nat) x)))\n"
          "(def cv-main : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
          " := (fn (c :0 ReadCap) (fn (x :w Nat) (cv-helper x))))\n"
          "(cap-verify cv-main)")))
  (check-true (string-contains? (last result) "verification passed")
              "cap-verify should report passed"))

(test-case "cap-verify/repl-fails-with-E2004-security-error"
  ;; Construct env directly with mismatched caps, then attempt process-string.
  ;; cv-fail declares ReadCap but calls cv-http (HttpCap).
  ;; run-post-compilation-inference! raises E2004 (security violation) because
  ;; cv-fail's closure includes HttpCap which is not covered by ReadCap.
  (define g-type (expr-Pi 'm0 (expr-fvar 'HttpCap)
                   (expr-Pi 'mw (expr-fvar 'Nat) (expr-fvar 'Nat))))
  (define g-body (expr-lam 'mw #f (expr-lam 'mw #f (expr-fvar 'x))))
  (define f-type (expr-Pi 'm0 (expr-fvar 'ReadCap)
                   (expr-Pi 'mw (expr-fvar 'Nat) (expr-fvar 'Nat))))
  (define f-body (expr-lam 'mw #f
                   (expr-lam 'mw #f (expr-app (expr-fvar 'cv-http) (expr-fvar 'x)))))
  ;; Inject into env, then run — should raise E2004 security error
  (define env-with-fns
    (hash-set (hash-set shared-global-env 'cv-http (cons g-type g-body))
              'cv-fail (cons f-type f-body)))
  (check-exn
   (lambda (e)
     (and (exn:fail? e)
          (string-contains? (exn-message e) "E2004")
          (string-contains? (exn-message e) "HttpCap")))
   (lambda ()
     (parameterize ([current-prelude-env env-with-fns]
                    [current-ns-context shared-ns-context]
                    [current-module-registry shared-module-reg]
                    [current-lib-paths (list prelude-lib-dir)]
                    [current-preparse-registry (current-preparse-registry)]
                    [current-trait-registry shared-trait-reg]
                    [current-impl-registry shared-impl-reg]
                    [current-param-impl-registry shared-param-impl-reg]
                    [current-capability-registry shared-capability-reg]
                    [current-subtype-registry shared-subtype-reg])
       (process-string "(cap-verify cv-fail)")))
   "Underdeclared authority root should raise E2004 security error"))

(test-case "cap-verify/repl-pure-function-passes"
  (define result
    (run (string-append
          "(def cv-pure : (Pi (x :w Nat) Nat) := (fn (x :w Nat) x))\n"
          "(cap-verify cv-pure)")))
  (check-true (string-contains? (last result) "verification passed")
              "Pure function should pass"))

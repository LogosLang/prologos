#lang racket/base

;;;
;;; Tests for Capabilities as Types — Phase 8: Cross-Network Interfacing
;;; Tests α/γ abstraction functions, cross-domain network construction,
;;; overdeclared capability detection, and cap-bridge REPL command.
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
         "../cap-type-bridge.rkt"
         "../type-lattice.rkt"
         "../propagator.rkt")

;; ========================================
;; Shared Fixture (modules loaded once)
;; ========================================

(define shared-preamble
  "(ns test-cap8)")

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-capability-reg
                shared-subtype-reg)
  (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
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
  (parameterize ([current-global-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-capability-registry shared-capability-reg]
                 [current-subtype-registry shared-subtype-reg])
    (process-string s)))

(define (run-last s) (last (run s)))

;; Helper: run code, capture env, then run cross-domain bridge.
(define (run-and-bridge s)
  (parameterize ([current-global-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-capability-registry shared-capability-reg]
                 [current-subtype-registry shared-subtype-reg])
    (process-string s)
    (build-cross-domain-network)))

;; ========================================
;; Phase 8a: α/γ Unit Tests
;; ========================================

(test-case "alpha/bare-capability-fvar"
  ;; type-to-cap-set on a bare capability fvar → singleton cap-set
  (parameterize ([current-capability-registry shared-capability-reg])
    (define result (type-to-cap-set (expr-fvar 'ReadCap)))
    (check-true (closure-has-cap-name? (cap-set-members result) 'ReadCap))
    (check-equal? (set-count (cap-set-members result)) 1)))

(test-case "alpha/non-capability-fvar"
  ;; type-to-cap-set on a non-capability fvar → empty
  (parameterize ([current-capability-registry shared-capability-reg])
    (define result (type-to-cap-set (expr-fvar 'Nat)))
    (check-true (set-empty? (cap-set-members result)))))

(test-case "alpha/union-of-capabilities"
  ;; type-to-cap-set on (ReadCap | WriteCap) → {ReadCap, WriteCap}
  (parameterize ([current-capability-registry shared-capability-reg])
    (define result
      (type-to-cap-set (expr-union (expr-fvar 'ReadCap) (expr-fvar 'WriteCap))))
    (check-true (closure-has-cap-name? (cap-set-members result) 'ReadCap))
    (check-true (closure-has-cap-name? (cap-set-members result) 'WriteCap))
    (check-equal? (set-count (cap-set-members result)) 2)))

(test-case "alpha/pi-with-capability-domain"
  ;; type-to-cap-set on (Pi :0 ReadCap String) → {ReadCap}
  (parameterize ([current-capability-registry shared-capability-reg])
    (define result
      (type-to-cap-set (expr-Pi 'm0 (expr-fvar 'ReadCap) (expr-fvar 'String))))
    (check-true (closure-has-cap-name? (cap-set-members result) 'ReadCap))
    (check-equal? (set-count (cap-set-members result)) 1)))

(test-case "alpha/type-bot-gives-empty"
  ;; type-to-cap-set on type-bot → empty
  (parameterize ([current-capability-registry shared-capability-reg])
    (define result (type-to-cap-set type-bot))
    (check-true (set-empty? (cap-set-members result)))))

(test-case "gamma/empty-gives-type-bot"
  ;; cap-set-to-type on empty → type-bot
  (define result (cap-set-to-type cap-set-bot))
  (check-true (type-bot? result)))

(test-case "gamma/singleton-gives-fvar"
  ;; cap-set-to-type on {ReadCap} → (expr-fvar 'ReadCap)
  (define result (cap-set-to-type (cap-set (set (bare-cap 'ReadCap)))))
  (check-true (expr-fvar? result))
  (check-equal? (expr-fvar-name result) 'ReadCap))

(test-case "gamma/multi-gives-union"
  ;; cap-set-to-type on {ReadCap, WriteCap} → union
  (define result (cap-set-to-type (cap-set (set (bare-cap 'ReadCap) (bare-cap 'WriteCap)))))
  (check-true (expr-union? result)))

(test-case "roundtrip/alpha-gamma-alpha"
  ;; α(γ(α(T))) = α(T) for union type
  (parameterize ([current-capability-registry shared-capability-reg])
    (define t (expr-union (expr-fvar 'ReadCap) (expr-fvar 'WriteCap)))
    (define alpha-t (type-to-cap-set t))
    (define gamma-alpha-t (cap-set-to-type alpha-t))
    (define alpha-gamma-alpha-t (type-to-cap-set gamma-alpha-t))
    (check-equal? (cap-set-members alpha-t) (cap-set-members alpha-gamma-alpha-t))))

(test-case "roundtrip/gamma-alpha-gamma"
  ;; γ(α(γ(S))) = γ(S) for cap-set — structural equality on types
  (parameterize ([current-capability-registry shared-capability-reg])
    (define s (cap-set (set (bare-cap 'ReadCap) (bare-cap 'WriteCap))))
    (define gamma-s (cap-set-to-type s))
    (define alpha-gamma-s (type-to-cap-set gamma-s))
    (define gamma-alpha-gamma-s (cap-set-to-type alpha-gamma-s))
    ;; Both should produce the same union structure
    (check-equal? gamma-s gamma-alpha-gamma-s)))

;; ========================================
;; Phase 8b: Cross-Domain Network Integration Tests
;; ========================================

;; Helper: find a key in a hash by suffix match (for namespace-qualified names)
(define (find-key-by-suffix h suffix)
  (for/first ([(k _) (in-hash h)]
              #:when (regexp-match? (regexp (string-append (regexp-quote suffix) "$"))
                                    (symbol->string k)))
    k))

(test-case "bridge/call-chain-propagation"
  ;; f calls g, g declares ReadCap. After quiescence,
  ;; f's cap closure should include ReadCap.
  (define result
    (run-and-bridge
     (string-append
      "(def g8 : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 ReadCap) (fn (x :w Nat) x)))\n"
      "(def f8 : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 ReadCap) (fn (x :w Nat) (g8 x))))")))
  (define cap-closures (cap-type-bridge-result-cap-closures result))
  (define f-key (find-key-by-suffix cap-closures "f8"))
  (check-true (and f-key (closure-has-cap-name? (hash-ref cap-closures f-key (set)) 'ReadCap))
              "f8 should have ReadCap in its closure"))

(test-case "bridge/overdeclared-detection"
  ;; Function declares both ReadCap and HttpCap but only calls something
  ;; requiring ReadCap → HttpCap is overdeclared.
  ;; We construct this directly since well-typed programs use all declared caps.
  (parameterize ([current-capability-registry shared-capability-reg]
                 [current-subtype-registry shared-subtype-reg])
    ;; Build env: f declares {ReadCap, HttpCap}, g declares {ReadCap}, f calls g
    (define f-type
      (expr-Pi 'm0 (expr-fvar 'ReadCap)
        (expr-Pi 'm0 (expr-fvar 'HttpCap)
          (expr-Pi 'mw (expr-fvar 'Nat) (expr-fvar 'Nat)))))
    (define g-type
      (expr-Pi 'm0 (expr-fvar 'ReadCap)
        (expr-Pi 'mw (expr-fvar 'Nat) (expr-fvar 'Nat))))
    (define g-body (expr-lam 'mw (expr-fvar 'Nat) (expr-bvar 0)))
    ;; f calls g (via fvar)
    (define f-body
      (expr-lam 'm0 (expr-fvar 'ReadCap)
        (expr-lam 'm0 (expr-fvar 'HttpCap)
          (expr-lam 'mw (expr-fvar 'Nat)
            (expr-app (expr-fvar 'g-od) (expr-bvar 0))))))
    (define env
      (hasheq 'f-od (cons f-type f-body)
              'g-od (cons g-type g-body)))
    (define bridge-result (build-cross-domain-network env))
    (define overdeclared (cap-audit-overdeclared bridge-result 'f-od))
    ;; HttpCap is declared by f but never used in call graph
    (check-true (closure-has-cap-name? overdeclared 'HttpCap)
                "HttpCap should be overdeclared")))

(test-case "bridge/pure-function"
  ;; A pure function (no capabilities) should have empty results.
  (define result
    (run-and-bridge
     "(def pure8 : (Pi (x :w Nat) Nat) := (fn (x :w Nat) x))"))
  (define cap-closures (cap-type-bridge-result-cap-closures result))
  (define k (find-key-by-suffix cap-closures "pure8"))
  (check-true (and k (set-empty? (hash-ref cap-closures k (set))))
              "pure function should have empty cap closure"))

(test-case "bridge/diamond-topology"
  ;; Diamond: f calls both g and h, g declares ReadCap, h declares HttpCap.
  ;; f should have both in its closure.
  (define result
    (run-and-bridge
     (string-append
      "(def g-dia : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 ReadCap) (fn (x :w Nat) x)))\n"
      "(def h-dia : (Pi (c :0 HttpCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 HttpCap) (fn (x :w Nat) x)))\n"
      "(def f-dia : (Pi (c1 :0 ReadCap) (Pi (c2 :0 HttpCap) (Pi (x :w Nat) Nat)))"
      " := (fn (c1 :0 ReadCap) (fn (c2 :0 HttpCap) (fn (x :w Nat) (g-dia (h-dia x))))))")))
  (define cap-closures (cap-type-bridge-result-cap-closures result))
  (define f-key (find-key-by-suffix cap-closures "f-dia"))
  (define f-caps (and f-key (hash-ref cap-closures f-key (set))))
  (check-true (and f-caps (closure-has-cap-name? f-caps 'ReadCap)) "f-dia should require ReadCap")
  (check-true (and f-caps (closure-has-cap-name? f-caps 'HttpCap)) "f-dia should require HttpCap"))

(test-case "bridge/convergence-mutual-recursion"
  ;; Mutual recursion: f calls g, g calls f. Both declare ReadCap.
  ;; Network should converge without fuel exhaustion.
  ;; We construct the env directly since process-string can't handle
  ;; mutual forward references in sequential def forms.
  (parameterize ([current-capability-registry shared-capability-reg]
                 [current-subtype-registry shared-subtype-reg])
    (define f-type
      (expr-Pi 'm0 (expr-fvar 'ReadCap)
        (expr-Pi 'mw (expr-fvar 'Nat) (expr-fvar 'Nat))))
    (define g-type
      (expr-Pi 'm0 (expr-fvar 'ReadCap)
        (expr-Pi 'mw (expr-fvar 'Nat) (expr-fvar 'Nat))))
    ;; f calls g, g calls f
    (define f-body
      (expr-lam 'm0 (expr-fvar 'ReadCap)
        (expr-lam 'mw (expr-fvar 'Nat)
          (expr-app (expr-fvar 'g-mr) (expr-bvar 0)))))
    (define g-body
      (expr-lam 'm0 (expr-fvar 'ReadCap)
        (expr-lam 'mw (expr-fvar 'Nat)
          (expr-app (expr-fvar 'f-mr) (expr-bvar 0)))))
    (define env
      (hasheq 'f-mr (cons f-type f-body)
              'g-mr (cons g-type g-body)))
    (define result (build-cross-domain-network env))
    (define cap-closures (cap-type-bridge-result-cap-closures result))
    ;; Both should have ReadCap in their closures
    (check-true (closure-has-cap-name? (hash-ref cap-closures 'f-mr (set)) 'ReadCap)
                "f-mr should have ReadCap")
    (check-true (closure-has-cap-name? (hash-ref cap-closures 'g-mr (set)) 'ReadCap)
                "g-mr should have ReadCap")))

;; ========================================
;; Phase 8c: REPL Command Tests
;; ========================================

(test-case "cap-bridge/repl-pure-function"
  ;; cap-bridge on a pure function
  (define output
    (run-last
     (string-append
      "(def pure-bridge : (Pi (x :w Nat) Nat) := (fn (x :w Nat) x))\n"
      "(cap-bridge pure-bridge)")))
  (check-true (string-contains? output "cap-bridge pure-bridge:"))
  (check-true (string-contains? output "pure")))

(test-case "cap-bridge/repl-with-capabilities"
  ;; cap-bridge on a function with capabilities
  (define output
    (run-last
     (string-append
      "(def g-br : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 ReadCap) (fn (x :w Nat) x)))\n"
      "(def f-br : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 ReadCap) (fn (x :w Nat) (g-br x))))\n"
      "(cap-bridge f-br)")))
  (check-true (string-contains? output "cap-bridge f-br:"))
  (check-true (string-contains? output "ReadCap")))

(test-case "cap-bridge/repl-overdeclared"
  ;; cap-bridge showing overdeclared caps — function declares both ReadCap
  ;; and HttpCap but only uses ReadCap through call chain.
  ;; Due to lexical resolution (Phase 4), functions must use all declared caps
  ;; at the type level. So we test overdeclared indirectly: f declares HttpCap
  ;; and calls g which declares ReadCap. f's type has HttpCap, but f's body
  ;; never calls anything requiring HttpCap directly.
  ;; Actually: f passes through HttpCap's scope, so it IS in scope — but if
  ;; no callee requires it, the INFERENCE won't include it. The overdeclared
  ;; analysis compares declared vs inferred.
  (define output
    (run-last
     (string-append
      "(def helper-or : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 ReadCap) (fn (x :w Nat) x)))\n"
      "(def main-or : (Pi (c1 :0 ReadCap) (Pi (c2 :0 HttpCap) (Pi (x :w Nat) Nat)))"
      " := (fn (c1 :0 ReadCap) (fn (c2 :0 HttpCap) (fn (x :w Nat) (helper-or x)))))\n"
      "(cap-bridge main-or)")))
  (check-true (string-contains? output "cap-bridge main-or:"))
  ;; HttpCap should appear as overdeclared since helper-or only needs ReadCap
  (check-true (string-contains? output "HttpCap")))

(test-case "cap-bridge/repl-no-overdeclared"
  ;; cap-bridge on a function where declared = inferred (no overdeclared)
  (define output
    (run-last
     (string-append
      "(def leaf-no : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 ReadCap) (fn (x :w Nat) x)))\n"
      "(cap-bridge leaf-no)")))
  (check-true (string-contains? output "cap-bridge leaf-no:"))
  (check-true (string-contains? output "ReadCap"))
  ;; Overdeclared should be "none" since declared matches inferred
  (check-true (string-contains? output "none")))

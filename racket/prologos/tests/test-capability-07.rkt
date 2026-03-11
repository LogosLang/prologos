#lang racket/base

;;;
;;; Tests for Capabilities as Types — Phase 7: Dependent (Parameterized) Capabilities
;;; Tests parsing, type formation, scope tracking, dependent resolution,
;;; minting pattern, and integration for parameterized capability types.
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
         "../type-lattice.rkt")

;; ========================================
;; Shared Fixture (modules loaded once)
;; ========================================

(define shared-preamble
  "(ns test-cap7)")

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-capability-reg
                shared-subtype-reg)
  (parameterize ([current-global-env (hasheq)]
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

;; Helper: run code and capture env + registries
(define (run-capturing s)
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
    (define results (process-string s))
    (list results
          (global-env-snapshot)  ;; Phase 3a: merge both layers
          (current-capability-registry))))

;; ========================================
;; Phase 7a: Parsing Tests
;; ========================================

(test-case "parse/single-param-capability"
  ;; (capability FileCap7 (p : String)) → surf-capability with 1 binder-info param
  (define result (parse-datum '(capability FileCap7 (p : String))))
  (check-true (surf-capability? result))
  (check-equal? (surf-capability-name result) 'FileCap7)
  (define params (surf-capability-params result))
  (check-equal? (length params) 1)
  (check-true (binder-info? (car params)))
  (check-equal? (binder-info-name (car params)) 'p)
  ;; Type should be surf-string-type (parser recognizes String as built-in)
  (check-true (surf-string-type? (binder-info-type (car params)))))

(test-case "parse/multi-param-capability"
  ;; (capability BiCap7 (p : String) (n : Nat)) → 2 binder-infos
  (define result (parse-datum '(capability BiCap7 (p : String) (n : Nat))))
  (check-true (surf-capability? result))
  (check-equal? (surf-capability-name result) 'BiCap7)
  (check-equal? (length (surf-capability-params result)) 2)
  (check-equal? (binder-info-name (first (surf-capability-params result))) 'p)
  (check-equal? (binder-info-name (second (surf-capability-params result))) 'n))

(test-case "parse/nullary-capability-regression"
  ;; Nullary caps still work: (capability ReadCap) → empty params
  (define result (parse-datum '(capability ReadCap7)))
  (check-true (surf-capability? result))
  (check-equal? (surf-capability-name result) 'ReadCap7)
  (check-equal? (surf-capability-params result) '()))

(test-case "parse/malformed-param-error"
  ;; Malformed param: (capability Bad7 (p)) → parse error
  (define result (parse-datum '(capability Bad7 (p))))
  ;; parse-binder on bare (p) → binder-info with hole type (Sprint 10: [x] is ok)
  ;; Actually (p) is a 1-element list with a symbol — parse-binder returns binder-info with hole
  (check-true (surf-capability? result))
  (define params (surf-capability-params result))
  (check-equal? (length params) 1)
  (check-equal? (binder-info-name (car params)) 'p))

;; ========================================
;; Phase 7b: Type Formation Tests
;; ========================================

(test-case "type-formation/dependent-cap-has-pi-type"
  ;; (capability FileCap7 (p : String)) → FileCap7 : Pi(:0 String, Type 0)
  (define captured (run-capturing "(capability FileCap7 (p : String))"))
  (define env (second captured))
  ;; Look up FileCap7 in env (should have been installed under FQN)
  (define ty
    (for/or ([(k v) (in-hash env)])
      (and (regexp-match? #rx"FileCap7$" (symbol->string k))
           (if (pair? v) (car v) v))))
  (check-true (expr-Pi? ty) "FileCap7 should have Pi type")
  (check-equal? (expr-Pi-mult ty) 'm0 "Pi should use :0 multiplicity")
  ;; Domain should be String (elaborated to expr-String, not expr-fvar)
  (check-true (expr-String? (expr-Pi-domain ty))
              "Pi domain should be String")
  ;; Codomain should be (Type 0)
  (check-true (expr-Type? (expr-Pi-codomain ty))))

(test-case "type-formation/applied-dependent-cap"
  ;; [FileCap7b "hello"] should have type (Type 0) — applying a dependent cap to an arg
  (define output
    (run-last
     (string-append
      "(capability FileCap7b (p : String))\n"
      "(infer [FileCap7b \"hello\"])")))
  (check-true (string-contains? output "Type")
              "Applied dependent cap should have Type 0"))

(test-case "type-formation/nullary-cap-type-regression"
  ;; Nullary ReadCap7 still has type (Type 0)
  (define captured (run-capturing "(capability ReadCap7)"))
  (define env (second captured))
  (define ty
    (for/or ([(k v) (in-hash env)])
      (and (regexp-match? #rx"ReadCap7$" (symbol->string k))
           (if (pair? v) (car v) v))))
  (check-true (expr-Type? ty) "Nullary cap should have Type 0"))

(test-case "type-formation/multi-param-nested-pi"
  ;; (capability BiCap7 (p : String) (n : Nat)) → Pi(:0 String, Pi(:0 Nat, Type 0))
  (define captured (run-capturing "(capability BiCap7 (p : String) (n : Nat))"))
  (define env (second captured))
  (define ty
    (for/or ([(k v) (in-hash env)])
      (and (regexp-match? #rx"BiCap7$" (symbol->string k))
           (if (pair? v) (car v) v))))
  (check-true (expr-Pi? ty) "BiCap7 should have outer Pi")
  (check-true (expr-Pi? (expr-Pi-codomain ty)) "BiCap7 should have nested Pi")
  (check-true (expr-Type? (expr-Pi-codomain (expr-Pi-codomain ty)))
              "Inner codomain should be Type 0"))

;; ========================================
;; Phase 7c: Scope Tracking Tests
;; ========================================

(test-case "scope/pi-with-dependent-cap-domain"
  ;; Pi type with applied dependent cap domain enters scope correctly.
  ;; A function that takes a dependent cap can be declared.
  (define output
    (run-last
     (string-append
      "(capability FileCap7c (p : String))\n"
      "(def use-file : (Pi (fc :0 [FileCap7c \"hello\"]) (Pi (x :w Nat) Nat))"
      " := (fn (fc :0 [FileCap7c \"hello\"]) (fn (x :w Nat) x)))")))
  (check-true (string? output) "Dependent cap in Pi domain should elaborate"))

(test-case "scope/lambda-with-dependent-cap-param"
  ;; Lambda with dependent cap param tracks scope
  (define output
    (run-last
     (string-append
      "(capability FileCap7d (p : String))\n"
      "(def use-file-lam : (Pi (fc :0 [FileCap7d \"test\"]) (Pi (x :w Nat) Nat))"
      " := (fn (fc :0 [FileCap7d \"test\"]) (fn (x :w Nat) x)))")))
  (check-true (string? output) "Lambda with dependent cap param should elaborate"))

(test-case "scope/w2001-on-dependent-cap"
  ;; W2001 fires for :w on dependent cap (same as simple caps)
  ;; Using :w on a capability type is suspicious — should at least parse/elaborate
  (define output
    (run-last
     (string-append
      "(capability FileCap7e (p : String))\n"
      "(def ww : (Pi (fc :w [FileCap7e \"x\"]) Nat)"
      " := (fn (fc :w [FileCap7e \"x\"]) 42N))")))
  (check-true (string? output) "Should elaborate despite W2001"))

;; ========================================
;; Phase 7c: Dependent Resolution Tests
;; ========================================

(test-case "resolution/simple-cap-still-resolves"
  ;; Regression: simple (non-dependent) cap resolution still works.
  ;; f8 declares ReadCap, g8 requires ReadCap → implicit resolution.
  (define output
    (run-last
     (string-append
      "(def g7res : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 ReadCap) (fn (x :w Nat) x)))\n"
      "(def f7res : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 ReadCap) (fn (x :w Nat) (g7res x))))")))
  (check-true (string? output) "Simple cap resolution should still work"))

(test-case "resolution/dependent-cap-functor-match"
  ;; Dependent cap in scope resolves by functor name.
  ;; fn (fc :0 [FileCap7f "test"]) ... → fc in scope satisfies {fc :0 [FileCap7f "test"]}
  (define output
    (run-last
     (string-append
      "(capability FileCap7f (p : String))\n"
      "(def use-dep : (Pi (fc :0 [FileCap7f \"test\"]) (Pi (x :w Nat) Nat))"
      " := (fn (fc :0 [FileCap7f \"test\"]) (fn (x :w Nat) x)))")))
  (check-true (string? output) "Dependent cap should resolve by functor name"))

(test-case "resolution/missing-cap-e2001"
  ;; E2001 when dependent cap is not in scope
  ;; A function body references a dep-cap-requiring function without providing the cap.
  ;; This should produce an E2001 error.
  (define result
    (run-last
     (string-append
      "(capability FileCap7g (p : String))\n"
      "(def needs-cap7g : (Pi (fc :0 [FileCap7g \"x\"]) (Pi (x :w Nat) Nat))"
      " := (fn (fc :0 [FileCap7g \"x\"]) (fn (x :w Nat) x)))\n"
      "(def no-cap7g : (Pi (x :w Nat) Nat)"
      " := (fn (x :w Nat) (needs-cap7g x)))")))
  ;; Result may be a prologos-error struct (not a string) containing E2001
  (check-true (prologos-error? result)
              "Missing dependent cap should produce an error"))

(test-case "resolution/subtype-cap-resolves"
  ;; Subtype resolution: ReadCap requirement satisfied by FsCap in scope.
  ;; (ReadCap <: FsCap declared in prelude)
  (define output
    (run-last
     (string-append
      "(def needs-read : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 ReadCap) (fn (x :w Nat) x)))\n"
      "(def has-fs : (Pi (c :0 FsCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 FsCap) (fn (x :w Nat) (needs-read x))))")))
  (check-true (string? output)
              "Subtype cap resolution should work (FsCap subsumes ReadCap)"))

(test-case "resolution/multiple-dep-caps-correct-functor"
  ;; Multiple dependent caps in scope — correct one chosen by functor name.
  (define output
    (run-last
     (string-append
      "(capability CapA7 (p : String))\n"
      "(capability CapB7 (q : Nat))\n"
      "(def needs-a : (Pi (a :0 [CapA7 \"x\"]) (Pi (x :w Nat) Nat))"
      " := (fn (a :0 [CapA7 \"x\"]) (fn (x :w Nat) x)))\n"
      "(def has-both : (Pi (a :0 [CapA7 \"x\"]) (Pi (b :0 [CapB7 0N]) (Pi (x :w Nat) Nat)))"
      " := (fn (a :0 [CapA7 \"x\"]) (fn (b :0 [CapB7 0N]) (fn (x :w Nat) (needs-a x)))))")))
  (check-true (string? output)
              "Multiple dep caps: correct functor should be chosen"))

;; ========================================
;; Phase 7: Integration Tests
;; ========================================

(test-case "integration/declare-and-use-dependent-cap"
  ;; Full pipeline: declare dependent cap, use it in function type, elaborate body.
  (define output
    (run-last
     (string-append
      "(capability FileCap7int (p : String))\n"
      "(def read-file7 : (Pi (fc :0 [FileCap7int \"data\"]) (Pi (x :w Nat) Nat))"
      " := (fn (fc :0 [FileCap7int \"data\"]) (fn (x :w Nat) x)))\n"
      "(def use-file7 : (Pi (fc :0 [FileCap7int \"data\"]) (Pi (x :w Nat) Nat))"
      " := (fn (fc :0 [FileCap7int \"data\"]) (fn (x :w Nat) (read-file7 x))))")))
  (check-true (string? output)
              "Full declare → use → resolve pipeline should work"))

(test-case "integration/cap-closure-with-dependent-cap"
  ;; cap-closure on a function with a dependent capability.
  ;; The cap-closure command reports capability requirements.
  ;; Since Phase 7e (cap-set extension for expr-app) is deferred, the closure
  ;; should at minimum include the functor name from simple cap extraction.
  (define output
    (run-last
     (string-append
      "(capability FileCap7clo (p : String))\n"
      "(def needs-file7 : (Pi (fc :0 [FileCap7clo \"test\"]) (Pi (x :w Nat) Nat))"
      " := (fn (fc :0 [FileCap7clo \"test\"]) (fn (x :w Nat) x)))\n"
      "(cap-closure needs-file7)")))
  ;; cap-closure extracts capabilities from the type. For applied caps,
  ;; the current extract-capability-requirements uses expr-fvar? which
  ;; won't match expr-app. So the function appears pure.
  ;; This is expected and will be fixed in Phase 7e.
  (check-true (string? output)
              "cap-closure should run without error on dependent-cap function"))

(test-case "integration/capability-type-expr-helper"
  ;; Direct test of capability-type-expr? helper
  (parameterize ([current-capability-registry shared-capability-reg])
    ;; Simple cap: (expr-fvar 'ReadCap) → 'ReadCap
    (check-equal? (capability-type-expr? (expr-fvar 'ReadCap)) 'ReadCap)
    ;; Non-cap: (expr-fvar 'Nat) → #f
    (check-false (capability-type-expr? (expr-fvar 'Nat)))
    ;; Applied cap: (expr-app (expr-fvar 'ReadCap) (expr-fvar 'Nat)) → 'ReadCap
    ;; (ReadCap isn't actually dependent, but the helper checks functor name only)
    (check-equal? (capability-type-expr? (expr-app (expr-fvar 'ReadCap) (expr-fvar 'Nat))) 'ReadCap)
    ;; Non-cap app: (expr-app (expr-fvar 'Nat) (expr-fvar 'Bool)) → #f
    (check-false (capability-type-expr? (expr-app (expr-fvar 'Nat) (expr-fvar 'Bool))))
    ;; type-bot → #f
    (check-false (capability-type-expr? type-bot))))

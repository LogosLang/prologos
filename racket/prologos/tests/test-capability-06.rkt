#lang racket/base

;;;
;;; Tests for Capabilities as Types — Phase 6: Foreign Function Capability Gating
;;; Tests that foreign imports can declare capability requirements via :requires,
;;; and that these requirements propagate through inference and lexical resolution.
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
         "../foreign.rkt")

;; ========================================
;; Shared Fixture (modules loaded once)
;; ========================================

(define shared-preamble
  "(ns test-cap6)")

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
                 [current-definition-cells-content (hasheq)]  ;; Phase 3a: fresh per-test
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

;; Helper: run code and capture global-env after execution
(define (run-capturing-env s)
  (parameterize ([current-prelude-env shared-global-env]
                 [current-definition-cells-content (hasheq)]  ;; Phase 3a: fresh per-test
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
    (global-env-snapshot)))

;; ========================================
;; Unit Tests: extract-foreign-caps
;; ========================================

(test-case "foreign-caps/requires-keyword"
  ;; :requires (ReadCap) extracts ReadCap
  (parameterize ([current-capability-registry shared-capability-reg])
    (define-values (caps decls)
      (extract-foreign-caps (list ':requires '(ReadCap) '(add1 : Nat -> Nat))))
    (check-equal? caps '(ReadCap))
    (check-equal? (length decls) 1)))

(test-case "foreign-caps/requires-multiple"
  ;; :requires (ReadCap HttpCap) extracts both
  (parameterize ([current-capability-registry shared-capability-reg])
    (define-values (caps decls)
      (extract-foreign-caps (list ':requires '(ReadCap HttpCap) '(add1 : Nat -> Nat))))
    (check-equal? (length caps) 2)
    (check-not-false (member 'ReadCap caps))
    (check-not-false (member 'HttpCap caps))))

(test-case "foreign-caps/no-requires"
  ;; No :requires → empty caps
  (parameterize ([current-capability-registry shared-capability-reg])
    (define-values (caps decls)
      (extract-foreign-caps (list '(add1 : Nat -> Nat))))
    (check-equal? caps '())
    (check-equal? (length decls) 1)))

(test-case "foreign-caps/brace-params"
  ;; ($brace-params fs :0 ReadCap) → extracts ReadCap
  (parameterize ([current-capability-registry shared-capability-reg])
    (define-values (caps decls)
      (extract-foreign-caps (list '($brace-params fs :0 ReadCap) '(add1 : Nat -> Nat))))
    (check-equal? caps '(ReadCap))
    (check-equal? (length decls) 1)))

;; ========================================
;; Unit Tests: extract-caps-from-brace-params
;; ========================================

(test-case "brace-params-caps/single"
  (parameterize ([current-capability-registry shared-capability-reg])
    (define caps (extract-caps-from-brace-params '(fs :0 ReadCap)))
    (check-equal? caps '(ReadCap))))

(test-case "brace-params-caps/multiple"
  (parameterize ([current-capability-registry shared-capability-reg])
    (define caps (extract-caps-from-brace-params '(fs :0 ReadCap net :0 HttpCap)))
    (check-equal? (length caps) 2)))

(test-case "brace-params-caps/no-caps"
  ;; Non-capability type → empty
  (parameterize ([current-capability-registry shared-capability-reg])
    (define caps (extract-caps-from-brace-params '(x :w Nat)))
    (check-equal? caps '())))

;; ========================================
;; Integration: Foreign with Capabilities — Type Registration
;; ========================================

(test-case "foreign/requires-registers-type-with-cap"
  ;; Foreign import with :requires should register a type that includes :0 cap binder
  (define env
    (run-capturing-env
     (string-append
      "(foreign racket \"racket/base\" :requires (ReadCap)"
      " (add1 : Nat -> Nat))")))
  (define entry (hash-ref env 'add1 #f))
  (check-true (pair? entry) "add1 should be registered")
  ;; The type (car entry) should be a Pi with :0 ReadCap domain
  (define ty (car entry))
  (check-true (expr-Pi? ty) "Type should be a Pi")
  (check-equal? (expr-Pi-mult ty) 'm0 "First Pi should be :0")
  (check-true (expr-fvar? (expr-Pi-domain ty)) "Domain should be fvar")
  (check-equal? (expr-fvar-name (expr-Pi-domain ty)) 'ReadCap "Domain should be ReadCap"))

(test-case "foreign/no-requires-no-cap-binder"
  ;; Foreign import without :requires — type should be plain Pi (domain = Nat, not ReadCap)
  (define env
    (run-capturing-env
     "(foreign racket \"racket/base\" (sub1 : Nat -> Nat))"))
  (define entry (hash-ref env 'sub1 #f))
  (check-true (pair? entry) "sub1 should be registered")
  (define ty (car entry))
  (check-true (expr-Pi? ty) "Type should be a Pi")
  ;; The domain should NOT be a capability type
  (check-equal? (expr-Pi-mult ty) 'mw "First Pi should be :w (runtime arg)"))

;; ========================================
;; Integration: Inference via cap-closure
;; ========================================

(test-case "foreign/requires-inference-closure"
  ;; Foreign with ReadCap → cap-closure should show ReadCap
  (define result
    (run (string-append
          "(foreign racket \"racket/base\" :requires (ReadCap)"
          " (add1 : Nat -> Nat))\n"
          "(cap-closure add1)")))
  ;; foreign import produces no output, cap-closure does
  (check-true (not (null? result)))
  (check-true (string-contains? (last result) "ReadCap")))

(test-case "foreign/requires-transitive-closure"
  ;; Function calling foreign with ReadCap → caller inherits ReadCap in closure
  (define result
    (run (string-append
          "(foreign racket \"racket/base\" :requires (ReadCap)"
          " (add1 : Nat -> Nat))\n"
          "(def use-add1 : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
          " := (fn (c :0 ReadCap) (fn (x :w Nat) (add1 x))))\n"
          "(cap-closure use-add1)")))
  (check-true (not (null? result)))
  (check-true (string-contains? (last result) "ReadCap")))

(test-case "foreign/requires-multiple-caps-closure"
  ;; Foreign with multiple capabilities
  (define result
    (run (string-append
          "(foreign racket \"racket/base\" :requires (ReadCap HttpCap)"
          " (add1 : Nat -> Nat))\n"
          "(cap-closure add1)")))
  (check-true (not (null? result)))
  (check-true (string-contains? (last result) "ReadCap"))
  (check-true (string-contains? (last result) "HttpCap")))

(test-case "foreign/pure-foreign-no-caps"
  ;; Foreign without :requires → pure closure
  (define result
    (run (string-append
          "(foreign racket \"racket/base\" (add1 : Nat -> Nat))\n"
          "(cap-closure add1)")))
  (check-true (not (null? result)))
  (check-true (string-contains? (last result) "pure")))

(test-case "foreign/requires-with-alias"
  ;; :requires works with :as module alias
  (define result
    (run (string-append
          "(foreign racket \"racket/base\" :as rkt :requires (ReadCap)"
          " (add1 : Nat -> Nat))\n"
          "(cap-closure rkt/add1)")))
  (check-true (not (null? result)))
  (check-true (string-contains? (last result) "ReadCap")))

(test-case "foreign/requires-audit-trail"
  ;; cap-audit for foreign function shows "directly declares"
  (define result
    (run (string-append
          "(foreign racket \"racket/base\" :requires (ReadCap)"
          " (add1 : Nat -> Nat))\n"
          "(cap-audit add1 ReadCap)")))
  (check-true (not (null? result)))
  (check-true (string-contains? (last result) "directly declares")))

(test-case "foreign/multiple-decls-share-caps"
  ;; All declarations in a foreign block share the same :requires
  (define result
    (run (string-append
          "(foreign racket \"racket/base\" :requires (ReadCap)"
          " (add1 : Nat -> Nat)"
          " (sub1 : Nat -> Nat))\n"
          "(cap-closure add1)\n"
          "(cap-closure sub1)")))
  ;; Both add1 and sub1 should require ReadCap
  (define results (filter (lambda (s) (string-contains? s "ReadCap")) result))
  (check-equal? (length results) 2 "Both functions should require ReadCap"))

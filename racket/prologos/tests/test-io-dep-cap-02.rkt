#lang racket/base

;;;
;;; test-io-dep-cap-02.rkt — Dependent Capabilities E2E Tests (IO-I)
;;;
;;; End-to-end tests for dependent capability inference through the
;;; compilation pipeline: process-string with applied capability types
;;; like (FileCap "/data"), cap-closure/cap-audit REPL commands,
;;; and E2004 security enforcement for applied caps.
;;;
;;; Pattern: Shared fixture with process-string + prelude.
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
         "../cap-type-bridge.rkt")

;; ========================================
;; Shared Fixture (prelude + capabilities loaded once)
;; ========================================

(define shared-preamble
  (string-append
   "(ns test-dep-cap-e2e)\n"
   "(capability FileCap (p : String))\n"
   "(subtype FileCap FsCap)"))

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

;; Helper: run code and return (values results cap-result)
(define (run-and-infer s)
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
                 [current-subtype-registry shared-subtype-reg]
                 [current-module-cap-result #f])
    (define results (process-string s))
    (values results (current-module-cap-result))))

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
                 [current-subtype-registry shared-subtype-reg]
                 [current-module-cap-result #f])
    (process-string s)))

(define (run-last s) (last (run s)))

;; ========================================
;; Group 1: Applied capability inference through pipeline
;; ========================================

(test-case "dep-cap-e2e/filecap-path-inference"
  ;; A function declaring (FileCap "/data") → inference sees the applied cap
  (define-values (results cap-result)
    (run-and-infer
     (string-append
      "(def file-reader : (Pi (c :0 (FileCap \"/data\")) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 (FileCap \"/data\")) (fn (x :w Nat) x)))")))
  (check-true (cap-inference-result? cap-result)
              "cap-result should be populated")
  (define closures (cap-inference-result-closures cap-result))
  (define closure
    (hash-ref closures 'test-dep-cap-e2e::file-reader (set)))
  ;; Closure should contain FileCap
  (check-true (closure-has-cap-name? closure 'FileCap)
              "closure should include FileCap")
  ;; The actual entry should be an applied cap with index "/data"
  ;; Note: cap-entry-name is FQN (test-dep-cap-e2e::FileCap), so match by suffix
  (define file-entries
    (for/list ([e (in-set closure)]
               #:when (closure-has-cap-name? (set e) 'FileCap))
      e))
  (check-equal? (length file-entries) 1
                "Should have exactly one FileCap entry")
  (check-equal? (cap-entry-index-expr (car file-entries)) (expr-string "/data")
                "FileCap should have index \"/data\""))

(test-case "dep-cap-e2e/mixed-bare-and-applied"
  ;; Function declaring both ReadCap (bare) and FileCap "/data" (applied)
  (define-values (results cap-result)
    (run-and-infer
     (string-append
      "(def rw-file : (Pi (c1 :0 ReadCap) (Pi (c2 :0 (FileCap \"/data\")) (Pi (x :w Nat) Nat)))"
      " := (fn (c1 :0 ReadCap) (fn (c2 :0 (FileCap \"/data\")) (fn (x :w Nat) x))))")))
  (check-true (cap-inference-result? cap-result))
  (define closures (cap-inference-result-closures cap-result))
  (define closure
    (hash-ref closures 'test-dep-cap-e2e::rw-file (set)))
  (check-true (closure-has-cap-name? closure 'ReadCap)
              "should include ReadCap")
  (check-true (closure-has-cap-name? closure 'FileCap)
              "should include FileCap"))

(test-case "dep-cap-e2e/transitive-applied-cap"
  ;; f calls g which declares (FileCap "/data") → f's closure includes it
  (define-values (results cap-result)
    (run-and-infer
     (string-append
      "(def g-file : (Pi (c :0 (FileCap \"/data\")) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 (FileCap \"/data\")) (fn (x :w Nat) x)))\n"
      "(def f-file : (Pi (c :0 (FileCap \"/data\")) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 (FileCap \"/data\")) (fn (x :w Nat) (g-file x))))")))
  (check-true (cap-inference-result? cap-result))
  (define closures (cap-inference-result-closures cap-result))
  (define f-closure
    (hash-ref closures 'test-dep-cap-e2e::f-file (set)))
  (check-true (closure-has-cap-name? f-closure 'FileCap)
              "f-file closure should include FileCap transitively"))

;; ========================================
;; Group 2: REPL commands with applied caps
;; ========================================

(test-case "dep-cap-e2e/cap-closure-shows-applied"
  ;; cap-closure should show the applied capability
  (define result
    (run (string-append
          "(def fc-fn : (Pi (c :0 (FileCap \"/data\")) (Pi (x :w Nat) Nat))"
          " := (fn (c :0 (FileCap \"/data\")) (fn (x :w Nat) x)))\n"
          "(cap-closure fc-fn)")))
  (check-true (string-contains? (last result) "FileCap")
              "cap-closure should mention FileCap"))

(test-case "dep-cap-e2e/cap-audit-applied-declares"
  ;; cap-audit for a function that directly declares an applied cap
  (define result
    (run (string-append
          "(def fc-audit : (Pi (c :0 (FileCap \"/data\")) (Pi (x :w Nat) Nat))"
          " := (fn (c :0 (FileCap \"/data\")) (fn (x :w Nat) x)))\n"
          "(cap-audit fc-audit FileCap)")))
  (check-true (string-contains? (last result) "directly declares")
              "cap-audit should report direct declaration"))

;; ========================================
;; Group 3: E2004 security with applied caps
;; ========================================

(test-case "dep-cap-e2e/e2004-applied-cap-violation"
  ;; Synthetic: f declares ReadCap (bare) but calls g which needs FileCap "/data".
  ;; FileCap is NOT a subtype of ReadCap → E2004 security violation.
  (check-exn
   (lambda (e)
     (and (exn:fail? e)
          (string-contains? (exn-message e) "E2004")
          (string-contains? (exn-message e) "FileCap")))
   (lambda ()
     (parameterize ([current-global-env
                     (hash-set
                      (hash-set shared-global-env
                                'g-fc
                                (cons (expr-Pi 'm0 (expr-app (expr-fvar 'FileCap) (expr-string "/data"))
                                        (expr-Pi 'mw (expr-fvar 'Nat) (expr-fvar 'Nat)))
                                      (expr-lam 'mw (expr-fvar 'Nat) (expr-fvar 'g-fc))))
                      'f-sneaky
                      (cons (expr-Pi 'm0 (expr-fvar 'ReadCap)
                              (expr-Pi 'mw (expr-fvar 'Nat) (expr-fvar 'Nat)))
                            (expr-lam 'mw (expr-fvar 'Nat)
                              (expr-app (expr-fvar 'g-fc) (expr-bvar 0)))))]
                    [current-capability-registry shared-capability-reg]
                    [current-subtype-registry shared-subtype-reg]
                    [current-module-cap-result #f])
       (run-post-compilation-inference!)))
   "Applied cap mismatch should raise E2004"))

(test-case "dep-cap-e2e/fscap-subsumes-filecap"
  ;; Authority root declares FsCap, callee needs FileCap "/data".
  ;; FileCap <: FsCap (via subtype registry), so FsCap subsumes → no error.
  (parameterize ([current-capability-registry shared-capability-reg]
                 [current-subtype-registry shared-subtype-reg])
    ;; Verify the subtype relationship exists
    (check-true (subtype-pair? 'FileCap 'FsCap)
                "FileCap should be subtype of FsCap")
    ;; Build subsumption check
    (define avail (cap-set (set (bare-cap 'FsCap))))
    (define req (cap-set (set (cap-entry 'FileCap (expr-string "/data")))))
    (check-true (cap-set-subsumes? avail req)
                "FsCap should subsume FileCap \"/data\"")))

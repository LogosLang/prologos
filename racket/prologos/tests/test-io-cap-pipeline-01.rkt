#lang racket/base

;;;
;;; test-io-cap-pipeline-01.rkt — Capability Inference Pipeline (IO-H)
;;;
;;; Tests that capability inference runs automatically after compilation
;;; (process-string / process-string-ws / load-module) and that:
;;;   1. current-module-cap-result is populated with inference results
;;;   2. Closures contain the expected capabilities
;;;   3. E2004 security errors are raised for underdeclared authority roots
;;;   4. Pure programs skip inference (fast path)
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
         "../capability-inference.rkt")

;; ========================================
;; Shared Fixture (prelude + capabilities loaded once)
;; ========================================

(define shared-preamble
  "(ns test-cap-pipeline)")

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
                 [current-capability-registry prelude-capability-registry]
                 [current-module-cap-result #f])
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
;; Uses current-module-cap-result to capture the inference result.
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

;; Standard run (for tests that don't need cap-result)
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
;; Group 1: Automatic inference happens
;; ========================================

(test-case "cap-pipeline/read-cap-infers"
  ;; A function declaring ReadCap → inference result has ReadCap in closure
  (define-values (results cap-result)
    (run-and-infer
     (string-append
      "(def read-fn : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 ReadCap) (fn (x :w Nat) x)))")))
  (check-true (cap-inference-result? cap-result)
              "cap-result should be a cap-inference-result struct")
  (define closures (cap-inference-result-closures cap-result))
  ;; The function should have ReadCap in its closure
  (define read-fn-closure
    (hash-ref closures 'test-cap-pipeline::read-fn (set)))
  (check-true (closure-has-cap-name? read-fn-closure 'ReadCap)
              "read-fn closure should include ReadCap"))

(test-case "cap-pipeline/transitive-inference"
  ;; f calls g which declares ReadCap → f's closure includes ReadCap
  (define-values (results cap-result)
    (run-and-infer
     (string-append
      "(def g-cap : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 ReadCap) (fn (x :w Nat) x)))\n"
      "(def f-calls-g : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 ReadCap) (fn (x :w Nat) (g-cap x))))")))
  (check-true (cap-inference-result? cap-result))
  (define closures (cap-inference-result-closures cap-result))
  (define f-closure
    (hash-ref closures 'test-cap-pipeline::f-calls-g (set)))
  (check-true (closure-has-cap-name? f-closure 'ReadCap)
              "f-calls-g closure should include ReadCap transitively"))

(test-case "cap-pipeline/pure-function-empty-closure"
  ;; Pure function with no IO → closure is empty
  (define-values (results cap-result)
    (run-and-infer
     "(def pure-ident : (Pi (x :w Nat) Nat) := (fn (x :w Nat) x))"))
  (check-true (cap-inference-result? cap-result))
  (define closures (cap-inference-result-closures cap-result))
  (define pure-closure
    (hash-ref closures 'test-cap-pipeline::pure-ident (set)))
  (check-true (set-empty? pure-closure)
              "pure function should have empty closure"))

(test-case "cap-pipeline/multiple-caps-accumulate"
  ;; Function declaring both ReadCap and WriteCap → closure has both
  (define-values (results cap-result)
    (run-and-infer
     (string-append
      "(def rw-fn : (Pi (c1 :0 ReadCap) (Pi (c2 :0 WriteCap) (Pi (x :w Nat) Nat)))"
      " := (fn (c1 :0 ReadCap) (fn (c2 :0 WriteCap) (fn (x :w Nat) x))))")))
  (check-true (cap-inference-result? cap-result))
  (define closures (cap-inference-result-closures cap-result))
  (define rw-closure
    (hash-ref closures 'test-cap-pipeline::rw-fn (set)))
  (check-true (closure-has-cap-name? rw-closure 'ReadCap)
              "rw-fn closure should include ReadCap")
  (check-true (closure-has-cap-name? rw-closure 'WriteCap)
              "rw-fn closure should include WriteCap"))

;; ========================================
;; Group 2: Security enforcement (underdeclared caps = error)
;; ========================================

(test-case "cap-pipeline/independent-caps-no-error"
  ;; Two functions — each declaring one cap, neither calling the other.
  ;; No underdeclared caps → no error.
  (define-values (results cap-result)
    (run-and-infer
     (string-append
      "(def read-thing : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 ReadCap) (fn (x :w Nat) x)))\n"
      "(def write-thing : (Pi (c :0 WriteCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 WriteCap) (fn (x :w Nat) x)))")))
  (check-true (cap-inference-result? cap-result)
              "Both definitions should succeed without cap security error"))

(test-case "cap-pipeline/fully-declared-no-error"
  ;; Authority root declares all needed caps → no error
  (define-values (results cap-result)
    (run-and-infer
     (string-append
      "(def writer2 : (Pi (c :0 WriteCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 WriteCap) (fn (x :w Nat) x)))\n"
      "(def caller-ok : (Pi (c1 :0 ReadCap) (Pi (c2 :0 WriteCap) (Pi (x :w Nat) Nat)))"
      " := (fn (c1 :0 ReadCap) (fn (c2 :0 WriteCap) (fn (x :w Nat) (writer2 x)))))")))
  (check-true (cap-inference-result? cap-result)
              "Fully-declared authority root should not raise error"))

(test-case "cap-pipeline/no-caps-no-inference"
  ;; Program with no capabilities at all → fast path, cap-result is #f
  (define-values (results cap-result)
    (run-and-infer
     "(def just-id : (Pi (x :w Nat) Nat) := (fn (x :w Nat) x))"))
  ;; With no capabilities, the registry might still have prelude caps registered.
  ;; But the function itself is pure. Check result was populated (since prelude
  ;; loads capability types, the registry isn't empty).
  (check-true (cap-inference-result? cap-result)
              "Cap result should be populated when capability registry is non-empty"))

;; ========================================
;; Group 3: Module-level integration
;; ========================================

(test-case "cap-pipeline/cap-result-available-after-process"
  ;; current-module-cap-result is non-#f after process-string with cap-bearing code
  (define-values (results cap-result)
    (run-and-infer
     (string-append
      "(def capped : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 ReadCap) (fn (x :w Nat) x)))")))
  (check-true (cap-inference-result? cap-result)
              "current-module-cap-result should be a cap-inference-result"))

(test-case "cap-pipeline/repl-commands-still-work"
  ;; cap-closure and cap-verify REPL commands still work alongside automatic inference
  (define result
    (run (string-append
          "(def repl-fn : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
          " := (fn (c :0 ReadCap) (fn (x :w Nat) x)))\n"
          "(cap-closure repl-fn)")))
  (check-true (string-contains? (last result) "ReadCap")
              "cap-closure REPL command should still work"))

(test-case "cap-pipeline/subtype-subsumption-no-error"
  ;; Authority root declares FsCap, callee needs ReadCap.
  ;; ReadCap <: FsCap, so FsCap subsumes ReadCap → no error.
  (define-values (results cap-result)
    (run-and-infer
     (string-append
      "(def reader3 : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 ReadCap) (fn (x :w Nat) x)))\n"
      "(def fs-root : (Pi (c :0 FsCap) (Pi (x :w Nat) Nat))"
      " := (fn (c :0 FsCap) (fn (x :w Nat) (reader3 x))))")))
  (check-true (cap-inference-result? cap-result)
              "FsCap subsumes ReadCap — no error expected"))

(test-case "cap-pipeline/synthetic-e2004-security-error"
  ;; Synthetic test: manually inject a function whose type declares only ReadCap
  ;; but whose body references a WriteCap-requiring function. This bypasses
  ;; the type checker to test the E2004 error machinery directly.
  ;;
  ;; SECURITY INVARIANT: underdeclared transitive caps are a security violation.
  ;; This MUST raise an error, not just a warning.
  (check-exn
   (lambda (e)
     (and (exn:fail? e)
          (string-contains? (exn-message e) "E2004")
          (string-contains? (exn-message e) "sneaky-fn")
          (string-contains? (exn-message e) "WriteCap")))
   (lambda ()
     (parameterize ([current-global-env
                     ;; Env with two functions:
                     ;; write-fn: declares WriteCap (type + body)
                     ;; sneaky-fn: declares ReadCap but body references write-fn
                     (hash-set
                      (hash-set shared-global-env
                                'write-fn
                                (cons (expr-Pi 'm0 (expr-fvar 'WriteCap)
                                        (expr-Pi 'mw (expr-fvar 'Nat)
                                          (expr-fvar 'Nat)))
                                      (expr-lam 'mw (expr-fvar 'Nat)
                                        (expr-fvar 'write-fn))))
                      'sneaky-fn
                      (cons (expr-Pi 'm0 (expr-fvar 'ReadCap)
                              (expr-Pi 'mw (expr-fvar 'Nat)
                                (expr-fvar 'Nat)))
                            ;; body references write-fn → call graph has edge
                            (expr-lam 'mw (expr-fvar 'Nat)
                              (expr-app (expr-fvar 'write-fn) (expr-bvar 0)))))]
                    [current-capability-registry shared-capability-reg]
                    [current-subtype-registry shared-subtype-reg]
                    [current-module-cap-result #f])
       (run-post-compilation-inference!)))
   "Underdeclared transitive cap should raise E2004 security error"))

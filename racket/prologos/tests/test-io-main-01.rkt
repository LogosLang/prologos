#lang racket/base

;;;
;;; test-io-main-01.rkt — main as Powerbox + Capability Enforcement (IO-D5)
;;;
;;; Tests that:
;;;   1. `main` implicitly provisions SysCap (powerbox pattern)
;;;   2. IO functions work inside `main` without explicit cap params
;;;   3. Top-level (REPL) expressions also get SysCap
;;;   4. Functions WITHOUT caps in scope get E2001 errors
;;;   5. Explicit cap parameters work for non-main functions
;;;   6. Subtype satisfaction (SysCap satisfies leaf caps)
;;;
;;; Pattern: Shared fixture with process-string + prelude.
;;;

(require rackunit
         racket/list
         racket/set
         racket/string
         racket/file
         racket/path
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
;; Shared Fixture (IO module loaded once)
;; ========================================

(define shared-preamble
  (string-append
   "(ns test-main)\n"
   "(imports (prologos::core::io :refer [read-file write-file println]))\n"
   "(imports (prologos::core::csv :refer [parse-csv csv-to-string read-csv write-csv]))"))

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg)
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
                 [current-spec-store (hasheq)])
    (install-module-loader!)
    (process-string shared-preamble)
    (values (global-env-snapshot)  ;; Phase 3a: merge both layers
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry))))

;; Capture subtype registry — populated during prelude loading in test-support.rkt.
;; This has all the subtype relationships from capabilities.prologos
;; (ReadCap <: FsCap <: IOCap <: SysCap, etc.)
(define shared-subtype-reg (current-subtype-registry))

;; Run with SysCap in scope (REPL/powerbox mode)
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
                 [current-capability-registry prelude-capability-registry]
                 [current-subtype-registry shared-subtype-reg]
                 ;; IO-D5: SysCap in scope for top-level defs (test runner as powerbox)
                 [current-capability-scope
                  (list (cons 0 (expr-fvar 'SysCap)))])
    (process-string s)))

(define (run-last s) (last (run s)))

;; Run WITHOUT SysCap in scope — for testing E2001 enforcement
(define (run-no-cap s)
  (parameterize ([current-global-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-capability-registry prelude-capability-registry]
                 [current-subtype-registry shared-subtype-reg]
                 ;; Deliberately NO capability scope — simulates non-powerbox context
                 [current-capability-scope '()])
    (process-string s)))

;; ========================================
;; Group 1: main as powerbox (4 tests)
;; ========================================

(test-case "main/read-file-in-main"
  ;; main implicitly provisions SysCap, which satisfies ReadCap via subtype chain.
  ;; read-file requires ReadCap → SysCap subsumes it → compiles.
  (define tmp (make-temporary-file "main-read-~a.txt"))
  (call-with-output-file tmp
    (lambda (out) (write-string "main-test-data" out))
    #:exists 'truncate/replace)
  (define result
    (run-last (format
               "(def main : (Pi (x :w Unit) String) := (fn (x :w Unit) (read-file ~s)))"
               (path->string tmp))))
  (check-true (string-contains? result "defined")
              "main with read-file should compile successfully")
  (delete-file tmp))

(test-case "main/write-file-in-main"
  ;; main + write-file: SysCap subsumes WriteCap
  (define tmp (make-temporary-file "main-write-~a.txt"))
  (define result
    (run-last (format
               "(def main : (Pi (x :w Unit) Unit) := (fn (x :w Unit) (write-file ~s \"from-main\")))"
               (path->string tmp))))
  (check-true (string-contains? result "defined")
              "main with write-file should compile successfully")
  (when (file-exists? tmp) (delete-file tmp)))

(test-case "main/println-in-main"
  ;; main + println: SysCap subsumes StdioCap
  (define result
    (run-last
     "(def main : (Pi (x :w Unit) Unit) := (fn (x :w Unit) (println \"hello\")))"))
  (check-true (string-contains? result "defined")
              "main with println should compile successfully"))

(test-case "main/transitive-io-in-main"
  ;; main calls a helper that declares ReadCap via spec.
  ;; main provisions SysCap → helper's ReadCap is satisfied.
  (define tmp (make-temporary-file "main-trans-~a.txt"))
  (call-with-output-file tmp
    (lambda (out) (write-string "transitive-data" out))
    #:exists 'truncate/replace)
  (define result
    (run (format
          (string-append
           "(def helper : (Pi (c :0 ReadCap) (Pi (p :w String) String))"
           " := (fn (c :0 ReadCap) (fn (p :w String) (read-file p))))\n"
           "(def main : (Pi (x :w Unit) String)"
           " := (fn (x :w Unit) (helper ~s)))")
          (path->string tmp))))
  (check-true (string-contains? (last result) "defined")
              "main calling cap-bearing helper should compile")
  (delete-file tmp))

;; ========================================
;; Group 2: Capability enforcement (3 tests)
;; ========================================

(test-case "main/io-without-cap-errors"
  ;; A non-main function calling read-file WITHOUT declaring ReadCap.
  ;; No SysCap in scope (run-no-cap) → E2001 error (no-instance-error struct).
  (define tmp (make-temporary-file "main-nocap-~a.txt"))
  (call-with-output-file tmp
    (lambda (out) (write-string "nocap" out))
    #:exists 'truncate/replace)
  (define result
    (run-no-cap
     (format
      "(def not-main : (Pi (x :w Unit) String) := (fn (x :w Unit) (read-file ~s)))"
      (path->string tmp))))
  ;; Should get E2001 error (returned as prologos-error struct)
  (check-true (ormap (lambda (r)
                       (and (prologos-error? r)
                            (string-contains? (prologos-error-message r) "E2001")))
                     result)
              "IO without cap in scope should produce E2001 error")
  (delete-file tmp))

(test-case "main/non-main-with-explicit-cap-works"
  ;; A non-main function with explicit ReadCap parameter calling read-file.
  ;; This works because the cap param puts ReadCap in scope.
  (define tmp (make-temporary-file "main-excap-~a.txt"))
  (call-with-output-file tmp
    (lambda (out) (write-string "explicit-cap" out))
    #:exists 'truncate/replace)
  (define result
    (run-last (format
               (string-append
                "(def read-fn : (Pi (c :0 ReadCap) (Pi (p :w String) String))"
                " := (fn (c :0 ReadCap) (fn (p :w String) (read-file p))))")
               )))
  (check-true (string-contains? result "defined")
              "Function with explicit ReadCap param should compile")
  (delete-file tmp))

(test-case "main/top-level-io-works"
  ;; Top-level IO expression (REPL-style) — SysCap provisioned automatically.
  (define tmp (make-temporary-file "main-toplevel-~a.txt"))
  (call-with-output-file tmp
    (lambda (out) (write-string "top-level-read" out))
    #:exists 'truncate/replace)
  (define result
    (run-last (format "(read-file ~s)" (path->string tmp))))
  (check-true (string-contains? result "top-level-read")
              "Top-level read-file should work with SysCap in scope")
  (delete-file tmp))

;; ========================================
;; Group 3: Cap inference integration (3 tests)
;; ========================================

(test-case "main/cap-closure-includes-io"
  ;; A function declaring ReadCap → cap-closure query shows ReadCap.
  (define result
    (run (string-append
          "(def reader : (Pi (c :0 ReadCap) (Pi (p :w String) String))"
          " := (fn (c :0 ReadCap) (fn (p :w String) (read-file p))))\n"
          "(cap-closure reader)")))
  (check-true (string-contains? (last result) "ReadCap")
              "cap-closure should show ReadCap for IO function"))

(test-case "main/csv-read-in-main"
  ;; main calling read-csv → compiles (ReadCap flows through csv module)
  (define tmp (make-temporary-file "main-csv-~a.csv"))
  (display-to-file "a,b\n1,2\n" tmp #:exists 'truncate/replace)
  (define result
    (run-last (format
               "(def main : (Pi (x :w Unit) (List (List String))) := (fn (x :w Unit) (read-csv ~s)))"
               (path->string tmp))))
  (check-true (string-contains? result "defined")
              "main calling read-csv should compile (SysCap satisfies ReadCap)")
  (delete-file tmp))

(test-case "main/subtype-satisfaction-diagnostics"
  ;; Verify the registries are populated correctly for subtype resolution
  ;; Must check inside parameterize since the registries are parameters
  (parameterize ([current-capability-registry prelude-capability-registry]
                 [current-subtype-registry shared-subtype-reg])
    (check-true (capability-type? 'FsCap)
                "FsCap should be in capability registry")
    (check-true (capability-type? 'SysCap)
                "SysCap should be in capability registry")
    (check-true (subtype-pair? 'FsCap 'SysCap)
                "FsCap <: SysCap should be in subtype registry")))

(test-case "main/subtype-satisfaction"
  ;; Function requiring ReadCap → SysCap satisfies via subtype chain.
  ;; ReadCap <: FsCap <: IOCap <: SysCap
  ;; Test calls the function from main where SysCap is provisioned.
  (define results
    (run (string-append
          "(def rc-fn : (Pi (c :0 ReadCap) (Pi (x :w String) String))"
          " := (fn (c :0 ReadCap) (fn (x :w String) x)))\n"
          "(def main : (Pi (x :w Unit) String)"
          " := (fn (x :w Unit) (rc-fn \"test\")))")))
  ;; Both definitions should succeed
  (define last-result (last results))
  (check-true (and (string? last-result)
                   (string-contains? last-result "defined"))
              (format "SysCap should satisfy ReadCap via subtype chain; got: ~a" last-result)))

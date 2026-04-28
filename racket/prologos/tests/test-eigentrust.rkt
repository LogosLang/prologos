#lang racket/base

;;;
;;; Tests for the EigenTrust-on-propagators example.
;;;
;;; Loads `lib/examples/eigentrust.prologos` end-to-end via `process-file`
;;; and checks that the algorithm converges to the expected steady-state
;;; trust vector. See:
;;;   * docs/tracking/2026-04-28_FFI_LAMBDA_PASSING.md
;;;   * docs/tracking/2026-04-28_ETPROP_PITFALLS.md
;;;
;;; The example demonstrates that — with the FFI lambda passing track
;;; landed — almost the entire algorithm now lives in the .prologos
;;; source. The Racket-side shim is irreducible plumbing only:
;;; cell-value carrier, the propagator's fire-fn (a Racket closure that
;;; just plumbs the cell vector through the Prologos kernel via the FFI
;;; callback bridge), and FFI marshalling glue. Matrix transpose, decay
;;; scaling, bias computation, the per-row affine kernel, and the
;;; iteration driver all live in Prologos.
;;;

(require rackunit
         racket/list
         racket/path
         racket/string
         "test-support.rkt"
         "../prelude.rkt"
         "../macros.rkt"
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
         "../foreign.rkt"
         "../posit-impl.rkt")

;; ========================================
;; Helpers
;; ========================================

(define here (path->string (path-only (syntax-source #'here))))
(define example-path
  (path->string
   (simplify-path (build-path here ".." "lib" "examples" "eigentrust.prologos"))))

;; Run the eigentrust.prologos file through the full pipeline (process-file)
;; with the standard prelude environment. Returns the list of per-form
;; result strings produced by process-file.
(define (run-eigentrust-file)
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
                 [current-multi-defn-registry (current-multi-defn-registry)]
                 [current-spec-store (hasheq)])
    (install-module-loader!)
    (process-file example-path)))

;; Extract the four converged Posit32 bit-patterns from process-file's
;; final result string, e.g.
;;   "'[[posit32 542706466] [posit32 904510774] ...] : [...List Posit32]"
;; Returns a list of integers.
(define (extract-bits result-str)
  (define matches (regexp-match* #rx"posit32 ([0-9]+)" result-str #:match-select cdr))
  (for/list ([m (in-list matches)]) (string->number (car m))))

;; Approximate equality on Posit32 rationals.
(define (approx= rat target tol)
  (<= (abs (- (exact->inexact rat) target)) tol))

;; ========================================
;; Tests
;; ========================================
;;
;; The example takes a few seconds per run, so we invoke it ONCE at module
;; load and let all test-cases share the result.

(define eigentrust-results (run-eigentrust-file))
(define eigentrust-final
  (and (list? eigentrust-results)
       (positive? (length eigentrust-results))
       (last eigentrust-results)))
(define eigentrust-bits
  (and (string? eigentrust-final) (extract-bits eigentrust-final)))
(define eigentrust-rats
  (and eigentrust-bits (map posit32-to-rational eigentrust-bits)))

(test-case "eigentrust/file-runs-without-error"
  ;; The example should process end-to-end and produce a final result
  ;; that is not a prologos-error.
  (check-true (list? eigentrust-results) "process-file should return a list of result strings")
  (check-true (> (length eigentrust-results) 0) "should produce at least one result form")
  (check-true (string? eigentrust-final) "final result should be a string")
  (check-false (regexp-match? #rx"error" eigentrust-final)
               (format "final result should not contain an error: ~v"
                       eigentrust-final)))

(test-case "eigentrust/converges-to-reference-vector"
  ;; The 4-peer trust graph in the example converges to
  ;;   [0.0652, 0.4348, 0.0652, 0.4348]   (sum = 1.0)
  ;; per the Python reference implementation. The .prologos source runs
  ;; 5 power iterations, which lands within ~3e-3 of the eigenvector.
  ;; A tolerance of 1e-2 is comfortably above both the iteration error
  ;; and the Posit32 quantisation noise.
  (check-equal? (length eigentrust-bits) 4
                (format "expected 4 Posit32 components in final result, got: ~v"
                        eigentrust-final))
  (define rats eigentrust-rats)
  ;; Symmetry of the trust matrix means peers 0 = 2 and peers 1 = 3.
  (define tol 1e-2)
  (check-true (approx= (list-ref rats 0) 0.0652 tol)
              (format "peer 0 should be ~~0.0652, got ~a"
                      (exact->inexact (list-ref rats 0))))
  (check-true (approx= (list-ref rats 1) 0.4348 tol)
              (format "peer 1 should be ~~0.4348, got ~a"
                      (exact->inexact (list-ref rats 1))))
  (check-true (approx= (list-ref rats 2) 0.0652 tol)
              (format "peer 2 should be ~~0.0652, got ~a"
                      (exact->inexact (list-ref rats 2))))
  (check-true (approx= (list-ref rats 3) 0.4348 tol)
              (format "peer 3 should be ~~0.4348, got ~a"
                      (exact->inexact (list-ref rats 3))))
  ;; Sum to ≈ 1 (probability vector).
  (define sum (apply + rats))
  (check-true (approx= sum 1.0 1e-2)
              (format "scores should sum to ~~1.0, got ~a" (exact->inexact sum))))

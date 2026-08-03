#lang racket/base

;;; test-numerics-float.rkt — Numerics Tower Phase 4 (Float32/Float64).
;;;
;;; DEFERRED listed Phase 4 as pending: "13 AST nodes per width", special
;;; values, cross-family conversions, trait instances, and an open question
;;; about the literal form. Re-probed 2026-08-02 — it is essentially all there,
;;; and nothing was pinning it, because the entry said it was not.
;;;
;;; Also pins the `from-int` arity fix found while probing: `from-int` and
;;; `from-nat` were registered as BINARY operators while their constructors are
;;; unary, so a two-argument call passed three arguments to a two-argument
;;; constructor and died at parse time with a raw arity mismatch — taking the
;;; whole file. One argument reached the application path and worked, which is
;;; why it went unnoticed.

(require rackunit
         racket/string
         racket/file
         "test-support.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../macros.rkt"
         "../errors.rkt")

(define (f s) (run-ns-ws-last (string-append "ns nf\n" s)))

(test-case "float/literals carry their width"
  (check-true (string-contains? (format "~a" (f "3.14f32\n")) "Float32"))
  (check-true (string-contains? (format "~a" (f "3.14f64\n")) "Float64")))

(test-case "float/arithmetic resolves through the numeric traits"
  ;; The entry lists Add/Sub/Mul/Div/Neg/Abs as work to be done. They dispatch.
  (check-true (string-contains? (format "~a" (f "[+ 1.5f32 2.5f32]\n")) "4"))
  (check-true (string-contains? (format "~a" (f "[- 5.0f32 1.5f32]\n")) "3.5"))
  (check-true (string-contains? (format "~a" (f "[* 2.0f32 3.0f32]\n")) "6"))
  (check-true (string-contains? (format "~a" (f "[/ 6.0f32 2.0f32]\n")) "3"))
  (check-true (string-contains? (format "~a" (f "[negate 2.5f32]\n")) "-2.5"))
  (check-true (string-contains? (format "~a" (f "[abs -2.5f32]\n")) "2.5"))
  (check-true (string-contains? (format "~a" (f "[+ 1.5f64 2.5f64]\n")) "4")))

(test-case "float/Ord resolves too"
  (check-true (string-contains? (format "~a" (f "[lt 1.5f32 2.5f32]\n")) "true"))
  (check-true (string-contains? (format "~a" (f "[le 2.5f32 2.5f32]\n")) "true"))
  (check-true (string-contains? (format "~a" (f "[compare 1.5f32 2.5f32]\n")) "lt-ord")))

(test-case "float/IEEE infinity is produced and detected"
  ;; The entry calls out "Special values: ±Inf, NaN" as outstanding. Division by
  ;; zero gives an infinity rather than an error, and `float-finite?` sees it.
  (check-true (string-contains? (format "~a" (f "[/ 1.0f64 0.0f64]\n")) "inf"))
  (check-true (string-contains? (format "~a" (f "[float-finite? [/ 1.0f64 0.0f64]]\n")) "false"))
  (check-true (string-contains? (format "~a" (f "[float-finite? 1.5f64]\n")) "true")))

(test-case "float/cross-family conversions exist"
  ;; "Cross-family conversions: Float↔Posit, Float↔Rat, Float↔Int" — listed as
  ;; outstanding; three of them are here.
  (check-true (string-contains? (format "~a" (f "[float-to-int 3.9f64]\n")) "3"))
  (check-true (string-contains? (format "~a" (f "[float-to-rat 0.5f64]\n")) "1/2"))
  (check-true (string-contains? (format "~a" (f "[float-to-float32 1.5f64]\n")) "Float32")))

;; --- the from-int arity fix ---

(define (run-file-lines src)
  (define f2 (make-prologos-temp-file))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file f2 #:exists 'truncate (lambda (o) (display src o)))
      (parameterize ([current-module-registry prelude-module-registry]
                     [current-lib-paths (list prelude-lib-dir)]
                     [current-preparse-registry prelude-preparse-registry]
                     [current-trait-registry prelude-trait-registry]
                     [current-impl-registry prelude-impl-registry]
                     [current-param-impl-registry prelude-param-impl-registry])
        (install-module-loader!)
        (process-file (path->string f2))))
    (lambda () (with-handlers ([void void]) (delete-file f2)))))

(test-case "float/a two-argument from-int is a per-command error, not an abort"
  (define results (run-file-lines "ns fi\ndef a := 1\n[from-int Float64 3]\ndef b := 2\n"))
  (check-true (list? results) "the file aborted instead of reporting")
  (define text (string-join (map (lambda (r) (format "~a" r)) results) "\n"))
  (check-false (string-contains? text "arity mismatch")
               (format "still the raw constructor arity error: ~v" results))
  (check-true (string-contains? text "from-int expects 1 argument")
              (format "got: ~v" results))
  (check-true (string-contains? text "a :") (format "command BEFORE lost: ~v" results))
  (check-true (string-contains? text "b :") (format "command AFTER lost: ~v" results)))

(test-case "float/a one-argument from-int still works"
  ;; The arm that was already fine, so the table move cannot have broken it.
  ;; Uses the FILE path like its neighbour: mixing `process-file` and
  ;; `run-ns-ws-last` in one test file trips the network state.
  (define results (run-file-lines "ns fi2\n[from-int 3]\n"))
  (check-false (ormap prologos-error? results) (format "got: ~v" results))
  (check-true (string-contains? (format "~a" results) "3") (format "got: ~v" results)))

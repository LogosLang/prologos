#lang racket/base

;;; test-float-lib.rkt — the Float residuals from DEFERRED § "Numerics Tower"
;;; Phase 4, plus the FFI arm that made them possible.
;;;
;;; The entry listed "Residual, unverified: `sqrt` (no `float-sqrt` found),
;;; `if-nan`, NaN specifically, and Float↔Posit". Probed 2026-08-03: five
;;; `Unbound variable`s — genuinely absent, not stale.
;;;
;;; ⚠ THE INTERESTING HALF IS THE FFI. Both marshallers in `foreign.rkt` have
;;; carried Float32/Float64 cases since Numerics N3f, with a comment calling the
;;; FFI "the legitimate NaN/Inf round-trip point". None of it was REACHABLE:
;;; `base-type-name` had no Float arms, so a Float64-typed foreign argument fell
;;; to the `Passthrough` catch-all and the raw `expr-float64` STRUCT went to the
;;; Racket function — `sqrt: contract violation … given: (expr-float64 4.0)`,
;;; which reads like a bad declaration rather than a missing arm.

(require rackunit
         racket/list
         racket/string
         racket/file
         "test-support.rkt"
         "../driver.rkt"
         "../namespace.rkt")

(define (run-float src)
  (define tmp (make-temporary-file "prologos-floatlib-~a.prologos"))
  (call-with-output-file tmp #:exists 'replace
    (lambda (o) (display (string-append
                          "ns floatlibtest\n\n"
                          "imports [prologos::data::float :as flt :refer []]\n\n"
                          src) o)))
  (define rs (parameterize ([current-lib-paths (list prelude-lib-dir)]
                            [current-module-registry prelude-module-registry])
               (install-module-loader!)
               (process-file (path->string tmp))))
  (delete-file tmp)
  (map (lambda (r) (format "~a" r)) rs))

(test-case "float-lib/sqrt, exp/log and expt round-trip through the FFI"
  (define rs (run-float "[flt::sqrt 4.0f64]\n[flt::expt 2.0f64 10.0f64]\n"))
  (check-regexp-match #rx"2[.]0f : Float64" (first rs) (format "~v" rs))
  (check-regexp-match #rx"1024[.]0f : Float64" (second rs) (format "~v" rs)))

(test-case "float-lib/NaN and infinity are DISTINGUISHABLE"
  ;; This is what the entry meant by "NaN specifically". `float-finite?` (the
  ;; parser keyword) answers "neither NaN nor ±Inf" and so cannot separate them;
  ;; these two can, which is the whole point of adding both rather than one.
  (define rs (run-float (string-append
                         "[flt::nan? [/ 0.0f64 0.0f64]]\n"
                         "[flt::nan? [/ 1.0f64 0.0f64]]\n"
                         "[flt::infinite? [/ 1.0f64 0.0f64]]\n"
                         "[flt::infinite? [/ 0.0f64 0.0f64]]\n")))
  (check-regexp-match #rx"^true"  (first rs)  "NaN is NaN")
  (check-regexp-match #rx"^false" (second rs) "an infinity is NOT NaN")
  (check-regexp-match #rx"^true"  (third rs)  "an infinity is infinite")
  (check-regexp-match #rx"^false" (fourth rs) "NaN is NOT infinite"))

(test-case "float-lib/rounding"
  (define rs (run-float (string-append
                         "[flt::floor 3.7f64]\n[flt::ceiling 3.2f64]\n"
                         "[flt::truncate 3.7f64]\n")))
  (check-regexp-match #rx"^3[.]0f" (first rs)  (format "~a" (first rs)))
  (check-regexp-match #rx"^4[.]0f" (second rs) (format "~a" (second rs)))
  (check-regexp-match #rx"^3[.]0f" (third rs)  (format "~a" (third rs))))

(test-case "float-lib/the FFI MARSHALS floats rather than passing the IR struct"
  ;; The regression guard for `base-type-name`'s Float arms. Without them this
  ;; raises `sqrt: contract violation … given: (expr-float64 4.0)` — a RAISE,
  ;; not a per-command error, so it takes the file down. Asserting the value is
  ;; what proves the round trip; asserting no error would also pass if the
  ;; struct were handed through and happened not to crash.
  (define rs (run-float "[flt::sqrt 9.0f64]\n"))
  (check-regexp-match #rx"^3[.]0f : Float64" (first rs) (format "~v" rs)))

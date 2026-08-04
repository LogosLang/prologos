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
         "../namespace.rkt"
         (only-in "../macros.rkt"
                  current-preparse-registry current-trait-registry
                  current-impl-registry current-param-impl-registry))

(define (run-float src)
  (define tmp (make-temporary-file "prologos-floatlib-~a.prologos"))
  (call-with-output-file tmp #:exists 'replace
    (lambda (o) (display (string-append
                          "ns floatlibtest\n\n"
                          "imports [prologos::data::float :as flt :refer []]\n\n"
                          src) o)))
  ;; ⚠ THE REGISTRIES ARE NOT OPTIONAL. A first cut parameterized only
  ;; `current-lib-paths` + `current-module-registry`, and the direct foreign
  ;; calls (`flt::sqrt`) worked fine — they need no dispatch. `to-posit` /
  ;; `to-float` do, and came back "No instance of ToPosit32 for Float64" while
  ;; the identical file through `run-file.rkt` gave `NaR`. That divergence is
  ;; the fixture's, not the compiler's: without the impl/trait registries the
  ;; prelude's instances are invisible. It also passed twice before failing,
  ;; because a batch neighbour had already loaded them into the process.
  (define rs (parameterize ([current-lib-paths (list prelude-lib-dir)]
                            [current-module-registry prelude-module-registry]
                            [current-preparse-registry prelude-preparse-registry]
                            [current-trait-registry prelude-trait-registry]
                            [current-impl-registry prelude-impl-registry]
                            [current-param-impl-registry prelude-param-impl-registry])
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


(test-case "float-lib/if-nan guards the value case"
  ;; The last named item on the Phase 4 residual list, and NOT a compiler
  ;; primitive unlike its posit sibling `p32-if-nar`. That one has to be one
  ;; because there is no other way to test nar-ness; `nan?` gives the test, so
  ;; this is an ordinary `match` — and a match arm is only evaluated when
  ;; selected, which is the laziness the guard exists for.
  (define rs (run-float (string-append
                         "def nn : Float64 := [/ 0.0f64 0.0f64]\n"
                         "[flt::if-nan 0.0f64 [flt::sqrt 4.0f64] nn]\n"
                         "[flt::if-nan 0.0f64 [flt::sqrt 4.0f64] 9.0f64]\n"
                         "[flt::if-nan -1 42 nn]\n")))
  (check-regexp-match #rx"^0[.]0f" (second rs) "NaN takes the nan-case")
  (check-regexp-match #rx"^2[.]0f" (third rs)  "a real value takes the val-case")
  ;; polymorphic in the result type, not Float64-only
  (check-regexp-match #rx"^-1 : Int" (fourth rs)))

(test-case "float-lib/Float<->Posit already round-trips (the residual was stale)"
  ;; The Phase 4 residual listed "Float↔Posit" as unverified. It works, via the
  ;; trait route — `to-float` / `to-posit`, not a `from`-shaped spelling. The
  ;; interesting half is the non-finite one: BOTH NaN and infinity map to NaR,
  ;; which is the posit tower's single non-value, so nothing silently becomes a
  ;; number.
  (define rs (run-float (string-append
                         "def nn : Float64 := [/ 0.0f64 0.0f64]\n"
                         "def ii : Float64 := [/ 1.0f64 0.0f64]\n"
                         "[to-posit nn]\n[to-posit ii]\n[to-float [to-posit 1.5f64]]\n")))
  (check-regexp-match #rx"NaR" (third rs)  "NaN → NaR")
  (check-regexp-match #rx"NaR" (fourth rs) "infinity → NaR")
  (check-regexp-match #rx"^1[.]5f" (fifth rs) "a finite value round-trips exactly"))

#lang racket/base

;;;
;;; Tests for Posit <-> Float cross-scheme conversions — Numerics Q11.
;;;
;;; TOTAL From both directions per the posit standard's prescribed conversion:
;;;   Posit -> Float: NaR -> NaN; finite posits pivot exactly through Rat.
;;;   Float -> Posit: NaN/+Inf/-Inf -> NaR; finite floats pivot through Rat,
;;;   then round-to-nearest posit (clamped to maxpos, never NaR).
;;; Zero new prim-ops: pure composition in conversions.prologos —
;;; p*-if-nar guards the Posit->Float pivot (p*-to-rat errors on NaR);
;;; float-finite? guards the Float->Posit pivot (the N3e-rest pattern).
;;; Also covers the Q11 retrofit: posit-widening From instances are now
;;; NaR-correct (NaR widens to NaR, matching the Racket posit-widen path).
;;;
;;; NOTE: numeric-join gains NOTHING here — mixed Posit/Float arithmetic
;;; stays a type error (the locked N3d absence).
;;;

(require rackunit
         racket/list
         racket/string
         "test-support.rkt")

;; One env load per direction: a single multi-form WS program through
;; run-ns-ws-all; evals come back in order as "value : Type" strings.

(define (ws-all . lines)
  (run-ns-ws-all (string-join (list* "ns t"
                                     "require [prologos::core::conversions :refer [From From-from]]"
                                     lines)
                              "\n")))

(define (check-has actual substr [msg #f])
  (check-true (string-contains? actual substr)
              (or msg (format "expected ~s to contain ~s" actual substr))))

;; ========================================
;; Direction A: Posit -> Float (8 pairs) + NaR -> NaN + widening retrofit
;; ========================================

(define results-a
  (ws-all
   ;; happy paths, all 8 width pairs (posit8 64 = 1.0, posit16 16384 = 1.0)
   "eval [From-from Posit8  Float64 Posit8-Float64--From--dict  [posit8 64]]"
   "eval [From-from Posit16 Float64 Posit16-Float64--From--dict [posit16 16384]]"
   "eval [From-from Posit32 Float64 Posit32-Float64--From--dict ~1.5]"
   "eval [From-from Posit64 Float64 Posit64-Float64--From--dict [p64-from-rat 3/2]]"
   "eval [From-from Posit8  Float32 Posit8-Float32--From--dict  [posit8 64]]"
   "eval [From-from Posit16 Float32 Posit16-Float32--From--dict [posit16 16384]]"
   "eval [From-from Posit32 Float32 Posit32-Float32--From--dict ~2.5]"
   "eval [From-from Posit64 Float32 Posit64-Float32--From--dict [p64-from-rat 1/2]]"
   ;; NaR -> NaN (both float widths; posit8 128 / posit32 2147483648 = NaR)
   "eval [From-from Posit32 Float64 Posit32-Float64--From--dict [posit32 2147483648]]"
   "eval [From-from Posit8  Float32 Posit8-Float32--From--dict  [posit8 128]]"
   ;; widening retrofit: NaR widens to NaR; finite widening unchanged
   "eval [From-from Posit8 Posit16 Posit8-Posit16--From--dict [posit8 128]]"
   "eval [From-from Posit8 Posit16 Posit8-Posit16--From--dict [posit8 64]]"))

(test-case "posit->float happy paths (all 8 width pairs)"
  (check-equal? (list-ref results-a 0) "1.0f : Float64")
  (check-equal? (list-ref results-a 1) "1.0f : Float64")
  (check-equal? (list-ref results-a 2) "1.5f : Float64")
  (check-equal? (list-ref results-a 3) "1.5f : Float64")
  (check-equal? (list-ref results-a 4) "1f32 : Float32")
  (check-equal? (list-ref results-a 5) "1f32 : Float32")
  (check-equal? (list-ref results-a 6) "2.5f32 : Float32")
  (check-equal? (list-ref results-a 7) "0.5f32 : Float32"))

(test-case "posit NaR -> float NaN (posit-standard total mapping)"
  (check-has (list-ref results-a 8) "nan")
  (check-has (list-ref results-a 8) "Float64")
  (check-has (list-ref results-a 9) "nan")
  (check-has (list-ref results-a 9) "Float32"))

(test-case "posit widening is NaR-correct after the Q11 retrofit"
  (check-has (list-ref results-a 10) "NaR")
  (check-has (list-ref results-a 10) "Posit16")
  ;; finite widening behavior unchanged
  (check-has (list-ref results-a 11) "~1")
  (check-has (list-ref results-a 11) "Posit16"))

;; ========================================
;; Direction B: Float -> Posit (8 pairs) + NaN/±Inf -> NaR + saturation
;; ========================================

(define results-b
  (ws-all
   ;; happy paths, all 8 width pairs
   "eval [From-from Float64 Posit8  Float64-Posit8--From--dict  1.0f64]"
   "eval [From-from Float64 Posit16 Float64-Posit16--From--dict 2.0f64]"
   "eval [From-from Float64 Posit32 Float64-Posit32--From--dict 1.5f64]"
   "eval [From-from Float64 Posit64 Float64-Posit64--From--dict 1.5f64]"
   "eval [From-from Float32 Posit8  Float32-Posit8--From--dict  2.0f32]"
   "eval [From-from Float32 Posit16 Float32-Posit16--From--dict 1.5f32]"
   "eval [From-from Float32 Posit32 Float32-Posit32--From--dict 2.5f32]"
   "eval [From-from Float32 Posit64 Float32-Posit64--From--dict 0.5f32]"
   ;; NaN / +Inf / -Inf -> NaR (posit-standard: all non-reals collapse to NaR)
   "eval [From-from Float64 Posit32 Float64-Posit32--From--dict [f64/ 0.0f64 0.0f64]]"
   "eval [From-from Float64 Posit32 Float64-Posit32--From--dict [f64/ 1.0f64 0.0f64]]"
   "eval [From-from Float64 Posit32 Float64-Posit32--From--dict [f64/ -1.0f64 0.0f64]]"
   "eval [From-from Float32 Posit16 Float32-Posit16--From--dict [f32/ 0.0f32 0.0f32]]"
   ;; saturation regression (audit gap): huge Float64 -> Posit8 clamps to
   ;; maxpos — identical to encoding the same rational directly, never NaR
   "eval [From-from Float64 Posit8 Float64-Posit8--From--dict 1000000.0f64]"
   "eval [p8-from-rat 1000000]"))

(test-case "float->posit happy paths (all 8 width pairs)"
  (check-equal? (list-ref results-b 0) "~1 : Posit8")
  (check-equal? (list-ref results-b 1) "~2 : Posit16")
  (check-equal? (list-ref results-b 2) "~1.5 : Posit32")
  (check-equal? (list-ref results-b 3) "~1.5 : Posit64")
  (check-equal? (list-ref results-b 4) "~2 : Posit8")
  (check-equal? (list-ref results-b 5) "~1.5 : Posit16")
  (check-equal? (list-ref results-b 6) "~2.5 : Posit32")
  (check-equal? (list-ref results-b 7) "~0.5 : Posit64"))

(test-case "float NaN/+Inf/-Inf -> posit NaR (posit-standard total mapping)"
  (for ([i (in-list '(8 9 10))])
    (check-has (list-ref results-b i) "NaR")
    (check-has (list-ref results-b i) "Posit32"))
  (check-has (list-ref results-b 11) "NaR")
  (check-has (list-ref results-b 11) "Posit16"))

(test-case "big float -> small posit saturates to maxpos (never NaR)"
  (check-equal? (list-ref results-b 12) (list-ref results-b 13))
  (check-false (string-contains? (list-ref results-b 12) "NaR")))

#lang racket/base

;;;
;;; Tests for the to-X source-generic conversion family — Numerics N6d-ii.
;;;
;;; Per-target traits (ToFloat64/32, ToPosit8/16/32/64, ToRat, ToInt) dispatching
;;; on the SOURCE type; bare method names first-class via the N6d-i auto-derive;
;;; to-float/to-posit default-width aliases. TOTAL across Posit<->Float
;;; (posit-standard NaR<->NaN); to-rat/to-int PANIC on non-finite / NaR.
;;; Pure composition over existing prims (zero new AST nodes); rat-numer/rat-denom
;;; registered in pnet-serialize for this (their first cached-body use).
;;;

(require rackunit
         racket/list
         racket/string
         "test-support.rkt")

(define (ws-all . lines)
  (run-ns-ws-all (string-join (list* "ns t" lines) "\n")))

;; panicking evals come back as a (prologos-error #f "panic: ...") struct rather
;; than a string; coerce to its readable form (transparent struct → message shows).
(define (as-str x) (if (string? x) x (format "~s" x)))
(define (check-has actual substr [msg #f])
  (check-true (string-contains? (as-str actual) substr)
              (or msg (format "expected ~s to contain ~s" actual substr))))

;; ========================================
;; to-float64 / to-float32 (total; NaR -> NaN)
;; ========================================

(define r-float
  (ws-all
   "eval [to-float64 42]"                ; Int -> F64
   "eval [to-float64 3/4]"               ; Rat -> F64
   "eval [to-float64 1.5]"               ; Posit32 -> F64
   "eval [to-float64 2.5f32]"            ; Float32 -> F64 (widen via f64+ idiom)
   "eval [to-float64 5.0f64]"            ; Float64 -> F64 (identity)
   "eval [to-float32 100]"              ; Int -> F32
   "eval [to-float32 3/4]"              ; Rat -> F32
   "eval [to-float32 2.5f64]"           ; Float64 -> F32 (narrow)
   "eval [to-float64 [p32/ 1.0 0.0]]")) ; Posit32 NaR -> Float64 NaN

(test-case "to-float64 / to-float32 across sources"
  (check-equal? (list-ref r-float 0) "42.0f : Float64")
  (check-equal? (list-ref r-float 1) "0.75f : Float64")
  (check-equal? (list-ref r-float 2) "1.5f : Float64")
  (check-equal? (list-ref r-float 3) "2.5f : Float64")
  (check-equal? (list-ref r-float 4) "5.0f : Float64")
  (check-equal? (list-ref r-float 5) "100f32 : Float32")
  (check-equal? (list-ref r-float 6) "0.75f32 : Float32")
  (check-equal? (list-ref r-float 7) "2.5f32 : Float32"))

(test-case "to-float64: posit NaR -> float NaN (total)"
  (check-has (list-ref r-float 8) "nan")
  (check-has (list-ref r-float 8) "Float64"))

;; ========================================
;; to-posit* (total; NaN/±Inf/NaR -> NaR); widen / narrow / identity
;; ========================================

(define r-posit
  (ws-all
   "eval [to-posit32 42]"               ; Int -> P32
   "eval [to-posit32 3/2]"              ; Rat -> P32
   "eval [to-posit32 3.5f64]"           ; Float64 -> P32 (finite)
   "eval [to-posit32 2.5f32]"           ; Float32 -> P32 (finite)
   "eval [to-posit8 1.5]"               ; Posit32 -> Posit8 (narrow)
   "eval [to-posit64 1.5]"              ; Posit32 -> Posit64 (widen)
   "eval [to-posit16 3.5f64]"           ; Float64 -> P16
   "eval [to-posit32 [f64/ 1.0f64 0.0f64]]"   ; +Inf -> NaR
   "eval [to-posit8 [p32/ 1.0 0.0]]"))  ; Posit32 NaR -> Posit8 NaR (total)

(test-case "to-posit* across sources (widen / narrow / finite float)"
  (check-equal? (list-ref r-posit 0) "42.0 : Posit32")
  (check-equal? (list-ref r-posit 1) "1.5 : Posit32")
  (check-equal? (list-ref r-posit 2) "3.5 : Posit32")
  (check-equal? (list-ref r-posit 3) "2.5 : Posit32")
  (check-equal? (list-ref r-posit 4) "1.5p8 : Posit8")
  (check-equal? (list-ref r-posit 5) "1.5p : Posit64")
  (check-equal? (list-ref r-posit 6) "3.5p16 : Posit16"))

(test-case "to-posit*: non-finite float -> NaR; posit NaR -> NaR"
  (check-has (list-ref r-posit 7) "NaR")
  (check-has (list-ref r-posit 7) "Posit32")
  (check-has (list-ref r-posit 8) "NaR")
  (check-has (list-ref r-posit 8) "Posit8"))

;; ========================================
;; to-rat / to-int (finite): exact / truncate-toward-zero
;; ========================================

(define r-exact
  (ws-all
   "eval [to-rat 5]"                    ; Int -> Rat
   "eval [to-rat 1.5]"                  ; Posit32 -> Rat (exact: 3/2)
   "eval [to-rat 0.75f64]"              ; Float64 -> Rat
   "eval [to-int 42]"                   ; Int -> Int (identity)
   "eval [to-int 3/4]"                  ; Rat -> Int (trunc -> 0)
   "eval [to-int -7/2]"                 ; Rat -> Int (trunc toward zero -> -3)
   "eval [to-int 3.9f64]"               ; Float64 -> Int (trunc -> 3)
   "eval [to-int 2.0]"                  ; Posit32 -> Int (via rat pivot)
   "eval [to-float 42]"                 ; alias -> Float64
   "eval [to-posit 3.5f64]"))           ; alias -> Posit32

(test-case "to-rat / to-int (finite) + aliases"
  (check-equal? (list-ref r-exact 0) "5 : Rat")
  (check-equal? (list-ref r-exact 1) "3/2 : Rat")
  (check-equal? (list-ref r-exact 2) "3/4 : Rat")
  (check-equal? (list-ref r-exact 3) "42 : Int")
  (check-equal? (list-ref r-exact 4) "0 : Int")
  (check-equal? (list-ref r-exact 5) "-3 : Int")
  (check-equal? (list-ref r-exact 6) "3 : Int")
  (check-equal? (list-ref r-exact 7) "2 : Int")
  (check-equal? (list-ref r-exact 8) "42.0f : Float64")
  (check-equal? (list-ref r-exact 9) "3.5 : Posit32"))

;; ========================================
;; to-rat / to-int PANIC on non-finite / NaR (top-level command position)
;; ========================================

(define r-panic
  (ws-all
   "eval [to-int [f64/ 1.0f64 0.0f64]]"     ; +Inf
   "eval [to-int [f64/ 0.0f64 0.0f64]]"     ; NaN
   "eval [to-int [p32/ 1.0 0.0]]"           ; Posit32 NaR
   "eval [to-rat [f64/ -1.0f64 0.0f64]]"    ; -Inf
   "eval [to-rat [p64/ 1.0p64 0.0p64]]"))   ; Posit64 NaR

(test-case "to-int / to-rat panic on non-finite / NaR"
  (for ([i (in-list '(0 1 2))])
    (check-has (list-ref r-panic i) "panic")
    (check-has (list-ref r-panic i) "to-int"))
  (check-has (list-ref r-panic 3) "panic")
  (check-has (list-ref r-panic 3) "to-rat")
  (check-has (list-ref r-panic 4) "panic")
  (check-has (list-ref r-panic 4) "to-rat"))

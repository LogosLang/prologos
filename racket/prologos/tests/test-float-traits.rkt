#lang racket/base

;;;
;;; Tests for Float trait instances — Numerics N6d-iii.
;;;
;;; Add/Sub/Mul/Div/Neg/Abs + Eq/Ord/PartialOrd + AdditiveIdentity/
;;; MultiplicativeIdentity for Float32/Float64, making Float a Num/Fractional
;;; citizen (sum/product/where(Num A)/sorting work).
;;;
;;; Eq/Ord are TOTAL (Option B, IEEE 754 totalOrder spirit): NaN is a single top
;;; equivalence class (NaN==NaN, +0==-0) — lawful for containers/sorting. The raw
;;; f*-eq/f*-lt prims keep IEEE operator semantics; PartialOrd Float is the
;;; operator-honest partial order (NaN -> none). Realized with zero new prims via
;;; the [not [f*-eq x x]] NaN idiom. Also covers the paired posit-standard fix
;;; (posit-eq?/lt?/le?): NaR==NaR, NaR < every real (NaR least).
;;;

(require rackunit
         racket/list
         racket/string
         "test-support.rkt")

(define (ws-all . lines)
  (run-ns-ws-all (string-join (list* "ns t" lines) "\n")))

(define (check-has actual substr [msg #f])
  (check-true (string-contains? (if (string? actual) actual (format "~s" actual)) substr)
              (or msg (format "expected ~s to contain ~s" actual substr))))

;; ========================================
;; Float arithmetic via traits + Num/Fractional citizenship
;; ========================================

(define r-arith
  (ws-all
   "eval [mul 3.0f32 4.0f32]"          ; derived Mul wrapper + Float instance
   "eval [neg 5.0f64]"
   "eval [abs -2.5f64]"
   "eval [+ 1.5f64 2.0f64]"            ; generic operator (numeric-join path)
   "eval [sum Float64--Add--dict Float64--AdditiveIdentity--dict '[1.0f64 2.0f64 3.0f64]]"
   "eval [product Float64--Mul--dict Float64--MultiplicativeIdentity--dict '[2.0f64 3.0f64 4.0f64]]"))

(test-case "Float arithmetic traits + sum/product (Num citizen)"
  (check-equal? (list-ref r-arith 0) "12f32 : Float32")
  (check-equal? (list-ref r-arith 1) "-5.0f : Float64")
  (check-equal? (list-ref r-arith 2) "2.5f : Float64")
  (check-equal? (list-ref r-arith 3) "3.5f : Float64")
  (check-equal? (list-ref r-arith 4) "6.0f : Float64")     ; sum
  (check-equal? (list-ref r-arith 5) "24.0f : Float64"))    ; product

;; ========================================
;; Eq Float — TOTAL (reflexive; NaN==NaN; +0==-0)
;; ========================================

(define r-eq
  (ws-all
   "eval [eq? 1.5f64 1.5f64]"
   "eval [eq? 1.5f64 2.0f64]"
   "eval [eq? [f64/ 0.0f64 0.0f64] [f64/ 0.0f64 0.0f64]]"   ; NaN==NaN -> true (reflexive)
   "eval [eq? 0.0f64 -0.0f64]"                               ; +0 == -0
   "eval [eq? 3.0f32 3.0f32]"
   "eval [eq? [f32/ 0.0f32 0.0f32] [f32/ 0.0f32 0.0f32]]"))  ; f32 NaN==NaN

(test-case "Eq Float: total equality (NaN reflexive, +0==-0)"
  (check-equal? (list-ref r-eq 0) "true : Bool")
  (check-equal? (list-ref r-eq 1) "false : Bool")
  (check-equal? (list-ref r-eq 2) "true : Bool")
  (check-equal? (list-ref r-eq 3) "true : Bool")
  (check-equal? (list-ref r-eq 4) "true : Bool")
  (check-equal? (list-ref r-eq 5) "true : Bool"))

;; ========================================
;; Ord Float — TOTAL, NaN as a single top equivalence class
;; ========================================

(define r-ord
  (ws-all
   "eval [compare 1.0f64 2.0f64]"                       ; lt
   "eval [compare 2.0f64 1.0f64]"                       ; gt
   "eval [compare 1.0f64 1.0f64]"                       ; eq (reflexive)
   "eval [compare [f64/ 0.0f64 0.0f64] 5.0f64]"         ; NaN vs real -> gt (NaN max)
   "eval [compare 5.0f64 [f64/ 0.0f64 0.0f64]]"         ; real vs NaN -> lt
   "eval [compare [f64/ 0.0f64 0.0f64] [f64/ 0.0f64 0.0f64]]"  ; NaN vs NaN -> eq
   "eval [compare [f64/ -1.0f64 0.0f64] 0.0f64]"        ; -Inf < 0
   "eval [compare 0.0f64 [f64/ 1.0f64 0.0f64]]"))       ; 0 < +Inf

(test-case "Ord Float: total order, NaN as top (lawful)"
  (check-has (list-ref r-ord 0) "lt-ord")
  (check-has (list-ref r-ord 1) "gt-ord")
  (check-has (list-ref r-ord 2) "eq-ord")
  (check-has (list-ref r-ord 3) "gt-ord")
  (check-has (list-ref r-ord 4) "lt-ord")
  (check-has (list-ref r-ord 5) "eq-ord")
  (check-has (list-ref r-ord 6) "lt-ord")
  (check-has (list-ref r-ord 7) "lt-ord"))

;; ========================================
;; PartialOrd Float — IEEE operator-honest (NaN incomparable -> none)
;; ========================================

(define r-partial
  (ws-all
   "eval [partial-compare 1.0f64 2.0f64]"                 ; some lt
   "eval [partial-compare 2.0f64 2.0f64]"                 ; some eq
   "eval [partial-compare [f64/ 0.0f64 0.0f64] 5.0f64]"   ; NaN -> none
   "eval [partial-compare 5.0f64 [f64/ 0.0f64 0.0f64]]")) ; NaN -> none

(test-case "PartialOrd Float: NaN incomparable (none)"
  (check-has (list-ref r-partial 0) "some")
  (check-has (list-ref r-partial 0) "lt-ord")
  (check-has (list-ref r-partial 1) "eq-ord")
  (check-has (list-ref r-partial 2) "none")
  (check-has (list-ref r-partial 3) "none"))

;; ========================================
;; Posit-standard fix (paired): NaR==NaR, NaR < every real (NaR least)
;; ========================================

(define r-posit
  (ws-all
   "eval [eq? [p32/ 1.0 0.0] [p32/ 1.0 0.0]]"    ; NaR == NaR -> true (was false)
   "eval [eq? 1.5 [p32/ 1.0 0.0]]"                ; NaR != real
   "eval [compare [p32/ 1.0 0.0] 5.0]"            ; NaR < real -> lt (NaR least)
   "eval [compare 5.0 [p32/ 1.0 0.0]]"            ; real > NaR -> gt
   "eval [compare [p32/ 1.0 0.0] [p32/ 1.0 0.0]]")) ; NaR vs NaR -> eq

(test-case "Posit 2022-standard fix: NaR reflexive + least element"
  (check-equal? (list-ref r-posit 0) "true : Bool")
  (check-equal? (list-ref r-posit 1) "false : Bool")
  (check-has (list-ref r-posit 2) "lt-ord")
  (check-has (list-ref r-posit 3) "gt-ord")
  (check-has (list-ref r-posit 4) "eq-ord"))

;; ========================================
;; Ord Float LAWS with NaN/±Inf in the mix (Option B must be a genuine total order)
;; ========================================

(define r-laws
  (ws-all
   ;; transitivity chain  -Inf < 5 < NaN  =>  -Inf < NaN
   "eval [compare [f64/ -1.0f64 0.0f64] 5.0f64]"          ; -Inf < 5   -> lt
   "eval [compare 5.0f64 [f64/ 0.0f64 0.0f64]]"           ; 5 < NaN    -> lt
   "eval [compare [f64/ -1.0f64 0.0f64] [f64/ 0.0f64 0.0f64]]"  ; -Inf < NaN -> lt (transitive)
   ;; antisymmetry: compare a b = lt  <=>  compare b a = gt
   "eval [compare [f64/ 0.0f64 0.0f64] 5.0f64]"           ; NaN vs 5   -> gt
   "eval [compare [f64/ -1.0f64 0.0f64] [f64/ 1.0f64 0.0f64]]"  ; -Inf < +Inf -> lt
   "eval [compare [f64/ 1.0f64 0.0f64] [f64/ -1.0f64 0.0f64]]"  ; +Inf > -Inf -> gt
   ;; Eq / Ord consistency: eq? x y  <=>  compare x y = eq
   "eval [compare 0.0f64 -0.0f64]"))                       ; +0 vs -0  -> eq (matches eq?)

(test-case "Ord Float is a genuine total order (transitive + antisymmetric) incl. NaN/±Inf"
  (check-has (list-ref r-laws 0) "lt-ord")   ; -Inf < 5
  (check-has (list-ref r-laws 1) "lt-ord")   ; 5 < NaN
  (check-has (list-ref r-laws 2) "lt-ord")   ; -Inf < NaN (transitivity holds)
  (check-has (list-ref r-laws 3) "gt-ord")   ; NaN > 5 (antisymmetric w/ r-laws[1])
  (check-has (list-ref r-laws 4) "lt-ord")   ; -Inf < +Inf
  (check-has (list-ref r-laws 5) "gt-ord")   ; +Inf > -Inf (antisymmetric)
  (check-has (list-ref r-laws 6) "eq-ord"))  ; +0 == -0 (consistent with Eq)

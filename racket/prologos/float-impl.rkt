#lang racket/base

;; ============================================================================
;; float-impl.rkt — IEEE-754 Float32/Float64 compute kernel (Numerics N3b)
;; ============================================================================
;;
;; Float values are native Racket flonums (double-precision). Float64 ops
;; delegate directly to `racket/flonum`. Float32 ops compute in double then
;; round the RESULT to single precision via `flsingle`, so a Float32 value
;; stays single-precision on the double-backed runtime (per the N3b design:
;; "Float32 ops round via (flsingle …)"). Comparisons need no rounding.
;;
;; IEEE semantics fall out of the native ops for free:
;;   - NaN ≠ NaN              ((fl= +nan.0 +nan.0) → #f)
;;   - -0.0 = +0.0            ((fl= -0.0 0.0)      → #t)
;;   - 1.0/0.0 = +inf.0 ; (-1.0)/0.0 = -inf.0 ; 0.0/0.0 = +nan.0 ; sqrt(neg) = +nan.0
;; so there is NO posit-style `if-nar` analog — NaN/±Inf are ordinary flonums.
;;
;; Negation uses (fl* -1.0 a) (correct IEEE sign on 0.0/±inf/nan; verified).

(require racket/flonum)

(provide
 ;; Float64 (native double)
 float64-add float64-sub float64-mul float64-div
 float64-neg float64-abs float64-sqrt
 float64-lt? float64-le? float64-eq?
 ;; Float32 (single-precision rounded results)
 float32-add float32-sub float32-mul float32-div
 float32-neg float32-abs float32-sqrt
 float32-lt? float32-le? float32-eq?)

;; ---- Float64: direct double-precision delegation -------------------------
(define (float64-add a b) (fl+ a b))
(define (float64-sub a b) (fl- a b))
(define (float64-mul a b) (fl* a b))
(define (float64-div a b) (fl/ a b))
(define (float64-neg a)   (fl* -1.0 a))
(define (float64-abs a)   (flabs a))
(define (float64-sqrt a)  (flsqrt a))
(define (float64-lt? a b) (fl< a b))
(define (float64-le? a b) (fl<= a b))
(define (float64-eq? a b) (fl= a b))

;; ---- Float32: same ops, result rounded to single precision ---------------
;; Arithmetic results are rounded via flsingle so the stored flonum is the
;; nearest single-precision value. Comparisons return booleans (no rounding).
(define (float32-add a b) (flsingle (fl+ a b)))
(define (float32-sub a b) (flsingle (fl- a b)))
(define (float32-mul a b) (flsingle (fl* a b)))
(define (float32-div a b) (flsingle (fl/ a b)))
(define (float32-neg a)   (flsingle (fl* -1.0 a)))
(define (float32-abs a)   (flsingle (flabs a)))
(define (float32-sqrt a)  (flsingle (flsqrt a)))
(define (float32-lt? a b) (fl< a b))
(define (float32-le? a b) (fl<= a b))
(define (float32-eq? a b) (fl= a b))

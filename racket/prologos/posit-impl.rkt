#lang racket/base

;;;
;;; POSIT8 IMPLEMENTATION
;;; Pure Racket implementation of 8-bit posit arithmetic (2022 Standard, es=2).
;;;
;;; All posit8 values are represented as exact integers 0–255 (8-bit unsigned).
;;; Internally, arithmetic operates via exact rationals: decode → compute → encode.
;;;
;;; Posit8 format:
;;;   sign (1 bit) | regime (variable) | exponent (es=2 bits max) | fraction (remaining)
;;;
;;; Value = (-1)^sign × useed^regime × 2^exponent × (1 + fraction)
;;; where useed = 2^(2^es) = 2^4 = 16
;;;
;;; Special values:
;;;   Zero = 0x00 (00000000)
;;;   NaR  = 0x80 (10000000) — Not a Real
;;;

(require racket/match
         racket/list)

(provide
 ;; Constants
 posit8-zero posit8-one posit8-neg-one posit8-nar
 posit8-maxpos posit8-minpos
 ;; Decode/encode
 posit8-decode posit8-encode
 ;; Arithmetic
 posit8-add posit8-sub posit8-mul posit8-div
 posit8-neg posit8-abs posit8-sqrt
 ;; Comparison
 posit8-eq? posit8-lt? posit8-le?
 ;; Predicates
 posit8-nar? posit8-zero?
 ;; Conversion
 posit8-from-nat posit8-to-rational
 ;; Display
 posit8-display)

;; ========================================
;; Constants
;; ========================================

(define posit8-zero    0)     ; 0x00 — value 0
(define posit8-one     64)    ; 0x40 — value 1
(define posit8-neg-one 192)   ; 0xC0 — value -1
(define posit8-nar     128)   ; 0x80 — Not a Real
(define posit8-maxpos  127)   ; 0x7F — maximum positive value (64)
(define posit8-minpos  1)     ; 0x01 — minimum positive value

;; Posit8 parameters
(define es 2)                 ; exponent size (fixed for 2022 Standard)
(define nbits 8)              ; total bits
(define useed 16)             ; 2^(2^es) = 2^4 = 16

;; ========================================
;; Predicates
;; ========================================

(define (posit8-nar? v) (= v 128))
(define (posit8-zero? v) (= v 0))

;; ========================================
;; Bit manipulation helpers
;; ========================================

;; Extract bit at position pos (0 = LSB) from an nbits-bit value
(define (bit-at v pos)
  (bitwise-and 1 (arithmetic-shift v (- pos))))

;; Convert unsigned 8-bit to signed (two's complement)
(define (u8->s8 v)
  (if (>= v 128) (- v 256) v))

;; Convert signed back to unsigned 8-bit
(define (s8->u8 v)
  (if (< v 0) (+ v 256) v))

;; ========================================
;; Decoding: posit8 bit pattern → rational
;; ========================================

;; Returns 'nar for NaR, 0 for zero, or an exact rational.
(define (posit8-decode v)
  (cond
    [(posit8-nar? v) 'nar]
    [(posit8-zero? v) 0]
    [else
     (let* ([sign (bit-at v 7)]            ; sign bit
            [abs-bits (if (= sign 1)
                         (bitwise-and (- 256 v) #xFF) ; two's complement negate
                         v)]
            ;; Now abs-bits is the positive posit representation
            ;; Extract regime from bits 6 down to 0
            [regime-msb (bit-at abs-bits 6)])
       (let loop ([pos 5]                    ; start scanning from bit 5
                   [run-len 1])              ; regime-msb already counted
         ;; Count run of identical bits (same as regime-msb)
         (if (and (>= pos 0)
                  (= (bit-at abs-bits pos) regime-msb))
             (loop (- pos 1) (+ run-len 1))
             ;; Run ended. pos is now pointing at the terminator bit (or -1 if all same)
             ;; After the terminator, remaining bits are: exponent then fraction
             (let* ([regime-val (if (= regime-msb 1)
                                    (- run-len 1)    ; k ones → regime = k-1
                                    (- run-len))]    ; k zeros → regime = -k
                    ;; Remaining bit positions: pos-1 down to 0 (pos is terminator or -1)
                    [remaining-start (- pos 1)]       ; first bit after terminator
                    [remaining-bits (if (>= remaining-start 0)
                                       (+ remaining-start 1)
                                       0)]
                    ;; Extract exponent (up to es bits)
                    [exp-bits (min es remaining-bits)]
                    [exp-val (if (> exp-bits 0)
                                (let ([raw (arithmetic-shift
                                            (bitwise-and abs-bits
                                                         (- (arithmetic-shift 1 (+ remaining-start 1)) 1))
                                            (- (- remaining-bits exp-bits)))])
                                  ;; Left-justify: shift left by (es - exp-bits) if truncated
                                  (arithmetic-shift raw (- es exp-bits)))
                                0)]
                    ;; Extract fraction bits (remaining after exponent)
                    [frac-bits (- remaining-bits exp-bits)]
                    [frac-val (if (> frac-bits 0)
                                  (bitwise-and abs-bits
                                               (- (arithmetic-shift 1 frac-bits) 1))
                                  0)]
                    ;; Compute value: useed^regime × 2^exp × (1 + frac/2^frac-bits)
                    [scale (* (expt useed regime-val) (expt 2 exp-val))]
                    [mantissa (if (> frac-bits 0)
                                  (+ 1 (/ frac-val (expt 2 frac-bits)))
                                  1)]
                    [abs-value (* scale mantissa)])
               (if (= sign 1) (- abs-value) abs-value)))))]))

;; ========================================
;; Encoding: rational → posit8 bit pattern
;; ========================================

;; Encode an exact rational as posit8 with round-to-nearest-even.
(define (posit8-encode r)
  (cond
    [(eq? r 'nar) posit8-nar]
    [(zero? r) posit8-zero]
    [else
     (let* ([sign (if (negative? r) 1 0)]
            [abs-r (abs r)]
            ;; Determine regime: find k such that useed^k ≤ abs-r < useed^(k+1)
            ;; regime = floor(log_useed(abs-r))
            ;; But we need to handle this carefully with exact arithmetic
            [regime (regime-for abs-r)]
            ;; Factor out regime: remainder = abs-r / useed^regime
            [remainder-val (/ abs-r (expt useed regime))]
            ;; Determine exponent: find e such that 2^e ≤ remainder < 2^(e+1)
            [exp-val (exponent-for remainder-val)]
            ;; Factor out exponent: fraction-plus-one = remainder / 2^exp
            [frac-plus-one (/ remainder-val (expt 2 exp-val))]
            ;; frac-plus-one should be in [1, 2)
            ;; fraction = frac-plus-one - 1
            [frac-val (- frac-plus-one 1)])
       ;; Now encode into bits
       (encode-bits sign regime exp-val frac-val))]))

;; Find the regime value k such that useed^k ≤ |x| < useed^(k+1)
;; Regime ranges from -(nbits-2) to (nbits-2)
(define (regime-for x)
  (cond
    [(>= x 1)
     ;; Positive regime: count powers of useed
     (let loop ([k 0])
       (if (or (>= k (- nbits 2))
               (< x (expt useed (+ k 1))))
           k
           (loop (+ k 1))))]
    [else
     ;; Negative regime: x < 1
     (let loop ([k -1])
       (if (or (<= k (- 2 nbits))
               (>= x (expt useed k)))
           k
           (loop (- k 1))))]))

;; Find exponent e in [0, 2^es - 1] such that 2^e ≤ remainder < 2^(e+1)
;; where remainder = |x| / useed^regime, so remainder ∈ [1, useed)
(define (exponent-for remainder)
  (let ([max-exp (- (expt 2 es) 1)])  ; 3 for es=2
    (let loop ([e 0])
      (if (or (>= e max-exp)
              (< remainder (expt 2 (+ e 1))))
          e
          (loop (+ e 1))))))

;; Encode sign, regime, exponent, fraction into 8-bit posit
(define (encode-bits sign regime exp-val frac-val)
  (let* (;; Regime bits: if regime >= 0, emit (regime+1) ones then a zero
         ;; if regime < 0, emit (-regime) zeros then a one
         [regime-bits-list (if (>= regime 0)
                               (append (make-list (+ regime 1) 1)
                                       (list 0))       ; terminator
                               (append (make-list (- regime) 0)
                                       (list 1)))]     ; terminator
         ;; Available bits after sign = 7
         [available 7]
         ;; Truncate regime if needed (for extreme regimes)
         [regime-bits (if (> (length regime-bits-list) available)
                          (take regime-bits-list available)
                          regime-bits-list)]
         [bits-after-regime (- available (length regime-bits))]
         ;; Exponent bits (up to es, truncated if not enough room)
         [exp-bits-count (min es bits-after-regime)]
         [exp-bits-list (integer->bit-list exp-val es exp-bits-count)]
         [bits-after-exp (- bits-after-regime exp-bits-count)]
         ;; Fraction bits
         [frac-bits-list (fraction->bit-list frac-val bits-after-exp)]
         ;; Check for rounding
         [all-bits (append regime-bits exp-bits-list frac-bits-list)]
         ;; Pad to exactly 7 bits
         [padded (if (< (length all-bits) 7)
                     (append all-bits (make-list (- 7 (length all-bits)) 0))
                     (take all-bits 7))]
         ;; Convert bit list to integer
         [abs-posit (bit-list->integer padded)]
         ;; Apply rounding
         [rounded (round-posit abs-posit sign regime exp-val frac-val
                               bits-after-exp)])
    ;; Apply sign via two's complement
    (if (= sign 1)
        (s8->u8 (- rounded))
        rounded)))

;; Convert integer to bit list (MSB first), taking only the top count bits
(define (integer->bit-list val total-bits count)
  (for/list ([i (in-range count)])
    (bit-at val (- total-bits 1 i))))

;; Convert fraction (0 ≤ frac < 1) to bit list of given length
(define (fraction->bit-list frac count)
  (let loop ([f frac] [n count] [acc '()])
    (if (<= n 0)
        (reverse acc)
        (let ([doubled (* f 2)])
          (if (>= doubled 1)
              (loop (- doubled 1) (- n 1) (cons 1 acc))
              (loop doubled (- n 1) (cons 0 acc)))))))

;; Convert bit list (MSB first) to integer
(define (bit-list->integer bits)
  (for/fold ([acc 0]) ([b (in-list bits)])
    (+ (* acc 2) b)))

;; Round the posit value. For simplicity, we use the decode→compare strategy:
;; Encode without rounding gives a candidate; check if rounding up is closer.
(define (round-posit abs-posit sign regime exp-val frac-val frac-bits-available)
  (cond
    ;; No fraction bits available → no rounding needed
    [(<= frac-bits-available 0) (clamp-posit abs-posit)]
    [else
     ;; Check the residual: what fraction is left after truncation?
     (let* ([truncated-frac (posit8-decode abs-posit)]
            ;; If abs-posit is 0 or represents a very different value, just clamp
            [_ (void)])
       ;; Simple approach: compare abs-posit and abs-posit+1 to the true value
       (let* ([true-val (* (expt useed regime) (expt 2 exp-val) (+ 1 frac-val))]
              [lo abs-posit]
              [hi (min 127 (+ abs-posit 1))]
              [lo-val (posit8-decode lo)]
              [hi-val (posit8-decode hi)]
              ;; Handle edge case where lo or hi decode to non-numbers
              [lo-val (if (eq? lo-val 'nar) +inf.0 lo-val)]
              [hi-val (if (eq? hi-val 'nar) +inf.0 hi-val)])
         (cond
           ;; If lo and hi are both valid, pick the closer one
           [(and (number? lo-val) (number? hi-val))
            (let ([lo-dist (abs (- true-val lo-val))]
                  [hi-dist (abs (- true-val hi-val))])
              (cond
                [(< lo-dist hi-dist) (clamp-posit lo)]
                [(< hi-dist lo-dist) (clamp-posit hi)]
                ;; Tie: round to even (prefer even bit pattern)
                [(even? lo) (clamp-posit lo)]
                [else (clamp-posit hi)]))]
           [else (clamp-posit lo)])))]))

;; Clamp to valid positive posit range [1, 127]
;; (0 and 128 are handled separately as zero and NaR)
(define (clamp-posit v)
  (cond
    [(<= v 0) 1]       ; underflow → minpos
    [(>= v 127) 127]   ; overflow → maxpos
    [else v]))

;; ========================================
;; Arithmetic: decode → exact rational → encode
;; ========================================

;; Helper: apply binary op via rationals with NaR propagation
(define (posit8-binary-op op a b)
  (cond
    [(or (posit8-nar? a) (posit8-nar? b)) posit8-nar]
    [else
     (let ([va (posit8-decode a)]
           [vb (posit8-decode b)])
       (let ([result (op va vb)])
         (if (eq? result 'nar)
             posit8-nar
             (posit8-encode result))))]))

;; Helper: apply unary op via rationals with NaR propagation
(define (posit8-unary-op op a)
  (cond
    [(posit8-nar? a) posit8-nar]
    [else
     (let ([va (posit8-decode a)])
       (let ([result (op va)])
         (if (eq? result 'nar)
             posit8-nar
             (posit8-encode result))))]))

(define (posit8-add a b) (posit8-binary-op + a b))
(define (posit8-sub a b) (posit8-binary-op - a b))
(define (posit8-mul a b) (posit8-binary-op * a b))

(define (posit8-div a b)
  (cond
    [(or (posit8-nar? a) (posit8-nar? b)) posit8-nar]
    [(and (posit8-zero? a) (posit8-zero? b)) posit8-nar]  ; 0/0 = NaR
    [(posit8-zero? b) posit8-nar]                           ; x/0 = NaR
    [else
     (let ([va (posit8-decode a)]
           [vb (posit8-decode b)])
       (posit8-encode (/ va vb)))]))

(define (posit8-neg a)
  (cond
    [(posit8-nar? a) posit8-nar]
    [(posit8-zero? a) posit8-zero]
    [else (s8->u8 (- (u8->s8 a)))]))  ; two's complement negation

(define (posit8-abs a)
  (cond
    [(posit8-nar? a) posit8-nar]
    [(>= (u8->s8 a) 0) a]
    [else (posit8-neg a)]))

(define (posit8-sqrt a)
  (cond
    [(posit8-nar? a) posit8-nar]
    [(posit8-zero? a) posit8-zero]
    [(negative? (u8->s8 a)) posit8-nar]  ; sqrt of negative = NaR
    [else
     (let* ([va (posit8-decode a)]
            ;; Use Racket's inexact sqrt then convert to rational for encoding
            [result (inexact->exact (sqrt (exact->inexact va)))])
       (posit8-encode result))]))

;; ========================================
;; Comparison
;; ========================================

;; Posit comparison uses signed two's complement ordering.
;; NaR comparisons: NaR is not ordered (all comparisons involving NaR are false).

(define (posit8-eq? a b)
  (and (not (posit8-nar? a))
       (not (posit8-nar? b))
       (= a b)))

(define (posit8-lt? a b)
  (and (not (posit8-nar? a))
       (not (posit8-nar? b))
       (< (u8->s8 a) (u8->s8 b))))

(define (posit8-le? a b)
  (and (not (posit8-nar? a))
       (not (posit8-nar? b))
       (<= (u8->s8 a) (u8->s8 b))))

;; ========================================
;; Conversion
;; ========================================

(define (posit8-from-nat n)
  (posit8-encode n))

(define (posit8-to-rational v)
  (posit8-decode v))

;; ========================================
;; Display
;; ========================================

(define (posit8-display v)
  (let ([r (posit8-decode v)])
    (cond
      [(eq? r 'nar) "NaR"]
      [(zero? r) "0"]
      [(integer? r) (number->string r)]
      [else
       ;; Display as exact decimal if possible, otherwise as fraction
       (let ([inexact-val (exact->inexact r)])
         (number->string inexact-val))])))

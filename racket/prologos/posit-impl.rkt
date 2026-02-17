#lang racket/base

;;;
;;; POSIT ARITHMETIC IMPLEMENTATION
;;; Pure Racket implementation of posit arithmetic (2022 Standard, es=2).
;;;
;;; Supports Posit8, Posit16, Posit32, and Posit64.
;;; All posit values are represented as exact integers (unsigned N-bit).
;;; Internally, arithmetic operates via exact rationals: decode → compute → encode.
;;;
;;; Posit format:
;;;   sign (1 bit) | regime (variable) | exponent (es=2 bits max) | fraction (remaining)
;;;
;;; Value = (-1)^sign × useed^regime × 2^exponent × (1 + fraction)
;;; where useed = 2^(2^es) = 2^4 = 16
;;;
;;; Special values:
;;;   Zero = 0x00...0 (all zeros)
;;;   NaR  = 0x80...0 (sign bit set, rest zero) — Not a Real
;;;

(require racket/match
         racket/list)

(provide
 ;; ---- Posit8 ----
 posit8-zero posit8-one posit8-neg-one posit8-nar
 posit8-maxpos posit8-minpos
 posit8-decode posit8-encode
 posit8-add posit8-sub posit8-mul posit8-div
 posit8-neg posit8-abs posit8-sqrt
 posit8-eq? posit8-lt? posit8-le?
 posit8-nar? posit8-zero?
 posit8-from-nat posit8-to-rational
 posit8-display
 ;; ---- Posit16 ----
 posit16-zero posit16-one posit16-neg-one posit16-nar
 posit16-maxpos posit16-minpos
 posit16-decode posit16-encode
 posit16-add posit16-sub posit16-mul posit16-div
 posit16-neg posit16-abs posit16-sqrt
 posit16-eq? posit16-lt? posit16-le?
 posit16-nar? posit16-zero?
 posit16-from-nat posit16-to-rational
 posit16-display
 ;; ---- Posit32 ----
 posit32-zero posit32-one posit32-neg-one posit32-nar
 posit32-maxpos posit32-minpos
 posit32-decode posit32-encode
 posit32-add posit32-sub posit32-mul posit32-div
 posit32-neg posit32-abs posit32-sqrt
 posit32-eq? posit32-lt? posit32-le?
 posit32-nar? posit32-zero?
 posit32-from-nat posit32-to-rational
 posit32-display
 ;; ---- Posit64 ----
 posit64-zero posit64-one posit64-neg-one posit64-nar
 posit64-maxpos posit64-minpos
 posit64-decode posit64-encode
 posit64-add posit64-sub posit64-mul posit64-div
 posit64-neg posit64-abs posit64-sqrt
 posit64-eq? posit64-lt? posit64-le?
 posit64-nar? posit64-zero?
 posit64-from-nat posit64-to-rational
 posit64-display)

;; ========================================
;; Global parameters (2022 Standard)
;; ========================================

(define es 2)                 ; exponent size (fixed for all widths)
(define useed 16)             ; 2^(2^es) = 2^4 = 16

;; ========================================
;; Width-parameterized helpers
;; ========================================

;; NaR bit pattern for given width
(define (posit-nar-val n) (arithmetic-shift 1 (- n 1)))

;; Maximum positive posit value
(define (posit-maxpos-val n) (sub1 (posit-nar-val n)))

;; Unsigned → signed (two's complement)
(define (u->s n v)
  (if (>= v (arithmetic-shift 1 (- n 1)))
      (- v (arithmetic-shift 1 n))
      v))

;; Signed → unsigned (two's complement)
(define (s->u n v)
  (if (< v 0)
      (+ v (arithmetic-shift 1 n))
      v))

;; Extract bit at position pos (0 = LSB)
(define (bit-at v pos)
  (bitwise-and 1 (arithmetic-shift v (- pos))))

;; ========================================
;; Width-parameterized decoding
;; ========================================

;; Returns 'nar for NaR, 0 for zero, or an exact rational.
(define (posit-decode n v)
  (cond
    [(= v (posit-nar-val n)) 'nar]
    [(= v 0) 0]
    [else
     (let* ([sign-bit (- n 1)]
            [sign (bit-at v sign-bit)]
            [abs-bits (if (= sign 1)
                         (bitwise-and (- (arithmetic-shift 1 n) v)
                                      (sub1 (arithmetic-shift 1 n)))
                         v)]
            [regime-msb (bit-at abs-bits (- n 2))])
       (let loop ([pos (- n 3)]
                   [run-len 1])
         (if (and (>= pos 0)
                  (= (bit-at abs-bits pos) regime-msb))
             (loop (- pos 1) (+ run-len 1))
             (let* ([regime-val (if (= regime-msb 1)
                                    (- run-len 1)
                                    (- run-len))]
                    [remaining-start (- pos 1)]
                    [remaining-bits (if (>= remaining-start 0)
                                       (+ remaining-start 1)
                                       0)]
                    [exp-bits (min es remaining-bits)]
                    [exp-val (if (> exp-bits 0)
                                (let ([raw (arithmetic-shift
                                            (bitwise-and abs-bits
                                                         (- (arithmetic-shift 1 (+ remaining-start 1)) 1))
                                            (- (- remaining-bits exp-bits)))])
                                  (arithmetic-shift raw (- es exp-bits)))
                                0)]
                    [frac-bits (- remaining-bits exp-bits)]
                    [frac-val (if (> frac-bits 0)
                                  (bitwise-and abs-bits
                                               (- (arithmetic-shift 1 frac-bits) 1))
                                  0)]
                    [scale (* (expt useed regime-val) (expt 2 exp-val))]
                    [mantissa (if (> frac-bits 0)
                                  (+ 1 (/ frac-val (expt 2 frac-bits)))
                                  1)]
                    [abs-value (* scale mantissa)])
               (if (= sign 1) (- abs-value) abs-value)))))]))

;; ========================================
;; Width-parameterized encoding
;; ========================================

;; Find the regime value k such that useed^k ≤ |x| < useed^(k+1)
(define (regime-for n x)
  (cond
    [(>= x 1)
     (let loop ([k 0])
       (if (or (>= k (- n 2))
               (< x (expt useed (+ k 1))))
           k
           (loop (+ k 1))))]
    [else
     (let loop ([k -1])
       (if (or (<= k (- 2 n))
               (>= x (expt useed k)))
           k
           (loop (- k 1))))]))

;; Find exponent e in [0, 2^es - 1]
(define (exponent-for remainder)
  (let ([max-exp (- (expt 2 es) 1)])
    (let loop ([e 0])
      (if (or (>= e max-exp)
              (< remainder (expt 2 (+ e 1))))
          e
          (loop (+ e 1))))))

;; Convert integer to bit list (MSB first), taking only the top count bits
(define (integer->bit-list val total-bits count)
  (for/list ([i (in-range count)])
    (bit-at val (- total-bits 1 i))))

;; Convert fraction (0 ≤ frac < 1) to bit list of given length
(define (fraction->bit-list frac count)
  (let loop ([f frac] [nc count] [acc '()])
    (if (<= nc 0)
        (reverse acc)
        (let ([doubled (* f 2)])
          (if (>= doubled 1)
              (loop (- doubled 1) (- nc 1) (cons 1 acc))
              (loop doubled (- nc 1) (cons 0 acc)))))))

;; Convert bit list (MSB first) to integer
(define (bit-list->integer bits)
  (for/fold ([acc 0]) ([b (in-list bits)])
    (+ (* acc 2) b)))

;; Clamp to valid positive posit range [1, maxpos]
(define (clamp-posit n v)
  (let ([mp (posit-maxpos-val n)])
    (cond
      [(<= v 0) 1]
      [(>= v mp) mp]
      [else v])))

;; Round the posit value using decode→compare strategy
(define (round-posit n abs-posit sign regime exp-val frac-val frac-bits-available)
  (cond
    [(<= frac-bits-available 0) (clamp-posit n abs-posit)]
    [else
     (let* ([true-val (* (expt useed regime) (expt 2 exp-val) (+ 1 frac-val))]
            [lo abs-posit]
            [hi (min (posit-maxpos-val n) (+ abs-posit 1))]
            [lo-val (posit-decode n lo)]
            [hi-val (posit-decode n hi)]
            [lo-val (if (eq? lo-val 'nar) +inf.0 lo-val)]
            [hi-val (if (eq? hi-val 'nar) +inf.0 hi-val)])
       (cond
         [(and (number? lo-val) (number? hi-val))
          (let ([lo-dist (abs (- true-val lo-val))]
                [hi-dist (abs (- true-val hi-val))])
            (cond
              [(< lo-dist hi-dist) (clamp-posit n lo)]
              [(< hi-dist lo-dist) (clamp-posit n hi)]
              [(even? lo) (clamp-posit n lo)]
              [else (clamp-posit n hi)]))]
         [else (clamp-posit n lo)]))]))

;; Encode sign, regime, exponent, fraction into n-bit posit
(define (encode-bits n sign regime exp-val frac-val)
  (let* ([regime-bits-list (if (>= regime 0)
                               (append (make-list (+ regime 1) 1) (list 0))
                               (append (make-list (- regime) 0) (list 1)))]
         [available (- n 1)]
         [regime-bits (if (> (length regime-bits-list) available)
                          (take regime-bits-list available)
                          regime-bits-list)]
         [bits-after-regime (- available (length regime-bits))]
         [exp-bits-count (min es bits-after-regime)]
         [exp-bits-list (integer->bit-list exp-val es exp-bits-count)]
         [bits-after-exp (- bits-after-regime exp-bits-count)]
         [frac-bits-list (fraction->bit-list frac-val bits-after-exp)]
         [all-bits (append regime-bits exp-bits-list frac-bits-list)]
         [padded (if (< (length all-bits) available)
                     (append all-bits (make-list (- available (length all-bits)) 0))
                     (take all-bits available))]
         [abs-posit (bit-list->integer padded)]
         [rounded (round-posit n abs-posit sign regime exp-val frac-val
                               bits-after-exp)])
    (if (= sign 1)
        (s->u n (- rounded))
        rounded)))

;; Encode an exact rational as n-bit posit with round-to-nearest-even.
(define (posit-encode n r)
  (cond
    [(eq? r 'nar) (posit-nar-val n)]
    [(zero? r) 0]
    [else
     (let* ([sign (if (negative? r) 1 0)]
            [abs-r (abs r)]
            [regime (regime-for n abs-r)]
            [remainder-val (/ abs-r (expt useed regime))]
            [exp-val (exponent-for remainder-val)]
            [frac-plus-one (/ remainder-val (expt 2 exp-val))]
            [frac-val (- frac-plus-one 1)])
       (encode-bits n sign regime exp-val frac-val))]))

;; ========================================
;; Width-parameterized arithmetic
;; ========================================

(define (posit-binary-op n op a b)
  (let ([nar (posit-nar-val n)])
    (cond
      [(or (= a nar) (= b nar)) nar]
      [else
       (let ([va (posit-decode n a)]
             [vb (posit-decode n b)])
         (let ([result (op va vb)])
           (if (eq? result 'nar) nar (posit-encode n result))))])))

(define (posit-unary-op n op a)
  (let ([nar (posit-nar-val n)])
    (cond
      [(= a nar) nar]
      [else
       (let ([va (posit-decode n a)])
         (let ([result (op va)])
           (if (eq? result 'nar) nar (posit-encode n result))))])))

(define (posit-div n a b)
  (let ([nar (posit-nar-val n)])
    (cond
      [(or (= a nar) (= b nar)) nar]
      [(and (= a 0) (= b 0)) nar]
      [(= b 0) nar]
      [else
       (let ([va (posit-decode n a)]
             [vb (posit-decode n b)])
         (posit-encode n (/ va vb)))])))

(define (posit-neg n a)
  (let ([nar (posit-nar-val n)])
    (cond
      [(= a nar) nar]
      [(= a 0) 0]
      [else (s->u n (- (u->s n a)))])))

(define (posit-abs n a)
  (let ([nar (posit-nar-val n)])
    (cond
      [(= a nar) nar]
      [(>= (u->s n a) 0) a]
      [else (posit-neg n a)])))

(define (posit-sqrt n a)
  (let ([nar (posit-nar-val n)])
    (cond
      [(= a nar) nar]
      [(= a 0) 0]
      [(negative? (u->s n a)) nar]
      [else
       (let* ([va (posit-decode n a)]
              [result (inexact->exact (sqrt (exact->inexact va)))])
         (posit-encode n result))])))

(define (posit-eq? n a b)
  (let ([nar (posit-nar-val n)])
    (and (not (= a nar)) (not (= b nar)) (= a b))))

(define (posit-lt? n a b)
  (let ([nar (posit-nar-val n)])
    (and (not (= a nar)) (not (= b nar)) (< (u->s n a) (u->s n b)))))

(define (posit-le? n a b)
  (let ([nar (posit-nar-val n)])
    (and (not (= a nar)) (not (= b nar)) (<= (u->s n a) (u->s n b)))))

(define (posit-from-nat n k)
  (posit-encode n k))

(define (posit-to-rational n v)
  (posit-decode n v))

(define (posit-display n v)
  (let ([r (posit-decode n v)])
    (cond
      [(eq? r 'nar) "NaR"]
      [(zero? r) "0"]
      [(integer? r) (number->string r)]
      [else (number->string (exact->inexact r))])))

;; ========================================
;; Posit8 wrappers (backward-compatible)
;; ========================================

(define posit8-zero    0)
(define posit8-one     64)      ; 0x40
(define posit8-neg-one 192)     ; 0xC0
(define posit8-nar     128)     ; 0x80
(define posit8-maxpos  127)     ; 0x7F
(define posit8-minpos  1)

(define (posit8-nar? v) (= v 128))
(define (posit8-zero? v) (= v 0))
(define (posit8-decode v) (posit-decode 8 v))
(define (posit8-encode r) (posit-encode 8 r))
(define (posit8-add a b) (posit-binary-op 8 + a b))
(define (posit8-sub a b) (posit-binary-op 8 - a b))
(define (posit8-mul a b) (posit-binary-op 8 * a b))
(define (posit8-div a b) (posit-div 8 a b))
(define (posit8-neg a) (posit-neg 8 a))
(define (posit8-abs a) (posit-abs 8 a))
(define (posit8-sqrt a) (posit-sqrt 8 a))
(define (posit8-eq? a b) (posit-eq? 8 a b))
(define (posit8-lt? a b) (posit-lt? 8 a b))
(define (posit8-le? a b) (posit-le? 8 a b))
(define (posit8-from-nat n) (posit-from-nat 8 n))
(define (posit8-to-rational v) (posit-to-rational 8 v))
(define (posit8-display v) (posit-display 8 v))

;; ========================================
;; Posit16 wrappers
;; ========================================

(define posit16-zero    0)
(define posit16-one     #x4000)    ; 16384
(define posit16-neg-one #xC000)    ; 49152
(define posit16-nar     #x8000)    ; 32768
(define posit16-maxpos  #x7FFF)    ; 32767
(define posit16-minpos  1)

(define (posit16-nar? v) (= v posit16-nar))
(define (posit16-zero? v) (= v 0))
(define (posit16-decode v) (posit-decode 16 v))
(define (posit16-encode r) (posit-encode 16 r))
(define (posit16-add a b) (posit-binary-op 16 + a b))
(define (posit16-sub a b) (posit-binary-op 16 - a b))
(define (posit16-mul a b) (posit-binary-op 16 * a b))
(define (posit16-div a b) (posit-div 16 a b))
(define (posit16-neg a) (posit-neg 16 a))
(define (posit16-abs a) (posit-abs 16 a))
(define (posit16-sqrt a) (posit-sqrt 16 a))
(define (posit16-eq? a b) (posit-eq? 16 a b))
(define (posit16-lt? a b) (posit-lt? 16 a b))
(define (posit16-le? a b) (posit-le? 16 a b))
(define (posit16-from-nat n) (posit-from-nat 16 n))
(define (posit16-to-rational v) (posit-to-rational 16 v))
(define (posit16-display v) (posit-display 16 v))

;; ========================================
;; Posit32 wrappers
;; ========================================

(define posit32-zero    0)
(define posit32-one     #x40000000)      ; 1073741824
(define posit32-neg-one #xC0000000)      ; 3221225472
(define posit32-nar     #x80000000)      ; 2147483648
(define posit32-maxpos  #x7FFFFFFF)      ; 2147483647
(define posit32-minpos  1)

(define (posit32-nar? v) (= v posit32-nar))
(define (posit32-zero? v) (= v 0))
(define (posit32-decode v) (posit-decode 32 v))
(define (posit32-encode r) (posit-encode 32 r))
(define (posit32-add a b) (posit-binary-op 32 + a b))
(define (posit32-sub a b) (posit-binary-op 32 - a b))
(define (posit32-mul a b) (posit-binary-op 32 * a b))
(define (posit32-div a b) (posit-div 32 a b))
(define (posit32-neg a) (posit-neg 32 a))
(define (posit32-abs a) (posit-abs 32 a))
(define (posit32-sqrt a) (posit-sqrt 32 a))
(define (posit32-eq? a b) (posit-eq? 32 a b))
(define (posit32-lt? a b) (posit-lt? 32 a b))
(define (posit32-le? a b) (posit-le? 32 a b))
(define (posit32-from-nat n) (posit-from-nat 32 n))
(define (posit32-to-rational v) (posit-to-rational 32 v))
(define (posit32-display v) (posit-display 32 v))

;; ========================================
;; Posit64 wrappers
;; ========================================

(define posit64-zero    0)
(define posit64-one     #x4000000000000000)    ; 4611686018427387904
(define posit64-neg-one #xC000000000000000)    ; 13835058055282163712
(define posit64-nar     #x8000000000000000)    ; 9223372036854775808
(define posit64-maxpos  #x7FFFFFFFFFFFFFFF)    ; 9223372036854775807
(define posit64-minpos  1)

(define (posit64-nar? v) (= v posit64-nar))
(define (posit64-zero? v) (= v 0))
(define (posit64-decode v) (posit-decode 64 v))
(define (posit64-encode r) (posit-encode 64 r))
(define (posit64-add a b) (posit-binary-op 64 + a b))
(define (posit64-sub a b) (posit-binary-op 64 - a b))
(define (posit64-mul a b) (posit-binary-op 64 * a b))
(define (posit64-div a b) (posit-div 64 a b))
(define (posit64-neg a) (posit-neg 64 a))
(define (posit64-abs a) (posit-abs 64 a))
(define (posit64-sqrt a) (posit-sqrt 64 a))
(define (posit64-eq? a b) (posit-eq? 64 a b))
(define (posit64-lt? a b) (posit-lt? 64 a b))
(define (posit64-le? a b) (posit-le? 64 a b))
(define (posit64-from-nat n) (posit-from-nat 64 n))
(define (posit64-to-rational v) (posit-to-rational 64 v))
(define (posit64-display v) (posit-display 64 v))

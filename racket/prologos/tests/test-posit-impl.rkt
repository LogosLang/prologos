#lang racket/base

;;;
;;; Tests for posit-impl.rkt — Posit8 arithmetic library
;;;

(require rackunit
         "../posit-impl.rkt")

;; ========================================
;; Constants
;; ========================================

(test-case "posit8 constants"
  (check-equal? posit8-zero 0)
  (check-equal? posit8-one 64)
  (check-equal? posit8-neg-one 192)
  (check-equal? posit8-nar 128)
  (check-equal? posit8-maxpos 127)
  (check-equal? posit8-minpos 1))

;; ========================================
;; Predicates
;; ========================================

(test-case "posit8 predicates"
  (check-true (posit8-nar? 128))
  (check-false (posit8-nar? 0))
  (check-false (posit8-nar? 64))
  (check-true (posit8-zero? 0))
  (check-false (posit8-zero? 64))
  (check-false (posit8-zero? 128)))

;; ========================================
;; Decoding
;; ========================================

(test-case "posit8-decode special values"
  (check-equal? (posit8-decode 0) 0 "zero")
  (check-equal? (posit8-decode 128) 'nar "NaR"))

(test-case "posit8-decode positive values"
  ;; 0x40 = 0100 0000 → regime = 0 (one 1, then 0) → useed^0 = 1, exp = 0, frac = 0
  ;; value = 1
  (check-equal? (posit8-decode #x40) 1 "0x40 = 1")

  ;; 0x60 = 0110 0000 → regime bits: 10 (one 1, zero terminates) → regime=0
  ;; exp bits: 10 → exp=2, frac=0
  ;; Wait, let me trace: 0110 0000
  ;; sign=0, remaining=110 0000
  ;; regime-msb=1, scan: bit5=1, bit4=0 → run of 2 ones, regime=1
  ;; Hmm, let me re-check. 0x60 = 0 1100000
  ;; sign=0, bit6=1, bit5=1, bit4=0 → two 1s then 0 → regime = 2-1 = 1
  ;; remaining after regime+terminator: bits 3,2,1,0 = 0000
  ;; exp = 00 = 0, frac = 00 (2 frac bits) = 0
  ;; value = useed^1 × 2^0 × 1 = 16
  ;; Actually no: 0x60 = 96 in decimal
  ;; Binary: 01100000
  ;; sign=0, regime: bit6=1, bit5=1, bit4=0 → run=2 ones → regime = 2-1 = 1
  ;; After terminator (bit4=0), remaining = bits 3,2,1,0 = 0000
  ;; exp = bits 3,2 = 00 → 0
  ;; frac = bits 1,0 = 00 → 0
  ;; value = 16^1 × 2^0 × 1 = 16
  (check-equal? (posit8-decode #x60) 16 "0x60 = 16")

  ;; 0x7F = 0111 1111 → max positive
  ;; sign=0, regime: bit6=1,bit5=1,bit4=1,bit3=1,bit2=1,bit1=1,bit0=1 → seven 1s, no terminator
  ;; regime = 7-1 = 6, no exp bits, no frac bits
  ;; value = 16^6 = 16777216
  (check-equal? (posit8-decode #x7F) (expt 16 6) "0x7F = maxpos = 16^6")

  ;; 0x01 = 0000 0001 → min positive
  ;; sign=0, regime: bit6=0,bit5=0,bit4=0,bit3=0,bit2=0,bit1=0,bit0=1
  ;; six 0s then 1 → regime = -6
  ;; no remaining bits for exp/frac
  ;; value = 16^(-6)
  (check-equal? (posit8-decode #x01) (/ 1 (expt 16 6)) "0x01 = minpos = 16^-6"))

(test-case "posit8-decode known values"
  ;; 0x48 = 0100 1000 → sign=0
  ;; regime: bit6=1, bit5=0 → one 1 then 0 → regime=0
  ;; remaining: bits 4,3,2,1,0 = 01000
  ;; exp: bits 4,3 = 01 → 1
  ;; frac: bits 2,1,0 = 000 → 0/8 = 0
  ;; value = 16^0 × 2^1 × 1 = 2
  (check-equal? (posit8-decode #x48) 2 "0x48 = 2")

  ;; 0x30 = 0011 0000 → sign=0
  ;; regime: bit6=0, bit5=1 → one 0 then 1 → regime=-1
  ;; remaining: bits 4,3,2,1,0 = 10000
  ;; exp: bits 4,3 = 10 → 2
  ;; frac: bits 2,1,0 = 000 → 0
  ;; value = 16^(-1) × 2^2 × 1 = (1/16) × 4 = 1/4
  (check-equal? (posit8-decode #x30) 1/4 "0x30 = 0.25"))

(test-case "posit8-decode negative values"
  ;; Negative values are two's complement of the positive
  ;; -1 = two's complement of 0x40 = 0xC0 = 192
  (check-equal? (posit8-decode #xC0) -1 "0xC0 = -1")
  ;; -16 = two's complement of 0x60 = 0xA0 = 160
  (check-equal? (posit8-decode #xA0) -16 "0xA0 = -16"))

;; ========================================
;; Encoding
;; ========================================

(test-case "posit8-encode special values"
  (check-equal? (posit8-encode 0) 0 "encode 0")
  (check-equal? (posit8-encode 'nar) 128 "encode NaR"))

(test-case "posit8-encode known values"
  (check-equal? (posit8-encode 1) #x40 "encode 1")
  (check-equal? (posit8-encode -1) #xC0 "encode -1")
  (check-equal? (posit8-encode 2) #x48 "encode 2")
  (check-equal? (posit8-encode 16) #x60 "encode 16")
  (check-equal? (posit8-encode 1/4) #x30 "encode 1/4"))

(test-case "posit8 roundtrip encode-decode"
  ;; Every valid posit8 pattern should roundtrip
  (for ([i (in-range 0 256)])
    (let ([decoded (posit8-decode i)])
      (unless (eq? decoded 'nar)
        (check-equal? (posit8-encode decoded) i
                      (format "roundtrip for pattern ~a (value ~a)" i decoded))))))

;; ========================================
;; Arithmetic
;; ========================================

(test-case "posit8 addition"
  ;; 1 + 1 = 2
  (check-equal? (posit8-add #x40 #x40) #x48 "1+1=2")
  ;; 0 + 1 = 1
  (check-equal? (posit8-add 0 #x40) #x40 "0+1=1")
  ;; NaR + anything = NaR
  (check-equal? (posit8-add 128 #x40) 128 "NaR+1=NaR")
  (check-equal? (posit8-add #x40 128) 128 "1+NaR=NaR"))

(test-case "posit8 subtraction"
  ;; 2 - 1 = 1
  (check-equal? (posit8-sub #x48 #x40) #x40 "2-1=1")
  ;; 1 - 1 = 0
  (check-equal? (posit8-sub #x40 #x40) 0 "1-1=0"))

(test-case "posit8 multiplication"
  ;; 1 × 2 = 2
  (check-equal? (posit8-mul #x40 #x48) #x48 "1×2=2")
  ;; 0 × anything = 0
  (check-equal? (posit8-mul 0 #x40) 0 "0×1=0")
  ;; NaR × anything = NaR
  (check-equal? (posit8-mul 128 #x40) 128 "NaR×1=NaR"))

(test-case "posit8 division"
  ;; 2 / 1 = 2
  (check-equal? (posit8-div #x48 #x40) #x48 "2/1=2")
  ;; 1 / 2 = 0.5
  ;; Need to verify what 0.5 encodes to
  (let ([half (posit8-encode 1/2)])
    (check-equal? (posit8-div #x40 #x48) half "1/2"))
  ;; 0 / 0 = NaR
  (check-equal? (posit8-div 0 0) 128 "0/0=NaR")
  ;; x / 0 = NaR (for non-zero x)
  (check-equal? (posit8-div #x40 0) 128 "1/0=NaR"))

;; ========================================
;; Negation and Absolute Value
;; ========================================

(test-case "posit8 negation"
  (check-equal? (posit8-neg #x40) #xC0 "neg(1)=-1")
  (check-equal? (posit8-neg #xC0) #x40 "neg(-1)=1")
  (check-equal? (posit8-neg 0) 0 "neg(0)=0")
  (check-equal? (posit8-neg 128) 128 "neg(NaR)=NaR"))

(test-case "posit8 absolute value"
  (check-equal? (posit8-abs #x40) #x40 "abs(1)=1")
  (check-equal? (posit8-abs #xC0) #x40 "abs(-1)=1")
  (check-equal? (posit8-abs 0) 0 "abs(0)=0")
  (check-equal? (posit8-abs 128) 128 "abs(NaR)=NaR"))

;; ========================================
;; Comparison
;; ========================================

(test-case "posit8 comparison"
  (check-true (posit8-lt? 0 #x40) "0 < 1")
  (check-true (posit8-lt? #x40 #x48) "1 < 2")
  (check-false (posit8-lt? #x48 #x40) "not 2 < 1")
  (check-false (posit8-lt? #x40 #x40) "not 1 < 1")
  ;; NaR comparisons are always false
  (check-false (posit8-lt? 128 #x40) "NaR not < 1")
  (check-false (posit8-lt? #x40 128) "1 not < NaR")
  ;; <=
  (check-true (posit8-le? #x40 #x40) "1 <= 1")
  (check-true (posit8-le? 0 #x40) "0 <= 1")
  (check-false (posit8-le? 128 #x40) "NaR not <= 1")
  ;; Equality
  (check-true (posit8-eq? #x40 #x40) "1 == 1")
  (check-false (posit8-eq? #x40 #x48) "1 != 2")
  (check-false (posit8-eq? 128 128) "NaR != NaR"))

;; ========================================
;; Conversion
;; ========================================

(test-case "posit8-from-nat"
  (check-equal? (posit8-from-nat 0) 0 "from-nat 0")
  (check-equal? (posit8-from-nat 1) #x40 "from-nat 1")
  (check-equal? (posit8-from-nat 2) #x48 "from-nat 2"))

;; ========================================
;; Display
;; ========================================

(test-case "posit8-display"
  (check-equal? (posit8-display 0) "0" "display 0")
  (check-equal? (posit8-display 128) "NaR" "display NaR")
  (check-equal? (posit8-display #x40) "1" "display 1"))

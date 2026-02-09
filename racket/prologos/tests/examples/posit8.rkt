#lang prologos/sexp

;; ========================================
;; Posit8 Arithmetic — 8-bit Posit (2022 Standard, es=2)
;;
;; Posit8 values are 8-bit numbers using the Posit format.
;; posit8 literals take the raw bit pattern (0–255).
;;
;; Key values:
;;   (posit8 0)   = 0        (zero)
;;   (posit8 64)  = 1        (one)
;;   (posit8 72)  = 2        (two)
;;   (posit8 128) = NaR      (Not a Real)
;;   (posit8 192) = -1       (negative one)
;; ========================================

;; Define some constants
(def zero-p <Posit8> (posit8 0))
(def one   <Posit8> (posit8 64))
(def two   <Posit8> (posit8 72))
(def nar   <Posit8> (posit8 128))

;; Basic arithmetic
(eval (p8+ one one))           ;; => (posit8 72) : Posit8  [2]
(eval (p8* one two))           ;; => (posit8 72) : Posit8  [2]
(eval (p8- two one))           ;; => (posit8 64) : Posit8  [1]

;; Negation
(eval (p8-neg one))            ;; => (posit8 192) : Posit8  [-1]

;; NaR propagation
(eval (p8+ nar one))           ;; => (posit8 128) : Posit8  [NaR]
(eval (p8/ one zero-p))        ;; => (posit8 128) : Posit8  [NaR: div by zero]

;; Comparison
(eval (p8-lt one two))         ;; => true : Bool
(eval (p8-le one one))         ;; => true : Bool

;; Conversion from Nat
(eval (p8-from-nat (inc (inc (inc zero)))))   ;; => (posit8 ...) : Posit8  [3]

;; Type checking
(check one <Posit8>)
(check Posit8 <(Type 0)>)

;; Branch on NaR
(eval (p8-if-nar Nat zero (inc zero) one))    ;; => 1 : Nat  [one is not NaR]
(eval (p8-if-nar Nat zero (inc zero) nar))    ;; => zero : Nat  [nar IS NaR]

;; Define a function using Posit8
(defn p8-double [x <Posit8>] <Posit8>
  (p8+ x x))
(eval (p8-double one))         ;; => (posit8 72) : Posit8  [2]
(eval (p8-double two))         ;; => (posit8 76) : Posit8  [4]

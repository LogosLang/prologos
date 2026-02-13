#lang prologos

;; Posit8 Arithmetic — Whitespace Syntax

;; Constants
def one <Posit8> [posit8 64]
def two <Posit8> [posit8 72]

;; Arithmetic
eval [p8+ one one]
eval [p8* one two]
eval [p8- two one]

;; Negation
eval [p8-neg one]

;; NaR propagation
eval [p8+ [posit8 128] one]

;; Comparison
eval [p8-lt one two]

;; Type checking
check one <Posit8>
check Posit8 <[Type 0]>

;; Function definition
defn p8-double [x <Posit8>] <Posit8>
  p8+ x x

eval [p8-double one]

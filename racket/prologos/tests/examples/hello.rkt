#lang prologos/sexp

(def one <Nat> (suc zero))
(def two <Nat> (suc one))
(check two <Nat>)
(eval two)

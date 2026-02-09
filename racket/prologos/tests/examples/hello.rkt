#lang prologos/sexp

(def one <Nat> (inc zero))
(def two <Nat> (inc one))
(check two <Nat>)
(eval two)

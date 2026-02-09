#lang prologos/sexp

;; Simple function with defn
(defn increment [x <Nat>] <Nat> (inc x))
(eval (increment zero))
(eval (increment (inc zero)))

;; Polymorphic identity with defn
(defn id [A :0 <(Type 0)> x <A>] <A> x)
(eval (id Nat zero))
(eval (id Bool true))

;; Using defn-defined function with other operations
(check (increment zero) <Nat>)

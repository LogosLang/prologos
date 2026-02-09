#lang prologos/sexp

;; Polymorphic identity: forall (A : Type). A -> A
(def id <(Pi [A :0 <(Type 0)>] (-> A A))>
  (fn [A :0 <(Type 0)>] (fn [x <A>] x)))

;; Apply id to Nat
(eval (the (-> Nat Nat) (id Nat)))
(infer (id Nat))

;; Apply id to specific values
(eval (id Nat zero))
(eval (id Nat (inc (inc zero))))
(eval (id Bool true))

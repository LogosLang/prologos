#lang prologos

;; Polymorphic identity: forall (A : Type). A -> A
def id <(Pi [A :0 <(Type 0)>] (-> A A))>
  fn [A :0 <(Type 0)>]
    fn [x <A>] x

;; Apply id to specific values (implicit type inference for A)
eval (id zero)
infer (id zero)
eval (id (inc (inc zero)))
eval (id true)

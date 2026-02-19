#lang prologos

;; Simple function with defn
defn increment [x <Nat>] <Nat>
    suc x

increment zero
increment [suc zero]
increment [suc [suc zero]]


;; Polymorphic identity with defn
defn id [A :0 <[Type 0]>
         x <A>] <A>
  x

eval [id Nat zero]
eval [id Bool true]

;; Using defn-defined function with other operations
check [increment zero] <Nat>

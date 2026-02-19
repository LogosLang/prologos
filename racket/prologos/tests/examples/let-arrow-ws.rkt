#lang prologos

;; End-to-end test: let :=, sibling lets, uncurried arrows in WS mode

;; Simple let :=
def one : Nat
  let x : Nat := zero
    [suc x]

eval one

;; Sibling lets
def three : Nat
  let a : Nat := [suc zero]
  let b : Nat := [suc a]
  let c : Nat := [suc b]
    c

eval three

;; Defn with multi-arg (uncurried arrow in type output)
defn add [x : Nat y : Nat] <Nat>
  [natrec Nat x [fn [k : Nat] [fn [r : Nat] [suc r]]] y]

eval [add [suc zero] [suc [suc zero]]]

;; Let := with function type
defn apply-fn [f : [-> Nat Nat] x : Nat] <Nat>
  [f x]

defn inc2 [x : Nat] <Nat>
  [suc [suc x]]

eval [apply-fn inc2 [suc zero]]

;; Sibling lets with trailing body at same indent (no indentation under last let)
def five : Nat
  let a := [suc [suc [suc zero]]]
  let b := [suc [suc zero]]
  let c := [add a b]
  c

eval five

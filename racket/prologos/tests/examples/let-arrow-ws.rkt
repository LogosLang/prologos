#lang prologos

;; End-to-end test: let :=, sibling lets, uncurried arrows in WS mode

;; Simple let :=
def one : Nat
  let x : Nat := zero
    [inc x]

eval one

;; Sibling lets
def three : Nat
  let a : Nat := [inc zero]
  let b : Nat := [inc a]
  let c : Nat := [inc b]
    c

eval three

;; Defn with multi-arg (uncurried arrow in type output)
defn add [x : Nat y : Nat] <Nat>
  [natrec Nat x [fn [k : Nat] [fn [r : Nat] [inc r]]] y]

eval [add [inc zero] [inc [inc zero]]]

;; Let := with function type
defn apply-fn [f : [-> Nat Nat] x : Nat] <Nat>
  [f x]

defn inc2 [x : Nat] <Nat>
  [inc [inc x]]

eval [apply-fn inc2 [inc zero]]

;; Sibling lets with trailing body at same indent (no indentation under last let)
def five : Nat
  let a := [inc [inc [inc zero]]]
  let b := [inc [inc zero]]
  let c := [add a b]
  c

eval five

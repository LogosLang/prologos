#lang prologos

;; Spec: declare types separately from implementations

spec add Nat Nat -> Nat
defn add [x y]
    natrec Nat x [fn [k : Nat] [fn [r : Nat] [inc r]]] y

eval [add [inc zero] [inc [inc zero]]]

;; Spec with docstring
spec inc2 "Increments twice." Nat -> Nat
defn inc2 [x]
    inc [inc x]

eval [inc2 [inc zero]]

;; HOF spec
spec apply-fn [-> Nat Nat] Nat -> Nat
defn apply-fn [f x]
    f x

eval [apply-fn inc2 zero]

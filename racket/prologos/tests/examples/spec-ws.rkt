#lang prologos

;; Spec: declare types separately from implementations

spec add Nat Nat -> Nat
defn add [x y]
    natrec Nat x [fn [k : Nat] [fn [r : Nat] [suc r]]] y

eval [add [suc zero] [suc [suc zero]]]

;; Spec with docstring
spec inc2 "Increments twice." Nat -> Nat
defn inc2 [x]
    suc [suc x]

eval [inc2 [suc zero]]

;; HOF spec
spec apply-fn [-> Nat Nat] Nat -> Nat
defn apply-fn [f x]
    f x

eval [apply-fn inc2 zero]

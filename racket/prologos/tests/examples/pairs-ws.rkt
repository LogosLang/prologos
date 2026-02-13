#lang prologos

;; Simple non-dependent pair
check [pair zero true] <[Sigma [x <Nat>] Bool]>
eval [first [the [Sigma [x <Nat>] Bool] [pair zero true]]]
eval [second [the [Sigma [x <Nat>] Bool] [pair zero true]]]

first  [the [Sigma [x <Nat>] Bool]
            [pair zero true]]
second [the [Sigma [x <Nat>] Bool]
            [pair zero true]]


;; Dependent pair: (n : Nat, Eq Nat n zero)
check [pair zero refl] <[Sigma [x <Nat>] [Eq Nat x zero]]>

#lang prologos

;; Built-in macros work in whitespace mode.

;; Define a function with defn
defn double [x <Nat>] <Nat>
  [natrec [the [-> Nat [Type 0]] [fn [_ <Nat>] Nat]]
          zero
          [fn [_ <Nat>] [fn [r <Nat>] [suc [suc r]]]]
          x]

;; Evaluate double
eval [double [suc [suc zero]]]

;; Use if — built-in, expands to boolrec
eval [if Nat true [suc zero] zero]
eval [if Nat false [suc zero] zero]

;; Use boolrec directly
eval [boolrec [the [-> Bool [Type 0]] [fn [_ <Bool>] Nat]] zero [suc zero] true]
eval [boolrec [the [-> Bool [Type 0]] [fn [_ <Bool>] Nat]] zero [suc zero] false]

;; Use let
eval [let [n <Nat> [double [suc zero]] m <Nat> [suc n]] m]

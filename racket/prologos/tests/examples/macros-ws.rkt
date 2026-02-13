#lang prologos

;; Built-in macros work in whitespace mode.

;; Define a function with defn
defn double [x <Nat>] <Nat>
  [natrec [the [-> Nat [Type 0]] [fn [_ <Nat>] Nat]]
          zero
          [fn [_ <Nat>] [fn [r <Nat>] [inc [inc r]]]]
          x]

;; Evaluate double
eval [double [inc [inc zero]]]

;; Use if — built-in, expands to boolrec
eval [if Nat true [inc zero] zero]
eval [if Nat false [inc zero] zero]

;; Use boolrec directly
eval [boolrec [the [-> Bool [Type 0]] [fn [_ <Bool>] Nat]] zero [inc zero] true]
eval [boolrec [the [-> Bool [Type 0]] [fn [_ <Bool>] Nat]] zero [inc zero] false]

;; Use let
eval [let [n <Nat> [double [inc zero]] m <Nat> [inc n]] m]

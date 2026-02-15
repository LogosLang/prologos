#lang prologos/sexp

;; Define a not macro
(defmacro not ($b) (if Bool $b false true))

;; Define a parameterized type alias
(deftype (Pair $A $B) (Sigma [x <$A>] $B))

;; Define a function with defn
(defn double [x <Nat>] <Nat>
  (natrec (the (-> Nat (Type 0)) (fn [_ <Nat>] Nat))
          zero
          (fn [_ <Nat>] (fn [r <Nat>] (inc (inc r))))
          x))

;; Evaluate some expressions
(eval (double (inc (inc zero))))
(eval (not true))
(eval (not false))

;; Use let
(eval (let [n <Nat> (double (inc zero)) m <Nat> (inc n)] m))

;; Use if
(eval (if Nat true (inc zero) zero))
(eval (if Nat false (inc zero) zero))

;; Use parameterized type alias
(check (pair zero true) <(Pair Nat Bool)>)

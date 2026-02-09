#lang prologos

;; Empty vector of Nat
check (vnil Nat) <(Vec Nat zero)>

;; Single-element vector [42]
check (vcons Nat zero (inc zero) (vnil Nat)) <(Vec Nat (inc zero))>

;; Head of single-element vector
vhead Nat zero
  the (Vec Nat (inc zero))
    vcons Nat zero (inc zero) (vnil Nat)

;; Fin type well-formedness
check (fzero zero) <(Fin (inc zero))>

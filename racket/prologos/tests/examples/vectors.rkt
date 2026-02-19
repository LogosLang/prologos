#lang prologos/sexp

;; Empty vector of Nat
(check (vnil Nat) <(Vec Nat zero)>)

;; Single-element vector [42]
(check (vcons Nat zero (suc zero) (vnil Nat)) <(Vec Nat (suc zero))>)

;; Head of single-element vector
(eval (vhead Nat zero
  (the (Vec Nat (suc zero))
       (vcons Nat zero (suc zero) (vnil Nat)))))

;; Fin type well-formedness
(check (fzero zero) <(Fin (suc zero))>)

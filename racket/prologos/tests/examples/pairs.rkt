#lang prologos/sexp

;; Simple non-dependent pair
(check (pair zero true) <(Sigma [x <Nat>] Bool)>)
(eval (fst (the (Sigma [x <Nat>] Bool) (pair zero true))))
(eval (snd (the (Sigma [x <Nat>] Bool) (pair zero true))))


(fst (the (Sigma [x <Nat>] Bool) (pair zero true)))
(snd (the (Sigma [x <Nat>] Bool) (pair zero true)))

;; Dependent pair: (n : Nat, Eq Nat n zero)
(check (pair zero refl) <(Sigma [x <Nat>] (Eq Nat x zero))>)

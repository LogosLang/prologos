#lang racket/base
;; test-sign-refinement.rkt — Numerics N5c substrate unit tests.
;; Exercises the Racket-side Sign transfer algebra + name<->Sign/base tables
;; (sign-refinement.rkt). No type-checker wiring (that is N5d).

(require rackunit
         "../sign-refinement.rkt")

;; ---- lattice (⊑ = ⊆, join = ∪) ----
(test-case "sign lattice: ⊑ and join"
  (check-true  (sign<=? sign-pos sign-nonneg))    ;; {pos} ⊆ {zero,pos}
  (check-true  (sign<=? sign-pos sign-top))
  (check-false (sign<=? sign-nonneg sign-pos))
  (check-false (sign<=? sign-pos sign-neg))
  (check-true  (sign<=? sign-bot sign-neg))        ;; ∅ ⊆ anything
  (check-equal? (sign-join sign-neg sign-pos) sign-nonzero)   ;; {neg}∪{pos}
  (check-equal? (sign-join sign-neg sign-zero) sign-nonpos)
  (check-equal? (sign-join sign-zero sign-pos) sign-nonneg)
  (check-equal? (sign-join sign-pos sign-pos) sign-pos)
  (check-equal? (sign-name sign-nonzero) 'sign-nonzero))

;; ---- Galois Int <-> Sign ----
(test-case "sign Galois: α and γ"
  (check-equal? (sign-alpha-int 5) sign-pos)
  (check-equal? (sign-alpha-int 0) sign-zero)
  (check-equal? (sign-alpha-int -3) sign-neg)
  (check-true  (sign-gamma-holds? sign-pos 5))
  (check-false (sign-gamma-holds? sign-pos -1))
  (check-false (sign-gamma-holds? sign-pos 0))
  (check-true  (sign-gamma-holds? sign-nonzero 7))
  (check-false (sign-gamma-holds? sign-nonzero 0))   ;; 0 ∉ γ(nonzero)
  (check-true  (sign-gamma-holds? sign-top 0)))

;; ---- transfer: add (pointwise) ----
(test-case "sign transfer: add"
  (check-equal? (sign-transfer-add sign-pos sign-pos) sign-pos)    ;; Pos+Pos = Pos
  (check-equal? (sign-transfer-add sign-pos sign-neg) sign-top)    ;; Pos+Neg = ⊤
  (check-equal? (sign-transfer-add sign-pos sign-zero) sign-pos)
  (check-equal? (sign-transfer-add sign-nonneg sign-nonneg) sign-nonneg) ;; {z,p}+{z,p}
  (check-equal? (sign-transfer-add sign-neg sign-neg) sign-neg)
  (check-equal? (sign-transfer-add sign-bot sign-pos) sign-bot))   ;; bot propagates

;; ---- transfer: mul / neg / abs / sub / div ----
(test-case "sign transfer: mul"
  (check-equal? (sign-transfer-mul sign-pos sign-neg) sign-neg)
  (check-equal? (sign-transfer-mul sign-neg sign-neg) sign-pos)
  (check-equal? (sign-transfer-mul sign-pos sign-zero) sign-zero)
  (check-equal? (sign-transfer-mul sign-nonzero sign-nonzero) sign-nonzero)) ;; {n,p}*{n,p}

(test-case "sign transfer: neg / abs"
  (check-equal? (sign-transfer-neg sign-pos) sign-neg)
  (check-equal? (sign-transfer-neg sign-nonneg) sign-nonpos)       ;; -{z,p} = {z,n}
  (check-equal? (sign-transfer-abs sign-neg) sign-pos)             ;; |neg| = pos
  (check-equal? (sign-transfer-abs sign-top) sign-nonneg)          ;; |⊤| = {z,p}
  (check-equal? (sign-transfer-abs sign-nonneg) sign-nonneg))

(test-case "sign transfer: sub / div"
  (check-equal? (sign-transfer-sub sign-pos sign-neg) sign-pos)    ;; pos - neg = pos
  (check-equal? (sign-transfer-div sign-pos sign-pos) sign-pos)
  (check-equal? (sign-transfer-div sign-neg sign-pos) sign-neg)
  (check-equal? (sign-transfer-div sign-pos sign-zero) sign-top)   ;; divisor may be 0 → ⊤
  (check-equal? (sign-transfer-div sign-pos sign-nonneg) sign-top));; nonneg ⊄ nonzero

;; ---- name <-> Sign / base tables + the design's key examples ----
(test-case "refined-name tables"
  (check-true  (refined-name? 'PosInt))
  (check-false (refined-name? 'Int))
  (check-equal? (refined-name->sign 'PosInt) sign-pos)
  (check-equal? (refined-name->sign 'NonZeroRat) sign-nonzero)
  (check-equal? (refined-name->base 'PosInt) 'Int)
  (check-equal? (refined-name->base 'NegRat) 'Rat)
  (check-equal? (refined-name->base 'Zero) 'Int)
  (check-equal? (base+sign->refined-name 'Int sign-pos) 'PosInt)
  (check-equal? (base+sign->refined-name 'Rat sign-neg) 'NegRat)
  (check-equal? (base+sign->refined-name 'Int sign-nonzero) 'NonZeroInt)
  (check-false  (base+sign->refined-name 'Int sign-nonneg))        ;; unnamed → bare base
  (check-false  (base+sign->refined-name 'Int sign-top)))

(test-case "design key examples: PosInt+PosInt→PosInt, PosInt+NegInt→Int"
  ;; PosInt + PosInt: base Int+Int=Int, sign pos+pos=pos → PosInt
  (let ([base 'Int]
        [s (sign-transfer-add (refined-name->sign 'PosInt) (refined-name->sign 'PosInt))])
    (check-equal? (base+sign->refined-name base s) 'PosInt))
  ;; PosInt + NegInt: sign pos+neg=⊤ → no named type → bare Int
  (let ([base 'Int]
        [s (sign-transfer-add (refined-name->sign 'PosInt) (refined-name->sign 'NegInt))])
    (check-false (base+sign->refined-name base s))))

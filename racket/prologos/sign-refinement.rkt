#lang racket/base
;; sign-refinement.rkt — Racket-side Sign refinement substrate for numeric typing.
;;
;; Numerics N5c (2026-06-30). Realizes the 8-element Sign transfer algebra + the
;; name<->Sign/base tables that the type-checker (N5d) consults for refinement-
;; preserving arithmetic and decomposed subsumption.
;;
;; ARCHITECTURE (owner-decided, N5c): the transfer lives HERE in Racket, where its
;; ONLY consumer (typing-core, N5d) lives — NOT as a Prologos `impl Add Sign`,
;; which would be speculative (the abstract-interpretation engine uses INTERVAL
;; arithmetic — interval-domain.rkt — not sign arithmetic, so nothing else consumes
;; a sign transfer). The Prologos `impl Lattice/GaloisConnection Sign`
;; (data/sign.prologos + abstract-domains.prologos, built in N5b) remain the
;; user/AI-facing Sign lattice algebra. This is the FIXED built-in Sign slice; the
;; general user-domain / Prologos-trait transfer is deferred to the UCS track
;; (design doc §9c; §15 "domain algebra = traits" holds for the lattice, which has
;; real consumers, not for the consumer-less transfer).
;;
;; Sign is an immutable seteq of atoms ⊆ {'neg 'zero 'pos} — the powerset
;; ℘({neg,zero,pos}) = the Boolean cube Q₃, with ⊑ = ⊆, join = ∪, bot = ∅.
;;
;; NOTE: NonZeroInt/NonZeroRat appear in the tables but their TYPE definitions land
;; in N5e; the reverse map can only produce them once a NonZero-signed operand
;; exists (which requires N5e), so they never fire prematurely.

(require racket/set)

(provide
 ;; lattice
 sign-bot sign-neg sign-zero sign-pos sign-nonpos sign-nonzero sign-nonneg sign-top
 sign? sign<=? sign-join sign-meet sign-name sign->atoms
 ;; Galois Int<->Sign
 sign-alpha-int sign-gamma-holds?
 ;; transfer (pointwise α∘op#∘(γ×γ))
 sign-transfer-add sign-transfer-sub sign-transfer-mul sign-transfer-div
 sign-transfer-neg sign-transfer-abs
 ;; name <-> Sign / base (the fixed built-in refined-type slice)
 refined-name? refined-name->sign refined-name->base base+sign->refined-name)

;; ---- Sign values: seteq of atoms ⊆ {'neg 'zero 'pos} ----
(define sign-bot     (seteq))
(define sign-neg     (seteq 'neg))
(define sign-zero    (seteq 'zero))
(define sign-pos     (seteq 'pos))
(define sign-nonpos  (seteq 'neg 'zero))
(define sign-nonzero (seteq 'neg 'pos))
(define sign-nonneg  (seteq 'zero 'pos))
(define sign-top     (seteq 'neg 'zero 'pos))

(define (sign? s)
  (and (set? s) (for/and ([a (in-set s)]) (and (memq a '(neg zero pos)) #t))))
(define (sign<=? a b) (subset? a b))     ;; ⊑ = ⊆
(define (sign-join a b) (set-union a b))  ;; join = ∪
(define (sign-meet a b) (set-intersect a b))
(define (sign->atoms s) (sort (set->list s) symbol<?))

;; canonical name symbol for a sign (display + reverse-map key)
(define (sign-name s)
  (cond
    [(set-empty? s)             'sign-bot]
    [(equal? s sign-neg)        'sign-neg]
    [(equal? s sign-zero)       'sign-zero]
    [(equal? s sign-pos)        'sign-pos]
    [(equal? s sign-nonpos)     'sign-nonpos]
    [(equal? s sign-nonzero)    'sign-nonzero]
    [(equal? s sign-nonneg)     'sign-nonneg]
    [else                       'sign-top]))

;; ---- Galois Int <-> Sign ----
(define (int-sign n) (cond [(< n 0) 'neg] [(= n 0) 'zero] [else 'pos]))
(define (sign-alpha-int n) (seteq (int-sign n)))              ;; α(n) = {sign n}
(define (sign-gamma-holds? s n) (set-member? s (int-sign n))) ;; n ∈ γ(S)

;; ---- scalar sign ops on atoms (op#) ----
(define (add# a b)                       ;; sign of a+b (a set)
  (cond
    [(eq? a 'zero) (seteq b)]
    [(eq? b 'zero) (seteq a)]
    [(eq? a b)     (seteq a)]            ;; neg+neg=neg, pos+pos=pos
    [else          sign-top]))           ;; neg+pos = ⊤
(define (mul# a b)                        ;; sign of a*b (an atom)
  (cond
    [(or (eq? a 'zero) (eq? b 'zero)) 'zero]
    [(eq? a b)                       'pos]   ;; neg*neg=pos, pos*pos=pos
    [else                            'neg])) ;; neg*pos = neg
(define (neg# a) (case a [(neg) 'pos] [(pos) 'neg] [else 'zero]))
(define (abs# a) (case a [(neg) 'pos] [else a]))   ;; |neg|=pos, |zero|=zero, |pos|=pos

;; ---- pointwise lift: transfer(S..) = ⋃ op#(atoms) (α∘op#∘(γ×γ)) ----
(define (lift2-set op S1 S2)   ;; op : atom×atom -> set
  (for*/fold ([acc sign-bot]) ([a (in-set S1)] [b (in-set S2)])
    (set-union acc (op a b))))
(define (lift2-atom op S1 S2)  ;; op : atom×atom -> atom
  (for*/fold ([acc sign-bot]) ([a (in-set S1)] [b (in-set S2)])
    (set-add acc (op a b))))
(define (lift1-atom op S)      ;; op : atom -> atom
  (for/fold ([acc sign-bot]) ([a (in-set S)])
    (set-add acc (op a))))

(define (sign-transfer-add S1 S2) (lift2-set add# S1 S2))
(define (sign-transfer-mul S1 S2) (lift2-atom mul# S1 S2))
(define (sign-transfer-neg S)     (lift1-atom neg# S))
(define (sign-transfer-abs S)     (lift1-atom abs# S))
(define (sign-transfer-sub S1 S2) (sign-transfer-add S1 (sign-transfer-neg S2)))
;; div: refined only if divisor ⊑ nonzero (no 'zero atom); else ⊤. sign(a/b)=sign(a*b), b≠0.
(define (sign-transfer-div S1 S2)
  (cond
    [(set-empty? S1)          sign-bot]
    [(set-empty? S2)          sign-bot]
    [(set-member? S2 'zero)   sign-top]        ;; divisor may be zero → unrefined
    [else                     (lift2-atom mul# S1 S2)]))

;; ---- name <-> Sign / base (the fixed built-in refined-type slice) ----
(define name->sign-tbl
  (hasheq 'PosInt sign-pos 'NegInt sign-neg 'Zero sign-zero 'NonZeroInt sign-nonzero
          'PosRat sign-pos 'NegRat sign-neg 'NonZeroRat sign-nonzero))
(define name->base-tbl
  (hasheq 'PosInt 'Int 'NegInt 'Int 'Zero 'Int 'NonZeroInt 'Int
          'PosRat 'Rat 'NegRat 'Rat 'NonZeroRat 'Rat))
;; reverse: (base . sign-name) -> refined-name, for NAMED signs only.
(define base+sign->name-tbl
  (hash (cons 'Int 'sign-pos)     'PosInt     (cons 'Int 'sign-neg)     'NegInt
        (cons 'Int 'sign-zero)    'Zero       (cons 'Int 'sign-nonzero) 'NonZeroInt
        (cons 'Rat 'sign-pos)     'PosRat     (cons 'Rat 'sign-neg)     'NegRat
        (cons 'Rat 'sign-nonzero) 'NonZeroRat))

(define (refined-name? name) (hash-has-key? name->sign-tbl name))
(define (refined-name->sign name) (hash-ref name->sign-tbl name #f))
(define (refined-name->base name) (hash-ref name->base-tbl name #f))
;; base symbol × sign -> refined-name, or #f (bare base) for unnamed signs / top / bot.
(define (base+sign->refined-name base s)
  (hash-ref base+sign->name-tbl (cons base (sign-name s)) #f))

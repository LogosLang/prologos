#lang racket/base

;;;
;;; PROLOGOS SYNTAX
;;; The complete term language for Prologos in locally-nameless representation.
;;; Direct translation of prologos-syntax.maude + prologos-inductive.maude constructors.
;;;
;;; Bound variables are de Bruijn indices (expr-bvar).
;;; Free variables are names (expr-fvar).
;;; Types are Expr (types are first-class in dependent type theory).
;;;

(require "prelude.rkt")

(provide
 ;; Expression constructors
 (struct-out expr-bvar)
 (struct-out expr-fvar)
 (struct-out expr-zero)
 (struct-out expr-suc)
 (struct-out expr-nat-val)
 (struct-out expr-lam)
 (struct-out expr-app)
 (struct-out expr-pair)
 (struct-out expr-fst)
 (struct-out expr-snd)
 (struct-out expr-refl)
 (struct-out expr-ann)
 (struct-out expr-natrec)
 (struct-out expr-J)
 ;; Type constructors (also Exprs)
 (struct-out expr-Type)
 (struct-out expr-Nat)
 (struct-out expr-Bool)
 (struct-out expr-true)
 (struct-out expr-false)
 (struct-out expr-boolrec)
 (struct-out expr-Unit)
 (struct-out expr-unit)
 (struct-out expr-Nil)
 (struct-out expr-nil)
 (struct-out expr-nil-check)
 (struct-out expr-Pi)
 (struct-out expr-Sigma)
 (struct-out expr-Eq)
 ;; Vec/Fin (from inductive module — defined upfront)
 (struct-out expr-Vec)
 (struct-out expr-vnil)
 (struct-out expr-vcons)
 (struct-out expr-Fin)
 (struct-out expr-fzero)
 (struct-out expr-fsuc)
 (struct-out expr-vhead)
 (struct-out expr-vtail)
 (struct-out expr-vindex)
 ;; Posit8 (8-bit posit, es=2, 2022 Standard)
 (struct-out expr-Posit8)
 (struct-out expr-posit8)
 (struct-out expr-p8-add)
 (struct-out expr-p8-sub)
 (struct-out expr-p8-mul)
 (struct-out expr-p8-div)
 (struct-out expr-p8-neg)
 (struct-out expr-p8-abs)
 (struct-out expr-p8-sqrt)
 (struct-out expr-p8-lt)
 (struct-out expr-p8-le)
 (struct-out expr-p8-eq)
 (struct-out expr-p8-from-nat)
 (struct-out expr-p8-to-rat) (struct-out expr-p8-from-rat) (struct-out expr-p8-from-int)
 (struct-out expr-p8-if-nar)
 ;; Posit16 (16-bit posit, es=2, 2022 Standard)
 (struct-out expr-Posit16)
 (struct-out expr-posit16)
 (struct-out expr-p16-add)
 (struct-out expr-p16-sub)
 (struct-out expr-p16-mul)
 (struct-out expr-p16-div)
 (struct-out expr-p16-neg)
 (struct-out expr-p16-abs)
 (struct-out expr-p16-sqrt)
 (struct-out expr-p16-lt)
 (struct-out expr-p16-le)
 (struct-out expr-p16-eq)
 (struct-out expr-p16-from-nat)
 (struct-out expr-p16-to-rat) (struct-out expr-p16-from-rat) (struct-out expr-p16-from-int)
 (struct-out expr-p16-if-nar)
 ;; Posit32 (32-bit posit, es=2, 2022 Standard)
 (struct-out expr-Posit32)
 (struct-out expr-posit32)
 (struct-out expr-p32-add)
 (struct-out expr-p32-sub)
 (struct-out expr-p32-mul)
 (struct-out expr-p32-div)
 (struct-out expr-p32-neg)
 (struct-out expr-p32-abs)
 (struct-out expr-p32-sqrt)
 (struct-out expr-p32-lt)
 (struct-out expr-p32-le)
 (struct-out expr-p32-eq)
 (struct-out expr-p32-from-nat)
 (struct-out expr-p32-to-rat) (struct-out expr-p32-from-rat) (struct-out expr-p32-from-int)
 (struct-out expr-p32-if-nar)
 ;; Posit64 (64-bit posit, es=2, 2022 Standard)
 (struct-out expr-Posit64)
 (struct-out expr-posit64)
 (struct-out expr-p64-add)
 (struct-out expr-p64-sub)
 (struct-out expr-p64-mul)
 (struct-out expr-p64-div)
 (struct-out expr-p64-neg)
 (struct-out expr-p64-abs)
 (struct-out expr-p64-sqrt)
 (struct-out expr-p64-lt)
 (struct-out expr-p64-le)
 (struct-out expr-p64-eq)
 (struct-out expr-p64-from-nat)
 (struct-out expr-p64-to-rat) (struct-out expr-p64-from-rat) (struct-out expr-p64-from-int)
 (struct-out expr-p64-if-nar)
 ;; Quire accumulators (exact product sums for posit types)
 (struct-out expr-Quire8) (struct-out expr-quire8-val)
 (struct-out expr-quire8-fma) (struct-out expr-quire8-to)
 (struct-out expr-Quire16) (struct-out expr-quire16-val)
 (struct-out expr-quire16-fma) (struct-out expr-quire16-to)
 (struct-out expr-Quire32) (struct-out expr-quire32-val)
 (struct-out expr-quire32-fma) (struct-out expr-quire32-to)
 (struct-out expr-Quire64) (struct-out expr-quire64-val)
 (struct-out expr-quire64-fma) (struct-out expr-quire64-to)
 ;; Symbol type (opaque atomic type for code-as-data)
 (struct-out expr-Symbol) (struct-out expr-symbol)
 ;; Keyword type (opaque atomic type for map keys)
 (struct-out expr-Keyword) (struct-out expr-keyword)
 ;; Char type (opaque atomic type for Unicode codepoints)
 (struct-out expr-Char) (struct-out expr-char)
 ;; String type (opaque atomic type for UTF-8 text)
 (struct-out expr-String) (struct-out expr-string)
 ;; Map (persistent hash map)
 (struct-out expr-Map) (struct-out expr-champ)
 (struct-out expr-map-empty) (struct-out expr-map-assoc)
 (struct-out expr-map-get) (struct-out expr-nil-safe-get) (struct-out expr-map-dissoc)
 (struct-out expr-map-size) (struct-out expr-map-has-key)
 (struct-out expr-map-keys) (struct-out expr-map-vals)
 (struct-out expr-get) (struct-out expr-get-in) (struct-out expr-update-in)
 ;; Set (persistent hash set)
 (struct-out expr-Set) (struct-out expr-hset)
 (struct-out expr-set-empty) (struct-out expr-set-insert)
 (struct-out expr-set-member) (struct-out expr-set-delete)
 (struct-out expr-set-size) (struct-out expr-set-union)
 (struct-out expr-set-intersect) (struct-out expr-set-diff)
 (struct-out expr-set-to-list)
 ;; Persistent Vector (PVec)
 (struct-out expr-PVec) (struct-out expr-rrb) (struct-out expr-pvec-empty)
 (struct-out expr-pvec-push) (struct-out expr-pvec-nth) (struct-out expr-pvec-update)
 (struct-out expr-pvec-length) (struct-out expr-pvec-pop)
 (struct-out expr-pvec-concat) (struct-out expr-pvec-slice)
 (struct-out expr-pvec-to-list) (struct-out expr-pvec-from-list)
 (struct-out expr-pvec-fold) (struct-out expr-pvec-map) (struct-out expr-pvec-filter)
 (struct-out expr-set-fold) (struct-out expr-set-filter)
 (struct-out expr-map-fold-entries) (struct-out expr-map-filter-entries) (struct-out expr-map-map-vals)
 ;; Transient Builders (mutable versions for batch construction)
 (struct-out expr-transient) (struct-out expr-persist)
 (struct-out expr-TVec) (struct-out expr-trrb)
 (struct-out expr-TMap) (struct-out expr-tchamp)
 (struct-out expr-TSet) (struct-out expr-thset)
 (struct-out expr-transient-vec) (struct-out expr-persist-vec)
 (struct-out expr-transient-map) (struct-out expr-persist-map)
 (struct-out expr-transient-set) (struct-out expr-persist-set)
 (struct-out expr-tvec-push!) (struct-out expr-tvec-update!)
 (struct-out expr-tmap-assoc!) (struct-out expr-tmap-dissoc!)
 (struct-out expr-tset-insert!) (struct-out expr-tset-delete!)
 ;; PropNetwork (persistent propagator network)
 (struct-out expr-net-type) (struct-out expr-cell-id-type) (struct-out expr-prop-id-type)
 (struct-out expr-prop-network) (struct-out expr-cell-id) (struct-out expr-prop-id)
 (struct-out expr-net-new) (struct-out expr-net-new-cell) (struct-out expr-net-new-cell-widen)
 (struct-out expr-net-cell-read) (struct-out expr-net-cell-write)
 (struct-out expr-net-add-prop) (struct-out expr-net-run)
 (struct-out expr-net-snapshot) (struct-out expr-net-contradiction)
 ;; UnionFind (persistent disjoint sets)
 (struct-out expr-uf-type) (struct-out expr-uf-store)
 (struct-out expr-uf-empty) (struct-out expr-uf-make-set)
 (struct-out expr-uf-find) (struct-out expr-uf-union)
 (struct-out expr-uf-value)
 ;; ATMS (persistent assumption-based truth maintenance)
 (struct-out expr-atms-type) (struct-out expr-assumption-id-type)
 (struct-out expr-atms-store) (struct-out expr-assumption-id-val)
 (struct-out expr-atms-new) (struct-out expr-atms-assume)
 (struct-out expr-atms-retract) (struct-out expr-atms-nogood)
 (struct-out expr-atms-amb) (struct-out expr-atms-solve-all)
 (struct-out expr-atms-read) (struct-out expr-atms-write)
 (struct-out expr-atms-consistent) (struct-out expr-atms-worldview)
 ;; Tabling (SLG-style memoization)
 (struct-out expr-table-store-type) (struct-out expr-table-store-val)
 (struct-out expr-table-new) (struct-out expr-table-register)
 (struct-out expr-table-add) (struct-out expr-table-answers)
 (struct-out expr-table-freeze) (struct-out expr-table-complete)
 (struct-out expr-table-run) (struct-out expr-table-lookup)
 ;; Opaque FFI values (IO library)
 (struct-out expr-opaque)
 ;; Relational language (Phase 7)
 (struct-out expr-defr) (struct-out expr-defr-variant)
 (struct-out expr-rel) (struct-out expr-clause) (struct-out expr-fact-block) (struct-out expr-fact-row)
 (struct-out expr-goal-app) (struct-out expr-logic-var) (struct-out expr-unify-goal) (struct-out expr-is-goal) (struct-out expr-not-goal)
 ;; Narrowing (Phase 1e)
 (struct-out expr-narrow)
 (struct-out expr-relation-type) (struct-out expr-schema) (struct-out expr-schema-type)
 (struct-out expr-solve) (struct-out expr-solve-with) (struct-out expr-solve-one) (struct-out expr-goal-type)
 (struct-out expr-explain) (struct-out expr-explain-with)
 (struct-out expr-solver-config) (struct-out expr-solver-type)
 (struct-out expr-all-different) (struct-out expr-element)
 (struct-out expr-cumulative) (struct-out expr-minimize)
 (struct-out expr-answer-type) (struct-out expr-derivation-type)
 (struct-out expr-cut) (struct-out expr-guard)
 ;; Int (arbitrary-precision integers)
 (struct-out expr-Int)
 (struct-out expr-int)
 (struct-out expr-int-add)
 (struct-out expr-int-sub)
 (struct-out expr-int-mul)
 (struct-out expr-int-div)
 (struct-out expr-int-mod)
 (struct-out expr-int-neg)
 (struct-out expr-int-abs)
 (struct-out expr-int-lt)
 (struct-out expr-int-le)
 (struct-out expr-int-eq)
 (struct-out expr-from-nat)
 ;; Rat (exact rationals)
 (struct-out expr-Rat)
 (struct-out expr-rat)
 (struct-out expr-rat-add)
 (struct-out expr-rat-sub)
 (struct-out expr-rat-mul)
 (struct-out expr-rat-div)
 (struct-out expr-rat-neg)
 (struct-out expr-rat-abs)
 (struct-out expr-rat-lt)
 (struct-out expr-rat-le)
 (struct-out expr-rat-eq)
 (struct-out expr-from-int)
 (struct-out expr-rat-numer)
 (struct-out expr-rat-denom)
 ;; Generic arithmetic operators (type-polymorphic over all numeric types)
 (struct-out expr-generic-add)
 (struct-out expr-generic-sub)
 (struct-out expr-generic-mul)
 (struct-out expr-generic-div)
 (struct-out expr-generic-lt)
 (struct-out expr-generic-le)
 (struct-out expr-generic-eq)
 (struct-out expr-generic-negate)
 (struct-out expr-generic-abs)
 ;; Generic conversion operators (type-directed)
 (struct-out expr-generic-from-int)
 (struct-out expr-generic-from-rat)
 ;; Foreign function binding
 (struct-out expr-foreign-fn)
 ;; Type hole (to be inferred during checking)
 (struct-out expr-hole)
 ;; Typed hole (?? or ??name — reports expected type)
 (struct-out expr-typed-hole)
 ;; Panic (runtime abort — inhabits any type)
 (struct-out expr-panic)
 ;; Metavariable (to be solved during elaboration/unification)
 (struct-out expr-meta)
 ;; Reduce (ML-style pattern matching — desugared in type checker)
 (struct-out expr-reduce)
 (struct-out expr-reduce-arm)
 ;; Union types
 (struct-out expr-union)
 ;; Unapplied type constructor (HKT support)
 (struct-out expr-tycon)
 builtin-tycon-arity
 current-tycon-arity-extension
 tycon-arity
 ;; Error marker
 (struct-out expr-error)
 ;; Expr predicate
 expr?
 ;; Convenience
 nat->expr arrow sigma-pair
 ;; Context operations
 ctx-empty ctx-extend
 lookup-type lookup-mult ctx-len)

;; ========================================
;; Expression Constructors
;; ========================================

;; Variables
(struct expr-bvar (index) #:transparent)         ; bound variable (de Bruijn index)
(struct expr-fvar (name) #:transparent)           ; free variable (named)

;; Natural numbers
(struct expr-zero () #:transparent)
(struct expr-suc (pred) #:transparent)
(struct expr-nat-val (n) #:transparent)   ; O(1) native natural number (Idris 2 model)

;; Lambda and application
(struct expr-lam (mult type body) #:transparent)  ; lam(mult, type, body)
(struct expr-app (func arg) #:transparent)        ; app(func, arg)

;; Pairs (Sigma intro/elim)
(struct expr-pair (fst snd) #:transparent)
(struct expr-fst (expr) #:transparent)
(struct expr-snd (expr) #:transparent)

;; Equality introduction
(struct expr-refl () #:transparent)

;; Type annotation
(struct expr-ann (term type) #:transparent)       ; ann(term, type)

;; Nat eliminator
;; natrec(motive, base, step, target)
;; motive : Nat -> Type
;; base   : motive(0)
;; step   : Pi(n:Nat). motive(n) -> motive(suc(n))
;; target : Nat
(struct expr-natrec (motive base step target) #:transparent)

;; J eliminator for equality
;; J(motive, base, target-left, target-right, proof)
;; motive : Pi(a:A). Pi(b:A). (a = b) -> Type
;; base   : Pi(a:A). motive(a, a, refl)
;; target-left, target-right : A
;; proof  : target-left = target-right
(struct expr-J (motive base left right proof) #:transparent)

;; ========================================
;; Type Constructors (also Exprs)
;; ========================================

;; Universe
(struct expr-Type (level) #:transparent)          ; Type(n) : Type(n+1)

;; Natural number type
(struct expr-Nat () #:transparent)

;; Bool type
(struct expr-Bool () #:transparent)
(struct expr-true () #:transparent)
(struct expr-false () #:transparent)

;; Bool eliminator
;; boolrec(motive, true-case, false-case, target)
;; motive     : Bool -> Type(l)
;; true-case  : motive(true)
;; false-case : motive(false)
;; target     : Bool
;; result     : motive(target)
(struct expr-boolrec (motive true-case false-case target) #:transparent)

;; Unit type
(struct expr-Unit () #:transparent)
(struct expr-unit () #:transparent)

;; Nil type (nullable/nothing type — distinct from list's nil)
(struct expr-Nil () #:transparent)
(struct expr-nil () #:transparent)
(struct expr-nil-check (arg) #:transparent)  ; nil? : A -> Bool

;; Dependent function type
(struct expr-Pi (mult domain codomain) #:transparent) ; Pi(mult, domain, codomain)

;; Dependent pair type
(struct expr-Sigma (fst-type snd-type) #:transparent) ; Sigma(fst-type, snd-type)

;; Identity/Equality type
(struct expr-Eq (type lhs rhs) #:transparent)     ; Eq(type, lhs, rhs)

;; ========================================
;; Vec and Fin (from prologos-inductive.maude)
;; Defined upfront since the full set of constructors is known.
;; ========================================

;; Vec type: Vec(A, n) where A : Type and n : Nat
(struct expr-Vec (elem-type length) #:transparent)

;; Vec constructors
(struct expr-vnil (type) #:transparent)            ; vnil(A) : Vec(A, zero)
(struct expr-vcons (type len head tail) #:transparent) ; vcons(A, n, head, tail) : Vec(A, suc(n))

;; Fin type: Fin(n) where n : Nat
(struct expr-Fin (bound) #:transparent)

;; Fin constructors
(struct expr-fzero (n) #:transparent)              ; fzero(n) : Fin(suc(n))
(struct expr-fsuc (n inner) #:transparent)         ; fsuc(n, i) : Fin(suc(n)) when i : Fin(n)

;; Vec eliminators
(struct expr-vhead (type len vec) #:transparent)   ; vhead(A, n, v) : A
(struct expr-vtail (type len vec) #:transparent)   ; vtail(A, n, v) : Vec(A, n)
(struct expr-vindex (type len idx vec) #:transparent) ; vindex(A, n, i, v) : A

;; ========================================
;; Posit8 (8-bit posit, es=2, 2022 Standard)
;; ========================================

;; Type
(struct expr-Posit8 () #:transparent)                           ; Posit8 : Type 0

;; Value (val is exact integer 0–255 representing the posit8 bit pattern)
(struct expr-posit8 (val) #:transparent)                        ; posit8 literal

;; Binary arithmetic (Posit8 -> Posit8 -> Posit8)
(struct expr-p8-add (a b) #:transparent)
(struct expr-p8-sub (a b) #:transparent)
(struct expr-p8-mul (a b) #:transparent)
(struct expr-p8-div (a b) #:transparent)

;; Unary operations (Posit8 -> Posit8)
(struct expr-p8-neg (a) #:transparent)
(struct expr-p8-abs (a) #:transparent)
(struct expr-p8-sqrt (a) #:transparent)

;; Comparison (Posit8 -> Posit8 -> Bool)
(struct expr-p8-lt (a b) #:transparent)
(struct expr-p8-le (a b) #:transparent)
(struct expr-p8-eq (a b) #:transparent)

;; Conversion (Nat -> Posit8)
(struct expr-p8-from-nat (n) #:transparent)
;; Phase 3f: Cross-family conversions
(struct expr-p8-to-rat (a) #:transparent)     ; Posit8 -> Rat
(struct expr-p8-from-rat (a) #:transparent)   ; Rat -> Posit8
(struct expr-p8-from-int (a) #:transparent)   ; Int -> Posit8

;; Eliminator: branch on NaR
;; p8-if-nar(A, nar-case, normal-case, x) : A
;; If x is NaR, return nar-case; otherwise, return normal-case
(struct expr-p8-if-nar (type nar-case normal-case val) #:transparent)

;; ========================================
;; Posit16 (16-bit posit, es=2, 2022 Standard)
;; ========================================

(struct expr-Posit16 () #:transparent)
(struct expr-posit16 (val) #:transparent)
(struct expr-p16-add (a b) #:transparent)
(struct expr-p16-sub (a b) #:transparent)
(struct expr-p16-mul (a b) #:transparent)
(struct expr-p16-div (a b) #:transparent)
(struct expr-p16-neg (a) #:transparent)
(struct expr-p16-abs (a) #:transparent)
(struct expr-p16-sqrt (a) #:transparent)
(struct expr-p16-lt (a b) #:transparent)
(struct expr-p16-le (a b) #:transparent)
(struct expr-p16-eq (a b) #:transparent)
(struct expr-p16-from-nat (n) #:transparent)
(struct expr-p16-to-rat (a) #:transparent)     ; Posit16 -> Rat
(struct expr-p16-from-rat (a) #:transparent)   ; Rat -> Posit16
(struct expr-p16-from-int (a) #:transparent)   ; Int -> Posit16
(struct expr-p16-if-nar (type nar-case normal-case val) #:transparent)

;; ========================================
;; Posit32 (32-bit posit, es=2, 2022 Standard)
;; ========================================

(struct expr-Posit32 () #:transparent)
(struct expr-posit32 (val) #:transparent)
(struct expr-p32-add (a b) #:transparent)
(struct expr-p32-sub (a b) #:transparent)
(struct expr-p32-mul (a b) #:transparent)
(struct expr-p32-div (a b) #:transparent)
(struct expr-p32-neg (a) #:transparent)
(struct expr-p32-abs (a) #:transparent)
(struct expr-p32-sqrt (a) #:transparent)
(struct expr-p32-lt (a b) #:transparent)
(struct expr-p32-le (a b) #:transparent)
(struct expr-p32-eq (a b) #:transparent)
(struct expr-p32-from-nat (n) #:transparent)
(struct expr-p32-to-rat (a) #:transparent)     ; Posit32 -> Rat
(struct expr-p32-from-rat (a) #:transparent)   ; Rat -> Posit32
(struct expr-p32-from-int (a) #:transparent)   ; Int -> Posit32
(struct expr-p32-if-nar (type nar-case normal-case val) #:transparent)

;; ========================================
;; Posit64 (64-bit posit, es=2, 2022 Standard)
;; ========================================

(struct expr-Posit64 () #:transparent)
(struct expr-posit64 (val) #:transparent)
(struct expr-p64-add (a b) #:transparent)
(struct expr-p64-sub (a b) #:transparent)
(struct expr-p64-mul (a b) #:transparent)
(struct expr-p64-div (a b) #:transparent)
(struct expr-p64-neg (a) #:transparent)
(struct expr-p64-abs (a) #:transparent)
(struct expr-p64-sqrt (a) #:transparent)
(struct expr-p64-lt (a b) #:transparent)
(struct expr-p64-le (a b) #:transparent)
(struct expr-p64-eq (a b) #:transparent)
(struct expr-p64-from-nat (n) #:transparent)
(struct expr-p64-to-rat (a) #:transparent)     ; Posit64 -> Rat
(struct expr-p64-from-rat (a) #:transparent)   ; Rat -> Posit64
(struct expr-p64-from-int (a) #:transparent)   ; Int -> Posit64
(struct expr-p64-if-nar (type nar-case normal-case val) #:transparent)

;; ========================================
;; Quire accumulators (exact product sums for posit types)
;; ========================================
;; A quire accumulates exact sums of products.  Runtime value is an exact
;; Racket rational (or 'nar for NaR contamination).

;; Quire8 (32-bit accumulator for Posit8)
(struct expr-Quire8 () #:transparent)                              ; Quire8 : Type 0
(struct expr-quire8-val (v) #:transparent)                         ; quire literal (runtime)
(struct expr-quire8-fma (q a b) #:transparent)                     ; Quire8 → Posit8 → Posit8 → Quire8
(struct expr-quire8-to (q) #:transparent)                          ; Quire8 → Posit8

;; Quire16 (128-bit accumulator for Posit16)
(struct expr-Quire16 () #:transparent)
(struct expr-quire16-val (v) #:transparent)
(struct expr-quire16-fma (q a b) #:transparent)
(struct expr-quire16-to (q) #:transparent)

;; Quire32 (512-bit accumulator for Posit32)
(struct expr-Quire32 () #:transparent)
(struct expr-quire32-val (v) #:transparent)
(struct expr-quire32-fma (q a b) #:transparent)
(struct expr-quire32-to (q) #:transparent)

;; Quire64 (2048-bit accumulator for Posit64)
(struct expr-Quire64 () #:transparent)
(struct expr-quire64-val (v) #:transparent)
(struct expr-quire64-fma (q a b) #:transparent)
(struct expr-quire64-to (q) #:transparent)

;; ========================================
;; Symbol (opaque atomic type for code-as-data)
;; ========================================

;; Type
(struct expr-Symbol () #:transparent)                         ; Symbol : Type 0
;; Value (name is a Racket symbol, e.g. 'foo)
(struct expr-symbol (name) #:transparent)                     ; symbol literal

;; ========================================
;; Keyword (opaque atomic type for map keys)
;; ========================================

;; Type
(struct expr-Keyword () #:transparent)                        ; Keyword : Type 0
;; Value (name is a Racket symbol, e.g. 'name for :name)
(struct expr-keyword (name) #:transparent)                    ; keyword literal

;; ========================================
;; Char (opaque atomic type for Unicode codepoints)
;; ========================================

;; Type
(struct expr-Char () #:transparent)                          ; Char : Type 0
;; Value (val is a Racket character, e.g. #\a)
(struct expr-char (val) #:transparent)                       ; char literal

;; ========================================
;; String (opaque atomic type for UTF-8 text)
;; ========================================

;; Type
(struct expr-String () #:transparent)                        ; String : Type 0
;; Value (val is a Racket string, e.g. "hello")
(struct expr-string (val) #:transparent)                     ; string literal

;; ========================================
;; Map (persistent hash map, backed by CHAMP)
;; ========================================

;; Type constructor: Map K V
(struct expr-Map (k-type v-type) #:transparent)               ; Map K V : Type 0

;; Runtime value (racket-champ is a champ-root from champ.rkt)
(struct expr-champ (racket-champ) #:transparent)              ; map literal value

;; Constructor
(struct expr-map-empty (k-type v-type) #:transparent)         ; empty map : Map K V

;; Operations
(struct expr-map-assoc (m k v) #:transparent)                 ; assoc : Map K V → K → V → Map K V
(struct expr-get (coll key) #:transparent)                     ; get : Collection → Key → Option Value (type-directed)
(struct expr-map-get (m k) #:transparent)                     ; get : Map K V → K → V (error if missing)
(struct expr-nil-safe-get (m k) #:transparent)                ; nil-safe-get : (Map K V | Nil) → K → (V | Nil)
(struct expr-map-dissoc (m k) #:transparent)                  ; dissoc : Map K V → K → Map K V
(struct expr-map-size (m) #:transparent)                      ; size : Map K V → Nat
(struct expr-map-has-key (m k) #:transparent)                 ; has-key? : Map K V → K → Bool
(struct expr-map-keys (m) #:transparent)                      ; keys : Map K V → List K
(struct expr-map-vals (m) #:transparent)                      ; vals : Map K V → List V

;; Path algebra operations
(struct expr-get-in (target paths) #:transparent)             ; get-in : M → paths → V
(struct expr-update-in (target paths fn) #:transparent)       ; update-in : M → paths → (V → V) → M

;; ========================================
;; Set (persistent hash set, backed by CHAMP with #t sentinel)
;; ========================================

;; Type constructor: Set A
(struct expr-Set (elem-type) #:transparent)                   ; Set A : Type(level(A))

;; Runtime value (racket-champ is a champ-root from champ.rkt, values are #t)
(struct expr-hset (racket-champ) #:transparent)               ; set literal value

;; Constructor
(struct expr-set-empty (elem-type) #:transparent)             ; empty set : Set A

;; Operations
(struct expr-set-insert (s a) #:transparent)                  ; set-insert : Set A → A → Set A
(struct expr-set-member (s a) #:transparent)                  ; set-member? : Set A → A → Bool
(struct expr-set-delete (s a) #:transparent)                  ; set-delete : Set A → A → Set A
(struct expr-set-size (s) #:transparent)                      ; set-size : Set A → Nat
(struct expr-set-union (s1 s2) #:transparent)                 ; set-union : Set A → Set A → Set A
(struct expr-set-intersect (s1 s2) #:transparent)             ; set-intersect : Set A → Set A → Set A
(struct expr-set-diff (s1 s2) #:transparent)                  ; set-diff : Set A → Set A → Set A
(struct expr-set-to-list (s) #:transparent)                   ; set-to-list : Set A → List A

;; ---- Persistent Vector (PVec, RRB-Tree-backed) ----
(struct expr-PVec (elem-type) #:transparent)                  ; PVec A : Type(level(A))
(struct expr-rrb (racket-rrb) #:transparent)                  ; runtime wrapper (opaque Racket rrb-root)
(struct expr-pvec-empty (elem-type) #:transparent)            ; pvec-empty(A) : PVec A
(struct expr-pvec-push (v x) #:transparent)                   ; pvec-push : PVec A → A → PVec A
(struct expr-pvec-nth (v i) #:transparent)                    ; pvec-nth : PVec A → Nat → A
(struct expr-pvec-update (v i x) #:transparent)               ; pvec-update : PVec A → Nat → A → PVec A
(struct expr-pvec-length (v) #:transparent)                   ; pvec-length : PVec A → Nat
(struct expr-pvec-pop (v) #:transparent)                      ; pvec-pop : PVec A → PVec A
(struct expr-pvec-concat (v1 v2) #:transparent)               ; pvec-concat : PVec A → PVec A → PVec A
(struct expr-pvec-slice (v lo hi) #:transparent)              ; pvec-slice : PVec A → Nat → Nat → PVec A
(struct expr-pvec-to-list (v) #:transparent)                  ; pvec-to-list : PVec A → List A
(struct expr-pvec-from-list (v) #:transparent)                ; pvec-from-list : List A → PVec A
(struct expr-pvec-fold (f init vec) #:transparent)            ; pvec-fold : (B → A → B) → B → PVec A → B
(struct expr-pvec-map (f vec) #:transparent)                  ; pvec-map : (A → B) → PVec A → PVec B
(struct expr-pvec-filter (pred vec) #:transparent)            ; pvec-filter : (A → Bool) → PVec A → PVec A
(struct expr-set-fold (f init set) #:transparent)             ; set-fold : (B → A → B) → B → Set A → B
(struct expr-set-filter (pred set) #:transparent)             ; set-filter : (A → Bool) → Set A → Set A
(struct expr-map-fold-entries (f init map) #:transparent)     ; map-fold-entries : (B → K → V → B) → B → Map K V → B
(struct expr-map-filter-entries (pred map) #:transparent)     ; map-filter-entries : (K → V → Bool) → Map K V → Map K V
(struct expr-map-map-vals (f map) #:transparent)              ; map-map-vals : (V → W) → Map K V → Map K W

;; ---- Transient Builders (mutable versions for batch construction) ----

;; Transient type constructors
(struct expr-TVec (elem-type) #:transparent)                   ; TVec A : Type(level(A))
(struct expr-TMap (k-type v-type) #:transparent)               ; TMap K V : Type(max(level(K),level(V)))
(struct expr-TSet (elem-type) #:transparent)                   ; TSet A : Type(level(A))

;; Runtime wrappers (opaque Racket values)
(struct expr-trrb (racket-trrb) #:transparent)                 ; transient PVec value
(struct expr-tchamp (racket-tchamp) #:transparent)             ; transient Map value
(struct expr-thset (racket-tchamp) #:transparent)              ; transient Set value (uses tchamp with val=#t)

;; Generic conversion (resolved by type checker into specific node)
(struct expr-transient (coll) #:transparent)                   ; generic transient
(struct expr-persist (coll) #:transparent)                     ; generic persist!

;; Conversion operations
(struct expr-transient-vec (v) #:transparent)                  ; PVec A → TVec A
(struct expr-persist-vec (t) #:transparent)                    ; TVec A → PVec A
(struct expr-transient-map (m) #:transparent)                  ; Map K V → TMap K V
(struct expr-persist-map (t) #:transparent)                    ; TMap K V → Map K V
(struct expr-transient-set (s) #:transparent)                  ; Set A → TSet A
(struct expr-persist-set (t) #:transparent)                    ; TSet A → Set A

;; Mutation operations (return transient for linear threading)
(struct expr-tvec-push! (t x) #:transparent)                   ; TVec A → A → TVec A
(struct expr-tvec-update! (t i x) #:transparent)               ; TVec A → Nat → A → TVec A
(struct expr-tmap-assoc! (t k v) #:transparent)                ; TMap K V → K → V → TMap K V
(struct expr-tmap-dissoc! (t k) #:transparent)                 ; TMap K V → K → TMap K V
(struct expr-tset-insert! (t a) #:transparent)                 ; TSet A → A → TSet A
(struct expr-tset-delete! (t a) #:transparent)                 ; TSet A → A → TSet A

;; ========================================
;; PropNetwork (persistent propagator network)
;; ========================================

;; Type constructors
(struct expr-net-type () #:transparent)                          ; PropNetwork : Type 0
(struct expr-cell-id-type () #:transparent)                      ; CellId : Type 0
(struct expr-prop-id-type () #:transparent)                      ; PropId : Type 0

;; Runtime wrappers (opaque Racket values from propagator.rkt)
(struct expr-prop-network (net-value) #:transparent)             ; wrapped prop-network
(struct expr-cell-id (cell-id-value) #:transparent)              ; wrapped cell-id
(struct expr-prop-id (prop-id-value) #:transparent)              ; wrapped prop-id

;; Operations
(struct expr-net-new (fuel) #:transparent)                       ; Int -> PropNetwork
(struct expr-net-new-cell (net init merge) #:transparent)        ; PropNetwork -> A -> (A A -> A) -> [PropNetwork * CellId]
(struct expr-net-new-cell-widen (net init merge widen-fn narrow-fn) #:transparent) ; PropNetwork -> A -> (A A -> A) -> (A A -> A) -> (A A -> A) -> [PropNetwork * CellId]
(struct expr-net-cell-read (net cell) #:transparent)             ; PropNetwork -> CellId -> A
(struct expr-net-cell-write (net cell val) #:transparent)        ; PropNetwork -> CellId -> A -> PropNetwork
(struct expr-net-add-prop (net ins outs fn) #:transparent)       ; PropNetwork -> [List CellId] -> [List CellId] -> fn -> [PropNetwork * PropId]
(struct expr-net-run (net) #:transparent)                        ; PropNetwork -> PropNetwork
(struct expr-net-snapshot (net) #:transparent)                   ; PropNetwork -> PropNetwork (identity on persistent data)
(struct expr-net-contradiction (net) #:transparent)              ; PropNetwork -> Bool

;; ========================================
;; UnionFind (persistent disjoint sets, Conchon & Filliâtre 2007)
;; ========================================

;; Type constructor
(struct expr-uf-type () #:transparent)                            ; UnionFind : Type 0

;; Runtime wrapper (opaque Racket uf-store from union-find.rkt)
(struct expr-uf-store (store-value) #:transparent)                ; wrapped uf-store

;; Operations
(struct expr-uf-empty () #:transparent)                           ; UnionFind (nullary constructor)
(struct expr-uf-make-set (store id val) #:transparent)            ; UnionFind -> Nat -> A -> UnionFind
(struct expr-uf-find (store id) #:transparent)                    ; UnionFind -> Nat -> [Nat * UnionFind]
(struct expr-uf-union (store id1 id2) #:transparent)              ; UnionFind -> Nat -> Nat -> UnionFind
(struct expr-uf-value (store id) #:transparent)                   ; UnionFind -> Nat -> A (type-unsafe)

;; ========================================
;; ATMS (persistent assumption-based truth maintenance, de Kleer 1986)
;; ========================================

;; Type constructors
(struct expr-atms-type () #:transparent)                          ; ATMS : Type 0
(struct expr-assumption-id-type () #:transparent)                 ; AssumptionId : Type 0

;; Runtime wrappers (opaque Racket values from atms.rkt)
(struct expr-atms-store (store-value) #:transparent)              ; wrapped atms
(struct expr-assumption-id-val (aid-value) #:transparent)         ; wrapped assumption-id

;; Operations
(struct expr-atms-new (network) #:transparent)                    ; PropNetwork -> ATMS
(struct expr-atms-assume (atms name datum) #:transparent)         ; ATMS -> Keyword -> A -> [ATMS * AssumptionId]
(struct expr-atms-retract (atms aid) #:transparent)               ; ATMS -> AssumptionId -> ATMS
(struct expr-atms-nogood (atms aids) #:transparent)               ; ATMS -> List AssumptionId -> ATMS
(struct expr-atms-amb (atms alternatives) #:transparent)          ; ATMS -> List A -> [ATMS * List AssumptionId]
(struct expr-atms-solve-all (atms goal) #:transparent)            ; ATMS -> CellId -> List _
(struct expr-atms-read (atms cell) #:transparent)                 ; ATMS -> CellId -> _ (type-unsafe)
(struct expr-atms-write (atms cell val support) #:transparent)    ; ATMS -> CellId -> A -> List AssumptionId -> ATMS
(struct expr-atms-consistent (atms aids) #:transparent)           ; ATMS -> List AssumptionId -> Bool
(struct expr-atms-worldview (atms aids) #:transparent)            ; ATMS -> List AssumptionId -> ATMS

;; ---- Tabling (SLG-style memoization) ----
;; Type constructor
(struct expr-table-store-type () #:transparent)                           ; TableStore
;; Runtime wrapper
(struct expr-table-store-val (store-value) #:transparent)                 ; wraps Racket table-store
;; Operations
(struct expr-table-new (network) #:transparent)                           ; PropNetwork -> TableStore
(struct expr-table-register (store name mode) #:transparent)              ; TableStore -> Keyword -> Keyword -> [TableStore * CellId]
(struct expr-table-add (store name answer) #:transparent)                 ; TableStore -> Keyword -> A -> TableStore
(struct expr-table-answers (store name) #:transparent)                    ; TableStore -> Keyword -> List _
(struct expr-table-freeze (store name) #:transparent)                     ; TableStore -> Keyword -> TableStore
(struct expr-table-complete (store name) #:transparent)                   ; TableStore -> Keyword -> Bool
(struct expr-table-run (store) #:transparent)                             ; TableStore -> TableStore
(struct expr-table-lookup (store name answer) #:transparent)              ; TableStore -> Keyword -> A -> Bool

;; ---- Opaque FFI values (IO library) ----
;; Runtime wrapper for Racket values passed through FFI without inspection.
;; Used for file ports, database connections, etc.
(struct expr-opaque (value tag) #:transparent)  ; wraps Racket value with type tag symbol

;; ---- Relational language (Phase 7) ----
;; Relational core (14)
(struct expr-defr (name schema variants) #:transparent)         ; (defr name schema [variants...])
(struct expr-defr-variant (params body) #:transparent)          ; single arity/pattern variant
(struct expr-rel (params clauses) #:transparent)                ; anonymous relation
(struct expr-clause (goals) #:transparent)                      ; single rule clause (&> ...)
(struct expr-fact-block (rows) #:transparent)                   ; ground fact block (|| ...)
(struct expr-fact-row (terms) #:transparent)                    ; single fact row
(struct expr-goal-app (name args) #:transparent)                ; relational goal application
(struct expr-logic-var (name mode) #:transparent)               ; logic variable (signature)
(struct expr-unify-goal (lhs rhs) #:transparent)                ; unification goal (= x y)
(struct expr-is-goal (var expr) #:transparent)                  ; functional eval (is x [expr])
(struct expr-not-goal (goal) #:transparent)                     ; negation-as-failure
;; Narrowing expression: [f ?x ?y] = target (functional unification)
;; func: expr — the function expression
;; args: (listof expr) — function arguments (may include expr-logic-var)
;; target: expr — the target value to unify with
;; vars: (listof symbol) — the ?-prefixed narrowing variable names
(struct expr-narrow (func args target vars) #:transparent)
(struct expr-relation-type (param-types) #:transparent)         ; type of a relation
(struct expr-schema (name fields) #:transparent)                ; named closed validated map
(struct expr-schema-type (name) #:transparent)                  ; type constructor for schema
;; Solve family (4)
(struct expr-solve (goal) #:transparent)                        ; → Seq (Map Keyword Value)
(struct expr-solve-with (solver overrides goal) #:transparent)  ; parameterized solve
(struct expr-solve-one (goal) #:transparent)                    ; → Option (Map Keyword Value)
(struct expr-goal-type () #:transparent)                        ; type of a goal (Prop)
;; Explain family (2)
(struct expr-explain (goal) #:transparent)                      ; → Seq (Answer Value)
(struct expr-explain-with (solver overrides goal) #:transparent) ; parameterized explain
;; Solver config (2)
(struct expr-solver-config (config-map) #:transparent)          ; solver configuration value
(struct expr-solver-type () #:transparent)                      ; type constructor Solver
;; Constraint forms (Phase 3c) (4)
(struct expr-all-different (var-names) #:transparent)            ; all-different constraint
(struct expr-element (index-name list-val var-name) #:transparent) ; element constraint v=xs[i]
(struct expr-cumulative (tasks capacity) #:transparent)          ; cumulative scheduling constraint
(struct expr-minimize (cost-var-name) #:transparent)             ; BB-min cost variable
;; Answer + Provenance (2)
(struct expr-answer-type (val-type) #:transparent)              ; type constructor Answer V
(struct expr-derivation-type () #:transparent)                  ; type constructor DerivationTree
;; Control (2)
(struct expr-cut () #:transparent)                              ; committed choice (once)
(struct expr-guard (condition goal) #:transparent)              ; guard evaluation

;; ========================================
;; Int (arbitrary-precision integers, backed by Racket exact integers)
;; ========================================

;; Type
(struct expr-Int () #:transparent)                             ; Int : Type 0

;; Value (val is a Racket exact integer)
(struct expr-int (val) #:transparent)                          ; int literal

;; Binary arithmetic (Int -> Int -> Int)
(struct expr-int-add (a b) #:transparent)
(struct expr-int-sub (a b) #:transparent)
(struct expr-int-mul (a b) #:transparent)
(struct expr-int-div (a b) #:transparent)                      ; truncating division
(struct expr-int-mod (a b) #:transparent)                      ; remainder

;; Unary operations (Int -> Int)
(struct expr-int-neg (a) #:transparent)
(struct expr-int-abs (a) #:transparent)

;; Comparison (Int -> Int -> Bool)
(struct expr-int-lt (a b) #:transparent)
(struct expr-int-le (a b) #:transparent)
(struct expr-int-eq (a b) #:transparent)

;; Conversion (Nat -> Int, lossless)
(struct expr-from-nat (n) #:transparent)

;; ========================================
;; Rat (exact rationals, backed by Racket exact rationals)
;; ========================================

;; Type
(struct expr-Rat () #:transparent)                             ; Rat : Type 0

;; Value (val is a Racket exact rational)
(struct expr-rat (val) #:transparent)                          ; rat literal

;; Binary arithmetic (Rat -> Rat -> Rat)
(struct expr-rat-add (a b) #:transparent)
(struct expr-rat-sub (a b) #:transparent)
(struct expr-rat-mul (a b) #:transparent)
(struct expr-rat-div (a b) #:transparent)                      ; exact division

;; Unary operations (Rat -> Rat)
(struct expr-rat-neg (a) #:transparent)
(struct expr-rat-abs (a) #:transparent)

;; Comparison (Rat -> Rat -> Bool)
(struct expr-rat-lt (a b) #:transparent)
(struct expr-rat-le (a b) #:transparent)
(struct expr-rat-eq (a b) #:transparent)

;; Conversions
(struct expr-from-int (n) #:transparent)                       ; Int -> Rat (lossless)
(struct expr-rat-numer (a) #:transparent)                      ; Rat -> Int (numerator)
(struct expr-rat-denom (a) #:transparent)                      ; Rat -> Int (denominator, always > 0)

;; ========================================
;; Generic arithmetic operators (type-polymorphic over all numeric types)
;; ========================================
;; These dispatch on argument types at reduction time.
;; Binary arithmetic: T -> T -> T (where T is any concrete numeric type)
(struct expr-generic-add (a b) #:transparent)
(struct expr-generic-sub (a b) #:transparent)
(struct expr-generic-mul (a b) #:transparent)
(struct expr-generic-div (a b) #:transparent)
;; Binary comparison: T -> T -> Bool
(struct expr-generic-lt (a b) #:transparent)
(struct expr-generic-le (a b) #:transparent)
(struct expr-generic-eq (a b) #:transparent)
;; Unary: T -> T
(struct expr-generic-negate (a) #:transparent)
(struct expr-generic-abs (a) #:transparent)
;; Generic conversion: (from-integer TargetType val) and (from-rational TargetType val)
;; target-type is a numeric type expr, arg is the value to convert
(struct expr-generic-from-int (target-type arg) #:transparent)
(struct expr-generic-from-rat (target-type arg) #:transparent)

;; ========================================
;; Foreign function binding
;; ========================================
;; name:        symbol (the Prologos binding name)
;; proc:        Racket procedure (the actual function)
;; arity:       exact non-negative integer (number of Prologos args)
;; args:        list of accumulated args (for curried partial application)
;; marshal-in:  list of (Prologos-value -> Racket-value) converters, one per arg
;; marshal-out: (Racket-value -> Prologos-value) converter for return type
(struct expr-foreign-fn (name proc arity args marshal-in marshal-out) #:transparent)

;; ========================================
;; Type hole (for untyped lambda parameters — filled during checking)
;; ========================================
(struct expr-hole () #:transparent)

;; ========================================
;; Typed hole (?? or ??name — reports expected type to stderr)
;; ========================================
;; name is #f (unnamed ??) or a symbol (named ??goal)
(struct expr-typed-hole (name) #:transparent)

;; ========================================
;; Metavariable (placeholder to be solved by unification)
;; ========================================
(struct expr-meta (id) #:transparent)    ; id is a gensym symbol

;; ========================================
;; Reduce (ML-style pattern matching — desugared in type checker)
;; ========================================
;; expr-reduce-arm: ctor-name (symbol), binding-count (int), body (core expr)
(struct expr-reduce-arm (ctor-name binding-count body) #:transparent)

;; expr-reduce: scrutinee (core expr), arms (list of expr-reduce-arm),
;;   structural? (boolean) — #t for true structural PM, #f for Church fold semantics
(struct expr-reduce (scrutinee arms structural?) #:transparent)

;; ========================================
;; Union types: A | B
;; ========================================
;; Represents the union of two types. Components are normalized:
;;   - Flattened: (A | B) | C ≡ A | (B | C) (right-associated)
;;   - Idempotent: A | A ≡ A
;;   - Commutative: A | B ≡ B | A (for unification, sorted by canonical order)
(struct expr-union (left right) #:transparent)

;; ========================================
;; Unapplied type constructor (HKT support)
;; ========================================
;; Represents a type constructor as a first-class entity, e.g., PVec as kind Type -> Type.
;; Created by normalize-for-resolution during trait resolution; not user-facing syntax.
;; name : symbol — e.g., 'PVec, 'Map, 'Set, 'List, 'LSeq
(struct expr-tycon (name) #:transparent)

;; Kind table: maps type constructor names to their arity (number of type arguments).
;; Used for normalization and kind inference.
(define builtin-tycon-arity
  (hasheq 'PVec 1    ;; PVec : Type -> Type
          'Set  1    ;; Set  : Type -> Type
          'Map  2    ;; Map  : Type -> Type -> Type
          'List 1    ;; List : Type -> Type (user-defined but known)
          'LSeq 1    ;; LSeq : Type -> Type
          'Vec  2    ;; Vec  : Type -> Nat -> Type
          'TVec 1    ;; TVec : Type -> Type
          'TMap 2    ;; TMap : Type -> Type -> Type
          'TSet 1))  ;; TSet : Type -> Type

;; Dynamic extension for trait-generated type constructors.
;; Populated by process-trait in macros.rkt when traits are declared.
(define current-tycon-arity-extension (make-parameter (hasheq)))

;; Unified kind lookup: checks built-in table first, then dynamic extensions.
(define (tycon-arity name)
  (or (hash-ref builtin-tycon-arity name #f)
      (hash-ref (current-tycon-arity-extension) name #f)))


;; ========================================
;; Panic (runtime abort, inhabits any type)
;; ========================================
(struct expr-panic (msg) #:transparent)                      ; (panic msg) — msg : String

;; ========================================
;; Error marker (for failed inference)
;; ========================================
(struct expr-error () #:transparent)

;; ========================================
;; Expr predicate
;; ========================================
(define (expr? x)
  (or (expr-bvar? x) (expr-fvar? x)
      (expr-zero? x) (expr-suc? x) (expr-nat-val? x)
      (expr-lam? x) (expr-app? x)
      (expr-pair? x) (expr-fst? x) (expr-snd? x)
      (expr-refl? x) (expr-ann? x)
      (expr-natrec? x) (expr-J? x)
      (expr-Type? x) (expr-Nat? x)
      (expr-Bool? x) (expr-true? x) (expr-false? x) (expr-boolrec? x)
      (expr-Unit? x) (expr-unit? x)
      (expr-Nil? x) (expr-nil? x) (expr-nil-check? x)
      (expr-Pi? x) (expr-Sigma? x) (expr-Eq? x)
      (expr-Vec? x) (expr-vnil? x) (expr-vcons? x)
      (expr-Fin? x) (expr-fzero? x) (expr-fsuc? x)
      (expr-vhead? x) (expr-vtail? x) (expr-vindex? x)
      (expr-Posit8? x) (expr-posit8? x)
      (expr-p8-add? x) (expr-p8-sub? x) (expr-p8-mul? x) (expr-p8-div? x)
      (expr-p8-neg? x) (expr-p8-abs? x) (expr-p8-sqrt? x)
      (expr-p8-lt? x) (expr-p8-le? x) (expr-p8-eq? x)
      (expr-p8-from-nat? x) (expr-p8-to-rat? x) (expr-p8-from-rat? x) (expr-p8-from-int? x) (expr-p8-if-nar? x)
      (expr-Posit16? x) (expr-posit16? x)
      (expr-p16-add? x) (expr-p16-sub? x) (expr-p16-mul? x) (expr-p16-div? x)
      (expr-p16-neg? x) (expr-p16-abs? x) (expr-p16-sqrt? x)
      (expr-p16-lt? x) (expr-p16-le? x) (expr-p16-eq? x)
      (expr-p16-from-nat? x) (expr-p16-to-rat? x) (expr-p16-from-rat? x) (expr-p16-from-int? x) (expr-p16-if-nar? x)
      (expr-Posit32? x) (expr-posit32? x)
      (expr-p32-add? x) (expr-p32-sub? x) (expr-p32-mul? x) (expr-p32-div? x)
      (expr-p32-neg? x) (expr-p32-abs? x) (expr-p32-sqrt? x)
      (expr-p32-lt? x) (expr-p32-le? x) (expr-p32-eq? x)
      (expr-p32-from-nat? x) (expr-p32-to-rat? x) (expr-p32-from-rat? x) (expr-p32-from-int? x) (expr-p32-if-nar? x)
      (expr-Posit64? x) (expr-posit64? x)
      (expr-p64-add? x) (expr-p64-sub? x) (expr-p64-mul? x) (expr-p64-div? x)
      (expr-p64-neg? x) (expr-p64-abs? x) (expr-p64-sqrt? x)
      (expr-p64-lt? x) (expr-p64-le? x) (expr-p64-eq? x)
      (expr-p64-from-nat? x) (expr-p64-to-rat? x) (expr-p64-from-rat? x) (expr-p64-from-int? x) (expr-p64-if-nar? x)
      (expr-Int? x) (expr-int? x)
      (expr-int-add? x) (expr-int-sub? x) (expr-int-mul? x)
      (expr-int-div? x) (expr-int-mod? x)
      (expr-int-neg? x) (expr-int-abs? x)
      (expr-int-lt? x) (expr-int-le? x) (expr-int-eq? x)
      (expr-from-nat? x)
      (expr-Rat? x) (expr-rat? x)
      (expr-rat-add? x) (expr-rat-sub? x) (expr-rat-mul? x) (expr-rat-div? x)
      (expr-rat-neg? x) (expr-rat-abs? x)
      (expr-rat-lt? x) (expr-rat-le? x) (expr-rat-eq? x)
      (expr-from-int? x) (expr-rat-numer? x) (expr-rat-denom? x)
      (expr-generic-add? x) (expr-generic-sub? x) (expr-generic-mul? x) (expr-generic-div? x)
      (expr-generic-lt? x) (expr-generic-le? x) (expr-generic-eq? x)
      (expr-generic-negate? x) (expr-generic-abs? x)
      (expr-generic-from-int? x) (expr-generic-from-rat? x)
      (expr-Symbol? x) (expr-symbol? x)
      (expr-Keyword? x) (expr-keyword? x)
      (expr-Char? x) (expr-char? x)
      (expr-String? x) (expr-string? x)
      (expr-Map? x) (expr-champ? x) (expr-map-empty? x)
      (expr-map-assoc? x) (expr-map-get? x) (expr-nil-safe-get? x) (expr-map-dissoc? x)
      (expr-map-size? x) (expr-map-has-key? x)
      (expr-map-keys? x) (expr-map-vals? x)
      (expr-Set? x) (expr-hset? x) (expr-set-empty? x)
      (expr-set-insert? x) (expr-set-member? x) (expr-set-delete? x)
      (expr-set-size? x) (expr-set-union? x)
      (expr-set-intersect? x) (expr-set-diff? x)
      (expr-set-to-list? x)
      (expr-PVec? x) (expr-rrb? x) (expr-pvec-empty? x)
      (expr-pvec-push? x) (expr-pvec-nth? x) (expr-pvec-update? x)
      (expr-pvec-length? x) (expr-pvec-pop? x)
      (expr-pvec-concat? x) (expr-pvec-slice? x)
      (expr-pvec-to-list? x) (expr-pvec-from-list? x)
      (expr-pvec-fold? x) (expr-pvec-map? x) (expr-pvec-filter? x)
      (expr-set-fold? x) (expr-set-filter? x)
      (expr-map-fold-entries? x) (expr-map-filter-entries? x) (expr-map-map-vals? x)
      (expr-transient? x) (expr-persist? x)
      (expr-TVec? x) (expr-TMap? x) (expr-TSet? x)
      (expr-trrb? x) (expr-tchamp? x) (expr-thset? x)
      (expr-transient-vec? x) (expr-persist-vec? x)
      (expr-transient-map? x) (expr-persist-map? x)
      (expr-transient-set? x) (expr-persist-set? x)
      (expr-tvec-push!? x) (expr-tvec-update!? x)
      (expr-tmap-assoc!? x) (expr-tmap-dissoc!? x)
      (expr-tset-insert!? x) (expr-tset-delete!? x)
      (expr-net-type? x) (expr-cell-id-type? x) (expr-prop-id-type? x)
      (expr-prop-network? x) (expr-cell-id? x) (expr-prop-id? x)
      (expr-net-new? x) (expr-net-new-cell? x) (expr-net-new-cell-widen? x)
      (expr-net-cell-read? x) (expr-net-cell-write? x)
      (expr-net-add-prop? x) (expr-net-run? x)
      (expr-net-snapshot? x) (expr-net-contradiction? x)
      (expr-uf-type? x) (expr-uf-store? x)
      (expr-atms-type? x) (expr-assumption-id-type? x)
      (expr-atms-store? x) (expr-assumption-id-val? x)
      (expr-table-store-type? x) (expr-table-store-val? x)
      (expr-solver-type? x) (expr-goal-type? x) (expr-derivation-type? x)
      (expr-schema-type? x) (expr-answer-type? x) (expr-relation-type? x)
      (expr-solver-config? x) (expr-cut? x)
      (expr-opaque? x)
      (expr-panic? x)
      (expr-hole? x) (expr-typed-hole? x) (expr-meta? x) (expr-reduce? x)
      (expr-union? x) (expr-tycon? x) (expr-error? x)))

;; ========================================
;; Convenience: convert Racket natural to Prologos numerals
;; ========================================
;; nat(n) = native Nat value (Idris 2 model: Peano surface, native runtime)
(define (nat->expr n)
  (expr-nat-val n))

;; Non-dependent function type sugar: A --> B = Pi(mw, A, B)
(define (arrow a b)
  (expr-Pi mw a b))

;; Non-dependent pair type sugar: A ** B = Sigma(A, B)
(define (sigma-pair a b)
  (expr-Sigma a b))

;; ========================================
;; Contexts
;; ========================================
;; A context is a list of (cons type mult) bindings.
;; Binding at position 0 is the most recently added (head of list).
;; bvar(k) refers to the binding at position k.

(define ctx-empty '())

;; extend(ctx, type, mult) — add a binding to the front
(define (ctx-extend ctx type mult)
  (cons (cons type mult) ctx))

;; lookup-type: retrieve the type at position k
(define (lookup-type k ctx)
  (if (< k (length ctx))
      (car (list-ref ctx k))
      (expr-error)))

;; lookup-mult: retrieve the multiplicity at position k
(define (lookup-mult k ctx)
  (if (< k (length ctx))
      (cdr (list-ref ctx k))
      (error 'lookup-mult "index ~a out of bounds for context of length ~a" k (length ctx))))

;; ctx-len: number of bindings in context
(define (ctx-len ctx)
  (length ctx))

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

(require "prelude.rkt"
         racket/generic   ;; PM 8F Phase 1: gen:equal+hash for expr-meta
         (only-in racket/string string-join)   ;; D4.P3b select-synth-name
         (only-in racket/list append-map))     ;; D4.P3b select-branch-top-keys

;; ========================================
;; SRE Track 2 Phase 0: O(1) Constructor Tag Dispatch
;; ========================================
;;
;; Struct-type property for O(1) lookup of constructor tags.
;; Property value is (cons domain-symbol tag-symbol), e.g., '(type . Pi).
;; Used by ctor-tag-for-value to bypass linear recognizer scan.
;; See: docs/tracking/2026-03-23_SRE_TRACK2_ELABORATOR_ON_SRE_DESIGN.md §1b.2
(define-values (prop:ctor-desc-tag ctor-desc-tag? ctor-desc-tag-ref)
  (make-struct-type-property 'ctor-desc-tag))

(provide
 ;; SRE Track 2: O(1) dispatch property
 prop:ctor-desc-tag
 ctor-desc-tag?
 ctor-desc-tag-ref
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
 ;; Float (IEEE-754 binary floats — Numerics N3)
 (struct-out expr-Float32) (struct-out expr-float32)
 (struct-out expr-Float64) (struct-out expr-float64)
 ;; Float arithmetic + comparison ops (Numerics N3b)
 (struct-out expr-f32-add) (struct-out expr-f32-sub) (struct-out expr-f32-mul) (struct-out expr-f32-div)
 (struct-out expr-f32-neg) (struct-out expr-f32-abs) (struct-out expr-f32-sqrt)
 (struct-out expr-f32-lt) (struct-out expr-f32-le) (struct-out expr-f32-eq)
 (struct-out expr-f64-add) (struct-out expr-f64-sub) (struct-out expr-f64-mul) (struct-out expr-f64-div)
 (struct-out expr-f64-neg) (struct-out expr-f64-abs) (struct-out expr-f64-sqrt)
 (struct-out expr-f64-lt) (struct-out expr-f64-le) (struct-out expr-f64-eq)
 ;; Cross-width Float conversions (Numerics N3e-rest)
 (struct-out expr-float-finite) (struct-out expr-float-to-rat)
 (struct-out expr-float-to-int) (struct-out expr-float-to-float32)
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
 ;; Anonymous structural record / tuple type (CIU T6 F1; internal-only — inferred, not parsed)
 (struct-out expr-Record) (struct-out record-field)
 (struct-out expr-validate) validate-map-exprs
 ;; Path Selection block node (CIU T6 D4.P3a; step vocabulary D4.P3b)
 (struct-out expr-select) select-map-exprs
 select-key-step? select-sub-step? select-ord-step? select-step-name
 select-sorts select-sort? select-sort-unhandled
 ;; D4.P4a: the step-kind totality dispatcher + the consumer-side else
 select-step-kind select-step-kind-unhandled select-step-kind/display
 select-bcast-step? select-bcast-inner make-select-bcast
 ;; D4.P4e-1b (Q_U40): the flatten step. `select-star-cont` is the ONLY reader of
 ;; its continuation — `select-step-cont` deliberately answers #f (see its note).
 select-star-step? select-star-cont make-select-star
 select-branch-deep-star? select-steps-star-tail?
 select-step-makes-no-layer? select-branch-has-star?/deep
 select-steps-yield-bare-join?
 ;; [Q_U44] canonical key order — ONE definition, shared by both twins.
 canonical-keyword-key? canonical-keyword-key<?
 select-step-cont select-cont-collapse? select-cont-rename
 select-branch-collapse select-branch-keyless?
 select-step-output-name select-synth-name select-branch-top-keys
 select-synth-separator select-synth-prefixed-key
 record-map-field-types record-map-field-types/labeled make-record record-extend record-lookup-field record-remove
 closed-nat-row? closed-keyword-row? record-mark-all-unknown
 ;; Map (persistent hash map)
 (struct-out expr-Map) (struct-out expr-champ)
 (struct-out expr-map-empty) (struct-out expr-map-assoc)
 (struct-out expr-map-get) (struct-out expr-nil-safe-get) (struct-out expr-map-dissoc)
 (struct-out expr-map-size) (struct-out expr-map-has-key)
 (struct-out expr-map-keys) (struct-out expr-map-vals)
 (struct-out expr-get) (struct-out expr-get-in) (struct-out expr-update-in)
 ;; Path (first-class path values)
 (struct-out expr-path) (struct-out expr-Path)
 ;; Set (persistent hash set)
 (struct-out expr-Set) (struct-out expr-hset)
 (struct-out expr-set-empty) (struct-out expr-set-insert)
 (struct-out expr-set-member) (struct-out expr-set-delete)
 (struct-out expr-set-size) (struct-out expr-set-union)
 (struct-out expr-set-intersect) (struct-out expr-set-diff)
 (struct-out expr-set-to-list)
 ;; Persistent Vector (PVec)
 (struct-out expr-PVec) (struct-out expr-rrb) (struct-out expr-pvec-empty)
 (struct-out expr-pvec-push) (struct-out expr-pvec-literal) (struct-out expr-list-literal) (struct-out expr-map-literal) (struct-out expr-pvec-nth) (struct-out expr-pvec-update)
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
 (struct-out expr-relation-type)
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
 (struct-out expr-generic-gt)
 (struct-out expr-generic-ge)
 (struct-out expr-generic-eq)
 (struct-out expr-generic-mod)
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
 ;; Open type — universal type for "Open by Design" Maps (PPN 4C T-2, 2026-04-23).
 ;; Used as Map value type for unannotated heterogeneous literals. No user-writable
 ;; syntax — only arises from inference. α-semantic: compatible with any type in
 ;; both directions (bidirectional trust). Narrowing at use site is per-reference,
 ;; never globally pinned. Contrast with expr-hole (inference hole; gets solved)
 ;; and type-top (lattice contradiction sentinel). Display: "Open".
 ;; Panic (runtime abort — inhabits any type)
 (struct-out expr-panic)
 ;; Metavariable (to be solved during elaboration/unification)
 (struct-out expr-meta)
 ;; N4: context-typed polymorphic numeric literal (transient)
 (struct-out expr-num-lit)
 num-lit-default-type  ;; N6b: the origin-keyed unconstrained-default rule

 ;; Reduce (ML-style pattern matching — desugared in type checker)
 (struct-out expr-reduce)
 (struct-out expr-reduce-arm)
 ;; Union types
 (struct-out expr-union)
 expr-substructs-all?   ;; CIU T6 P2.a: generic containment-descent helper (pipeline.md § Exhaustive Walkers)
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
(struct expr-suc (pred) #:transparent #:property prop:ctor-desc-tag '(type . suc))
(struct expr-nat-val (n) #:transparent)   ; O(1) native natural number (Idris 2 model)

;; Lambda and application
(struct expr-lam (mult type body) #:transparent #:property prop:ctor-desc-tag '(type . lam))
(struct expr-app (func arg) #:transparent #:property prop:ctor-desc-tag '(type . app))

;; Pairs (Sigma intro/elim)
(struct expr-pair (fst snd) #:transparent #:property prop:ctor-desc-tag '(type . pair))
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
(struct expr-Pi (mult domain codomain) #:transparent #:property prop:ctor-desc-tag '(type . Pi))

;; Dependent pair type
(struct expr-Sigma (fst-type snd-type) #:transparent #:property prop:ctor-desc-tag '(type . Sigma))

;; Identity/Equality type
(struct expr-Eq (type lhs rhs) #:transparent #:property prop:ctor-desc-tag '(type . Eq))

;; ========================================
;; Vec and Fin (from prologos-inductive.maude)
;; Defined upfront since the full set of constructors is known.
;; ========================================

;; Vec type: Vec(A, n) where A : Type and n : Nat
(struct expr-Vec (elem-type length) #:transparent #:property prop:ctor-desc-tag '(type . Vec))

;; Vec constructors
(struct expr-vnil (type) #:transparent)            ; vnil(A) : Vec(A, zero)
(struct expr-vcons (type len head tail) #:transparent) ; vcons(A, n, head, tail) : Vec(A, suc(n))

;; Fin type: Fin(n) where n : Nat
(struct expr-Fin (bound) #:transparent #:property prop:ctor-desc-tag '(type . Fin))

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
;; Float (IEEE-754 binary floats — interop numeric, Numerics N3)
;; Float32 = single precision, Float64 = double precision. Value `val` is a
;; Racket flonum (f64 = double; f32 = single-flonum). +nan.0/+inf.0/-inf.0 are
;; native flonum values. Ops + `f` literals are added in later N3 sub-phases.
;; ========================================

(struct expr-Float32 () #:transparent)
(struct expr-float32 (val) #:transparent)
(struct expr-Float64 () #:transparent)
(struct expr-float64 (val) #:transparent)
;; Float arithmetic + comparison ops (Numerics N3b) — mirror the Posit op shape.
;; Binary ops carry (a b); unary ops carry (a). lt/le/eq are typed to Bool.
(struct expr-f32-add (a b) #:transparent)
(struct expr-f32-sub (a b) #:transparent)
(struct expr-f32-mul (a b) #:transparent)
(struct expr-f32-div (a b) #:transparent)
(struct expr-f32-neg (a) #:transparent)
(struct expr-f32-abs (a) #:transparent)
(struct expr-f32-sqrt (a) #:transparent)
(struct expr-f32-lt (a b) #:transparent)
(struct expr-f32-le (a b) #:transparent)
(struct expr-f32-eq (a b) #:transparent)
(struct expr-f64-add (a b) #:transparent)
(struct expr-f64-sub (a b) #:transparent)
(struct expr-f64-mul (a b) #:transparent)
(struct expr-f64-div (a b) #:transparent)
(struct expr-f64-neg (a) #:transparent)
(struct expr-f64-abs (a) #:transparent)
(struct expr-f64-sqrt (a) #:transparent)
(struct expr-f64-lt (a b) #:transparent)
(struct expr-f64-le (a b) #:transparent)
(struct expr-f64-eq (a b) #:transparent)
;; Cross-width Float conversions (Numerics N3e-rest) — accept Float32 OR Float64.
;; `float-finite?` : Float -> Bool ; float-to-rat : Float -> Rat (NaN/±Inf stuck);
;; float-to-int : Float -> Int (truncate) ; float-to-float32 : Float -> Float32.
(struct expr-float-finite (a) #:transparent)      ; Float -> Bool  (keyword: float-finite?)
(struct expr-float-to-rat (a) #:transparent)      ; Float -> Rat
(struct expr-float-to-int (a) #:transparent)      ; Float -> Int
(struct expr-float-to-float32 (a) #:transparent)  ; Float -> Float32

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

;; Anonymous structural-row TYPE node (CIU T6 F1 — internal-only: inferred + displayed, NOT parsed).
;; ONE carrier, TWO surface presentations keyed by key-domain (D13/Q_A): a record ('keyword) or a
;; tuple ('nat). Deliberately carries NO prop:ctor-desc-tag — a keyed/variable-width row cannot register
;; in the fixed-arity positional ctor-desc registry; width subsumption is F1b (erasure-mode), not the walk.
;;   ✏ F1b.3 (D21, 2026-07-17): CONFIRMED under its strict reading — width landed as the
;;   erasure-mode discharge in check's conversion fallback (record-width-* below), NOT the walk
;;   and NOT unify/classify (a width rule in unify would CORRUPT the D15 literal-homogeneity
;;   probes, which rely on closed row-vs-row unify failing — PROBES P8).
;;   key-domain : 'keyword | 'nat   (F1a-core mints 'keyword only; 'nat = tuples, F1a-col.
;;                                   Q_B: homogeneous-key-domain — a row is ALL-keyword or ALL-nat.)
;;   fields     : canonical assoc ((label . record-field) ...); label = keyword-symbol | Nat,
;;                sorted by symbol<? / < per domain (smart-constructor-enforced).
;;   tail       : 'closed | 'dyn    (F1a mints 'closed; 'dyn = F1a.2; ρ row-meta = F-row.)
(struct expr-Record (key-domain fields tail) #:transparent)
;; A single field/slot: its type + presence mark.
;;
;; PRESENCE LATTICE (D24, F1b.3 — the points-map + joins, declared here per the S-lens
;; obligation). A mark denotes a subset of {P(resent), A(bsent)} — what is known about the
;; field's runtime membership; the TYPE is the field's type-if-present (a fact regardless):
;;   'present  = {P}      (positive evidence: literal mint, assoc — record-extend's
;;                         overwrite-to-'present on assoc IS the evidence-narrowing join)
;;   'absent   = {A}      (reserved: negative evidence / Lacks facts — F-carrier-era)
;;   'unknown  = {P,A}    (no evidence either way: the dissoc-dynamic writer, F1b.3)
;;   'optional = {P,A}    (reserved: same POINT as 'unknown, distinguished by PROVENANCE —
;;                         schema-declared optionality, schema-optional-keys era)
;;   (contradiction = {} has no mark: presence conflicts surface as type-level conflicts)
;; Evidence-narrowing = set intersection (future has-key? narrowing: 'unknown ∩ {P} → 'present);
;; row-merge join = set union. Marks propagate through type rewrites unchanged (presence is
;; orthogonal to the type dimension — e.g. map-vals rebuilds keep marks with types := W).
;; Comparison semantics: marks NEVER become unification goals (the unify B3 pin); they are
;; consulted ONLY by arm-level GUARDS (C_Cons containment treats 'unknown labels as
;; non-required) and by the gated-identically projection reads (an 'unknown hit mints a fresh
;; meta exactly like a tail miss — D24/Q7, courtesy-upgrade rejected).
;; Display: 'unknown fields render with a `?` label suffix ({:a? Int | _}). NOTE the edge:
;; a 'present field whose LABEL itself ends in `?` (predicate-named keys) is visually
;; indistinguishable — accepted display-only ambiguity, revisit if it bites.
(struct record-field (type presence) #:transparent)

;; Map a procedure over every field TYPE of a record, preserving labels/presence/tail/key-domain.
;; The single reconstruction point used by all the pipeline recursions (shift/subst/zonk/nf/…), so the
;; `fields` list-spine walk lives in ONE place (labels + presence are not exprs — only types recurse).
(define (record-map-field-types proc rec)
  (expr-Record (expr-Record-key-domain rec)
               (for/list ([fld (in-list (expr-Record-fields rec))])
                 (cons (car fld)
                       (record-field (proc (record-field-type (cdr fld)))
                                     (record-field-presence (cdr fld)))))
               (expr-Record-tail rec)))

;; D4.P4d slice 2 — the LABEL-AWARE sibling of the walker above (kept adjacent
;; so the reconstruction cannot drift): identical preservation contract
;; (key-domain / labels / presence / tail / order), but the proc receives the
;; LABEL too — the broadcast per-field walk needs it to NAME a failing
;; field/position in its diagnostic (the label-blind walk structurally lost
;; the position; slice-2 audit).
(define (record-map-field-types/labeled proc rec)
  (expr-Record (expr-Record-key-domain rec)
               (for/list ([fld (in-list (expr-Record-fields rec))])
                 (cons (car fld)
                       (record-field (proc (car fld) (record-field-type (cdr fld)))
                                     (record-field-presence (cdr fld)))))
               (expr-Record-tail rec)))

;; ============================================================
;; expr-validate — the runtime schema-tabulation node (CIU T6 F1b.5-s2, D27)
;; ============================================================
;; Minted at ELABORATION from `[validate SchemaName e]` with the per-field
;; plan fully BAKED (the schema registry is preparse/elaboration-time state;
;; the whnf memo cache forbids registry reads at reduce time, and lazy baking
;; is structurally impossible — typing can't rewrite immutable exprs and
;; reduction can't reach typing-core). Reduces (ONE arm) to
;; `ok filled-champ` / `err reason-champ` — payload-only ctor apps per the
;; documented dual-arity runtime contract (foreign.rkt marshal-out precedent).
;;
;;   schema-name : symbol           (as resolved at bake — display + errors)
;;   closed?     : boolean          (:closed schema → unexpected-field scan)
;;   plan        : (listof (list kw tag default-expr pred-expr type-str pred-str))
;;                 kw = stripped field-name symbol; tag = the s1 witness tag
;;                 (plain sexp — field-witness.rkt grammar); default-expr /
;;                 pred-expr = elaborated exprs or #f (pred = an expr-lam,
;;                 NEVER a Racket closure — pnet serializes procedures to
;;                 error stubs); type-str / pred-str = display strings baked
;;                 for Reason payloads
;;   subject     : expr
;;   names       : (list Result-type Reason-type ok err missing-required
;;                       check-failed type-mismatch unexpected-field)
;;                 — eight FQN symbols resolved at bake (types first: the
;;                 typing rule builds Result S (Map Keyword Reason) from them;
;;                 the rest are the arm's runtime ctor heads)
(struct expr-validate (schema-name closed? plan subject names) #:transparent)

;; Map proc over every EXPR slot of a validate node (subject + per-field
;; default/pred), preserving all atoms — the record-map-field-types pattern:
;; the plan-spine walk lives in ONE place for shift/subst/zonk/nf/pp.
(define (validate-map-exprs proc v)
  (expr-validate (expr-validate-schema-name v)
                 (expr-validate-closed? v)
                 (for/list ([entry (in-list (expr-validate-plan v))])
                   (list (car entry)
                         (cadr entry)
                         (let ([d (caddr entry)]) (and d (proc d)))
                         (let ([p (cadddr entry)]) (and p (proc p)))
                         (list-ref entry 4)
                         (list-ref entry 5)
                         (list-ref entry 6)))  ; F1b.5-s4: required-on-miss? (atom)
                 (proc (expr-validate-subject v))
                 (expr-validate-names v)))

;; ============================================================
;; expr-select — the Path Selection block node (CIU T6 D4.P3a, Q_T1 Route A)
;; ============================================================
;; `x{…}` — a keyed select block over a keyword-row subject. Grades-1-scoped
;; at P3a (no `^`, no broadcast); P3b extends the step vocabulary with `^`
;; continuations, P3c adds the keyless sort, P4 broadcast steps.
;;
;;   subject  : expr
;;   branches : (listof branch)              STATIC data — no exprs inside
;;   branch  ::= (listof step), non-empty
;;   step    ::= symbol                       nominal descent key (colon-less)
;;             | (cons '@sub (listof branch)) terminal sub-block  `.{…}`
;;
;; The branches are segmented + malformed-checked + duplicate-checked at the
;; PARSER ($select head arm) — by construction an expr-select carries only
;; well-formed, duplicate-free plain-key branches at this slice. Typing =
;; per-branch copattern demand under Q_T2 Horn-D LENIENT presence
;; (typing-core `select-project`); reduction evaluates the subject ONCE
;; (reduction.rkt). Walkers: subject is the only expr slot — branches pass
;; through untouched (P1b/P2 walker discipline; no binder ⇒ no depth routing).
;; D4.P4b-ii-2a — `tier` is the TWO-TIER MISS DECISION, materialized from
;; typing into reduction. It is the carrier's analogue of `expr-map-get`'s
;; third field (P2.b slice 4): a fresh strictness meta that typing solves to
;; `(expr-true)` when it PROVED an assertive subject, and which reduction
;; reads to choose between a LOUD panic naming the key and the PERMISSIVE
;; `(expr-error)` degradation. `#f` = no claim (the block sort, and every
;; internal reconstruction).
;;
;; WHY IT IS ON `expr-select` AND NOT ON THE SELECTOR: the tier is a property
;; of the APPLICATION (subject × selector), not of the selector — a bare
;; `#p(…)` has no subject and so has no tier. It also keeps the selector's
;; declared "STATIC data — no exprs inside" invariant intact, and rides
;; `select-map-exprs`, the ONE reconstruction point for six walkers, instead
;; of six independent identity arms that would never zonk a meta.
;;
;; WHY A SCALAR SUFFICES [Q_U13, owner]: the tier is decided PER DESCENT
;; LEVEL, and under the NEST encoding each level is its own `expr-select`
;; node — exactly as each `.field` is its own `expr-map-get` today. Under the
;; rejected GATHER encoding one node would span a whole chain and this would
;; have to be a list parallel to the steps.
;;
;; INERT AT 2a: every construction passes `#f` and nothing reads it. b-ii-2b
;; mints the meta at the fold and teaches `select-reduce` to read it. The
;; field lands in its own slice deliberately — an arity change on a shipped
;; struct is the §8 R6 hazard, and it is cheaper when it does not share a diff
;; with a behavioural flip.
(struct expr-select (subject branches tier) #:transparent)

;; Map proc over the single EXPR slot (the record-map-field-types pattern:
;; ONE reconstruction point for shift/subst/zonk/nf).
;; D4.P4b-i slice 3: the `branches` slot holds the SELECTOR CARRIER (an
;; `expr-path`), not a raw list — Q_U5's "one representation". So the mapper
;; maps into BOTH slots. The selector's own walker arms are all
;; `[(expr-path _) e]` (identity), so this is a no-op at P4 by the monomorphic
;; ruling — a selector holds bare symbols, never exprs. It stops being a no-op
;; when BOUND selectors land (F-row), and mapping it now is what makes that
;; landing safe rather than a silent under-walk.
(define (select-map-exprs proc v)
  ;; D4.P4b-ii-2a: the tier is MAPPED, not merely preserved. It becomes a
  ;; strictness META at b-ii-2b, and this is the ONE reconstruction point for
  ;; all six walkers (shift, subst, zonk ×3, nf) — so a tier that is carried
  ;; but not mapped would never ZONK, `expr-true?` would never hold, and every
  ;; Map miss would silently go PERMISSIVE. That is a reverse regression with
  ;; no signal, and it is exactly the hidden cost the b-ii-2 mini-audit
  ;; identified in the rejected put-it-on-the-selector option, whose six
  ;; identity arms had the same defect.
  ;; `#f` (no claim) is not an expr, so it passes through untouched.
  (let ([tier (expr-select-tier v)])
    (expr-select (proc (expr-select-subject v))
                 (proc (expr-select-branches v))
                 (if (expr? tier) (proc tier) tier))))

;; ============================================================
;; D4.P3b — the `^` step vocabulary + the ONE shared branch walk
;; ============================================================
;; A step is now:
;;   symbol                          plain kept descent (key preserved)
;;   (list '@key name cont)          `^`-bearing segment
;;   (cons '@sub (listof branch))    terminal sub-block  `.{…}`
;; cont ::= 'dissolve                        k^   mid-path: splice a level up
;;        | (cons 'rename k')                k^k' rename IN PLACE (Q_T4b)
;;        | 'synth                           k^_  Reading N (Q_T4b′) — leaf
;;        | 'collapse                        k^-  flatten branch, keep leaf key
;;        | (cons 'collapse-rename k')       k^-k'                     (Q_T7)
;;        | 'collapse-synth                  k^-_  flat provenance      (Q_T7)
;; `^..` (Q_T8) never reaches the node — the parser desugars it at
;; segmentation to the owner-ruled equivalence [P^ . L^P].
;;
;; These helpers are the ONE walk over the vocabulary: the parser's Q_T3
;; OUTPUT-level duplicate check, typing-core's select-project and
;; reduction's select-reduce all consume them, so output-key computation
;; cannot drift between the check and the semantics (the infer/inferQ-twin
;; lesson applied to check+meaning).

(define (select-key-step? s) (and (pair? s) (eq? (car s) '@key)))
(define (select-sub-step? s) (and (pair? s) (eq? (car s) '@sub)))
;; D4.P3c: `(@ord N)` = an ordinal BRANCH head (written `{N …}` — re-derives,
;; keyless sort). A bare number N in the steps is an ordinal STEP (`.N` —
;; Q_U2 Reading A: descends, contributes NO output level, transparent to
;; keys and synth names). The two are distinct on purpose: after a dissolve
;; splice, `a^.0.name`'s continuation [0 name] must stay a STEP chain
;; (output key :name), while `{0.name}` is a keyless component.
(define (select-ord-step? s) (and (pair? s) (eq? (car s) '@ord)))

;; D4.P4c-3 (Q_U7): `(@bcast step)` — THE ω/BROADCAST STEP, a ONE-STEP WRAPPER.
;;   users:name    → [(@bcast name)]
;;   users:{a b}   → [(@bcast (@sub …))]
;;   x:s:t         → [(@bcast s) (@bcast t)]
;;
;; ⚠ EXTENT IS STRUCTURAL, not a count. The wrapper holds exactly ONE step, so
;; "broadcasts the next step" IS the representation 1:1 and a broadcast-of-
;; nothing is UNCONSTRUCTIBLE. L1 fusion (`users:0:userName` → ONE layer) is a
;; THEOREM the battery pins, not a property this representation maintains —
;; each ω step consumes one container layer and re-wraps one, so fmap∘fmap =
;; fmap arithmetically and nothing here computes a layer count. The rejected
;; alternatives are recorded in D4 §3 Q_U7: the flat nullary marker (extent by
;; ADJACENCY ⇒ representable malformed states + a backward scan), the
;; run-carrying wrapper (the surface never writes runs, so the parser would have
;; to MERGE adjacent wrappers — the normalization pass 4b exists to forbid), and
;; the per-step grade field (taxes the whole landed vocabulary for one grade).
;;
;; ⚠ CORRECTED AT D4.P4c-4b — "A WRAPPER NEVER HEADS A BRANCH" IS FALSE, and it
;; was asserted at FOUR sites, three of which justified an arm by it.
;; The claim conflated two different things. W2 / spec §7.3 refuses branch-initial
;; `:` in a BLOCK (`x{:name}`) — a SURFACE rule. It says nothing about a one-step
;; `'path` branch, and Q_U7's own `users:name → [(@bcast name)]` makes the wrapper
;; the branch HEAD for the headline spelling: `$select-path` consumes the SUBJECT
;; itself and hands `segment-select-items` only the steps, so the ω step arrives
;; first with no preceding step. Measured — the first cut of the parser arm
;; refused exactly that and reported "needs a preceding subject" for `users:name`.
;; So `'bcast` IS reachable at head, the arms that were "written rather than
;; omitted" are live, and the reasoning that wrote them (a surface rule is not a
;; representation invariant) was right for a reason its own premise got wrong.
(define (select-bcast-step? s) (and (pair? s) (eq? (car s) '@bcast)))

;; The ω step's VALUE-level semantics (map the wrapped step over the container)
;; land at P4c-4 together with the PVec dispatcher and the L1/extent law pins.
;; P4c-3 lands the KIND and its arms; the value walks therefore carry a guided
;; not-yet rather than a wrong answer.
;;
;; ⚠ WHY NOT DELEGATE TO THE INNER STEP HERE. Delegation is exactly right for
;; the NAME/KEY walks — ω changes container arity, not key behaviour — but at
;; the value level it would project the field off the CONTAINER instead of
;; broadcasting over it: a silent wrong answer, which is the one outcome this
;; track's totality dispatcher exists to prevent. Loud beats plausible.
;; ⚠ RETIRED AT D4.P4c-4c — the ω value semantics LANDED, so this helper
;; named its own discharge point and then reached ZERO callers. It raised a raw
;; `error`, which `process-command/solve-guard` does not catch, so leaving it in
;; the tree would have left a WHOLE-FILE-ABORT primitive lying next to the
;; walks that used to call it — the exact shape this track has shipped four
;; times. Retired rather than kept "in case P5 needs it": ban-dual-paths.
;; What replaced it: typing refuses through the failure slot the walks already
;; thread (`bcast-carrier` in typing-errors.rkt), and reduction reports through
;; `(return (expr-panic …))` via the single `let/ec`. Two channels, neither a raise.

;; The wrapped step. Total on `select-bcast-step?` values by construction: the
;; smart constructor is the only producer and it always supplies one.
(define (select-bcast-inner s) (cadr s))

(define (make-select-bcast step) (list '@bcast step))

;; D4.P4e-1b (Q_U40): `(@star cont)` — THE FLATTEN / LAYER-DELETE STEP.
;;   cont ::= 'flatten        (bare `*`)
;;          | 'flatten-synth  (`*_`, the Q_U24 provenance variant)
;; Those two symbols are exactly what `split-star-lexeme` (parser.rkt) already
;; returns, so the parser mints this kind without inventing a vocabulary.
;;
;; SEMANTICS (Q_U40, one sentence): the star deletes the container layer
;; contributed by the PRECEDING step — everything to its left in its branch, or
;; the SUBJECT when it is branch-initial — and joins that layer's contents into
;; the enclosing level. The join's SORT follows the CONTENTS: vectors CONCAT ·
;; Maps join KEYWISE (Q_U38 refuses collisions) · keyless components CONCAT
;; (spec §3.6 rule 5) · leaves ERROR (rule 4). Q_U42 makes it one RECURSIVE rule:
;; a shared key whose two values are vectors CONCATENATES rather than erroring.
;;
;; ⚠⚠ THE "INERT AT 1b-ii" HEADER THAT STOOD HERE WAS FALSE FROM 1b-iii-B2
;; (`d5934397`) UNTIL 1b-iii-C1, and this is the first thing a reader grounding
;; on the star opens. It said the parser still refuses so nothing mints an
;; `(@star …)`; the seat migration made four sites mint one, and the flatten has
;; been LIVE ever since. Corrected rather than deleted, because "a precondition
;; written into a comment and then invalidated a slice later" is the exact shape
;; that got 1b-iii reverted TWICE — its two other instances were at
;; `select-branch-top-keys` and `select-branch-keyless?`, and this was the third.
;;
;; STATE AT 1b-iii-C2 + verify round 1. The kind is LIVE and so is the DEEP
;; flatten: the parser mints `(@star cont)` from all four bands, both shields are
;; GONE, and vector contents join at ANY prefix depth. The landing is [Q_U47]'s —
;; keyed under a surviving named step, keyless otherwise — and it is produced by
;; whichever caller catches the bare join, not computed anywhere. Nominal
;; contents are 1b-iv. The ordinal gap ([Q_U46]) is a guided refusal at BOTH
;; layer-computing seats.
;; ⚠ THIS HEADER WAS STALE FOR THE WHOLE OF C2 — it still said "STATE AT
;; 1b-iii-C1 … depth ≥ 2 is SHIELDED", present tense, at a HEAD where it was not,
;; and the adversarial verify is what caught it. That is the FOURTH instance of
;; the shape named below, and the second time it was THIS comment. Rewriting it
;; is cheap; the reason it keeps rotting is that it describes state rather than
;; contract, so it is now written to survive the next slice: what is invariant is
;; the LANDING RULE, not which shields happen to exist.
;; ⚠ Whoever changes that: this comment is a PRECONDITION. Re-read it at the
;; seat before invalidating it, and correct it in the SAME commit.
(define (select-star-step? s) (and (pair? s) (eq? (car s) '@star)))

;; ⭐⭐ D4.P4e-1b slice 1b-iii-C2 — THE TWO SHAPE TESTS THE SEAT MIGRATION TURNS
;; ON. Both live HERE, in the one file that owns the step vocabulary, because
;; each is consulted by BOTH twins and a hand-copied second definition is the
;; drift class this track has paid for repeatedly.
;;
;; `select-branch-deep-star?` — is this branch a WELL-FORMED DEEP trailing star,
;; i.e. one the head dispatch should handle rather than the branch-level star
;; pre-check? Deep means at least TWO prefix steps, so the remainder (the branch
;; minus the star minus `sₙ`) is NON-EMPTY and [Q_U47]'s landing is the caller's
;; to make. Everything else a star can appear in — `[★]`, `[k ★]`, a star that is
;; not last, two stars — stays with `star-branch-entries`, which owns the
;; remainder-EMPTY landing and every star refusal.
;; ⚠ The malformed shapes MUST keep routing there. A mid-branch star that fell
;; through to the head dispatch would reach `select-below-field` with a star at
;; the HEAD of its step list, match no arm, and hit the `[else]` — which is a
;; plain `error`, i.e. a WHOLE-FILE abort. That is round 1's abort, one seat over.
(define (select-branch-deep-star? b)
  (let ([rev (reverse b)])
    (and (pair? rev)
         (select-star-step? (car rev))          ;; ends in a star
         (pair? (cdr rev)) (pair? (cddr rev))   ;; …with ≥ 2 prefix steps
         (not (ormap select-star-step? (cdr rev))))))

;; `select-steps-star-tail?` — is this below-walk step list EXACTLY `(sₙ ★)`?
;; ⚠ EXACTLY TWO, and that is the subtle half. The tail arm must fire only when
;; the layer to delete is the one `sₙ` makes. On `(b c ★)` it must NOT fire: the
;; walk has to consume `b` normally so `b` re-nests around the join, exactly as
;; it would around a starless result. Firing early would compute the layer over
;; the whole remaining prefix — which re-nests — and that is the BRANCH-ROOT
;; reading Q_U46 rejected, reappearing one level down.
(define (select-steps-star-tail? steps)
  (and (pair? steps) (pair? (cdr steps)) (null? (cddr steps))
       (select-star-step? (cadr steps))
       (not (select-star-step? (car steps)))))

;; ⭐ 1b-iii-C2 VERIFY ROUND 1 — the two predicates the round-1 defects needed,
;; both here for the same reason as their neighbours: more than one seat asks.
;; ⚠ ROUND 2, F7 — THEY WERE SPLICED ABOVE THIS POINT, between the header of
;; `select-steps-star-tail?` and the function that header guards: ~40 lines and
;; two unrelated definitions separating a PRECONDITION ("⚠ EXACTLY TWO, and that
;; is the subtle half") from the code it constrains. Moved below it, so a reader
;; meets the rule and the function together — which is the only reason the rule
;; survives the next edit.
;;
;; `select-step-makes-no-layer?` — does this step contribute NO output level, so
;; that a star after it has nothing to delete? [Q_U2] Reading A for ordinals.
;; ⚠ IT MUST BE ASKED AT EVERY SEAT THAT COMPUTES A LAYER, not just one. C2
;; shipped the check at the tail arm only, and the dissolve route reaches the
;; layer through `star-branch-entries` instead — so `y{a[0]*}` refused while
;; `y{a^[0]*}` silently ANSWERED, deleting a layer the ordinal never made and
;; committing by accident to the question Q_U46 deliberately reserved.
(define (select-step-makes-no-layer? s)
  (memq (select-step-kind s) '(ord-step ord-branch)))

;; `select-branch-has-star?/deep` — does this branch contain a star ANYWHERE,
;; including inside a `(@sub …)` payload?
;; ⚠ THE RECURSION IS THE POINT. A plain `ormap select-star-step?` sees only the
;; branch's TOP-LEVEL steps, so a star nested in a sub-block is invisible — and
;; a dissolved head then SPLICES that star's keyed component into the enclosing
;; level, where two branches can deliver the same output key with no gate seeing
;; either. Measured: `s7{a^.{b.c*} b}` and `s7{b a^.{b.c*}}` returned DIFFERENT
;; values and DIFFERENT types at ZERO errors, i.e. the answer depended on the
;; order the branches were written.
;; ⚠ ROUND 2, F4 — AND THE NAME USED TO OVERCLAIM. This said "ANYWHERE" while
;; recursing into `(@sub …)` ONLY. The step vocabulary is a CLOSED union of seven
;; kinds and exactly TWO carry a nestable payload — `@sub` and `@bcast` — so the
;; gap was total and nameable: a star inside `xs:{…}` was invisible to it exactly
;; as one inside `.{…}` had been. ω-TRANSPARENCY is a written invariant of this
;; predicate's own [leaf] family, and all four siblings (`select-step-name`,
;; `select-step-cont`, `select-branch-collapse`, `select-branch-keyless?`) unwrap
;; through `select-bcast-inner` first; the new predicate joined the family
;; without it. Unwrapping is the two-line repair, and it means "ANYWHERE" is now
;; true rather than aspirational.
(define (select-branch-has-star?/deep b)
  (ormap (lambda (s0)
           (let ([s (if (eq? (select-step-kind s0) 'bcast)
                        (select-bcast-inner s0)
                        s0)])
             (or (select-star-step? s)
                 (and (select-sub-step? s)
                      (ormap select-branch-has-star?/deep (cdr s))))))
         b))

;; ⭐⭐ 1b-iv VERIFY — "WILL THIS WALK END IN A BARE JOIN?", which is what the
;; CALLERS actually need to ask, and is NOT the same question as the tail arm's.
;; `select-steps-star-tail?` answers "is THIS step list exactly `(sₙ ★)`", which
;; is right for the ARM. B2 used it caller-side as a PROXY for "did the tail arm
;; fire", and that proxy is a FALSE NEGATIVE through TRANSPARENT steps: an
;; ordinal contributes no layer (Q_U2 Reading A) and the below-walk recurses
;; straight through it, so `(0 m ★)` DOES end in a bare join — but the two-step
;; test says no. MEASURED before this fix, at 0 errors:
;;   vk1{0.m*}      ⟹  {:x 1} : {:x Int}          rest = (m ★)   — SPLICED
;;   vk2{0 .0.m*}   ⟹  @[{:x 1}] : ⟨{:x Int}⟩     rest = (0 m ★) — NOT spliced
;; with `w2{0 .0.{m n}*}` proving the JOIN itself ran (both fields merged) and
;; only the LANDING differed. Two spellings of the same shape, two landings.
;; ⚠ THE ARM'S OWN "EXACTLY TWO" WARNING IS UNTOUCHED AND MUST STAY SO: it fires
;; on exactly `(sₙ ★)` because a KEYED prefix step has to re-nest. That reason is
;; precisely what does NOT apply to a step making no layer, which is why skipping
;; those here is the same rule rather than a relaxation of it.
(define (select-steps-yield-bare-join? steps)
  (let loop ([ss steps])
    (if (and (pair? ss) (pair? (cdr ss)) (select-step-makes-no-layer? (car ss)))
        (loop (cdr ss))
        (select-steps-star-tail? ss))))

(define (make-select-star cont) (list '@star cont))

;; ⭐ D4.P4e-1b slice 1b-iii-A [Q_U44] — CANONICAL KEY ORDER, defined ONCE.
;; When the star's join concatenates the values of a KEYED layer into a vector,
;; an order has to be MANUFACTURED, and Q_U44 rules it canonical: the `symbol<?`
;; order `make-record` already canonicalizes record labels with (see its own
;; `less?`, this file). Champ hash order was the defect Q_U44 killed — arbitrary
;; and liable to move with the champ implementation.
;;
;; ⛔ ATTEMPT 2 SORTED `(format "~a" key)` AND ITS COMMENT *AND* ITS NEW PIN BOTH
;; CLAIMED `symbol<?`. A champ key is the `expr-keyword` STRUCT, and it is
;; `#:transparent`, so `format` renders `#(struct:expr-keyword reset)` — whose
;; trailing `)` (ASCII 41) reorders any proper-prefix pair whose extra character
;; sorts below it (`!` `$` `%` `&` `'`, all legal in Prologos identifiers).
;; MEASURED: `reset` vs `reset!` → `format` says #f where `symbol<?` says #t.
;; The pin missed it because its `aa`/`mm`/`zz` key set AGREES under both.
;;
;; ⚠ SCOPE, and it is deliberate: this is `make-record`'s **'keyword** fork only.
;; `make-record` also has a 'nat fork (plain `<`), but a nat-domain level is an
;; `expr-rrb` at the VALUE layer — `entries->value`'s keyless branch builds one —
;; so it never reaches a champ walk and is already ordered. A champ CAN still
;; hold a non-keyword key (`map-assoc` inserts any whnf'd expr), which is why the
;; guard below is separate and total: the WALKER checks it and reports an
;; invariant violation through reduction's panic channel rather than inventing an
;; order here. A comparator that silently ordered the un-orderable is exactly the
;; defect this replaces.
(define (canonical-keyword-key? k) (expr-keyword? k))
(define (canonical-keyword-key<? a b)
  (symbol<? (expr-keyword-name a) (expr-keyword-name b)))
;; The star's OWN continuation. ⚠ Read it with THIS, never with
;; `select-step-cont` — see that function's note: `'flatten`/`'flatten-synth`
;; are not CARET conts and must not enter that channel.
(define (select-star-cont s) (cadr s))

;; D4.P4a — THE STEP-KIND TOTALITY DISPATCHER (owner ruling 2026-07-31:
;; route ALL EIGHT dispatch sites through this one classifier).
;;
;; The step vocabulary is a CLOSED union, and it is about to grow: Q_U7 adds
;; `(@bcast step)` at P4c. Before P4a, eight `cond` arms across THREE modules
;; dispatched on step kind and SILENTLY absorbed an unknown one — two
;; contributing no name/component, six silently projecting it as a NOMINAL
;; KEY. A sixth kind reaching any of them is a silent wrong answer, which is
;; the exact failure `pipeline.md` § "Exhaustive Walkers" was written for.
;; This is that rule applied BEFORE the kind lands rather than after a miss.
;;
;; The kinds are pairwise disjoint by construction (a symbol and a number are
;; not pairs; @key/@sub/@ord are pairs with distinct heads), so the classifier
;; is total and order-independent. `match` cannot help here — steps are
;; s-expressions, not transparent structs, so the generic-rebuild answer in
;; pipeline.md does not apply and a named classifier is the available
;; structural form.
;;
;; ADDING A KIND — the site list. ⚠⚠ **CORRECTED AT D4.P4e-1b (2026-08-11): IT
;; WAS NOT COMPLETE, AND ITS OWN BOAST OF COMPLETENESS IS WHAT MADE IT
;; DANGEROUS.** The list below (13 functions, FIVE files) is REAL but PARTIAL.
;; Measured by attributing every live dispatch site to its enclosing function
;; (indentation-aware, so nested helpers charge to themselves):
;;
;;     59 live dispatch sites · 35 inside the 13 named functions · 24 outside,
;;     of which the classifier family itself (select-step-kind, /display,
;;     -unhandled, the export manifest) accounts for the bulk, leaving:
;;
;;   TWO deliberately outside, and THE RECIPE NEVER SAID SO — `select-step-name`
;;   and `select-step-cont` (below). Their permissive `[else s]` / `[else #f]`
;;   tails mean a new kind gets a WRONG ANSWER rather than a raise:
;;   `select-step-name` hands back the RAW STEP LIST (the DEFERRED 40/46
;;   raw-list-into-a-user-message class) and `select-step-cont` answers `#f` —
;;   which is exactly what `findf select-step-cont` (parser.rkt, the `^`-in-path
;;   refusal) and `branch-problem`'s positional check key on. These are the
;;   vocabulary's silent trapdoors; a new kind MUST decide both deliberately.
;;
;;   EIGHT genuinely OMITTED sites, each in a function this list never named:
;;     parser.rkt       segment-select-items — the bare-`.`-after-caret arm
;;                      segment-select-items — the head-name recovery, whose
;;                                             `[else "field"]` is a SILENT wrong
;;                                             default in a USER-FACING message
;;                      parse-list           — the `^`-in-path-access refusal
;;     reduction.rkt    bcast-apply
;;     typing-core.rkt  select-tier-subject  — the ω PEEL (DEFERRED 43's
;;                                             silent-miss class)
;;                      select-bcast-lift
;;                      select-bcast-inner-apply/non-union
;;                      select-below-components
;;
;; Reproduce before trusting (coordinates drift; the FUNCTION NAMES do not):
;;   grep -n 'select-step-kind\|select-key-step?\|select-sub-step?\|
;;            select-ord-step?\|select-bcast-step?' *.rkt
;; then attribute each hit to its INNERMOST enclosing `define`. ⚠ A pass that
;; matches only column-0 `define` charges every nested helper to its enclosing
;; top-level function and over-counts the omissions ~3× — six entries in the list
;; below are themselves nested, so the tell is the list appearing to have no live
;; sites. That instrument defect was made and caught during this correction.
;;
;; ⚠ P4c-3 ADDED THE SIXTH KIND, `(@bcast step)`, THROUGH THIS RECIPE and this
;; comment claimed it *"met all thirteen; the recipe held with no correction
;; needed, which is the first time an enumeration in this track has survived a
;; new member intact."* **THAT CLAIM IS FALSE, and it is struck.** The sixth kind
;; met the thirteen because the thirteen were the only places anyone looked; four
;; of the eight omissions above are ω-specific functions that `(@bcast step)`
;; ITSELF introduced. An enumeration cannot be validated by the member it was
;; written for. ⚠ The first
;; cut of this recipe said "every `case (select-step-kind …)` in syntax.rkt,
;; typing-core.rkt and reduction.rkt", which was written from the eight sites
;; a name-grep found. That census was SYNTAX-directed and structurally could
;; not see two whole classes: dispatchers that OPEN-CODE the shape tests
;; (pretty-print), and dispatchers shaped as `and`/`if` rather than `cond`
;; (the leaf classifiers, parser). Following the old recipe literally left
;; FIVE sites wrong — two of them UPSTREAM of the guards, so they defeat the
;; guard rather than sit beside it. Corrected at the P4a adversarial verify.
;;
;;   syntax.rkt       select-step-output-name · select-branch-top-keys
;;                    select-branch-collapse  · select-branch-keyless?   [leaf]
;;   typing-core.rkt  walk-to-leaf · select-branch-entries · select-below-field
;;   reduction.rkt    walk-to-leaf · branch-entries · below-value
;;   parser.rkt       dissolve-step? [leaf] · branch-problem
;;   pretty-print.rkt step->string
;;
;; The four LEAF classifiers (marked [leaf]) matter most: they run BEFORE the
;; branch walks and answer a silent #f if they do not recognize the leaf, so a
;; missed kind is mis-SORTED (keyed vs keyless) with no raise downstream.
;;
;; All sites raise on a missed kind EXCEPT `pretty-print.rkt`'s, which renders
;; a loud marker instead — `pp-expr` is on the error-message path, so raising
;; there would turn a diagnostic into an internal crash, and an existing
;; catch-all handler could swallow it, achieving LESS than a visible marker.
;; That is a written scope decision, not an omission.
(define (select-step-kind s)
  (cond
    [(symbol? s)          'key]         ;; plain kept descent
    [(number? s)          'ord-step]    ;; `.N` — Q_U2 Reading A (no output level)
    [(select-key-step? s) 'caret]       ;; (@key name cont)
    [(select-sub-step? s) 'sub]         ;; (@sub . branches) — terminal sub-block
    [(select-ord-step? s) 'ord-branch]  ;; (@ord N) — ordinal BRANCH head
    [(select-bcast-step? s) 'bcast]     ;; (@bcast step) — the ω/broadcast step
    [(select-star-step? s) 'star]       ;; (@star cont) — D4.P4e-1b, the FLATTEN
    [else
     (error 'select-step-kind
            (string-append
             "unknown select step kind: ~s\n"
             "  the step vocabulary is a CLOSED union: symbol | number"
             " | (@key name cont) | (@sub . branches) | (@ord N) | (@bcast step)"
             " | (@star cont)\n"
             "  a new kind must be added to select-step-kind AND given an arm"
             " in every `case` over it (D4.P4a)")
            s)]))

;; D4.P4a: the NON-RAISING variant, for the DISPLAY path ONLY
;; (`pretty-print.rkt`'s `step->string`). `pp-expr` is on the error-message
;; path, so it must never convert a real diagnostic into an internal crash —
;; it renders a loud marker instead. Defined by DELEGATION rather than by
;; re-listing the predicates: a second copy of the kind list is precisely the
;; drift this phase exists to eliminate, so this cannot fall out of step with
;; the classifier by construction.
(define (select-step-kind/display s)
  (with-handlers ([exn:fail? (lambda (_) 'unknown)])
    (select-step-kind s)))

;; The consumer-side else. Every `case (select-step-kind …)` ends here, so a
;; kind added to the classifier but missed at a consumer raises AT that
;; consumer, naming it — rather than falling into a nominal-key arm.
(define (select-step-kind-unhandled who s)
  (error who
         (string-append
          "no arm for select step kind '~a (step: ~s)\n"
          "  the kind is known to select-step-kind but this walk has no arm"
          " for it — add one (D4.P4a totality)")
         (select-step-kind s) s))

;; D4.P4b-ii-1 — the SORT axis gets the same totality treatment as the step
;; axis, for the same reason and BEFORE it grows. `sort` is 'path | 'block
;; today, but Q_U12 already NAMES the next members: `#.field` (nil-safe) and
;; `[k]` (ordinal/dynamic) are "genuinely DIFFERENT SORTS" whose migration is
;; a deferred follow-up. An `(if (eq? sort 'path) … …)` would hand each of
;; them BLOCK semantics silently — the exact catch-all class P4a spent a
;; phase eliminating, re-introduced on a fresh axis one slice later.
;; Every sort dispatch ends here instead.
(define select-sorts '(path block))
(define (select-sort? s) (and (memq s select-sorts) #t))
(define (select-sort-unhandled who sort)
  (error who
         (string-append
          "no arm for selector sort '~a\n"
          "  known sorts: ~a — add an arm (D4.P4b-ii-1 sort totality)")
         sort select-sorts))

;; ⚠ D4.P4c-3a — THE TWO ACCESSORS ARE ω-TRANSPARENT. Both were ω-BLIND, both
;; sit OUTSIDE the `ADDING A KIND` recipe, and both were missed for the same
;; structural reason: the recipe enumerates `case (select-step-kind …)`
;; dispatchers, and these are an `if`/`and` over ONE predicate. D4's P4c-3
;; partition names them as "the two shape-test helpers OUTSIDE the recipe".
;;
;; ⚠ NO LINE NUMBERS BELOW, DELIBERATELY. The first cut of this block cited its
;; own file's coordinates and the block's own length invalidated every one of
;; them — the exact class `19ab78a9` had fixed one commit earlier. Anchor on
;; NAMES; `grep` is the index.
;;
;; ω is KEY-TRANSPARENT: it changes container ARITY, not key behaviour, so
;; `users:k` names and re-keys exactly as `users.k` does. Delegation is
;; RECURSIVE, matching `select-step-output-name`'s `[(bcast)]` arm — the surface
;; cannot write a nested wrapper (extent is one-step, Q_U7) but the
;; representation permits one and P5's factoring rewrites branches, and a
;; surface rule is not a representation invariant.
;;
;; ── WHAT WAS BROKEN, MEASURED ──
;; `select-step-name`: an ASYMMETRY, which is why the P4c-3 pins missed it. The
;; branch CLASSIFIER `select-branch-collapse` already saw through the wrapper, so
;; a `users:k^-` branch sorted correctly as collapsing — and then its LABEL came
;; from the RAW leaf, so `select-branch-top-keys` yielded `((@bcast (@key k
;; collapse)))`, a LIST, against a contract of "a key SYMBOL … or #f". Three
;; sites share `[else (select-step-name (car (reverse b)))]`: this file's
;; `select-branch-top-keys`, `reduction.rkt`'s `branch-entries`, and
;; `typing-core.rkt`'s `select-branch-entries`. The latter two are MASKED — but
;; for DIFFERENT reasons, and only one of them is evaluation order: reduction
;; computes the label first and discards it when `walk-to-leaf` raises, while
;; typing-core computes it INSIDE the continuation, which the raise precedes.
;; Both go live when P4c-4 removes the raise. THIS file's is live NOW —
;; `select-branch-top-keys` is a pure STATIC key computation feeding the parser's
;; OUTPUT-key duplicate check and its L4 sort-homogeneity check, with nothing to
;; raise first; a non-symbol can never match under the duplicate check's `eq?`,
;; so duplicates go UNDETECTED. Silent, the one outcome P4a exists to prevent.
;;
;; `select-step-cont`: `parser.rkt`'s `^`-in-path-access refusal asked it "does
;; this branch carry a `^`?" without unwrapping, so it silently answered no for a
;; step that had one. Measured on that site's own predicate:
;; `(@key k dissolve)` ⇒ `dissolve` (refusal fires);
;; `(@bcast (@key k dissolve))` ⇒ `#f` (refusal does NOT). D4 §4310 had already
;; booked this hazard for the `:name^alias` spelling.
;;
;; ── WHY TRANSPARENCY RATHER THAN UNWRAP-AT-THE-SITE ──
;; The first cut kept `select-step-cont` blind and hand-copied the unwrap into
;; the parser, on the theory that its callers "ask several questions (kind AND
;; cont)" so the unwrap belongs with the classification. **That theory is false
;; at the one site that needed it**: the refusal asks ONE question, and with a
;; transparent accessor its whole lambda collapses back to a bare
;; `(ormap select-step-cont …)`. Measured: transparency is a NO-OP at the other
;; eight call sites — each has already unwrapped and is looking at a `caret`
;; step, or is behind a `memq` guard that excludes `bcast` — so it fixes the
;; ninth and changes nothing else. A standing obligation on nine call sites that
;; has already been sprung once is not a property to pin; it is a trap to remove.
;; ⚠⚠ THE TWO PERMISSIVE TAILS — named at D4.P4e-1b (2026-08-11) because the
;; "adding a kind" recipe above had never listed them, and they are the
;; vocabulary's only SILENT trapdoors. Every other consumer raises through
;; `select-step-kind-unhandled` on an unknown kind; these two answer.
;;   · `select-step-name`'s `[else s]` hands back the RAW STEP LIST for any kind
;;     that is neither bcast nor caret. For a LIST-shaped kind that is an
;;     internal datum rendered into a user-facing message — DEFERRED 40/46's
;;     class. (It is correct for the two ATOM kinds, `key` and `ord-step`, which
;;     is why it has never fired wrongly: today every list-shaped kind is either
;;     unwrapped first or excluded by a `memq` guard.)
;;   · `select-step-cont`'s `[else #f]` reports "no continuation", and `#f` is
;;     load-bearing downstream: `findf select-step-cont` (parser.rkt's
;;     `^`-in-path-access refusal) and `branch-problem`'s positional check both
;;     key on it. A new kind that legitimately carries a cont and is not added
;;     here is silently treated as carrying none.
;; A NEW KIND MUST DECIDE BOTH DELIBERATELY. Adding an arm is usually right;
;; leaving the tail is defensible ONLY for an atom-shaped kind, and then say so.
(define (select-step-name s)
  (cond
    [(select-bcast-step? s) (select-step-name (select-bcast-inner s))]
    [(select-key-step? s) (cadr s)]
    ;; D4.P4e-1b: the star NAMES NOTHING — it deletes a layer, and the keys it
    ;; lifts are SUBJECT-derived. An explicit arm because `(@star cont)` is
    ;; LIST-shaped: without it the `[else s]` tail hands the raw step list back,
    ;; and this function feeds user-facing messages (DEFERRED 40/46's class).
    [(select-star-step? s) #f]
    [else s]))

(define (select-step-cont s)
  (cond
    [(select-bcast-step? s) (select-step-cont (select-bcast-inner s))]
    [(select-key-step? s) (caddr s)]
    ;; D4.P4e-1b — A DELIBERATE `#f`, and the reasoning is the point. The star
    ;; DOES carry a continuation (`'flatten` / `'flatten-synth`), so returning it
    ;; here would look like the honest answer. It is not: this channel is the
    ;; CARET cont vocabulary, consumed by `select-cont-collapse?` and by
    ;; parser.rkt's `findf select-step-cont` (the `^`-in-path-access refusal). A
    ;; `'flatten` arriving there would be read as a caret continuation and
    ;; misfire. The star's cont is read with `select-star-cont`, deliberately
    ;; kept out of this channel — the two vocabularies are disjoint on purpose.
    [(select-star-step? s) #f]
    [else #f]))

(define (select-cont-collapse? c)
  (or (eq? c 'collapse) (eq? c 'collapse-synth)
      (and (pair? c) (eq? (car c) 'collapse-rename))))

;; the rename target carried by a (collapse-)rename cont, else #f
(define (select-cont-rename c)
  (and (pair? c) (memq (car c) '(rename collapse-rename)) (cdr c)))

;; the branch's LEAF collapse continuation, or #f (the `^-` family flattens
;; the WHOLE branch, so its walk is a pre-classified special case)
(define (select-branch-collapse b)
  (let* ([s0 (car (reverse b))]
         ;; D4.P4c-3 (Q_U7): a LEAF classifier sees through the ω wrapper —
         ;; `users:k^-` collapses exactly as `users.k^-` does. ⚠ This is one of
         ;; the FOUR [leaf] sites the recipe flags as mattering most: they run
         ;; BEFORE the branch walks and answer a silent #f on a kind they do
         ;; not know, so a missed arm MIS-SORTS the branch (keyed vs keyless)
         ;; with no raise anywhere downstream.
         [s (if (eq? (select-step-kind s0) 'bcast) (select-bcast-inner s0) s0)])
    ;; D4.P4a: CLASSIFY the leaf rather than testing `select-key-step?`
    ;; directly. This runs UPSTREAM of every guarded walk (syntax :932,
    ;; typing-core :787, reduction :1689), so an unknown leaf kind answering
    ;; a silent #f here defeats the guards downstream instead of reaching
    ;; them — the branch is then mis-sorted with no raise anywhere.
    ;; Identical for all five known kinds (only `caret` ever answered #t).
    ;; ⚠ D4.P4e-1b: `star` answers #f here, and that is CORRECT rather than
    ;; merely inherited — a `^-` collapse lifts exactly ONE flat entry to the
    ;; enclosing level, while a star lifts MANY. Collapse-adjacent, not a
    ;; collapse. Recorded because this is a [leaf] site, where a #f nobody
    ;; examined is how a kind gets mis-sorted with no raise downstream.
    (and (eq? (select-step-kind s) 'caret)
         (let ([c (select-step-cont s)])
           (and (select-cont-collapse? c) c)))))

;; A step's contribution to the surviving OUTPUT-name path: kept → its name;
;; renamed → the new label; dissolved → none ("dropped means dropped");
;; synth/collapse leaves → their SOURCE name (they have no other). Ordinal
;; steps and `@ord` heads contribute no name (P3c — contingent keys have no
;; identity, Q_U2).
(define (select-step-output-name s)
  ;; D4.P4a site 1: was `[else #f]` — a sixth kind silently contributed NO
  ;; name, so every synth name (`^_`, `^-_`) computed from a branch carrying
  ;; one would be silently short.
  (case (select-step-kind s)
    [(key) s]
    [(ord-step) #f]
    [(sub) #f]
    [(ord-branch) #f]
    [(caret)
     (let ([c (select-step-cont s)])
       (cond
         [(eq? c 'dissolve) #f]
         [(select-cont-rename c) => values]
         [else (cadr s)]))]
    ;; D4.P4c-3 (Q_U7): ω is KEY-TRANSPARENT — it changes container ARITY, not
    ;; key behaviour, so the output name is the WRAPPED step's. `users:name`
    ;; keys `:name` exactly as `users.name` does. NOT `#f` like `ord-step`:
    ;; transparent here means DELEGATE, not "contributes nothing".
    [(bcast) (select-step-output-name (select-bcast-inner s))]
    ;; D4.P4e-1b (Q_U40): the star contributes NO output name, and this is right
    ;; for BOTH conts — which is the non-obvious part. `*_`'s synth prefix comes
    ;; from the PRECEDING step, not from the star: `cfg{database*_ …}` has branch
    ;; [database (@star flatten-synth)], `select-synth-name` joins the surviving
    ;; names, `database` comes from the key step, the star adds nothing, and
    ;; `:database-url` falls out. `#f` here is NOT the `ord-step` "transparent"
    ;; reading — it is "this step names nothing of its own".
    [(star) #f]
    [else (select-step-kind-unhandled 'select-step-output-name s)]))

;; D4.P3c: the `^`-terminated (keyless) branch pre-classifier — a branch
;; whose LAST step is a bare dissolve contributes the leaf VALUE as a
;; keyless component (Q_T4b: no keys ⇒ no ancestry question; the whole
;; branch flattens like the collapse family, minus the label).
(define (select-branch-keyless? b)
  (let* ([s0 (car (reverse b))]
         ;; D4.P4c-3 (Q_U7): see through the ω wrapper — same [leaf] argument as
         ;; select-branch-collapse; a silent #f here mis-sorts the branch as
         ;; KEYED, which then feeds the parser's L4 sort and duplicate checks.
         [s (if (eq? (select-step-kind s0) 'bcast) (select-bcast-inner s0) s0)])
    ;; D4.P4a: classify the leaf — same upstream-of-the-guards argument as
    ;; select-branch-collapse. A silent #f here mis-sorts the branch as KEYED,
    ;; which then feeds the parser's L4 sort check and duplicate-key check.
    ;; ⚠⚠ D4.P4e-1b (Q_U43): `star` answers #f here — i.e. "KEYED" — and unlike
    ;; `select-branch-collapse`'s #f that answer is NOT known to be right. A star
    ;; branch's sort follows its CONTENTS, which are subject-derived: keyed when
    ;; they are Maps, keyless when they are vectors or ordinal components. This
    ;; classifier cannot see them. Q_U43 moves the L4 sort decision to typing for
    ;; star-bearing branches; the #f here must not be read as a classification.
    ;;
    ;; ⚠⚠⚠ THE REASON THIS #f IS SAFE WAS REWRITTEN AT 1b-iii-A, AND THE OLD
    ;; REASON IS THE SHAPE THAT GOT 1b-iii REVERTED TWICE. It read: "the #f here
    ;; is INERT (the parser refuses the star before any branch walk runs)". That
    ;; is a PRECONDITION THE SEAT MIGRATION DELETES — and the migration is the
    ;; whole point of 1b-iii, so the comment was guaranteed to rot, and did. Its
    ;; sibling at `select-branch-top-keys` rotted the same way, one slice apart.
    ;;
    ;; The replacement is a CHECKABLE INVARIANT rather than a precondition:
    ;;   EVERY production consumer pre-checks for a star BEFORE consulting this.
    ;; All three, and the grep that audits them is `select-branch-keyless?`:
    ;;   · syntax.rkt      `select-branch-top-keys` — `[(ormap select-star-step? b) '()]`
    ;;                     immediately above its call. LIVE TODAY.
    ;;   · reduction.rkt   `branch-entries`         — star arm ahead of `col`   [1b-iii]
    ;;   · typing-core.rkt `select-branch-entries`  — star arm ahead of `col`   [1b-iii]
    ;; Adding a consumer means adding its shield, or giving this predicate a real
    ;; answer — which it cannot have without the subject. Do not restore a reason
    ;; that depends on what some OTHER layer currently refuses.
    (and (eq? (select-step-kind s) 'caret)
         (eq? (select-step-cont s) 'dissolve))))

;; Reading N (Q_T4b′) + `^-_` flat provenance (Q_T7): join the surviving
;; output names with `-`. Scope = the branch of the block the leaf sits in.

;; ⭐ D4.P4e-1b slice 1b-v — THE SYNTH SEPARATOR, DEFINED ONCE.
;; `^_` / `^-_` join the surviving path with it; [Q_U51] rules `*_`'s lifted key
;; is `<the key its content sat under in the deleted layer>-<the field's own
;; key>`, and [Q_U24] rules `*_` inherits `^-_`'s rule rather than `^_`'s. Two
;; operators, one convention — so it lives in one place. A second copy of a
;; separator is the F1b.7g drift shape in miniature.
(define select-synth-separator "-")

(define (select-synth-name steps)
  (string->symbol
   (string-join
    (map symbol->string (filter values (map select-step-output-name steps)))
    select-synth-separator)))

;; [Q_U51]'s provenance key for `*_`: the content's own key, then the field's.
;; ⚠ Takes SYMBOLS and returns a SYMBOL — the callers hold champ/record keys,
;; which are already symbols at both layers.
(define (select-synth-prefixed-key content-key field-key)
  (string->symbol
   (string-append (symbol->string content-key)
                  select-synth-separator
                  (symbol->string field-key))))

;; The output COMPONENTS a branch contributes AT ITS BLOCK'S LEVEL — a
;; dissolved head splices its continuation's components (Q_T3:
;; "level-local" means OUTPUT level, after splicing). Each component is a
;; key SYMBOL (keyed sort) or **#f** (keyless sort — D4.P3c: `^`-terminated
;; branches, `@ord` heads, and pure ordinal-step chains). Fully static; the
;; parser's duplicate check (over the keyed subset) AND the L4
;; sort-homogeneity check both run on these, strictly BEFORE any
;; make-record could last-win.
(define (select-branch-top-keys b)
  (let ([col (select-branch-collapse b)])
    (cond
      ;; ⚠⚠ D4.P4e-1b (Q_U43) — PRE-CLASSIFY a star-bearing branch, BEFORE the
      ;; head dispatch below. The head dispatch reads `(car b)`, and a star is
      ;; almost always LAST (`database*` is [database (@star flatten)]), so an
      ;; arm in the `case` would be nearly unreachable — and the fall-through is
      ;; not merely blind, it is WRONG: the branch would report `:database`, a
      ;; key the star has DELETED and which the output therefore does not carry.
      ;; `dup-output-key` would then compare a phantom key against siblings and
      ;; `mixed-sorts?` would classify the branch keyed on that basis.
      ;; (Found by the 1b-ii failing test, which is why the arm is here and not
      ;; in the `case`: the first cut put it there and the pin caught it.)
      ;; `'()` is NOT a classification — it is the recorded ABSENCE of one, per
      ;; Q_U43, which moves both gates to typing where the subject's row is
      ;; visible. A nested star inside a `(@sub …)` reaches this same pre-check
      ;; through the recursive `append-map` below.
      ;;
      ;; ⚠⚠ REASON REWRITTEN AT 1b-iii-A — the old one ("safe only while the star
      ;; cannot reach a block; THE CARVE-OUT AT THE GATES IS 1b-iv WORK") was a
      ;; precondition the SEAT MIGRATION deletes, and its sibling comment at
      ;; `select-branch-keyless?` rotted identically. `'()` is right BEFORE and
      ;; AFTER the migration, and here is the part that has to be checked rather
      ;; than assumed:
      ;;   · `'()` lets `m2{a* b}` through the parser, which is CORRECT — Q_U40
      ;;     rules it legal (splice `a`, KEEP `b`'s key) and calls it the reason
      ;;     the branch form is strictly more expressive.
      ;;   · `'()` ALSO lets `mm{zz* aa}` through, which is an L4 mixed-sorts
      ;;     ERROR — so TYPING OWES THAT CHECK. It does not exist yet. Until it
      ;;     lands, a star branch beside a keyed sibling reaches `make-record`
      ;;     with a `#f` label and RAISES (round 1's defect #2).
      ;; ⛔ DO NOT "FIX" THIS TO `(list #f)`. Attempt 2 did, classifying every star
      ;; branch KEYLESS, and it refuses `m2{a* b}` — the parser cannot tell Map
      ;; contents from vector contents, which is the entire reason Q_U43 moved the
      ;; decision to typing. Recorded at D4 § the attempt-3 audit, finding A2.
      [(ormap select-star-step? b) '()]
      [col
       (list (cond
               [(select-cont-rename col)]
               [(eq? col 'collapse-synth) (select-synth-name b)]
               [else (select-step-name (car (reverse b)))]))]
      [(select-branch-keyless? b) (list #f)]
      [else
       ;; D4.P4a site 2: was `[else '()]` — a sixth kind silently contributed
       ;; NO component, so the parser's L4 sort check and its OUTPUT-key
       ;; duplicate check would both simply not see it.
       (let ([s (car b)] [rest (cdr b)])
         (case (select-step-kind s)
           [(key) (list s)]
           [(ord-branch) (list #f)]
           ;; ⚠ D4.P4e-1b: `star` has NO arm here BY DESIGN — the pre-check at
           ;; the top of this function classifies star-bearing branches before
           ;; the head dispatch is reached, so an arm here would be a second path
           ;; to the same answer (ban-dual-paths). See that pre-check for why the
           ;; walk cannot answer for a star at all (Q_U43).
           ;; a bare-number STEP head arises only from dissolve-splice
           ;; continuations — transparent (Q_U2: no output level); an
           ;; ordinal-terminal chain has no surviving key → keyless.
           [(ord-step)
            (if (null? rest) (list #f) (select-branch-top-keys rest))]
           [(sub) (append-map select-branch-top-keys (cdr s))]
           ;; D4.P4c-3 (Q_U7): ω is key-transparent — the component set is the
           ;; WRAPPED step's, with the same rest. ⚠ POLARITY CORRECTED at
           ;; P4c-4b: this arm is NOT "unreachable-at-head today" — it is REACHED
           ;; by the headline spelling `users:name`, because `$select-path`
           ;; consumes the subject and the ω step arrives first. See
           ;; `select-bcast-step?`'s header. The arm was written on the reasoning
           ;; that a surface rule is not a representation invariant; that
           ;; reasoning was right and its premise was wrong.
           ;; ⚠ D4.P4d-0 (B1, adversarial verify): delegation is right for a
           ;; SYMBOL inner and WRONG for a SUB inner — recursing into the sub
           ;; arm SPLICES the inner keys `(a b)`, while the branch walks
           ;; contribute ONE KEYLESS component (`select-step-output-name` says
           ;; #f). That drift leaked past the L4 gates in three grades, the
           ;; worst a `symbol<?` WHOLE-FILE ABORT on `x{k users^:{a b}}` —
           ;; `select-assemble-row` sorting a #f label.
           ;; ⚠ D4.P4d slice 2 (DEFERRED 45): the SAME drift had an ORDINAL
           ;; grade — recursing `(cons inner rest)` walked PAST an ordinal
           ;; inner to whatever keyed step followed (`k^:0:nm` computed as
           ;; keyed `nm`), while both consumers label the component by
           ;; `select-step-output-name` (typing entries + reduction entries) —
           ;; a live WRONG L4 mixed-sorts refusal. The fix makes check ≡
           ;; meaning BY CONSTRUCTION: ONE component labeled by the ω step's
           ;; output name. B1's sub special-case DISSOLVES into it
           ;; (output-name on a sub inner is #f).
           [(bcast) (list (select-step-output-name s))]
           [(caret)
            (let ([c (select-step-cont s)])
              (cond
                [(eq? c 'dissolve)
                 (cond
                   [(null? rest) (list #f)] ;; keyless leaf (pre-classified above; defensive)
                   [(and (select-sub-step? (car rest)) (null? (cdr rest)))
                    (append-map select-branch-top-keys (cdr (car rest)))]
                   [else (select-branch-top-keys rest)])]
                [(select-cont-rename c) => list]
                [(eq? c 'synth) (list (select-synth-name b))]
                [else (list (cadr s))]))]
           [else (select-step-kind-unhandled 'select-branch-top-keys s)]))])))

;; SMART CONSTRUCTOR (D6 §4.1): the ONLY row producer. Dedups labels right-priority
;; (later entries win — Clojure/D10 assoc overwrite) and re-canonicalizes the field order
;; (keyword labels by symbol<?, nat labels by <), so structural `equal?` is a valid identity.
(define (make-record key-domain fields tail)
  (define ht (make-hash))
  (for ([f (in-list fields)]) (hash-set! ht (car f) f))  ;; last write wins
  (define less?
    (if (eq? key-domain 'keyword)
        (lambda (a b) (symbol<? (car a) (car b)))
        (lambda (a b) (< (car a) (car b)))))
  (expr-Record key-domain (sort (hash-values ht) less?) tail))

;; Right-priority row extension (D10 assoc): add/overwrite one field, re-canonicalize.
(define (record-extend rec label field-type)
  (make-record (expr-Record-key-domain rec)
               (append (expr-Record-fields rec)             ;; new field LAST → wins on collision
                       (list (cons label (record-field field-type 'present))))
               (expr-Record-tail rec)))

;; Look up a field by label; returns the record-field or #f.
(define (record-lookup-field rec label)
  (for/first ([f (in-list (expr-Record-fields rec))] #:when (eqv? (car f) label)) (cdr f)))

;; Remove a field by label (exact closed-row removal, D10 dissoc); re-canonicalize.
(define (record-remove rec label)
  (make-record (expr-Record-key-domain rec)
               (filter (lambda (f) (not (eqv? (car f) label))) (expr-Record-fields rec))
               (expr-Record-tail rec)))

;; CIU T6 F1a-col-3: a CLOSED tuple ('nat domain, 'closed tail). The EXACT tuple-op
;; typing arms require BOTH — explicit forward-necessary guards (the B3 precedent),
;; so a future 'dyn tail or a 'keyword row never mis-dispatches into an exact arm.
(define (closed-nat-row? rec)
  (and (expr-Record? rec)
       (eq? (expr-Record-key-domain rec) 'nat)
       (eq? (expr-Record-tail rec) 'closed)))

;; CIU T6 F1b.3 (D21): a CLOSED record ('keyword domain, 'closed tail) — the width
;; discharge's guard shape (tuples are exact/no-width per the F1 pin; dyn-tailed
;; pairs already have C_Cons semantics in the primary unify leg).
(define (closed-keyword-row? rec)
  (and (expr-Record? rec)
       (eq? (expr-Record-key-domain rec) 'keyword)
       (eq? (expr-Record-tail rec) 'closed)))

;; CIU T6 F1b.3 (D24): mark every field 'unknown, tail → 'dyn — the dissoc-dynamic
;; writer's row (a dynamic-key removal leaves every field's PRESENCE uncertain while
;; its type-if-present stays a fact). The sole 'unknown producer this phase.
(define (record-mark-all-unknown rec)
  (expr-Record (expr-Record-key-domain rec)
               (for/list ([fld (in-list (expr-Record-fields rec))])
                 (cons (car fld)
                       (record-field (record-field-type (cdr fld)) 'unknown)))
               'dyn))

;; Type constructor: Map K V
(struct expr-Map (k-type v-type) #:transparent #:property prop:ctor-desc-tag '(type . Map))

;; Runtime value (racket-champ is a champ-root from champ.rkt)
(struct expr-champ (racket-champ) #:transparent)              ; map literal value

;; Constructor
(struct expr-map-empty (k-type v-type) #:transparent)         ; empty map : Map K V

;; Operations
(struct expr-map-assoc (m k v) #:transparent)                 ; assoc : Map K V → K → V → Map K V
;; CIU T6 P2.b slice 4: both carry a STRICTNESS SLOT (the carried-alpha
;; pattern, expr-num-lit's precedent): `strict` is #f (permissive — raw
;; constructions, the get-in/update-in lowering family = the PS12/M3 dynamic
;; tier), an unsolved expr-meta (minted at elaboration on the USER's direct
;; projection), or (expr-true) (typing solved it: the subject is (Map K V) —
;; a runtime miss is a LOUD panic). zonk materializes the meta; reduction reads
;; only the materialized value. The two nodes delegate to each other at
;; reduction, so BOTH carry the slot (a one-node slot is dropped at the crossing).
(struct expr-get (coll key strict) #:transparent)              ; get : Collection → Key → Value (type-directed; ASSERTIVE tier — error if missing/OOB)
(struct expr-map-get (m k strict) #:transparent)              ; get : Map K V → K → V (assertive: LOUD miss when strict)
(struct expr-nil-safe-get (m k) #:transparent)                ; nil-safe-get : (Map K V | Nil) → K → (V | Nil)
(struct expr-map-dissoc (m k) #:transparent)                  ; dissoc : Map K V → K → Map K V
(struct expr-map-size (m) #:transparent)                      ; size : Map K V → Nat
(struct expr-map-has-key (m k) #:transparent)                 ; has-key? : Map K V → K → Bool
(struct expr-map-keys (m) #:transparent)                      ; keys : Map K V → List K
(struct expr-map-vals (m) #:transparent)                      ; vals : Map K V → List V

;; Path algebra operations
(struct expr-get-in (target paths) #:transparent)             ; get-in : M → paths → V
(struct expr-update-in (target paths fn) #:transparent)       ; update-in : M → paths → (V → V) → M
;; expr-broadcast-get: RETIRED at CIU T6 D4.P1a (ruling Q_L3) — it was
;; permissive (fabricated <error>/none rows at 0 errors) and its surface
;; `.*name` is superseded by `:field` broadcast — SHIPPED (D4.P4c-4c);
;; was written as a future promise ("Path Selection P4").

;; ============================================================
;; THE ONE SELECTOR CARRIER  (Q_U5; encoding `389f6802`, nesting `2e3fc14e`)
;; ============================================================
;; `expr-path` IS the reified selector — `#p(…)` is a bare carrier, `x{…}` is
;; a carrier applied to a subject (it sits in `expr-select`'s branches slot),
;; and after D4.P4b-ii-2 path position mints the same carrier. The NAME is
;; legacy (the rename is ~30 arms of pure churn — a named cosmetic follow-up,
;; NOT an alias: there is exactly one struct).
;;
;; branches : (listof branch), branch = (listof step), step per the vocabulary
;;   at §"the `^` step vocabulary" above — BARE SYMBOLS and the tagged sexps,
;;   NOT `expr-keyword`/`expr-symbol` structs (the b-i encoding convergence
;;   `389f6802` unified them; this comment said otherwise until D4.P4b-ii-1).
;;
;; sort : 'path | 'block  — WHICH SPELLING minted this selector.
;;   'block  — `x{…}`: PROJECTS (spec §1.2); refuses a (Map K V) subject,
;;             refuses an 'unknown-presence field (Horn D, Q_T2).
;;   'path   — `#p(…)`, and after b-ii-2 `x.a`: DESCENDS; keeps `map-get`
;;             semantics on a (Map K V) subject (the MAP POSTURE, Q_U10) and
;;             is D19-permissive on a dyn row.
;;
;; WHY A FIELD and not a step kind or a second struct [owner, D4.P4b-ii-1]:
;; the sort is a property of the WHOLE carrier, not of any one step, and it
;; cannot be DERIVED once b-ii-2 lands — today a bare carrier is `#p(…)` and
;; a nested one is a block, but after the fold migrates `x.a` and `x{a}` are
;; the same node shape. A second struct would reopen "ends single-carrier"
;; one slice after b-i closed it.
;;
;; ⚠ ARITY: this struct is registered with `regN!` (pnet-serialize.rkt), NOT
;; `auto-cache!` — auto-cache!'s body swallows exceptions, so a stale-arity
;; call there voids the registration SILENTLY and the node comes back from a
;; `.pnet` as a raw-vector impostor (pipeline.md § New AST Node item 6). The
;; same move `expr-map-get` made at P2.b slice 4, for the same reason.
(struct expr-path (branches sort) #:transparent)              ; THE selector carrier
(struct expr-Path () #:transparent)                           ; Path type (ground, unparameterized)

;; ========================================
;; Set (persistent hash set, backed by CHAMP with #t sentinel)
;; ========================================

;; Type constructor: Set A
(struct expr-Set (elem-type) #:transparent #:property prop:ctor-desc-tag '(type . Set))

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
(struct expr-PVec (elem-type) #:transparent #:property prop:ctor-desc-tag '(type . PVec))
(struct expr-rrb (racket-rrb) #:transparent)                  ; runtime wrapper (opaque Racket rrb-root)
(struct expr-pvec-empty (elem-type) #:transparent)            ; pvec-empty(A) : PVec A
(struct expr-pvec-push (v x) #:transparent)                   ; pvec-push : PVec A → A → PVec A
;; CIU T6 F1a-col (D15): literal-extent node for non-empty @[…] literals. Typed
;; ALL-AT-ONCE: homogeneous (element types unify) → (PVec T) exactly as the old
;; meta-seeded chain; heterogeneous → a closed 'nat row (tuple-by-default, Q_D).
;; Reduction lowers to the pvec-push chain (runtime identical). Explicit
;; [pvec-push v x] chains and empty @[] keep today's meta-seeded semantics.
(struct expr-pvec-literal (elems) #:transparent)              ; @[e0 e1 …] (non-empty)
;; CIU T6 F1a-col-2 (D15): list-literal twin. Carries BOTH the element exprs
;; (typed all-at-once) and the elaborated cons/nil CHAIN (the runtime value —
;; cons/nil are prelude constructors, so the chain is built at elaboration).
(struct expr-list-literal (elems chain) #:transparent)        ; '[e0 e1 …] (non-empty, tree route)
;; CIU T6 F1a.2 p1b-pre (D18): mixed-key map literal, typed ALL-AT-ONCE — keys
;; unify to K, values give the OBSERVED uniform bound ⋃vals (the D15 literal-
;; extent mechanism at the Map domain). The chain is the legacy assoc build
;; (runtime reads only the chain; its metas default at zonk-final).
(struct expr-map-literal (keys vals chain) #:transparent)     ; {k v …} with ≥1 non-keyword key
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
;; expr-schema / expr-schema-type — DELETED (CIU T6 F1b.4d, 2026-07-17). The
;; history: a dormant SECOND schema realization ("named closed validated map"
;; + its type constructor) from a road not taken — sealing was once conceived
;; as WRAPPING the value in a witness node. The shipped realization is the
;; registry + opaque-fvar approach (schema-entry in macros.rkt; the type is a
;; type-only (Type 0) def), and D22 ruled TYPE-AS-WITNESS stands: sealedness
;; is a fact of the typing derivation, values stay uniform champs (a wrapper
;; node would fork the value representation, fight the MLstruct nominality
;; pin, and duplicate fact-carrying the row TYPES already do). The nodes had
;; ZERO producers, were pnet-UNREGISTERED (a latent vector-impostor hazard,
;; pipeline.md rule 6), and their ~30 pipeline identity arms were pure drift
;; surface. Deleted with the full-arm sweep per the expr-Open tombstone
;; pattern (F1a.2 p2).
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
(struct expr-generic-gt (a b) #:transparent)
(struct expr-generic-ge (a b) #:transparent)
(struct expr-generic-eq (a b) #:transparent)
;; Binary modulo: T -> T -> T
(struct expr-generic-mod (a b) #:transparent)
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
;; Track 10 Phase 2a: added source-module + racket-name for .pnet serialization.
;; source-module: string (Racket module path, e.g., "racket/char") or #f
;; racket-name: symbol (binding name in source module, e.g., 'char-upcase) or #f
;; Together: (dynamic-require source-module racket-name) reconstructs proc on deserialize.
(struct expr-foreign-fn (name proc arity args marshal-in marshal-out source-module racket-name) #:transparent)

;; ========================================
;; Type hole (for untyped lambda parameters — filled during checking)
;; ========================================
(struct expr-hole () #:transparent)

;; ========================================
;; expr-Open — DELETED (CIU T6 F1a.2 p2, 2026-07-15). The two-role history:
;; ========================================
;; "Open by Design" (PPN 4C T-2, 2026-04-23) was the universal α-semantic value
;; type for unannotated map literals — absorbing in both directions in
;; check/checkQ/unify. The frontier research (F1 §3b) identified its two
;; formalized roles: (1) Sekiyama–Igarashi's ★ DYNAMIC ROW TAIL — the
;; unify-wildcard absorption WAS the C_ConsL/C_ConsR consistency rules, coarsely
;; rendered (unconditional, not row-scoped, absorbed metas without solving);
;; (2) the polarized-subtyping &{} NEGATIVE TOP (the empty observation set —
;; "nothing has been asked of this value yet"). Both roles RELOCATED into the
;; structural row carrier's 'dyn tail (D7/D16, design doc §12): absorption is
;; row-scoped C_Cons in unify's classifier + the knowns-only pure α; the
;; negative-top reading is the empty dyn row {| _} that bare {} now seeds
;; (D17); unknown-field projection mints a fresh meta (D19) instead of
;; absorbing. Deleted only AFTER the relocation (D1-b) — no deletion before
;; relocation, per the load-bearing annotation-satisfaction chain.

;; ========================================
;; Typed hole (?? or ??name — reports expected type to stderr)
;; ========================================
;; name is #f (unnamed ??) or a symbol (named ??goal)
(struct expr-typed-hole (name) #:transparent)

;; ========================================
;; Metavariable (placeholder to be solved by unification)
;; ========================================
;; PM 8F Phase 1: cell-id field for direct cell access (skips id-map lookup).
;; cell-id is METADATA, not IDENTITY — custom equal?/hash compares only id.
;; cell-id = #f during module loading (no propagator network available).
(struct expr-meta (id cell-id)
  #:transparent
  #:methods gen:equal+hash
  [(define (equal-proc a b _rec)
     (eq? (expr-meta-id a) (expr-meta-id b)))
   (define (hash-proc a _rec)
     (eq-hash-code (expr-meta-id a)))
   (define (hash2-proc a _rec)
     (+ 17 (eq-hash-code (expr-meta-id a))))])

;; ========================================
;; N4: context-typed polymorphic numeric literal (transient).
;; Collapses to a concrete numeric node once its type meta `alpha` resolves
;; (check-mode, from context) or defaults (see num-lit-default-type below).
;; `val` = exact rational; `integral?` = whether val is an integer; `origin` =
;; the NOTATION the literal was written in ('decimal | 'fraction | 'exponent) —
;; N6b: drives the unconstrained default (notation is unrecoverable from the
;; value: 157/50 written as a fraction stays Rat; 3.14 written as a decimal
;; defaults Posit32); `alpha` = a fresh type meta (expr-meta). Never reaches
;; a .pnet cache (collapsed at freeze).
(struct expr-num-lit (val integral? origin alpha) #:transparent)

;; N6b (D-N6.1): the unconstrained-default rule, keyed on notation origin.
;; Lives here (not typing-core/zonk) so all four default sites — typing-core
;; infer, qtt inferQ, zonk default-metas, typing-propagators install — share
;; ONE definition without require cycles.
;;   'decimal  → Posit32  (decimal notation = approximate intent; includes 3.0 —
;;               integral VALUE, decimal NOTATION; context-typing to Int still works)
;;   'fraction → Rat      (intentional fractional use)
;;   'exponent → Int if integral else Posit32 (1e10 stays Int — structurally it
;;               never becomes a num-lit in WS; defensive here — 1.5e-3 → Posit32)
;;   fallback  → old Int/Rat rule (defensive; no producer emits other origins)
(define (num-lit-default-type origin integral?)
  (case origin
    [(decimal)  (expr-Posit32)]
    [(fraction) (expr-Rat)]
    [(exponent) (if integral? (expr-Int) (expr-Posit32))]
    [else       (if integral? (expr-Int) (expr-Rat))]))

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
      (expr-Float32? x) (expr-float32? x) (expr-Float64? x) (expr-float64? x)
      (expr-f32-add? x) (expr-f32-sub? x) (expr-f32-mul? x) (expr-f32-div? x)
      (expr-f32-neg? x) (expr-f32-abs? x) (expr-f32-sqrt? x)
      (expr-f32-lt? x) (expr-f32-le? x) (expr-f32-eq? x)
      (expr-f64-add? x) (expr-f64-sub? x) (expr-f64-mul? x) (expr-f64-div? x)
      (expr-f64-neg? x) (expr-f64-abs? x) (expr-f64-sqrt? x)
      (expr-f64-lt? x) (expr-f64-le? x) (expr-f64-eq? x)
      (expr-float-finite? x) (expr-float-to-rat? x) (expr-float-to-int? x) (expr-float-to-float32? x)
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
      (expr-generic-lt? x) (expr-generic-le? x) (expr-generic-gt? x) (expr-generic-ge? x)
      (expr-generic-eq? x) (expr-generic-mod? x)
      (expr-generic-negate? x) (expr-generic-abs? x)
      (expr-generic-from-int? x) (expr-generic-from-rat? x)
      (expr-Symbol? x) (expr-symbol? x)
      (expr-Keyword? x) (expr-keyword? x)
      (expr-Char? x) (expr-char? x)
      (expr-String? x) (expr-string? x)
      (expr-Record? x)
      (expr-validate? x)
      (expr-select? x)
      (expr-Map? x) (expr-champ? x) (expr-map-empty? x)
      ;; CIU T6 P2.b slice 4: expr-get? was ABSENT here (pipeline.md core item
      ;; 1 unmet — pre-existing, found by the slice-2 audit C25). Fixed.
      (expr-map-assoc? x) (expr-map-get? x) (expr-get? x)
      (expr-nil-safe-get? x) (expr-map-dissoc? x)
      (expr-map-size? x) (expr-map-has-key? x)
      (expr-map-keys? x) (expr-map-vals? x)
      (expr-Set? x) (expr-hset? x) (expr-set-empty? x)
      (expr-set-insert? x) (expr-set-member? x) (expr-set-delete? x)
      (expr-set-size? x) (expr-set-union? x)
      (expr-set-intersect? x) (expr-set-diff? x)
      (expr-set-to-list? x)
      (expr-PVec? x) (expr-rrb? x) (expr-pvec-empty? x)
      (expr-pvec-push? x) (expr-pvec-literal? x) (expr-list-literal? x) (expr-map-literal? x) (expr-pvec-nth? x) (expr-pvec-update? x)
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
      (expr-table-store-type? x) (expr-table-store-val? x)
      (expr-solver-type? x) (expr-goal-type? x) (expr-derivation-type? x)
      (expr-answer-type? x) (expr-relation-type? x)
      (expr-solver-config? x) (expr-cut? x)
      (expr-opaque? x)
      (expr-panic? x)
      (expr-hole? x) (expr-typed-hole? x) (expr-meta? x) (expr-num-lit? x) (expr-reduce? x)
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


;; ============================================================
;; CIU T6 P2.a — generic transparent-struct descent for READ-ONLY
;; containment predicates (pipeline.md § Exhaustive Walkers).
;; ============================================================
;; Applies `pred` to every sub-value of a struct or list spine; non-struct
;; atoms (symbols, numbers, strings, …) are vacuously TRUE. All runtime
;; container internals (champ/rrb/hset tries) are #:transparent, so element
;; descent falls out of the same walk. A predicate using this as its
;; catch-all CANNOT silently skip a node kind — the structural answer to the
;; [_ #t] permissive-tail disease (7+ in-tree instances, all silent).
;; NOTE: read-only — no rebuild, no depth routing; do NOT use this for
;; transforming walkers (those need the binder inventory from shift).
(define (expr-substructs-all? e pred)
  (cond
    ;; pair covers proper lists too (the cdr chain re-enters via pred→fallback)
    [(pair? e) (and (pred (car e)) (pred (cdr e)))]
    ;; champ/rrb tries store entries in raw VECTORS — descend them
    [(vector? e) (for/and ([x (in-vector e)]) (pred x))]
    [(struct? e)
     (let ([v (struct->vector e)])
       (for/and ([i (in-range 1 (vector-length v))])
         (pred (vector-ref v i))))]
    [else #t]))

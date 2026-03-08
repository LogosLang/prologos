#lang racket/base

;;;
;;; PROLOGOS SURFACE SYNTAX
;;; Surface AST with named variables and source locations.
;;; This is the output of the parser, before elaboration to core AST.
;;;

(require "source-location.rkt")

(provide
 ;; Surface expression structs
 (struct-out surf-var)
 (struct-out surf-nat-lit)
 (struct-out surf-zero)
 (struct-out surf-suc)
 (struct-out surf-true)
 (struct-out surf-false)
 (struct-out surf-lam)
 (struct-out surf-app)
 (struct-out surf-pi)
 (struct-out surf-arrow)
 (struct-out surf-sigma)
 (struct-out surf-pair)
 (struct-out surf-fst)
 (struct-out surf-snd)
 (struct-out surf-ann)
 (struct-out surf-refl)
 (struct-out surf-eq)
 (struct-out surf-type)
 (struct-out surf-nat-type)
 (struct-out surf-bool-type)
 (struct-out surf-boolrec)
 (struct-out surf-unit-type)
 (struct-out surf-unit)
 (struct-out surf-nil-type)
 (struct-out surf-nil)
 (struct-out surf-nil-check)
 (struct-out surf-natrec)
 (struct-out surf-J)
 ;; Vec/Fin surface forms
 (struct-out surf-vec-type)
 (struct-out surf-vnil)
 (struct-out surf-vcons)
 (struct-out surf-fin-type)
 (struct-out surf-fzero)
 (struct-out surf-fsuc)
 (struct-out surf-vhead)
 (struct-out surf-vtail)
 (struct-out surf-vindex)
 ;; Int surface forms
 (struct-out surf-int-type)
 (struct-out surf-int-lit)
 (struct-out surf-int-add)
 (struct-out surf-int-sub)
 (struct-out surf-int-mul)
 (struct-out surf-int-div)
 (struct-out surf-int-mod)
 (struct-out surf-int-neg)
 (struct-out surf-int-abs)
 (struct-out surf-int-lt)
 (struct-out surf-int-le)
 (struct-out surf-int-eq)
 (struct-out surf-from-nat)
 ;; Rat surface forms
 (struct-out surf-rat-type)
 (struct-out surf-rat-lit)
 (struct-out surf-rat-add)
 (struct-out surf-rat-sub)
 (struct-out surf-rat-mul)
 (struct-out surf-rat-div)
 (struct-out surf-rat-neg)
 (struct-out surf-rat-abs)
 (struct-out surf-rat-lt)
 (struct-out surf-rat-le)
 (struct-out surf-rat-eq)
 (struct-out surf-from-int)
 (struct-out surf-rat-numer)
 (struct-out surf-rat-denom)
 ;; Generic arithmetic surface forms
 (struct-out surf-generic-add)
 (struct-out surf-generic-sub)
 (struct-out surf-generic-mul)
 (struct-out surf-generic-div)
 (struct-out surf-generic-lt)
 (struct-out surf-generic-le)
 (struct-out surf-generic-eq)
 (struct-out surf-generic-negate)
 (struct-out surf-generic-abs)
 ;; Generic conversion surface forms
 (struct-out surf-generic-from-int)
 (struct-out surf-generic-from-rat)
 ;; Posit8 surface forms
 (struct-out surf-posit8-type)
 (struct-out surf-posit8)
 (struct-out surf-p8-add)
 (struct-out surf-p8-sub)
 (struct-out surf-p8-mul)
 (struct-out surf-p8-div)
 (struct-out surf-p8-neg)
 (struct-out surf-p8-abs)
 (struct-out surf-p8-sqrt)
 (struct-out surf-p8-lt)
 (struct-out surf-p8-le)
 (struct-out surf-p8-eq)
 (struct-out surf-p8-from-nat)
 (struct-out surf-p8-to-rat)
 (struct-out surf-p8-from-rat)
 (struct-out surf-p8-from-int)
 (struct-out surf-p8-if-nar)
 ;; Posit16 surface forms
 (struct-out surf-posit16-type)
 (struct-out surf-posit16)
 (struct-out surf-p16-add)
 (struct-out surf-p16-sub)
 (struct-out surf-p16-mul)
 (struct-out surf-p16-div)
 (struct-out surf-p16-neg)
 (struct-out surf-p16-abs)
 (struct-out surf-p16-sqrt)
 (struct-out surf-p16-lt)
 (struct-out surf-p16-le)
 (struct-out surf-p16-eq)
 (struct-out surf-p16-from-nat)
 (struct-out surf-p16-to-rat)
 (struct-out surf-p16-from-rat)
 (struct-out surf-p16-from-int)
 (struct-out surf-p16-if-nar)
 ;; Posit32 surface forms
 (struct-out surf-posit32-type)
 (struct-out surf-posit32)
 (struct-out surf-p32-add)
 (struct-out surf-p32-sub)
 (struct-out surf-p32-mul)
 (struct-out surf-p32-div)
 (struct-out surf-p32-neg)
 (struct-out surf-p32-abs)
 (struct-out surf-p32-sqrt)
 (struct-out surf-p32-lt)
 (struct-out surf-p32-le)
 (struct-out surf-p32-eq)
 (struct-out surf-p32-from-nat)
 (struct-out surf-p32-to-rat)
 (struct-out surf-p32-from-rat)
 (struct-out surf-p32-from-int)
 (struct-out surf-p32-if-nar)
 ;; Posit64 surface forms
 (struct-out surf-posit64-type)
 (struct-out surf-posit64)
 (struct-out surf-p64-add)
 (struct-out surf-p64-sub)
 (struct-out surf-p64-mul)
 (struct-out surf-p64-div)
 (struct-out surf-p64-neg)
 (struct-out surf-p64-abs)
 (struct-out surf-p64-sqrt)
 (struct-out surf-p64-lt)
 (struct-out surf-p64-le)
 (struct-out surf-p64-eq)
 (struct-out surf-p64-from-nat)
 (struct-out surf-p64-to-rat)
 (struct-out surf-p64-from-rat)
 (struct-out surf-p64-from-int)
 (struct-out surf-p64-if-nar)
 ;; Quire surface forms (exact accumulators)
 (struct-out surf-quire8-type)
 (struct-out surf-quire8-zero)
 (struct-out surf-quire8-fma)
 (struct-out surf-quire8-to)
 (struct-out surf-quire16-type)
 (struct-out surf-quire16-zero)
 (struct-out surf-quire16-fma)
 (struct-out surf-quire16-to)
 (struct-out surf-quire32-type)
 (struct-out surf-quire32-zero)
 (struct-out surf-quire32-fma)
 (struct-out surf-quire32-to)
 (struct-out surf-quire64-type)
 (struct-out surf-quire64-zero)
 (struct-out surf-quire64-fma)
 (struct-out surf-quire64-to)
 ;; Approximate literal (~N)
 (struct-out surf-approx-literal)
 ;; Symbol surface forms
 (struct-out surf-symbol-type)
 (struct-out surf-symbol)
 ;; Keyword surface forms
 (struct-out surf-keyword-type)
 (struct-out surf-keyword)
 ;; Char surface forms
 (struct-out surf-char-type)
 (struct-out surf-char)
 ;; String surface forms
 (struct-out surf-string-type)
 (struct-out surf-string)
 ;; Map surface forms
 (struct-out surf-map-type)
 (struct-out surf-map-literal)
 (struct-out surf-map-empty)
 (struct-out surf-map-assoc)
 (struct-out surf-map-get)
 (struct-out surf-nil-safe-get)
 (struct-out surf-map-dissoc)
 (struct-out surf-map-size)
 (struct-out surf-map-has-key)
 (struct-out surf-map-keys)
 (struct-out surf-map-vals)
 (struct-out surf-get-in)
 (struct-out surf-update-in)
 ;; Set surface forms
 (struct-out surf-set-type)
 (struct-out surf-set-literal)
 (struct-out surf-set-empty)
 (struct-out surf-set-insert)
 (struct-out surf-set-member)
 (struct-out surf-set-delete)
 (struct-out surf-set-size)
 (struct-out surf-set-union)
 (struct-out surf-set-intersect)
 (struct-out surf-set-diff)
 (struct-out surf-set-to-list)
 ;; Persistent Vector (PVec)
 (struct-out surf-pvec-type) (struct-out surf-pvec-literal)
 (struct-out surf-pvec-empty) (struct-out surf-pvec-push)
 (struct-out surf-pvec-nth) (struct-out surf-pvec-update)
 (struct-out surf-pvec-length) (struct-out surf-pvec-pop)
 (struct-out surf-pvec-concat) (struct-out surf-pvec-slice)
 (struct-out surf-pvec-to-list) (struct-out surf-pvec-from-list)
 (struct-out surf-pvec-fold) (struct-out surf-pvec-map) (struct-out surf-pvec-filter)
 (struct-out surf-set-fold) (struct-out surf-set-filter)
 (struct-out surf-map-fold-entries) (struct-out surf-map-filter-entries) (struct-out surf-map-map-vals)
 ;; Transient Builders
 (struct-out surf-transient-type)
 (struct-out surf-transient) (struct-out surf-persist)
 ;; Panic
 (struct-out surf-panic)
 (struct-out surf-tvec-push!) (struct-out surf-tvec-update!)
 (struct-out surf-tmap-assoc!) (struct-out surf-tmap-dissoc!)
 (struct-out surf-tset-insert!) (struct-out surf-tset-delete!)
 ;; PropNetwork (persistent propagator network)
 (struct-out surf-net-type) (struct-out surf-cell-id-type) (struct-out surf-prop-id-type)
 (struct-out surf-net-new) (struct-out surf-net-new-cell) (struct-out surf-net-new-cell-widen)
 (struct-out surf-net-cell-read) (struct-out surf-net-cell-write)
 (struct-out surf-net-add-prop) (struct-out surf-net-run)
 (struct-out surf-net-snapshot) (struct-out surf-net-contradiction)
 ;; UnionFind (persistent disjoint sets)
 (struct-out surf-uf-type) (struct-out surf-uf-empty)
 (struct-out surf-uf-make-set) (struct-out surf-uf-find)
 (struct-out surf-uf-union) (struct-out surf-uf-value)
 ;; ATMS (hypothetical reasoning)
 (struct-out surf-atms-type) (struct-out surf-assumption-id-type)
 (struct-out surf-atms-new) (struct-out surf-atms-assume) (struct-out surf-atms-retract)
 (struct-out surf-atms-nogood) (struct-out surf-atms-amb) (struct-out surf-atms-solve-all)
 (struct-out surf-atms-read) (struct-out surf-atms-write)
 (struct-out surf-atms-consistent) (struct-out surf-atms-worldview)
 ;; Tabling (SLG-style memoization)
 (struct-out surf-table-store-type)
 (struct-out surf-table-new) (struct-out surf-table-register) (struct-out surf-table-add)
 (struct-out surf-table-answers) (struct-out surf-table-freeze) (struct-out surf-table-complete)
 (struct-out surf-table-run) (struct-out surf-table-lookup)
 ;; Relational language (Phase 7)
 (struct-out surf-defr) (struct-out surf-defr-variant) (struct-out surf-rel)
 (struct-out surf-clause) (struct-out surf-facts) (struct-out surf-fact-row)
 (struct-out surf-goal-app) (struct-out surf-unify) (struct-out surf-not) (struct-out surf-is)
 (struct-out surf-solve) (struct-out surf-solve-with)
 (struct-out surf-explain) (struct-out surf-explain-with)
 ;; Narrowing (Phase 1e)
 (struct-out surf-narrow)
 (struct-out surf-schema) (struct-out surf-solver)
 ;; Relational type constructors
 (struct-out surf-solver-type) (struct-out surf-goal-type)
 (struct-out surf-derivation-type) (struct-out surf-answer-type)
 ;; Top-level commands
 (struct-out surf-def)
 (struct-out surf-defn)
 (struct-out surf-check)
 (struct-out surf-eval)
 (struct-out surf-infer)
 ;; Inspection commands
 (struct-out surf-expand)
 (struct-out surf-expand-1)
 (struct-out surf-expand-full)
 (struct-out surf-parse)
 (struct-out surf-elaborate)
 ;; Annotated lambda
 (struct-out surf-the-fn)
 ;; Type hole (inferred)
 (struct-out surf-hole)
 ;; Typed hole (?? or ??name — reports expected type)
 (struct-out surf-typed-hole)
 ;; Numbered placeholder (_1, _2, etc.)
 (struct-out surf-numbered-hole)
 ;; Union type
 (struct-out surf-union)
 ;; Reduce (ML-style pattern matching with type inference)
 (struct-out surf-reduce)
 (struct-out reduce-arm)
 ;; Multi-body defn (case-split by arity)
 (struct-out defn-clause)
 (struct-out surf-defn-multi)
 (struct-out surf-def-group)
 ;; Pattern-based defn clauses
 (struct-out pat-atom)
 (struct-out pat-compound)
 (struct-out pat-head-tail)
 (struct-out defn-pattern-clause)
 ;; Binder info
 (struct-out binder-info)
 ;; Foreign escape block
 (struct-out surf-foreign-block)
 (struct-out surf-subtype)
 ;; Selection declaration
 (struct-out surf-selection)
 ;; Capability declaration
 (struct-out surf-capability)
 ;; Capability inference REPL commands
 (struct-out surf-cap-closure)
 (struct-out surf-cap-audit)
 (struct-out surf-cap-verify)
 (struct-out surf-cap-bridge)
 ;; Session declaration and body nodes (S1)
 (struct-out surf-session)
 (struct-out surf-sess-send)
 (struct-out surf-sess-recv)
 (struct-out surf-sess-dsend)
 (struct-out surf-sess-drecv)
 (struct-out surf-sess-async-send)
 (struct-out surf-sess-async-recv)
 (struct-out surf-sess-choice)
 (struct-out surf-sess-offer)
 (struct-out surf-sess-branch)
 (struct-out surf-sess-rec)
 (struct-out surf-sess-var)
 (struct-out surf-sess-end)
 (struct-out surf-sess-shared)
 (struct-out surf-sess-ref)
 ;; Process declarations and body nodes (S2)
 (struct-out surf-defproc)
 (struct-out surf-proc)
 (struct-out surf-dual)
 (struct-out surf-proc-send)
 (struct-out surf-proc-recv)
 (struct-out surf-proc-select)
 (struct-out surf-proc-offer)
 (struct-out surf-proc-offer-branch)
 (struct-out surf-proc-stop)
 (struct-out surf-proc-new)
 (struct-out surf-proc-par)
 (struct-out surf-proc-link)
 (struct-out surf-proc-rec)
 ;; S5b: Boundary operations
 (struct-out surf-proc-open)
 (struct-out surf-proc-connect)
 (struct-out surf-proc-listen)
 ;; S6: Strategy declaration
 (struct-out surf-strategy)
 ;; S7c: Spawn command
 (struct-out surf-spawn)
 ;; S7d: Spawn-with command
 (struct-out surf-spawn-with))

;; ========================================
;; Type hole (to be inferred by the type checker)
;; ========================================
(struct surf-hole (srcloc) #:transparent)

;; ========================================
;; Typed hole (?? or ??name — reports expected type at check time)
;; ========================================
;; name is #f (unnamed ??) or a symbol (named ??goal)
(struct surf-typed-hole (name srcloc) #:transparent)

;; ========================================
;; Numbered placeholder: _N where N is a positive integer (1-based)
;; Used for positional argument reordering in partial application.
;; ========================================
(struct surf-numbered-hole (index srcloc) #:transparent)

;; ========================================
;; Binder information (for lam, Pi, Sigma)
;; ========================================
(struct binder-info (name mult type) #:transparent)

;; ========================================
;; Surface Expressions
;; ========================================

;; Variables (named, not de Bruijn)
(struct surf-var (name srcloc) #:transparent)

;; Natural number literal (desugars to suc(suc(...zero)))
(struct surf-nat-lit (value srcloc) #:transparent)

;; Nat constants
(struct surf-zero (srcloc) #:transparent)
(struct surf-suc (pred srcloc) #:transparent)

;; Bool constants
(struct surf-true (srcloc) #:transparent)
(struct surf-false (srcloc) #:transparent)

;; Lambda: (lam (x : T) body) or (lam (x :1 T) body)
(struct surf-lam (binder body srcloc) #:transparent)

;; Application: (f a b c) -> multi-arg
(struct surf-app (func args srcloc) #:transparent)

;; Pi type: (Pi (x : T) body)
(struct surf-pi (binder body srcloc) #:transparent)

;; Non-dependent function: (-> A B), with optional multiplicity
;; mult is #f (default unrestricted), 'm0 (erased), 'm1 (linear), or 'mw (unrestricted)
(struct surf-arrow (mult domain codomain srcloc) #:transparent)

;; Sigma type: (Sigma (x : T) body)
(struct surf-sigma (binder body srcloc) #:transparent)

;; Pair: (pair a b)
(struct surf-pair (fst snd srcloc) #:transparent)

;; Projections: (fst e), (snd e)
(struct surf-fst (expr srcloc) #:transparent)
(struct surf-snd (expr srcloc) #:transparent)

;; Type annotation: (the T e)
(struct surf-ann (type term srcloc) #:transparent)

;; Reflexivity: refl
(struct surf-refl (srcloc) #:transparent)

;; Equality type: (Eq A a b)
(struct surf-eq (type lhs rhs srcloc) #:transparent)

;; Universe: (Type n)
(struct surf-type (level srcloc) #:transparent)

;; Nat type: Nat
(struct surf-nat-type (srcloc) #:transparent)

;; Bool type: Bool
(struct surf-bool-type (srcloc) #:transparent)

;; Unit type: Unit
(struct surf-unit-type (srcloc) #:transparent)
(struct surf-unit (srcloc) #:transparent)

;; Nil type: Nil (nullable/nothing)
(struct surf-nil-type (srcloc) #:transparent)
(struct surf-nil (srcloc) #:transparent)
(struct surf-nil-check (arg srcloc) #:transparent)  ; (nil? expr)

;; Bool eliminator: (boolrec motive true-case false-case target)
(struct surf-boolrec (motive true-case false-case target srcloc) #:transparent)

;; Nat eliminator: (natrec motive base step target)
(struct surf-natrec (motive base step target srcloc) #:transparent)

;; J eliminator: (J motive base left right proof)
(struct surf-J (motive base left right proof srcloc) #:transparent)

;; ========================================
;; Vec/Fin surface forms
;; ========================================

;; Vec type: (Vec A n)
(struct surf-vec-type (elem-type length srcloc) #:transparent)

;; vnil: (vnil A)
(struct surf-vnil (type srcloc) #:transparent)

;; vcons: (vcons A n head tail)
(struct surf-vcons (type len head tail srcloc) #:transparent)

;; Fin type: (Fin n)
(struct surf-fin-type (bound srcloc) #:transparent)

;; fzero: (fzero n)
(struct surf-fzero (n srcloc) #:transparent)

;; fsuc: (fsuc n inner)
(struct surf-fsuc (n inner srcloc) #:transparent)

;; vhead: (vhead A n v)
(struct surf-vhead (type len vec srcloc) #:transparent)

;; vtail: (vtail A n v)
(struct surf-vtail (type len vec srcloc) #:transparent)

;; vindex: (vindex A n i v)
(struct surf-vindex (type len idx vec srcloc) #:transparent)

;; ========================================
;; Int surface forms (arbitrary-precision integers)
;; ========================================

;; Int type: Int
(struct surf-int-type (srcloc) #:transparent)

;; Int literal: bare integer (e.g., 42, -5)
(struct surf-int-lit (value srcloc) #:transparent)

;; Binary arithmetic: (int+ a b), (int- a b), (int* a b), (int/ a b), (int-mod a b)
(struct surf-int-add (a b srcloc) #:transparent)
(struct surf-int-sub (a b srcloc) #:transparent)
(struct surf-int-mul (a b srcloc) #:transparent)
(struct surf-int-div (a b srcloc) #:transparent)
(struct surf-int-mod (a b srcloc) #:transparent)

;; Unary ops: (int-neg a), (int-abs a)
(struct surf-int-neg (a srcloc) #:transparent)
(struct surf-int-abs (a srcloc) #:transparent)

;; Comparison: (int< a b), (int<= a b), (int= a b)
(struct surf-int-lt (a b srcloc) #:transparent)
(struct surf-int-le (a b srcloc) #:transparent)
(struct surf-int-eq (a b srcloc) #:transparent)

;; Conversion: (from-nat n)
(struct surf-from-nat (n srcloc) #:transparent)

;; ========================================
;; Rat surface forms (exact rationals)
;; ========================================

;; Rat type: Rat
(struct surf-rat-type (srcloc) #:transparent)

;; Rat literal: bare rational (e.g., 3/7, -1/2)
(struct surf-rat-lit (value srcloc) #:transparent)

;; Binary arithmetic: (rat+ a b), (rat- a b), (rat* a b), (rat/ a b)
(struct surf-rat-add (a b srcloc) #:transparent)
(struct surf-rat-sub (a b srcloc) #:transparent)
(struct surf-rat-mul (a b srcloc) #:transparent)
(struct surf-rat-div (a b srcloc) #:transparent)

;; Unary ops: (rat-neg a), (rat-abs a)
(struct surf-rat-neg (a srcloc) #:transparent)
(struct surf-rat-abs (a srcloc) #:transparent)

;; Comparison: (rat-lt a b), (rat-le a b), (rat-eq a b)
(struct surf-rat-lt (a b srcloc) #:transparent)
(struct surf-rat-le (a b srcloc) #:transparent)
(struct surf-rat-eq (a b srcloc) #:transparent)

;; Conversion: (from-int n)
(struct surf-from-int (n srcloc) #:transparent)

;; Projections: (rat-numer a), (rat-denom a)
(struct surf-rat-numer (a srcloc) #:transparent)
(struct surf-rat-denom (a srcloc) #:transparent)

;; ========================================
;; Generic arithmetic surface forms (type-polymorphic operators)
;; ========================================

;; Binary arithmetic: (+ a b), (- a b), (* a b), (/ a b)
(struct surf-generic-add (a b srcloc) #:transparent)
(struct surf-generic-sub (a b srcloc) #:transparent)
(struct surf-generic-mul (a b srcloc) #:transparent)
(struct surf-generic-div (a b srcloc) #:transparent)

;; Unary ops: (negate a), (abs a)
(struct surf-generic-negate (a srcloc) #:transparent)
(struct surf-generic-abs (a srcloc) #:transparent)

;; Generic conversion: (from-integer TargetType val), (from-rational TargetType val)
(struct surf-generic-from-int (target-type arg srcloc) #:transparent)
(struct surf-generic-from-rat (target-type arg srcloc) #:transparent)

;; Comparison: (< a b), (<= a b), (= a b)
(struct surf-generic-lt (a b srcloc) #:transparent)
(struct surf-generic-le (a b srcloc) #:transparent)
(struct surf-generic-eq (a b srcloc) #:transparent)

;; ========================================
;; Posit8 surface forms (8-bit posit, es=2, 2022 Standard)
;; ========================================

;; Posit8 type: Posit8
(struct surf-posit8-type (srcloc) #:transparent)

;; Posit8 literal: (posit8 <integer>)
(struct surf-posit8 (val srcloc) #:transparent)

;; Binary arithmetic: (p8+ a b), (p8- a b), (p8* a b), (p8/ a b)
(struct surf-p8-add (a b srcloc) #:transparent)
(struct surf-p8-sub (a b srcloc) #:transparent)
(struct surf-p8-mul (a b srcloc) #:transparent)
(struct surf-p8-div (a b srcloc) #:transparent)

;; Unary ops: (p8-neg a), (p8-abs a), (p8-sqrt a)
(struct surf-p8-neg (a srcloc) #:transparent)
(struct surf-p8-abs (a srcloc) #:transparent)
(struct surf-p8-sqrt (a srcloc) #:transparent)

;; Comparison: (p8< a b), (p8<= a b)
(struct surf-p8-lt (a b srcloc) #:transparent)
(struct surf-p8-le (a b srcloc) #:transparent)
(struct surf-p8-eq (a b srcloc) #:transparent)

;; Conversion: (p8-from-nat n)
(struct surf-p8-from-nat (n srcloc) #:transparent)

;; Cross-family conversions
(struct surf-p8-to-rat (a srcloc) #:transparent)
(struct surf-p8-from-rat (a srcloc) #:transparent)
(struct surf-p8-from-int (a srcloc) #:transparent)

;; Eliminator: (p8-if-nar A nar-case normal-case val)
(struct surf-p8-if-nar (type nar-case normal-case val srcloc) #:transparent)

;; ========================================
;; Posit16 surface forms (16-bit posit, es=2, 2022 Standard)
;; ========================================

;; Posit16 type: Posit16
(struct surf-posit16-type (srcloc) #:transparent)

;; Posit16 literal: (posit16 <integer>)
(struct surf-posit16 (val srcloc) #:transparent)

;; Binary arithmetic: (p16+ a b), (p16- a b), (p16* a b), (p16/ a b)
(struct surf-p16-add (a b srcloc) #:transparent)
(struct surf-p16-sub (a b srcloc) #:transparent)
(struct surf-p16-mul (a b srcloc) #:transparent)
(struct surf-p16-div (a b srcloc) #:transparent)

;; Unary ops: (p16-neg a), (p16-abs a), (p16-sqrt a)
(struct surf-p16-neg (a srcloc) #:transparent)
(struct surf-p16-abs (a srcloc) #:transparent)
(struct surf-p16-sqrt (a srcloc) #:transparent)

;; Comparison: (p16< a b), (p16<= a b)
(struct surf-p16-lt (a b srcloc) #:transparent)
(struct surf-p16-le (a b srcloc) #:transparent)
(struct surf-p16-eq (a b srcloc) #:transparent)

;; Conversion: (p16-from-nat n)
(struct surf-p16-from-nat (n srcloc) #:transparent)

;; Cross-family conversions
(struct surf-p16-to-rat (a srcloc) #:transparent)
(struct surf-p16-from-rat (a srcloc) #:transparent)
(struct surf-p16-from-int (a srcloc) #:transparent)

;; Eliminator: (p16-if-nar A nar-case normal-case val)
(struct surf-p16-if-nar (type nar-case normal-case val srcloc) #:transparent)

;; ========================================
;; Posit32 surface forms (32-bit posit, es=2, 2022 Standard)
;; ========================================

;; Posit32 type: Posit32
(struct surf-posit32-type (srcloc) #:transparent)

;; Posit32 literal: (posit32 <integer>)
(struct surf-posit32 (val srcloc) #:transparent)

;; Binary arithmetic: (p32+ a b), (p32- a b), (p32* a b), (p32/ a b)
(struct surf-p32-add (a b srcloc) #:transparent)
(struct surf-p32-sub (a b srcloc) #:transparent)
(struct surf-p32-mul (a b srcloc) #:transparent)
(struct surf-p32-div (a b srcloc) #:transparent)

;; Unary ops: (p32-neg a), (p32-abs a), (p32-sqrt a)
(struct surf-p32-neg (a srcloc) #:transparent)
(struct surf-p32-abs (a srcloc) #:transparent)
(struct surf-p32-sqrt (a srcloc) #:transparent)

;; Comparison: (p32< a b), (p32<= a b)
(struct surf-p32-lt (a b srcloc) #:transparent)
(struct surf-p32-le (a b srcloc) #:transparent)
(struct surf-p32-eq (a b srcloc) #:transparent)

;; Conversion: (p32-from-nat n)
(struct surf-p32-from-nat (n srcloc) #:transparent)

;; Cross-family conversions
(struct surf-p32-to-rat (a srcloc) #:transparent)
(struct surf-p32-from-rat (a srcloc) #:transparent)
(struct surf-p32-from-int (a srcloc) #:transparent)

;; Eliminator: (p32-if-nar A nar-case normal-case val)
(struct surf-p32-if-nar (type nar-case normal-case val srcloc) #:transparent)

;; ========================================
;; Posit64 surface forms (64-bit posit, es=2, 2022 Standard)
;; ========================================

;; Posit64 type: Posit64
(struct surf-posit64-type (srcloc) #:transparent)

;; Posit64 literal: (posit64 <integer>)
(struct surf-posit64 (val srcloc) #:transparent)

;; Binary arithmetic: (p64+ a b), (p64- a b), (p64* a b), (p64/ a b)
(struct surf-p64-add (a b srcloc) #:transparent)
(struct surf-p64-sub (a b srcloc) #:transparent)
(struct surf-p64-mul (a b srcloc) #:transparent)
(struct surf-p64-div (a b srcloc) #:transparent)

;; Unary ops: (p64-neg a), (p64-abs a), (p64-sqrt a)
(struct surf-p64-neg (a srcloc) #:transparent)
(struct surf-p64-abs (a srcloc) #:transparent)
(struct surf-p64-sqrt (a srcloc) #:transparent)

;; Comparison: (p64< a b), (p64<= a b)
(struct surf-p64-lt (a b srcloc) #:transparent)
(struct surf-p64-le (a b srcloc) #:transparent)
(struct surf-p64-eq (a b srcloc) #:transparent)

;; Conversion: (p64-from-nat n)
(struct surf-p64-from-nat (n srcloc) #:transparent)

;; Cross-family conversions
(struct surf-p64-to-rat (a srcloc) #:transparent)
(struct surf-p64-from-rat (a srcloc) #:transparent)
(struct surf-p64-from-int (a srcloc) #:transparent)

;; Eliminator: (p64-if-nar A nar-case normal-case val)
(struct surf-p64-if-nar (type nar-case normal-case val srcloc) #:transparent)

;; ========================================
;; Quire surface forms (exact accumulators for posit arithmetic)
;; ========================================

;; Quire8
(struct surf-quire8-type (srcloc) #:transparent)
(struct surf-quire8-zero (srcloc) #:transparent)
(struct surf-quire8-fma (q a b srcloc) #:transparent)
(struct surf-quire8-to (q srcloc) #:transparent)

;; Quire16
(struct surf-quire16-type (srcloc) #:transparent)
(struct surf-quire16-zero (srcloc) #:transparent)
(struct surf-quire16-fma (q a b srcloc) #:transparent)
(struct surf-quire16-to (q srcloc) #:transparent)

;; Quire32
(struct surf-quire32-type (srcloc) #:transparent)
(struct surf-quire32-zero (srcloc) #:transparent)
(struct surf-quire32-fma (q a b srcloc) #:transparent)
(struct surf-quire32-to (q srcloc) #:transparent)

;; Quire64
(struct surf-quire64-type (srcloc) #:transparent)
(struct surf-quire64-zero (srcloc) #:transparent)
(struct surf-quire64-fma (q a b srcloc) #:transparent)
(struct surf-quire64-to (q srcloc) #:transparent)

;; Approximate literal: ~N → nearest Posit32 (default), width-aware in check context
;; val is an exact rational (integer or fraction)
(struct surf-approx-literal (val srcloc) #:transparent)

;; ========================================
;; Symbol type and literal (for code-as-data)
;; ========================================
(struct surf-symbol-type (srcloc) #:transparent)           ; Symbol type
(struct surf-symbol (name srcloc) #:transparent)           ; symbol literal, name is a Racket symbol

;; ========================================
;; Keyword type and literal
;; ========================================
(struct surf-keyword-type (srcloc) #:transparent)          ; Keyword type
(struct surf-keyword (name srcloc) #:transparent)          ; keyword literal, name is a symbol

;; ========================================
;; Char type and literal
;; ========================================
(struct surf-char-type (srcloc) #:transparent)              ; Char type
(struct surf-char (val srcloc) #:transparent)               ; char literal, val is a Racket char

;; ========================================
;; String type and literal
;; ========================================
(struct surf-string-type (srcloc) #:transparent)            ; String type
(struct surf-string (val srcloc) #:transparent)             ; string literal, val is a Racket string

;; ========================================
;; Map (CHAMP-backed persistent hash map)
;; ========================================
(struct surf-map-type (k v srcloc) #:transparent)          ; Map K V type
(struct surf-map-literal (entries srcloc) #:transparent)   ; {k1 v1, k2 v2, ...} — entries is list of (key . val) pairs
(struct surf-map-empty (k v srcloc) #:transparent)         ; (map-empty K V)
(struct surf-map-assoc (m k v srcloc) #:transparent)       ; (map-assoc m k v)
(struct surf-map-get (m k srcloc) #:transparent)           ; (map-get m k)
(struct surf-nil-safe-get (m k srcloc) #:transparent)      ; (nil-safe-get m k)
(struct surf-map-dissoc (m k srcloc) #:transparent)        ; (map-dissoc m k)
(struct surf-map-size (m srcloc) #:transparent)            ; (map-size m)
(struct surf-map-has-key (m k srcloc) #:transparent)       ; (map-has-key m k)
(struct surf-map-keys (m srcloc) #:transparent)            ; (map-keys m)
(struct surf-map-vals (m srcloc) #:transparent)            ; (map-vals m)
(struct surf-get-in (target paths srcloc) #:transparent)   ; (get-in target path-spec) — paths is list of parsed paths
(struct surf-update-in (target paths fn-expr srcloc) #:transparent) ; (update-in target path-spec fn)

;; ========================================
;; Set (CHAMP-backed persistent hash set)
;; ========================================
(struct surf-set-type (elem srcloc) #:transparent)           ; Set A type
(struct surf-set-literal (elems srcloc) #:transparent)       ; #{e1 e2 ...} — elems is a list of parsed surface exprs
(struct surf-set-empty (elem srcloc) #:transparent)          ; (set-empty A)
(struct surf-set-insert (s a srcloc) #:transparent)          ; (set-insert s a)
(struct surf-set-member (s a srcloc) #:transparent)          ; (set-member? s a)
(struct surf-set-delete (s a srcloc) #:transparent)          ; (set-delete s a)
(struct surf-set-size (s srcloc) #:transparent)              ; (set-size s)
(struct surf-set-union (s1 s2 srcloc) #:transparent)         ; (set-union s1 s2)
(struct surf-set-intersect (s1 s2 srcloc) #:transparent)     ; (set-intersect s1 s2)
(struct surf-set-diff (s1 s2 srcloc) #:transparent)          ; (set-diff s1 s2)
(struct surf-set-to-list (s srcloc) #:transparent)           ; (set-to-list s)

;; ========================================
;; Persistent Vector (PVec)
;; ========================================
(struct surf-pvec-type (elem srcloc) #:transparent)          ; PVec A type
(struct surf-pvec-literal (elems srcloc) #:transparent)      ; @[e1 e2 ...] literal — elems is a list of parsed surface exprs
(struct surf-pvec-empty (elem-type srcloc) #:transparent)    ; (pvec-empty A)
(struct surf-pvec-push (v x srcloc) #:transparent)           ; (pvec-push v x)
(struct surf-pvec-nth (v i srcloc) #:transparent)            ; (pvec-nth v i)
(struct surf-pvec-update (v i x srcloc) #:transparent)       ; (pvec-update v i x)
(struct surf-pvec-length (v srcloc) #:transparent)           ; (pvec-length v)
(struct surf-pvec-pop (v srcloc) #:transparent)              ; (pvec-pop v)
(struct surf-pvec-concat (v1 v2 srcloc) #:transparent)       ; (pvec-concat v1 v2)
(struct surf-pvec-slice (v lo hi srcloc) #:transparent)      ; (pvec-slice v lo hi)
(struct surf-pvec-to-list (v srcloc) #:transparent)          ; (pvec-to-list v)
(struct surf-pvec-from-list (v srcloc) #:transparent)        ; (pvec-from-list v)
(struct surf-pvec-fold (f init vec srcloc) #:transparent)    ; (pvec-fold f init vec)
(struct surf-pvec-map (f vec srcloc) #:transparent)          ; (pvec-map f vec)
(struct surf-pvec-filter (pred vec srcloc) #:transparent)    ; (pvec-filter pred vec)
(struct surf-set-fold (f init set srcloc) #:transparent)     ; (set-fold f init set)
(struct surf-set-filter (pred set srcloc) #:transparent)     ; (set-filter pred set)
(struct surf-map-fold-entries (f init map srcloc) #:transparent)   ; (map-fold-entries f init map)
(struct surf-map-filter-entries (pred map srcloc) #:transparent)   ; (map-filter-entries pred map)
(struct surf-map-map-vals (f map srcloc) #:transparent)      ; (map-map-vals f map)

;; ---- Transient Builders ----
(struct surf-transient-type (kind args srcloc) #:transparent) ; (TVec A), (TMap K V), (TSet A) — kind is 'TVec/'TMap/'TSet
(struct surf-transient    (coll srcloc) #:transparent)       ; (transient coll) — generic, dispatch on collection type
(struct surf-persist      (coll srcloc) #:transparent)       ; (persist! coll) — generic, dispatch on transient type
(struct surf-tvec-push!   (t x srcloc) #:transparent)        ; (tvec-push! t x)
(struct surf-tvec-update! (t i x srcloc) #:transparent)      ; (tvec-update! t i x)
(struct surf-tmap-assoc!  (t k v srcloc) #:transparent)      ; (tmap-assoc! t k v)
(struct surf-tmap-dissoc! (t k srcloc) #:transparent)        ; (tmap-dissoc! t k)
(struct surf-tset-insert! (t a srcloc) #:transparent)        ; (tset-insert! t a)
(struct surf-tset-delete! (t a srcloc) #:transparent)        ; (tset-delete! t a)

;; ---- Panic ----
(struct surf-panic (msg srcloc) #:transparent)               ; (panic msg)

;; ---- PropNetwork (persistent propagator network) ----
(struct surf-net-type         (srcloc) #:transparent)                  ; PropNetwork
(struct surf-cell-id-type     (srcloc) #:transparent)                  ; CellId
(struct surf-prop-id-type     (srcloc) #:transparent)                  ; PropId
(struct surf-net-new          (fuel srcloc) #:transparent)             ; (net-new fuel)
(struct surf-net-new-cell     (net init merge srcloc) #:transparent)   ; (net-new-cell net init merge)
(struct surf-net-new-cell-widen (net init merge widen-fn narrow-fn srcloc) #:transparent) ; (net-new-cell-widen net init merge widen narrow)
(struct surf-net-cell-read    (net cell srcloc) #:transparent)         ; (net-cell-read net cell)
(struct surf-net-cell-write   (net cell val srcloc) #:transparent)     ; (net-cell-write net cell val)
(struct surf-net-add-prop     (net ins outs fn srcloc) #:transparent)  ; (net-add-prop net ins outs fn)
(struct surf-net-run          (net srcloc) #:transparent)              ; (net-run net)
(struct surf-net-snapshot     (net srcloc) #:transparent)              ; (net-snapshot net)
(struct surf-net-contradiction (net srcloc) #:transparent)             ; (net-contradict? net)

;; ---- UnionFind (persistent disjoint sets) ----
(struct surf-uf-type      (srcloc) #:transparent)                      ; UnionFind
(struct surf-uf-empty     (srcloc) #:transparent)                      ; (uf-empty)
(struct surf-uf-make-set  (store id val srcloc) #:transparent)         ; (uf-make-set store id val)
(struct surf-uf-find      (store id srcloc) #:transparent)             ; (uf-find store id)
(struct surf-uf-union     (store id1 id2 srcloc) #:transparent)        ; (uf-union store id1 id2)
(struct surf-uf-value     (store id srcloc) #:transparent)             ; (uf-value store id)

;; ---- ATMS (hypothetical reasoning) ----
(struct surf-atms-type          (srcloc) #:transparent)                       ; ATMS
(struct surf-assumption-id-type (srcloc) #:transparent)                       ; AssumptionId
(struct surf-atms-new           (network srcloc) #:transparent)               ; (atms-new net)
(struct surf-atms-assume        (atms name datum srcloc) #:transparent)       ; (atms-assume atms name datum)
(struct surf-atms-retract       (atms aid srcloc) #:transparent)              ; (atms-retract atms aid)
(struct surf-atms-nogood        (atms aids srcloc) #:transparent)             ; (atms-nogood atms aids)
(struct surf-atms-amb           (atms alternatives srcloc) #:transparent)     ; (atms-amb atms alts)
(struct surf-atms-solve-all     (atms goal srcloc) #:transparent)             ; (atms-solve-all atms goal)
(struct surf-atms-read          (atms cell srcloc) #:transparent)             ; (atms-read atms cell)
(struct surf-atms-write         (atms cell val support srcloc) #:transparent) ; (atms-write atms cell val support)
(struct surf-atms-consistent    (atms aids srcloc) #:transparent)             ; (atms-consistent? atms aids)
(struct surf-atms-worldview     (atms aids srcloc) #:transparent)             ; (atms-worldview atms aids)

;; ---- Tabling (SLG-style memoization) ----
(struct surf-table-store-type   (srcloc) #:transparent)                       ; TableStore
(struct surf-table-new          (network srcloc) #:transparent)               ; (table-new net)
(struct surf-table-register     (store name mode srcloc) #:transparent)       ; (table-register store name mode)
(struct surf-table-add          (store name answer srcloc) #:transparent)     ; (table-add store name answer)
(struct surf-table-answers      (store name srcloc) #:transparent)            ; (table-answers store name)
(struct surf-table-freeze       (store name srcloc) #:transparent)            ; (table-freeze store name)
(struct surf-table-complete     (store name srcloc) #:transparent)            ; (table-complete? store name)
(struct surf-table-run          (store srcloc) #:transparent)                 ; (table-run store)
(struct surf-table-lookup       (store name answer srcloc) #:transparent)     ; (table-lookup store name answer)

;; ---- Relational language (Phase 7) ----

;; Named relation: (defr name [params] body) or (defr name | [...] body | [...] body)
;; name: symbol, schema: surf-expr or #f, variants: (listof surf-defr-variant)
(struct surf-defr             (name schema variants srcloc) #:transparent)
;; Single arity/pattern variant: | [params] body
(struct surf-defr-variant     (params body srcloc) #:transparent)
;; Anonymous relation: (rel [params] body)
(struct surf-rel              (params clauses srcloc) #:transparent)
;; Rule clause: &> goal1 goal2 ...
(struct surf-clause           (goals srcloc) #:transparent)
;; Fact block: || term1 term2 \n term3 term4 ...
(struct surf-facts            (rows srcloc) #:transparent)
;; Single fact row
(struct surf-fact-row         (terms srcloc) #:transparent)
;; Relational goal application: (name arg ...)
(struct surf-goal-app         (name args srcloc) #:transparent)
;; Unification goal: (= lhs rhs)
(struct surf-unify            (lhs rhs srcloc) #:transparent)
;; Negation-as-failure: (not goal)
(struct surf-not              (goal srcloc) #:transparent)
;; Functional eval in relation: (is var [expr])
(struct surf-is               (var expr srcloc) #:transparent)
;; Solve: (solve (goal))
(struct surf-solve            (goal srcloc) #:transparent)
;; Solve-with: (solve-with solver {overrides} (goal))
(struct surf-solve-with       (solver overrides goal srcloc) #:transparent)
;; Explain: (explain (goal))
(struct surf-explain          (goal srcloc) #:transparent)
;; Explain-with: (explain-with solver {overrides} (goal))
(struct surf-explain-with     (solver overrides goal srcloc) #:transparent)
;; Narrowing expression: [f ?x ?y] = target (functional context unification)
;; lhs: surf-expr (the functional expression with ?-variables)
;; rhs: surf-expr (the target value)
;; vars: (listof symbol) — the ?-prefixed variables found in lhs/rhs
(struct surf-narrow           (lhs rhs vars srcloc) #:transparent)
;; Schema: schema name :field Type ...
(struct surf-schema           (name fields srcloc) #:transparent)
;; Solver: solver name :key val ...
(struct surf-solver           (name options srcloc) #:transparent)

;; ---- Relational type constructors ----
(struct surf-solver-type      (srcloc) #:transparent)          ; Solver
(struct surf-goal-type        (srcloc) #:transparent)          ; Goal
(struct surf-derivation-type  (srcloc) #:transparent)          ; DerivationTree
(struct surf-answer-type      (val-type srcloc) #:transparent) ; (Answer V) — val-type is surf-expr or #f

;; ========================================
;; Top-level commands
;; ========================================

;; Definition: (def name : type body)
(struct surf-def (name type body srcloc) #:transparent)

;; Sugared definition: (defn name : type [params...] body)
;; Desugars to (def name : type (fn ...nested lambdas... body))
(struct surf-defn (name type param-names body srcloc) #:transparent)

;; Type check: (check expr : type)
(struct surf-check (expr type srcloc) #:transparent)

;; Evaluate: (eval expr)
(struct surf-eval (expr srcloc) #:transparent)

;; Infer type: (infer expr)
(struct surf-infer (expr srcloc) #:transparent)

;; Inspection: (expand form) — show preparse macro expansion
(struct surf-expand (datum srcloc) #:transparent)

;; Inspection: (parse form) — show parsed surface AST
(struct surf-parse (expr srcloc) #:transparent)

;; Inspection: (elaborate form) — show elaborated core AST
(struct surf-elaborate (expr srcloc) #:transparent)

;; Inspection: (expand-1 form) — show single preparse expansion step
(struct surf-expand-1 (datum srcloc) #:transparent)

;; Inspection: (expand-full form) — show all preparse transforms with labels
(struct surf-expand-full (datum srcloc) #:transparent)

;; Annotated lambda: (the-fn type [params...] body)
;; Desugars to (the type (fn (p1:T1) (fn (p2:T2) ... body)))
(struct surf-the-fn (type param-names body srcloc) #:transparent)

;; ========================================
;; Union type: A | B
;; ========================================
;; Represents a union type at the surface level.
;; Parsed from infix `|` in type position (e.g., Nat | Bool, A | B | C).
(struct surf-union (left right srcloc) #:transparent)

;; ========================================
;; Reduce: ML-style pattern matching with type inference
;; ========================================
;; reduce scrutinee | ctor1 bindings -> body1 | ctor2 bindings -> body2 ...
;; Result type is inferred from the checking context.

;; reduce-arm: constructor name, list of binding names (symbols), body (surf expr)
(struct reduce-arm (ctor-name bindings body srcloc) #:transparent)

;; reduce: scrutinee (surf expr), list of reduce-arms
(struct surf-reduce (scrutinee arms srcloc) #:transparent)

;; ========================================
;; Multi-body defn: case-split by arity
;; ========================================
;; Each clause has its own parameter list, return type, and body.
;; Compile-time dispatch selects the clause matching the argument count.

;; A single clause of a multi-body defn
(struct defn-clause (type param-names body srcloc) #:transparent)

;; Multi-body defn: name, optional docstring, list of clauses
(struct surf-defn-multi (name docstring clauses srcloc) #:transparent)

;; Group of surf-defs produced by expanding a multi-body defn
;; name: base name (symbol), defs: list of surf-def, arities: sorted list of int,
;; docstring: (or/c string? #f)
(struct surf-def-group (name defs arities docstring srcloc) #:transparent)

;; ========================================
;; Pattern AST: for pattern-matching defn clauses and head-tail patterns
;; ========================================
;; Parsed pattern elements used in pattern-based defn clauses.
;; Patterns are structural — no constructor registry lookup at parse time.

;; Atomic pattern: variable, wildcard, or numeric literal
;; kind: 'var | 'wildcard | 'numeric
;; name: symbol (var name, ctor name, or '_ for wildcard)
;; value: #f for var/wildcard, integer for numeric
(struct pat-atom (kind name value srcloc) #:transparent)

;; Compound pattern: constructor applied to sub-patterns
;; ctor-name: symbol; args: list of pattern
(struct pat-compound (ctor-name args srcloc) #:transparent)

;; Head-tail list pattern: [a b | rest]
;; heads: list of pattern; tail: pattern
(struct pat-head-tail (heads tail srcloc) #:transparent)

;; Pattern-based clause of a multi-body defn
;; patterns: list of pattern (one per argument position)
;; body: surface expression
(struct defn-pattern-clause (patterns body srcloc) #:transparent)

;; ========================================
;; Foreign escape block
;; ========================================
;; Inline Racket code with explicit capture/export lists.
;; lang: symbol (currently always 'racket)
;; code-datums: list of raw Racket S-expression datums (the code inside {})
;; captures: list of (list name type-surf) — Prologos values captured from scope
;; return-type: surface type expression for the return value
(struct surf-foreign-block (lang code-datums captures return-type srcloc) #:transparent)

;; ========================================
;; Phase E: Subtype declaration
;; ========================================
;; (subtype PosInt Int) or (subtype Zero Int via zero-to-int)
;; sub-type, super-type: symbols (type names)
;; via-fn: symbol or #f (explicit coercion function, or auto-infer from ctor)
(struct surf-subtype (sub-type super-type via-fn srcloc) #:transparent)

;; ========================================
;; Selection declaration
;; ========================================
;; (selection Name from Schema :requires [...] :provides [...] :includes [...])
;; name: symbol (selection type name)
;; schema-name: symbol (the schema this selects from)
;; requires-paths: list of keywords or path-exprs (fields caller must provide)
;; provides-paths: list of keywords or path-exprs (fields function guarantees)
;; includes-names: list of symbols (other selections to include via set union)
(struct surf-selection (name schema-name requires-paths provides-paths includes-names srcloc) #:transparent)

;; ========================================
;; Capability declaration
;; ========================================
;; (capability ReadCap) — zero-argument capability type declaration
;; (capability FileCap (p : Path)) — dependent capability (Phase 7, reserved)
;; name: symbol (capability type name)
;; params: list of (list name type-datum) or '() for nullary capabilities
(struct surf-capability (name params srcloc) #:transparent)

;; ========================================
;; Capability inference REPL commands (Phase 5)
;; ========================================
;; (cap-closure name) — show transitive capability closure for a function
(struct surf-cap-closure (name srcloc) #:transparent)
;; (cap-audit name cap-name) — show provenance trail for why a function requires a capability
(struct surf-cap-audit (name cap-name srcloc) #:transparent)
;; (cap-verify name) — verify authority root: declared caps subsume inferred closure
(struct surf-cap-verify (name srcloc) #:transparent)
;; (cap-bridge name) — cross-domain bridge analysis: type ↔ capability with overdeclared detection
(struct surf-cap-bridge (name srcloc) #:transparent)

;; ========================================
;; Session type declaration (Phase S1)
;; ========================================
;; (session Name metadata body) — top-level session type declaration
;; name: symbol, metadata: assoc list of keyword options (:doc, :deprecated, :throws), body: surf-sess-* tree
(struct surf-session (name metadata body srcloc) #:transparent)
;; Session body nodes — right-nested continuation-passing structure
(struct surf-sess-send   (type cont srcloc) #:transparent)       ; ! Type . cont
(struct surf-sess-recv   (type cont srcloc) #:transparent)       ; ? Type . cont
(struct surf-sess-dsend  (name type cont srcloc) #:transparent)  ; !: name Type . cont
(struct surf-sess-drecv  (name type cont srcloc) #:transparent)  ; ?: name Type . cont
(struct surf-sess-async-send (type cont srcloc) #:transparent)   ; !! Type . cont (non-blocking send)
(struct surf-sess-async-recv (type cont srcloc) #:transparent)   ; ?? Type . cont (non-blocking recv)
(struct surf-sess-choice (branches srcloc) #:transparent)        ; +> with branch list
(struct surf-sess-offer  (branches srcloc) #:transparent)        ; &> with branch list
(struct surf-sess-branch (label cont srcloc) #:transparent)      ; | :label -> cont
(struct surf-sess-rec    (label body srcloc) #:transparent)      ; rec (label=#f for anonymous)
(struct surf-sess-var    (name srcloc) #:transparent)            ; recursion variable reference
(struct surf-sess-end    (srcloc) #:transparent)                 ; end
(struct surf-sess-shared (body srcloc) #:transparent)            ; shared session
(struct surf-sess-ref    (name srcloc) #:transparent)            ; named session reference

;; ========================================
;; Process declarations (Phase S2)
;; ========================================
;; (defproc Name : SessionType body) — named process definition
;; channels: list of (name . session-type) for multi-channel form, or '() for single-channel
;; caps: list of capability binders, or '()
(struct surf-defproc (name session-type channels caps body srcloc) #:transparent)
;; (proc : SessionType body) — anonymous process
(struct surf-proc    (session-type channels caps body srcloc) #:transparent)
;; (dual SessionRef) — dual of a named session type
(struct surf-dual    (session-ref srcloc) #:transparent)
;; Process body nodes — right-nested continuation-passing structure
(struct surf-proc-send    (chan expr cont srcloc) #:transparent)   ; chan ! expr
(struct surf-proc-recv    (var chan cont srcloc) #:transparent)    ; var := chan ?
(struct surf-proc-select  (chan label cont srcloc) #:transparent)  ; select chan :label
(struct surf-proc-offer   (chan branches srcloc) #:transparent)    ; offer chan | ...
(struct surf-proc-offer-branch (label body srcloc) #:transparent) ; | :label -> body
(struct surf-proc-stop    (srcloc) #:transparent)                 ; stop
(struct surf-proc-new     (channels session-type body srcloc) #:transparent) ; new [c1 c2] : S
(struct surf-proc-par     (left right srcloc) #:transparent)      ; par P1 P2
(struct surf-proc-link    (chan1 chan2 srcloc) #:transparent)      ; link c1 c2
(struct surf-proc-rec     (label srcloc) #:transparent)           ; rec (tail recursion)
;; Phase S5b: Boundary operations — capability-gated channel creation
(struct surf-proc-open    (path session-type cap cont srcloc) #:transparent)    ; open path : S {cap}
(struct surf-proc-connect (addr session-type cap cont srcloc) #:transparent)    ; connect addr : S {cap}
(struct surf-proc-listen  (port session-type cap cont srcloc) #:transparent)    ; listen port : S {cap}
;; Phase S6: Strategy declaration
;; name: symbol, properties: assoc list of (cons keyword datum), srcloc: source location
(struct surf-strategy (name properties srcloc) #:transparent)
;; Phase S7c: Spawn command — execute a process
;; target: symbol (named process ref) or surf-proc (anonymous process)
;; strategy: symbol or #f (S7d: strategy application)
(struct surf-spawn (target strategy srcloc) #:transparent)
;; Phase S7d: Spawn-with command — execute a process with strategy
;; strategy: symbol — named strategy reference, or #f (use defaults)
;; overrides: list of (key val ...) or #f — inline property overrides
;; target: surf-var (named process ref) or surf-proc (anonymous process)
(struct surf-spawn-with (strategy overrides target srcloc) #:transparent)

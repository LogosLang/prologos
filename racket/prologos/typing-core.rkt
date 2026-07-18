#lang racket/base

;;;
;;; PROLOGOS TYPING-CORE
;;; Bidirectional type checker for the core dependent type theory.
;;; Direct translation of prologos-typing-core.maude + prologos-inductive.maude typing rules.
;;;
;;; infer(ctx, e)       -> Expr       : synthesize a type (or expr-error)
;;; check(ctx, e, T)    -> Bool       : check that e has type T
;;; is-type(ctx, T)     -> Bool       : verify T is a well-formed type
;;; infer-level(ctx, T) -> MaybeLevel : infer the universe level of type T
;;;
;;; IMPORTANT: When looking up bvar(K) in the context, the stored type
;;; must be shifted by (K+1) because it was stored relative to the context
;;; above position K, but we need it relative to the current scope.
;;;

(require racket/match
         racket/string

         "prelude.rkt"
         "syntax.rkt"
         "substitution.rkt"
         "reduction.rkt"
         "unify.rkt"
         "performance-counters.rkt"
         "global-env.rkt"
         "macros.rkt"
         "namespace.rkt"
         "metavar-store.rkt"
         "elab-speculation-bridge.rkt"
         "warnings.rkt"
         "pretty-print.rkt"
         "subtype-predicate.rkt"  ;; SRE Track 1: extracted flat subtype predicate
         "sign-refinement.rkt"    ;; Numerics N5c: Sign transfer + name<->Sign/base tables
)

(provide infer check is-type infer-level
         (struct-out no-level) (struct-out just-level)
         mark-structural-reduce! structural-reduce? structural-reduce-set
         subtype? type-key
         list-type-fvar
         concrete-numeric-type? divisible-numeric-type? negatable-numeric-type?
         from-int-target-type? from-rat-target-type? num-lit-representable?
         numeric-join exact-numeric-type? posit-type?
         numeric-type-name bare-exact-literal?  ;; N6a: warning policy + text normalization
         base-numeric-type refine-arith refine-arith1
         ;; Schema type helpers
         schema-field-type->expr
         field-type->witness-tag
         schema-lookup-field
         record-<:-map?
         record-<:-pvec?         ;; CIU T6 F1a-col: Tuple→PVec α (meta-aware)
         record-<:-elem?         ;; CIU T6 F1a-col-2: shared elem-side α core (PVec/List)
         record-value-union      ;; CIU T6 F1 (s3): ⋃fields uniform view (qtt mirrors consume it)
         record-value-bound      ;; CIU T6 F1a.2 p1a: dyn-aware value bound (⋃knowns ∪ fresh; §12.4)
         record-project          ;; CIU T6 F1a.2 p1a: exported for synthetic dyn-row tests
         union-record-component-vt  ;; CIU T6 F1a.2 p1a: exported for synthetic dyn-row tests
         record-width-applicable?   ;; CIU T6 F1b.3 (D21): width-discharge static guard (qtt twin + tests)
         record-width-discharge?    ;; CIU T6 F1b.3 (D21): the shared discharge (qtt twin + tests)
         schema->row                ;; CIU T6 F1b.4a (D22): schema→row up-shift projection (qtt twins + tests)
         record-<:-schema?          ;; CIU T6 F1b.4a (D22): per-field row-vs-schema discharge (residual-free)
         record-seals-schema?       ;; CIU T6 F1b.4e (D22): per-field + residual (qtt twin + tests)
         record-seals-selection?    ;; CIU T6 F1b.4e (D22): parent types + requires-subset residual (qtt twin)
         schema-seal-residual-ok?   ;; CIU T6 F1b.4e (D22): the residual proper (tests)
         seal-missing-required      ;; CIU T6 F1b.4e: diagnostic support (typing-errors hint)
         seal-first-field-type-mismatch  ;; CIU T6 F1b.7f: wrong-field-type diagnostic (both doors)
         validate-subject-map-ish?  ;; CIU T6 F1b.7f: reused by the validate-nonmap hint
         lookup-selection-parent-schema  ;; CIU T6 F1b.4a: shared parent resolution
         lookup-schema-by-name
         ;; Selection type helpers
         lookup-selection-by-name
         selection-allows-field?
         ;; Sub-selection synthesis (Phase 3c)
         selection-sub-name
         extract-path-suffixes
         selection-field-unrestricted?
         selection-field-type)

;; ========================================
;; Structural reduce tracking
;; ========================================
;; During type checking, expr-reduce nodes that need structural PM
;; (instead of Church fold) are recorded here. The driver uses this
;; to set the structural? flag before storing the body for evaluation.
(define structural-reduce-set (make-hasheq))

(define (mark-structural-reduce! reduce-expr)
  (hash-set! structural-reduce-set reduce-expr #t))

(define (structural-reduce? reduce-expr)
  (hash-ref structural-reduce-set reduce-expr #f))

;; ========================================
;; MaybeLevel: result of inferLevel
;; ========================================
(struct no-level () #:transparent)
(struct just-level (level) #:transparent)

;; ========================================
;; Within-family subtype predicate (Phase 3e + Phase E)
;; ========================================
;; SRE Track 1: Extracted to subtype-predicate.rkt to break circular
;; dependency (typing-core → unify → subtype-predicate).
;; subtype?, type-key, subtype-lattice-merge are re-exported from there.

;; ========================================
;; Forward declarations for mutual recursion
;; ========================================
;; infer, check, is-type, infer-level are all mutually recursive.
;; In Racket, top-level defines can reference each other, so no forward decl needed.

;; ========================================
;; List type fvar resolution
;; ========================================
;; In module contexts, 'List' is qualified as 'prologos::data::list::List'.
;; In bare (no-prelude) contexts, it's just 'List'.
;; This helper returns the correct expr-fvar for constructing List types
;; in typing rules for map-keys, map-vals, set-to-list, pvec-to-list.
(define (list-type-fvar)
  (if (global-env-lookup-type 'prologos::data::list::List)
      (expr-fvar 'prologos::data::list::List)
      (expr-fvar 'List)))

;; ========================================
;; Generic arithmetic type helpers
;; ========================================
;; Concrete numeric types for which generic operators are valid.
(define (concrete-numeric-type? t)
  (or (expr-Nat? t) (expr-Int? t) (expr-Rat? t)
      (expr-Posit8? t) (expr-Posit16? t)
      (expr-Posit32? t) (expr-Posit64? t)
      (expr-Float32? t) (expr-Float64? t)))

;; Types that support division (excludes Nat).
(define (divisible-numeric-type? t)
  (or (expr-Int? t) (expr-Rat? t)
      (expr-Posit8? t) (expr-Posit16? t)
      (expr-Posit32? t) (expr-Posit64? t)
      (expr-Float32? t) (expr-Float64? t)))

;; Types that support negation (excludes Nat).
(define (negatable-numeric-type? t)
  (or (expr-Int? t) (expr-Rat? t)
      (expr-Posit8? t) (expr-Posit16? t)
      (expr-Posit32? t) (expr-Posit64? t)
      (expr-Float32? t) (expr-Float64? t)))

;; Valid target types for from-integer (Int -> T): Int, Rat, Posit8-64, Float32/64 (N3e).
(define (from-int-target-type? t)
  (or (expr-Int? t) (expr-Rat? t)
      (expr-Posit8? t) (expr-Posit16? t)
      (expr-Posit32? t) (expr-Posit64? t)
      (expr-Float32? t) (expr-Float64? t)))

;; Valid target types for from-rational (Rat -> T): Rat, Posit8-64, Float32/64 (N3e).
(define (from-rat-target-type? t)
  (or (expr-Rat? t)
      (expr-Posit8? t) (expr-Posit16? t)
      (expr-Posit32? t) (expr-Posit64? t)
      (expr-Float32? t) (expr-Float64? t)))

;; N4: is exact `val` (with integral? flag) representable in concrete numeric type `t`?
;; Int needs integral; Nat needs integral + nonneg; Rat/Posit/Float accept any rational.
(define (num-lit-representable? val integral? t)
  (cond
    [(expr-Int? t) integral?]
    [(expr-Nat? t) (and integral? (>= val 0))]
    [(expr-Rat? t) #t]
    [(posit-type? t) #t]
    [(float-type? t) #t]
    [else #f]))

;; ========================================
;; Numeric type join (least upper bound)
;; ========================================
;; exact-numeric-type? — Nat, Int, Rat (exact family)
(define (exact-numeric-type? t)
  (or (expr-Nat? t) (expr-Int? t) (expr-Rat? t)))

;; posit-type? — Posit8, Posit16, Posit32, Posit64 (approximate family)
(define (posit-type? t)
  (or (expr-Posit8? t) (expr-Posit16? t) (expr-Posit32? t) (expr-Posit64? t)))

;; Rank within exact family: Nat < Int < Rat
(define (exact-rank t)
  (cond [(expr-Nat? t) 0] [(expr-Int? t) 1] [(expr-Rat? t) 2] [else -1]))

;; Rank within posit family: P8 < P16 < P32 < P64
(define (posit-rank t)
  (cond [(expr-Posit8? t) 0] [(expr-Posit16? t) 1]
        [(expr-Posit32? t) 2] [(expr-Posit64? t) 3] [else -1]))

;; Type at a given exact rank
(define (exact-type-at-rank r)
  (case r [(0) (expr-Nat)] [(1) (expr-Int)] [(2) (expr-Rat)] [else #f]))

;; Type at a given posit rank
(define (posit-type-at-rank r)
  (case r [(0) (expr-Posit8)] [(1) (expr-Posit16)]
          [(2) (expr-Posit32)] [(3) (expr-Posit64)] [else #f]))

;; float-type? — Float32, Float64 (IEEE approximate family; separate rank family
;; from posit — Posit↔Float has NO numeric-join, explicit conversion only)
(define (float-type? t)
  (or (expr-Float32? t) (expr-Float64? t)))

;; Rank within float family: Float32 < Float64
(define (float-rank t)
  (cond [(expr-Float32? t) 0] [(expr-Float64? t) 1] [else -1]))

;; Type at a given float rank
(define (float-type-at-rank r)
  (case r [(0) (expr-Float32)] [(1) (expr-Float64)] [else #f]))

;; Phase H: Normalize refined numeric types to their base type.
;; PosInt/NegInt/Zero → Int; PosRat/NegRat → Rat; others unchanged.
;; Uses the subtype registry to determine the base type.
;; Issue #70 (N6e-E5, R1 extension): resolve a SOLVED meta first — the unary
;; generic rules (negate/abs) guard on this function's result directly (they
;; don't go through numeric-join), so they need the same resolution step.
;; resolve-solved-meta is defined below with numeric-join (R1-join).
(define (base-numeric-type t0)
  (define t (resolve-solved-meta t0))
  (match t
    [(expr-fvar name)
     (cond
       ;; Check if it's a subtype of Int (direct, not transitive through Int→Rat)
       [(subtype-pair? name 'Int) (expr-Int)]
       ;; Check if it's a subtype of Rat (could be direct or via Int)
       [(subtype-pair? name 'Rat) (expr-Rat)]
       [else t])]
    [_ t]))

;; Numerics N5de: base-type expr for a refined-name's base symbol ('Int/'Rat).
(define (refined-base->expr base-sym)
  (case base-sym [(Int) (expr-Int)] [(Rat) (expr-Rat)] [else (expr-error)]))

;; Numerics N5de: refinement-preserving arithmetic transfer. Runs PARALLEL to numeric-join —
;; base via rank (numeric-join, which already strips refined operands to base), sign via the
;; Sign transfer; the sign channel never enters numeric-join / subtype-lattice-merge.
(define (operand-sign t)
  (if (and (expr-fvar? t) (refined-name? (expr-fvar-name t)))
      (refined-name->sign (expr-fvar-name t))
      sign-top))                       ;; bare/non-refined operand ⇒ ⊤ ("no refinement")
(define (base-sym-of j)                ;; refinements are named only over Int/Rat bases
  (cond [(expr-Int? j) 'Int] [(expr-Rat? j) 'Rat] [else #f]))
;; re-refine the numeric-join result j via a binary sign transfer; bare j if the sign is unnamed/⊤.
(define (refine-arith ta tb j transfer2)
  (let ([bs (base-sym-of j)])
    (if bs
        (let ([rn (base+sign->refined-name bs (transfer2 (operand-sign ta) (operand-sign tb)))])
          (if rn (expr-fvar rn) j))
        j)))
;; unary variant (negate/abs): j is the base result type (post base-numeric-type strip).
(define (refine-arith1 ta j transfer1)
  (let ([bs (base-sym-of j)])
    (if bs
        (let ([rn (base+sign->refined-name bs (transfer1 (operand-sign ta)))])
          (if rn (expr-fvar rn) j))
        j)))

;; numeric-join: least upper bound of two numeric types.
;; Returns the wider type, or #f if not numeric types.
;; Within-family: wider wins (Nat < Int < Rat; P8 < P16 < P32 < P64).
;; Cross-family: posit wins (approximate dominates exact).
;; The resulting posit width is max(P32, posit operand width) for cross-family.
;; Phase H: normalizes refined types (PosInt→Int, etc.) before computing the join.
;; Issue #70 (N6e-E5, R1-join): follow a meta operand to its solution before
;; the concrete-only tests below. The generic-op rules read RAW operand types
;; (no whnf/zonk anywhere on that path: ctx-extend stores raw metas, bvar infer
;; shifts them unresolved), so without this even a SOLVED element meta
;; hard-fails the join (verified by repro at E5 open). Placing the resolution
;; INSIDE numeric-join makes it drift-free across the 3 typing stages by
;; construction: infer (this file), inferQ (qtt.rkt imports THIS numeric-join),
;; and the on-network make-arith-ret (typing-propagators.rkt) all share it —
;; as does numeric-join/warn!.
(define (resolve-solved-meta t)
  (match t
    [(expr-meta id cell-id)
     (let ([sol (meta-solution/cell-id cell-id id)])
       (if sol (resolve-solved-meta sol) t))]
    [_ t]))

(define (numeric-join t1 t2)
  (let ([t1 (base-numeric-type (resolve-solved-meta t1))]
        [t2 (base-numeric-type (resolve-solved-meta t2))])
    (cond
      ;; Same numeric type
      [(and (equal? t1 t2) (concrete-numeric-type? t1)) t1]
      ;; Both exact
      [(and (exact-numeric-type? t1) (exact-numeric-type? t2))
       (exact-type-at-rank (max (exact-rank t1) (exact-rank t2)))]
      ;; Both posit
      [(and (posit-type? t1) (posit-type? t2))
       (posit-type-at-rank (max (posit-rank t1) (posit-rank t2)))]
      ;; Cross-family: posit wins
      [(and (exact-numeric-type? t1) (posit-type? t2))
       ;; Posit dominates; ensure at least P32 for precision
       (posit-type-at-rank (max 2 (posit-rank t2)))]
      [(and (posit-type? t1) (exact-numeric-type? t2))
       (posit-type-at-rank (max 2 (posit-rank t1)))]
      ;; Float family (Numerics N3d): widen within-Float; exact+Float PRESERVES the
      ;; Float operand's width (NOT a clamp like posit); Posit+Float = no join (→ #f).
      [(and (float-type? t1) (float-type? t2))
       (float-type-at-rank (max (float-rank t1) (float-rank t2)))]
      [(and (exact-numeric-type? t1) (float-type? t2)) t2]
      [(and (float-type? t1) (exact-numeric-type? t2)) t1]
      ;; Not numeric types (incl. Posit↔Float — explicit conversion only)
      [else #f])))

;; Human-readable name for a numeric type expression (for warnings).
(define (numeric-type-name t)
  (cond
    [(expr-Nat? t) "Nat"] [(expr-Int? t) "Int"] [(expr-Rat? t) "Rat"]
    [(expr-Posit8? t) "Posit8"] [(expr-Posit16? t) "Posit16"]
    [(expr-Posit32? t) "Posit32"] [(expr-Posit64? t) "Posit64"]
    [(expr-Float32? t) "Float32"] [(expr-Float64? t) "Float64"]
    [else "?"]))

;; N6a values-only warning policy (D-N6.4c): a bare exact LITERAL operand
;; never triggers a coercion warning — a literal's exactness is not user
;; intent (the polymorphic-literal default just happens to be exact); only
;; a runtime VALUE of exact type flowing into an approximate type warns.
;; Scope: bare literal nodes at typing time (pre-zonk); an ASCRIBED literal
;; like (the Rat 3.13) is an explicit exactness assertion and still warns.
(define (bare-exact-literal? e)
  (or (expr-num-lit? e) (expr-int? e) (expr-rat? e)
      (expr-nat-val? e)  ;; 3N → O(1) native natural literal
      ;; Hand-written Peano numerals: ground suc-chains ending in zero.
      ;; (suc n) with a variable inside is a VALUE, not a literal — still warns.
      (let loop ([v e])
        (cond [(expr-zero? v) #t]
              [(expr-suc? v) (loop (expr-suc-pred v))]
              [else #f]))))

;; numeric-join with coercion warning: emit when an EXACT operand is coerced into
;; an APPROXIMATE result (Posit OR Float). Single source of truth for the imperative
;; path — matches the on-network coercion detector (typing-propagators
;; make-coercion-detection-fire-fn), which already warns on exact↔approximate.
;; exact→Float warns by symmetry with exact→Posit: Float is 'approximate (loses
;; exactness) just like Posit.
;; N6a: optional operand exprs (a b, aligned with t1 t2) enable the values-only
;; policy — when the exact-side operand is a bare literal, the warning is
;; suppressed. Callers that don't pass operands keep the old always-warn behavior.
(define (numeric-join/warn! t1 t2 [a #f] [b #f])
  (define j (numeric-join t1 t2))
  (when (and j (not (equal? t1 t2)))
    (define t1-exact? (exact-numeric-type? t1))
    (define t2-exact? (exact-numeric-type? t2))
    (define t1-approx? (or (posit-type? t1) (float-type? t1)))
    (define t2-approx? (or (posit-type? t2) (float-type? t2)))
    ;; Cross-family exact↔approximate → loss of exactness
    (when (or (and t1-exact? t2-approx?)
              (and t2-exact? t1-approx?))
      (define exact-t (cond [t1-exact? t1] [t2-exact? t2] [else #f]))
      (define exact-operand (cond [t1-exact? a] [t2-exact? b] [else #f]))
      (when (and exact-t
                 (not (and exact-operand (bare-exact-literal? exact-operand))))
        (emit-coercion-warning! (numeric-type-name exact-t)
                                (numeric-type-name j)))))
  j)

;; ========================================
;; Schema field type conversion
;; ========================================
;; Convert a schema field type-datum (symbol or list) into an AST type expression.
;; Built-in types map to their constructors; user-defined types map to expr-fvar.
;; Compound types like (List Nat) are handled as nested applications.
(define (schema-field-type->expr datum)
  (cond
    [(symbol? datum)
     (case datum
       [(Nat)     (expr-Nat)]
       [(Int)     (expr-Int)]
       [(Rat)     (expr-Rat)]
       [(Bool)    (expr-Bool)]
       [(String)  (expr-String)]
       [(Char)    (expr-Char)]
       [(Keyword) (expr-Keyword)]
       [(Unit)    (expr-Unit)]
       [(Nil)     (expr-Nil)]
       [(Symbol)  (expr-Symbol)]
       [(Posit8)  (expr-Posit8)]
       [(Posit16) (expr-Posit16)]
       [(Posit32) (expr-Posit32)]
       [(Posit64) (expr-Posit64)]
       ;; CIU T6 F1b.5-s1: Quire arms were MISSING (the two-list drift vs
       ;; macros' builtin-type-names — Quire fields minted bare fvars).
       [(Quire8)  (expr-Quire8)]
       [(Quire16) (expr-Quire16)]
       [(Quire32) (expr-Quire32)]
       [(Quire64) (expr-Quire64)]
       [(Float32) (expr-Float32)]
       [(Float64) (expr-Float64)]
       [else
        ;; CIU T6 F1b.5-s1: guarded name resolution — the list-type-fvar
        ;; recipe (typing-core:117) generalized. User-type datums arrive
        ;; ns-QUALIFIED from registration (qualify-type-datum); prelude
        ;; container heads (List, Map, Option…) are qualification-SKIPPED
        ;; (builtin-type-names) and pre-s1 minted BARE fvars that never
        ;; unified with the prelude's qualified types (p0 probe: a correct
        ;; List Int value REJECTED against a (List Int) field). Resolution
        ;; order: stored name if bound → import-map resolution (guarded by
        ;; global-env existence, the elaborate-var shape) → bare fallback
        ;; (preserves :no-prelude / unit-test contexts).
        (cond
          ;; (1) import-map resolution FIRST — a bare container head (List,
          ;; Map, Option…) may ALSO be global-env-bound under its short name,
          ;; so stored-name-first would return the bare fvar and never unify
          ;; with the prelude's qualified type (the list-type-fvar lesson:
          ;; check qualified before bare).
          [(let ([ns-ctx (current-ns-context)])
             (and ns-ctx
                  (let ([r (resolve-name datum ns-ctx)])
                    (and r (not (eq? r datum)) (global-env-lookup-type r) r))))
           => (lambda (r) (expr-fvar r))]
          ;; (2) the stored name itself if bound (qualified user-type datums
          ;; from registration; bare names in bare contexts).
          [(global-env-lookup-type datum) (expr-fvar datum)]
          ;; (3) bare fallback (:no-prelude / unit-test contexts).
          [else (expr-fvar datum)])])]
    ;; CIU T6 F1b.5-s1: canonical angle forms from schema-field registration
    ;; (normalize-field-type-datum): unions and arrows now CONVERT (pre-s1
    ;; there were no arms — even a de-sentineled union was unconvertible).
    [(and (pair? datum) (eq? (car datum) '$union))
     ;; ($union A B C) → right-nested expr-union (the surf-union foldr shape)
     (let build ([parts (cdr datum)])
       (cond
         [(null? parts) (error 'schema-field-type->expr "empty $union datum")]
         [(null? (cdr parts)) (schema-field-type->expr (car parts))]
         [else (expr-union (schema-field-type->expr (car parts))
                           (build (cdr parts)))]))]
    [(and (pair? datum) (eq? (car datum) '$arrow))
     ;; ($arrow A B) → non-dependent Pi at 'mw (the surf-arrow default mult;
     ;; field types are closed, so the codomain carries no binder reference)
     (expr-Pi 'mw
              (schema-field-type->expr (cadr datum))
              (schema-field-type->expr (caddr datum)))]
    [(and (list? datum) (>= (length datum) 2))
     ;; Compound type: (List Nat) → (app (fvar List) (Nat))
     ;; (Map Keyword String) → (app (app (fvar Map) (Keyword)) (String))
     ;; (head resolution rides the symbol arm's guarded resolution above)
     (let loop ([parts datum])
       (cond
         [(null? parts) (error 'schema-field-type->expr "empty type datum")]
         [(null? (cdr parts)) (schema-field-type->expr (car parts))]
         [else
          (let loop2 ([args (cdr parts)]
                      [result (schema-field-type->expr (car parts))])
            (if (null? args)
                result
                (loop2 (cdr args)
                       (expr-app result (schema-field-type->expr (car args))))))]))]
    [else (error 'schema-field-type->expr (format "unsupported type datum: ~a" datum))]))

;; ========================================
;; Witness tag assignment (CIU T6 F1b.5-s1, D28)
;; ========================================
;; Compute a per-field acceptance TAG (plain data — the field-witness.rkt
;; grammar: (prim …) / (ctor Name) / any / (union …)) from an elaborated
;; field-type expr, by CONSUMING subtype? so the primitive acceptance set IS
;; the subtype closure (Nat⊂Int handled → the runtime witness never false-
;; rejects data the static seal accepted; the D28 err-polarity invariant).
;; whnf-first for type-alias transparency. Unwitnessable shapes (functions,
;; type vars, unknown/abstract heads) → 'any (the D28 skip posture). Tags are
;; plain s-expressions (no struct), so they carry into an AST node payload and
;; serialize with zero registration. The runtime interpreter lives in
;; field-witness.rkt (below reduction, where subtype? cannot reach).
(define PRIM-WITNESS-SLICE
  (list (cons 'Nat (expr-Nat))   (cons 'Int (expr-Int))     (cons 'Rat (expr-Rat))
        (cons 'Bool (expr-Bool)) (cons 'String (expr-String)) (cons 'Char (expr-Char))
        (cons 'Keyword (expr-Keyword)) (cons 'Symbol (expr-Symbol)) (cons 'Unit (expr-Unit))
        (cons 'Nil (expr-Nil))
        (cons 'Posit8 (expr-Posit8))   (cons 'Posit16 (expr-Posit16))
        (cons 'Posit32 (expr-Posit32)) (cons 'Posit64 (expr-Posit64))
        (cons 'Float32 (expr-Float32)) (cons 'Float64 (expr-Float64))))

(define (prim-type-expr->tag t)
  (cond [(expr-Nat? t) 'Nat] [(expr-Int? t) 'Int] [(expr-Rat? t) 'Rat]
        [(expr-Bool? t) 'Bool] [(expr-String? t) 'String] [(expr-Char? t) 'Char]
        [(expr-Keyword? t) 'Keyword] [(expr-Symbol? t) 'Symbol] [(expr-Unit? t) 'Unit]
        [(expr-Nil? t) 'Nil]
        [(expr-Posit8? t) 'Posit8] [(expr-Posit16? t) 'Posit16]
        [(expr-Posit32? t) 'Posit32] [(expr-Posit64? t) 'Posit64]
        [(expr-Float32? t) 'Float32] [(expr-Float64? t) 'Float64]
        [else #f]))

(define (field-type->witness-tag ft)
  (let ([t (whnf ft)])
    (cond
      ;; union: ⋃ of branch tags (mirrors field-type-satisfies? some-branch)
      [(expr-union? t)
       (cons 'union (map field-type->witness-tag (flatten-union t)))]
      ;; primitive: the subtype closure over the witnessable slice
      [(prim-type-expr->tag t)
       (cons 'prim
             (for/list ([p (in-list PRIM-WITNESS-SLICE)]
                        #:when (subtype? (cdr p) t))
               (car p)))]
      ;; refined numeric name (PosInt, …): erase to base — values are the base
      ;; at runtime, and the refined→base edges are one-directional (a naive
      ;; closure would be empty and reject everything)
      [(and (expr-fvar? t) (refined-name? (bare-name (expr-fvar-name t))))
       (field-type->witness-tag
        (schema-field-type->expr (refined-name->base (bare-name (expr-fvar-name t)))))]
      ;; a CONFIRMED data type (bare head OR applied container head with
      ;; registered ctors): the tier-2 HEAD route — element args are NOT
      ;; recursed (deferred to the walker charter). Only emit (ctor …) when the
      ;; head genuinely has ctors, else fall to 'any (never false-reject an
      ;; abstract/type-var field).
      [(let-values ([(head _args) (decompose-type-app t)])
         (and head
              (let* ([bare (bare-name head)]
                     [ctors (lookup-type-ctors bare)])
                (and (pair? ctors) bare))))
       => (lambda (bare) (list 'ctor bare))]
      ;; functions (Pi), type vars, unknown/abstract heads, higher-kinded —
      ;; unwitnessable → skip
      [else 'any])))

;; Look up a field keyword in a schema's field list.
;; Returns the schema-field or #f.
(define (schema-lookup-field schema-entry keyword-sym)
  (for/first ([f (in-list (schema-entry-fields schema-entry))]
              #:when (eq? (schema-field-keyword f) keyword-sym))
    f))

;; CIU T6 F1 (s2): project a field type out of a structural-row type.
;;   literal key (keyword/nat) present → the field's type; absent → error (closed-row miss);
;;   dynamic key → union of ALL field types (B4-gated on the key domain; empty row → error).
(define (record-project ctx rec key)
  (define kd (expr-Record-key-domain rec))
  ;; CIU T6 F1a.2 p1a (D19): a literal-key MISS on a 'dyn row is NOT an error —
  ;; the field may live in the unknown remainder; mint a fresh meta (the meta IS
  ;; the observation; recording descoped to F-row per §12.5). 'closed keeps the
  ;; miss error (+ the S7 diagnostic on the infer/err walk).
  (define (miss)
    (if (eq? (expr-Record-tail rec) 'dyn)
        (fresh-meta ctx (expr-Type (lzero)) (dyn-row-source 'dyn-row-projection))
        (expr-error)))
  (match key
    [(expr-keyword kw) #:when (eq? kd 'keyword)
     (let ([fld (record-lookup-field rec kw)])
       ;; CIU T6 F1b.3 (D24/Q7, gated-identically): an 'unknown-marked HIT
       ;; projects exactly like a tail miss — a fresh meta, never the retained
       ;; type (the courtesy upgrade would assert presence the compiler lacks).
       (if (and fld (not (eq? (record-field-presence fld) 'unknown)))
           (record-field-type fld)
           (miss)))]
    ;; CIU T6 F1a-col: literal Nat/Int index on a 'nat row (tuple) — position lookup.
    ;; Bare Int literals accepted (Q_col-C), mirroring expr-get's PVec Nat-or-Int gate.
    [(or (expr-nat-val n) (expr-int n))
     #:when (and (eq? kd 'nat) (exact-nonnegative-integer? n))
     (let ([fld (record-lookup-field rec n)])
       (if fld (record-field-type fld) (miss)))]
    [_
     (let ([fields (expr-Record-fields rec)]
           [key-ty (if (eq? kd 'keyword) (expr-Keyword) (expr-Nat))])
       (cond
         ;; dyn + dynamic key: the result may be any known field OR the remainder
         ;; — ⋃knowns ∪ fresh; the EMPTY dyn row still projects (fresh alone).
         [(eq? (expr-Record-tail rec) 'dyn)
          (if (check ctx key key-ty)
              (record-value-bound ctx rec (dyn-row-source 'dyn-row-dynamic-projection))
              (expr-error))]
         [(and (pair? fields) (check ctx key key-ty))
          (record-value-union rec)]
         [else (expr-error)]))]))

;; CIU T6 F1a.2 p1a (§12.4): the value bound of a row for ENUMERATING consumers
;; ("all values" — vals/fold/filter/map-vals/dynamic projection).
;;   closed → ⋃fields (record-value-union, exactly as before);
;;   dyn    → ⋃fields ∪ fresh-meta — the remainder's values must be absorbed by
;;            anything consuming every value. Fresh-meta-per-call is the accepted
;;            D19 posture (no reconciliation; speculation rolls metas back via
;;            the existing save/restore machinery).

;; CIU T6 F1b.2 (D23 groundwork): structured provenance for D19 dyn-row metas.
;; loc=#f interim — record-project/record-value-bound carry no srcloc; the
;; D23 error boundary is the STORE sites, where def-srcloc is in scope.
;; kind = the tag symbol (meta-category's else-arm classifies it 'primary,
;; same as the historical bare strings — behavior-preserving).
(define (dyn-row-source tag)
  (meta-source-info #f tag (symbol->string tag) #f #f))

(define (record-value-bound ctx rec [src (dyn-row-source 'dyn-row-values)])
  (cond
    [(eq? (expr-Record-tail rec) 'dyn)
     (build-union-type
      (cons (fresh-meta ctx (expr-Type (lzero)) src)
            (map (lambda (f) (record-field-type (cdr f)))
                 (expr-Record-fields rec))))]
    ;; CIU T6 F1a.2 p1b (Q6): the empty CLOSED row (dissoc-to-{} / slice-to-⟨⟩)
    ;; has no values — a fresh meta, not Open (record-value-union's Open empty
    ;; arm is DEAD after this commit; deleted with the node at p2).
    [(null? (expr-Record-fields rec))
     (fresh-meta ctx (expr-Type (lzero)) src)]
    [else (record-value-union rec)]))

;; CIU T6 F1 (s3): ⋃fields — the uniform-bound view of a row's value types.
;; NON-EMPTY rows only (F1a.2 p2): every caller either guards the empty row or
;; routes through record-value-bound (whose empty-closed arm mints a fresh meta,
;; Q6). The old empty→Open arm died with the node.
(define (record-value-union rec)
  (define fields (expr-Record-fields rec))
  (when (null? fields)
    (error 'record-value-union "empty row — callers must guard or use record-value-bound (F1a.2 p2)"))
  (build-union-type (map (lambda (f) (record-field-type (cdr f))) fields)))

;; CIU T6 F1a-col: does a 'nat row (tuple) satisfy (PVec A)?  The Tuple→PVec α
;; (meta-aware sibling of subtype-predicate's pure record-subtypes-pvec?).
;; If A is an unsolved meta, solve A := ⋃positions (uniform-bound view);
;; else every position type must fit A. 'keyword rows never α to PVec.
;; CIU T6 F1a-col-2: the shared elem-side α core — does a 'nat row satisfy a
;; uniform container with element type `at`? (PVec and List share this.)
(define (record-<:-elem? ctx rec at)
  (and (eq? (expr-Record-key-domain rec) 'nat)
       (let ([at* (whnf at)])
         (cond
           ;; CIU T6 F1a.2 p1a (D16): meta-elem solving from ⋃positions only for
           ;; CLOSED rows (dyn remainder unknown → refuse; §12.4).
           [(expr-meta? at*)
            ;; p1b: the EMPTY closed row satisfies any elem meta WITHOUT solving
            ;; it (Q6 mirror of record-<:-map?'s null guard — RVU on empty is dead).
            (and (eq? (expr-Record-tail rec) 'closed)
                 (or (null? (expr-Record-fields rec))
                     (unify-ok? (unify ctx at (record-value-union rec)))))]
           [else
            ;; A union element type accepts a position when SOME branch fits
            ;; (subtype? first — pure — so ground positions don't stray-solve).
            (let ([branches (if (expr-union? at*) (flatten-union at*) (list at*))])
              (andmap (lambda (f)
                        (let ([ft (record-field-type (cdr f))])
                          (ormap (lambda (br)
                                   (or (subtype? ft br) (unify-ok? (unify ctx ft br))))
                                 branches)))
                      (expr-Record-fields rec)))]))))

(define (record-<:-pvec? ctx rec at)
  (record-<:-elem? ctx rec at))

;; CIU T6 F1 (s3): a record component's contribution to a union-typed map access.
;;   keyword-literal key: PURE lookup — present → the field type; absent → #f (Q5: filter,
;;   matching the sibling Map-component behavior; all-components-miss errors at the caller).
;;   dynamic key: check against the row's key domain (B4) — ok → ⋃fields; else #f.
;;   The dynamic-key check is rollback-wrapped EXACTLY like the sibling Map-component
;;   check in the same loops: a filtered component must not leave meta commitments.
(define (union-record-component-vt ctx rec key)
  (define kd (expr-Record-key-domain rec))
  (match key
    [(expr-keyword kw) #:when (eq? kd 'keyword)
     (let ([fld (record-lookup-field rec kw)])
       (cond
         ;; CIU T6 F1b.3 (D24/Q7): an 'unknown-marked hit is treated exactly
         ;; like the dyn miss below (gated-identically).
         [(and fld (not (eq? (record-field-presence fld) 'unknown)))
          (record-field-type fld)]
         ;; CIU T6 F1a.2 p1a (§12.4): a literal miss on a 'dyn component may live
         ;; in its remainder — FILTERING it (the closed Q5 behavior) would
         ;; silently drop a live component; contribute a fresh meta instead.
         [(eq? (expr-Record-tail rec) 'dyn)
          (fresh-meta ctx (expr-Type (lzero)) (dyn-row-source 'dyn-row-union-component))]
         [else #f]))]
    [_
     (let ([key-ty (if (eq? kd 'keyword) (expr-Keyword) (expr-Nat))])
       (and (or (pair? (expr-Record-fields rec))
                (eq? (expr-Record-tail rec) 'dyn))   ;; empty dyn row still projects
            (with-speculative-rollback
              (lambda () (check ctx key key-ty))
              values
              "union-record-component")
            (record-value-bound ctx rec (dyn-row-source 'dyn-row-union-component))))]))

;; CIU T6 F1 (s2): does a structural-row type satisfy (Map K V)?  The Galois α (§5.3).
;;   keys: every label must check against K;  values: if V is an unsolved meta, solve V := ⋃fields
;;   (uniform-bound view); else each field type must be <: V.  Empty row satisfies any (Map K V) (Q6).
(define (record-<:-map? ctx rec kt vt)
  (define kd (expr-Record-key-domain rec))
  (define fields (expr-Record-fields rec))
  (and
   (andmap (lambda (f)
             (check ctx (if (eq? kd 'keyword) (expr-keyword (car f)) (expr-nat-val (car f))) kt))
           fields)
   (cond
     [(null? fields) #t]
     ;; CIU T6 F1a.2 p1a (D16): a meta V may be solved from ⋃fields ONLY for a
     ;; CLOSED row — a dyn row's remainder is unknown, so ⋃knowns would
     ;; over-commit; REFUSE (the meta stays unsolved; Q4 display posture).
     [(expr-meta? (whnf vt))
      (and (eq? (expr-Record-tail rec) 'closed)
           (unify-ok? (unify ctx vt (record-value-union rec))))]
     [else
      ;; Concrete V: knowns-only IS the C_ConsL absorption for dyn rows (§12.4).
      ;; F1b.4a: via the shared per-field satisfaction (union-V aware).
      (andmap (lambda (f)
                (field-type-satisfies? ctx (record-field-type (cdr f)) vt))
              fields)])))

;; CIU T6 F1b.4a: shared per-field satisfaction — does field type ft satisfy
;; expected value type vt at α-strength? The single-branch case is BYTE-
;; IDENTICAL to the historical record-<:-map? leg (unify-first — a meta ft
;; must still solve against vt); a UNION expected type accepts when SOME
;; branch fits (subtype?-first per the record-<:-elem? idiom, so ground
;; fields don't stray-solve). Closes a PRE-EXISTING gap the up-shift probe
;; surfaced: rows vs (Map K <A|B>) annotations refused although every field
;; fit a branch (probe-4a-union ;;2). Consumers: record-<:-map?,
;; record-<:-schema?, record-seals-schema?/-selection?.
(define (field-type-satisfies? ctx ft vt)
  (let ([vt* (whnf vt)])
    (if (expr-union? vt*)
        (ormap (lambda (br)
                 (or (subtype? ft br) (unify-ok? (unify ctx ft br))))
               (flatten-union vt*))
        (or (unify-ok? (unify ctx ft vt)) (subtype? ft vt)))))

;; Look up a schema by name, trying both the full name and bare (short) name.
;; Handles qualified names like 'test::Point → looks up 'Point.
(define (lookup-schema-by-name name)
  (or (lookup-schema name)
      (let ([short (let-values ([(_prefix s) (split-qualified-name name)])
                     s)])
        (and short (lookup-schema short)))))

;; Look up a selection by name, trying both the full name and bare (short) name.
(define (lookup-selection-by-name name)
  (or (lookup-selection name)
      (let ([short (let-values ([(_prefix s) (split-qualified-name name)])
                     s)])
        (and short (lookup-selection short)))))

;; Check if a keyword is in a selection's allowed fields (requires + provides).
;; kw-sym is a symbol (e.g., 'name). Paths are structured lists: ((#:name) (#:address #:zip) ...).
;; A top-level field :foo is allowed if ANY path's first segment is #:foo.
;; This includes flat paths like (#:name) and the first hop of deep paths like (#:address #:zip).
(define (selection-allows-field? sel kw-sym)
  (define kw-rkt (string->keyword (symbol->string kw-sym)))
  (define (path-starts-with? path kw)
    (and (pair? path) (equal? (car path) kw)))
  (or (ormap (lambda (p) (path-starts-with? p kw-rkt))
             (selection-entry-requires-paths sel))
      (ormap (lambda (p) (path-starts-with? p kw-rkt))
             (selection-entry-provides-paths sel))))

;; ========================================
;; Sub-selection synthesis for nested field-gating (Phase 3c)
;; ========================================

;; Compute deterministic synthetic name for a sub-selection.
;; E.g., (selection-sub-name 'AddrZip 'address) → 'AddrZip/address
(define (selection-sub-name parent-name field-sym)
  (string->symbol (format "~a/~a" parent-name field-sym)))

;; Extract path suffixes for a given keyword from a path list.
;; ((#:address #:zip) (#:address #:city) (#:name)) with kw=#:address
;; → ((#:zip) (#:city))
(define (extract-path-suffixes paths kw)
  (let loop ([ps paths] [acc '()])
    (if (null? ps)
        (reverse acc)
        (let ([p (car ps)])
          (if (and (pair? p) (equal? (car p) kw))
              (let ([tail (cdr p)])
                (if (pair? tail)
                    (loop (cdr ps) (cons tail acc))
                    (loop (cdr ps) acc)))
              (loop (cdr ps) acc))))))

;; Check if a field should return the full schema type (unrestricted).
;; True when any matching path is: bare (#:field), wildcard (#:field *),
;; or globstar (#:field **).
(define (selection-field-unrestricted? paths kw)
  (ormap (lambda (p)
           (and (pair? p) (equal? (car p) kw)
                (or (null? (cdr p))              ;; bare: (#:address)
                    (equal? (cdr p) '(*))         ;; wildcard: (#:address *)
                    (equal? (cdr p) '(**)))))     ;; globstar: (#:address **)
         paths))

;; Compute the type for a selection field access.
;; If the field's schema type needs sub-selection gating, synthesize
;; or retrieve a cached sub-selection. Returns an expr (type).
(define (selection-field-type sel kw-sym schema)
  (define field (schema-lookup-field schema kw-sym))
  (if (not field)
      (expr-error)
      (let ([field-type-expr (schema-field-type->expr (schema-field-type-datum field))])
        ;; Only apply sub-selection gating if the field type is a schema
        (match field-type-expr
          [(expr-fvar nested-schema-name)
           #:when (lookup-schema-by-name nested-schema-name)
           (let* ([kw-rkt (string->keyword (symbol->string kw-sym))]
                  [all-paths (append (selection-entry-requires-paths sel)
                                    (selection-entry-provides-paths sel))])
             (cond
               ;; Unrestricted access — return full schema type
               [(selection-field-unrestricted? all-paths kw-rkt)
                field-type-expr]
               ;; Compute sub-selection
               [else
                (let* ([suffixes (extract-path-suffixes all-paths kw-rkt)]
                       [sub-name (selection-sub-name (selection-entry-name sel) kw-sym)])
                  (cond
                    ;; No deep paths through this field — shouldn't happen since
                    ;; selection-allows-field? passed, but guard anyway
                    [(null? suffixes) field-type-expr]
                    ;; Already cached
                    [(lookup-selection sub-name) (expr-fvar sub-name)]
                    ;; Create + register sub-selection
                    [else
                     (let ([nested-schema (lookup-schema-by-name nested-schema-name)])
                       (register-selection!
                        sub-name
                        (selection-entry sub-name
                                        (schema-entry-name nested-schema)
                                        suffixes  ;; requires-paths = path suffixes
                                        '()       ;; provides-paths = empty
                                        '()       ;; includes-names = empty
                                        #f))      ;; srcloc = synthetic
                       ;; Install as type in global-env (4A.c-iii-a: always-mnr)
                       (global-env-add-type-only sub-name (expr-Type (lzero)))
                       (expr-fvar sub-name))]))]))]
          ;; Not a schema type — return as-is (e.g., String, Nat)
          [_ field-type-expr]))))

;; ========================================
;; Issue #70 (N6e-E5, R2-spine) helpers
;; ========================================

;; Collect an application spine: (app (app f a) b) → (values f (list a b)).
;; Local (typing-core-only fix; reduction's decompose-app is not provided and
;; targets fvar heads — this one is shape-agnostic).
(define (spine-collect e)
  (let loop ([x e] [args '()])
    (match x
      [(expr-app f a) (loop f (cons a args))]
      [_ (values x args)])))

;; A hole-domain lambda: an unannotated `fn` or an E3 explicit-hole section.
(define (hole-domain-lam? x)
  (and (expr-lam? x) (expr-hole? (expr-lam-type x))))

;; Trigger for the deferred spine walk: a non-lambda-headed spine with at
;; least one hole-domain-lambda argument. Head-lam spines are excluded so the
;; beta/let-expansion special case and the #71 saturated-section pre-case
;; keep their existing paths.
(define (app-spine-with-deferrable-fn? e)
  (let-values ([(head args) (spine-collect e)])
    (and (not (expr-lam? head))
         (pair? args)
         (ormap hole-domain-lam? args))))

;; The deferred two-pass walk. Pass 1: walk the Pi left-to-right; check each
;; non-deferrable arg in order; for hole-domain-lambda args, RECORD (arg . dom)
;; and continue (substituting the arg expression into the codomain exactly as
;; the default path does). Pass 2: run the deferred checks — by now the later
;; args (containers, inits, seeds) have solved the shared metas, and the body's
;; numeric rules resolve them via R1-join. Non-Pi mid-walk → expr-error (any
;; spine matching the trigger also fails on today's union/other paths, since
;; those infer the hole-domain lambda — behavior-equivalent).
(define (infer-app-spine-deferred ctx e)
  (let-values ([(head args) (spine-collect e)])
    (let loop ([t (infer ctx head)] [as args] [deferred '()])
      (cond
        [(expr-error? t) (expr-error)]
        [(null? as)
         (if (for/and ([d (in-list (reverse deferred))])
               (check ctx (car d) (cdr d)))
             t
             (expr-error))]
        [else
         (let ([tw (whnf t)])
           (if (expr-Pi? tw)
               (let ([arg (car as)]
                     [dom (expr-Pi-domain tw)]
                     [cod (expr-Pi-codomain tw)])
                 (if (hole-domain-lam? arg)
                     (loop (subst 0 arg cod) (cdr as) (cons (cons arg dom) deferred))
                     (if (check ctx arg dom)
                         (loop (subst 0 arg cod) (cdr as) deferred)
                         (expr-error))))
               (expr-error)))]))))

;; ========================================
;; Type inference (synthesis mode)
;; ========================================
(define (infer ctx e)
  (perf-inc-infer!)
  (match e
    ;; ---- Bound variable: lookup in context and SHIFT the type ----
    [(expr-bvar k)
     (if (< k (ctx-len ctx))
         (shift (+ k 1) 0 (lookup-type k ctx))
         (expr-error))]

    ;; ---- Free variable: lookup in global environment ----
    ;; Numerics N5de: nominal-erased refined numeric types are built-in types (: Type 0).
    [(expr-fvar (? refined-name? _)) (expr-Type (lzero))]
    [(expr-fvar name)
     (let ([ty (global-env-lookup-type name)])
       (when ty
         ;; Check for deprecation warning — spec, then trait, then functor (G7)
         (let ([spec-dep
                (let ([se (lookup-spec name)])
                  (and se
                       (let ([md (spec-entry-metadata se)])
                         (and md (hash-ref md ':deprecated #f)))))])
           (cond
             [spec-dep
              (emit-deprecation-warning! name (if (string? spec-dep) spec-dep #f))]
             [else
              ;; G7: Check trait deprecation
              (let ([tdep (trait-deprecated name)])
                (when tdep
                  (emit-deprecation-warning! name (if (string? tdep) tdep #f))))
              ;; G7: Check functor deprecation
              (let ([fe (lookup-functor name)])
                (when fe
                  (let ([fdep (hash-ref (functor-entry-metadata fe) ':deprecated #f)])
                    (when fdep
                      (emit-deprecation-warning! name (if (string? fdep) fdep #f))))))])))
       (if ty ty (expr-error)))]

    ;; ---- Universes ----
    ;; Type(n) : Type(n+1)
    [(expr-Type l) (expr-Type (lsuc l))]

    ;; ---- Pi type formation ----
    ;; Pi(m, A, B) : Type(max(level(A), level(B)))
    [(expr-Pi m a b)
     (match (infer-level ctx (expr-Pi m a b))
       [(just-level l) (expr-Type l)]
       [_ (expr-error)])]

    ;; ---- Sigma type formation ----
    ;; Sigma(A, B) : Type(max(level(A), level(B)))
    [(expr-Sigma a b)
     (match (infer-level ctx (expr-Sigma a b))
       [(just-level l) (expr-Type l)]
       [_ (expr-error)])]

    ;; ---- Eq type formation ----
    ;; Eq(A, a, b) : Type(level(A))
    [(expr-Eq a e1 e2)
     (match (infer-level ctx (expr-Eq a e1 e2))
       [(just-level l) (expr-Type l)]
       [_ (expr-error)])]

    ;; ---- Union type formation ----
    ;; A | B : Type(max(level(A), level(B)))
    [(expr-union l r)
     (match (infer-level ctx (expr-union l r))
       [(just-level lv) (expr-Type lv)]
       [_ (expr-error)])]

    ;; ---- Unapplied type constructor (HKT) ----
    ;; Returns the kind as a curried Pi type: Type -> Type -> ... -> Type
    ;; Arity from builtin-tycon-arity table
    [(expr-tycon name)
     (let ([arity (tycon-arity name)])
       (if arity
           (let loop ([n arity])
             (if (= n 0)
                 (expr-Type (lzero))
                 (expr-Pi 'm0 (expr-Type (lzero)) (loop (sub1 n)))))
           (expr-error)))]

    ;; ---- Open type (PPN 4C T-2, 2026-04-23) ----

    ;; ---- Natural numbers ----
    [(expr-Nat) (expr-Type (lzero))]
    [(expr-zero) (expr-Nat)]
    [(expr-nat-val _) (expr-Nat)]
    ;; suc in synthesis: if argument infers to Nat
    [(expr-suc e1)
     (if (equal? (infer ctx e1) (expr-Nat))
         (expr-Nat)
         (expr-error))]

    ;; ---- Booleans ----
    [(expr-Bool) (expr-Type (lzero))]
    [(expr-true) (expr-Bool)]
    [(expr-false) (expr-Bool)]

    ;; ---- Unit ----
    [(expr-Unit) (expr-Type (lzero))]
    [(expr-unit) (expr-Unit)]

    ;; ---- Nil ----
    [(expr-Nil) (expr-Type (lzero))]
    ;; nil value: inferred type is Nil (the nullable type).
    ;; Note: when List's nil constructor is loaded, the elaborator produces (expr-fvar 'nil)
    ;; instead — this case only fires for bare Nil usage without List loaded.
    [(expr-nil) (expr-Nil)]

    ;; ---- Annotated terms ----
    ;; ann(e, T) synthesizes T if T is a type and e checks against T
    [(expr-ann e1 t)
     ;; Numerics N5de: ascription to a refined numeric type is an ERASED NARROWING CAST
     ;; (unsafe; scoped to `the` — NOT the general conversion fallback, so the invariant
     ;; that Int </: PosInt is preserved elsewhere). Check the operand against the BASE
     ;; (Int/Rat) and re-type to the refined type. `the` already erases to e1 at runtime.
     (let ([tw (whnf t)])
       (cond
         [(and (expr-fvar? tw) (refined-name? (expr-fvar-name tw)))
          (if (check ctx e1 (refined-base->expr (refined-name->base (expr-fvar-name tw))))
              t
              (expr-error))]
         [(and (is-type ctx t) (check ctx e1 t)) t]
         [else (expr-error)]))]

    ;; ---- Lambda with explicit domain: synthesize Pi type ----
    ;; Enables inference of bare lambdas (e.g., multi-bracket fn) at top level.
    ;; Only fires when the domain annotation is a concrete type, not a hole.
    [(expr-lam m dom body)
     (cond
       [(expr-hole? dom) (expr-error)]  ;; can't infer without context
       [(not (is-type ctx dom)) (expr-error)]
       [else
        (let ([body-ty (infer (ctx-extend ctx dom m) body)])
          (if (equal? body-ty (expr-error))
              (expr-error)
              (expr-Pi m dom body-ty)))])]

    ;; ---- Pi elimination (application) ----
    [(expr-app e1 e2)
     (cond
       ;; Issue #71: a saturated multi-hole explicit-hole section applied in
       ;; infer position (`[[- _ _] 10 3]`) — whnf-reduce to the lambda-free
       ;; concrete form, which the ordinary rules type. The guard fires ONLY on
       ;; the failing set (>=2 nested hole lambdas + saturated): single-hole
       ;; sections + single-beta let-expansion (below) and under-applied def-RHS
       ;; sections stay on their existing paths. Mirrored in qtt inferQ.
       ;; (On-network install has no twin: a saturated section leaves ⊥ there →
       ;;  driver.rkt:585 falls back to this imperative infer — sound, no divergence.)
       [(saturated-hole-section-app? e) (infer ctx (whnf e))]
       ;; Issue #70 (N6e-E5, R2-spine): an application spine containing a
       ;; hole-domain-lambda argument (`[map [+ _ 1] xs]`, `[map [fn [x] …] xs]`).
       ;; The default one-arg-per-node walk checks the fn BEFORE the container
       ;; that solves the shared element meta, and the fn's failure kills the
       ;; app before the container is ever visited. Fix: walk the whole spine,
       ;; DEFER checking hole-domain-lambda args (substitute-and-continue —
       ;; subst uses the arg EXPRESSION, so deferral never blocks dependent
       ;; codomains), check everything else left-to-right, then run the
       ;; deferred checks (their domains' metas now solved by the later args;
       ;; numeric-join resolves solved metas per R1-join above).
       ;; Soundness: no stdlib HOF Pi is term-dependent between explicit args
       ;; (surf-arrow emits anonymous binders — grounded at E5 open); the walk
       ;; order is unchanged, only CHECK order moves. Head-lam spines are
       ;; excluded (beta/let-expansion + #71 keep their paths).
       ;; Stage twins deliberately ABSENT: qtt runs post-freeze (solved metas
       ;; already substituted — the trigger is erased before inferQ); the
       ;; on-network path leaves the op position at ⊥ and driver.rkt:585 falls
       ;; back here (verified: it cannot ship a wrong type for this shape).
       [(app-spine-with-deferrable-fn? e) (infer-app-spine-deferred ctx e)]
       [else
     (match e1
       ;; Special case: ((lam m A body) arg) — direct beta-typed application
       ;; The lambda's domain gives us the argument type, and we infer the body
       ;; type in the extended context. This supports let-expansion and similar patterns.
       [(expr-lam m dom body)
        (cond
          ;; Hole domain: infer arg type and use as domain (let type inference)
          [(expr-hole? dom)
           (let ([arg-ty (infer ctx e2)])
             (if (equal? arg-ty (expr-error))
                 (expr-error)
                 (let ([body-ty (infer (ctx-extend ctx arg-ty m) body)])
                   (if (equal? body-ty (expr-error))
                       (expr-error)
                       (subst 0 e2 body-ty)))))]
          ;; Explicit domain: check arg against it
          [(and (is-type ctx dom)
                (check ctx e2 dom))
           (let ([body-ty (infer (ctx-extend ctx dom m) body)])
             (if (equal? body-ty (expr-error))
                 (expr-error)
                 (subst 0 e2 body-ty)))]
          [else (expr-error)])]
       ;; General case: infer function type, check argument
       [_
        (let ([t1 (whnf (infer ctx e1))])
          (cond
            ;; Direct Pi: existing fast path
            [(expr-Pi? t1)
             (if (check ctx e2 (expr-Pi-domain t1))
                 (subst 0 e2 (expr-Pi-codomain t1))
                 (expr-error))]
            ;; SRE Track 2H Phase 5: Union type → distribute via tensor (scaffolding)
            ;; type-tensor-core returns bot for inapplicable (F1), so
            ;; type-tensor-distribute may return bot (all inapplicable)
            ;; or top (contradiction). Both → expr-error.
            [(expr-union? t1)
             (let ([arg-ty (infer ctx e2)])
               (if (expr-error? arg-ty)
                   (expr-error)
                   (let ([result (type-tensor-distribute t1 arg-ty)])
                     ;; type-bot = 'type-bot, type-top = 'type-top (sentinel symbols)
                     (if (or (eq? result 'type-bot) (eq? result 'type-top))
                         (expr-error)
                         result))))]
            [else (expr-error)]))])])]

    ;; ---- Sigma elimination: fst ----
    [(expr-fst e1)
     (let ([t (whnf (infer ctx e1))])
       (match t
         [(expr-Sigma a _) a]
         [_ (expr-error)]))]

    ;; ---- Sigma elimination: snd ----
    [(expr-snd e1)
     (let ([t (whnf (infer ctx e1))])
       (match t
         [(expr-Sigma _ b) (subst 0 (expr-fst e1) b)]
         [_ (expr-error)]))]

    ;; ---- Bool eliminator (boolrec) ----
    ;; boolrec(motive, true-case, false-case, target)
    ;; motive : Bool -> Type(l)
    ;; true-case : motive(true)
    ;; false-case : motive(false)
    ;; target : Bool
    ;; result type: app(motive, target)
    ;;
    ;; Note: The motive's codomain is not explicitly verified to be Type(l).
    ;; This is safe because the result type app(mot, target) propagates upward,
    ;; and any consumer that uses it as a type will fail if it's not one.
    ;; Adding is-type here causes re-entrancy issues with mult-meta solving.
    [(expr-boolrec mot tc fc target)
     (let ([mot-ty (whnf (infer ctx mot))])
       (match mot-ty
         [(expr-Pi _ dom _)
          ;; When the motive body is a hole (from 3-arg `if`), the result type
          ;; (app mot true) reduces to (expr-hole), which accepts any type without
          ;; solving. Replace with a fresh meta so branch checking solves it.
          (let* ([result-tc (nf (expr-app mot (expr-true)))]
                 [use-meta? (expr-hole? result-tc)]
                 [mot* (if use-meta?
                           (let ([m (fresh-meta ctx (expr-Type (lzero)) "if-motive")])
                             (expr-ann (expr-lam 'mw (expr-Bool) m)
                                       (expr-Pi 'mw (expr-Bool) (expr-Type (lzero)))))
                           mot)])
            (if (and (unify-ok? (unify ctx dom (expr-Bool)))
                     (check ctx tc (nf (expr-app mot* (expr-true))))
                     (check ctx fc (nf (expr-app mot* (expr-false))))
                     (check ctx target (expr-Bool)))
                (nf (expr-app mot* target))
                (expr-error)))]
         [_ (expr-error)]))]

    ;; ---- Nat eliminator (natrec) ----
    ;; natrec(motive, base, step, target)
    ;; motive : Nat → Type(l)
    ;; base   : motive(zero)
    ;; step   : Π(n:Nat). motive(n) → motive(suc(n))
    ;; target : Nat
    ;; result type: app(motive, target)
    [(expr-natrec mot base step target)
     (let ([step-type
            ;; Π(n:Nat). motive(n) → motive(suc(n))
            ;; Under one binder (n), mot must be shifted by 1.
            ;; Under two binders (n, rec), mot must be shifted by 2.
            (expr-Pi 'mw (expr-Nat)
              (expr-Pi 'mw (expr-app (shift 1 0 mot) (expr-bvar 0))
                (expr-app (shift 2 0 mot) (expr-suc (expr-bvar 1)))))])
       (if (and (check ctx target (expr-Nat))
                (check ctx base (expr-app mot (expr-zero)))
                (check ctx step step-type))
           (expr-app mot target)
           (expr-error)))]

    ;; ---- J eliminator ----
    ;; J(motive, base, left, right, proof)
    ;; motive : Π(a:A). Π(b:A). Eq(A,a,b) → Type(l)
    ;; base   : Π(a:A). motive(a, a, refl)
    ;; proof  : Eq(A, left, right)
    ;; result type: app(app(app(motive, left), right), proof)
    ;;
    ;; Note: The motive's codomain is not explicitly checked to be Type(l).
    ;; This is safe because the result type propagates upward, and any consumer
    ;; that uses it as a type will fail if it's not one. Adding is-type here
    ;; causes re-entrancy issues with mult-meta solving.
    [(expr-J mot base left right proof)
     (let ([pt (whnf (infer ctx proof))])
       (match pt
         [(expr-Eq t t1 t2)
          (if (and (unify-ok? (unify ctx t1 left))
                   (unify-ok? (unify ctx t2 right))
                   ;; Verify base has correct type: Π(a:A). motive(a, a, refl)
                   (check ctx base
                     (expr-Pi 'mw t
                       (expr-app (expr-app (expr-app (shift 1 0 mot) (expr-bvar 0))
                                           (expr-bvar 0))
                                 (expr-refl)))))
              (expr-app (expr-app (expr-app mot left) right) proof)
              (expr-error))]
         [_ (expr-error)]))]

    ;; ---- Vec eliminators ----
    ;; vhead(A, n, v) : A  when v : Vec(A, suc(n))
    [(expr-vhead a n v)
     (if (check ctx v (expr-Vec a (expr-suc n)))
         a
         (expr-error))]

    ;; vtail(A, n, v) : Vec(A, n)  when v : Vec(A, suc(n))
    [(expr-vtail a n v)
     (if (check ctx v (expr-Vec a (expr-suc n)))
         (expr-Vec a n)
         (expr-error))]

    ;; vindex(A, n, i, v) : A  when i : Fin(n) and v : Vec(A, n)
    [(expr-vindex a n i v)
     (if (and (check ctx i (expr-Fin n))
              (check ctx v (expr-Vec a n)))
         a
         (expr-error))]

    ;; ---- Int (arbitrary-precision integers) ----
    [(expr-Int) (expr-Type (lzero))]

    ;; int literal: val must be a Racket exact integer
    [(expr-int v)
     (if (exact-integer? v)
         (expr-Int)
         (expr-error))]

    ;; Binary arithmetic: Int -> Int -> Int
    [(expr-int-add a b)
     (if (and (check ctx a (expr-Int)) (check ctx b (expr-Int)))
         (expr-Int) (expr-error))]
    [(expr-int-sub a b)
     (if (and (check ctx a (expr-Int)) (check ctx b (expr-Int)))
         (expr-Int) (expr-error))]
    [(expr-int-mul a b)
     (if (and (check ctx a (expr-Int)) (check ctx b (expr-Int)))
         (expr-Int) (expr-error))]
    [(expr-int-div a b)
     (if (and (check ctx a (expr-Int)) (check ctx b (expr-Int)))
         (expr-Int) (expr-error))]
    [(expr-int-mod a b)
     (if (and (check ctx a (expr-Int)) (check ctx b (expr-Int)))
         (expr-Int) (expr-error))]

    ;; Unary ops: Int -> Int
    [(expr-int-neg a)
     (if (check ctx a (expr-Int)) (expr-Int) (expr-error))]
    [(expr-int-abs a)
     (if (check ctx a (expr-Int)) (expr-Int) (expr-error))]

    ;; Comparison: Int -> Int -> Bool
    [(expr-int-lt a b)
     (if (and (check ctx a (expr-Int)) (check ctx b (expr-Int)))
         (expr-Bool) (expr-error))]
    [(expr-int-le a b)
     (if (and (check ctx a (expr-Int)) (check ctx b (expr-Int)))
         (expr-Bool) (expr-error))]
    [(expr-int-eq a b)
     (if (and (check ctx a (expr-Int)) (check ctx b (expr-Int)))
         (expr-Bool) (expr-error))]

    ;; Conversion: Nat -> Int
    [(expr-from-nat n)
     (if (check ctx n (expr-Nat)) (expr-Int) (expr-error))]

    ;; ---- Rat (exact rationals) ----
    [(expr-Rat) (expr-Type (lzero))]

    ;; rat literal: val must be a Racket exact rational
    [(expr-rat v)
     (if (and (exact? v) (rational? v))
         (expr-Rat)
         (expr-error))]

    ;; Binary arithmetic: Rat -> Rat -> Rat
    [(expr-rat-add a b)
     (if (and (check ctx a (expr-Rat)) (check ctx b (expr-Rat)))
         (expr-Rat) (expr-error))]
    [(expr-rat-sub a b)
     (if (and (check ctx a (expr-Rat)) (check ctx b (expr-Rat)))
         (expr-Rat) (expr-error))]
    [(expr-rat-mul a b)
     (if (and (check ctx a (expr-Rat)) (check ctx b (expr-Rat)))
         (expr-Rat) (expr-error))]
    [(expr-rat-div a b)
     (if (and (check ctx a (expr-Rat)) (check ctx b (expr-Rat)))
         (expr-Rat) (expr-error))]

    ;; Unary ops: Rat -> Rat
    [(expr-rat-neg a)
     (if (check ctx a (expr-Rat)) (expr-Rat) (expr-error))]
    [(expr-rat-abs a)
     (if (check ctx a (expr-Rat)) (expr-Rat) (expr-error))]

    ;; Comparison: Rat -> Rat -> Bool
    [(expr-rat-lt a b)
     (if (and (check ctx a (expr-Rat)) (check ctx b (expr-Rat)))
         (expr-Bool) (expr-error))]
    [(expr-rat-le a b)
     (if (and (check ctx a (expr-Rat)) (check ctx b (expr-Rat)))
         (expr-Bool) (expr-error))]
    [(expr-rat-eq a b)
     (if (and (check ctx a (expr-Rat)) (check ctx b (expr-Rat)))
         (expr-Bool) (expr-error))]

    ;; Conversion: Int -> Rat
    [(expr-from-int n)
     (if (check ctx n (expr-Int)) (expr-Rat) (expr-error))]

    ;; Projections: Rat -> Int
    [(expr-rat-numer a)
     (if (check ctx a (expr-Rat)) (expr-Int) (expr-error))]
    [(expr-rat-denom a)
     (if (check ctx a (expr-Rat)) (expr-Int) (expr-error))]

    ;; ---- Generic arithmetic operators ----
    ;; Binary arithmetic: T1 -> T2 -> join(T1,T2) (coercion via numeric-join)
    [(expr-generic-add a b)
     (let* ([ta (infer ctx a)] [tb (infer ctx b)]
            [j (numeric-join/warn! ta tb a b)])
       (if j (refine-arith ta tb j sign-transfer-add) (expr-error)))]
    [(expr-generic-sub a b)
     (let* ([ta (infer ctx a)] [tb (infer ctx b)]
            [j (numeric-join/warn! ta tb a b)])
       (if j (refine-arith ta tb j sign-transfer-sub) (expr-error)))]
    [(expr-generic-mul a b)
     (let* ([ta (infer ctx a)] [tb (infer ctx b)]
            [j (numeric-join/warn! ta tb a b)])
       (if j (refine-arith ta tb j sign-transfer-mul) (expr-error)))]
    [(expr-generic-div a b)
     (let* ([ta (infer ctx a)] [tb (infer ctx b)]
            [j (numeric-join/warn! ta tb a b)])
       (if (and j (divisible-numeric-type? j)) (refine-arith ta tb j sign-transfer-div) (expr-error)))]

    ;; Binary comparison: T1 -> T2 -> Bool (coercion via numeric-join)
    [(expr-generic-lt a b)
     (let* ([ta (infer ctx a)] [tb (infer ctx b)]
            [j (numeric-join/warn! ta tb a b)])
       (if j (expr-Bool) (expr-error)))]
    [(expr-generic-le a b)
     (let* ([ta (infer ctx a)] [tb (infer ctx b)]
            [j (numeric-join/warn! ta tb a b)])
       (if j (expr-Bool) (expr-error)))]
    [(expr-generic-gt a b)
     (let* ([ta (infer ctx a)] [tb (infer ctx b)]
            [j (numeric-join/warn! ta tb a b)])
       (if j (expr-Bool) (expr-error)))]
    [(expr-generic-ge a b)
     (let* ([ta (infer ctx a)] [tb (infer ctx b)]
            [j (numeric-join/warn! ta tb a b)])
       (if j (expr-Bool) (expr-error)))]
    [(expr-generic-eq a b)
     (let* ([ta (infer ctx a)] [tb (infer ctx b)]
            [j (numeric-join/warn! ta tb a b)])
       (if j (expr-Bool) (expr-error)))]
    [(expr-generic-mod a b)
     (let* ([ta (infer ctx a)] [tb (infer ctx b)]
            [j (numeric-join/warn! ta tb a b)])
       (if j j (expr-error)))]

    ;; Unary: T -> T  (Numerics N5de: guard on the BASE — refined operands strip to Int/Rat —
    ;; then re-refine via the sign transfer; also fixes `abs NegInt → PosInt`.)
    [(expr-generic-negate a)
     (let* ([ta (infer ctx a)] [tb (base-numeric-type ta)])
       (if (negatable-numeric-type? tb)
           (refine-arith1 ta tb sign-transfer-neg)
           (expr-error)))]
    [(expr-generic-abs a)
     (let* ([ta (infer ctx a)] [tb (base-numeric-type ta)])
       (if (concrete-numeric-type? tb)
           (refine-arith1 ta tb sign-transfer-abs)
           (expr-error)))]

    ;; Generic conversion: from-integer TargetType val (Int -> T)
    [(expr-generic-from-int target-type arg)
     (let ([tt (infer ctx target-type)])
       (cond
         [(not (expr-Type? tt)) (expr-error)]   ; target must be a type
         [(not (from-int-target-type? target-type)) (expr-error)]
         [(not (check ctx arg (expr-Int))) (expr-error)]
         [else target-type]))]
    ;; Generic conversion: from-rational TargetType val (Rat -> T)
    [(expr-generic-from-rat target-type arg)
     (let ([tt (infer ctx target-type)])
       (cond
         [(not (expr-Type? tt)) (expr-error)]   ; target must be a type
         [(not (from-rat-target-type? target-type)) (expr-error)]
         [(not (check ctx arg (expr-Rat))) (expr-error)]
         [else target-type]))]

    ;; ---- Posit8 ----
    [(expr-Posit8) (expr-Type (lzero))]

    ;; posit8 literal
    [(expr-posit8 v)
     (if (and (exact-integer? v) (<= 0 v 255))
         (expr-Posit8)
         (expr-error))]

    ;; Binary arithmetic: Posit8 -> Posit8 -> Posit8
    [(expr-p8-add a b)
     (if (and (check ctx a (expr-Posit8)) (check ctx b (expr-Posit8)))
         (expr-Posit8) (expr-error))]
    [(expr-p8-sub a b)
     (if (and (check ctx a (expr-Posit8)) (check ctx b (expr-Posit8)))
         (expr-Posit8) (expr-error))]
    [(expr-p8-mul a b)
     (if (and (check ctx a (expr-Posit8)) (check ctx b (expr-Posit8)))
         (expr-Posit8) (expr-error))]
    [(expr-p8-div a b)
     (if (and (check ctx a (expr-Posit8)) (check ctx b (expr-Posit8)))
         (expr-Posit8) (expr-error))]

    ;; Unary ops: Posit8 -> Posit8
    [(expr-p8-neg a)
     (if (check ctx a (expr-Posit8)) (expr-Posit8) (expr-error))]
    [(expr-p8-abs a)
     (if (check ctx a (expr-Posit8)) (expr-Posit8) (expr-error))]
    [(expr-p8-sqrt a)
     (if (check ctx a (expr-Posit8)) (expr-Posit8) (expr-error))]

    ;; Comparison: Posit8 -> Posit8 -> Bool
    [(expr-p8-lt a b)
     (if (and (check ctx a (expr-Posit8)) (check ctx b (expr-Posit8)))
         (expr-Bool) (expr-error))]
    [(expr-p8-le a b)
     (if (and (check ctx a (expr-Posit8)) (check ctx b (expr-Posit8)))
         (expr-Bool) (expr-error))]
    [(expr-p8-eq a b)
     (if (and (check ctx a (expr-Posit8)) (check ctx b (expr-Posit8)))
         (expr-Bool) (expr-error))]

    ;; Conversion: Nat -> Posit8
    [(expr-p8-from-nat n)
     (if (check ctx n (expr-Nat)) (expr-Posit8) (expr-error))]

    ;; Phase 3f: Cross-family conversions for Posit8
    [(expr-p8-to-rat a)
     (if (check ctx a (expr-Posit8)) (expr-Rat) (expr-error))]
    [(expr-p8-from-rat a)
     (if (check ctx a (expr-Rat)) (expr-Posit8) (expr-error))]
    [(expr-p8-from-int a)
     (if (check ctx a (expr-Int)) (expr-Posit8) (expr-error))]

    ;; p8-if-nar(A, nar-case, normal-case, val) : A
    [(expr-p8-if-nar tp nc vc v)
     (if (and (is-type ctx tp)
              (check ctx nc tp)
              (check ctx vc tp)
              (check ctx v (expr-Posit8)))
         tp (expr-error))]

    ;; ---- Posit16 ----
    [(expr-Posit16) (expr-Type (lzero))]

    ;; posit16 literal
    [(expr-posit16 v)
     (if (and (exact-integer? v) (<= 0 v 65535))
         (expr-Posit16)
         (expr-error))]

    ;; Binary arithmetic: Posit16 -> Posit16 -> Posit16
    [(expr-p16-add a b)
     (if (and (check ctx a (expr-Posit16)) (check ctx b (expr-Posit16)))
         (expr-Posit16) (expr-error))]
    [(expr-p16-sub a b)
     (if (and (check ctx a (expr-Posit16)) (check ctx b (expr-Posit16)))
         (expr-Posit16) (expr-error))]
    [(expr-p16-mul a b)
     (if (and (check ctx a (expr-Posit16)) (check ctx b (expr-Posit16)))
         (expr-Posit16) (expr-error))]
    [(expr-p16-div a b)
     (if (and (check ctx a (expr-Posit16)) (check ctx b (expr-Posit16)))
         (expr-Posit16) (expr-error))]

    ;; Unary ops: Posit16 -> Posit16
    [(expr-p16-neg a)
     (if (check ctx a (expr-Posit16)) (expr-Posit16) (expr-error))]
    [(expr-p16-abs a)
     (if (check ctx a (expr-Posit16)) (expr-Posit16) (expr-error))]
    [(expr-p16-sqrt a)
     (if (check ctx a (expr-Posit16)) (expr-Posit16) (expr-error))]

    ;; Comparison: Posit16 -> Posit16 -> Bool
    [(expr-p16-lt a b)
     (if (and (check ctx a (expr-Posit16)) (check ctx b (expr-Posit16)))
         (expr-Bool) (expr-error))]
    [(expr-p16-le a b)
     (if (and (check ctx a (expr-Posit16)) (check ctx b (expr-Posit16)))
         (expr-Bool) (expr-error))]
    [(expr-p16-eq a b)
     (if (and (check ctx a (expr-Posit16)) (check ctx b (expr-Posit16)))
         (expr-Bool) (expr-error))]

    ;; Conversion: Nat -> Posit16
    [(expr-p16-from-nat n)
     (if (check ctx n (expr-Nat)) (expr-Posit16) (expr-error))]

    ;; Phase 3f: Cross-family conversions for Posit16
    [(expr-p16-to-rat a)
     (if (check ctx a (expr-Posit16)) (expr-Rat) (expr-error))]
    [(expr-p16-from-rat a)
     (if (check ctx a (expr-Rat)) (expr-Posit16) (expr-error))]
    [(expr-p16-from-int a)
     (if (check ctx a (expr-Int)) (expr-Posit16) (expr-error))]

    ;; p16-if-nar(A, nar-case, normal-case, val) : A
    [(expr-p16-if-nar tp nc vc v)
     (if (and (is-type ctx tp)
              (check ctx nc tp)
              (check ctx vc tp)
              (check ctx v (expr-Posit16)))
         tp (expr-error))]

    ;; ---- Posit32 ----
    [(expr-Posit32) (expr-Type (lzero))]

    ;; posit32 literal
    [(expr-posit32 v)
     (if (and (exact-integer? v) (<= 0 v 4294967295))
         (expr-Posit32)
         (expr-error))]

    ;; ---- Float (Numerics N3): val is a Racket flonum (incl. +nan.0/+inf.0) ----
    [(expr-Float32) (expr-Type (lzero))]
    [(expr-float32 v) (if (flonum? v) (expr-Float32) (expr-error))]
    [(expr-Float64) (expr-Type (lzero))]
    [(expr-float64 v) (if (flonum? v) (expr-Float64) (expr-error))]

    ;; Float ops (Numerics N3b): arith FloatN -> FloatN -> FloatN; compare -> Bool
    [(expr-f32-add a b) (if (and (check ctx a (expr-Float32)) (check ctx b (expr-Float32))) (expr-Float32) (expr-error))]
    [(expr-f32-sub a b) (if (and (check ctx a (expr-Float32)) (check ctx b (expr-Float32))) (expr-Float32) (expr-error))]
    [(expr-f32-mul a b) (if (and (check ctx a (expr-Float32)) (check ctx b (expr-Float32))) (expr-Float32) (expr-error))]
    [(expr-f32-div a b) (if (and (check ctx a (expr-Float32)) (check ctx b (expr-Float32))) (expr-Float32) (expr-error))]
    [(expr-f32-neg a) (if (check ctx a (expr-Float32)) (expr-Float32) (expr-error))]
    [(expr-f32-abs a) (if (check ctx a (expr-Float32)) (expr-Float32) (expr-error))]
    [(expr-f32-sqrt a) (if (check ctx a (expr-Float32)) (expr-Float32) (expr-error))]
    [(expr-f32-lt a b) (if (and (check ctx a (expr-Float32)) (check ctx b (expr-Float32))) (expr-Bool) (expr-error))]
    [(expr-f32-le a b) (if (and (check ctx a (expr-Float32)) (check ctx b (expr-Float32))) (expr-Bool) (expr-error))]
    [(expr-f32-eq a b) (if (and (check ctx a (expr-Float32)) (check ctx b (expr-Float32))) (expr-Bool) (expr-error))]
    [(expr-f64-add a b) (if (and (check ctx a (expr-Float64)) (check ctx b (expr-Float64))) (expr-Float64) (expr-error))]
    [(expr-f64-sub a b) (if (and (check ctx a (expr-Float64)) (check ctx b (expr-Float64))) (expr-Float64) (expr-error))]
    [(expr-f64-mul a b) (if (and (check ctx a (expr-Float64)) (check ctx b (expr-Float64))) (expr-Float64) (expr-error))]
    [(expr-f64-div a b) (if (and (check ctx a (expr-Float64)) (check ctx b (expr-Float64))) (expr-Float64) (expr-error))]
    [(expr-f64-neg a) (if (check ctx a (expr-Float64)) (expr-Float64) (expr-error))]
    [(expr-f64-abs a) (if (check ctx a (expr-Float64)) (expr-Float64) (expr-error))]
    [(expr-f64-sqrt a) (if (check ctx a (expr-Float64)) (expr-Float64) (expr-error))]
    [(expr-f64-lt a b) (if (and (check ctx a (expr-Float64)) (check ctx b (expr-Float64))) (expr-Bool) (expr-error))]
    [(expr-f64-le a b) (if (and (check ctx a (expr-Float64)) (check ctx b (expr-Float64))) (expr-Bool) (expr-error))]
    [(expr-f64-eq a b) (if (and (check ctx a (expr-Float64)) (check ctx b (expr-Float64))) (expr-Bool) (expr-error))]

    ;; Cross-width Float conversions (Numerics N3e-rest): arg is Float32 OR Float64.
    [(expr-float-finite a)
     (if (float-type? (whnf (infer ctx a))) (expr-Bool) (expr-error))]
    [(expr-float-to-rat a)
     (if (float-type? (whnf (infer ctx a))) (expr-Rat) (expr-error))]
    [(expr-float-to-int a)
     (if (float-type? (whnf (infer ctx a))) (expr-Int) (expr-error))]
    [(expr-float-to-float32 a)
     (if (float-type? (whnf (infer ctx a))) (expr-Float32) (expr-error))]

    ;; Binary arithmetic: Posit32 -> Posit32 -> Posit32
    [(expr-p32-add a b)
     (if (and (check ctx a (expr-Posit32)) (check ctx b (expr-Posit32)))
         (expr-Posit32) (expr-error))]
    [(expr-p32-sub a b)
     (if (and (check ctx a (expr-Posit32)) (check ctx b (expr-Posit32)))
         (expr-Posit32) (expr-error))]
    [(expr-p32-mul a b)
     (if (and (check ctx a (expr-Posit32)) (check ctx b (expr-Posit32)))
         (expr-Posit32) (expr-error))]
    [(expr-p32-div a b)
     (if (and (check ctx a (expr-Posit32)) (check ctx b (expr-Posit32)))
         (expr-Posit32) (expr-error))]

    ;; Unary ops: Posit32 -> Posit32
    [(expr-p32-neg a)
     (if (check ctx a (expr-Posit32)) (expr-Posit32) (expr-error))]
    [(expr-p32-abs a)
     (if (check ctx a (expr-Posit32)) (expr-Posit32) (expr-error))]
    [(expr-p32-sqrt a)
     (if (check ctx a (expr-Posit32)) (expr-Posit32) (expr-error))]

    ;; Comparison: Posit32 -> Posit32 -> Bool
    [(expr-p32-lt a b)
     (if (and (check ctx a (expr-Posit32)) (check ctx b (expr-Posit32)))
         (expr-Bool) (expr-error))]
    [(expr-p32-le a b)
     (if (and (check ctx a (expr-Posit32)) (check ctx b (expr-Posit32)))
         (expr-Bool) (expr-error))]
    [(expr-p32-eq a b)
     (if (and (check ctx a (expr-Posit32)) (check ctx b (expr-Posit32)))
         (expr-Bool) (expr-error))]

    ;; Conversion: Nat -> Posit32
    [(expr-p32-from-nat n)
     (if (check ctx n (expr-Nat)) (expr-Posit32) (expr-error))]

    ;; Phase 3f: Cross-family conversions for Posit32
    [(expr-p32-to-rat a)
     (if (check ctx a (expr-Posit32)) (expr-Rat) (expr-error))]
    [(expr-p32-from-rat a)
     (if (check ctx a (expr-Rat)) (expr-Posit32) (expr-error))]
    [(expr-p32-from-int a)
     (if (check ctx a (expr-Int)) (expr-Posit32) (expr-error))]

    ;; p32-if-nar(A, nar-case, normal-case, val) : A
    [(expr-p32-if-nar tp nc vc v)
     (if (and (is-type ctx tp)
              (check ctx nc tp)
              (check ctx vc tp)
              (check ctx v (expr-Posit32)))
         tp (expr-error))]

    ;; ---- Posit64 ----
    [(expr-Posit64) (expr-Type (lzero))]

    ;; posit64 literal
    [(expr-posit64 v)
     (if (and (exact-integer? v) (<= 0 v 18446744073709551615))
         (expr-Posit64)
         (expr-error))]

    ;; Binary arithmetic: Posit64 -> Posit64 -> Posit64
    [(expr-p64-add a b)
     (if (and (check ctx a (expr-Posit64)) (check ctx b (expr-Posit64)))
         (expr-Posit64) (expr-error))]
    [(expr-p64-sub a b)
     (if (and (check ctx a (expr-Posit64)) (check ctx b (expr-Posit64)))
         (expr-Posit64) (expr-error))]
    [(expr-p64-mul a b)
     (if (and (check ctx a (expr-Posit64)) (check ctx b (expr-Posit64)))
         (expr-Posit64) (expr-error))]
    [(expr-p64-div a b)
     (if (and (check ctx a (expr-Posit64)) (check ctx b (expr-Posit64)))
         (expr-Posit64) (expr-error))]

    ;; Unary ops: Posit64 -> Posit64
    [(expr-p64-neg a)
     (if (check ctx a (expr-Posit64)) (expr-Posit64) (expr-error))]
    [(expr-p64-abs a)
     (if (check ctx a (expr-Posit64)) (expr-Posit64) (expr-error))]
    [(expr-p64-sqrt a)
     (if (check ctx a (expr-Posit64)) (expr-Posit64) (expr-error))]

    ;; Comparison: Posit64 -> Posit64 -> Bool
    [(expr-p64-lt a b)
     (if (and (check ctx a (expr-Posit64)) (check ctx b (expr-Posit64)))
         (expr-Bool) (expr-error))]
    [(expr-p64-le a b)
     (if (and (check ctx a (expr-Posit64)) (check ctx b (expr-Posit64)))
         (expr-Bool) (expr-error))]
    [(expr-p64-eq a b)
     (if (and (check ctx a (expr-Posit64)) (check ctx b (expr-Posit64)))
         (expr-Bool) (expr-error))]

    ;; Conversion: Nat -> Posit64
    [(expr-p64-from-nat n)
     (if (check ctx n (expr-Nat)) (expr-Posit64) (expr-error))]

    ;; Phase 3f: Cross-family conversions for Posit64
    [(expr-p64-to-rat a)
     (if (check ctx a (expr-Posit64)) (expr-Rat) (expr-error))]
    [(expr-p64-from-rat a)
     (if (check ctx a (expr-Rat)) (expr-Posit64) (expr-error))]
    [(expr-p64-from-int a)
     (if (check ctx a (expr-Int)) (expr-Posit64) (expr-error))]

    ;; p64-if-nar(A, nar-case, normal-case, val) : A
    [(expr-p64-if-nar tp nc vc v)
     (if (and (is-type ctx tp)
              (check ctx nc tp)
              (check ctx vc tp)
              (check ctx v (expr-Posit64)))
         tp (expr-error))]

    ;; ---- Quire types ----
    ;; QuireW : Type 0
    [(expr-Quire8) (expr-Type (lzero))]
    [(expr-Quire16) (expr-Type (lzero))]
    [(expr-Quire32) (expr-Type (lzero))]
    [(expr-Quire64) (expr-Type (lzero))]

    ;; quireW-val: runtime literal → QuireW
    [(expr-quire8-val _) (expr-Quire8)]
    [(expr-quire16-val _) (expr-Quire16)]
    [(expr-quire32-val _) (expr-Quire32)]
    [(expr-quire64-val _) (expr-Quire64)]

    ;; quireW-fma: QuireW → PositW → PositW → QuireW
    [(expr-quire8-fma q a b)
     (if (and (check ctx q (expr-Quire8))
              (check ctx a (expr-Posit8))
              (check ctx b (expr-Posit8)))
         (expr-Quire8) (expr-error))]
    [(expr-quire16-fma q a b)
     (if (and (check ctx q (expr-Quire16))
              (check ctx a (expr-Posit16))
              (check ctx b (expr-Posit16)))
         (expr-Quire16) (expr-error))]
    [(expr-quire32-fma q a b)
     (if (and (check ctx q (expr-Quire32))
              (check ctx a (expr-Posit32))
              (check ctx b (expr-Posit32)))
         (expr-Quire32) (expr-error))]
    [(expr-quire64-fma q a b)
     (if (and (check ctx q (expr-Quire64))
              (check ctx a (expr-Posit64))
              (check ctx b (expr-Posit64)))
         (expr-Quire64) (expr-error))]

    ;; quireW-to: QuireW → PositW
    [(expr-quire8-to q)
     (if (check ctx q (expr-Quire8)) (expr-Posit8) (expr-error))]
    [(expr-quire16-to q)
     (if (check ctx q (expr-Quire16)) (expr-Posit16) (expr-error))]
    [(expr-quire32-to q)
     (if (check ctx q (expr-Quire32)) (expr-Posit32) (expr-error))]
    [(expr-quire64-to q)
     (if (check ctx q (expr-Quire64)) (expr-Posit64) (expr-error))]

    ;; ---- Symbol type and literals ----
    [(expr-Symbol) (expr-Type (lzero))]
    [(expr-symbol _) (expr-Symbol)]

    ;; ---- Keyword type and literals ----
    [(expr-Keyword) (expr-Type (lzero))]
    [(expr-keyword _) (expr-Keyword)]

    ;; ---- Path type and literals ----
    [(expr-Path) (expr-Type (lzero))]
    [(expr-path _) (expr-Path)]
    ;; Dynamic path operations
    [(expr-get-in target paths)
     (define _tt (infer ctx target))
     (define _pt (infer ctx paths))
     ;; Result type is a fresh meta (dynamic paths can't be statically resolved)
     (fresh-meta ctx-empty (expr-hole)
       (meta-source-info #f 'get-in-result "result type of dynamic get-in" #f '()))]
    [(expr-broadcast-get target fields)
     (define _tt (infer ctx target))
     ;; fields are keyword literals — no sub-expressions to infer
     ;; Result type: [List V] where V is resolved at reduction time
     (fresh-meta ctx-empty (expr-hole)
       (meta-source-info #f 'broadcast-get-result "result type of broadcast-get" #f '()))]
    [(expr-update-in target paths fn)
     (define tt (infer ctx target))
     (define _pt (infer ctx paths))
     (define _ft (infer ctx fn))
     ;; CIU T6 F1b.3 (D24, supersedes the D20 drop-all): only DYNAMIC paths
     ;; reach this node (literal paths desugar at the elaborator). Per the P6
     ;; probe, a dynamic deep-update CANNOT delete spine keys on a non-empty
     ;; path (every spine level rebuilds via map-assoc) — the zero-segment
     ;; case, which CAN replace the whole map, is a runtime error since
     ;; F1b.3 (reduction.rkt). So for a KEYWORD record target the sound
     ;; maximally-informative posture is: labels kept, per-field FRESH metas
     ;; (any field's VALUE may have changed), presence='present (spine
     ;; membership is stable), dyn tail (a missing-key path INSERTS — growth
     ;; absorbed). 'nat rows keep the prior drop-all degrade ('nat dyn rows
     ;; are not minted — the §12.3 pin). Non-record targets type-preserving.
     (match (whnf tt)
       [(? expr-Record? rec)
        #:when (eq? (expr-Record-key-domain rec) 'keyword)
        (expr-Record 'keyword
                     (for/list ([fld (in-list (expr-Record-fields rec))])
                       (cons (car fld)
                             (record-field
                              (fresh-meta ctx (expr-Type (lzero))
                                          (dyn-row-source 'dyn-row-update-in))
                              'present)))
                     'dyn)]
       [(? expr-Record? rec)
        (make-record (expr-Record-key-domain rec) '() 'dyn)]
       [_ tt])]

    ;; ---- Char type and literals ----
    [(expr-Char) (expr-Type (lzero))]
    [(expr-char _) (expr-Char)]

    ;; ---- String type and literals ----
    [(expr-String) (expr-Type (lzero))]
    [(expr-string _) (expr-String)]

    ;; ---- Structural-row type (CIU T6 F1) ----
    ;; A record/tuple type is well-formed at Type 0 iff every field type is a type.
    [(expr-Record _ fields _)
     (if (andmap (lambda (fld) (is-type ctx (record-field-type (cdr fld)))) fields)
         (expr-Type (lzero))
         (expr-error))]
    ;; ---- Map type and operations ----
    [(expr-Map k v)
     (if (and (is-type ctx k) (is-type ctx v))
         (expr-Type (lzero))
         (expr-error))]
    [(expr-champ _) (expr-error)]  ;; champ needs checking context
    ;; CIU T6 F1 (s2): record-seed map-empty — the empty record type IS the map's type.
    ;; The ONLY source of a map-empty with an expr-Record v-type is the all-keyword literal
    ;; seed (elaborator §4.2); grows via the map-assoc Record arm below.
    [(expr-map-empty _ (? expr-Record? rec)) rec]
    [(expr-map-empty k v)
     (if (and (is-type ctx k) (is-type ctx v))
         (expr-Map k v)
         (expr-error))]
    [(expr-map-assoc m k v)
     ;; Map-subject checks are STRICT against the concrete/⋃observed value type
     ;; (post-F1a.2 no unannotated literal produces an absorbing value slot; the
     ;; retired speculative-widening history: D.3 §7.6 T-3, PPN 4C T-2).
     (let ([tm (schema-fvar->row-or-self (whnf (infer ctx m)))])
       (match tm
         ;; CIU T6 F1 (s2): row extension. keyword-literal key → grow the record
         ;; (right-priority, D10). Non-literal key → degrade to dictionary view (B4-gated).
         [(? expr-Record? rec)
          (match k
            [(expr-keyword kw)
             (let ([vt (infer ctx v)])
               (if (expr-error? vt) (expr-error) (record-extend rec kw vt)))]
            [_
             ;; CIU T6 F1a.2 p1b (D16): dynamic-key extension keeps the KNOWN
             ;; fields and flips the tail to 'dyn — strictly more informative
             ;; than the old (Map Keyword Open). The inserted value's type is
             ;; not recorded (bounds-free tail; named cost, §12.2).
             (if (and (check ctx k (expr-Keyword)) (not (expr-error? (infer ctx v))))
                 (make-record (expr-Record-key-domain rec) (expr-Record-fields rec) 'dyn)
                 (expr-error))])]
         [(expr-Map kt vt)
          (cond
            ;; Key must check against key type
            [(not (check ctx k kt)) (expr-error)]
            ;; Value must check against value type (strict).
            [(not (check ctx v vt)) (expr-error)]
            [else (expr-Map kt vt)])]
         [_ (expr-error)]))]
    ;; get: type-directed index/lookup
    ;; List A → Nat → A, PVec A → Nat → A, Map K V → K → V
    ;; Selection/Schema → delegate to expr-map-get
    [(expr-get coll key)
     (let ([tc (whnf (infer ctx coll))])
       (match tc
         ;; PVec A → Nat/Int → A
         [(expr-PVec a)
          (if (or (check ctx key (expr-Nat)) (check ctx key (expr-Int))) a (expr-error))]
         ;; CIU T6 F1 (s2): structural-row projection (records + tuples)
         [(? expr-Record? rec) (record-project ctx rec key)]
         ;; Map K V → K → V
         [(expr-Map kt vt)
          (if (check ctx key kt) vt (expr-error))]
         ;; Selection type → delegate to map-get typing
         [(expr-fvar name)
          #:when (lookup-selection-by-name name)
          (infer ctx (expr-map-get coll key))]
         ;; Schema type → delegate to map-get typing
         [(expr-fvar name)
          #:when (lookup-schema-by-name name)
          (infer ctx (expr-map-get coll key))]
         ;; List A → Nat/Int → A
         [(expr-app f a)
          #:when (equal? f (list-type-fvar))
          (if (or (check ctx key (expr-Nat)) (check ctx key (expr-Int))) a (expr-error))]
         [_ (expr-error)]))]
    ;; CIU T6 F1b.5-s2 (D27): validate — ONE rule, Result S (Map Keyword Reason).
    ;; Subject discipline = INFER-DISPATCH (the map-get template below; the
    ;; check-against-(Map Keyword ?meta) route was audit-REFUTED: record-<:-map?
    ;; refuses to solve a meta V from a DYN row, and check's match* commits).
    ;; Map-ish subjects accept (Record incl. dyn tails / Map / schema / selection
    ;; / union-of-map-ish / unsolved-meta gradual); non-maps reject statically.
    ;; The PLAN is bake-trusted (elaborated + witness-tagged at elaboration —
    ;; the expr-num-lit carried-alpha precedent); the rule never re-checks it.
    [(expr-validate sname _closed? _plan subject names)
     (let ([tm (whnf (infer ctx subject))])
       (cond
         [(expr-error? tm) (expr-error)]
         [(validate-subject-map-ish? tm)
          ;; Result S (Map Keyword Reason) — names resolved at bake:
          ;; (Result-type Reason-type ok err …)
          (expr-app (expr-app (expr-fvar (car names)) (expr-fvar sname))
                    (expr-Map (expr-Keyword) (expr-fvar (cadr names))))]
         [else (expr-error)]))]

    [(expr-map-get m k)
     (let ([tm (whnf (infer ctx m))])
       (match tm
         ;; CIU T6 F1 (s2): structural-row projection — {:a 1}.a : Int (THE goal)
         [(? expr-Record? rec) (record-project ctx rec k)]
         [(expr-Map kt vt)
          (if (check ctx k kt) vt (expr-error))]
         ;; Selection type: gate field access to selected fields only
         [(expr-fvar name)
          #:when (lookup-selection-by-name name)
          (let* ([sel (lookup-selection-by-name name)]
                 [schema-name (selection-entry-schema-name sel)]
                 [schema (lookup-schema-by-name schema-name)])
            (if (not schema)
                (expr-error)  ;; parent schema not found — shouldn't happen if elaborator validated
                (match k
                  [(expr-keyword kw-sym)
                   (cond
                     ;; Field NOT in selection's allowed fields → error
                     [(not (selection-allows-field? sel kw-sym))
                      (expr-error)]
                     ;; Field in selection → compute type with sub-selection gating
                     [else
                      (selection-field-type sel kw-sym schema)])]
                  [_ (expr-error)])))]
         ;; Schema type: look up field by keyword name
         [(expr-fvar name)
          #:when (lookup-schema-by-name name)
          (let ([schema (lookup-schema-by-name name)])
            (match k
              ;; Keyword literal access: user.name → (map-get user :name)
              [(expr-keyword kw-sym)
               (let ([field (schema-lookup-field schema kw-sym)])
                 (if field
                     (schema-field-type->expr (schema-field-type-datum field))
                     (expr-error)))]
              ;; Non-keyword key on schema: fall back to error
              ;; (schemas only support keyword field access)
              [_ (expr-error)]))]
         [(expr-union _ _)
          ;; Union type: extract Map + Record components, check key, collect value types
          (let* ([components (flatten-union tm)]
                 [map-vts
                  (let loop ([cs components] [acc '()])
                    (if (null? cs)
                        (reverse acc)
                        (let ([c* (whnf (car cs))])
                          (cond
                            [(expr-Map? c*)
                             ;; Phase 5: speculative rollback with network fork/restore
                             (if (with-speculative-rollback
                                   (lambda () (check ctx k (expr-Map-k-type c*)))
                                   values
                                   "union-map-get-component")
                                 (loop (cdr cs) (cons (expr-Map-v-type c*) acc))
                                 (loop (cdr cs) acc))]
                            ;; CIU T6 F1 (s3): record components participate (Q5: filter on miss)
                            [(expr-Record? c*)
                             (let ([vt (union-record-component-vt ctx c* k)])
                               (if vt (loop (cdr cs) (cons vt acc)) (loop (cdr cs) acc)))]
                            [else (loop (cdr cs) acc)]))))])
            (if (null? map-vts)
                (expr-error)
                (build-union-type map-vts)))]
         [_ (expr-error)]))]
    ;; nil-safe-get: (Map K V | Nil) -> K -> (V | Nil)
    ;; On Nil input, returns Nil. On Map input, returns V | Nil.
    ;; On union input, extracts Map components and returns union of V's + Nil.
    [(expr-nil-safe-get m k)
     (let ([tm (schema-fvar->row-or-self (whnf (infer ctx m)))])
       (match tm
         ;; Direct Nil → result is Nil
         [(expr-Nil) (expr-Nil)]
         ;; CIU T6 F1 (s2): nil-safe-get on a record — present → (field | Nil); absent → Nil.
         [(? expr-Record? rec)
          (match k
            [(expr-keyword kw) #:when (eq? (expr-Record-key-domain rec) 'keyword)
             (let ([fld (record-lookup-field rec kw)])
               (cond
                 ;; CIU T6 F1b.3 (D24/Q7): an 'unknown hit rides the dyn-miss
                 ;; branch below (gated-identically — <fresh | Nil>).
                 [(and fld (not (eq? (record-field-presence fld) 'unknown)))
                  (build-union-type (list (whnf (record-field-type fld)) (expr-Nil)))]
                 ;; CIU T6 F1a.2 p1a (§12.4): miss on a 'dyn row — the field may
                 ;; live in the remainder → <fresh | Nil>; closed keeps → Nil.
                 [(eq? (expr-Record-tail rec) 'dyn)
                  (build-union-type
                   (list (fresh-meta ctx (expr-Type (lzero)) (dyn-row-source 'dyn-row-nil-safe)) (expr-Nil)))]
                 [else (expr-Nil)]))]
            [_ (let ([proj (record-project ctx rec k)])
                 (if (expr-error? proj) (expr-error) (build-union-type (list (whnf proj) (expr-Nil)))))])]
         ;; Direct Map K V → check key, return V | Nil
         [(expr-Map kt vt)
          (if (check ctx k kt)
              (build-union-type (list (whnf vt) (expr-Nil)))
              (expr-error))]
         ;; Union: extract Map and Nil components
         [(expr-union _ _)
          (let* ([components (flatten-union tm)]
                 [map-vts
                  (let loop ([cs components] [acc '()])
                    (if (null? cs)
                        (reverse acc)
                        (let ([c* (whnf (car cs))])
                          (cond
                            [(expr-Map? c*)
                             (if (with-speculative-rollback
                                   (lambda () (check ctx k (expr-Map-k-type c*)))
                                   values
                                   "union-nil-safe-get-component")
                                 (loop (cdr cs) (cons (expr-Map-v-type c*) acc))
                                 (loop (cdr cs) acc))]
                            ;; CIU T6 F1 (s3): record components participate (Q5: filter on miss)
                            [(expr-Record? c*)
                             (let ([vt (union-record-component-vt ctx c* k)])
                               (if vt (loop (cdr cs) (cons vt acc)) (loop (cdr cs) acc)))]
                            [else (loop (cdr cs) acc)]))))])
            ;; Always include Nil in the result (safe access returns Nil on miss/nil input)
            (build-union-type (append (map whnf map-vts) (list (expr-Nil)))))]
         [_ (expr-error)]))]
    ;; nil?: infer arg type (must succeed), return Bool
    [(expr-nil-check arg)
     (let ([ta (infer ctx arg)])
       (if (expr-error? ta)
           (expr-error)
           (expr-Bool)))]
    [(expr-map-dissoc m k)
     (let ([tm (schema-fvar->row-or-self (whnf (infer ctx m)))])
       (match tm
         ;; CIU T6 F1 (s2): keyword-literal → exact closed-row removal; dynamic key → degrade.
         [(? expr-Record? rec)
          (match k
            [(expr-keyword kw) #:when (eq? (expr-Record-key-domain rec) 'keyword) (record-remove rec kw)]
            [_
             ;; CIU T6 F1b.3 (D24, supersedes the D20 drop-all): a dynamic-key
             ;; removal leaves every field's PRESENCE uncertain — but its
             ;; type-if-present stays a FACT. Keep labels + types, mark all
             ;; 'unknown, dyn tail. The marks pay via comparison precision
             ;; (the knowns walks check retained types) + diagnostics; they
             ;; never upgrade projection (gated-identically, Q7 — an 'unknown
             ;; hit mints a fresh meta exactly like a tail miss).
             (if (and (check ctx k (expr-Keyword)) (not (expr-error? (infer ctx k))))
                 (record-mark-all-unknown rec) (expr-error))])]
         [(expr-Map kt vt)
          (if (check ctx k kt) (expr-Map kt vt) (expr-error))]
         [_ (expr-error)]))]
    [(expr-map-size m)
     (let ([tm (schema-fvar->row-or-self (whnf (infer ctx m)))])
       (match tm
         [(? expr-Record?) (expr-Nat)]   ;; CIU T6 F1 (s2)
         [(expr-Map _ _) (expr-Nat)]
         [_ (expr-error)]))]
    [(expr-map-has-key m k)
     (let ([tm (schema-fvar->row-or-self (whnf (infer ctx m)))])
       (match tm
         ;; CIU T6 F1 (s2): has-key on a record — Bool if the key checks the key domain.
         [(? expr-Record? rec)
          (if (check ctx k (if (eq? (expr-Record-key-domain rec) 'keyword) (expr-Keyword) (expr-Nat)))
              (expr-Bool) (expr-error))]
         [(expr-Map kt _)
          (if (check ctx k kt) (expr-Bool) (expr-error))]
         [_ (expr-error)]))]
    ;; map-keys: Map K V → List K
    [(expr-map-keys m)
     (let ([tm (schema-fvar->row-or-self (whnf (infer ctx m)))])
       (match tm
         ;; CIU T6 F1 (s2): keys of a record → List of its key-domain type.
         [(? expr-Record? rec)
          (expr-app (list-type-fvar) (if (eq? (expr-Record-key-domain rec) 'keyword) (expr-Keyword) (expr-Nat)))]
         [(expr-Map kt _) (expr-app (list-type-fvar) kt)]
         [_ (expr-error)]))]
    ;; map-vals: Map K V → List V
    [(expr-map-vals m)
     (let ([tm (schema-fvar->row-or-self (whnf (infer ctx m)))])
       (match tm
         ;; CIU T6 F1 (s2): vals of a record → List of the value bound
         ;; (⋃fields; dyn rows add the remainder meta; empty → fresh meta — §12.4).
         [(? expr-Record? rec)
          (expr-app (list-type-fvar) (record-value-bound ctx rec (dyn-row-source 'dyn-row-vals)))]
         [(expr-Map _ vt) (expr-app (list-type-fvar) vt)]
         [_ (expr-error)]))]

    ;; ---- Set type and operations ----
    [(expr-Set a)
     (match (infer-level ctx a)
       [(just-level l) (expr-Type l)]
       [_ (expr-error)])]
    [(expr-hset _) (expr-error)]  ;; hset needs checking context
    [(expr-set-empty a)
     (if (is-type ctx a) (expr-Set a) (expr-error))]
    [(expr-set-insert s a)
     (let ([ts (whnf (infer ctx s))])
       (match ts
         [(expr-Set a-ty)
          (if (check ctx a a-ty) (expr-Set a-ty) (expr-error))]
         [_ (expr-error)]))]
    [(expr-set-member s a)
     (let ([ts (whnf (infer ctx s))])
       (match ts
         [(expr-Set a-ty)
          (if (check ctx a a-ty) (expr-Bool) (expr-error))]
         [_ (expr-error)]))]
    [(expr-set-delete s a)
     (let ([ts (whnf (infer ctx s))])
       (match ts
         [(expr-Set a-ty)
          (if (check ctx a a-ty) (expr-Set a-ty) (expr-error))]
         [_ (expr-error)]))]
    [(expr-set-size s)
     (let ([ts (whnf (infer ctx s))])
       (match ts
         [(expr-Set _) (expr-Nat)]
         [_ (expr-error)]))]
    [(expr-set-union s1 s2)
     (let ([ts1 (whnf (infer ctx s1))])
       (match ts1
         [(expr-Set a-ty)
          (if (check ctx s2 (expr-Set a-ty)) (expr-Set a-ty) (expr-error))]
         [_ (expr-error)]))]
    [(expr-set-intersect s1 s2)
     (let ([ts1 (whnf (infer ctx s1))])
       (match ts1
         [(expr-Set a-ty)
          (if (check ctx s2 (expr-Set a-ty)) (expr-Set a-ty) (expr-error))]
         [_ (expr-error)]))]
    [(expr-set-diff s1 s2)
     (let ([ts1 (whnf (infer ctx s1))])
       (match ts1
         [(expr-Set a-ty)
          (if (check ctx s2 (expr-Set a-ty)) (expr-Set a-ty) (expr-error))]
         [_ (expr-error)]))]
    ;; set-to-list: Set A → List A
    [(expr-set-to-list s)
     (let ([ts (infer ctx s)])
       (match ts
         [(expr-Set a) (expr-app (list-type-fvar) a)]
         [_ (expr-error)]))]

    ;; ---- PVec type and operations ----
    [(expr-PVec a)
     (if (is-type ctx a) (expr-Type (lzero)) (expr-error))]
    [(expr-rrb _) (expr-error)]   ;; rrb needs checking context
    [(expr-pvec-empty a)
     (if (is-type ctx a) (expr-PVec a) (expr-error))]
    ;; CIU T6 F1a-col-2 (D15): list-literal twin — all-at-once. Homogeneous →
    ;; delegate to the CHAIN's infer (today's cons-polymorphism typing, exact
    ;; parity → (List T), and it solves the chain's implicit metas properly);
    ;; heterogeneous → a closed 'nat row (the chain's erased implicit metas
    ;; default at zonk-final; runtime reads only the chain).
    [(expr-list-literal elems chain)
     (let ([tys (for/list ([el (in-list elems)]) (whnf (infer ctx el)))])
       (cond
         [(ormap expr-error? tys) (expr-error)]
         [(with-speculative-rollback
            (lambda ()
              (for/and ([ti (in-list (cdr tys))])
                (unify-ok? (unify ctx (car tys) ti))))
            values
            "list-literal-homogeneity")
          (infer ctx chain)]
         [else
          (make-record 'nat
                       (for/list ([t (in-list tys)] [i (in-naturals)])
                         (cons i (record-field t 'present)))
                       'closed)]))]
    ;; CIU T6 F1a.2 p1b (D18): mixed-key map literal, ALL-AT-ONCE — the D15
    ;; literal-extent mechanism at the Map domain. Keys are UNIFORM (unify to K;
    ;; a key-type conflict is an error, matching the old per-key ?km solving);
    ;; values give the OBSERVED uniform bound ⋃vals — never a per-value check
    ;; against a single meta (which would break heterogeneous literals), never
    ;; global assoc-widening (D18). Runtime reads only the chain.
    [(expr-map-literal keys vals chain)
     (let ([kts (for/list ([k (in-list keys)]) (whnf (infer ctx k)))]
           [vts (for/list ([v (in-list vals)]) (whnf (infer ctx v)))])
       (cond
         [(ormap expr-error? kts) (expr-error)]
         [(ormap expr-error? vts) (expr-error)]
         [(for/and ([kt (in-list (cdr kts))])
            (unify-ok? (unify ctx (car kts) kt)))
          (expr-Map (whnf (car kts)) (build-union-type vts))]
         [else (expr-error)]))]
    ;; CIU T6 F1a-col (D15): literal-extent typing, ALL-AT-ONCE. Homogeneous
    ;; (element types unify — rollback-probed; success commits the solves) →
    ;; (PVec T) exactly as the old meta-seeded chain; heterogeneous → a closed
    ;; 'nat row (tuple-by-default, Q_D). The union view is the DERIVED α only.
    [(expr-pvec-literal elems)
     (let ([tys (for/list ([el (in-list elems)]) (whnf (infer ctx el)))])
       (cond
         [(ormap expr-error? tys) (expr-error)]
         [(with-speculative-rollback
            (lambda ()
              (for/and ([ti (in-list (cdr tys))])
                (unify-ok? (unify ctx (car tys) ti))))
            values
            "pvec-literal-homogeneity")
          (expr-PVec (whnf (car tys)))]
         [else
          (make-record 'nat
                       (for/list ([t (in-list tys)] [i (in-naturals)])
                         (cons i (record-field t 'present)))
                       'closed)]))]
    ;; CIU T6 F1a-col-3: every pvec-op arm whnfs its subject (the s3 map-op precedent —
    ;; aliased/record types match) and carries a tuple ('nat row) disposition:
    ;; EXACT where the position structure is statically known (closed tuples have static
    ;; length), degrading to the ⋃-positions uniform view where it is not.
    [(expr-pvec-push v x)
     (let ([tv (whnf (infer ctx v))])
       (match tv
         [(expr-PVec a) (if (check ctx x a) (expr-PVec a) (expr-error))]
         ;; col-3 EXACT: push appends at position len — the row GROWS (type-changing).
         [(? closed-nat-row? rec)
          (let ([tx (whnf (infer ctx x))])
            (if (expr-error? tx)
                (expr-error)
                (record-extend rec (length (expr-Record-fields rec)) tx)))]
         [_ (expr-error)]))]
    [(expr-pvec-nth v i)
     (let ([tv (whnf (infer ctx v))])
       (match tv
         [(expr-PVec a) (if (check ctx i (expr-Nat)) a (expr-error))]
         ;; col-3: positional projection — record-project (literal Nat → exact position
         ;; type / closed-row miss; dynamic index → Nat-check + ⋃positions). Int literals
         ;; are REJECTED here (unlike v[i]/expr-get): the pvec-* runtime is nat-value-only,
         ;; so the pvec-* ops keep their Nat-only index discipline on tuples too.
         [(? expr-Record? rec)
          (match i
            [(expr-int _) (expr-error)]
            [_ (record-project ctx rec i)])]
         [_ (expr-error)]))]
    [(expr-pvec-update v i x)
     (let ([tv (whnf (infer ctx v))])
       (match tv
         [(expr-PVec a) (if (and (check ctx i (expr-Nat)) (check ctx x a))
                            (expr-PVec a) (expr-error))]
         ;; col-3: literal in-bounds index → EXACT per-position replacement (out-of-bounds
         ;; is a STATIC miss, mirroring record-project's closed-row miss). Dynamic index →
         ;; the touched position is unknown: degrade to (PVec ⋃positions∪W) — sound, any
         ;; position may now hold W. Empty tuple has no position to update → error (Q6).
         [(? closed-nat-row? rec)
          (let ([len (length (expr-Record-fields rec))])
            (match i
              ;; Nat literals only (the pvec-* Nat-only index discipline; Int stalls at runtime)
              [(expr-nat-val n)
               #:when (exact-nonnegative-integer? n)
               (if (< n len)
                   (let ([tx (whnf (infer ctx x))])
                     (if (expr-error? tx) (expr-error) (record-extend rec n tx)))
                   (expr-error))]
              [_
               (if (and (> len 0) (check ctx i (expr-Nat)))
                   (let ([tx (whnf (infer ctx x))])
                     (if (expr-error? tx)
                         (expr-error)
                         (expr-PVec
                          (build-union-type
                           (cons tx (map (lambda (f) (record-field-type (cdr f)))
                                         (expr-Record-fields rec)))))))
                   (expr-error))]))]
         [_ (expr-error)]))]
    [(expr-pvec-length v)
     (let ([tv (whnf (infer ctx v))])
       (match tv
         [(expr-PVec _) (expr-Nat)]
         [(? closed-nat-row? _) (expr-Nat)]   ;; col-3: tuples have length too
         [_ (expr-error)]))]
    [(expr-pvec-pop v)
     (let ([tv (whnf (infer ctx v))])
       (match tv
         [(expr-PVec a) (expr-PVec a)]
         ;; col-3 EXACT: pop removes the LAST position (rrb-pop semantics); the row
         ;; SHRINKS. Pop on the empty tuple is statically impossible → error.
         [(? closed-nat-row? rec)
          (let ([fields (expr-Record-fields rec)])
            (if (null? fields)
                (expr-error)
                (record-remove rec (- (length fields) 1))))]
         [_ (expr-error)]))]
    [(expr-pvec-concat v1 v2)
     (let ([tv1 (whnf (infer ctx v1))])
       (match tv1
         [(expr-PVec a) (if (check ctx v2 (expr-PVec a)) (expr-PVec a) (expr-error))]
         ;; col-3: two closed tuples → EXACT index-shifted append (ground×ground, the
         ;; M1-style elaboration-time computation; the residuated Concat relation stays
         ;; F-row). Tuple ++ (PVec b) → degrade (PVec ⋃positions∪b). Else error.
         [(? closed-nat-row? rec1)
          (let ([tv2 (whnf (infer ctx v2))])
            (match tv2
              [(? closed-nat-row? rec2)
               (let ([len1 (length (expr-Record-fields rec1))])
                 (make-record 'nat
                              (append (expr-Record-fields rec1)
                                      (for/list ([f (in-list (expr-Record-fields rec2))])
                                        (cons (+ len1 (car f)) (cdr f))))
                              'closed))]
              [(expr-PVec b)
               (expr-PVec
                (build-union-type
                 (cons b (map (lambda (f) (record-field-type (cdr f)))
                              (expr-Record-fields rec1)))))]
              [_ (expr-error)]))]
         [_ (expr-error)]))]
    [(expr-pvec-slice v lo hi)
     (let ([tv (whnf (infer ctx v))])
       (match tv
         [(expr-PVec a) (if (and (check ctx lo (expr-Nat)) (check ctx hi (expr-Nat)))
                            (expr-PVec a) (expr-error))]
         ;; col-3: literal bounds → EXACT clamped half-open sub-row [lo, hi) renumbered
         ;; from 0 (rrb-slice semantics; empty range → the empty tuple). Dynamic bounds →
         ;; degrade (PVec ⋃positions); slicing the EMPTY tuple is the empty tuple always.
         [(? closed-nat-row? rec)
          (let* ([fields (expr-Record-fields rec)]
                 [len (length fields)]
                 ;; Nat literals only (the pvec-* Nat-only index discipline; Int stalls at runtime)
                 [lit (lambda (b) (match b
                                    [(expr-nat-val n)
                                     #:when (exact-nonnegative-integer? n) n]
                                    [_ #f]))]
                 [lo-n (lit lo)]
                 [hi-n (lit hi)])
            (cond
              [(and lo-n hi-n)
               (let ([hi* (min len hi-n)])
                 (make-record 'nat
                              (if (>= lo-n hi*)
                                  '()
                                  (for/list ([f (in-list fields)]
                                             #:when (and (>= (car f) lo-n) (< (car f) hi*)))
                                    (cons (- (car f) lo-n) (cdr f))))
                              'closed))]
              [(and (check ctx lo (expr-Nat)) (check ctx hi (expr-Nat)))
               (if (null? fields) rec (expr-PVec (record-value-union rec)))]
              [else (expr-error)]))]
         [_ (expr-error)]))]
    ;; pvec-to-list : PVec A → List A
    [(expr-pvec-to-list v)
     (let ([tv (whnf (infer ctx v))])
       (match tv
         [(expr-PVec a) (expr-app (list-type-fvar) a)]
         ;; col-3: uniform view (List ⋃positions) — the s2 map-vals LIST-view mirror.
         ;; Deliberately NOT row-identity: a row-typed cons list expands the pinned
         ;; S10-at-list-level value-stall surface; (List ⋃) keeps to-list the escape hatch.
         [(? closed-nat-row? rec)
          (expr-app (list-type-fvar) (record-value-bound ctx rec "tuple-to-list"))]
         [_ (expr-error)]))]
    ;; pvec-fold : (B → A → B) → B → PVec A → B
    ;; Left fold over a PVec: f takes (accumulator, element), returns accumulator.
    ;; Pi codomain types are shifted to account for the binder (de Bruijn convention).
    [(expr-pvec-fold f init vec)
     (let ([tv (whnf (infer ctx vec))]
           [tb (infer ctx init)])
       (match tv
         [(expr-PVec a)
          (let ([expected-f (expr-Pi 'mw tb (expr-Pi 'mw (shift 1 0 a) (shift 2 0 tb)))])
            (if (check ctx f expected-f)
                tb
                (expr-error)))]
         ;; CIU T6 F1a-col-3: fold over a tuple — uniform view (f consumes ⋃positions;
         ;; the map-fold-entries s3 mirror, minus the key argument).
         [(? closed-nat-row? rec)
          (let ([expected-f (expr-Pi 'mw tb
                              (expr-Pi 'mw (shift 1 0 (record-value-bound ctx rec "tuple-fold"))
                                       (shift 2 0 tb)))])
            (if (check ctx f expected-f)
                tb
                (expr-error)))]
         [_ (expr-error)]))]

    ;; pvec-map : (A → B) → PVec A → PVec B
    ;; Infers B from f's return type. Handles both named functions and lambdas.
    [(expr-pvec-map f vec)
     (let ([tv (whnf (infer ctx vec))])
       (match tv
         ;; CIU T6 F1a-col-3: map over a tuple — POSITION-PRESERVING (the map-map-vals
         ;; s3 mirror): f consumes ⋃positions; the result keeps the position set with
         ;; every slot type := W (per-position instantiation of a polymorphic f has no
         ;; in-tree machinery — constant-W is the honest static answer).
         [(? closed-nat-row? rec)
          (let* ([v (record-value-bound ctx rec "tuple-map")]
                 [tf (infer ctx f)]
                 [finish (lambda (w)
                           (make-record 'nat
                                        (for/list ([p (in-list (expr-Record-fields rec))])
                                          (cons (car p)
                                                (record-field w (record-field-presence (cdr p)))))
                                        (expr-Record-tail rec)))])
            (if (equal? tf (expr-error))
                ;; Fallback for lambdas (mirrors the PVec arm below)
                (match f
                  [(expr-lam _ dom body)
                   (let ([actual-dom (if (expr-hole? dom) v (whnf dom))])
                     (if (or (expr-hole? dom) (unify-ok? (unify ctx actual-dom v)))
                         (let ([w (infer (cons (cons actual-dom 'mw) ctx) body)])
                           (if (equal? w (expr-error))
                               (expr-error)
                               (finish (whnf (subst 0 (expr-zero) w)))))
                         (expr-error)))]
                  [_ (expr-error)])
                (match (whnf tf)
                  [(expr-Pi _ dom cod)
                   (if (unify-ok? (unify ctx dom v))
                       (finish (whnf (subst 0 (expr-zero) cod)))
                       (expr-error))]
                  [_ (expr-error)])))]
         [(expr-PVec a)
          ;; Try to infer f's type first (works for named functions)
          (let ([tf (infer ctx f)])
            (if (equal? tf (expr-error))
                ;; Fallback for lambdas: check f against A → ?B by extending ctx
                (match f
                  [(expr-lam m dom body)
                   (let* ([actual-dom (if (expr-hole? dom) a (whnf dom))])
                     (if (or (expr-hole? dom) (unify-ok? (unify ctx actual-dom a)))
                         (let ([b (infer (cons (cons actual-dom 'mw) ctx) body)])
                           (if (equal? b (expr-error))
                               (expr-error)
                               ;; b is at extended depth; un-shift via subst
                               (expr-PVec (whnf (subst 0 (expr-zero) b)))))
                         (expr-error)))]
                  [_ (expr-error)])
                ;; Normal path: f inferred to Pi — un-shift codomain via subst
                (match (whnf tf)
                  [(expr-Pi _ dom cod)
                   (if (unify-ok? (unify ctx dom a))
                       (expr-PVec (whnf (subst 0 (expr-zero) cod)))
                       (expr-error))]
                  [_ (expr-error)])))]
         [_ (expr-error)]))]

    ;; pvec-filter : (A → Bool) → PVec A → PVec A
    [(expr-pvec-filter pred vec)
     (let ([tv (whnf (infer ctx vec))])
       (match tv
         [(expr-PVec a)
          (if (check ctx pred (expr-Pi 'mw a (expr-Bool)))
              (expr-PVec a)
              (expr-error))]
         ;; CIU T6 F1a-col-3: filter on a tuple — the surviving position set isn't
         ;; static, so the result DEGRADES to (PVec ⋃positions) (the map-filter-entries
         ;; s3 dictionary-degrade mirror at the positional domain).
         [(? closed-nat-row? rec)
          (let ([v (record-value-bound ctx rec "tuple-filter")])
            (if (check ctx pred (expr-Pi 'mw v (expr-Bool)))
                (expr-PVec v)
                (expr-error)))]
         [_ (expr-error)]))]

    ;; set-fold : (B → A → B) → B → Set A → B
    [(expr-set-fold f init set)
     (let ([ts (infer ctx set)]
           [tb (infer ctx init)])
       (match ts
         [(expr-Set a)
          (let ([expected-f (expr-Pi 'mw tb (expr-Pi 'mw (shift 1 0 a) (shift 2 0 tb)))])
            (if (check ctx f expected-f)
                tb
                (expr-error)))]
         [_ (expr-error)]))]

    ;; set-filter : (A → Bool) → Set A → Set A
    [(expr-set-filter pred set)
     (let ([ts (infer ctx set)])
       (match ts
         [(expr-Set a)
          (if (check ctx pred (expr-Pi 'mw a (expr-Bool)))
              (expr-Set a)
              (expr-error))]
         [_ (expr-error)]))]

    ;; map-fold-entries : (B → K → V → B) → B → Map K V → B
    [(expr-map-fold-entries f init map)
     (let ([tm (whnf (infer ctx map))]   ;; s3: whnf (map-get precedent) so aliased/record types match
           [tb (infer ctx init)])
       (match tm
         [(expr-Map k v)
          (let ([expected-f (expr-Pi 'mw tb
                              (expr-Pi 'mw (shift 1 0 k)
                                (expr-Pi 'mw (shift 2 0 v) (shift 3 0 tb))))])
            (if (check ctx f expected-f)
                tb
                (expr-error)))]
         ;; CIU T6 F1 (s3): fold over a record via the uniform view (K=Keyword, V=⋃fields)
         ;; F1a.2 p1a: dyn rows fold over the BOUND (§12.4).
         [(? expr-Record? rec)
          (let ([expected-f (expr-Pi 'mw tb
                              (expr-Pi 'mw (shift 1 0 (expr-Keyword))
                                (expr-Pi 'mw (shift 2 0 (record-value-bound ctx rec (dyn-row-source 'dyn-row-fold))) (shift 3 0 tb))))])
            (if (check ctx f expected-f)
                tb
                (expr-error)))]
         [_ (expr-error)]))]

    ;; map-filter-entries : (K → V → Bool) → Map K V → Map K V
    [(expr-map-filter-entries pred map)
     (let ([tm (whnf (infer ctx map))])
       (match tm
         [(expr-Map k v)
          (if (check ctx pred (expr-Pi 'mw k (expr-Pi 'mw (shift 1 0 v) (expr-Bool))))
              (expr-Map k v)
              (expr-error))]
         ;; CIU T6 F1 (s3): filter on a record — the surviving field set isn't static, so
         ;; the result DEGRADES to the dictionary view (Map Keyword ⋃fields); a dyn-tailed
         ;; row takes over at F1a.2.
         [(? expr-Record? rec)
          ;; F1a.2 p1a: dyn rows filter over the BOUND (§12.4).
          (let ([v (record-value-bound ctx rec (dyn-row-source 'dyn-row-filter))])
            (if (check ctx pred (expr-Pi 'mw (expr-Keyword) (expr-Pi 'mw (shift 1 0 v) (expr-Bool))))
                (expr-Map (expr-Keyword) v)
                (expr-error)))]
         [_ (expr-error)]))]

    ;; map-map-vals : (V → W) → Map K V → Map K W
    ;; Handles both named functions and lambdas for f.
    ;; CIU T6 F1 (s3): on a record, f consumes ⋃fields and the result is a LABEL-PRESERVING
    ;; record (map-vals touches values only — the label set is static; same labels + presence,
    ;; every field type := W). No dictionary degrade.
    [(expr-map-map-vals f map)
     (let ([tm (whnf (infer ctx map))])
       (match tm
         [(? expr-Record? rec)
          ;; F1a.2 p1a: f consumes the BOUND for dyn rows; the rebuild is tail-
          ;; preserving already (knowns := W, remainder stays unknown — §12.4).
          (let* ([v (record-value-bound ctx rec (dyn-row-source 'dyn-row-map-vals))]
                 [tf (infer ctx f)]
                 [finish (lambda (w)
                           ;; NB: for/list, NOT map — the arm's pattern var `map` (the term)
                           ;; shadows Racket's map procedure here.
                           (make-record (expr-Record-key-domain rec)
                                        (for/list ([p (in-list (expr-Record-fields rec))])
                                          (cons (car p)
                                                (record-field w (record-field-presence (cdr p)))))
                                        (expr-Record-tail rec)))])
            (if (equal? tf (expr-error))
                ;; Fallback for lambdas (mirrors the Map arm below)
                (match f
                  [(expr-lam _ dom body)
                   (let ([actual-dom (if (expr-hole? dom) v (whnf dom))])
                     (if (or (expr-hole? dom) (unify-ok? (unify ctx actual-dom v)))
                         (let ([w (infer (cons (cons actual-dom 'mw) ctx) body)])
                           (if (equal? w (expr-error))
                               (expr-error)
                               (finish (whnf (subst 0 (expr-zero) w)))))
                         (expr-error)))]
                  [_ (expr-error)])
                (match (whnf tf)
                  [(expr-Pi _ dom cod)
                   (if (unify-ok? (unify ctx dom v))
                       (finish (whnf (subst 0 (expr-zero) cod)))
                       (expr-error))]
                  [_ (expr-error)])))]
         [(expr-Map k v)
          (let ([tf (infer ctx f)])
            (if (equal? tf (expr-error))
                ;; Fallback for lambdas
                (match f
                  [(expr-lam m dom body)
                   (let* ([actual-dom (if (expr-hole? dom) v (whnf dom))])
                     (if (or (expr-hole? dom) (unify-ok? (unify ctx actual-dom v)))
                         (let ([w (infer (cons (cons actual-dom 'mw) ctx) body)])
                           (if (equal? w (expr-error))
                               (expr-error)
                               ;; w is at extended depth; un-shift via subst
                               (expr-Map k (whnf (subst 0 (expr-zero) w)))))
                         (expr-error)))]
                  [_ (expr-error)])
                ;; Normal path — un-shift codomain via subst
                (match (whnf tf)
                  [(expr-Pi _ dom cod)
                   (if (unify-ok? (unify ctx dom v))
                       (expr-Map k (whnf (subst 0 (expr-zero) cod)))
                       (expr-error))]
                  [_ (expr-error)])))]
         [_ (expr-error)]))]

    ;; pvec-from-list : List A → PVec A
    ;; List constructor name may be 'List or 'prologos::data::list::List (qualified)
    [(expr-pvec-from-list v)
     (let ([tv (whnf (infer ctx v))])
       (match tv
         [(expr-app (? (lambda (f)
                         (and (expr-fvar? f)
                              (let* ([n (symbol->string (expr-fvar-name f))]
                                     [len (string-length n)])
                                (or (string=? n "List")
                                    (and (>= len 6)
                                         (string=? (substring n (- len 6)) "::List"))))))) a)
          (expr-PVec a)]
         ;; CIU T6 F1a-col-3: from-list on a 'nat row — EXACT identity. The row carries
         ;; no container tag (a '[…] row and a @[…] row are the same observational type);
         ;; the runtime becomes an rrb where every pvec op works.
         [(? closed-nat-row? rec) rec]
         [_ (expr-error)]))]

    ;; ---- Transient Builders ----
    ;; Generic transient: dispatch on collection type
    [(expr-transient coll)
     (let ([tc (infer ctx coll)])
       (match (whnf tc)
         [(expr-PVec a) (expr-TVec a)]
         [(expr-Map k v) (expr-TMap k v)]
         [(expr-Set a) (expr-TSet a)]
         ;; CIU T6 F1a-col-3 (audit-surfaced same-class gap): a tuple entering the
         ;; transient world degrades to the uniform view — transients are mutation-
         ;; indexed dictionaries; per-position tracking through mutation is not v1.
         [(? closed-nat-row? rec) (expr-TVec (record-value-bound ctx rec "tuple-transient"))]
         [_ (expr-error)]))]
    ;; Generic persist: dispatch on transient type
    [(expr-persist coll)
     (let ([tc (infer ctx coll)])
       (match (whnf tc)
         [(expr-TVec a) (expr-PVec a)]
         [(expr-TMap k v) (expr-Map k v)]
         [(expr-TSet a) (expr-Set a)]
         [_ (expr-error)]))]
    ;; Panic: requires checking context (can't synthesize type for panic)
    [(expr-panic _) (expr-error)]
    [(expr-TVec a)
     (if (is-type ctx a) (expr-Type (lzero)) (expr-error))]
    [(expr-TMap k v)
     (if (and (is-type ctx k) (is-type ctx v)) (expr-Type (lzero)) (expr-error))]
    [(expr-TSet a)
     (if (is-type ctx a) (expr-Type (lzero)) (expr-error))]
    [(expr-trrb _) (expr-error)]   ;; trrb needs checking context
    [(expr-tchamp _) (expr-error)]  ;; tchamp needs checking context
    [(expr-thset _) (expr-error)]   ;; thset needs checking context
    [(expr-transient-vec v)
     (let ([tv (whnf (infer ctx v))])
       (match tv
         [(expr-PVec a) (expr-TVec a)]
         ;; CIU T6 F1a-col-3: tuple → uniform transient view (generic-transient mirror)
         [(? closed-nat-row? rec) (expr-TVec (record-value-bound ctx rec "tuple-transient"))]
         [_ (expr-error)]))]
    [(expr-persist-vec t)
     (let ([tt (infer ctx t)])
       (match tt
         [(expr-TVec a) (expr-PVec a)]
         [_ (expr-error)]))]
    [(expr-transient-map m)
     (let ([tm (infer ctx m)])
       (match tm
         [(expr-Map k v) (expr-TMap k v)]
         [_ (expr-error)]))]
    [(expr-persist-map t)
     (let ([tt (infer ctx t)])
       (match tt
         [(expr-TMap k v) (expr-Map k v)]
         [_ (expr-error)]))]
    [(expr-transient-set s)
     (let ([ts (infer ctx s)])
       (match ts
         [(expr-Set a) (expr-TSet a)]
         [_ (expr-error)]))]
    [(expr-persist-set t)
     (let ([tt (infer ctx t)])
       (match tt
         [(expr-TSet a) (expr-Set a)]
         [_ (expr-error)]))]
    [(expr-tvec-push! t x)
     (let ([tt (infer ctx t)])
       (match tt
         [(expr-TVec a) (if (check ctx x a) (expr-TVec a) (expr-error))]
         [_ (expr-error)]))]
    [(expr-tvec-update! t i x)
     (let ([tt (infer ctx t)])
       (match tt
         [(expr-TVec a) (if (and (check ctx i (expr-Nat)) (check ctx x a))
                            (expr-TVec a) (expr-error))]
         [_ (expr-error)]))]
    [(expr-tmap-assoc! t k v)
     (let ([tt (infer ctx t)])
       (match tt
         [(expr-TMap kt vt)
          (if (and (check ctx k kt) (check ctx v vt))
              (expr-TMap kt vt) (expr-error))]
         [_ (expr-error)]))]
    [(expr-tmap-dissoc! t k)
     (let ([tt (infer ctx t)])
       (match tt
         [(expr-TMap kt vt)
          (if (check ctx k kt) (expr-TMap kt vt) (expr-error))]
         [_ (expr-error)]))]
    [(expr-tset-insert! t a)
     (let ([tt (infer ctx t)])
       (match tt
         [(expr-TSet a-ty)
          (if (check ctx a a-ty) (expr-TSet a-ty) (expr-error))]
         [_ (expr-error)]))]
    [(expr-tset-delete! t a)
     (let ([tt (infer ctx t)])
       (match tt
         [(expr-TSet a-ty)
          (if (check ctx a a-ty) (expr-TSet a-ty) (expr-error))]
         [_ (expr-error)]))]

    ;; ---- Foreign function: look up type from global env ----
    [(expr-foreign-fn name _ _ _ _ _ _ _)
     (or (global-env-lookup-type name) (expr-error))]

    ;; ---- PropNetwork type constructors ----
    [(expr-net-type) (expr-Type (lzero))]
    [(expr-cell-id-type) (expr-Type (lzero))]
    [(expr-prop-id-type) (expr-Type (lzero))]

    ;; ---- PropNetwork runtime wrappers ----
    [(expr-prop-network _) (expr-net-type)]
    [(expr-cell-id _) (expr-cell-id-type)]
    [(expr-prop-id _) (expr-prop-id-type)]

    ;; ---- PropNetwork operations ----

    ;; net-new : Int -> PropNetwork
    [(expr-net-new fuel)
     (if (check ctx fuel (expr-Int))
         (expr-net-type)
         (expr-error))]

    ;; net-new-cell : PropNetwork -> A -> (A -> A -> A) -> [PropNetwork * CellId]
    ;; Build merge type as A -> A -> A.  When A contains bvars (polymorphic context),
    ;; each Pi binder introduces a new variable, so references to A in the codomain
    ;; must be shifted.  Pi(mw, A, Pi(mw, shift(1,0,A), shift(2,0,A))).
    [(expr-net-new-cell net init merge)
     (if (check ctx net (expr-net-type))
         (let ([init-ty (infer ctx init)])
           (if (expr-error? init-ty)
               (expr-error)
               (let ([merge-ty (expr-Pi mw init-ty
                                 (expr-Pi mw (shift 1 0 init-ty)
                                   (shift 2 0 init-ty)))])
                 (if (check ctx merge merge-ty)
                     (expr-Sigma (expr-net-type) (expr-cell-id-type))
                     (expr-error)))))
         (expr-error))]

    ;; net-new-cell-widen : PropNetwork -> A -> (A A -> A) -> (A A -> A) -> (A A -> A) -> [PropNetwork * CellId]
    ;; Same as net-new-cell but with two additional function args: widen and narrow.
    ;; All three function args have the same type: A -> A -> A.
    [(expr-net-new-cell-widen net init merge widen-fn narrow-fn)
     (if (check ctx net (expr-net-type))
         (let ([init-ty (infer ctx init)])
           (if (expr-error? init-ty)
               (expr-error)
               (let ([fn-ty (expr-Pi mw init-ty
                              (expr-Pi mw (shift 1 0 init-ty)
                                (shift 2 0 init-ty)))])
                 (if (and (check ctx merge fn-ty)
                          (check ctx widen-fn fn-ty)
                          (check ctx narrow-fn fn-ty))
                     (expr-Sigma (expr-net-type) (expr-cell-id-type))
                     (expr-error)))))
         (expr-error))]

    ;; net-cell-read : PropNetwork -> CellId -> A (type-unsafe: returns fresh hole)
    [(expr-net-cell-read net cell)
     (if (and (check ctx net (expr-net-type))
              (check ctx cell (expr-cell-id-type)))
         (expr-hole)   ;; type-unsafe — caller must use (the T ...) or checking context
         (expr-error))]

    ;; net-cell-write : PropNetwork -> CellId -> A -> PropNetwork
    [(expr-net-cell-write net cell val)
     (if (and (check ctx net (expr-net-type))
              (check ctx cell (expr-cell-id-type)))
         (let ([_ (infer ctx val)])  ;; val can be any type
           (expr-net-type))
         (expr-error))]

    ;; net-add-prop : PropNetwork -> List CellId -> List CellId -> (PropNetwork -> PropNetwork) -> [PropNetwork * PropId]
    [(expr-net-add-prop net ins outs fn)
     (let ([list-cid (expr-app (list-type-fvar) (expr-cell-id-type))])
       (if (and (check ctx net (expr-net-type))
                (check ctx ins list-cid)
                (check ctx outs list-cid)
                (check ctx fn (arrow (expr-net-type) (expr-net-type))))
           (expr-Sigma (expr-net-type) (expr-prop-id-type))
           (expr-error)))]

    ;; net-run : PropNetwork -> PropNetwork
    [(expr-net-run net)
     (if (check ctx net (expr-net-type))
         (expr-net-type)
         (expr-error))]

    ;; net-snapshot : PropNetwork -> PropNetwork (identity — documents backtracking intent)
    [(expr-net-snapshot net)
     (if (check ctx net (expr-net-type))
         (expr-net-type)
         (expr-error))]

    ;; net-contradict? : PropNetwork -> Bool
    [(expr-net-contradiction net)
     (if (check ctx net (expr-net-type))
         (expr-Bool)
         (expr-error))]

    ;; ---- UnionFind type constructor ----
    [(expr-uf-type) (expr-Type (lzero))]

    ;; ---- UnionFind runtime wrapper ----
    [(expr-uf-store _) (expr-uf-type)]

    ;; ---- UnionFind operations ----

    ;; uf-empty : UnionFind
    [(expr-uf-empty) (expr-uf-type)]

    ;; uf-make-set : UnionFind -> Nat -> A -> UnionFind
    [(expr-uf-make-set store id val)
     (if (and (check ctx store (expr-uf-type))
              (check ctx id (expr-Nat)))
         (let ([_ (infer ctx val)])  ;; val can be any type
           (expr-uf-type))
         (expr-error))]

    ;; uf-find : UnionFind -> Nat -> [Nat * UnionFind]
    [(expr-uf-find store id)
     (if (and (check ctx store (expr-uf-type))
              (check ctx id (expr-Nat)))
         (expr-Sigma (expr-Nat) (expr-uf-type))
         (expr-error))]

    ;; uf-union : UnionFind -> Nat -> Nat -> UnionFind
    [(expr-uf-union store id1 id2)
     (if (and (check ctx store (expr-uf-type))
              (check ctx id1 (expr-Nat))
              (check ctx id2 (expr-Nat)))
         (expr-uf-type)
         (expr-error))]

    ;; uf-value : UnionFind -> Nat -> A (type-unsafe: returns fresh hole)
    [(expr-uf-value store id)
     (if (and (check ctx store (expr-uf-type))
              (check ctx id (expr-Nat)))
         (expr-hole)   ;; type-unsafe — caller must use (the T ...) or checking context
         (expr-error))]

    ;; ---- Tabling type constructor ----
    [(expr-table-store-type) (expr-Type (lzero))]

    ;; ---- Tabling runtime wrapper ----
    [(expr-table-store-val _) (expr-table-store-type)]

    ;; ---- Tabling operations ----

    ;; table-new : PropNetwork -> TableStore
    [(expr-table-new network)
     (if (check ctx network (expr-net-type))
         (expr-table-store-type)
         (expr-error))]

    ;; table-register : TableStore -> Keyword -> Keyword -> [TableStore * CellId]
    [(expr-table-register store name mode)
     (if (and (check ctx store (expr-table-store-type))
              (check ctx name (expr-Keyword))
              (check ctx mode (expr-Keyword)))
         (expr-Sigma (expr-table-store-type) (expr-cell-id-type))
         (expr-error))]

    ;; table-add : TableStore -> Keyword -> A -> TableStore
    [(expr-table-add store name answer)
     (if (and (check ctx store (expr-table-store-type))
              (check ctx name (expr-Keyword)))
         (begin (infer ctx answer)  ;; answer can be any type
                (expr-table-store-type))
         (expr-error))]

    ;; table-answers : TableStore -> Keyword -> _ (type-unsafe)
    [(expr-table-answers store name)
     (if (and (check ctx store (expr-table-store-type))
              (check ctx name (expr-Keyword)))
         (expr-hole)
         (expr-error))]

    ;; table-freeze : TableStore -> Keyword -> TableStore
    [(expr-table-freeze store name)
     (if (and (check ctx store (expr-table-store-type))
              (check ctx name (expr-Keyword)))
         (expr-table-store-type)
         (expr-error))]

    ;; table-complete? : TableStore -> Keyword -> Bool
    [(expr-table-complete store name)
     (if (and (check ctx store (expr-table-store-type))
              (check ctx name (expr-Keyword)))
         (expr-Bool)
         (expr-error))]

    ;; table-run : TableStore -> TableStore
    [(expr-table-run store)
     (if (check ctx store (expr-table-store-type))
         (expr-table-store-type)
         (expr-error))]

    ;; table-lookup : TableStore -> Keyword -> A -> Bool
    [(expr-table-lookup store name answer)
     (if (and (check ctx store (expr-table-store-type))
              (check ctx name (expr-Keyword)))
         (begin (infer ctx answer)  ;; answer can be any type
                (expr-Bool))
         (expr-error))]

    ;; ---- Relational language (Phase 7) ----

    ;; Type constructors → Type 0
    [(expr-solver-type) (expr-Type (lzero))]
    [(expr-goal-type) (expr-Type (lzero))]
    [(expr-derivation-type) (expr-Type (lzero))]
    [(expr-answer-type t)
     (when t (check ctx t (expr-Type (lzero))))
     (expr-Type (lzero))]
    [(expr-relation-type pts)
     (for-each (lambda (p) (check ctx p (expr-Type (lzero)))) pts)
     (expr-Type (lzero))]

    ;; Runtime wrappers
    [(expr-solver-config m) (infer ctx m) (expr-solver-type)]
    [(expr-cut) (expr-goal-type)]
    [(expr-logic-var _ _) (expr-hole)]  ;; inferred from context

    ;; defr / rel → relation type (type-unsafe: returns hole)
    [(expr-defr nm sc vs)
     (when sc (infer ctx sc))
     (for-each (lambda (v) (infer ctx v)) vs)
     (expr-hole)]
    [(expr-defr-variant ps bd) (for-each (lambda (b) (infer ctx b)) bd) (expr-hole)]
    [(expr-rel ps cls) (for-each (lambda (c) (infer ctx c)) cls) (expr-hole)]

    ;; Clause/fact bodies → Goal
    [(expr-clause gs) (for-each (lambda (g) (infer ctx g)) gs) (expr-goal-type)]
    [(expr-fact-block rs) (for-each (lambda (r) (infer ctx r)) rs) (expr-goal-type)]
    [(expr-fact-row ts) (for-each (lambda (t) (infer ctx t)) ts) (expr-hole)]

    ;; Goals → Goal
    [(expr-goal-app nm as)
     (infer ctx nm)
     (for-each (lambda (a) (infer ctx a)) as)
     (expr-goal-type)]
    [(expr-unify-goal l r)
     (infer ctx l) (infer ctx r)
     (expr-goal-type)]
    [(expr-is-goal v ex)
     (infer ctx v) (infer ctx ex)
     (expr-goal-type)]
    [(expr-not-goal g) (infer ctx g) (expr-goal-type)]
    [(expr-guard cond goal)
     (check ctx cond (expr-Bool))
     (infer ctx goal)
     (expr-goal-type)]

    ;; Schema → schema-type

    ;; Solve/Explain → type-unsafe (hole)
    [(expr-solve g) (infer ctx g) (expr-hole)]
    [(expr-solve-with sv ov g)
     (when sv (infer ctx sv))
     (when ov (infer ctx ov))
     (infer ctx g)
     (expr-hole)]
    [(expr-solve-one g) (infer ctx g) (expr-hole)]
    [(expr-explain g) (infer ctx g) (expr-hole)]
    [(expr-explain-with sv ov g)
     (when sv (infer ctx sv))
     (when ov (infer ctx ov))
     (infer ctx g)
     (expr-hole)]

    ;; Narrow — functional-logic narrowing: type-unsafe (hole) like solve
    [(expr-narrow func args target vars)
     (infer ctx func)
     (for-each (lambda (a) (infer ctx a)) args)
     (infer ctx target)
     (expr-hole)]

    ;; ---- N4: numeric literal in INFER position (unconstrained: bare/top-level 3.14,
    ;; ---- arithmetic operand, polymorphic-fn arg) → its DEFAULT type (N6b: keyed on
    ;; ---- notation origin — decimal→Posit32, fraction→Rat, exponent→Int/Posit32).
    ;; ---- Context-typing happens in CHECK (fires before infer, solves alpha).
    [(expr-num-lit _ integral? origin _) (num-lit-default-type origin integral?)]

    ;; ---- Fallback: cannot infer ----
    [_ (expr-error)]))

;; ========================================
;; Type checking (checking mode)
;; ========================================
(define (check ctx e t)
  (perf-inc-infer!)  ;; counts both infer and check calls
  (match* (e (whnf t))
    ;; ---- suc: check against Nat ----
    [((expr-suc e1) (expr-Nat))
     (check ctx e1 (expr-Nat))]
    ;; ---- nat-val: always Nat ----
    [((expr-nat-val _) (expr-Nat)) #t]

    ;; ---- Panic: inhabits any type ----
    ;; (panic msg) checks against any T when msg : String
    [((expr-panic msg) _)
     (check ctx msg (expr-String))]

    ;; ---- Lambda: check against Pi ----
    ;; check(G, lam(m, A, body), Pi(m, A', B))
    ;; requires A conv A' and body checks against B in extended context
    ;; Special case: if A is expr-hole, use the expected domain AND multiplicity
    [((expr-lam m a body) (expr-Pi m2 t-dom b))
     (cond
       [(expr-hole? a)
        ;; Type hole: accept both the expected domain and multiplicity from the Pi type
        (check (ctx-extend ctx t-dom m2) body b)]
       ;; Sprint 7: lambda mult is mult-meta → accept Pi's mult
       [(mult-meta? m)
        (let ([resolved (if (mult-meta? m2) 'mw m2)])
          (solve-mult-meta! (mult-meta-id m) resolved)
          (when (mult-meta? m2)
            (solve-mult-meta! (mult-meta-id m2) resolved))
          (and (unify-ok? (unify ctx a t-dom))
               (check (ctx-extend ctx a resolved) body b)))]
       ;; Sprint 7: Pi mult is mult-meta → accept lambda's mult
       [(mult-meta? m2)
        (solve-mult-meta! (mult-meta-id m2) m)
        (and (unify-ok? (unify ctx a t-dom))
             (check (ctx-extend ctx a m) body b))]
       ;; Concrete mults: must match
       [(not (eq? m m2)) #f]
       [(not (unify-ok? (unify ctx a t-dom))) #f]
       [else (check (ctx-extend ctx a m) body b)])]

    ;; ---- Pair: check against Sigma ----
    ;; check(G, pair(e1, e2), Sigma(A, B))
    [((expr-pair e1 e2) (expr-Sigma a b))
     (and (check ctx e1 a)
          (check ctx e2 (subst 0 e1 b)))]

    ;; ---- refl: check against Eq ----
    ;; refl : Eq(A, e1, e2) iff conv(e1, e2)
    [((expr-refl) (expr-Eq _ e1 e2))
     (unify-ok? (unify ctx e1 e2))]

    ;; ---- Vec constructors ----
    ;; vnil(A) : Vec(A, zero)
    [((expr-vnil a1) (expr-Vec a2 n))
     (and (is-type ctx a1)
          (unify-ok? (unify ctx a1 a2))
          (unify-ok? (unify ctx n (expr-zero))))]

    ;; vcons(A, n, head, tail) : Vec(A, suc(n))
    [((expr-vcons a1 n1 hd tl) (expr-Vec a2 len))
     (and (unify-ok? (unify ctx a1 a2))
          (unify-ok? (unify ctx len (expr-suc n1)))
          (check ctx hd a1)
          (check ctx tl (expr-Vec a1 n1)))]

    ;; ---- Fin constructors ----
    ;; fzero(n) : Fin(suc(n))
    [((expr-fzero n1) (expr-Fin bound))
     (and (unify-ok? (unify ctx bound (expr-suc n1)))
          (check ctx n1 (expr-Nat)))]

    ;; fsuc(n, i) : Fin(suc(n))  when i : Fin(n)
    [((expr-fsuc n1 i) (expr-Fin bound))
     (and (unify-ok? (unify ctx bound (expr-suc n1)))
          (check ctx i (expr-Fin n1)))]

    ;; ---- N4: context-typed numeric literal (decimal/fraction/non-integral-exp) ----
    ;; Resolve alpha from the expected type T + validate representability. Concrete
    ;; numeric target → representability-gated solve; unsolved meta target → link + defer.
    ;; Refined numeric targets (PosRat etc.) are deferred (error) — a decimal rarely targets one.
    [((expr-num-lit exact-val integral? _origin alpha) T)
     (cond
       [(concrete-numeric-type? T)
        (and (num-lit-representable? exact-val integral? T)
             (unify-ok? (unify ctx alpha T)))]
       [(expr-meta? T)
        (unify-ok? (unify ctx alpha T))]
       [else #f])]

    ;; ---- Int literal check ----
    [((expr-int v) (expr-Int))
     (exact-integer? v)]

    ;; ---- Rat literal check ----
    [((expr-rat v) (expr-Rat))
     (and (exact? v) (rational? v))]

    ;; ---- Posit8 literal check ----
    [((expr-posit8 v) (expr-Posit8))
     (and (exact-integer? v) (<= 0 v 255))]

    ;; ---- Posit16 literal check ----
    [((expr-posit16 v) (expr-Posit16))
     (and (exact-integer? v) (<= 0 v 65535))]

    ;; ---- Posit32 literal check ----
    [((expr-posit32 v) (expr-Posit32))
     (and (exact-integer? v) (<= 0 v 4294967295))]

    ;; ---- Float literal check (Numerics N3) ----
    [((expr-float32 v) (expr-Float32)) (flonum? v)]
    [((expr-float64 v) (expr-Float64)) (flonum? v)]

    ;; ---- Posit64 literal check ----
    [((expr-posit64 v) (expr-Posit64))
     (and (exact-integer? v) (<= 0 v 18446744073709551615))]

    ;; ---- Symbol literal check ----
    [((expr-symbol _) (expr-Symbol)) #t]

    ;; ---- Keyword literal check ----
    [((expr-keyword _) (expr-Keyword)) #t]

    ;; ---- Char literal check ----
    [((expr-char _) (expr-Char)) #t]

    ;; ---- String literal check ----
    [((expr-string _) (expr-String)) #t]

    ;; ---- Map checks ----
    ;; champ checked against Map K V
    [((expr-champ _) (expr-Map _ _)) #t]
    ;; map-empty checked against Map K V
    [((expr-map-empty k1 v1) (expr-Map k2 v2))
     ;; CIU T6 F1 (B1): an empty-closed record SEED asserts no fields, so it satisfies any
     ;; (Map K V) — unify keys only, SKIP the value-unify (else it fails / flex-rigid-poisons ?V).
     ;; Per-entry strictness is preserved by the map-assoc-vs-Map arm as the chain unwinds.
     (if (and (expr-Record? v1) (null? (expr-Record-fields v1)))
         (unify-ok? (unify ctx k1 k2))
         (and (unify-ok? (unify ctx k1 k2))
              (unify-ok? (unify ctx v1 v2))))]
    ;; map-assoc checked against Map K V — propagate expected type
    [((expr-map-assoc m k v) (expr-Map kt vt))
     (and (check ctx m (expr-Map kt vt))
          (check ctx k kt)
          (check ctx v vt))]
    ;; CIU T6 F1b.4e (D22): map-assoc checked against Schema type — the
    ;; SEAL-BOUNDARY chain walk: per-entry checks + ONE residual at THIS
    ;; boundary (no recursive re-entry with the schema expectation — the old
    ;; recursion made the map-empty base arm the de-facto residual point,
    ;; whose blanket #t WAS the width-partial acceptance; the flip retires it).
    [((expr-map-assoc m k v) (expr-fvar schema-name))
     #:when (lookup-schema-by-name schema-name)
     (let ([schema (lookup-schema-by-name schema-name)])
       (check-seal-chain ctx (expr-map-assoc m k v) schema
                         (lambda (provided open?)
                           (schema-seal-residual-ok? schema provided open?))))]
    ;; F1b.4e: map-assoc checked against Selection type — same walk (field
    ;; TYPES validate against the PARENT: a selection is a read-side VIEW,
    ;; extra parent fields by-design), but the RESIDUAL requires only the
    ;; SELECTION's requires-subset (D22 "delegate against their SUBSET").
    [((expr-map-assoc m k v) (expr-fvar sel-name))
     #:when (lookup-selection-by-name sel-name)
     (let* ([sel (lookup-selection-by-name sel-name)]
            [schema (lookup-selection-parent-schema sel)])
       (and schema
            (check-seal-chain ctx (expr-map-assoc m k v) schema
                              (lambda (provided open?)
                                (selection-seal-residual-ok? sel schema provided open?)))))]
    ;; F1b.4e: map-empty checked against Selection type — the residual with
    ;; EXACT empty knowledge (an empty literal seals iff the selection
    ;; requires nothing, or everything it requires is parent-defaulted).
    [((expr-map-empty k1 v1) (expr-fvar sel-name))
     #:when (lookup-selection-by-name sel-name)
     (let* ([sel (lookup-selection-by-name sel-name)]
            [schema (lookup-selection-parent-schema sel)])
       (and schema (selection-seal-residual-ok? sel schema '() #f)))]
    ;; CIU T6 F1b.4a (D22.8): champ-vs-selection RETIRED LOUD — a champ is a
    ;; RUNTIME map value (born only in reduction, after type-check); statically
    ;; sealing one is validate's job (F1b.5). The old unconditional #t was a
    ;; blanket-accept hole (dead at HEAD, probe-verified — but fails CLOSED now
    ;; so any future flow that re-checks reduced values gets a refusal, not a
    ;; silent pass). Runtime discharge: validate (Result-returning tabulation).
    [((expr-champ v) (expr-fvar sel-name))
     #:when (lookup-selection-by-name sel-name)
     #f]
    ;; CIU T6 F1b.4e (D22.3): the blanket-accept base RETIRES — THIS #t was
    ;; the width-partial acceptance (the recursion base + P5's silent-missing
    ;; gap). An empty literal now seals iff every schema field is defaulted
    ;; (the residual with EXACT empty knowledge). Census: zero live flips in
    ;; gated surfaces (F1b.4 mini-audit facet 6).
    [((expr-map-empty _ _) (expr-fvar schema-name))
     #:when (lookup-schema-by-name schema-name)
     (schema-seal-residual-ok? (lookup-schema-by-name schema-name) '() #f)]
    ;; CIU T6 F1b.4a (D22.8): champ-vs-schema RETIRED LOUD (see the selection
    ;; twin above — same rationale; runtime seal = validate, F1b.5).
    [((expr-champ _) (expr-fvar schema-name))
     #:when (lookup-schema-by-name schema-name)
     #f]

    ;; ---- Set checks ----
    ;; hset checked against Set A
    [((expr-hset _) (expr-Set _)) #t]
    ;; set-empty checked against Set A
    [((expr-set-empty a1) (expr-Set a2))
     (unify-ok? (unify ctx a1 a2))]
    ;; set-insert checked against Set A — propagate expected type
    [((expr-set-insert s a) (expr-Set a-ty))
     (and (check ctx s (expr-Set a-ty))
          (check ctx a a-ty))]

    ;; ---- PVec checks ----
    [((expr-rrb _) (expr-PVec _)) #t]
    [((expr-pvec-empty a1) (expr-PVec a2))
     (unify-ok? (unify ctx a1 a2))]
    ;; CIU T6 F1a-col: literal checked against (PVec A) — each element against A
    ;; (the union check arm handles <T1|T2> annotations; preserves the C2 behavior).
    [((expr-pvec-literal elems) (expr-PVec a))
     (for/and ([el (in-list elems)]) (check ctx el a))]
    ;; CIU T6 F1a-col-2: list literal vs (List A) — each element against A.
    [((expr-list-literal elems _) (expr-app f a))
     #:when (equal? f (list-type-fvar))
     (for/and ([el (in-list elems)]) (check ctx el a))]
    ;; CIU T6 F1a.2 p1b (D18): map literal vs (Map K V) — each key against K,
    ;; each value against V (the C2 annotated-literal behavior: an inline
    ;; literal in a checked position is per-entry strict against the annotation).
    [((expr-map-literal keys vals _) (expr-Map kt vt))
     (and (for/and ([k (in-list keys)]) (check ctx k kt))
          (for/and ([v (in-list vals)]) (check ctx v vt)))]
    [((expr-pvec-push v x) (expr-PVec a))
     (and (check ctx v (expr-PVec a))
          (check ctx x a))]
    ;; pvec-fold : check against result type B
    ;; Pi codomains shifted for de Bruijn convention.
    [((expr-pvec-fold f init vec) expected-type)
     (let ([tv (whnf (infer ctx vec))])
       (match tv
         [(expr-PVec a)
          (and (check ctx init expected-type)
               (check ctx f (expr-Pi 'mw expected-type
                              (expr-Pi 'mw (shift 1 0 a) (shift 2 0 expected-type)))))]
         ;; CIU T6 F1a-col-3: fold over a tuple in CHECK mode — uniform view (the arm's
         ;; catch-all expected pattern means a tuple subject would otherwise hard-fail
         ;; with no fallthrough to the conversion-fallback α).
         [(? closed-nat-row? rec)
          (and (check ctx init expected-type)
               (check ctx f (expr-Pi 'mw expected-type
                              (expr-Pi 'mw (shift 1 0 (record-value-bound ctx rec "tuple-fold"))
                                       (shift 2 0 expected-type)))))]
         [_ #f]))]
    ;; pvec-map : check against PVec B
    [((expr-pvec-map f vec) (expr-PVec b))
     (let ([tv (whnf (infer ctx vec))])
       (match tv
         [(expr-PVec a)
          (check ctx f (expr-Pi 'mw a (shift 1 0 b)))]
         ;; CIU T6 F1a-col-3: tuple source checked against (PVec B) — f consumes ⋃positions
         [(? closed-nat-row? rec)
          (check ctx f (expr-Pi 'mw (record-value-bound ctx rec "tuple-map") (shift 1 0 b)))]
         [_ #f]))]
    ;; pvec-filter : check against PVec A
    [((expr-pvec-filter pred vec) (expr-PVec a))
     (and (check ctx pred (expr-Pi 'mw a (expr-Bool)))
          (check ctx vec (expr-PVec a)))]
    ;; set-fold : check against result type B
    [((expr-set-fold f init set) expected-type)
     (let ([ts (infer ctx set)])
       (match ts
         [(expr-Set a)
          (and (check ctx init expected-type)
               (check ctx f (expr-Pi 'mw expected-type
                              (expr-Pi 'mw (shift 1 0 a) (shift 2 0 expected-type)))))]
         [_ #f]))]
    ;; set-filter : check against Set A
    [((expr-set-filter pred set) (expr-Set a))
     (and (check ctx pred (expr-Pi 'mw a (expr-Bool)))
          (check ctx set (expr-Set a)))]
    ;; map-fold-entries : check against result type B
    [((expr-map-fold-entries f init map) expected-type)
     (let ([tm (whnf (infer ctx map))])
       (match tm
         [(expr-Map k v)
          (and (check ctx init expected-type)
               (check ctx f (expr-Pi 'mw expected-type
                              (expr-Pi 'mw (shift 1 0 k)
                                (expr-Pi 'mw (shift 2 0 v) (shift 3 0 expected-type))))))]
         ;; CIU T6 F1 (s3): fold over a record — uniform view (K=Keyword, V=⋃fields)
         ;; F1a.2 p1a: dyn rows fold over the BOUND (§12.4).
         [(? expr-Record? rec)
          (and (check ctx init expected-type)
               (check ctx f (expr-Pi 'mw expected-type
                              (expr-Pi 'mw (shift 1 0 (expr-Keyword))
                                (expr-Pi 'mw (shift 2 0 (record-value-bound ctx rec (dyn-row-source 'dyn-row-fold)))
                                         (shift 3 0 expected-type))))))]
         [_ #f]))]
    ;; map-filter-entries : check against Map K V
    [((expr-map-filter-entries pred map) (expr-Map k v))
     (and (check ctx pred (expr-Pi 'mw k (expr-Pi 'mw (shift 1 0 v) (expr-Bool))))
          (check ctx map (expr-Map k v)))]
    ;; map-map-vals : check against Map K W
    [((expr-map-map-vals f map) (expr-Map k w))
     (let ([tm (whnf (infer ctx map))])
       (match tm
         [(expr-Map k2 v)
          (and (unify-ok? (unify ctx k k2))
               (check ctx f (expr-Pi 'mw v (shift 1 0 w))))]
         ;; CIU T6 F1 (s3): record source checked against a Map result — keys are Keyword;
         ;; f consumes the uniform view ⋃fields (the BOUND for dyn rows, F1a.2 p1a §12.4)
         [(? expr-Record? rec)
          (and (unify-ok? (unify ctx k (expr-Keyword)))
               (check ctx f (expr-Pi 'mw (record-value-bound ctx rec (dyn-row-source 'dyn-row-map-vals)) (shift 1 0 w))))]
         [_ #f]))]

    ;; ---- Transient Builder checks ----
    [((expr-trrb _) (expr-TVec _)) #t]
    [((expr-tchamp _) (expr-TMap _ _)) #t]
    [((expr-thset _) (expr-TSet _)) #t]
    [((expr-persist-vec t) (expr-PVec a))
     (check ctx t (expr-TVec a))]
    [((expr-persist-map t) (expr-Map k v))
     (check ctx t (expr-TMap k v))]
    [((expr-persist-set t) (expr-Set a))
     (check ctx t (expr-TSet a))]
    [((expr-tvec-push! t x) (expr-TVec a))
     (and (check ctx t (expr-TVec a))
          (check ctx x a))]
    [((expr-tvec-update! t i x) (expr-TVec a))
     (and (check ctx t (expr-TVec a))
          (check ctx i (expr-Nat))
          (check ctx x a))]
    [((expr-tmap-assoc! t k v) (expr-TMap kt vt))
     (and (check ctx t (expr-TMap kt vt))
          (check ctx k kt)
          (check ctx v vt))]
    [((expr-tmap-dissoc! t k) (expr-TMap kt vt))
     (and (check ctx t (expr-TMap kt vt))
          (check ctx k kt))]
    [((expr-tset-insert! t a) (expr-TSet a-ty))
     (and (check ctx t (expr-TSet a-ty))
          (check ctx a a-ty))]
    [((expr-tset-delete! t a) (expr-TSet a-ty))
     (and (check ctx t (expr-TSet a-ty))
          (check ctx a a-ty))]

    ;; ---- PropNetwork runtime wrappers ----
    [((expr-prop-network _) (expr-net-type)) #t]
    [((expr-cell-id _) (expr-cell-id-type)) #t]
    [((expr-prop-id _) (expr-prop-id-type)) #t]

    ;; ---- UnionFind runtime wrapper ----
    [((expr-uf-store _) (expr-uf-type)) #t]

    ;; ---- Tabling runtime wrapper ----
    [((expr-table-store-val _) (expr-table-store-type)) #t]

    ;; ---- Relational language runtime wrappers ----
    [((expr-solver-config _) (expr-solver-type)) #t]

    ;; ---- Reduce: ML-style Church elimination ----
    ;; check(G, reduce(scrutinee, arms), T)
    ;; 1. Infer scrutinee type, WHNF it to get Church Pi chain
    ;; 2. Build the Church application: (scrutinee T arm1 arm2 ...)
    ;; 3. Type-check the generated application
    [((expr-reduce scrutinee arms _) expected-type)
     (check-reduce ctx e scrutinee arms expected-type)]

    ;; ---- Hole expression: checks against any type ----
    ;; An expr-hole is a placeholder that will be filled by type inference.
    [((expr-hole) _) #t]


    ;; ---- Typed hole: reports expected type + context to stderr, then succeeds ----
    [((expr-typed-hole name) expected)
     (define hole-label (if name (format "??~a" name) "??"))
     (define pp-type (pp-expr expected))
     ;; Build context report with synthetic names
     (define hole-base-names '("x" "y" "z" "a" "b" "c" "d" "e" "f" "g" "h"))
     (define ctx-lines
       (for/list ([i (in-range (ctx-len ctx))])
         (define ty (lookup-type i ctx))
         (define m (lookup-mult i ctx))
         (define var-name
           (if (< i (length hole-base-names))
               (list-ref hole-base-names i)
               (format "v~a" i)))
         ;; Build name stack for pp-expr: indices 0..i mapped to names
         (define names-for-pp
           (for/list ([j (in-range (+ i 1))])
             (if (< j (length hole-base-names))
                 (list-ref hole-base-names j)
                 (format "v~a" j))))
         (format "  ~a : ~a  (~a)" var-name (pp-expr ty names-for-pp) (pp-mult m))))
     (fprintf (current-error-port)
              "Hole ~a : ~a\n~a"
              hole-label
              pp-type
              (if (null? ctx-lines)
                  ""
                  (format "Context:\n~a\n" (string-join ctx-lines "\n"))))
     #t]

    ;; ---- Meta expression: optimistically succeed ----
    ;; A metavariable in expression position (e.g., implicit argument)
    ;; will be solved by unification constraints from other arguments.
    ;; We can't infer its type yet, so accept it optimistically.
    [((expr-meta _ _) _) #t]

    ;; ---- nil overloading: check against Nil or List ----
    ;; nil checks against Nil (the nullable type)
    [((expr-nil) (expr-Nil)) #t]
    ;; nil checks against List A (backward compat — nil is the empty list)
    [((expr-nil) t-check)
     #:when (let-values ([(tname _targs) (decompose-type-app (whnf t-check))])
              (and tname (eq? (bare-name tname) 'List)))
     #t]

    ;; ---- Union type: check against A | B ----
    ;; check(G, e, A | B) succeeds if e : A or e : B.
    ;; Phase 5: speculative rollback with network fork/restore.
    ;; CIU T6 F1a.2 p0 (bug fix, p3 perf-refit): a term whose INFERRED type is
    ;; the WHOLE union can never re-derive it branch-wise; the whole-union
    ;; conversion runs on the BOTH-FAIL path only. The branch split stays
    ;; EXACTLY as it always was (left rollback-probed, right bare) — the p0
    ;; version rollback-wrapped the right branch and paid a fork on every
    ;; successful right-branch check (measured +7% on typing-dominated
    ;; programs). (checkQ has the same shape — mirror them together.)
    [(_ (expr-union l r))
     (or (with-speculative-rollback
           (lambda () (check ctx e l))
           values
           "union-check-left")
         (check ctx e r)
         (let ([t1 (infer ctx e)])
           (and (not (expr-error? t1))
                (unify-ok? (unify ctx (expr-union l r) t1)))))]

    ;; ---- Checking against hole type: succeed if expression is inferrable ----
    ;; When the expected type is a hole, just verify the expression is well-typed.
    [(_ (expr-hole))
     (not (expr-error? (infer ctx e)))]

    ;; ---- Let pattern (beta-redex): propagate expected type into body ----
    ;; (app (lam m dom body) arg) is the desugared form of (let x := arg in body).
    ;; Without this case, the conversion fallback tries to infer the body type,
    ;; which fails for match/reduce expressions (infer has no expr-reduce case).
    ;; Fix: propagate the expected type into the body via check, not infer.
    ;; The expected type must be shifted by 1 to account for the new binder.
    [((expr-app (expr-lam m dom body) arg) expected-type)
     (cond
       [(expr-hole? dom)
        ;; Hole domain: infer arg type, extend context, check body
        (let ([arg-ty (infer ctx arg)])
          (and (not (expr-error? arg-ty))
               (let ([m-resolved (if (mult-meta? m) 'mw m)])
                 (when (mult-meta? m)
                   (solve-mult-meta! (mult-meta-id m) m-resolved))
                 (check (ctx-extend ctx arg-ty m-resolved) body
                        (shift 1 0 expected-type)))))]
       ;; Explicit domain: check arg against domain, check body with extended context
       [(and (is-type ctx dom) (check ctx arg dom))
        (check (ctx-extend ctx dom m) body (shift 1 0 expected-type))]
       [else #f])]

    ;; ---- Conversion fallback ----
    ;; If e synthesizes to T' and conv(T, T'), then check succeeds.
    ;; Cumulativity: if T' = Type(m) and T = Type(n) where m ≤ n, accept.
    ;; This allows types from lower universes to be used where higher universes are expected.
    [(_ t-whnf)
     (let ([t1 (infer ctx e)])
       (and (not (expr-error? t1))
            (or (unify-ok? (unify ctx t t1))
                (match* ((whnf t) (whnf t1))
                  ;; Cumulativity: Type(m) ≤ Type(n) when m ≤ n
                  [((expr-Type l1) (expr-Type l2))
                   (level<=? l2 l1)]
                  ;; CIU T6 F1 (s2): a structural record satisfies a (Map K V) annotation
                  ;; (the Galois α — replaces seeded-Open absorption, more precise).
                  [((? expr-Map? mt) (? expr-Record? rec))
                   (record-<:-map? ctx rec (expr-Map-k-type mt) (expr-Map-v-type mt))]
                  ;; CIU T6 F1a-col: a 'nat row (tuple) satisfies a (PVec A) annotation
                  ;; (the Tuple→PVec α; a meta A solves to ⋃positions).
                  [((? expr-PVec? pt) (? expr-Record? rec))
                   (record-<:-pvec? ctx rec (expr-PVec-elem-type pt))]
                  ;; CIU T6 F1a-col-2: a 'nat row satisfies a (List A) annotation
                  ;; (same α, List-shaped container).
                  [((expr-app f a) (? expr-Record? rec))
                   #:when (equal? f (list-type-fvar))
                   (record-<:-elem? ctx rec a)]
                  ;; CIU T6 F1b.4a (D22): a keyword row satisfies a SCHEMA
                  ;; expectation — the row-vs-schema discharge (per-field
                  ;; CHECK-strength on knowns; width-partial toward missing
                  ;; until 4e's residual). `the Person m` on a def-bound row
                  ;; stops being an inference error here.
                  [((expr-fvar sname) (? expr-Record? rec))
                   #:when (lookup-schema-by-name sname)
                   ;; F1b.4e: per-field + the RESIDUAL (missing-required /
                   ;; closedness) — the row-route seal boundary.
                   (record-seals-schema? ctx rec (lookup-schema-by-name sname))]
                  ;; F1b.4a/4e: row vs SELECTION — parent types + the
                  ;; selection's requires-subset residual.
                  [((expr-fvar selname) (? expr-Record? rec))
                   #:when (lookup-selection-by-name selname)
                   (record-seals-selection? ctx rec (lookup-selection-by-name selname))]
                  ;; F1b.4a: schema-typed ACTUAL where a Map is expected — the
                  ;; free up-shift direction (D22.7): project schema→row and
                  ;; ride the EXISTING record→Map α.
                  [((? expr-Map? mt) (expr-fvar sname))
                   #:when (lookup-schema-by-name sname)
                   (record-<:-map? ctx (schema->row (lookup-schema-by-name sname))
                                   (expr-Map-k-type mt) (expr-Map-v-type mt))]
                  ;; F1b.4a: schema-typed ACTUAL where a ROW is expected — the
                  ;; projection feeding the D21 width machinery (a schema value
                  ;; flowing into a row-solved position discharges by width).
                  [((? expr-Record? t-rec) (expr-fvar sname))
                   #:when (and (lookup-schema-by-name sname)
                               (record-width-applicable?
                                t-rec (schema->row (lookup-schema-by-name sname))))
                   (record-width-discharge?
                    ctx t-rec (schema->row (lookup-schema-by-name sname)))]
                  ;; CIU T6 F1b.3 (D21): erasure-mode WIDTH discharge — a wider closed
                  ;; keyword row satisfies a narrower closed keyword row expectation
                  ;; (fact-subset: extras on the actual erased; shared fields at
                  ;; equality-depth via the relaxed-C_Cons delegation). The #:when
                  ;; carries the STATIC guards only, so guard-failing Record pairs
                  ;; ('nat tuples, mixed domains, dyn tails) still fall through to
                  ;; the subtype? leg (match* commits — the shadow would otherwise
                  ;; silently pre-empt a future judgment there).
                  [((? expr-Record? t-rec) (? expr-Record? t1-rec))
                   #:when (record-width-applicable? t-rec t1-rec)
                   (record-width-discharge? ctx t-rec t1-rec)]
                  ;; Phase 3e: within-family subtyping
                  [(t-w t1-w) (subtype? t1-w t-w)]))))]))

;; ========================================
;; CIU T6 F1b.3 (D21): the erasure-mode width discharge
;; ========================================
;;
;; ONE shared realization for check's conversion fallback AND qtt's checkQ
;; fallback twin (the issue-#76 mirror-drift cap). The principled reading:
;; width discharge = viewing the EXPECTED row through the open-row lens —
;; Tang-style upcast erasure erases the expected side's closure fact for the
;; comparison, realized by relaxing the expected tail 'closed→'dyn on a copy
;; and delegating to the EXISTING unify/C_Cons machinery (no new comparison
;; algebra; unify/classify itself is UNTOUCHED, keeping the D15 literal-
;; homogeneity probes structurally safe). Direction proof: unify is called
;; expected-first, so C_Cons's containment guard demands expected-labels ⊆
;; actual-labels (= actual ⊇ expected, exactly fact-subset width), and the
;; shared-label 'sub goals run per-field unify (equality-depth; metas solve —
;; the D21 residue posture). Covariant depth is the F-carrier-era upgrade
;; (triggers pinned at D21) — it CANNOT ride C_Cons ('sub goals are pure
;; unify pairs), so the upgrade swaps this realization, never patches unify.

;; STATIC applicability (side-effect-free — safe in #:when): both sides
;; closed keyword rows (tuples exact/no-width; dyn pairs already have C_Cons
;; in the primary unify leg) + label containment pre-filter (a statically
;; hopeless width event must not fork — each rollback mints a mandatory ATMS
;; hypothesis; C_Cons would re-check containment, but only after the fork).
(define (record-width-applicable? expected-rec actual-rec)
  (and (closed-keyword-row? expected-rec)
       (closed-keyword-row? actual-rec)
       (let ([la (map car (expr-Record-fields expected-rec))]
             [lb (map car (expr-Record-fields actual-rec))])
         (andmap (lambda (l) (and (memv l lb) #t)) la))))

;; The discharge proper: relax + delegate under rollback (union-check-left
;; precedent — the probe is wrapped, failure restores meta state; the SUCCESS
;; path is bare per the F1a.2 p3 refit lesson). Field metas solved on success
;; are the accepted D21 residue. The relaxed row is built by DIRECT
;; construction (fields are smart-constructor-canonical — the elaborator-seed
;; precedent; make-record's re-sort would be a no-op cost).
(define (record-width-discharge? ctx expected-rec actual-rec)
  (and (with-speculative-rollback
         (lambda ()
           (unify-ok? (unify ctx
                             (expr-Record 'keyword
                                          (expr-Record-fields expected-rec)
                                          'dyn)
                             actual-rec)))
         values
         "record-width-discharge")
       #t))

;; ========================================
;; CIU T6 F1b.4a (D22): the schema→row up-shift + the row-vs-schema discharge
;; ========================================
;;
;; schema->row — project a schema-entry to a CLOSED keyword row (the up-shift's
;; carrier: schema facts become row facts, feeding the EXISTING record→Map αs
;; and the D21 width machinery). ONE-LEVEL: nested sub-schemas stay opaque
;; fvars (their type-datum is the auto-registered sub-name symbol, which
;; schema-field-type->expr maps to an expr-fvar) — deep projection is not
;; needed by any current consumer and would open the recursive-schema
;; undecidability edge (R-note §known-hard-edges). All fields 'present
;; (a schema field IS a positive observation; :default-filled = 'present per
;; D22.6 — the fill happens at the seal boundary, not here).
(define (schema->row schema)
  (make-record 'keyword
               (for/list ([f (in-list (schema-entry-fields schema))])
                 (cons (schema-field-keyword f)
                       (record-field (schema-field-type->expr (schema-field-type-datum f))
                                     'present)))
               'closed))

;; F1b.7e: project a schema-fvar type to its row (else identity), so the
;; structural map-op infer arms (map-keys/vals/assoc/dissoc/has-key?/nil-safe-get/
;; size) treat a schema value like the anonymous row it up-shifts to — their
;; existing (? expr-Record?) arm then fires. Mirrors map-get's schema-fvar arm;
;; reuses schema->row (the D22 carrier); yields ROW results (map-assoc→grown row,
;; etc.), matching anon-row behavior. LOCAL by design — whnf must NOT globally
;; unfold a schema fvar (nominal opacity: the seal + display + selection gating
;; all depend on it staying opaque). SELECTION fvars are deliberately NOT
;; projected here: a selection restricts reads to its :requires (the
;; read-capability, per map-get's selection arm), which is selection-projection
;; design — deferred (DEFERRED.md § selection projections).
(define (schema-fvar->row-or-self tm)
  (if (and (expr-fvar? tm) (lookup-schema-by-name (expr-fvar-name tm)))
      (schema->row (lookup-schema-by-name (expr-fvar-name tm)))
      tm))

;; record-<:-schema? — a keyword row (closed OR dyn) satisfies a schema
;; expectation on its KNOWN fields: per-field CHECK-strength (unify ∨ subtype?
;; — the record-<:-map? concrete-V idiom; the D21 boundary invariant is what
;; makes a future `Num`-supertype schema field accept an Int row field here);
;; unknown row fields consult closed? (mirroring the map-assoc-vs-schema arm);
;; fields MISSING from the row are ACCEPTED — today's width-partial posture.
;; The residual scan (F1b.4e) owns missing-required/fill/closedness at the
;; seal boundary; a dyn row's remainder additionally can't witness absence,
;; which 4e's closedness scan handles (refuse :closed seals on dyn actuals).
(define (record-<:-schema? ctx rec schema)
  (and (eq? (expr-Record-key-domain rec) 'keyword)
       (andmap (lambda (f)
                 (let* ([label (car f)]
                        [ft (record-field-type (cdr f))]
                        [field (schema-lookup-field schema label)])
                   (if field
                       (field-type-satisfies?
                        ctx ft (schema-field-type->expr (schema-field-type-datum field)))
                       (not (schema-entry-closed? schema)))))
               (expr-Record-fields rec))))

;; (record-<:-selection? RETIRED at F1b.4e — superseded by record-seals-
;; selection?, which adds the selection's requires-subset residual to the
;; parent per-field discharge.)

;; Shared parent-schema resolution (selection entries store the schema NAME).
(define (lookup-selection-parent-schema sel)
  (lookup-schema-by-name (selection-entry-schema-name sel)))

;; ========================================
;; CIU T6 F1b.4e (D22): the seal RESIDUAL + the boundary chain walk
;; ========================================
;;
;; schema-seal-residual-ok? — runs ONCE per seal boundary. `provided` = the
;; labels the boundary KNOWS are present; `open?` = the knowledge is
;; open-ended (dyn tail / dynamic keys / unknown base — the remainder may
;; provide more at runtime, the C_Cons gradual posture, D16). Rules:
;;   missing + defaulted      → OK (literal routes are preparse-FILLED; the
;;                              non-literal fill = validate's tabulation,
;;                              F1b.5 — the M2 amendment: type-accepted here)
;;   missing + required:
;;     open?                  → ABSORBED (gradual; a runtime projection may miss)
;;     exact knowledge        → #f — MISSING-REQUIRED, the D22.3 flip
;;   closedness: a :closed schema REFUSES open? actuals (cannot verify the
;;   absence of extras — the seal-time closedness scan, CUE lesson).
(define (schema-seal-residual-ok? schema provided open?)
  (and (or (not (schema-entry-closed? schema)) (not open?))
       (andmap (lambda (f)
                 (or (memq (schema-field-keyword f) provided)
                     (and (schema-field-default-val f) #t)
                     open?))
               (schema-entry-fields schema))))

;; The selection residual: CLOSEDNESS ONLY — selections have NO completeness
;; requirement at construction. Empirically decisive (test-selection-paths
;; sel-path/nameaddr-name-gated: a by-design partial value omits a
;; requires-path field entirely): `:requires` is a READ-CAPABILITY
;; declaration (which paths consumers may access), not a value-completeness
;; contract; selection-typed values are PARTIAL VIEWS by design, and
;; completeness is the PARENT schema seal's business. D22's "delegate
;; against their SUBSET" = the residual never enumerates the parent's field
;; set for a selection (which would break all 10 by-design width-partial
;; sites). Runtime misses on partial views discharge via validate (F1b.5).
(define (selection-seal-residual-ok? sel schema provided open?)
  (or (not (schema-entry-closed? schema)) (not open?)))

;; check-seal-chain — the seal-boundary walk over a LITERAL map-assoc chain:
;; per-entry checks against the PARENT schema (types), collecting provided
;; labels, then residual-fn ONCE with the union knowledge. A non-literal
;; BASE contributes its row's fields residual-FREE (record-<:-schema? — the
;; per-field 4a helper), with open?=#t for dyn tails / unknown-typed bases.
(define (check-seal-chain ctx chain schema residual-fn)
  (let loop ([e chain] [provided '()] [open? #f])
    (match e
      [(expr-map-assoc m2 k2 v2)
       (match k2
         [(expr-keyword kw-sym)
          (let ([field (schema-lookup-field schema kw-sym)])
            (and (if field
                     (check ctx v2 (schema-field-type->expr (schema-field-type-datum field)))
                     ;; :closed schemas reject unknown fields; open infer them
                     (if (schema-entry-closed? schema)
                         #f
                         (not (expr-error? (infer ctx v2)))))
                 (loop m2 (cons kw-sym provided) open?)))]
         [_ ;; dynamic key: coverage unknown — may provide any field at runtime
          (and (check ctx k2 (expr-Keyword))
               (not (expr-error? (infer ctx v2)))
               (loop m2 provided #t))])]
      [(expr-map-empty _ _)
       ;; literal-complete: EXACT knowledge
       (residual-fn provided open?)]
      [base
       (let ([bt (whnf (infer ctx base))])
         (cond
           [(expr-error? bt) #f]
           [(expr-Record? bt)
            (and (record-<:-schema? ctx bt schema)
                 (residual-fn (append provided (map car (expr-Record-fields bt)))
                              (or open? (eq? (expr-Record-tail bt) 'dyn))))]
           [else
            ;; unknown-typed base (a sealed value, a Map-typed def, a meta):
            ;; gradual — the base may provide anything
            (residual-fn provided #t)]))])))

;; F1b.4e diagnostic support (NOT part of the discharge): which REQUIRED
;; schema fields are missing from a seal term's EXACT knowledge? Returns the
;; missing labels, or #f when the knowledge is open (dyn tail / dynamic keys
;; / unknown base — no missing-required claim is possible there). Consumed by
;; the S7-style hint in typing-errors.
(define (seal-missing-required ctx term schema)
  (define (missing-from provided)
    (for/list ([f (in-list (schema-entry-fields schema))]
               #:unless (or (memq (schema-field-keyword f) provided)
                            (schema-field-default-val f)))
      (schema-field-keyword f)))
  (let loop ([e term] [provided '()])
    (match e
      [(expr-map-assoc m2 (expr-keyword kw) _) (loop m2 (cons kw provided))]
      [(expr-map-assoc _ _ _) #f]  ;; dynamic key → open knowledge
      [(expr-map-empty _ _) (missing-from provided)]
      [base
       (let ([bt (whnf (infer ctx base))])
         (and (expr-Record? bt)
              (eq? (expr-Record-tail bt) 'closed)
              (missing-from (append provided
                                    (map car (expr-Record-fields bt))))))])))

;; CIU T6 F1b.7f diagnostic (NOT part of the discharge): the FIRST provided field
;; of a map-assoc chain whose value type-MISMATCHES its schema field (the wrong-
;; type case seal-missing-required cannot see — it is presence-only). Returns
;; (list field-kw expected-type-expr actual-type-expr-or-#f) or #f. Mirrors the
;; per-field `check` in check-seal-chain; used by the typing-errors.rkt infer/err
;; + check/err hints to NAME the offending field on BOTH seal doors.
(define (seal-first-field-type-mismatch ctx chain schema)
  (let loop ([e chain])
    (match e
      [(expr-map-assoc m2 (expr-keyword kw-sym) v2)
       (let ([field (schema-lookup-field schema kw-sym)])
         (if field
             (let ([ft (schema-field-type->expr (schema-field-type-datum field))])
               (if (check ctx v2 ft)
                   (loop m2)
                   (list kw-sym ft (let ([at (infer ctx v2)])
                                     (and (not (expr-error? at)) at)))))
             (loop m2)))]        ;; field not in schema (open accepts / closed = other error) — skip
      [(expr-map-assoc m2 _ v2) (loop m2)]  ;; dynamic key — skip
      [_ #f])))

;; CIU T6 F1b.7f: is a whnf'd type an acceptable validate SUBJECT (map-like)?
;; Lifted to module level (was a local closure in the expr-validate infer rule)
;; and PROVIDED so the typing-errors validate-nonmap hint reuses the EXACT
;; predicate (no drift). Gradual: unsolved metas / holes accept (the open?
;; posture — unannotated defn params zonk their domain metas to holes).
(define (validate-subject-map-ish? t)
  (match t
    [(? expr-Record? _) #t]
    [(expr-Map _ _) #t]
    [(expr-fvar n) (and (or (lookup-schema-by-name n) (lookup-selection-by-name n)) #t)]
    [(? expr-union? u) (ormap (lambda (b) (validate-subject-map-ish? (whnf b))) (flatten-union u))]
    [(? expr-meta? _) #t]
    [(? expr-hole? _) #t]
    [(? expr-typed-hole? _) #t]
    [_ #f]))


;; The row-vs-schema/selection SEAL discharges (per-field + residual) — the
;; conversion-fallback + qtt-twin entry points (shared, mirror-drift cap).
(define (record-seals-schema? ctx rec schema)
  (and (record-<:-schema? ctx rec schema)
       (schema-seal-residual-ok? schema (map car (expr-Record-fields rec))
                                 (eq? (expr-Record-tail rec) 'dyn))))

(define (record-seals-selection? ctx rec sel)
  (define schema (lookup-selection-parent-schema sel))
  (and schema
       (record-<:-schema? ctx rec schema)
       (selection-seal-residual-ok? sel schema (map car (expr-Record-fields rec))
                                    (eq? (expr-Record-tail rec) 'dyn))))

;; ========================================
;; check-reduce: type-check a reduce (match) expression
;; ========================================
;; Two paths:
;;   Path A (structural): When constructor metadata is available (types defined via `data`),
;;     use true structural pattern matching — look up constructor field types,
;;     extend the context, and check each arm body directly. This lifts the
;;     Type 0 restriction from Church encoding, allowing match to return Type 1.
;;   Path B (Church fold): Fallback for built-in types or when metadata is unavailable.
;;     Desugars match into a Church application as before.

;; Decompose (app (app (fvar 'List) Nat) ...) → (values 'List (list Nat ...))
(define (decompose-type-app e)
  (let loop ([expr e] [args '()])
    (match expr
      [(expr-app f a) (loop f (cons a args))]
      [(expr-fvar name) (values name args)]
      ;; Built-in types: Nat, Bool, Unit (no type parameters)
      [(expr-Nat) (values 'Nat args)]
      [(expr-Bool) (values 'Bool args)]
      [(expr-Unit) (values 'Unit args)]
      [_ (values #f #f)])))

;; 'prologos::data::list::List → 'List, 'List → 'List
(define (bare-name sym)
  (define-values (_prefix short) (split-qualified-name sym))
  (or short sym))

;; Substitute type-args into leading m0 Pi binders of a constructor type.
;; Returns the remaining Pi chain with field types as domains.
(define (instantiate-pi-chain type args)
  (cond
    [(null? args) type]
    [else
     (match (whnf type)
       [(expr-Pi 'm0 _dom cod)
        (instantiate-pi-chain (subst 0 (car args) cod) (cdr args))]
       [_ #f])]))

;; Walk the instantiated Pi chain, extending ctx with each field's domain type.
(define (extend-ctx-with-fields ctx type n-fields)
  (let loop ([ty (whnf type)] [ctx ctx] [remaining n-fields])
    (if (= remaining 0)
        ctx
        (match ty
          [(expr-Pi m dom cod)
           (loop cod (ctx-extend ctx dom m) (- remaining 1))]
          [_ ctx]))))

;; Qualify a bare ctor name using the type constructor's FQN prefix.
;; e.g., ctor='cons, type-fqn='prologos::data::list::List → 'prologos::data::list::cons
(define (qualify-ctor-name ctor-name type-ctor-fqn)
  (define-values (prefix _short) (split-qualified-name type-ctor-fqn))
  (if prefix
      (string->symbol
       (string-append (symbol->string prefix) "::"
                      (symbol->string ctor-name)))
      ctor-name))

(define (check-reduce ctx reduce-expr scrutinee arms expected-type)
  (define scrut-type (infer ctx scrutinee))
  (cond
    [(expr-error? scrut-type) #f]
    [else
     (let-values ([(type-ctor-name type-args) (decompose-type-app scrut-type)])
       (define bare-tc (and type-ctor-name (bare-name type-ctor-name)))
       (define type-ctors (and bare-tc (lookup-type-ctors bare-tc)))
       (cond
         ;; Structural PM for all types with constructor metadata
         ;; (both built-in and user-defined). With native constructors,
         ;; there is no Church fold / structural PM split — all match
         ;; uses structural decomposition.
         [(and type-ctors (not (null? type-ctors)))
          (let ([result (check-reduce-structural ctx arms expected-type
                                                  type-ctor-name type-args)])
            (when result (mark-structural-reduce! reduce-expr))
            result)]
         ;; Fallback: Church fold for types without constructor metadata
         [else (check-reduce-church ctx scrutinee arms expected-type)]))]))


;; Built-in constructor types for Nat/Bool (not in global-env)
(define (builtin-ctor-type ctor-name)
  (case ctor-name
    [(zero) (expr-Nat)]
    [(suc)  (expr-Pi 'mw (expr-Nat) (expr-Nat))]
    [(true) (expr-Bool)]
    [(false) (expr-Bool)]
    [(unit) (expr-Unit)]
    [else #f]))

;; Path A: True structural pattern matching using constructor metadata
(define (check-reduce-structural ctx arms expected-type
                                  type-ctor-name type-args)
  (for/and ([arm (in-list arms)])
    (define ctor-name (expr-reduce-arm-ctor-name arm))
    (define bc (expr-reduce-arm-binding-count arm))
    (define body (expr-reduce-arm-body arm))
    ;; Look up constructor type from global-env (try FQN, bare, then built-in)
    (define ctor-fqn (qualify-ctor-name ctor-name type-ctor-name))
    (define ctor-type (or (global-env-lookup-type ctor-fqn)
                          (global-env-lookup-type ctor-name)
                          (builtin-ctor-type ctor-name)))
    (cond
      [(not ctor-type) #f]
      [else
       (define instantiated (instantiate-pi-chain ctor-type type-args))
       (cond
         [(not instantiated) #f]
         [else
          (if (= bc 0)
              (check ctx body expected-type)
              (let ([ext-ctx (extend-ctx-with-fields ctx instantiated bc)])
                (define shifted-exp (shift bc 0 expected-type))
                (check ext-ctx body shifted-exp)))])])))

;; Path B: Church fold desugaring (fallback for built-in types)
(define (check-reduce-church ctx scrutinee arms expected-type)
  (define branch-lams
    (for/list ([arm (in-list arms)])
      (define bc (expr-reduce-arm-binding-count arm))
      (define body (expr-reduce-arm-body arm))
      (if (= bc 0)
          body
          (for/fold ([inner body])
                    ([_ (in-range bc)])
            (expr-lam 'mw (expr-hole) inner)))))
  (define church-app
    (foldl (lambda (branch app-so-far)
             (expr-app app-so-far branch))
           (expr-app scrutinee expected-type)
           branch-lams))
  (check ctx church-app expected-type))

;; ========================================
;; Infer universe level of a type
;; ========================================
(define (infer-level ctx e)
  (match e
    ;; Pi formation: Pi(m, A, B) : Type(max(level(A), level(B)))
    [(expr-Pi m a b)
     (let ([la (infer-level ctx a)])
       (match la
         [(just-level l1)
          (let ([lb (infer-level (ctx-extend ctx a m) b)])
            (match lb
              [(just-level l2) (just-level (lmax l1 l2))]
              [_ (no-level)]))]
         [_ (no-level)]))]

    ;; Sigma formation
    [(expr-Sigma a b)
     (let ([la (infer-level ctx a)])
       (match la
         [(just-level l1)
          (let ([lb (infer-level (ctx-extend ctx a 'mw) b)])
            (match lb
              [(just-level l2) (just-level (lmax l1 l2))]
              [_ (no-level)]))]
         [_ (no-level)]))]

    ;; Eq formation
    [(expr-Eq a e1 e2)
     (let ([la (infer-level ctx a)])
       (match la
         [(just-level l)
          (if (and (check ctx e1 a) (check ctx e2 a))
              (just-level l)
              (no-level))]
         [_ (no-level)]))]

    ;; Vec formation: Vec(A, n) : Type(level(A))  if A : Type(l) and n : Nat
    [(expr-Vec a n)
     (let ([la (infer-level ctx a)])
       (match la
         [(just-level l)
          (if (check ctx n (expr-Nat))
              (just-level l)
              (no-level))]
         [_ (no-level)]))]

    ;; Fin formation: Fin(n) : Type(0)  if n : Nat
    [(expr-Fin n)
     (if (check ctx n (expr-Nat))
         (just-level (lzero))
         (no-level))]

    ;; Int formation: Int : Type(0)
    [(expr-Int) (just-level (lzero))]

    ;; Rat formation: Rat : Type(0)
    [(expr-Rat) (just-level (lzero))]

    ;; Numerics N5de: refined numeric types (PosInt/…) : Type(0)
    [(expr-fvar (? refined-name? _)) (just-level (lzero))]

    ;; Posit8 formation: Posit8 : Type(0)
    [(expr-Posit8) (just-level (lzero))]

    ;; Posit16 formation: Posit16 : Type(0)
    [(expr-Posit16) (just-level (lzero))]

    ;; Posit32 formation: Posit32 : Type(0)
    [(expr-Posit32) (just-level (lzero))]

    ;; Float formation (Numerics N3): Float32/Float64 : Type(0)
    [(expr-Float32) (just-level (lzero))]
    [(expr-Float64) (just-level (lzero))]

    ;; Posit64 formation: Posit64 : Type(0)
    [(expr-Posit64) (just-level (lzero))]

    ;; Quire formations: QuireW : Type(0)
    [(expr-Quire8) (just-level (lzero))]
    [(expr-Quire16) (just-level (lzero))]
    [(expr-Quire32) (just-level (lzero))]
    [(expr-Quire64) (just-level (lzero))]

    ;; Symbol formation: Symbol : Type(0)
    [(expr-Symbol) (just-level (lzero))]

    ;; Keyword formation: Keyword : Type(0)
    [(expr-Keyword) (just-level (lzero))]


    ;; Char formation: Char : Type(0)
    [(expr-Char) (just-level (lzero))]

    ;; String formation: String : Type(0)
    [(expr-String) (just-level (lzero))]

    ;; Record/tuple formation: level = max over field-type levels (Type 0 if empty)
    [(expr-Record _ fields _)
     (let loop ([fs fields] [acc (just-level (lzero))])
       (if (null? fs)
           acc
           (let ([lf (infer-level ctx (record-field-type (cdr (car fs))))])
             (match* (acc lf)
               [((just-level a) (just-level b)) (loop (cdr fs) (just-level (lmax a b)))]
               [(_ _) (no-level)]))))]

    ;; Map formation: Map K V : Type(max(level(K), level(V)))
    [(expr-Map k v)
     (let ([lk (infer-level ctx k)]
           [lv (infer-level ctx v)])
       (match* (lk lv)
         [((just-level lk*) (just-level lv*))
          (just-level (lmax lk* lv*))]
         [(_ _) (no-level)]))]

    ;; Set formation: Set A : Type(level(A))
    [(expr-Set a) (infer-level ctx a)]

    ;; PVec formation: PVec A : Type(level(A))
    [(expr-PVec a) (infer-level ctx a)]

    ;; Transient type formations
    [(expr-TVec a) (infer-level ctx a)]
    [(expr-TMap k v)
     (let ([lk (infer-level ctx k)])
       (match lk
         [(just-level lk*)
          (let ([lv (infer-level ctx v)])
            (match lv
              [(just-level lv*) (just-level (lmax lk* lv*))]
              [_ (no-level)]))]
         [_ (no-level)]))]
    [(expr-TSet a) (infer-level ctx a)]

    ;; PropNetwork type constructors — all ground types at Type 0
    [(expr-net-type) (just-level (lzero))]
    [(expr-cell-id-type) (just-level (lzero))]
    [(expr-prop-id-type) (just-level (lzero))]

    ;; UnionFind type constructor — ground type at Type 0
    [(expr-uf-type) (just-level (lzero))]

    ;; Tabling type constructor — ground type at Type 0
    [(expr-table-store-type) (just-level (lzero))]

    ;; Relational type constructors — ground types at Type 0
    [(expr-solver-type) (just-level (lzero))]
    [(expr-goal-type) (just-level (lzero))]
    [(expr-derivation-type) (just-level (lzero))]
    [(expr-answer-type _) (just-level (lzero))]
    [(expr-relation-type _) (just-level (lzero))]

    ;; Union formation: A | B : Type(max(level(A), level(B)))
    [(expr-union l r)
     (let ([ll (infer-level ctx l)])
       (match ll
         [(just-level l1)
          (let ([lr (infer-level ctx r)])
            (match lr
              [(just-level l2) (just-level (lmax l1 l2))]
              [_ (no-level)]))]
         [_ (no-level)]))]

    ;; Metavariable: if solved, follow solution; if unsolved, assume Type(lzero).
    ;; Unsolved metas in type position (e.g. map-empty key/value types) will be
    ;; resolved later via unification. This mirrors check's [(expr-meta _) _) #t].
    ;; PPN Track 4 Phase 4b: cell-id fast path (cells authoritative)
    [(expr-meta id cell-id)
     (let ([sol (meta-solution/cell-id cell-id id)])
       (if sol
           (infer-level ctx sol)
           (just-level (lzero))))]

    ;; Fallback: try to infer and match Type(L)
    [_
     (let ([t (whnf (infer ctx e))])
       (match t
         [(expr-Type l) (just-level l)]
         [_ (no-level)]))]))

;; ========================================
;; Type formation check
;; ========================================
(define (is-type ctx e)
  (match e
    ;; Type(L) is always a type
    [(expr-Type _) #t]
    ;; Otherwise, try to infer its level
    [_ (just-level? (infer-level ctx e))]))

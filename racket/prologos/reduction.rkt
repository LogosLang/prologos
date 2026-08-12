#lang racket/base

;;;
;;; PROLOGOS REDUCTION
;;; Weak head normal form reduction, full normalization, and definitional equality.
;;; Direct translation of prologos-reduction.maude + prologos-inductive.maude extensions.
;;;
;;; whnf(e)      : reduce to weak head normal form (beta, iota, projections)
;;; nf(e)        : reduce to full normal form (under all binders)
;;; conv(e1, e2) : check definitional equality (compare normal forms)
;;;

(require racket/match
         (only-in "union-types.rkt" flatten-union)  ;; D4.P4d slice 0: conv-nf's union arm
         racket/list
         racket/string
         racket/flonum
         "prelude.rkt"
         "syntax.rkt"
         "substitution.rkt"
         "global-env.rkt"
         "posit-impl.rkt"
         "float-impl.rkt"
         "performance-counters.rkt"
         "macros.rkt"
         "metavar-store.rkt"
         "foreign.rkt"
         "champ.rkt"
         "rrb.rkt"
         "propagator.rkt"
         "union-find.rkt"
         (only-in "namespace.rkt" ns-context?)
         "atms.rkt"
         "tabling.rkt"
         "solver.rkt"
         "relations.rkt"
         "provenance.rkt"
         "stratified-eval.rkt"
         "narrowing.rkt"
         "definitional-tree.rkt"
         "constraint-propagators.rkt"
         "prop-observatory.rkt"  ;; Observatory: capture user network runs
         "field-witness.rkt")    ;; CIU T6 F1b.5-s2: the runtime witness interpreter (below reduction; cycle-safe)

(provide whnf nf nf-whnf conv conv-nf
         ;; ⭐ D4.P4e-1b slice 1b-iii-C1: the VALUE-side shared join, exported so
         ;; it can be pinned SYMMETRICALLY against typing-core's
         ;; `star-join-type`. Before the C1 hoist there was no reduction seam at
         ;; all — both walks live inside `select-reduce`'s ~470-line scope — so
         ;; the twin could only have been mutation-tested while its partner was
         ;; directly pinned. Same standard, both sides.
         star-join-value
         current-nf-cache current-whnf-cache
         current-reduction-fuel current-nat-value-cache
         ;; CIU T6 F1b.5-s2: the degradation guard (exemption-list membership
         ;; is test-pinned — the D22/P6 silent-value-loss class)
         definitely-not-map?
         ;; Solver normalization (for benchmarks + PUnify)
         normalize-ast-to-solver-term
         ;; SUB.1: substitution containment tripwire (predicate + raiser) —
         ;; docs/tracking/2026-07-24_SUBSTITUTION_CONTAINMENT_DEFECT.md
         contains-open-container? assert-no-open-container!
         ;; SUB.3 hot-scan: the reflective oracle, for the differential
         ;; contract tests ONLY (armed ≡ reflective)
         contains-open-container?/reflective
         ;; CIU T6 D4.P4a: the select-block value walk. Exported for the
         ;; TOTALITY pins ONLY — the untotal case (a step kind the walk has no
         ;; arm for) is UNCONSTRUCTIBLE from surface syntax, so the fixtures
         ;; must call the walk directly with a synthetic step. Zero behavioural
         ;; change; production reaches it through the whnf `expr-select` arm.
         select-reduce
         ;; N6e issue #71: saturated-multi-hole-section classifier (shared by
         ;; infer/inferQ so the 3-stage guard cannot drift between stages).
         saturated-hole-section-app?
         ;; Rel T1 Aspect B (typed solution rows) entry-gate (b): the ONE shared
         ;; goal-app ground/free classifier + champ-key policy, consumed by BOTH
         ;; the runtime row-build (here) and the static solve row-typing (typing-core).
         classify-goal-args (struct-out free-arg) query-var->champ-key
         ;; POL.2 / B3.0: anon-`_` projection exclusion — kernel-level so the
         ;; runtime champ rows and B3's static row labels stay key-agreed.
         anon-query-var? row-query-vars
         ;; B3.1: raw solver ground value → AST expr, so the static body-goal
         ;; walker can type raw literals in registered goal-descs via infer.
         ground->prologos-expr)

;; N4: collapse a resolved numeric literal (expr-num-lit) to its concrete node.
;; Local mirror of zonk's collapse-num-lit (reduction can't require zonk — cycle via
;; solver). Returns #f if `ty` is not a concrete numeric type (caller keeps the node).
(define (num-lit->concrete val integral? ty)
  (cond
    [(expr-Int? ty)     (expr-int val)]
    [(expr-Nat? ty)     (expr-nat-val val)]
    [(expr-Rat? ty)     (expr-rat val)]
    [(expr-Posit8? ty)  (expr-posit8  (posit8-encode  val))]
    [(expr-Posit16? ty) (expr-posit16 (posit16-encode val))]
    [(expr-Posit32? ty) (expr-posit32 (posit32-encode val))]
    [(expr-Posit64? ty) (expr-posit64 (posit64-encode val))]
    [(expr-Float32? ty) (expr-float32 (flsingle (exact->inexact val)))]
    [(expr-Float64? ty) (expr-float64 (exact->inexact val))]
    [else #f]))

;; ========================================
;; Helpers for building Prologos List values in reduction
;; ========================================
;; List constructors (nil, cons) are inductive-type fvars registered by
;; `data List {A}` in prologos::data::list.  At the reduction level they
;; appear as (expr-fvar 'nil) and (expr-app (expr-app (expr-fvar 'cons) elem) rest).
;; These helpers convert Racket-level lists of AST exprs into Prologos Lists.

;; Convert a Racket list of AST expressions → Prologos List value
(define (racket-list->prologos-list elems)
  (foldr (lambda (e acc)
           (expr-app (expr-app (expr-fvar 'cons) e) acc))
         (expr-nil)
         elems))

;; Convert a Racket list of (cons key val) pairs → Prologos List of (pair k v)
(define (racket-pairs->prologos-pair-list pairs)
  (racket-list->prologos-list
   (map (lambda (p)
          (expr-app (expr-app (expr-fvar 'pair) (car p)) (cdr p)))
        pairs)))

;; Helper: check if an fvar name matches 'nil or '...::nil (qualified)
(define (nil-name? name)
  (let ([s (symbol->string name)])
    (or (string=? s "nil")
        (let ([len (string-length s)])
          (and (>= len 5) (string=? (substring s (- len 5)) "::nil"))))))

;; Helper: check if an fvar name matches 'cons or '...::cons (qualified)
(define (cons-name? name)
  (let ([s (symbol->string name)])
    (or (string=? s "cons")
        (let ([len (string-length s)])
          (and (>= len 6) (string=? (substring s (- len 6)) "::cons"))))))

;; Convert a Prologos List value (nil/cons chain) → Racket list of AST exprs, or #f if stuck
(define (prologos-list->racket-list e)
  (let loop ([cur (whnf e)] [acc '()])
    (cond
      ;; expr-nil — end of list (new overloaded nil node)
      [(expr-nil? cur)
       (reverse acc)]
      ;; nil — end of list (legacy fvar form)
      [(and (expr-fvar? cur) (nil-name? (expr-fvar-name cur)))
       (reverse acc)]
      ;; (nil A) — nil applied to type argument
      [(and (expr-app? cur)
            (let ([f (expr-app-func cur)])
              (and (expr-fvar? f) (nil-name? (expr-fvar-name f)))))
       (reverse acc)]
      ;; (cons x xs) — two-arg constructor applied as ((cons x) xs)
      [(and (expr-app? cur)
            (expr-app? (expr-app-func cur))
            (let ([inner (expr-app-func (expr-app-func cur))])
              (or (and (expr-fvar? inner) (cons-name? (expr-fvar-name inner)))
                  ;; (cons A x xs) — cons applied to type arg first: (((cons A) x) xs)
                  (and (expr-app? inner)
                       (let ([innermost (expr-app-func inner)])
                         (and (expr-fvar? innermost) (cons-name? (expr-fvar-name innermost))))))))
       (let* ([xs (expr-app-arg cur)]
              ;; head is trickier: could be ((cons x) ...) or (((cons A) x) ...)
              [head-app (expr-app-func cur)]
              [head (if (and (expr-app? (expr-app-func head-app))
                             (let ([f (expr-app-func (expr-app-func head-app))])
                               (and (expr-fvar? f) (cons-name? (expr-fvar-name f)))))
                        ;; (((cons A) x) xs) — skip the type arg, head = x
                        (expr-app-arg head-app)
                        ;; ((cons x) xs) — head = x
                        (expr-app-arg head-app))])
         (loop (whnf xs) (cons head acc)))]
      [else #f])))

;; ========================================
;; Helper: Racket integer → Prologos Nat expression
;; ========================================

;; Convert a non-negative Racket integer to a native Nat value.
(define (racket-nat->expr n)
  (expr-nat-val n))

;; ========================================
;; Helpers for relational solve/explain (Phase 7 Sub-phase E)
;; ========================================

;; Convert a Prologos AST expression to a ground Racket value for the solver.
;; Returns a symbol (for logic vars), or the AST expression itself (for ground terms).
;; The solver unifies using equal? on these values.
(define (expr->ground-value e)
  (let ([e* (whnf e)])
    (cond
      [(expr-logic-var? e*) (expr-logic-var-name e*)]
      [else e*])))

;; Strip mode prefix (?, +, -) from a logic variable name symbol.
;; ?x → x, +y → y, -z → z, foo → foo
(define (strip-mode-prefix sym)
  (define s (symbol->string sym))
  (if (and (> (string-length s) 1)
           (memv (string-ref s 0) '(#\? #\+ #\-)))
      (string->symbol (substring s 1))
      sym))

;; Deep-normalize an elaborated AST expression into the solver's flat representation.
;; Logic vars → symbols, constructor apps → lists, ground terms → themselves.
;; The solver uses: symbols for vars, lists for compound terms, everything else ground.
;;
;; expr-app is curried: (expr-app (expr-app f a1) a2) → uncurry to (list f' a1' a2')
(define (normalize-ast-to-solver-term expr)
  (cond
    [(expr-logic-var? expr) (strip-mode-prefix (expr-logic-var-name expr))]
    ;; Curried application → uncurry to flat list
    [(expr-app? expr)
     (define-values (head args) (uncurry-app expr))
     (cons (normalize-ast-to-solver-term head)
           (map normalize-ast-to-solver-term args))]
    ;; Goal-app (relation call as term) — use keyword to keep constructor ground
    [(expr-goal-app? expr)
     (cons (string->keyword (symbol->string (expr-goal-app-name expr)))
           (map normalize-ast-to-solver-term (expr-goal-app-args expr)))]
    ;; Everything else is ground: expr-int, expr-string, expr-fvar, expr-keyword, etc.
    [else expr]))

;; Uncurry a chain of expr-app nodes into (values head-expr (list arg1 arg2 ...))
(define (uncurry-app e)
  (let loop ([e e] [acc '()])
    (cond
      [(expr-app? e) (loop (expr-app-func e) (cons (expr-app-arg e) acc))]
      [else (values e acc)])))

;; Collect all logic variable names from a deeply-nested AST expression.
;; Returns a list of symbols (may contain duplicates — caller should deduplicate).
(define (collect-deep-logic-vars expr)
  (cond
    [(expr-logic-var? expr) (list (strip-mode-prefix (expr-logic-var-name expr)))]
    [(expr-app? expr)
     (append (collect-deep-logic-vars (expr-app-func expr))
             (collect-deep-logic-vars (expr-app-arg expr)))]
    [(expr-goal-app? expr)
     (append-map collect-deep-logic-vars (expr-goal-app-args expr))]
    [(expr-unify-goal? expr)
     (append (collect-deep-logic-vars (expr-unify-goal-lhs expr))
             (collect-deep-logic-vars (expr-unify-goal-rhs expr)))]
    [else '()]))

;; Convert a solver term back to a Prologos AST expression.
;; Handles compound terms (lists) by reconstructing curried expr-app.
(define (solver-term->prologos-expr v)
  (cond
    [(and (pair? v) (not (null? v)))
     ;; Compound term: (func arg1 arg2 ...) → curried expr-app chain
     ;; Keywords at head are constructor names — convert back to expr-fvar
     (define head (car v))
     (define func (if (keyword? head)
                      (expr-fvar (string->symbol (keyword->string head)))
                      (solver-term->prologos-expr head)))
     (define args (map solver-term->prologos-expr (cdr v)))
     (foldl (lambda (a f) (expr-app f a)) func args)]
    [(symbol? v) (expr-fvar v)]  ;; Unresolved logic var
    [else v]))  ;; Already an AST expression

;; POL.2 / B3.0 (Rel T1, 2026-07-24): anonymous `_` query vars — minted as
;; `(gensym '_anon)` fresh logic vars at elaboration (elaborator.rkt surf-hole
;; relational arm) — remain solver-visible FREE vars (each `_` still matches
;; independently; answer COUNT is unchanged, duplicates preserved) but are NOT
;; projected into solution rows: rows carry only NAMED query-var keys.
;; The filter lives HERE, in the B0 key-policy kernel, so the runtime champ
;; rows and the B3 static row labels stay key-agreed by construction.
;; `_anon` is thereby a RESERVED projection-excluded name prefix.
(define (anon-query-var? name)
  (and (symbol? name)
       (let ([s (symbol->string name)])
         (and (>= (string-length s) 5)
              (string=? (substring s 0 5) "_anon")))))

(define (row-query-vars query-vars)
  (filter (lambda (qv) (not (anon-query-var? qv))) query-vars))

;; Convert solver answer maps (list of hasheq) into the row CHAMPs behind a
;; result. Each answer is a hasheq mapping query variable names (symbols) to
;; ground values. Solution maps carry ONLY query-var keys (CIU T6 F1b.1 / D25:
;; the bound-args echo — ground call-site values re-emitted under '_'-suffixed
;; relation param names — is deleted; solutions are pure answers to the queried
;; unknowns). POL.2: anon `_` vars are additionally excluded (row-query-vars).
;;
;; This is the SHARED core (SolveCarrier R5). The two wrappers below choose the
;; CARRIER; keeping one core means the row-key policy can never drift between
;; them.
(define (answers->champ-list answers query-vars)
  (for/list ([answer (in-list answers)])
    ;; Build a CHAMP map from the answer bindings
    (define champ-val
      (for/fold ([c champ-empty])
                ([qv (in-list (row-query-vars query-vars))])
        (define val (hash-ref answer qv #f))
        (define key (query-var->champ-key qv))
        (define pval (if val (ground->prologos-expr val) (expr-fvar 'none)))
        (champ-insert c (equal-hash-code key) key pval)))
    (expr-champ champ-val)))

;; Rows under the List carrier: '[{:x val1 :y val2}, ...].
;; Since the SolveCarrier flip this is NARROWING's carrier only (R3) — the
;; solve/explain family uses answers->prologos-pvec. Narrowing's static type is
;; expr-hole, so moving it would relocate a runtime shape with no type to match.
(define (answers->prologos-expr answers query-vars)
  (racket-list->prologos-list (answers->champ-list answers query-vars)))

;; Rows under the PVec carrier: @[{:x val1 :y val2}, ...] — the solve/explain
;; result since the SolveCarrier flip (2026-07-31, discharging CIU T6 Q_U9).
;; PVec is ordered and duplicate-bearing, so Rel T1 POL.1's BAG semantics (one
;; row per derivation path; the multiplicity IS the derivation count) are carried
;; exactly, and `expr-rrb` is the NATIVE carrier struct path selection's `:`
;; broadcast requires.
(define (answers->prologos-pvec answers query-vars)
  (rows->prologos-pvec (answers->champ-list answers query-vars)))

;; The same carrier, for a caller that already holds the rows (explain's
;; answer-result → row conversion). Same wrapper, one definition.
(define (rows->prologos-pvec rows)
  (expr-rrb (rrb-from-list rows)))

;; Convert a ground solver value back to a Prologos AST expression.
;; If the value is already an AST expression, return it directly.
;; If it's a symbol (unresolved logic var), return it as an fvar.
(define (ground->prologos-expr v)
  (cond
    [(keyword? v) (expr-fvar (string->symbol (keyword->string v)))]
    [(symbol? v) (expr-fvar v)]
    ;; Compound solver term (list): reconstruct as curried expr-app
    [(and (pair? v) (not (null? v)))
     (define head (car v))
     (define func (if (keyword? head)
                      (expr-fvar (string->symbol (keyword->string head)))
                      (ground->prologos-expr head)))
     (define args (map ground->prologos-expr (cdr v)))
     (foldl (lambda (a f) (expr-app f a)) func args)]
    ;; Raw Racket primitive values from the solver's PPN normalization boundary
    ;; (see relations.rkt comment "resolved-args normalizes AST→raw"). Wrap them
    ;; back into the corresponding AST expression so the formatter sees a value
    ;; it recognizes rather than falling through to the 'unknown fallback.
    [(string? v) (expr-string v)]
    [(boolean? v) (if v (expr-true) (expr-false))]
    [(exact-integer? v) (expr-int v)]
    ;; Already an AST expression
    [(or (expr-zero? v) (expr-suc? v) (expr-nat-val? v) (expr-true? v) (expr-false? v)
         (expr-string? v) (expr-int? v) (expr-keyword? v) (expr-fvar? v)
         (expr-app? v) (expr-champ? v) (expr-lam? v) (expr-pair? v))
     v]
    [else (expr-fvar (if (symbol? v) v 'unknown))]))

;; ── Rel T1 Aspect B (typed solution rows), entry-gate (b) ──────────────────────
;; The ONE shared ground/free classifier for goal-app args, consumed by BOTH the
;; runtime row-build (below) AND the static solve row-typing (typing-core, B1). It
;; is the Correct-by-Construction substrate: the free/ground split is spelled in
;; exactly one place (classify-goal-args) and the champ KEY in exactly one place
;; (query-var->champ-key), so the runtime row and the static row type cannot
;; disagree on which positions are keys or on how a key is spelled.

;; free-arg — a free (query) position of a goal-app: the raw logic-var NAME
;; (runtime answer lookup + static row-type LABEL), the champ KEY (runtime
;; row-build), and the goal-arg POSITION (the positional bridge to the relation's
;; schema field, B1). Keys-out: name/key are carried, not re-derived by each consumer.
(struct free-arg (name key pos) #:transparent)

;; query-var->champ-key — the ONE goal-app champ-key policy: keyword-wrap the raw
;; query-var name (no strip). Consumed by classify-goal-args (the free-arg key) AND
;; every goal-app row-build, so the key spelling lives in a single place.
(define (query-var->champ-key name) (expr-keyword name))

;; classify-goal-args — the shallow ground/free classifier for goal-app args. whnf
;; each arg, then split at the TOP level (logic-var → free; else → ground).
;; Non-recursive: a logic var nested inside a compound arg is treated as ground
;; (matches the runtime split today; the typeable fragment is the top-level free
;; positions — gate a). Returns (values goal-args free-args):
;;   goal-args : positional — free position = raw name (symbol), ground = whnf value
;;   free-args : (listof free-arg) in positional order
(define (classify-goal-args args)
  (for/fold ([gs '()] [fs '()] [i 0]
             #:result (values (reverse gs) (reverse fs)))
            ([a (in-list args)])
    (define a* (whnf a))
    (cond
      [(expr-logic-var? a*)
       (define name (expr-logic-var-name a*))
       (values (cons name gs)
               (cons (free-arg name (query-var->champ-key name) i) fs)
               (add1 i))]
      [else
       (values (cons a* gs) fs (add1 i))])))

;; Extract query variable names and ground args from a goal-app's arguments.
;; Thin adapter over classify-goal-args, preserving the (goal-args, query-vars)
;; contract the solver call sites use.
(define (extract-query-info args)
  (define-values (goal-args free-args) (classify-goal-args args))
  (values goal-args (map free-arg-name free-args)))

;; (The bound-args echo machinery — compute-bound-args and
;; compute-bound-args-for-relation, which re-emitted ground call-site values
;; into solution maps under '_'-suffixed param names — was DELETED at CIU T6
;; F1b.1 (D25). Solution maps carry only query-var keys. The defn param-name
;; registry (global-env.rkt lookup-defn-param-names) is unrelated
;; infrastructure and survives: macros/LSP/pnet caching consume it.)

;; Phase 5b: Constructor inversion — structurally match a constructor expression
;; containing logic variables against a concrete target value.
;; Returns a list of substitution hashes, or '() if no match.
(define (narrow-constructor-match lhs target var-names)
  (define target* (whnf target))
  ;; Structurally decompose: both sides must have the same constructor shape.
  (let match-ctor ([l lhs] [t target*] [subst (hasheq)])
    (cond
      ;; Logic variable → bind
      [(expr-logic-var? l)
       (define existing (hash-ref subst (expr-logic-var-name l) #f))
       (cond
         [existing (if (equal? existing t) (list subst) '())]
         [else (list (hash-set subst (expr-logic-var-name l) t))])]
      ;; Both suc → recurse on predecessor
      [(and (expr-suc? l) (expr-suc? t))
       (match-ctor (expr-suc-pred l) (expr-suc-pred t) subst)]
      ;; suc vs nat-val → convert nat-val to peano and retry
      [(and (expr-suc? l) (expr-nat-val? t) (> (expr-nat-val-n t) 0))
       (match-ctor l (ctor-nat-val->peano (expr-nat-val-n t)) subst)]
      ;; Both zero → match
      [(and (expr-zero? l) (expr-zero? t)) (list subst)]
      ;; Both nat-val same → match
      [(and (expr-nat-val? l) (expr-nat-val? t) (= (expr-nat-val-n l) (expr-nat-val-n t)))
       (list subst)]
      ;; Both true/false → match
      [(and (expr-true? l) (expr-true? t)) (list subst)]
      [(and (expr-false? l) (expr-false? t)) (list subst)]
      ;; Both nil → match
      [(and (or (expr-nil? l) (and (expr-fvar? l) (eq? (expr-fvar-name l) 'nil)))
            (or (expr-nil? t) (and (expr-fvar? t) (eq? (expr-fvar-name t) 'nil))))
       (list subst)]
      ;; Both unit → match
      [(and (expr-unit? l) (expr-unit? t)) (list subst)]
      ;; Constructor application (expr-app chains with same head) → decompose fields
      [(and (expr-app? l) (expr-app? t))
       (define-values (l-head l-args) (flatten-app l))
       (define-values (t-head t-args) (flatten-app t))
       (cond
         [(and (expr-fvar? l-head) (expr-fvar? t-head)
               (eq? (expr-fvar-name l-head) (expr-fvar-name t-head))
               (= (length l-args) (length t-args)))
          ;; Pairwise match all args
          (let loop ([ls l-args] [ts t-args] [subs (list subst)])
            (cond
              [(null? ls) subs]
              [(null? subs) '()]
              [else
               (define next-subs
                 (append-map
                  (lambda (s)
                    (match-ctor (car ls) (car ts) s))
                  subs))
               (loop (cdr ls) (cdr ts) next-subs)]))]
         [else '()])]
      ;; Structural equality fallback
      [(equal? l t) (list subst)]
      ;; No match
      [else '()])))

;; Convert a natural number to Peano representation (local helper for ctor matching)
(define (ctor-nat-val->peano n)
  (if (zero? n) (expr-zero) (expr-suc (ctor-nat-val->peano (- n 1)))))

;; Flatten nested expr-app into (head . args-list)
(define (flatten-app e)
  (let loop ([e e] [args '()])
    (match e
      [(expr-app f a) (loop f (cons a args))]
      [_ (values e args)])))

;; Run narrowing for [func args...] = target, returning a Prologos list of answer maps.
(define (run-narrowing func-expr arg-exprs target-expr var-names)
  ;; Extract function name and any additional args from the func expression.
  ;; func-expr may be (expr-app (expr-fvar 'add) (expr-suc ?x)) when the LHS
  ;; is (add (suc ?x) ?y) — the elaborator partially curries the application.
  ;; Unwrap the application chain to get the base function name and prepend
  ;; any embedded args to the explicit arg list.
  (define-values (func-name all-args)
    (let loop ([e func-expr] [extra-args '()])
      (match e
        [(expr-fvar name) (values name (append extra-args arg-exprs))]
        [(expr-app f a) (loop f (cons a extra-args))]
        ;; Generic operators: dispatch via constraint-cell-based resolution.
        ;; Queries impl registry dynamically; uses target-expr as fallback type hint.
        ;; Phase 2d: falls through to multi-candidate search when static dispatch fails.
        [(expr-generic-add a b)
         (let ([fname (resolve-generic-narrowing 'Add (list a b) target-expr)])
           (if fname (values fname (append extra-args (list a b) arg-exprs))
               (let ([cands (resolve-generic-narrowing-candidates 'Add (list a b) target-expr)])
                 (if (null? cands) (values #f '())
                     (values (list 'multi-dispatch 'Add cands)
                             (append extra-args (list a b) arg-exprs))))))]
        [(expr-generic-sub a b)
         (let ([fname (resolve-generic-narrowing 'Sub (list a b) target-expr)])
           (if fname (values fname (append extra-args (list a b) arg-exprs))
               (let ([cands (resolve-generic-narrowing-candidates 'Sub (list a b) target-expr)])
                 (if (null? cands) (values #f '())
                     (values (list 'multi-dispatch 'Sub cands)
                             (append extra-args (list a b) arg-exprs))))))]
        [(expr-generic-mul a b)
         (let ([fname (resolve-generic-narrowing 'Mul (list a b) target-expr)])
           (if fname (values fname (append extra-args (list a b) arg-exprs))
               (let ([cands (resolve-generic-narrowing-candidates 'Mul (list a b) target-expr)])
                 (if (null? cands) (values #f '())
                     (values (list 'multi-dispatch 'Mul cands)
                             (append extra-args (list a b) arg-exprs))))))]
        [(expr-generic-div a b)
         (let ([fname (resolve-generic-narrowing 'Div (list a b) target-expr)])
           (if fname (values fname (append extra-args (list a b) arg-exprs))
               (let ([cands (resolve-generic-narrowing-candidates 'Div (list a b) target-expr)])
                 (if (null? cands) (values #f '())
                     (values (list 'multi-dispatch 'Div cands)
                             (append extra-args (list a b) arg-exprs))))))]
        [_ (values #f '())])))
  (cond
    [(not func-name)
     ;; Phase 5b: Constructor inversion — when LHS is a constructor
     ;; (not a function), structurally decompose against the target.
     ;; E.g., [suc ?n] = 3N → match (suc ?n) against (suc (suc (suc (zero))))
     (define ctor-solutions
       (narrow-constructor-match func-expr target-expr var-names))
     (if (pair? ctor-solutions)
         (answers->prologos-expr ctor-solutions var-names)
         (expr-fvar 'nil))]
    ;; Phase 2d: multi-candidate dispatch — try each candidate independently
    [(and (list? func-name) (eq? (car func-name) 'multi-dispatch))
     (define candidates (caddr func-name))
     (define args-whnf (map whnf all-args))
     (define target-whnf (whnf target-expr))
     (define all-solutions
       (append*
        (for/list ([cp (in-list candidates)])
          (run-narrowing-search (cdr cp) args-whnf target-whnf var-names))))
     (define unique (remove-duplicates all-solutions equal?))
     (answers->prologos-expr unique var-names)]
    [else
     ;; Single-candidate dispatch (standard path)
     (define args-whnf (map whnf all-args))
     (define target-whnf (whnf target-expr))
     (define solutions
       (run-narrowing-search func-name args-whnf target-whnf var-names))
     (answers->prologos-expr solutions var-names)]))

;; ========================================
;; Substitution containment tripwire (SUB.1)
;; docs/tracking/2026-07-24_SUBSTITUTION_CONTAINMENT_DEFECT.md
;; ========================================
;; A runtime collection value (champ/hset/rrb + transients) whose contents hold
;; a de Bruijn variable FREE w.r.t. the container boundary is the poisoned
;; shape: shift/subst treat these containers as closed leaves (BY CONTRACT
;; under ruling (D) — champ is a closed runtime map value), so a later beta
;; over the enclosing binder silently drops the argument or captures. Until the
;; SUB.3 fix (NbE open-the-binder) makes the shape unconstructible, refuse to
;; PERSIST it at the three nf-persisting boundaries (solve/solve-one is-goal
;; answer rows + validate base-ok) — a loud per-command error via the POL.4
;; exn:prologos-solve pattern instead of a silent wrong answer. Deliberately
;; NOT at shift/subst (no srcloc/command context) and NOT at the champ mint
;; (fires on correct display-only code — driver.rkt legitimately nf's eval
;; results for display).
;;
;; The walk is depth-aware INSIDE containers: a bvar bound by a binder that is
;; itself inside the container (e.g. an answer row holding a closed lambda,
;; champ{:f λy.bvar0} — the repro's CONTROL) is legal and must NOT fire; only
;; a bvar pointing OUTSIDE its innermost container fires. Binder forms are the
;; FOUR from substitution.rkt's shift (the authoritative inventory): lam, Pi,
;; Sigma, reduce-arm. Everything else walks REFLECTIVELY (struct->vector over
;; transparent structs + pairs/vectors/hashes/boxes) — deliberately no
;; per-node arms, so the checker cannot itself have the missing-arm defect it
;; guards against. Cold paths only; small answer/field terms.

(define (runtime-container-value? v)
  (or (expr-champ? v) (expr-hset? v) (expr-rrb? v)
      (expr-trrb? v) (expr-tchamp? v) (expr-thset? v)))

;; d = #f outside any container (hunting for containers); an integer = binder
;; depth accumulated since the INNERMOST enclosing container (checking
;; freeness w.r.t. that container's boundary).
;;
;; TWO walks, ONE semantics (SUB.3 hot-scan, owner-directed 2026-07-25):
;; the production walk carries explicit ARMS for the hot node kinds (direct
;; accessors — struct->vector allocates a fresh vector per node, ~an order
;; of magnitude slower than an accessor arm on the nf fast path), with the
;; REFLECTIVE walk retained verbatim as (a) the structurally-total fallback
;; for every un-armed node — so coverage cannot regress — and (b) the
;; differential-testing ORACLE: the contract test asserts armed ≡ reflective
;; over a battery with poison planted in every armed field position. Arms
;; are pure optimization; only certain-leaf nodes (no expr-bearing fields)
;; short-circuit to #f.

(define (contains-open-container? e)
  (and (occ-walk e #f) #t))

;; the differential oracle (provided for the contract tests)
(define (contains-open-container?/reflective e)
  (and (occ-walk/reflective e #f) #t))

(define (occ-walk v d)
  (match v
    [(expr-bvar i) (and d (>= i d))]
    ;; certain leaves: no expr-bearing fields
    [(or (? expr-fvar?) (? expr-int?) (? expr-nat-val?) (? expr-string?)
         (? expr-keyword?) (? expr-true?) (? expr-false?) (? expr-zero?)
         (? expr-unit?) (? expr-nil?) (? expr-hole?) (? expr-refl?)
         (? expr-error?) (? expr-logic-var?))
     #f]
    ;; hot spines — direct accessors
    [(expr-app f a) (or (occ-walk f d) (occ-walk a d))]
    [(expr-pair a b) (or (occ-walk a d) (occ-walk b d))]
    [(expr-suc p) (occ-walk p d)]
    [(expr-fst x) (occ-walk x d)]
    [(expr-snd x) (occ-walk x d)]
    [(expr-map-assoc m k mv)
     (or (occ-walk m d) (occ-walk k d) (occ-walk mv d))]
    [(expr-map-get m k a) (or (occ-walk m d) (occ-walk k d) (occ-walk a d))]
    [(expr-map-empty k mv) (or (occ-walk k d) (occ-walk mv d))]
    [(expr-pvec-literal elems) (for/or ([el (in-list elems)]) (occ-walk el d))]
    ;; the four binder forms — body positions at d+1 (or +binding-count)
    [(expr-lam _ t body)
     (or (occ-walk t d) (occ-walk body (and d (add1 d))))]
    [(expr-Pi _ dom cod)
     (or (occ-walk dom d) (occ-walk cod (and d (add1 d))))]
    [(expr-Sigma t1 t2)
     (or (occ-walk t1 d) (occ-walk t2 (and d (add1 d))))]
    [(? expr-reduce?)
     (or (occ-walk (expr-reduce-scrutinee v) d)
         (for/or ([arm (in-list (expr-reduce-arms v))])
           (occ-walk (expr-reduce-arm-body arm)
                     (and d (+ d (expr-reduce-arm-binding-count arm))))))]
    ;; container boundary: contents check freeness at fresh depth 0
    [(? runtime-container-value?)
     (for/or ([f (in-vector (struct->vector v) 1)]) (occ-walk f 0))]
    ;; cold fallback — reflective, structurally total (recursing through the
    ;; ARMED walk so hot nodes below a cold node use their arms)
    [_
     (cond
       [(struct? v)
        (for/or ([f (in-vector (struct->vector v) 1)]) (occ-walk f d))]
       [(pair? v) (or (occ-walk (car v) d) (occ-walk (cdr v) d))]
       [(vector? v) (for/or ([f (in-vector v)]) (occ-walk f d))]
       [(hash? v) (for/or ([(hk hv) (in-hash v)]) (or (occ-walk hk d) (occ-walk hv d)))]
       [(box? v) (occ-walk (unbox v) d)]
       [else #f])]))

;; the original fully-reflective walk, verbatim — the testing oracle
(define (occ-walk/reflective v d)
  (cond
    [(expr-bvar? v) (and d (>= (expr-bvar-index v) d))]
    [(runtime-container-value? v)
     (for/or ([f (in-vector (struct->vector v) 1)]) (occ-walk/reflective f 0))]
    [(expr-lam? v)
     (or (occ-walk/reflective (expr-lam-type v) d)
         (occ-walk/reflective (expr-lam-body v) (and d (add1 d))))]
    [(expr-Pi? v)
     (or (occ-walk/reflective (expr-Pi-domain v) d)
         (occ-walk/reflective (expr-Pi-codomain v) (and d (add1 d))))]
    [(expr-Sigma? v)
     (or (occ-walk/reflective (expr-Sigma-fst-type v) d)
         (occ-walk/reflective (expr-Sigma-snd-type v) (and d (add1 d))))]
    [(expr-reduce? v)
     (or (occ-walk/reflective (expr-reduce-scrutinee v) d)
         (for/or ([arm (in-list (expr-reduce-arms v))])
           (occ-walk/reflective (expr-reduce-arm-body arm)
                                (and d (+ d (expr-reduce-arm-binding-count arm))))))]
    [(struct? v)
     (for/or ([f (in-vector (struct->vector v) 1)]) (occ-walk/reflective f d))]
    [(pair? v) (or (occ-walk/reflective (car v) d) (occ-walk/reflective (cdr v) d))]
    [(vector? v) (for/or ([f (in-vector v)]) (occ-walk/reflective f d))]
    [(hash? v) (for/or ([(hk hv) (in-hash v)])
                 (or (occ-walk/reflective hk d) (occ-walk/reflective hv d)))]
    [(box? v) (occ-walk/reflective (unbox v) d)]
    [else #f]))

(define (assert-no-open-container! who v)
  (when (contains-open-container? v)
    (raise-solve-error who
      (string-append
       "substitution containment guard: this result contains a runtime "
       "collection value (map/set/vector) that captures a variable bound "
       "outside it; persisting it would produce silent wrong answers when "
       "applied. Known defect, fix in progress — see "
       "docs/tracking/2026-07-24_SUBSTITUTION_CONTAINMENT_DEFECT.md"))))

;; Run solve for a goal expression, returning a Prologos list of answer maps.
(define (run-solve-goal goal-expr config)
  (define goal* (whnf goal-expr))
  (cond
    [(expr-goal-app? goal*)
     (define rel-name (expr-goal-app-name goal*))
     (define rel-args (expr-goal-app-args goal*))
     (define-values (goal-args query-vars) (extract-query-info rel-args))
     (define store (current-relation-store))
     (define answers
       (parameterize ([current-is-eval-fn nf])
         (stratified-solve-goal config store rel-name goal-args query-vars)))
     (answers->prologos-pvec answers query-vars)]
    [(expr-rel? goal*)
     ;; Anonymous relation — create temporary relation-info and solve
     (define temp-name (gensym 'anon-rel))
     (define rel-info (expr-rel->relation-info goal* temp-name))
     (define store (hash-set (current-relation-store) temp-name rel-info))
     ;; All params are query vars
     (define query-vars
       (for/list ([p (in-list (expr-rel-params goal*))])
         (cond [(pair? p) (car p)]
               [(expr-logic-var? p) (expr-logic-var-name p)]
               [else p])))
     (define goal-args (map (lambda (v) v) query-vars))  ;; all unbound
     (define answers
       (parameterize ([current-is-eval-fn nf])
         (stratified-solve-goal config store temp-name goal-args query-vars)))
     (answers->prologos-pvec answers query-vars)]
    [(expr-unify-goal? goal*)
     ;; Inline = goal: normalize both sides to solver representation,
     ;; collect query vars, run unification, format answer.
     (define lhs (expr-unify-goal-lhs goal*))
     (define rhs (expr-unify-goal-rhs goal*))
     (define norm-lhs (normalize-ast-to-solver-term lhs))
     (define norm-rhs (normalize-ast-to-solver-term rhs))
     ;; Collect all logic vars from both sides (deduplicated, order-preserving)
     (define all-vars (collect-deep-logic-vars goal*))
     (define query-vars
       (let loop ([vs all-vars] [seen (hasheq)] [acc '()])
         (cond
           [(null? vs) (reverse acc)]
           [(hash-ref seen (car vs) #f) (loop (cdr vs) seen acc)]
           [else (loop (cdr vs) (hash-set seen (car vs) #t) (cons (car vs) acc))])))
     (define goal-desc-val (goal-desc 'unify (list norm-lhs norm-rhs)))
     (define store (current-relation-store))
     (define answers
       (parameterize ([current-is-eval-fn nf])
         (solve-single-goal config store goal-desc-val (hasheq) 0)))
     ;; Deep-walk and convert solver term values back to AST for display
     (define converted-answers
       (for/list ([ans (in-list answers)])
         (for/hasheq ([qv (in-list query-vars)])
           (values qv (solver-term->prologos-expr (walk* ans qv))))))
     (answers->prologos-pvec converted-answers query-vars)]
    [(expr-is-goal? goal*)
     ;; Inline is goal: evaluate expr, bind to var, return single-answer list.
     (define var-node (expr-is-goal-var goal*))
     (define is-expr (expr-is-goal-expr goal*))
     (define var-name
       (cond [(expr-logic-var? var-node) (strip-mode-prefix (expr-logic-var-name var-node))]
             [(symbol? var-node) (strip-mode-prefix var-node)]
             [else (gensym 'is-var)]))
     (define result (nf is-expr))
     ;; SUB.1 tripwire: nf-persisting boundary 1 (solve is-goal answer row)
     (assert-no-open-container! 'solve result)
     (define answer (hasheq var-name result))
     (answers->prologos-pvec (list answer) (list var-name))]
    [(expr-not-goal? goal*)
     ;; Top-level NAF goal (A.1): run via the DFS engine — solve-single-goal
     ;; handles 'not (prove inner; empty ⇒ NAF succeeds). Mirrors the inline-unify
     ;; arm above. Previously this fell through to the else-echo, printing the goal
     ;; unevaluated. (A.3 adds the static floundering gate for unsafe free-var
     ;; negation; A.1 is the dispatch fix for the reachable ground case.)
     (define gd (goal-desc 'not (list (expr-not-goal-goal goal*))))
     ;; A.3: floundering check for the top-level solve(not G) site. A bare top-level
     ;; `not` has no positive companion goal, so a free var in the inner goal is
     ;; unbound (floundering). Prolog-parity (owner ruling): WARN to stderr and
     ;; return the standard unsafe-`\+` result (`nil`), NOT an error. (A `defr` clause
     ;; with unsafe negation still hard-errors at registration — that is an authoring
     ;; bug; here it is a query, and Prolog runs queries.)
     (define fl (clause-floundering-msg 'solve '() (list gd)))
     (when fl (fprintf (current-error-port) "warning: ~a\n" fl))
     (define all-vars (collect-deep-logic-vars goal*))
     (define query-vars
       (let loop ([vs all-vars] [seen (hasheq)] [acc '()])
         (cond
           [(null? vs) (reverse acc)]
           [(hash-ref seen (car vs) #f) (loop (cdr vs) seen acc)]
           [else (loop (cdr vs) (hash-set seen (car vs) #t) (cons (car vs) acc))])))
     (define store (current-relation-store))
     (define answers
       (parameterize ([current-is-eval-fn nf])
         (solve-single-goal config store gd (hasheq) 0)))
     (define converted-answers
       (for/list ([ans (in-list answers)])
         (for/hasheq ([qv (in-list query-vars)])
           (values qv (solver-term->prologos-expr (walk* ans qv))))))
     (answers->prologos-pvec converted-answers query-vars)]
    ;; If the goal is not yet reduced to a goal-app, return the expression unchanged
    [else (expr-solve goal*)]))

;; Run solve-one for a goal expression, returning THE solution map bare, or
;; `none` when there is no solution (CIU T6 F1b.1 / D25.4: the `some` wrapper
;; is unwrapped so `[solve-one q].x` projects directly; `none` — the existing
;; missing-binding fvar — stays the no-solution value; never `{}`, which since
;; D17 reads as a legitimate empty dyn-row value).
(define (run-solve-one-goal goal-expr config)
  (define goal* (whnf goal-expr))
  (cond
    [(expr-goal-app? goal*)
     (define rel-name (expr-goal-app-name goal*))
     (define rel-args (expr-goal-app-args goal*))
     (define-values (goal-args query-vars) (extract-query-info rel-args))
     (define store (current-relation-store))
     (define answers
       (parameterize ([current-is-eval-fn nf])
         (stratified-solve-goal config store rel-name goal-args query-vars)))
     (if (null? answers)
         (expr-fvar 'none)
         (let* ([first-answer (car answers)]
                [champ-val
                 ;; POL.2: anon `_` keys excluded here too (same kernel filter)
                 (for/fold ([c champ-empty])
                           ([qv (in-list (row-query-vars query-vars))])
                   (define val (hash-ref first-answer qv #f))
                   (define key (query-var->champ-key qv))
                   (define pval (if val (ground->prologos-expr val) (expr-fvar 'none)))
                   (champ-insert c (equal-hash-code key) key pval))])
           (expr-champ champ-val)))]
    [(expr-rel? goal*)
     ;; Anonymous relation — create temporary relation-info and solve-one
     (define temp-name (gensym 'anon-rel))
     (define rel-info (expr-rel->relation-info goal* temp-name))
     (define store (hash-set (current-relation-store) temp-name rel-info))
     (define query-vars
       (for/list ([p (in-list (expr-rel-params goal*))])
         (cond [(pair? p) (car p)]
               [(expr-logic-var? p) (expr-logic-var-name p)]
               [else p])))
     (define goal-args (map (lambda (v) v) query-vars))
     (define answers
       (parameterize ([current-is-eval-fn nf])
         (stratified-solve-goal config store temp-name goal-args query-vars)))
     (if (null? answers)
         (expr-fvar 'none)
         (let* ([first-answer (car answers)]
                [champ-val
                 ;; POL.2 filter + key-policy consolidation (was inline expr-keyword)
                 (for/fold ([c champ-empty])
                           ([qv (in-list (row-query-vars query-vars))])
                   (define val (hash-ref first-answer qv #f))
                   (define key (query-var->champ-key qv))
                   (define pval (if val (ground->prologos-expr val) (expr-fvar 'none)))
                   (champ-insert c (equal-hash-code key) key pval))])
           (expr-champ champ-val)))]
    [(expr-unify-goal? goal*)
     ;; Inline = goal for solve-one: unify, return first answer or none.
     (define lhs (expr-unify-goal-lhs goal*))
     (define rhs (expr-unify-goal-rhs goal*))
     (define norm-lhs (normalize-ast-to-solver-term lhs))
     (define norm-rhs (normalize-ast-to-solver-term rhs))
     (define all-vars (collect-deep-logic-vars goal*))
     (define query-vars
       (let loop ([vs all-vars] [seen (hasheq)] [acc '()])
         (cond
           [(null? vs) (reverse acc)]
           [(hash-ref seen (car vs) #f) (loop (cdr vs) seen acc)]
           [else (loop (cdr vs) (hash-set seen (car vs) #t) (cons (car vs) acc))])))
     (define goal-desc-val (goal-desc 'unify (list norm-lhs norm-rhs)))
     (define store (current-relation-store))
     (define answers
       (parameterize ([current-is-eval-fn nf])
         (solve-single-goal config store goal-desc-val (hasheq) 0)))
     (if (null? answers)
         (expr-fvar 'none)
         (let* ([first-ans (car answers)]
                [champ-val
                 ;; POL.2 filter + key-policy consolidation (was inline expr-keyword)
                 (for/fold ([c champ-empty])
                           ([qv (in-list (row-query-vars query-vars))])
                   (define val (solver-term->prologos-expr (walk* first-ans qv)))
                   (define key (query-var->champ-key qv))
                   (champ-insert c (equal-hash-code key) key val))])
           (expr-champ champ-val)))]
    [(expr-is-goal? goal*)
     ;; Inline is goal for solve-one: evaluate expr, return (some {:var result}).
     (define var-node (expr-is-goal-var goal*))
     (define is-expr (expr-is-goal-expr goal*))
     (define var-name
       (cond [(expr-logic-var? var-node) (strip-mode-prefix (expr-logic-var-name var-node))]
             [(symbol? var-node) (strip-mode-prefix var-node)]
             [else (gensym 'is-var)]))
     (define result (nf is-expr))
     ;; SUB.1 tripwire: nf-persisting boundary 2 (solve-one is-goal answer row)
     (assert-no-open-container! 'solve-one result)
     (define key (expr-keyword var-name))
     (define champ-val (champ-insert champ-empty (equal-hash-code key) key result))
     (expr-champ champ-val)]
    [(expr-not-goal? goal*)
     ;; Top-level NAF goal for solve-one (A.1): run via the DFS engine, return the
     ;; first answer map bare or `none`. Mirrors the inline-unify solve-one arm.
     (define gd (goal-desc 'not (list (expr-not-goal-goal goal*))))
     ;; A.3: floundering warning (Prolog-parity) — warn to stderr, return the
     ;; standard unsafe-`\+` result (`none`), NOT an error.
     (define fl (clause-floundering-msg 'solve '() (list gd)))
     (when fl (fprintf (current-error-port) "warning: ~a\n" fl))
     (define all-vars (collect-deep-logic-vars goal*))
     (define query-vars
       (let loop ([vs all-vars] [seen (hasheq)] [acc '()])
         (cond
           [(null? vs) (reverse acc)]
           [(hash-ref seen (car vs) #f) (loop (cdr vs) seen acc)]
           [else (loop (cdr vs) (hash-set seen (car vs) #t) (cons (car vs) acc))])))
     (define store (current-relation-store))
     (define answers
       (parameterize ([current-is-eval-fn nf])
         (solve-single-goal config store gd (hasheq) 0)))
     (if (null? answers)
         (expr-fvar 'none)
         (let* ([first-ans (car answers)]
                [champ-val
                 ;; POL.2 filter + key-policy consolidation (was inline expr-keyword)
                 (for/fold ([c champ-empty])
                           ([qv (in-list (row-query-vars query-vars))])
                   (define val (solver-term->prologos-expr (walk* first-ans qv)))
                   (define key (query-var->champ-key qv))
                   (champ-insert c (equal-hash-code key) key val))])
           (expr-champ champ-val)))]
    [else (expr-solve-one goal*)]))

;; Run explain for a goal expression, returning a Prologos list of answer maps.
;; Routes through stratified-explain-goal to support WF-aware explain.
;; All paths now produce answer-result structs (D4).
(define (run-explain-goal goal-expr config prov-level)
  (define goal* (whnf goal-expr))
  (cond
    [(expr-goal-app? goal*)
     (define rel-name (expr-goal-app-name goal*))
     (define rel-args (expr-goal-app-args goal*))
     (define-values (goal-args query-vars) (extract-query-info rel-args))
     (define store (current-relation-store))
     (define results
       (parameterize ([current-is-eval-fn nf])
         (stratified-explain-goal config store rel-name goal-args query-vars prov-level)))
     ;; All production explain results are answer-result structs (D4). The legacy
     ;; wf-explained-answer / answer-record arms were dead code (zero producers)
     ;; and were deleted at CIU T6 F1b.1 along with the bound-args echo.
     (define prologos-maps
       (for/list ([r (in-list results)])
         (if (answer-result? r)
             (answer-result->prologos-expr r query-vars)
             r)))
     (rows->prologos-pvec prologos-maps)]
    [(expr-not-goal? goal*)
     ;; Explain over a top-level NAF goal (A.1): a negation has no positive
     ;; provenance chain, so run it via the DFS engine and return plain answer maps
     ;; (the same shape `solve` produces). Previously fell through to the else-echo.
     (define gd (goal-desc 'not (list (expr-not-goal-goal goal*))))
     ;; A.3: floundering check for the top-level solve(not G) site. A bare top-level
     ;; `not` has no positive companion goal, so a free var in the inner goal is
     ;; unbound (floundering). Prolog-parity (owner ruling): WARN to stderr and
     ;; return the standard unsafe-`\+` result (`nil`), NOT an error. (A `defr` clause
     ;; with unsafe negation still hard-errors at registration — that is an authoring
     ;; bug; here it is a query, and Prolog runs queries.)
     (define fl (clause-floundering-msg 'solve '() (list gd)))
     (when fl (fprintf (current-error-port) "warning: ~a\n" fl))
     (define all-vars (collect-deep-logic-vars goal*))
     (define query-vars
       (let loop ([vs all-vars] [seen (hasheq)] [acc '()])
         (cond
           [(null? vs) (reverse acc)]
           [(hash-ref seen (car vs) #f) (loop (cdr vs) seen acc)]
           [else (loop (cdr vs) (hash-set seen (car vs) #t) (cons (car vs) acc))])))
     (define store (current-relation-store))
     (define answers
       (parameterize ([current-is-eval-fn nf])
         (solve-single-goal config store gd (hasheq) 0)))
     (define converted-answers
       (for/list ([ans (in-list answers)])
         (for/hasheq ([qv (in-list query-vars)])
           (values qv (solver-term->prologos-expr (walk* ans qv))))))
     (answers->prologos-pvec converted-answers query-vars)]
    [else (expr-explain goal*)]))

;; ----------------------------------------
;; D4: Serialize answer-result → Prologos map
;; ----------------------------------------

;; Convert an answer-result struct to a Prologos CHAMP expression.
;; Structure: bindings at top level, :certainty/:cycle at top level (WF only),
;; :provenance as nested map (when present).
;;
;; Reserved-key guard (CIU T6 F1b.1 / D25.2 interim): the metadata keys
;; :certainty/:cycle/:provenance are inserted AFTER the query-var bindings and
;; champ-insert overwrites on equal keys — so a query variable that happens to
;; share a reserved name would be silently CLOBBERED. The guard skips the
;; metadata insert on collision: the user's binding wins (solve never inserts
;; these keys, so this also keeps the same query behaving identically under
;; solve and explain). The proper fix — provenance in a wrapper record beside
;; the solutions, not merged into each row — is the explain restructure
;; (DEFERRED.md § explain restructure), which inherits this pin.
(define (answer-result->prologos-expr ar query-vars)
  ;; 1. Build base CHAMP from query variable bindings
  (define bindings (answer-result-bindings ar))
  (define base-champ
    ;; POL.2: anon `_` keys excluded from explain rows too (same kernel filter)
    (for/fold ([c champ-empty])
              ([qv (in-list (row-query-vars query-vars))])
      (define val (hash-ref bindings qv #f))
      (define key (query-var->champ-key qv))
      (define pval (if val (ground->prologos-expr val) (expr-fvar 'none)))
      (champ-insert c (equal-hash-code key) key pval)))

  ;; 2. Add :certainty if present (WF semantics only; skipped if a query var
  ;;    claims the name — the binding wins)
  (define with-certainty
    (let ([cert (answer-result-certainty ar)])
      (if (and cert (not (memq 'certainty query-vars)))
          (let ([k (expr-keyword 'certainty)])
            (champ-insert base-champ (equal-hash-code k) k (expr-keyword cert)))
          base-champ)))

  ;; 3. Add :cycle if present (WF unknown only; binding wins on collision)
  (define with-cycle
    (let ([cyc (answer-result-cycle ar)])
      (if (and cyc (not (memq 'cycle query-vars)))
          (let* ([k (expr-keyword 'cycle)]
                 [cycle-expr (racket-list->prologos-list
                              (map (lambda (p) (expr-string (symbol->string p))) cyc))])
            (champ-insert with-certainty (equal-hash-code k) k cycle-expr))
          with-certainty)))

  ;; 4. Add :provenance if present (provenance level >= :summary; binding wins
  ;;    on collision)
  (define with-provenance
    (let ([prov (answer-result-provenance ar)])
      (if (and prov (not (memq 'provenance query-vars)))
          (let ([k (expr-keyword 'provenance)])
            (champ-insert with-cycle (equal-hash-code k) k
                          (provenance-data->prologos-expr prov)))
          with-cycle)))

  (expr-champ with-provenance))

;; Serialize provenance-data → Prologos CHAMP map.
(define (provenance-data->prologos-expr pd)
  (define c0 champ-empty)

  ;; :clause-id
  (define cid-key (expr-keyword 'clause-id))
  (define c1
    (let ([cid (provenance-data-clause-id pd)])
      (if cid
          (champ-insert c0 (equal-hash-code cid-key) cid-key (expr-keyword cid))
          c0)))

  ;; :depth
  (define depth-key (expr-keyword 'depth))
  (define c2
    (champ-insert c1 (equal-hash-code depth-key) depth-key
                  (expr-nat-val (provenance-data-depth pd))))

  ;; :derivation (if present — :full and :atms only)
  (define c3
    (let ([dt (provenance-data-derivation pd)])
      (if dt
          (let ([k (expr-keyword 'derivation)])
            (champ-insert c2 (equal-hash-code k) k
                          (derivation-tree->prologos-expr dt)))
          c2)))

  ;; :support (if present — :atms only)
  (define c4
    (let ([sup (provenance-data-support pd)])
      (if sup
          (let ([k (expr-keyword 'support)])
            (champ-insert c3 (equal-hash-code k) k
                          (racket-list->prologos-list
                           (map (lambda (s) (expr-keyword s)) sup))))
          c3)))

  (expr-champ c4))

;; Serialize derivation-tree → Prologos CHAMP map (recursive).
(define (derivation-tree->prologos-expr dt)
  (define c0 champ-empty)

  ;; :goal
  (define goal-key (expr-keyword 'goal))
  (define c1
    (champ-insert c0 (equal-hash-code goal-key) goal-key
                  (expr-keyword (derivation-tree-goal dt))))

  ;; :args
  (define args-key (expr-keyword 'args))
  (define c2
    (champ-insert c1 (equal-hash-code args-key) args-key
                  (racket-list->prologos-list
                   (map ground->prologos-expr (derivation-tree-args dt)))))

  ;; :rule
  (define rule-key (expr-keyword 'rule))
  (define c3
    (champ-insert c2 (equal-hash-code rule-key) rule-key
                  (expr-keyword (derivation-tree-rule dt))))

  ;; :children
  (define children-key (expr-keyword 'children))
  (define c4
    (champ-insert c3 (equal-hash-code children-key) children-key
                  (racket-list->prologos-list
                   (map derivation-tree->prologos-expr
                        (derivation-tree-children dt)))))

  (expr-champ c4))

;; ========================================
;; Helpers for Posit8 reduction
;; ========================================

;; Extract a Racket natural number from an expr-zero/expr-suc chain, or #f if not a numeral.
;; Per-command memoization avoids O(N^2) re-traversal during coercion.
(define current-nat-value-cache (make-parameter #f))

(define (nat-value e)
  (define cache (current-nat-value-cache))
  (cond
    ;; O(1) fast path for native Nat values
    [(expr-nat-val? e) (expr-nat-val-n e)]
    [(and cache (hash-ref cache e #f)) => values]
    [else
     (define result
       (match e
         [(expr-zero) 0]
         [(expr-suc e1) (let ([v (nat-value e1)]) (and v (+ v 1)))]
         [_ #f]))
     (when (and cache result)
       (hash-set! cache e result))
     result]))

;; ========================================
;; Phase 3e: Subtype coercion helpers for stuck-term reduction
;; ========================================
;; When an operation (e.g., int-add) has operands in WHNF but of a narrower
;; type (e.g., expr-suc/expr-zero instead of expr-int), these helpers coerce
;; to the target type. Returns the coerced value, or #f if not coercible.

;; Try to coerce a WHNF value to Int. Nat → Int.
;; Phase E: also handles library-defined subtypes via coercion registry.
(define (try-coerce-to-int e)
  (or (let ([k (nat-value e)])
        (and k (expr-int k)))
      (try-coerce-via-registry e 'Int)))

;; Try to coerce a WHNF value to Rat. Nat → Rat, Int → Rat.
;; Phase E: also handles library-defined subtypes via coercion registry.
(define (try-coerce-to-rat e)
  (cond
    [(expr-int? e) (expr-rat (expr-int-val e))]
    [else (or (let ([k (nat-value e)])
                (and k (expr-rat k)))
              ;; Direct coercion: PosRat→Rat, NegRat→Rat
              (try-coerce-via-registry e 'Rat)
              ;; Transitive: PosInt→Int→Rat, NegInt→Int→Rat, Zero→Int→Rat
              (let ([as-int (try-coerce-via-registry e 'Int)])
                (and as-int (expr-int? as-int)
                     (expr-rat (expr-int-val as-int)))))]))

;; Phase E: Generic coercion via registry for library-defined subtypes.
;; Looks up the constructor's type in ctor-meta, finds a registered coercion
;; to the target type, and applies it. Handles both single-arg constructors
;; (e.g., pos-int 5) and nullary constructors (e.g., mk-zero).
(define (try-coerce-via-registry e target-key)
  (define (ctor-type-key name)
    (let ([meta (or (lookup-ctor name) (lookup-ctor (ctor-short-name name)))])
      (and meta (ctor-meta-type-name meta))))
  (match e
    ;; Single-arg constructor application: (pos-int 5), (neg-rat -3/7)
    [(expr-app (expr-fvar ctor-name) _inner)
     (let ([tk (ctor-type-key ctor-name)])
       (and tk
            (let ([coerce-fn (lookup-coercion tk target-key)])
              (and coerce-fn (coerce-fn e)))))]
    ;; Nullary constructor: mk-zero
    [(expr-fvar ctor-name)
     (let ([tk (ctor-type-key ctor-name)])
       (and tk
            (let ([coerce-fn (lookup-coercion tk target-key)])
              (and coerce-fn (coerce-fn e)))))]
    [_ #f]))

;; Try to coerce a WHNF posit value to a wider width. Returns wider posit or #f.
(define (try-coerce-to-posit target-width e)
  (cond
    [(and (expr-posit8? e) (> target-width 8))
     (case target-width
       [(16) (expr-posit16 (posit-widen 8 16 (expr-posit8-val e)))]
       [(32) (expr-posit32 (posit-widen 8 32 (expr-posit8-val e)))]
       [(64) (expr-posit64 (posit-widen 8 64 (expr-posit8-val e)))]
       [else #f])]
    [(and (expr-posit16? e) (> target-width 16))
     (case target-width
       [(32) (expr-posit32 (posit-widen 16 32 (expr-posit16-val e)))]
       [(64) (expr-posit64 (posit-widen 16 64 (expr-posit16-val e)))]
       [else #f])]
    [(and (expr-posit32? e) (> target-width 32))
     (case target-width
       [(64) (expr-posit64 (posit-widen 32 64 (expr-posit32-val e)))]
       [else #f])]
    [else #f]))

;; Widen a Float32 literal to Float64 (the only float subtype edge, N3d): a
;; single-precision value is exactly representable as a double, so the flonum is
;; unchanged. Returns #f when no widening applies (target=32, or already f64).
(define (try-coerce-to-float target-width e)
  (and (= target-width 64) (expr-float32? e)
       (expr-float64 (expr-float32-val e))))

;; ========================================
;; Stuck-term reduction helpers
;; ========================================
;; Phase 3e: Each helper now attempts subtype coercion before declaring stuck.
;; If coercion changes an operand, rebuild the expression and retry whnf.

;; Reduce a binary Int operation: Nat operands coerce to Int.
(define (reduce-int-binary ctor a b)
  (let* ([a* (whnf a)]
         [b* (whnf b)])
    (let ([ca (or (try-coerce-to-int a*) a*)]
          [cb (or (try-coerce-to-int b*) b*)])
      (cond
        ;; Coercion changed something → retry with coerced operands
        [(or (not (eq? ca a*)) (not (eq? cb b*)))
         (whnf (ctor ca cb))]
        ;; Standard: one operand reduced → retry
        [(not (equal? a* a)) (whnf (ctor a* b))]
        [(not (equal? b* b)) (whnf (ctor a b*))]
        ;; Stuck
        [else (ctor a b)]))))

;; Reduce a unary Int operation: Nat operand coerces to Int.
(define (reduce-int-unary ctor a)
  (let* ([a* (whnf a)]
         [ca (or (try-coerce-to-int a*) a*)])
    (cond
      [(not (eq? ca a*)) (whnf (ctor ca))]
      [(not (equal? a* a)) (whnf (ctor a*))]
      [else (ctor a)])))

;; Reduce a binary Rat operation: Nat/Int operands coerce to Rat.
(define (reduce-rat-binary ctor a b)
  (let* ([a* (whnf a)]
         [b* (whnf b)])
    (let ([ca (or (try-coerce-to-rat a*) a*)]
          [cb (or (try-coerce-to-rat b*) b*)])
      (cond
        [(or (not (eq? ca a*)) (not (eq? cb b*)))
         (whnf (ctor ca cb))]
        [(not (equal? a* a)) (whnf (ctor a* b))]
        [(not (equal? b* b)) (whnf (ctor a b*))]
        [else (ctor a b)]))))

;; Reduce a unary Rat operation: Nat/Int operand coerces to Rat.
(define (reduce-rat-unary ctor a)
  (let* ([a* (whnf a)]
         [ca (or (try-coerce-to-rat a*) a*)])
    (cond
      [(not (eq? ca a*)) (whnf (ctor ca))]
      [(not (equal? a* a)) (whnf (ctor a*))]
      [else (ctor a)])))

;; Unified posit binary reducer. target-width: 8, 16, 32, or 64.
;; Posit8 has no narrower type; Posit16/32/64 coerce from narrower widths.
(define (reduce-posit-binary target-width ctor a b)
  (let* ([a* (whnf a)]
         [b* (whnf b)])
    (if (= target-width 8)
        ;; Posit8: no coercion possible
        (cond
          [(not (equal? a* a)) (whnf (ctor a* b))]
          [(not (equal? b* b)) (whnf (ctor a b*))]
          [else (ctor a b)])
        ;; Posit16/32/64: try coercion from narrower widths
        (let ([ca (or (try-coerce-to-posit target-width a*) a*)]
              [cb (or (try-coerce-to-posit target-width b*) b*)])
          (cond
            [(or (not (eq? ca a*)) (not (eq? cb b*)))
             (whnf (ctor ca cb))]
            [(not (equal? a* a)) (whnf (ctor a* b))]
            [(not (equal? b* b)) (whnf (ctor a b*))]
            [else (ctor a b)])))))

;; Unified posit unary reducer.
(define (reduce-posit-unary target-width ctor a)
  (let ([a* (whnf a)])
    (if (= target-width 8)
        (if (equal? a* a) (ctor a) (whnf (ctor a*)))
        (let ([ca (or (try-coerce-to-posit target-width a*) a*)])
          (cond
            [(not (eq? ca a*)) (whnf (ctor ca))]
            [(not (equal? a* a)) (whnf (ctor a*))]
            [else (ctor a)])))))

;; Float reducers (Numerics N3b): no width-coercion (cross-family is N3d);
;; just reduce operands then re-apply, mirroring the posit no-coercion branch.
(define (reduce-float-binary target-width ctor a b)
  (let ([a* (whnf a)] [b* (whnf b)])
    (let ([ca (or (try-coerce-to-float target-width a*) a*)]
          [cb (or (try-coerce-to-float target-width b*) b*)])
      (cond
        [(or (not (eq? ca a*)) (not (eq? cb b*))) (whnf (ctor ca cb))]
        [(not (equal? a* a)) (whnf (ctor a* b))]
        [(not (equal? b* b)) (whnf (ctor a b*))]
        [else (ctor a b)]))))

(define (reduce-float-unary target-width ctor a)
  (let ([a* (whnf a)])
    (let ([ca (or (try-coerce-to-float target-width a*) a*)])
      (cond
        [(not (eq? ca a*)) (whnf (ctor ca))]
        [(not (equal? a* a)) (whnf (ctor a*))]
        [else (ctor a)]))))

;; Extract the Racket-level exact rational value from a concrete numeric literal.
;; Returns #f for non-literal/non-numeric expressions.
(define (literal->rational e)
  (cond
    [(expr-int? e) (expr-int-val e)]
    [(expr-rat? e) (expr-rat-val e)]
    [(expr-posit8? e) (posit8-decode (expr-posit8-val e))]
    [(expr-posit16? e) (posit16-decode (expr-posit16-val e))]
    [(expr-posit32? e) (posit32-decode (expr-posit32-val e))]
    [(expr-posit64? e) (posit64-decode (expr-posit64-val e))]
    [(expr-float32? e) (inexact->exact (expr-float32-val e))]
    [(expr-float64? e) (inexact->exact (expr-float64-val e))]
    [else
     (let ([nv (nat-value e)])
       (and nv nv))]))

;; Classify a concrete numeric literal: 'nat, 'int, 'rat, 'p8, 'p16, 'p32, 'p64, or #f
(define (literal-type-tag e)
  (cond
    [(nat-value e) 'nat]
    [(expr-int? e) 'int]
    [(expr-rat? e) 'rat]
    [(expr-posit8? e) 'p8]
    [(expr-posit16? e) 'p16]
    [(expr-posit32? e) 'p32]
    [(expr-posit64? e) 'p64]
    [(expr-float32? e) 'f32]
    [(expr-float64? e) 'f64]
    [else #f]))


;; Coerce a Racket rational value to a target type tag, returning an AST literal.
(define (rational->literal val tag)
  (case tag
    [(nat) (nat->expr (max 0 (inexact->exact (floor val))))]
    [(int) (expr-int (inexact->exact (floor val)))]
    [(rat) (expr-rat val)]
    [(p8)  (expr-posit8 (posit8-encode val))]
    [(p16) (expr-posit16 (posit16-encode val))]
    [(p32) (expr-posit32 (posit32-encode val))]
    [(p64) (expr-posit64 (posit64-encode val))]
    [(f32) (expr-float32 (flsingle (exact->inexact val)))]
    [(f64) (expr-float64 (exact->inexact val))]
    [else #f]))

;; NaN/Inf-safe flonum extraction: Float literals pass their flonum through
;; (so +inf.0/+nan.0 survive — these have NO exact rational representation);
;; exact/posit literals go via the exact rational then ->inexact.
(define (literal->flonum e)
  (cond
    [(expr-float32? e) (expr-float32-val e)]
    [(expr-float64? e) (expr-float64-val e)]
    [else (let ([r (literal->rational e)]) (and r (exact->inexact r)))]))

;; Coerce a concrete numeric literal to a target type tag, NaN/Inf-safe.
;; Float targets coerce via flonums DIRECTLY — round-tripping +inf.0/+nan.0
;; through inexact->exact (as the exact path does) crashes the reducer.
;; Non-float targets are only reached when both operands are exact/posit
;; (type-tag-join never yields an exact/posit tag once a Float operand is
;; present), so the exact rational path there is always NaN/Inf-free.
(define (coerce-literal e tag)
  (cond
    [(eq? tag 'f32) (let ([fv (literal->flonum e)]) (and fv (expr-float32 (flsingle fv))))]
    [(eq? tag 'f64) (let ([fv (literal->flonum e)]) (and fv (expr-float64 fv)))]
    [else (let ([r (literal->rational e)]) (and r (rational->literal r tag)))]))

;; Type-tag ranking for numeric-join at reduction level.
;; Exact: nat(0) < int(1) < rat(2). Posit: p8(10) < p16(11) < p32(12) < p64(13).
(define (type-tag-rank tag)
  (case tag
    [(nat) 0] [(int) 1] [(rat) 2]
    [(p8) 10] [(p16) 11] [(p32) 12] [(p64) 13]
    [(f32) 20] [(f64) 21]
    [else -1]))

;; Compute the join type tag for two type tags.
(define (type-tag-join t1 t2)
  (cond
    [(eq? t1 t2) t1]
    ;; Both exact
    [(and (memq t1 '(nat int rat)) (memq t2 '(nat int rat)))
     (if (> (type-tag-rank t1) (type-tag-rank t2)) t1 t2)]
    ;; Both posit
    [(and (memq t1 '(p8 p16 p32 p64)) (memq t2 '(p8 p16 p32 p64)))
     (if (> (type-tag-rank t1) (type-tag-rank t2)) t1 t2)]
    ;; Cross-family: posit dominates, minimum p32
    [(and (memq t1 '(nat int rat)) (memq t2 '(p8 p16 p32 p64)))
     (if (>= (type-tag-rank t2) (type-tag-rank 'p32)) t2 'p32)]
    [(and (memq t1 '(p8 p16 p32 p64)) (memq t2 '(nat int rat)))
     (if (>= (type-tag-rank t1) (type-tag-rank 'p32)) t1 'p32)]
    ;; Float family (Numerics N3d): widen within-float; exact+float PRESERVES the
    ;; float width (no clamp); posit+float = no join (→ #f → stuck/type error).
    [(and (memq t1 '(f32 f64)) (memq t2 '(f32 f64)))
     (if (> (type-tag-rank t1) (type-tag-rank t2)) t1 t2)]
    [(and (memq t1 '(nat int rat)) (memq t2 '(f32 f64))) t2]
    [(and (memq t1 '(f32 f64)) (memq t2 '(nat int rat))) t1]
    [else #f]))

;; Reduce a generic binary operation: reduce both operands, retry.
;; Handles Nat operands and cross-type coercion via numeric-join.
(define (reduce-generic-binary ctor a b)
  (let ([a* (whnf a)]
        [b* (whnf b)])
    ;; Classify both operands
    (define ta (literal-type-tag a*))
    (define tb (literal-type-tag b*))
    (cond
      ;; Both are concrete numeric literals
      [(and ta tb)
       (let ([join (type-tag-join ta tb)])
         (cond
           [(not join) (ctor a* b*)]  ;; shouldn't happen (type error caught earlier)
           ;; Same type — compute directly
           [(eq? ta tb)
            (cond
              ;; Nat — delegate to nat-specific dispatch
              [(eq? ta 'nat)
               (let ([na (nat-value a*)] [nb (nat-value b*)])
                 (cond
                   [(eq? ctor expr-generic-add) (nat->expr (+ na nb))]
                   [(eq? ctor expr-generic-sub) (nat->expr (max 0 (- na nb)))]
                   [(eq? ctor expr-generic-mul) (nat->expr (* na nb))]
                   [(eq? ctor expr-generic-lt)  (if (< na nb) (expr-true) (expr-false))]
                   [(eq? ctor expr-generic-le)  (if (<= na nb) (expr-true) (expr-false))]
                   [(eq? ctor expr-generic-gt)  (if (> na nb) (expr-true) (expr-false))]
                   [(eq? ctor expr-generic-ge)  (if (>= na nb) (expr-true) (expr-false))]
                   [(eq? ctor expr-generic-eq)  (if (= na nb) (expr-true) (expr-false))]
                   [(eq? ctor expr-generic-mod) (nat->expr (if (zero? nb) na (remainder na nb)))]
                   [else (ctor a* b*)]))]
              ;; Non-Nat same type: the same-type iota rules in whnf will handle it.
              ;; Retry via whnf so the pattern-match iota rules fire.
              [else (whnf (ctor a* b*))])]
           ;; Different types — coerce both to join type, retry.
           ;; coerce-literal is NaN/Inf-safe (a Float operand carrying +inf.0/
           ;; +nan.0 cannot round-trip through an exact rational).
           [else
            (let ([ca (coerce-literal a* join)]
                  [cb (coerce-literal b* join)])
              (if (and ca cb)
                  (whnf (ctor ca cb))
                  (ctor a* b*)))]))]
      ;; One operand reduced → retry
      [(not (equal? a* a)) (whnf (ctor a* b))]
      [(not (equal? b* b)) (whnf (ctor a b*))]
      ;; Stuck
      [else (ctor a b)])))

;; Reduce a generic unary operation: reduce operand, retry.
;; Also handles Nat operands for abs (identity).
(define (reduce-generic-unary ctor a)
  (let ([a* (whnf a)])
    ;; Try Nat: operand is Nat numeral?
    (define na (nat-value a*))
    (cond
      [(and na (eq? ctor expr-generic-abs))
       ;; abs on Nat is identity
       a*]
      [(not (equal? a* a)) (whnf (ctor a*))]
      [else (ctor a)])))

;; ========================================
;; N6e issue #71: recognize a SATURATED multi-hole explicit-hole SECTION
;; application — a spine whose ultimate head is a chain of >=2 nested HOLE-domain
;; lambdas, applied to at least that many args (e.g. `[[- _ _] 10 3]` =
;; ((λ$_0. λ$_1. body) 10 3)). Such a form can't be typed by unwrapping one lambda
;; per app node: after the first beta-app the inner λ is a bare hole-lambda in
;; INFER position → expr-error. whnf fully collapses it to a lambda-free concrete
;; form the ordinary rules type. The >=2-hole guard leaves single-hole sections
;; AND single-beta let-expansion untouched; the saturation guard leaves
;; under-applied (def-RHS) sections a loud error (E3 contract preserved).
(define (saturated-hole-section-app? e)
  (let loop ([spine e] [nargs 0])
    (match spine
      [(expr-app f _) (loop f (add1 nargs))]
      [(expr-lam _ _ _)
       (let count ([b spine] [k 0])
         (match b
           [(expr-lam _ d bb) #:when (expr-hole? d) (count bb (add1 k))]
           [_ (and (>= k 2) (>= nargs k))]))]
      [_ #f])))

;; ========================================
;; Structural pattern matching for reduce
;; ========================================
;; Decompose an expression into (head-fvar arg1 arg2 ...) if possible.
;; Returns (values fvar-name args-list) or (values #f #f).
(define (decompose-app e)
  (let loop ([expr e] [args '()])
    (match expr
      [(expr-app f a) (loop f (cons a args))]
      [(expr-fvar name) (values name args)]
      [_ (values #f #f)])))

;; Try structural reduce: if scrutinee is a constructor application,
;; match the arm and substitute field values into the body.
;; Returns the substituted body expression, or #f if not a constructor.
(define (try-structural-reduce scrut arms)
  (define-values (head-name all-args) (decompose-app scrut))
  (and head-name
       (let ([meta (or (lookup-ctor head-name)
                       (lookup-ctor (ctor-short-name head-name)))])
         (and meta
              (let* ([n-type-params (length (ctor-meta-params meta))]
                     [short-name (ctor-short-name head-name)]
                     ;; Find matching arm
                     [matching-arm
                      (findf (lambda (arm)
                               (eq? (expr-reduce-arm-ctor-name arm) short-name))
                             arms)])
                (and matching-arm
                     (let* ([bc (expr-reduce-arm-binding-count matching-arm)]
                            [body (expr-reduce-arm-body matching-arm)]
                            ;; Compute field-values: handle both WITH and WITHOUT type args.
                            ;; racket-list->prologos-list creates cons/nil chains without
                            ;; type args. When (length all-args) == bc, type args are absent;
                            ;; when (length all-args) == bc + n-type-params, they're present.
                            [n-args (length all-args)]
                            [field-values
                             (cond
                               [(= n-args (+ bc n-type-params))
                                ;; Full args: skip type params
                                (drop all-args n-type-params)]
                               [(= n-args bc)
                                ;; No type args present (e.g., from racket-list->prologos-list)
                                all-args]
                               [else #f])])
                       (and field-values
                            ;; Substitute field values for bindings.
                            ;; bindings: bvar(0) = last field, bvar(1) = second-to-last, etc.
                            ;; We substitute bvar(0) first with last field, which decrements
                            ;; higher indices, then repeat for the next.
                            (for/fold ([result body])
                                      ([fv (in-list (reverse field-values))])
                              (subst 0 fv result))))))))))

;; Extract the short (bare) name from a potentially FQN symbol.
;; 'prologos::data::list::cons → 'cons, 'cons → 'cons
(define (ctor-short-name fqn)
  (define parts (string-split (symbol->string fqn) "::"))
  (string->symbol (last parts)))

;; Try built-in structural reduce for Nat/Bool constructors.
;; These are primitive expr nodes (not fvar applications), so decompose-app
;; can't handle them. Returns substituted body expression, or #f.
(define (try-builtin-reduce scrut arms)
  (cond
    ;; Nat: nat-val(0) matches 'zero arm (native representation)
    [(and (expr-nat-val? scrut) (= (expr-nat-val-n scrut) 0))
     (let ([arm (findf (lambda (a) (eq? (expr-reduce-arm-ctor-name a) 'zero)) arms)])
       (and arm (= (expr-reduce-arm-binding-count arm) 0)
            (expr-reduce-arm-body arm)))]
    ;; Nat: nat-val(n>0) matches 'suc arm, binds predecessor as nat-val(n-1)
    [(and (expr-nat-val? scrut) (> (expr-nat-val-n scrut) 0))
     (let ([arm (findf (lambda (a) (eq? (expr-reduce-arm-ctor-name a) 'suc)) arms)])
       (and arm (= (expr-reduce-arm-binding-count arm) 1)
            (subst 0 (expr-nat-val (- (expr-nat-val-n scrut) 1))
                   (expr-reduce-arm-body arm))))]
    ;; Nat: zero (nullary) — legacy Peano
    [(expr-zero? scrut)
     (let ([arm (findf (lambda (a) (eq? (expr-reduce-arm-ctor-name a) 'zero)) arms)])
       (and arm (= (expr-reduce-arm-binding-count arm) 0)
            (expr-reduce-arm-body arm)))]
    ;; Nat: suc/suc (one field: the predecessor) — legacy Peano
    [(expr-suc? scrut)
     (let ([arm (findf (lambda (a) (eq? (expr-reduce-arm-ctor-name a) 'suc)) arms)])
       (and arm (= (expr-reduce-arm-binding-count arm) 1)
            (subst 0 (expr-suc-pred scrut) (expr-reduce-arm-body arm))))]
    ;; Bool: true (nullary)
    [(expr-true? scrut)
     (let ([arm (findf (lambda (a) (eq? (expr-reduce-arm-ctor-name a) 'true)) arms)])
       (and arm (= (expr-reduce-arm-binding-count arm) 0)
            (expr-reduce-arm-body arm)))]
    ;; Bool: false (nullary)
    [(expr-false? scrut)
     (let ([arm (findf (lambda (a) (eq? (expr-reduce-arm-ctor-name a) 'false)) arms)])
       (and arm (= (expr-reduce-arm-binding-count arm) 0)
            (expr-reduce-arm-body arm)))]
    ;; Unit: unit (nullary)
    [(expr-unit? scrut)
     (let ([arm (findf (lambda (a) (eq? (expr-reduce-arm-ctor-name a) 'unit)) arms)])
       (and arm (= (expr-reduce-arm-binding-count arm) 0)
            (expr-reduce-arm-body arm)))]
    ;; nil: matches 'nil arm in pattern matching (e.g., List pattern match)
    [(expr-nil? scrut)
     (let ([arm (findf (lambda (a) (eq? (expr-reduce-arm-ctor-name a) 'nil)) arms)])
       (and arm (= (expr-reduce-arm-binding-count arm) 0)
            (expr-reduce-arm-body arm)))]
    [else #f]))


;; ========================================
;; Value classification for map-get graceful degradation
;; ========================================
;; A value is "definitely not a map" if it cannot possibly be a CHAMP map
;; at runtime. Used by map-get to return none instead of a stuck term
;; when applied to non-map values from union-typed expressions.
;; ============================================================
;; CIU T6 F1b.5-s2 (D27/D28): the validate runtime TABULATION.
;; ============================================================
;; Force all observations, fill-or-err, positive witness (the ESOP framing).
;; COLLECT-ALL: per-field checks are independent observations — never
;; fail-fast (D27.4, API-pinned). Per-field failure precedence: missing →
;; type-mismatch → check-failed (one Reason per field; the map holds one
;; value per key). Ctor minting is PAYLOAD-ONLY over FQN heads (the
;; foreign.rkt marshal-out contract; the dual-arity match tolerance —
;; NEVER mint a partial type-arg chain, it silently sticks). Values are
;; nf'd AT INSERT (nf never descends into champs) and BEFORE witnessing
;; (the field-witness precondition). A pred that panics PROPAGATES as the
;; node's result ("validate inherits panic semantics, v1" — D27.3); a pred
;; that STICKS or reduces to a non-Bool (a stuck trait method, an unbound
;; name, a [fn ...] value) FAILS LOUD as check-unevaluable (F1b.7a Layer B:
;; err-polarity's "skip stuck" governs TYPE-WITNESSING, not the user's
;; runtime :check assertion; an un-evaluable check must never silently pass).
;; CIU T6 D4.P3a: the select-block value assembly (Q_T1 Route A).
;; subj-champ is the ALREADY-whnf'd subject (evaluated ONCE by the whnf arm —
;; reused across every branch). Per-branch: project the head key, then walk
;; the remaining steps rebuilding PROJECTION nesting (traversed nominal keys
;; are kept — spec §1.2; a `.k` descent contributes a one-field level), with
;; a terminal `(@sub …)` recursing over the narrowed champ. Typing (Horn D)
;; sourced every selected field as 'present and the parser rejected duplicate
;; output keys BEFORE this code can mint — so a miss or a non-map mid-descent
;; here is an INVARIANT VIOLATION: panic loudly, never fabricate (the P2.b
;; two-tier discipline; fabricating `none` was exactly divergence site 7).
;; D4.P4b-ii-2b: the ASSERTIVE-tier miss message, ONE definition and two
;; consumers (`expr-map-get`'s champ arm and `select-reduce`'s), so the dot
;; spelling cannot drift from the quality bar P2.b slice 4 set. Extracting it
;; also fixes a shadowing bug this slice introduced: `select-reduce` binds a
;; parameter named `sort`, which SHADOWS Racket's `sort` — so calling it inside
;; that scope applied the symbol `'path` as a procedure. Same class as the
;; propagator rule's "never let a parameter shadow the thing you call".
(define (assertive-miss-message who label c)
  (format "~a: key ~a not found; available keys: ~a"
          who (fmt-map-key label)
          (if (champ-empty? c)
              "(none — the map is empty)"
              (string-join (sort (map fmt-map-key (champ-keys c)) string<?) " "))))

;; ⭐ D4.P4e-1b slice 1b-iii-A [Q_U44] — the champ walker for the star's join.
;; ⚠⚠ IT LIVES AT MODULE LEVEL DELIBERATELY, and the reason is two lines above:
;; `select-reduce` binds a parameter named `sort` (:1643) and the next top-level
;; define is `validate-tabulate` — so EVERY internal helper between them is in
;; the shadow, and calling Racket's `sort` there applies the symbol `'path` as a
;; procedure. `assertive-miss-message` was hoisted for exactly this, and the star's
;; join is the first thing since that would trip it (measured: the only two live
;; `(sort ` calls in this file both sit OUTSIDE the window, so nothing catches it
;; today). Attempt 2 shipped the shadowing bug for a probe cycle.
;;
;; Returns the layer's values in CANONICAL KEY ORDER, or `#f` when the layer holds
;; a key this ordering cannot speak for. `#f` is NOT "empty" and must not be
;; treated as one — the caller reports an invariant violation through the panic
;; channel. Inventing an order for an un-orderable key is the defect Q_U44
;; replaced; declining to is the point of this shape.
(define (champ-values/canonical root)
  (let ([entries (champ-entries root)])
    (and (andmap (lambda (kv) (canonical-keyword-key? (car kv))) entries)
         (map cdr (sort entries canonical-keyword-key<? #:key car)))))

;; ⭐⭐ D4.P4e-1b slice 1b-iii-C1 — THE SHARED JOIN, VALUE side. The atomic twin
;; of typing-core's `star-join-type`; the two must always move together (this
;; file's own rule: landing either alone is "not a half-measure but a
;; REGRESSION", and a twin-order divergence at this seat already produced one
;; whole-file abort).
;;
;; Given the LAYER a star deletes and the star STEP, produce the JOINED VALUE —
;; **BARE**, with no component wrapper. Q_U47's landing belongs to the CALLER,
;; because each caller is the branch remainder's own arm; see the typing twin's
;; header for the three of them and for why a wrapper chosen here would force
;; the B-tuple Q_U46 rejected.
;;
;; ⚠ HOISTED TO MODULE LEVEL DELIBERATELY, for the reason the comment above
;; `champ-values/canonical` already gives: inside `select-reduce` the parameter
;; `sort` shadows Racket's `sort` for ~470 lines, so a join written in that scope
;; cannot sort and cannot be unit-pinned either. Out here it can do both.
;;
;; `oops` is the caller's invariant-violation escape — `(why) → ⊥` through
;; reduction's single `let/ec`. ⚠ NEVER `error`: typing carries the user-facing
;; refusal, and a raise on this path is a WHOLE-FILE abort.
(define (star-join-value layer star oops)
  (let* ([l (whnf layer)]
         [contents
          (cond
            [(expr-champ? l)
             (or (champ-values/canonical (expr-champ-racket-champ l))
                 (oops "the deleted layer's keys admit no canonical order (non-keyword keys)"))]
            [(expr-rrb? l)
             (let ([r (expr-rrb-racket-rrb l)])
               (for/list ([i (in-range (rrb-size r))]) (rrb-get r i)))]
            [else (oops "the deleted layer is a leaf — it has no contents to join")])])
    (cond
      [(eq? (select-star-cont star) 'flatten-synth)
       (oops "`*_` synthesizes keys from the deleted layer's KEYS, and this join is positional")]
      [(andmap (lambda (c) (expr-rrb? (whnf c))) contents)
       ;; BARE (C1) — was `(list (cons #f …))` here; the wrapper moved to the
       ;; callers so the three landings can differ.
       (expr-rrb
        (for/fold ([acc (rrb-from-list '())])
                  ([c (in-list contents)])
          (rrb-concat acc (expr-rrb-racket-rrb (whnf c)))))]
      [else
       (oops "non-vector contents (the nominal join is the next slice; mixed or leaf contents have no join)")])))

(define (select-reduce subj-expr branches sort tier)
  ;; D4.P4b-ii-2b (the verify, M3): NO DEFAULTS. `#f` is not a neutral tier —
  ;; reduction reads it as the BLOCK tier and PANICS, so a caller that omitted
  ;; it would silently get "invariant violation" rather than "no claim". One
  ;; production caller, which passes both; requiring them keeps it that way.
  (let/ec return
    (define (kw-of label) (expr-keyword label))
    ;; ⭐ D4.P4c-4c (DEFERRED 43) — CHAMP-OF NOW TIER-FORKS, mirroring `project`
    ;; below and the top-level `expr-get` sibling. It used to panic
    ;; UNCONDITIONALLY on a non-map, which is the mirror of the tier bug on the
    ;; typing side: a PERMISSIVE carrier (a union, a dyn row, a selection view)
    ;; degrades quietly everywhere else in the language, and under ω it panicked.
    ;; One root cause with the typing half, two opposite symptoms.
    ;;
    ;; ⚠ AND THE OLD MESSAGE WAS FALSE AT A `'path` SITE. It asserted "typing
    ;; admitted the BLOCK" unconditionally. The block claim now appears only on
    ;; the block tier, where it is true.
    ;; ⚠ MY OWN EARLIER VERSION OF THIS COMMENT SAID `rrb-of` "reached the false
    ;; wording anyway by delegating here" — THAT IS FALSE. `rrb-of` is
    ;; self-contained and does not call `champ-of`; the ω path reaches `champ-of`
    ;; through `bcast-apply` → `branch-entries`. Corrected rather than deleted
    ;; because the same wrong clause was propagated into DEFERRED.md §43.
    ;; ⚠ RESIDUAL, not fixed here (DEFERRED): this helper is called as
    ;; `(champ-of v name)` with `name` = the STEP name, so the message reads
    ;; "`a` is not a map" — naming the step, not the value. `rrb-of` gets it
    ;; right ("this one is not a vector"). Cosmetic; filed rather than widened
    ;; into a shared-helper signature change inside a slice that already moved
    ;; production behaviour once.
    (define (champ-of v what)
      (let ([v* (whnf v)])
        (cond
          [(expr-champ? v*) (expr-champ-racket-champ v*)]
          ;; ⭐⭐ D4.P4d slice 6 — `champ-of` CONSULTS ONLY THE BLOCK TIER
          ;; [owner 2026-08-08: "split the flag — don't trade one against the
          ;; other"; then "C9 governs"]. THE SPLIT IS A DELETION, not an arm.
          ;;
          ;; ONE scalar tier was answering TWO questions: here ("is this element a
          ;; map at all?" — absence) and at `project` ("it is a map; does it have
          ;; the key?" — a genuine MISS). Arming it to make a miss LOUD also armed
          ;; this site and made an ACTUALLY-ABSENT element panic, so
          ;; `tier-union-witness` short-circuited on Nil and disarmed the union —
          ;; making the miss a buried `<error>` at ZERO errors. Each protection was
          ;; bought by surrendering the other.
          ;;
          ;; ⭐ THE ASSERTIVE TIER'S GUARANTEE IS ABOUT THE **KEY**, AND THAT IS
          ;; `project`'S QUESTION — which keeps its assertive arm. It was NEVER a
          ;; guarantee about the element's SHAPE, and this file proves that itself:
          ;; it MINTS non-champ values AT MAP TYPE by ruling — `champ-of`'s own
          ;; `[else] → none` (the `ub.a` route documented below) and `project`'s
          ;; `[else] → <error>`. So the assertive arm here was always answering a
          ;; question it had no warrant for. Deleting it is the split.
          ;;
          ;; ⚠⚠ A PREVIOUS CUT ADDED `[(expr-nil? v*) (return (expr-fvar 'none))]`
          ;; ABOVE the block arm instead, and the adversarial verify refuted it two
          ;; ways. (1) The width argument was a TYPE-level claim defending a
          ;; VALUE-level site: the keys-⋂ gate proves no component TYPE fails to
          ;; offer the step, and says nothing about whether a value inhabiting
          ;; `[Map K V]` is a champ — so `@[m1 (ub.a)]` broadcast went `none` → PANIC,
          ;; a value→error break. (2) Sitting above `[(not tier)]` it pre-empted the
          ;; BLOCK arm, silently weakening Horn D on the reachable `map-assoc`
          ;; dyn-key route. Both are gone: no nil arm, and the permissive `[else]`
          ;; already returns `none` for a nil under a non-block tier.
          ;; tier = #f — the BLOCK sort. Typing sourced every field 'present
          ;; (Horn D), so a non-map here really IS an invariant violation.
          [(not tier)
           (return (expr-panic
                    (expr-string
                     (format "select: ~a is not a map at runtime (invariant violation — typing admitted the block)"
                             what))))]
          ;; ⚠ D4.P4d slice 6: the assertive-PATH arm that stood here is DELETED —
          ;; see the header. `project` keeps its assertive arm, which is where the
          ;; key guarantee actually lives; a non-champ at Map type is a shape this
          ;; file's own ruled degradations produce, so panicking on it was never
          ;; warranted. A non-block tier now falls to the permissive `[else]`.
          ;; unsolved — the PERMISSIVE tier (dyn row, selection view, union).
          ;; ⚠ THE VALUE IS `none`, NOT `<error>`, AND THAT IS A RULING THIS FILE
          ;; ALREADY MADE 1500 LINES DOWN — `[(definitely-not-map? subj*) (if tier
          ;; (expr-fvar 'none) …)]`, whose own comment says "Match `map-get`:
          ;; degrade to `none`". My first cut returned `(expr-error)` and the
          ;; adversarial verify caught that it gave a THIRD answer to a question
          ;; with two: three adjacent union-non-map cases one line apart
          ;; (`<Map|Int>`, `<Map|PVec>`, `<Map|Set>`) answered `none`, `<error>`,
          ;; `none` — and the odd one out was the one this change moved.
          ;;
          ;; ⚠⚠ AND THAT PATH IS PRODUCTION-REACHABLE WITH NO GRANT, which
          ;; falsified DEFERRED 43's own deferral rationale ("the grant is '(), so
          ;; nothing here is reachable in production"). The route: the
          ;; `expr-select` entry admits **rrb** subjects into `select-reduce`
          ;; BEFORE the `definitely-not-map?` fork, and `expr-rrb?` is not a member
          ;; of `definitely-not-map?` (only `expr-hset?` is). So `ub.a` where
          ;; `ub : <[Map Keyword Int] | [PVec Int]> := @[1 2 3]` reaches here on
          ;; the ordinary dot path. It used to PANIC "invariant violation", which
          ;; was itself wrong — the union's Map branch is exactly why typing
          ;; admitted `.a`, so there is no invariant violated. Degrading is right;
          ;; degrading to the same value as its siblings is what makes it correct.
          [else (return (expr-fvar 'none))])))
    (define (project c label)
      (let* ([kw (kw-of label)]
             [hit (champ-lookup c (equal-hash-code kw) kw)])
        (if (eq? hit 'none)
            ;; D4.P4b-ii-2b — THE TWO-TIER MISS, the carrier's analogue of
            ;; `expr-map-get`'s strictness fork (P2.b slice 4). The tier is
            ;; SOLVED to (expr-true) only when typing PROVED an assertive
            ;; subject; a dyn row / selection view / union leaves it unsolved,
            ;; and those misses must stay PERMISSIVE — they were `<error>` at
            ;; zero errors before the fold, and the b-ii-2a tripwire pins it.
            ;; ⚠ The old message asserted "typing sourced it as present". That
            ;; is FALSE for a Map under Q_U10's posture (the Map arm admits
            ;; uniformly and DEFERS the miss to runtime), so the assertive
            ;; message now names the key and the available keys instead —
            ;; matching the quality bar `map-get` set, which the dot spelling
            ;; would otherwise have lost.
            ;; THREE outcomes, not two — the first cut collapsed the first two
            ;; because they share "panic loudly", but they are different facts
            ;; and the P4a pin caught it:
            ;;   tier = #f          — the BLOCK sort. Typing sourced every
            ;;                        field 'present (Horn D), so a miss here
            ;;                        really IS an invariant violation.
            ;;   tier = (expr-true) — the PATH sort over a proved Map. Typing
            ;;                        admitted every label and DEFERRED the
            ;;                        miss (Q_U10), so "typing sourced it as
            ;;                        present" would be FALSE; name the key and
            ;;                        the available keys, the bar map-get set.
            ;;   otherwise          — unsolved: the PERMISSIVE tier (dyn row,
            ;;                        selection view, union). Quiet <error>,
            ;;                        exactly as before the fold.
            (cond
              [(not tier)
               (return (expr-panic
                        (expr-string
                         (format "select: field :~a not found at runtime (invariant violation — typing sourced it as present)"
                                 label))))]
              [(expr-true? tier)
               (return (expr-panic
                        (expr-string (assertive-miss-message "select" kw c))))]
              [else (return (expr-error))])
            (whnf hit))))
    ;; D4.P3c: a level assembles either sort — all-keyed components → champ;
    ;; all-keyless ((#f . v)) → the rrb tuple mint in written order (ruling
    ;; 2a: honest at EVERY n, incl. 1-tuples). Parser L4 guaranteed
    ;; homogeneity.
    (define (entries->value entries)
      (if (and (pair? entries) (not (car (car entries))))
          (expr-rrb (rrb-from-list (map cdr entries)))
          (expr-champ
           (for/fold ([acc champ-empty]) ([e (in-list entries)])
             (let ([kw (kw-of (car e))])
               (champ-insert acc (equal-hash-code kw) kw (cdr e)))))))
    ;; ordinal descent over the runtime value (Q_U2 / ordinal branches).
    ;; Typing admitted the block; a het-row OOB was caught statically; a
    ;; PVec OOB is a legitimate runtime assertive-tier error — LOUD, the
    ;; expr-get wording (P2.b: never fabricate).
    (define (index-into v n what)
      (let ([v* (whnf v)])
        (cond
          [(expr-rrb? v*)
           (let ([r (expr-rrb-racket-rrb v*)])
             (if (< n (rrb-size r))
                 (whnf (rrb-get r n))
                 (return (expr-panic
                          (expr-string
                           (format "select: index ~a out of bounds for the vector of length ~a (at `~a`)"
                                   n (rrb-size r) what))))))]
          [else
           (return (expr-panic
                    (expr-string
                     (format "select: ~a is not a vector at runtime (invariant violation — typing admitted the ordinal)"
                             what))))])))
    ;; D4.P4c-4c — ⭐ THE FOURTH SITE THE PARTITION NEVER NAMED: the rrb
    ;; container guard. `champ-of` and `index-into` are the precedent, and the
    ;; mini-audit's warning is that they are NOT twins — one unwraps, one
    ;; accesses. This one unwraps, so it is shaped on `champ-of`.
    ;;
    ;; ⚠ IT MUST `return` A PANIC, NEVER `error`. These walks carry NO failure
    ;; slot, so a non-container has exactly two exits: the escape (a per-command
    ;; error, file continues) or a raise (a WHOLE-FILE abort). P4c-4b split that
    ;; channel deliberately; an `error` here re-creates precisely the abort it
    ;; removed.
    ;;
    ;; ⚠ REACHABILITY, CORRECTED — my first comment here claimed "Map and
    ;; het-tuple subjects are GUARANTEED to arrive, so this arm is the reachable
    ;; one, not a defensive one." THE ADVERSARIAL VERIFY COULD NOT REACH IT: every
    ;; non-PVec carrier is stopped by `select-elem-of` at TYPING, so reduction
    ;; never runs. The honest statement is that this guard is currently
    ;; UNREACHABLE THROUGH TYPING and exists because reduction must not depend on
    ;; typing having run — `select-reduce` is called from whnf, and a future
    ;; carrier widening at P4d changes the typing gate, not this one. That is a
    ;; real reason to keep it; the reason I first wrote was not, and stating a
    ;; false reachability invites a future reader to delete the guard.
    ;;
    ;; ⚠ WORDING COPIED FROM `index-into`, NOT `champ-of`. `champ-of`'s message
    ;; asserts "typing admitted the block" unconditionally, which is FALSE under
    ;; sort='path — and ω is a 'path construct, so inheriting that sentence would
    ;; state something untrue at exactly the site that fires.
    (define (rrb-of v what)
      (let ([v* (whnf v)])
        (if (expr-rrb? v*)
            (expr-rrb-racket-rrb v*)
            (return (expr-panic
                     (expr-string
                      (format "select: broadcast `:~a` needs a vector or map subject at runtime — this one is neither"
                              what)))))))
    ;; D4.P4c-4c — ONE ω step applied to a runtime value: the FUNCTORIAL LIFT,
    ;; the ATOMIC TWIN of typing-core's `select-bcast-lift`. Unwrap one container
    ;; layer, apply the wrapped step to EVERY element, re-wrap one layer.
    ;;
    ;; The caller continues the walk itself (same contract as the typing twin) —
    ;; consuming the rest here would nest the next ω step inside this one's
    ;; ELEMENT, which is the opposite of L1 fusion.
    ;;
    ;; ⚠ WHOLE-NODE ABORT (ratified, Q_U7 rider): a miss inside ANY element
    ;; aborts the WHOLE selection. That is automatic here rather than coded —
    ;; `project` / `index-into` / `rrb-of` all `return` through the single
    ;; `let/ec`, so no partial vector can escape and no `expr-panic` can be
    ;; buried in an output slot. Stated because a "map semantics" intuition
    ;; would expect per-element recovery, and that is exactly the drift the
    ;; ruling forbids.
    (define (bcast-lift v s)
      (let* ([inner (select-bcast-inner s)]
             ;; same diagnostic-label guard as the typing twin: a sub inner's
             ;; `select-step-name` is the RAW LIST — never interpolate it.
             ;; only a LIST takes the stand-in — numbers are real labels
             ;; (see the typing twin's correction note)
             [name (let ([n (select-step-name s)]) (if (pair? n) '|{…}| n))]
             [v* (whnf v)])
        (cond
          ;; D4.P4d slice 1 — THE CHAMP CARRIER (both map carriers run on
          ;; expr-champ; the typing twins are select-bcast-lift's row walk +
          ;; select-elem-of's Map arm — landed ATOMICALLY with this arm).
          ;; Keys preserved BY CONSTRUCTION: the `expr-map-map-vals` idiom —
          ;; fold + transient insert with the ORIGINAL key and its hash. A
          ;; miss inside `bcast-apply` `return`s through the single let/ec,
          ;; abandoning the un-frozen transient — the whole-node abort
          ;; (DEFERRED 48) rides the existing seam with no partial map able
          ;; to escape.
          [(expr-champ? v*)
           (let ([c (expr-champ-racket-champ v*)]
                 [t (champ-transient champ-empty)])
             (champ-fold c
                         (lambda (k val _acc)
                           (tchamp-insert! t (equal-hash-code k) k
                                           (bcast-apply (whnf val) inner)))
                         (void))
             (expr-champ (tchamp-freeze t)))]
          [else
           (let ([r (rrb-of v* name)])
             (expr-rrb
              (rrb-from-list
               (for/list ([i (in-range (rrb-size r))])
                 (bcast-apply (whnf (rrb-get r i)) inner)))))])))
    ;; Apply ONE step to ONE element, yielding the leaf value — the reduction
    ;; analogue of typing's `select-project ctx elem (list (list inner)) sort`.
    ;; It mirrors the top-level sort dispatch at the tail of this function
    ;; rather than re-deciding it, so a third sort cannot inherit path
    ;; semantics here silently.
    (define (bcast-apply v inner)
      ;; ⭐ Q_U20 [owner, 2026-08-05] — the ATOMIC TWIN of typing's rule: a SUB
      ;; inner ASSEMBLES, always, regardless of the outer selector's sort. The
      ;; symbol path below mirrors the top-level sort dispatch unchanged.
      (if (select-sub-step? inner)
          (entries->value (level-entries v (cdr inner)))
      (let ([entries (branch-entries v (list inner) '())])
        (case sort
          [(block) (entries->value entries)]
          [(path)
           (if (and (pair? entries) (null? (cdr entries)))
               (cdr (car entries))
               (return (expr-panic
                        (expr-string
                         (format "select: a broadcast step must yield exactly ONE component per element, got ~a (malformed carrier)"
                                 (length entries))))))]
          [else (select-sort-unhandled 'select-bcast-apply sort)]))))
    ;; D4.P3b — one branch's entries at the CURRENT level, mirroring
    ;; typing-core's select-branch-entries over champs (the same shared
    ;; syntax.rkt walk classifies steps, so meaning cannot drift from the
    ;; parser's Q_T3 check). Duplicates were excluded at the parser, so
    ;; champ-insert is never asked to last-win; a miss or non-map
    ;; mid-descent is an INVARIANT VIOLATION — panic, never fabricate.
    ;; `seen` mirrors typing-core's select-branch-entries: the branch steps
    ;; consumed above this recursion, so `^_`'s Reading-N label synthesizes
    ;; over the FULL branch via the SHARED select-synth-name walk; resets at
    ;; a `.{…}` sub-block (branch-of-its-block scope — Q_U4: subject-root
    ;; preferred, flip deferred; DEFERRED 23).
    ;; ⭐⭐ D4.P4e-1b slice 1b-iii-B1 [Q_U40/Q_U42/Q_U44] — THE FLATTEN's VALUE,
    ;; the atomic twin of typing's `star-branch-entries`, and its arm sits FIRST
    ;; in `branch-entries`' cond at the SAME POSITION as the typing twin's.
    ;; The layer is `below-value` over the prefix (RE-NESTED — that row IS the
    ;; layer being deleted), or `v` itself when the star is branch-initial.
    ;; Contents: a champ layer's values in CANONICAL key order (Q_U44 —
    ;; `champ-values/canonical`, module-level, outside the `sort` shadow) or an
    ;; rrb layer's elements in ELEMENT order. All contents rrbs ⇒ concat via
    ;; `rrb-concat` ⇒ ONE keyless component. The empty champ layer concats to
    ;; `@[]` — the identity; typing is deliberately more conservative there.
    ;; ⚠ EVERY refusal here is an INVARIANT GUARD through `(return (expr-panic
    ;; …))`, NEVER `error` — typing carries the user-facing refusal, and
    ;; reduction must not depend on typing having run (`select-reduce` is called
    ;; from whnf; a raise here is a WHOLE-FILE abort).
    (define (star-entries v b seen)
      (let* ([rev (reverse b)]
             [star (car rev)]
             [prefix (reverse (cdr rev))]
             [oops (lambda (why)
                     (return (expr-panic (expr-string
                       (format "select: `*` — ~a (typing carries the user-facing refusal; reaching the value layer with this shape is a compiler-invariant violation)"
                               why)))))])
        (cond
          [(or (not (select-star-step? star)) (ormap select-star-step? prefix))
           (oops "a step after the flatten — `*` is only supported at the END of a branch")]
          ;; ⚠ B-verify F1/F7/F8 — the depth-≥2 shield, the typing twin's mirror
          ;; (see star-branch-entries for the full reasoning): at depth ≥ 2 the
          ;; shipped layer choice contradicts Q_U40's ruling, so it refuses
          ;; until ruled rather than producing the root-layer value.
          [(and (pair? prefix) (pair? (cdr prefix)))
           (oops "a multi-step prefix — which layer a deep flatten deletes is not yet ruled (typing refuses this shape)")]
          [else
           ;; ⭐ 1b-iii-C1: the join is SHARED (`star-join-value`, module level).
           ;; THIS caller is the remainder-EMPTY one — depth ≤ 1 — so it wraps the
           ;; bare join KEYLESS, matching the typing twin's own caller and the
           ;; behaviour that shipped at B2.
           (list (cons #f (star-join-value (if (null? prefix) v (below-value v prefix seen))
                                           star oops)))])))
    ;; ⭐ 1b-iii-B1 — the LEVEL assembly guard, the reduction mirror of typing's
    ;; star L4 check in `select-level-components`. STAR-GATED for the same
    ;; reason (starless behaviour must not move), and an invariant guard for the
    ;; same reason (typing's guided `star-l4-mixed` fires first on the typed
    ;; path). Without it, `entries->value`'s first-component fork either raises
    ;; in `make-record` (keyed first) or silently drops the keyed siblings
    ;; (keyless first) — round 1's defects #2/#3, order-dependent.
    (define (level-entries v bs)
      (let ([entries (append-map (lambda (b) (branch-entries v b '())) bs)])
        (when (and (ormap (lambda (b) (ormap select-star-step? b)) bs)
                   (ormap (lambda (e) (car e)) entries)
                   (ormap (lambda (e) (not (car e))) entries))
          (return (expr-panic (expr-string
            "select: internal — a flatten's keyless component beside keyed siblings reached the value layer (typing's star L4 check refuses this block)"))))
        entries))
    ;; D4.P3c: v is the RAW subject value (champ OR rrb) — each branch
    ;; dispatches per its head kind, mirroring typing's per-branch dispatch.
    ;; component ::= (cons kw-label . value) keyed | (cons #f value) keyless.
    (define (branch-entries v b seen)
      ;; shared by collapse + keyless: descend every step to the leaf value.
      ;; P3c verify (rank 1): the `(@ord N)` head arm — the ATOMIC twin of
      ;; typing's walk-to-leaf arm (missing here = champ-of panic on rrb).
      (define (walk-to-leaf)
        (let walk ([steps b] [v v])
          (let* ([s (car steps)]
                 [name (select-step-name s)]
                 ;; D4.P4a site 6: was `[else …]` — a sixth kind was silently
                 ;; projected as a NOMINAL KEY (and would have surfaced, if at
                 ;; all, as a champ-of "not a map" panic naming the wrong thing).
                 [hit (case (select-step-kind s)
                        [(ord-step) (index-into v s name)]
                        [(ord-branch) (index-into v (cadr s) (cadr s))]
                        [(key caret sub) (project (champ-of v name) name)]
                        ;; ✅ D4.P4c-4c: the value semantics LANDED, atomically
                        ;; with typing-core's twin. Landing either alone is not a
                        ;; half-measure but a REGRESSION — typing-first lets a
                        ;; successfully-typed broadcast reach this layer and
                        ;; raise, which `process-command/solve-guard` does not
                        ;; catch (whole-file abort); reduction-first types a
                        ;; refusal over a value that would have worked.
                        [(bcast) (bcast-lift v s)]
                        [else (select-step-kind-unhandled 'select-walk-to-leaf s)])])
            (if (null? (cdr steps))
                hit
                (walk (cdr steps) hit)))))
      (let ([col (select-branch-collapse b)])
        (cond
          ;; ⭐⭐ 1b-iii-B1: FIRST, before `col`/`keyless?` — both read the
          ;; branch's LAST step, which for a star branch is the star (or a caret
          ;; after one — round 1's abort). Same position as the typing twin's.
          [(ormap select-star-step? b)
           (star-entries v b seen)]
          [col
           (list (cons (cond [(select-cont-rename col)]
                             [(eq? col 'collapse-synth)
                              (select-synth-name (append seen b))]
                             [else (select-step-name (car (reverse b)))])
                       (walk-to-leaf)))]
          [(select-branch-keyless? b)
           ;; P3c: the keyless component — the leaf VALUE, no key
           (list (cons #f (walk-to-leaf)))]
          [(select-ord-step? (car b))
           ;; P3c: ordinal BRANCH — keyless component over the element
           (let* ([n (cadr (car b))]
                  [elem (index-into v n n)])
             (if (null? (cdr b))
                 (list (cons #f elem))
                 (list (cons #f (below-value elem (cdr b) '())))))]
          [(number? (car b))
           ;; bare-number STEP chain (splice continuation): transparent
           (let ([elem (index-into v (car b) (car b))])
             (if (null? (cdr b))
                 (list (cons #f elem))
                 (branch-entries elem (cdr b) seen)))]
          ;; D4.P4a site 7: was a bare `[else …]` — a sixth kind was silently
          ;; projected as a NOMINAL KEY. Guard rather than `case`: the body is
          ;; the walk's largest arm. `sub` joins `key`/`caret` because that is
          ;; what the old `else` caught — behaviour-preserving by construction.
          [(memq (select-step-kind (car b)) '(key caret sub))
           (let* ([s (car b)]
                  [rest (cdr b)]
                  [name (select-step-name s)]
                  [cont (select-step-cont s)]
                  [hit (project (champ-of v name) name)])
             (cond
               [(null? rest)
                (list (cons (cond [(and cont (select-cont-rename cont))]
                                  [(eq? cont 'synth)
                                   (select-synth-name (append seen (list s)))]
                                  [else name])
                            hit))]
               [(eq? cont 'dissolve)
                (below-components hit rest (append seen (list s)))]
               [else
                (list (cons (or (and cont (select-cont-rename cont)) name)
                            (below-value hit rest (append seen (list s)))))]))]
          ;; ⚠ POLARITY CORRECTED at D4.P4c-4b: NOT unreachable-at-head — `users:name`
          ;; reaches the branch head ($select-path consumes the subject). Reduction
          ;; KEEPS its raise here deliberately: typing now refuses through its
          ;; failure slot, so arriving at the VALUE layer with an ω step is a
          ;; compiler-invariant violation, not a user error. Two arms, two
          ;; questions — not belt-and-suspenders.
          ;; It is written, not omitted: the refusal is a SURFACE rule and a surface
          ;; rule is not a representation invariant — P5's factoring rewrites
          ;; branches. Loud not-yet rather than a guess at semantics P4c-4 owns.
          ;; ✅ D4.P4c-4c: the value semantics LANDED. THE ARM THE HEADLINE
          ;; SPELLING REACHES (measured — `users:name` routes here, not to
          ;; walk-to-leaf), and like its typing twin it returns a COMPONENT
          ;; LIST, not a value. The label is `select-step-output-name`, which is
          ;; ω-transparent by its own arm.
          [(eq? (select-step-kind (car b)) 'bcast)
           (let* ([s (car b)]
                  [rest (cdr b)]
                  [label (select-step-output-name s)]
                  [hit (bcast-lift v s)])
             (if (null? rest)
                 (list (cons label hit))
                 ;; continue against the RE-WRAPPED result — this is what makes
                 ;; `x:s:t` fuse to one layer rather than nest
                 (list (cons label (below-value hit rest seen)))))]
          [else (select-step-kind-unhandled 'select-branch-entries (car b))])))
    ;; the COMPONENTS a dissolved head splices (terminal sub-block = that
    ;; block's level, fresh branches; else the steps continue as one branch).
    ;; D4.P3a verify hardening carried: a sub-block is TERMINAL.
    (define (below-components v steps seen)
      (cond
        [(and (pair? (car steps)) (eq? (car (car steps)) '@sub))
         (if (null? (cdr steps))
             (level-entries v (cdr (car steps)))
             (return (expr-panic
                      (expr-string
                       "select: internal — steps after a terminal sub-block (the parser grammar forbids this shape)"))))]
        [else (branch-entries v steps seen)]))
    ;; the VALUE below a kept/renamed head: terminal sub-block assembles
    ;; honestly (incl. the keyless 1-tuple); ordinal steps descend with no
    ;; level (Q_U2); keyed chains build their nested level.
    (define (below-value v steps seen)
      (cond
        [(and (pair? (car steps)) (eq? (car (car steps)) '@sub))
         (if (null? (cdr steps))
             (entries->value (level-entries v (cdr (car steps))))
             (return (expr-panic
                      (expr-string
                       "select: internal — steps after a terminal sub-block (the parser grammar forbids this shape)"))))]
        [(number? (car steps))
         ;; ordinal STEP: descend, no output level (Reading A); seen carries
         ;; (numbers contribute no synth name — the shared walk skips them)
         (let ([elem (index-into v (car steps) (car steps))])
           (if (null? (cdr steps))
               elem
               (below-value elem (cdr steps) seen)))]
        ;; D4.P4a site 8: was a bare `[else …]`. The guard must list EXACTLY
        ;; what that else caught. ⚠ The twins are NOT symmetric here, and the
        ;; first version of this comment said they were (corrected at the P4a
        ;; verify): typing-core's arm-1 guard is `(and (select-sub-step? …)
        ;; (null? (cdr steps)))`, so its old else DID see non-terminal `sub`
        ;; — but reduction's arm at :1753 guards on `@sub` alone and tests
        ;; terminality INSIDE the arm, so `sub` never reached this else at
        ;; all. `sub` is therefore a DEAD entry in this list: harmless (a
        ;; wider guard, unreachable position) but not what the comment
        ;; claimed. What both twins genuinely omitted in the first cut, and
        ;; what is actually load-bearing here, is `ord-branch`.
        [(memq (select-step-kind (car steps)) '(key caret sub ord-branch))
         (entries->value (branch-entries v steps seen))]
        ;; ✅ D4.P4c-4c: the value semantics LANDED. `bcast` still does NOT join
        ;; the memq above, and now for a second reason: that arm runs
        ;; `entries->value`, which would wrap the broadcast result in a spurious
        ;; level. ω descends transparently, like the ordinal arm above it.
        [(eq? (select-step-kind (car steps)) 'bcast)
         (let ([hit (bcast-lift v (car steps))])
           (if (null? (cdr steps))
               hit
               (below-value hit (cdr steps) seen)))]
        [else (select-step-kind-unhandled 'select-below-value (car steps))]))
    ;; D4.P4a: HOIST the subject's whnf out of the per-branch lambda. The
    ;; header comment above has claimed since P3a that the subject is
    ;; "evaluated ONCE ... reused across every branch" — it was not: `(whnf
    ;; subj-expr)` sat INSIDE the append-map lambda, so an N-branch block
    ;; whnf'd the subject N times. Pure win (whnf is a pure function of the
    ;; expr); this makes the code match its own documented contract.
    (let* ([subj* (whnf subj-expr)]
           [entries (level-entries subj* branches)])
      ;; D4.P4b-ii-2a — THE `'path` ASSEMBLY. A block PROJECTS (assemble the
      ;; components into a row/tuple); a path EXTRACTS (yield the leaf value).
      ;; Both sorts assembled a ROW before this slice, which is why the fold
      ;; could not be flipped: `x.a` would have produced `{:a …}` instead of
      ;; the value. Under Q_U13's NEST encoding a `'path` carrier is exactly
      ;; one branch of one step per level, so extraction is unambiguous.
      (case sort
        [(block) (entries->value entries)]
        [(path)
         (if (and (pair? entries) (null? (cdr entries)))
             (cdr (car entries))
             ;; not constructible from the surface under NEST — a path
             ;; selector with 0 or >1 components is a malformed carrier, and
             ;; silently taking the first is how the P2.b fabrication class
             ;; starts. Loud, per this phase's whole discipline.
             (return (expr-panic
                      (expr-string
                       (format "select: a path selector must yield exactly ONE component, got ~a (malformed carrier — the path sort EXTRACTS, it does not project)"
                               (length entries))))))]
        [else (select-sort-unhandled 'select-reduce sort)]))))

(define (validate-tabulate sname closed? plan subj-champ names)
  (define c (expr-champ-racket-champ subj-champ))
  (define ok-name          (list-ref names 2))
  (define err-name         (list-ref names 3))
  (define missing-name     (list-ref names 4))
  (define checkfail-name   (list-ref names 5))
  (define typemis-name     (list-ref names 6))
  (define unexpected-name  (list-ref names 7))
  ;; F1b.7a: the Layer B guard's Reason ctor (index 8, appended in the
  ;; elaborator required-names) — a :check that cannot be evaluated.
  (define unevaluable-name (list-ref names 8))
  ;; F1b.7b: the un-evaluable-:default diagnostic (index 9) — a filled default
  ;; that didn't reduce to a clean value (an unresolved trait method).
  (define default-uneval-name (list-ref names 9))
  (define plan-kws (map car plan))
  ;; the ok-payload base: the subject champ rebuilt with nf'd values
  (define base-ok
    (champ-fold c
                (lambda (k v acc)
                  (define v* (nf v))
                  ;; SUB.1 tripwire: nf-persisting boundary 3 (validate base-ok)
                  (assert-no-open-container! 'validate v*)
                  (champ-insert acc (equal-hash-code k) k v*))
                champ-empty))
  ;; walk the plan: collect-all errs + fill defaults; escape on pred panic
  (let loop ([entries plan] [okc base-ok] [errc champ-empty] [any-err? #f])
    (cond
      [(pair? entries)
       (define entry (car entries))
       (define kw       (car entry))
       (define tag      (cadr entry))
       (define default  (caddr entry))
       (define pred     (cadddr entry))
       (define type-str (list-ref entry 4))
       (define pred-str (list-ref entry 5))
       ;; F1b.5-s4: required-on-miss? — schema plans set #t for every field;
       ;; selection plans set #t iff the field is a single-segment :requires
       ;; (the read-capability). Absent+no-default+required → missing-required;
       ;; absent+no-default+NOT-required → a partial-view SKIP (D22.4 amendment 2:
       ;; :requires is a read-capability, not a completeness contract).
       (define required? (list-ref entry 6))
       (define kexpr (expr-keyword kw))
       (define khash (equal-hash-code kexpr))
       (define found (champ-lookup c khash kexpr))
       (cond
         ;; missing + no default
         [(and (eq? found 'none) (not default))
          (if required?
              (loop (cdr entries) okc
                    (champ-insert errc khash kexpr (expr-fvar missing-name))
                    #t)
              (loop (cdr entries) okc errc any-err?))]  ; SKIP (view: optional field)
         [else
          (define val (nf (if (eq? found 'none) default found)))
          (cond
            ;; type-witness (the s1 acceptance tags; skip-safe by construction)
            [(not (value-witnesses-tag? val tag))
             ;; F1b.7b: distinguish a stuck FILLED DEFAULT from a provided-value
             ;; type-mismatch. found='none here ⟹ val came from the default (the
             ;; missing+no-default branch is handled above), so a witness-fail on
             ;; it means the :default expr did not reduce to a clean value (an
             ;; unresolved trait method — resolution deferred to the refinement
             ;; track). Name it clearly instead of mislabeling as type-mismatch.
             (loop (cdr entries) okc
                   (champ-insert errc khash kexpr
                                 (if (eq? found 'none)
                                     (expr-fvar default-uneval-name)
                                     (expr-app (expr-app (expr-fvar typemis-name)
                                                         (expr-string type-str))
                                               (expr-string (value-kind-string val)))))
                   #t)]
            [else
             ;; :check pred (baked expr-lam; beta via nf)
             (define pred-result (and pred (nf (expr-app pred val))))
             (cond
               ;; no :check on this field → passes
               [(not pred-result)
                (loop (cdr entries) (champ-insert okc khash kexpr val) errc any-err?)]
               ;; panic in a pred → the panic IS the node's result (D27.3)
               [(expr-panic? pred-result) pred-result]
               ;; a clean Bool result: true passes, false is a check-failed
               [(expr-true? pred-result)
                (loop (cdr entries) (champ-insert okc khash kexpr val) errc any-err?)]
               [(expr-false? pred-result)
                (loop (cdr entries) okc
                      (champ-insert errc khash kexpr
                                    (expr-app (expr-fvar checkfail-name)
                                              (expr-string (or pred-str "check"))))
                      #t)]
               ;; F1b.7a (Layer B guard): the pred did NOT reduce to a Bool
               ;; (a stuck trait method / an unbound name / a [fn …] value).
               ;; A :check that cannot be evaluated must FAIL LOUD, never
               ;; silently pass (the old `else` treated stuck as pass —
               ;; err-polarity mis-applied to :check eval). Fail-closed.
               [else
                (loop (cdr entries) okc
                      (champ-insert errc khash kexpr
                                    (expr-app (expr-fvar unevaluable-name)
                                              (expr-string (or pred-str "check"))))
                      #t)])])])]
      [else
       ;; :closed schemas: any subject key outside the plan → unexpected-field
       (define err-pair
         (if closed?
             (champ-fold c
                         (lambda (k v acc-pair)
                           (if (and (expr-keyword? k)
                                    (memq (expr-keyword-name k) plan-kws))
                               acc-pair
                               (cons (champ-insert (car acc-pair) (equal-hash-code k) k
                                                   (expr-fvar unexpected-name))
                                     #t)))
                         (cons errc any-err?))
             (cons errc any-err?)))
       (if (cdr err-pair)
           (expr-app (expr-fvar err-name) (expr-champ (car err-pair)))
           (expr-app (expr-fvar ok-name) (expr-champ okc)))])))

;; "Is `e` a CONCRETE non-map VALUE?" — the property the degradation arms
;; actually need, stated by their own callers: reduction.rkt's map-get arm says
;; "If m* is a concrete non-map value, return none … map-get on an Int from a
;; mixed-type union."
;;
;; CIU T6 P2.b (SITE 7) — THE POLARITY WAS INVERTED. This was written as
;; `(not (or <every node kind that might be a map>))`: a hand-maintained
;; NEGATIVE inclusion list whose DEFAULT was to FABRICATE. Any node kind nobody
;; remembered to exempt was judged "definitely not a map", so a `map-get` over
;; it degraded to `none` — a legitimate library value, at the correctly
;; projected type, with zero errors reported.
;;
;; That list was patched FIVE times, always by adding a sixth exemption, and
;; every patch's own comment records a silent-value-loss bug found AFTER the
;; fact: get-in/update-in (2026-07-16 P6) · broadcast-get (P2.a — "left out of
;; the 2026-07-16 fix") · expr-error · expr-panic (D22) · expr-validate
;; (F1b.5-s2). Site 7 was the sixth instance: a TUPLE's runtime representation
;; is `expr-rrb`, which nobody had exempted, so `[map-get tup 1N]` on a PRESENT
;; position returned `none` — and a `def` committed it silently at the right
;; type. A green suite could not see any of it.
;;
;; The fix is the POLARITY, not a sixth exemption (`pipeline.md` § Exhaustive
;; Walkers — "prefer the STRUCTURAL answer to the checklist"): enumerate
;; POSITIVELY the values we are certain are not maps, and default to #f. An
;; unrecognized node — including every node kind added in future — is now
;; CONSERVATIVE: map-get stays stuck rather than inventing absence. The unsafe
;; direction is no longer the default, so this list cannot silently rot.
;;
;; Deliberately ABSENT (and this is the site-7 fix): `expr-rrb` / `expr-trrb`.
;; A PVec/tuple is a legitimate nat-keyed map-get subject — it must project,
;; not degrade. `expr-champ` is absent because it IS a map.
;; CIU T6 P2.b slice 4: key display for the loud map-get miss. Keywords are the
;; overwhelmingly common case; the fallback is the raw struct (rare, still
;; informative). Deliberately NOT pp-expr — reduction must not require
;; pretty-print (module cycle).
(define (fmt-map-key k)
  (cond
    [(expr-keyword? k) (format ":~a" (expr-keyword-name k))]
    [(expr-string? k) (format "~s" (expr-string-val k))]
    [(expr-nat-val? k) (format "~aN" (expr-nat-val-n k))]
    [(expr-int? k) (format "~a" (expr-int-val k))]
    [else (format "~a" k)]))

(define (definitely-not-map? e)
  (or ;; numeric values
      (expr-zero? e) (expr-suc? e) (expr-nat-val? e)
      (expr-int? e) (expr-rat? e) (expr-num-lit? e)
      (expr-posit8? e) (expr-posit16? e) (expr-posit32? e) (expr-posit64? e)
      ;; text values
      (expr-string? e) (expr-char? e)
      ;; other scalar values
      (expr-true? e) (expr-false? e)
      (expr-keyword? e) (expr-symbol? e)
      (expr-unit? e) (expr-nil? e)
      ;; a function is not a map
      (expr-lam? e)
      ;; a SET is not a map (distinct carrier, no key→value association)
      (expr-hset? e)))

;; ========================================
;; Weak Head Normal Form
;; Per-command memoization: when current-whnf-cache is active,
;; cache whnf results keyed by expr.
;; ========================================
(define current-whnf-cache (make-parameter #f))
;; Fuel: #f = unlimited, or a box containing remaining step count.
;; Use (box N) to set a limit; whnf-impl decrements on each call.
(define current-reduction-fuel (make-parameter #f))

(define (whnf e)
  (define cache (current-whnf-cache))
  (cond
    [(and cache (hash-ref cache e #f))
     => values]
    [else
     (define result (whnf-impl e))
     ;; Issue #70 (N6e-E5): do NOT cache a result that is an (unsolved) meta —
     ;; a meta whnf'd before its solve would otherwise pin the UNRESOLVED meta
     ;; in the per-command cache, permanently masking the solution from every
     ;; later whnf in the same command (exposed by the deferred spine walk,
     ;; which legitimately whnfs metas after mid-command container solves).
     ;; A SOLVED meta's whnf returns its solution (concrete) and caches fine —
     ;; solutions are solve-once permanent.
     (when (and cache (not (expr-meta? result)))
       (hash-set! cache e result))
     result]))

;; Fast-path: is this expression definitely already in WHNF?
;; Returns #t for type atoms, type constructors, value constructors,
;; compound type formers, lambdas, pairs, and unions — expressions that
;; no whnf-impl match arm can reduce.
;;
;; This avoids the ~150μs cost of falling through the 1,700-line match
;; in whnf-impl for expressions that are trivially in WHNF.
;; Each predicate is a struct check (~0.01μs). The guard adds ~0.5μs
;; for the common case (type atoms in lattice operations) vs ~150μs
;; for the match fallthrough.
;;
;; Conservative: returns #f for anything uncertain → falls to full match.
;; Only returns #t for forms we are CERTAIN have no reduction rule.
(define (whnf-trivial? e)
  (or ;; Type atoms (nullary type constructors)
      (expr-Nat? e) (expr-Int? e) (expr-Rat? e)
      (expr-Bool? e) (expr-String? e) (expr-Char? e) (expr-Keyword? e)
      (expr-Unit? e) (expr-Nil? e) (expr-Symbol? e) (expr-Path? e)
      (expr-Posit8? e) (expr-Posit16? e) (expr-Posit32? e) (expr-Posit64? e)
      (expr-Float32? e) (expr-Float64? e)
      (expr-Quire8? e) (expr-Quire16? e) (expr-Quire32? e) (expr-Quire64? e)
      ;; Type constructors (compound type formers — no reduction rule)
      (expr-Pi? e) (expr-Sigma? e) (expr-Type? e)
      (expr-Vec? e) (expr-Eq? e) (expr-Fin? e)
      (expr-Map? e) (expr-Set? e) (expr-PVec? e)
      (expr-Record? e)  ;; structural row type — a compound type former, no reduction rule
      (expr-TVec? e) (expr-TMap? e) (expr-TSet? e)
      ;; Value constructors (canonical forms)
      (expr-true? e) (expr-false? e) (expr-zero? e) (expr-nat-val? e)
      (expr-unit? e) (expr-nil? e) (expr-refl? e)
      (expr-int? e) (expr-rat? e) (expr-string? e) (expr-char? e)
      (expr-keyword? e) (expr-symbol? e)
      (expr-posit8? e) (expr-posit16? e) (expr-posit32? e) (expr-posit64? e)
      (expr-float32? e) (expr-float64? e)
      ;; Structural forms (not reducible at head)
      (expr-lam? e) (expr-pair? e) (expr-union? e)
      (expr-vcons? e) (expr-vnil? e)
      ;; D4.P4a: container VALUE carriers. This list held every container
      ;; TYPE former (Map/Set/PVec/TVec/TMap/TSet/Record) and ZERO of the
      ;; value carriers, so every champ/rrb/hset reaching whnf paid the full
      ;; ~990-arm match to arrive at `[_ e]` (reduction.rkt:3957) — identity.
      ;; SAFETY PROOF (verified at `cab30b9a`, re-verify if the match moves):
      ;; `whnf-impl/match` has NO bare-head arm for any of the three — every
      ;; expr-champ/expr-rrb/expr-hset pattern in it sits at nested indent,
      ;; matching an already-whnf'd ARGUMENT of a map/set/vector operation,
      ;; never `e` itself. So the fast path returns exactly what the match
      ;; returned — VALUE-identical, one predicate instead of the match.
      ;; ⚠ NOT "identical semantics" without qualification (corrected at the
      ;; P4a adversarial verify, found independently by two reviewers): the
      ;; fast path returns at :2062, BEFORE the fuel decrement in the `else`
      ;; at :2065-2069, so a champ/rrb/hset now consumes ZERO reduction fuel.
      ;; That is a real semantic delta. It is one-way (a program that used to
      ;; exhaust the 1M budget may now complete; never the reverse), cannot
      ;; produce a wrong answer, and matches how the ~70 pre-existing trivial
      ;; kinds already behave — but it is NOT covered by the match-arm proof
      ;; above and must not be smuggled under it.
      (expr-champ? e) (expr-rrb? e) (expr-hset? e)
      ;; D4.P4b-i: the SELECTOR carrier value. `whnf-trivial?` already held
      ;; `expr-Path?` (the TYPE, :2014) but not `expr-path?` (the VALUE) — the
      ;; same type-former-without-its-value-carrier gap P4a closed for
      ;; champ/rrb/hset, one line away and missed by that census too.
      ;; VERIFIED at `f072c115`: `whnf-impl/match` has NO arm for `expr-path`
      ;; at any indent, so it already fell to `[_ e]` (:3957) — identity — and
      ;; `nf`'s arm is likewise `[(expr-path _ _) e]`. A path literal is a
      ;; canonical form with no head reduction rule, which is this predicate's
      ;; own stated criterion for membership.
      ;; ⚠ This is a DECISION, not an inheritance (the P4b audit named it as
      ;; one): the SELECTOR is a literal and belongs here; `expr-select` — the
      ;; APPLICATION of a selector to a subject — IS reducible (whnf arm at
      ;; :2967-2982) and must stay OUT.
      (expr-path? e)
      ;; Bound variables (stuck — no definition to unfold)
      (expr-bvar? e)
      ;; Type constructor names
      (expr-tycon? e)
      ;; Logic engine types (ground)
      (expr-net-type? e) (expr-cell-id-type? e) (expr-prop-id-type? e)
      (expr-uf-type? e)
      (expr-table-store-type? e) (expr-solver-type? e) (expr-goal-type? e)
      (expr-derivation-type? e)
      (expr-answer-type? e) (expr-relation-type? e)
      ;; Error / holes (stuck)
      (expr-error? e) (expr-hole? e) (expr-typed-hole? e)))

(define (whnf-impl e)
  (perf-inc-reduce!)
  ;; Fast path: trivially-WHNF expressions bypass the full match.
  ;; Cost: ~0.5μs (struct predicate checks) vs ~150μs (match fallthrough).
  (cond
    ;; Numerics N5de: type-lattice sentinels (from on-network type-unify-or-top merges) are
    ;; symbols, not exprs; pass through so a compound type carrying a nested type-top/bot
    ;; doesn't crash reduction. (Full on-network refinement handling → future PPN track, §15.)
    [(or (eq? e 'type-top) (eq? e 'type-bot)) e]
    [(whnf-trivial? e) e]
    [else
     ;; Check fuel
     (let ([fuel (current-reduction-fuel)])
       (when fuel
         (when (<= (unbox fuel) 0)
           (error 'reduction "fuel exhausted after too many reduction steps"))
         (set-box! fuel (sub1 (unbox fuel)))))
     (whnf-impl/match e)]))

;; The full match dispatch, split out so the fast-path guard in whnf-impl
;; can skip the ~1,700-line match entirely for non-reducible expressions.
(define (whnf-impl/match e)
  (match e
    ;; Beta reduction: app(lam(m, A, body), arg) -> whnf(subst(0, arg, body))
    [(expr-app (expr-lam _ _ body) arg)
     (whnf (subst 0 arg body))]

    ;; Projections on pairs
    [(expr-fst (expr-pair e1 _)) (whnf e1)]
    [(expr-snd (expr-pair _ e2)) (whnf e2)]

    ;; Iota reduction for natrec — native nat-val (Idris 2 model)
    [(expr-natrec _ base _ (expr-nat-val n)) #:when (= n 0) (whnf base)]
    [(expr-natrec mot base step (expr-nat-val n)) #:when (> n 0)
     (whnf (expr-app (expr-app step (expr-nat-val (- n 1)))
                     (expr-natrec mot base step (expr-nat-val (- n 1)))))]
    ;; Iota reduction for natrec — legacy Peano representation
    [(expr-natrec _ base _ (expr-zero)) (whnf base)]
    [(expr-natrec mot base step (expr-suc n))
     (whnf (expr-app (expr-app step n) (expr-natrec mot base step n)))]

    ;; Suc collapse: concrete inner → native nat-val
    [(expr-suc (expr-nat-val k)) (expr-nat-val (+ k 1))]
    [(expr-suc (expr-zero))      (expr-nat-val 1)]

    ;; J reduction: J(motive, base, a, _, refl) -> app(base, a)
    [(expr-J _ base left _ (expr-refl)) (whnf (expr-app base left))]

    ;; Bool elimination (iota rules)
    ;; boolrec(M, t, f, true)  -> t
    ;; boolrec(M, t, f, false) -> f
    [(expr-boolrec _ tc _ (expr-true)) (whnf tc)]
    [(expr-boolrec _ _ fc (expr-false)) (whnf fc)]

    ;; Annotation erasure
    [(expr-ann e1 _) (whnf e1)]

    ;; Vec eliminators: vhead/vtail on vcons
    [(expr-vhead _ _ (expr-vcons _ _ hd _)) (whnf hd)]
    [(expr-vtail _ _ (expr-vcons _ _ _ tl)) (whnf tl)]

    ;; Foreign function application: accumulate args, call when arity reached
    [(expr-app (expr-foreign-fn name proc arity args marshal-in marshal-out src-mod rkt-name) arg)
     (let* ([arg* (whnf arg)]
            [new-args (append args (list arg*))])
       (if (= (length new-args) arity)
           ;; All args collected — fully normalize for marshalling, then call Racket
           (let* ([nf-args (map nf new-args)]
                  [rkt-args (map (lambda (m a) (m a)) marshal-in nf-args)]
                  [rkt-result (apply proc rkt-args)]
                  [prologos-result (marshal-out rkt-result)])
             (whnf prologos-result))
           ;; Partial application — return updated foreign-fn
           (expr-foreign-fn name proc arity new-args marshal-in marshal-out src-mod rkt-name)))]

    ;; Application of non-lambda: reduce function first
    [(expr-app e1 e2)
     (let ([e1* (whnf e1)])
       (if (equal? e1* e1)
           e  ; stuck — already in WHNF
           (whnf (expr-app e1* e2))))]

    ;; Projection of non-pair: reduce argument first
    [(expr-fst e1)
     (let ([e1* (whnf e1)])
       (if (equal? e1* e1)
           e
           (whnf (expr-fst e1*))))]
    [(expr-snd e1)
     (let ([e1* (whnf e1)])
       (if (equal? e1* e1)
           e
           (whnf (expr-snd e1*))))]

    ;; natrec with non-canonical target: reduce target first, then retry
    [(expr-natrec mot base step target)
     (let ([target* (whnf target)])
       (if (equal? target* target)
           e  ; stuck — target is neutral
           (whnf (expr-natrec mot base step target*))))]

    ;; J with non-refl proof: reduce proof first, then retry
    [(expr-J mot base left right proof)
     (let ([proof* (whnf proof)])
       (if (equal? proof* proof)
           e  ; stuck
           (whnf (expr-J mot base left right proof*))))]

    ;; boolrec with non-canonical target: reduce target first
    [(expr-boolrec mot tc fc target)
     (let ([target* (whnf target)])
       (if (equal? target* target)
           e  ; stuck — target is neutral
           (whnf (expr-boolrec mot tc fc target*))))]

    ;; vhead/vtail with non-vcons: reduce vec first
    [(expr-vhead t n v)
     (let ([v* (whnf v)])
       (if (equal? v* v) e (whnf (expr-vhead t n v*))))]
    [(expr-vtail t n v)
     (let ([v* (whnf v)])
       (if (equal? v* v) e (whnf (expr-vtail t n v*))))]

    ;; ---- Int iota rules: compute when arguments are int literals ----

    ;; Binary arithmetic on literals
    [(expr-int-add (expr-int a) (expr-int b)) (expr-int (+ a b))]
    [(expr-int-sub (expr-int a) (expr-int b)) (expr-int (- a b))]
    [(expr-int-mul (expr-int a) (expr-int b)) (expr-int (* a b))]
    [(expr-int-div (expr-int a) (expr-int b))
     (if (zero? b) e (expr-int (quotient a b)))]
    [(expr-int-mod (expr-int a) (expr-int b))
     (if (zero? b) e (expr-int (remainder a b)))]

    ;; Unary ops on literals
    [(expr-int-neg (expr-int a)) (expr-int (- a))]
    [(expr-int-abs (expr-int a)) (expr-int (abs a))]

    ;; Comparison on literals → Bool
    [(expr-int-lt (expr-int a) (expr-int b))
     (if (< a b) (expr-true) (expr-false))]
    [(expr-int-le (expr-int a) (expr-int b))
     (if (<= a b) (expr-true) (expr-false))]
    [(expr-int-eq (expr-int a) (expr-int b))
     (if (= a b) (expr-true) (expr-false))]

    ;; from-nat: compute when arg is a Nat numeral
    [(expr-from-nat n)
     (let ([n* (whnf n)])
       (let ([k (nat-value n*)])
         (cond
           [k (expr-int k)]
           [(equal? n* n) e]    ; stuck
           [else (whnf (expr-from-nat n*))])))]

    ;; ---- Int stuck-term reduction ----

    ;; Binary ops: reduce operands
    [(expr-int-add a b) (reduce-int-binary expr-int-add a b)]
    [(expr-int-sub a b) (reduce-int-binary expr-int-sub a b)]
    [(expr-int-mul a b) (reduce-int-binary expr-int-mul a b)]
    [(expr-int-div a b) (reduce-int-binary expr-int-div a b)]
    [(expr-int-mod a b) (reduce-int-binary expr-int-mod a b)]
    [(expr-int-lt a b) (reduce-int-binary expr-int-lt a b)]
    [(expr-int-le a b) (reduce-int-binary expr-int-le a b)]
    [(expr-int-eq a b) (reduce-int-binary expr-int-eq a b)]

    ;; Unary ops: reduce operand
    [(expr-int-neg a) (reduce-int-unary expr-int-neg a)]
    [(expr-int-abs a) (reduce-int-unary expr-int-abs a)]

    ;; ---- Rat iota rules: compute when arguments are rat literals ----

    ;; Binary arithmetic on literals
    [(expr-rat-add (expr-rat a) (expr-rat b)) (expr-rat (+ a b))]
    [(expr-rat-sub (expr-rat a) (expr-rat b)) (expr-rat (- a b))]
    [(expr-rat-mul (expr-rat a) (expr-rat b)) (expr-rat (* a b))]
    [(expr-rat-div (expr-rat a) (expr-rat b))
     (if (zero? b) e (expr-rat (/ a b)))]

    ;; Unary ops on literals
    [(expr-rat-neg (expr-rat a)) (expr-rat (- a))]
    [(expr-rat-abs (expr-rat a)) (expr-rat (abs a))]

    ;; Comparison on literals → Bool
    [(expr-rat-lt (expr-rat a) (expr-rat b))
     (if (< a b) (expr-true) (expr-false))]
    [(expr-rat-le (expr-rat a) (expr-rat b))
     (if (<= a b) (expr-true) (expr-false))]
    [(expr-rat-eq (expr-rat a) (expr-rat b))
     (if (= a b) (expr-true) (expr-false))]

    ;; from-int: compute when arg is an int literal
    [(expr-from-int n)
     (let ([n* (whnf n)])
       (cond
         [(expr-int? n*) (expr-rat (expr-int-val n*))]
         [(equal? n* n) e]    ; stuck
         [else (whnf (expr-from-int n*))]))]

    ;; rat-numer: extract numerator when arg is a rat literal
    [(expr-rat-numer (expr-rat v)) (expr-int (numerator v))]

    ;; rat-denom: extract denominator when arg is a rat literal
    [(expr-rat-denom (expr-rat v)) (expr-int (denominator v))]

    ;; ---- Rat stuck-term reduction ----

    ;; Binary ops: reduce operands
    [(expr-rat-add a b) (reduce-rat-binary expr-rat-add a b)]
    [(expr-rat-sub a b) (reduce-rat-binary expr-rat-sub a b)]
    [(expr-rat-mul a b) (reduce-rat-binary expr-rat-mul a b)]
    [(expr-rat-div a b) (reduce-rat-binary expr-rat-div a b)]
    [(expr-rat-lt a b) (reduce-rat-binary expr-rat-lt a b)]
    [(expr-rat-le a b) (reduce-rat-binary expr-rat-le a b)]
    [(expr-rat-eq a b) (reduce-rat-binary expr-rat-eq a b)]

    ;; Unary ops: reduce operand
    [(expr-rat-neg a) (reduce-rat-unary expr-rat-neg a)]
    [(expr-rat-abs a) (reduce-rat-unary expr-rat-abs a)]
    [(expr-rat-numer a) (reduce-rat-unary expr-rat-numer a)]
    [(expr-rat-denom a) (reduce-rat-unary expr-rat-denom a)]

    ;; ---- Posit8 iota rules: compute when arguments are posit8 literals ----

    ;; Binary arithmetic on literals
    [(expr-p8-add (expr-posit8 a) (expr-posit8 b)) (expr-posit8 (posit8-add a b))]
    [(expr-p8-sub (expr-posit8 a) (expr-posit8 b)) (expr-posit8 (posit8-sub a b))]
    [(expr-p8-mul (expr-posit8 a) (expr-posit8 b)) (expr-posit8 (posit8-mul a b))]
    [(expr-p8-div (expr-posit8 a) (expr-posit8 b)) (expr-posit8 (posit8-div a b))]

    ;; Unary ops on literals
    [(expr-p8-neg (expr-posit8 a)) (expr-posit8 (posit8-neg a))]
    [(expr-p8-abs (expr-posit8 a)) (expr-posit8 (posit8-abs a))]
    [(expr-p8-sqrt (expr-posit8 a)) (expr-posit8 (posit8-sqrt a))]

    ;; Comparison on literals → Bool
    [(expr-p8-lt (expr-posit8 a) (expr-posit8 b))
     (if (posit8-lt? a b) (expr-true) (expr-false))]
    [(expr-p8-le (expr-posit8 a) (expr-posit8 b))
     (if (posit8-le? a b) (expr-true) (expr-false))]
    [(expr-p8-eq (expr-posit8 a) (expr-posit8 b))
     (if (posit8-eq? a b) (expr-true) (expr-false))]

    ;; from-nat: compute when arg is a Nat numeral
    [(expr-p8-from-nat n)
     (let ([n* (whnf n)])
       (let ([k (nat-value n*)])
         (cond
           [k (expr-posit8 (posit8-from-nat k))]
           [(equal? n* n) e]    ; stuck
           [else (whnf (expr-p8-from-nat n*))])))]

    ;; Phase 3f: p8-to-rat -- Posit8 -> Rat
    [(expr-p8-to-rat (expr-posit8 v))
     (let ([r (posit8-to-rational v)])
       (if (eq? r 'nar) (expr-error) (expr-rat r)))]
    [(expr-p8-to-rat a) (reduce-posit-unary 8 expr-p8-to-rat a)]

    ;; Phase 3f: p8-from-rat -- Rat -> Posit8
    [(expr-p8-from-rat (expr-rat v))
     (expr-posit8 (posit8-encode v))]
    [(expr-p8-from-rat a) (reduce-rat-unary expr-p8-from-rat a)]

    ;; Phase 3f: p8-from-int -- Int -> Posit8
    [(expr-p8-from-int (expr-int v))
     (expr-posit8 (posit8-encode v))]
    [(expr-p8-from-int a) (reduce-int-unary expr-p8-from-int a)]

    ;; p8-if-nar: branch when val is a literal
    [(expr-p8-if-nar _ nc _ (expr-posit8 128)) (whnf nc)]    ; NaR = 0x80 = 128
    [(expr-p8-if-nar _ _ vc (expr-posit8 _)) (whnf vc)]      ; any non-NaR literal

    ;; ---- Posit8 stuck-term reduction ----

    ;; Binary ops: reduce operands
    [(expr-p8-add a b) (reduce-posit-binary 8 expr-p8-add a b)]
    [(expr-p8-sub a b) (reduce-posit-binary 8 expr-p8-sub a b)]
    [(expr-p8-mul a b) (reduce-posit-binary 8 expr-p8-mul a b)]
    [(expr-p8-div a b) (reduce-posit-binary 8 expr-p8-div a b)]
    [(expr-p8-lt a b) (reduce-posit-binary 8 expr-p8-lt a b)]
    [(expr-p8-le a b) (reduce-posit-binary 8 expr-p8-le a b)]
    [(expr-p8-eq a b) (reduce-posit-binary 8 expr-p8-eq a b)]

    ;; Unary ops: reduce operand
    [(expr-p8-neg a) (reduce-posit-unary 8 expr-p8-neg a)]
    [(expr-p8-abs a) (reduce-posit-unary 8 expr-p8-abs a)]
    [(expr-p8-sqrt a) (reduce-posit-unary 8 expr-p8-sqrt a)]

    ;; p8-if-nar: reduce the value argument
    [(expr-p8-if-nar t nc vc v)
     (let ([v* (whnf v)])
       (if (equal? v* v) e (whnf (expr-p8-if-nar t nc vc v*))))]

    ;; ---- Posit16 iota rules: compute when arguments are posit16 literals ----

    ;; Binary arithmetic on literals
    [(expr-p16-add (expr-posit16 a) (expr-posit16 b)) (expr-posit16 (posit16-add a b))]
    [(expr-p16-sub (expr-posit16 a) (expr-posit16 b)) (expr-posit16 (posit16-sub a b))]
    [(expr-p16-mul (expr-posit16 a) (expr-posit16 b)) (expr-posit16 (posit16-mul a b))]
    [(expr-p16-div (expr-posit16 a) (expr-posit16 b)) (expr-posit16 (posit16-div a b))]

    ;; Unary ops on literals
    [(expr-p16-neg (expr-posit16 a)) (expr-posit16 (posit16-neg a))]
    [(expr-p16-abs (expr-posit16 a)) (expr-posit16 (posit16-abs a))]
    [(expr-p16-sqrt (expr-posit16 a)) (expr-posit16 (posit16-sqrt a))]

    ;; Comparison on literals → Bool
    [(expr-p16-lt (expr-posit16 a) (expr-posit16 b))
     (if (posit16-lt? a b) (expr-true) (expr-false))]
    [(expr-p16-le (expr-posit16 a) (expr-posit16 b))
     (if (posit16-le? a b) (expr-true) (expr-false))]
    [(expr-p16-eq (expr-posit16 a) (expr-posit16 b))
     (if (posit16-eq? a b) (expr-true) (expr-false))]

    ;; from-nat: compute when arg is a Nat numeral
    [(expr-p16-from-nat n)
     (let ([n* (whnf n)])
       (let ([k (nat-value n*)])
         (cond
           [k (expr-posit16 (posit16-from-nat k))]
           [(equal? n* n) e]    ; stuck
           [else (whnf (expr-p16-from-nat n*))])))]

    ;; Phase 3f: p16-to-rat -- Posit16 -> Rat
    [(expr-p16-to-rat (expr-posit16 v))
     (let ([r (posit16-to-rational v)])
       (if (eq? r 'nar) (expr-error) (expr-rat r)))]
    [(expr-p16-to-rat a) (reduce-posit-unary 16 expr-p16-to-rat a)]

    ;; Phase 3f: p16-from-rat -- Rat -> Posit16
    [(expr-p16-from-rat (expr-rat v))
     (expr-posit16 (posit16-encode v))]
    [(expr-p16-from-rat a) (reduce-rat-unary expr-p16-from-rat a)]

    ;; Phase 3f: p16-from-int -- Int -> Posit16
    [(expr-p16-from-int (expr-int v))
     (expr-posit16 (posit16-encode v))]
    [(expr-p16-from-int a) (reduce-int-unary expr-p16-from-int a)]

    ;; p16-if-nar: branch when val is a literal
    [(expr-p16-if-nar _ nc _ (expr-posit16 32768)) (whnf nc)]    ; NaR = 0x8000 = 32768
    [(expr-p16-if-nar _ _ vc (expr-posit16 _)) (whnf vc)]        ; any non-NaR literal

    ;; ---- Posit16 stuck-term reduction ----

    ;; Binary ops: reduce operands
    [(expr-p16-add a b) (reduce-posit-binary 16 expr-p16-add a b)]
    [(expr-p16-sub a b) (reduce-posit-binary 16 expr-p16-sub a b)]
    [(expr-p16-mul a b) (reduce-posit-binary 16 expr-p16-mul a b)]
    [(expr-p16-div a b) (reduce-posit-binary 16 expr-p16-div a b)]
    [(expr-p16-lt a b) (reduce-posit-binary 16 expr-p16-lt a b)]
    [(expr-p16-le a b) (reduce-posit-binary 16 expr-p16-le a b)]
    [(expr-p16-eq a b) (reduce-posit-binary 16 expr-p16-eq a b)]

    ;; Unary ops: reduce operand
    [(expr-p16-neg a) (reduce-posit-unary 16 expr-p16-neg a)]
    [(expr-p16-abs a) (reduce-posit-unary 16 expr-p16-abs a)]
    [(expr-p16-sqrt a) (reduce-posit-unary 16 expr-p16-sqrt a)]

    ;; p16-if-nar: reduce the value argument
    [(expr-p16-if-nar t nc vc v)
     (let ([v* (whnf v)])
       (if (equal? v* v) e (whnf (expr-p16-if-nar t nc vc v*))))]

    ;; ---- Float32/Float64 iota rules (Numerics N3b) ----
    ;; Compute when both args are float literals; comparisons → Bool.
    [(expr-f32-add (expr-float32 a) (expr-float32 b)) (expr-float32 (float32-add a b))]
    [(expr-f32-sub (expr-float32 a) (expr-float32 b)) (expr-float32 (float32-sub a b))]
    [(expr-f32-mul (expr-float32 a) (expr-float32 b)) (expr-float32 (float32-mul a b))]
    [(expr-f32-div (expr-float32 a) (expr-float32 b)) (expr-float32 (float32-div a b))]
    [(expr-f32-neg (expr-float32 a)) (expr-float32 (float32-neg a))]
    [(expr-f32-abs (expr-float32 a)) (expr-float32 (float32-abs a))]
    [(expr-f32-sqrt (expr-float32 a)) (expr-float32 (float32-sqrt a))]
    [(expr-f32-lt (expr-float32 a) (expr-float32 b)) (if (float32-lt? a b) (expr-true) (expr-false))]
    [(expr-f32-le (expr-float32 a) (expr-float32 b)) (if (float32-le? a b) (expr-true) (expr-false))]
    [(expr-f32-eq (expr-float32 a) (expr-float32 b)) (if (float32-eq? a b) (expr-true) (expr-false))]
    [(expr-f64-add (expr-float64 a) (expr-float64 b)) (expr-float64 (float64-add a b))]
    [(expr-f64-sub (expr-float64 a) (expr-float64 b)) (expr-float64 (float64-sub a b))]
    [(expr-f64-mul (expr-float64 a) (expr-float64 b)) (expr-float64 (float64-mul a b))]
    [(expr-f64-div (expr-float64 a) (expr-float64 b)) (expr-float64 (float64-div a b))]
    [(expr-f64-neg (expr-float64 a)) (expr-float64 (float64-neg a))]
    [(expr-f64-abs (expr-float64 a)) (expr-float64 (float64-abs a))]
    [(expr-f64-sqrt (expr-float64 a)) (expr-float64 (float64-sqrt a))]
    [(expr-f64-lt (expr-float64 a) (expr-float64 b)) (if (float64-lt? a b) (expr-true) (expr-false))]
    [(expr-f64-le (expr-float64 a) (expr-float64 b)) (if (float64-le? a b) (expr-true) (expr-false))]
    [(expr-f64-eq (expr-float64 a) (expr-float64 b)) (if (float64-eq? a b) (expr-true) (expr-false))]
    ;; Float stuck-term reduction: reduce operands
    [(expr-f32-add a b) (reduce-float-binary 32 expr-f32-add a b)]
    [(expr-f32-sub a b) (reduce-float-binary 32 expr-f32-sub a b)]
    [(expr-f32-mul a b) (reduce-float-binary 32 expr-f32-mul a b)]
    [(expr-f32-div a b) (reduce-float-binary 32 expr-f32-div a b)]
    [(expr-f32-lt a b) (reduce-float-binary 32 expr-f32-lt a b)]
    [(expr-f32-le a b) (reduce-float-binary 32 expr-f32-le a b)]
    [(expr-f32-eq a b) (reduce-float-binary 32 expr-f32-eq a b)]
    [(expr-f32-neg a) (reduce-float-unary 32 expr-f32-neg a)]
    [(expr-f32-abs a) (reduce-float-unary 32 expr-f32-abs a)]
    [(expr-f32-sqrt a) (reduce-float-unary 32 expr-f32-sqrt a)]
    [(expr-f64-add a b) (reduce-float-binary 64 expr-f64-add a b)]
    [(expr-f64-sub a b) (reduce-float-binary 64 expr-f64-sub a b)]
    [(expr-f64-mul a b) (reduce-float-binary 64 expr-f64-mul a b)]
    [(expr-f64-div a b) (reduce-float-binary 64 expr-f64-div a b)]
    [(expr-f64-lt a b) (reduce-float-binary 64 expr-f64-lt a b)]
    [(expr-f64-le a b) (reduce-float-binary 64 expr-f64-le a b)]
    [(expr-f64-eq a b) (reduce-float-binary 64 expr-f64-eq a b)]
    [(expr-f64-neg a) (reduce-float-unary 64 expr-f64-neg a)]
    [(expr-f64-abs a) (reduce-float-unary 64 expr-f64-abs a)]
    [(expr-f64-sqrt a) (reduce-float-unary 64 expr-f64-sqrt a)]

    ;; ---- Cross-width Float conversions (Numerics N3e-rest) ----
    ;; Value cases for BOTH float widths. `rational?` guards exclude NaN/±Inf so
    ;; float-to-rat / float-to-int never hit `inexact->exact` on a non-rational.
    ;; float-finite? : Float -> Bool
    [(expr-float-finite (expr-float64 v)) (if (rational? v) (expr-true) (expr-false))]
    [(expr-float-finite (expr-float32 v)) (if (rational? v) (expr-true) (expr-false))]
    ;; float-to-rat : Float -> Rat (finite only; NaN/±Inf → falls through to stuck)
    [(expr-float-to-rat (expr-float64 v)) #:when (rational? v) (expr-rat (inexact->exact v))]
    [(expr-float-to-rat (expr-float32 v)) #:when (rational? v) (expr-rat (inexact->exact v))]
    ;; float-to-int : Float -> Int (truncate toward zero; finite only)
    [(expr-float-to-int (expr-float64 v)) #:when (rational? v) (expr-int (inexact->exact (truncate v)))]
    [(expr-float-to-int (expr-float32 v)) #:when (rational? v) (expr-int (inexact->exact (truncate v)))]
    ;; float-to-float32 : Float -> Float32 (narrowing; total — flsingle handles NaN/±Inf)
    [(expr-float-to-float32 (expr-float64 v)) (expr-float32 (flsingle v))]
    [(expr-float-to-float32 (expr-float32 v)) (expr-float32 v)]
    ;; Stuck-term reduction: reduce operand then retry. NaN/±Inf float-to-rat /
    ;; float-to-int reach here (value guard failed) and stay stuck without crashing.
    [(expr-float-finite a)
     (let ([a* (whnf a)]) (if (equal? a* a) (expr-float-finite a) (whnf (expr-float-finite a*))))]
    [(expr-float-to-rat a)
     (let ([a* (whnf a)]) (if (equal? a* a) (expr-float-to-rat a) (whnf (expr-float-to-rat a*))))]
    [(expr-float-to-int a)
     (let ([a* (whnf a)]) (if (equal? a* a) (expr-float-to-int a) (whnf (expr-float-to-int a*))))]
    [(expr-float-to-float32 a)
     (let ([a* (whnf a)]) (if (equal? a* a) (expr-float-to-float32 a) (whnf (expr-float-to-float32 a*))))]

    ;; ---- Posit32 iota rules: compute when arguments are posit32 literals ----

    ;; Binary arithmetic on literals
    [(expr-p32-add (expr-posit32 a) (expr-posit32 b)) (expr-posit32 (posit32-add a b))]
    [(expr-p32-sub (expr-posit32 a) (expr-posit32 b)) (expr-posit32 (posit32-sub a b))]
    [(expr-p32-mul (expr-posit32 a) (expr-posit32 b)) (expr-posit32 (posit32-mul a b))]
    [(expr-p32-div (expr-posit32 a) (expr-posit32 b)) (expr-posit32 (posit32-div a b))]

    ;; Unary ops on literals
    [(expr-p32-neg (expr-posit32 a)) (expr-posit32 (posit32-neg a))]
    [(expr-p32-abs (expr-posit32 a)) (expr-posit32 (posit32-abs a))]
    [(expr-p32-sqrt (expr-posit32 a)) (expr-posit32 (posit32-sqrt a))]

    ;; Comparison on literals → Bool
    [(expr-p32-lt (expr-posit32 a) (expr-posit32 b))
     (if (posit32-lt? a b) (expr-true) (expr-false))]
    [(expr-p32-le (expr-posit32 a) (expr-posit32 b))
     (if (posit32-le? a b) (expr-true) (expr-false))]
    [(expr-p32-eq (expr-posit32 a) (expr-posit32 b))
     (if (posit32-eq? a b) (expr-true) (expr-false))]

    ;; from-nat: compute when arg is a Nat numeral
    [(expr-p32-from-nat n)
     (let ([n* (whnf n)])
       (let ([k (nat-value n*)])
         (cond
           [k (expr-posit32 (posit32-from-nat k))]
           [(equal? n* n) e]    ; stuck
           [else (whnf (expr-p32-from-nat n*))])))]

    ;; Phase 3f: p32-to-rat -- Posit32 -> Rat
    [(expr-p32-to-rat (expr-posit32 v))
     (let ([r (posit32-to-rational v)])
       (if (eq? r 'nar) (expr-error) (expr-rat r)))]
    [(expr-p32-to-rat a) (reduce-posit-unary 32 expr-p32-to-rat a)]

    ;; Phase 3f: p32-from-rat -- Rat -> Posit32
    [(expr-p32-from-rat (expr-rat v))
     (expr-posit32 (posit32-encode v))]
    [(expr-p32-from-rat a) (reduce-rat-unary expr-p32-from-rat a)]

    ;; Phase 3f: p32-from-int -- Int -> Posit32
    [(expr-p32-from-int (expr-int v))
     (expr-posit32 (posit32-encode v))]
    [(expr-p32-from-int a) (reduce-int-unary expr-p32-from-int a)]

    ;; p32-if-nar: branch when val is a literal
    [(expr-p32-if-nar _ nc _ (expr-posit32 2147483648)) (whnf nc)]    ; NaR = 0x80000000 = 2147483648
    [(expr-p32-if-nar _ _ vc (expr-posit32 _)) (whnf vc)]             ; any non-NaR literal

    ;; ---- Posit32 stuck-term reduction ----

    ;; Binary ops: reduce operands
    [(expr-p32-add a b) (reduce-posit-binary 32 expr-p32-add a b)]
    [(expr-p32-sub a b) (reduce-posit-binary 32 expr-p32-sub a b)]
    [(expr-p32-mul a b) (reduce-posit-binary 32 expr-p32-mul a b)]
    [(expr-p32-div a b) (reduce-posit-binary 32 expr-p32-div a b)]
    [(expr-p32-lt a b) (reduce-posit-binary 32 expr-p32-lt a b)]
    [(expr-p32-le a b) (reduce-posit-binary 32 expr-p32-le a b)]
    [(expr-p32-eq a b) (reduce-posit-binary 32 expr-p32-eq a b)]

    ;; Unary ops: reduce operand
    [(expr-p32-neg a) (reduce-posit-unary 32 expr-p32-neg a)]
    [(expr-p32-abs a) (reduce-posit-unary 32 expr-p32-abs a)]
    [(expr-p32-sqrt a) (reduce-posit-unary 32 expr-p32-sqrt a)]

    ;; p32-if-nar: reduce the value argument
    [(expr-p32-if-nar t nc vc v)
     (let ([v* (whnf v)])
       (if (equal? v* v) e (whnf (expr-p32-if-nar t nc vc v*))))]

    ;; ---- Posit64 iota rules: compute when arguments are posit64 literals ----

    ;; Binary arithmetic on literals
    [(expr-p64-add (expr-posit64 a) (expr-posit64 b)) (expr-posit64 (posit64-add a b))]
    [(expr-p64-sub (expr-posit64 a) (expr-posit64 b)) (expr-posit64 (posit64-sub a b))]
    [(expr-p64-mul (expr-posit64 a) (expr-posit64 b)) (expr-posit64 (posit64-mul a b))]
    [(expr-p64-div (expr-posit64 a) (expr-posit64 b)) (expr-posit64 (posit64-div a b))]

    ;; Unary ops on literals
    [(expr-p64-neg (expr-posit64 a)) (expr-posit64 (posit64-neg a))]
    [(expr-p64-abs (expr-posit64 a)) (expr-posit64 (posit64-abs a))]
    [(expr-p64-sqrt (expr-posit64 a)) (expr-posit64 (posit64-sqrt a))]

    ;; Comparison on literals → Bool
    [(expr-p64-lt (expr-posit64 a) (expr-posit64 b))
     (if (posit64-lt? a b) (expr-true) (expr-false))]
    [(expr-p64-le (expr-posit64 a) (expr-posit64 b))
     (if (posit64-le? a b) (expr-true) (expr-false))]
    [(expr-p64-eq (expr-posit64 a) (expr-posit64 b))
     (if (posit64-eq? a b) (expr-true) (expr-false))]

    ;; from-nat: compute when arg is a Nat numeral
    [(expr-p64-from-nat n)
     (let ([n* (whnf n)])
       (let ([k (nat-value n*)])
         (cond
           [k (expr-posit64 (posit64-from-nat k))]
           [(equal? n* n) e]    ; stuck
           [else (whnf (expr-p64-from-nat n*))])))]

    ;; Phase 3f: p64-to-rat -- Posit64 -> Rat
    [(expr-p64-to-rat (expr-posit64 v))
     (let ([r (posit64-to-rational v)])
       (if (eq? r 'nar) (expr-error) (expr-rat r)))]
    [(expr-p64-to-rat a) (reduce-posit-unary 64 expr-p64-to-rat a)]

    ;; Phase 3f: p64-from-rat -- Rat -> Posit64
    [(expr-p64-from-rat (expr-rat v))
     (expr-posit64 (posit64-encode v))]
    [(expr-p64-from-rat a) (reduce-rat-unary expr-p64-from-rat a)]

    ;; Phase 3f: p64-from-int -- Int -> Posit64
    [(expr-p64-from-int (expr-int v))
     (expr-posit64 (posit64-encode v))]
    [(expr-p64-from-int a) (reduce-int-unary expr-p64-from-int a)]

    ;; p64-if-nar: branch when val is a literal
    [(expr-p64-if-nar _ nc _ (expr-posit64 9223372036854775808)) (whnf nc)]    ; NaR = 0x8000000000000000
    [(expr-p64-if-nar _ _ vc (expr-posit64 _)) (whnf vc)]                      ; any non-NaR literal

    ;; ---- Posit64 stuck-term reduction ----

    ;; Binary ops: reduce operands
    [(expr-p64-add a b) (reduce-posit-binary 64 expr-p64-add a b)]
    [(expr-p64-sub a b) (reduce-posit-binary 64 expr-p64-sub a b)]
    [(expr-p64-mul a b) (reduce-posit-binary 64 expr-p64-mul a b)]
    [(expr-p64-div a b) (reduce-posit-binary 64 expr-p64-div a b)]
    [(expr-p64-lt a b) (reduce-posit-binary 64 expr-p64-lt a b)]
    [(expr-p64-le a b) (reduce-posit-binary 64 expr-p64-le a b)]
    [(expr-p64-eq a b) (reduce-posit-binary 64 expr-p64-eq a b)]

    ;; Unary ops: reduce operand
    [(expr-p64-neg a) (reduce-posit-unary 64 expr-p64-neg a)]
    [(expr-p64-abs a) (reduce-posit-unary 64 expr-p64-abs a)]
    [(expr-p64-sqrt a) (reduce-posit-unary 64 expr-p64-sqrt a)]

    ;; p64-if-nar: reduce the value argument
    [(expr-p64-if-nar t nc vc v)
     (let ([v* (whnf v)])
       (if (equal? v* v) e (whnf (expr-p64-if-nar t nc vc v*))))]

    ;; ---- Quire iota rules ----
    ;; quireW-fma on literals: accumulate exact product
    [(expr-quire8-fma (expr-quire8-val q) (expr-posit8 a) (expr-posit8 b))
     (expr-quire8-val (quire8-fma q a b))]
    [(expr-quire16-fma (expr-quire16-val q) (expr-posit16 a) (expr-posit16 b))
     (expr-quire16-val (quire16-fma q a b))]
    [(expr-quire32-fma (expr-quire32-val q) (expr-posit32 a) (expr-posit32 b))
     (expr-quire32-val (quire32-fma q a b))]
    [(expr-quire64-fma (expr-quire64-val q) (expr-posit64 a) (expr-posit64 b))
     (expr-quire64-val (quire64-fma q a b))]

    ;; quireW-to on literals: convert accumulator to posit
    [(expr-quire8-to (expr-quire8-val q)) (expr-posit8 (quire8-to q))]
    [(expr-quire16-to (expr-quire16-val q)) (expr-posit16 (quire16-to q))]
    [(expr-quire32-to (expr-quire32-val q)) (expr-posit32 (quire32-to q))]
    [(expr-quire64-to (expr-quire64-val q)) (expr-posit64 (quire64-to q))]

    ;; ---- Quire stuck-term reduction ----
    ;; fma: try reducing q, then a, then b
    [(expr-quire8-fma q a b)
     (let ([q* (whnf q)])
       (if (equal? q* q)
           (let ([a* (whnf a)])
             (if (equal? a* a)
                 (let ([b* (whnf b)])
                   (if (equal? b* b) e (whnf (expr-quire8-fma q a b*))))
                 (whnf (expr-quire8-fma q a* b))))
           (whnf (expr-quire8-fma q* a b))))]
    ;; Phase 3e: quire16/32/64 FMA — coerce posit operands a, b (not quire accumulator q)
    [(expr-quire16-fma q a b)
     (let* ([q* (whnf q)] [a* (whnf a)] [b* (whnf b)]
            [ca (or (try-coerce-to-posit 16 a*) a*)]
            [cb (or (try-coerce-to-posit 16 b*) b*)])
       (cond
         [(or (not (eq? ca a*)) (not (eq? cb b*)))
          (whnf (expr-quire16-fma q* ca cb))]
         [(not (equal? q* q)) (whnf (expr-quire16-fma q* a b))]
         [(not (equal? a* a)) (whnf (expr-quire16-fma q a* b))]
         [(not (equal? b* b)) (whnf (expr-quire16-fma q a b*))]
         [else e]))]
    [(expr-quire32-fma q a b)
     (let* ([q* (whnf q)] [a* (whnf a)] [b* (whnf b)]
            [ca (or (try-coerce-to-posit 32 a*) a*)]
            [cb (or (try-coerce-to-posit 32 b*) b*)])
       (cond
         [(or (not (eq? ca a*)) (not (eq? cb b*)))
          (whnf (expr-quire32-fma q* ca cb))]
         [(not (equal? q* q)) (whnf (expr-quire32-fma q* a b))]
         [(not (equal? a* a)) (whnf (expr-quire32-fma q a* b))]
         [(not (equal? b* b)) (whnf (expr-quire32-fma q a b*))]
         [else e]))]
    [(expr-quire64-fma q a b)
     (let* ([q* (whnf q)] [a* (whnf a)] [b* (whnf b)]
            [ca (or (try-coerce-to-posit 64 a*) a*)]
            [cb (or (try-coerce-to-posit 64 b*) b*)])
       (cond
         [(or (not (eq? ca a*)) (not (eq? cb b*)))
          (whnf (expr-quire64-fma q* ca cb))]
         [(not (equal? q* q)) (whnf (expr-quire64-fma q* a b))]
         [(not (equal? a* a)) (whnf (expr-quire64-fma q a* b))]
         [(not (equal? b* b)) (whnf (expr-quire64-fma q a b*))]
         [else e]))]
    ;; to: try reducing q
    [(expr-quire8-to q)
     (let ([q* (whnf q)]) (if (equal? q* q) e (whnf (expr-quire8-to q*))))]
    [(expr-quire16-to q)
     (let ([q* (whnf q)]) (if (equal? q* q) e (whnf (expr-quire16-to q*))))]
    [(expr-quire32-to q)
     (let ([q* (whnf q)]) (if (equal? q* q) e (whnf (expr-quire32-to q*))))]
    [(expr-quire64-to q)
     (let ([q* (whnf q)]) (if (equal? q* q) e (whnf (expr-quire64-to q*))))]

    ;; ---- Generic arithmetic iota rules ----
    ;; Dispatch on concrete operand types at reduction time.

    ;; generic-add: compute when both operands are same-type literals
    [(expr-generic-add (expr-int a) (expr-int b)) (expr-int (+ a b))]
    [(expr-generic-add (expr-rat a) (expr-rat b)) (expr-rat (+ a b))]
    [(expr-generic-add (expr-posit8 a) (expr-posit8 b)) (expr-posit8 (posit8-add a b))]
    [(expr-generic-add (expr-posit16 a) (expr-posit16 b)) (expr-posit16 (posit16-add a b))]
    [(expr-generic-add (expr-posit32 a) (expr-posit32 b)) (expr-posit32 (posit32-add a b))]
    [(expr-generic-add (expr-posit64 a) (expr-posit64 b)) (expr-posit64 (posit64-add a b))]

    ;; generic-sub
    [(expr-generic-sub (expr-int a) (expr-int b)) (expr-int (- a b))]
    [(expr-generic-sub (expr-rat a) (expr-rat b)) (expr-rat (- a b))]
    [(expr-generic-sub (expr-posit8 a) (expr-posit8 b)) (expr-posit8 (posit8-sub a b))]
    [(expr-generic-sub (expr-posit16 a) (expr-posit16 b)) (expr-posit16 (posit16-sub a b))]
    [(expr-generic-sub (expr-posit32 a) (expr-posit32 b)) (expr-posit32 (posit32-sub a b))]
    [(expr-generic-sub (expr-posit64 a) (expr-posit64 b)) (expr-posit64 (posit64-sub a b))]

    ;; generic-mul
    [(expr-generic-mul (expr-int a) (expr-int b)) (expr-int (* a b))]
    [(expr-generic-mul (expr-rat a) (expr-rat b)) (expr-rat (* a b))]
    [(expr-generic-mul (expr-posit8 a) (expr-posit8 b)) (expr-posit8 (posit8-mul a b))]
    [(expr-generic-mul (expr-posit16 a) (expr-posit16 b)) (expr-posit16 (posit16-mul a b))]
    [(expr-generic-mul (expr-posit32 a) (expr-posit32 b)) (expr-posit32 (posit32-mul a b))]
    [(expr-generic-mul (expr-posit64 a) (expr-posit64 b)) (expr-posit64 (posit64-mul a b))]

    ;; generic-div (no Nat — Nat excluded at type level)
    [(expr-generic-div (expr-int a) (expr-int b))
     (if (zero? b) e (expr-int (quotient a b)))]
    [(expr-generic-div (expr-rat a) (expr-rat b))
     (if (zero? b) e (expr-rat (/ a b)))]
    [(expr-generic-div (expr-posit8 a) (expr-posit8 b)) (expr-posit8 (posit8-div a b))]
    [(expr-generic-div (expr-posit16 a) (expr-posit16 b)) (expr-posit16 (posit16-div a b))]
    [(expr-generic-div (expr-posit32 a) (expr-posit32 b)) (expr-posit32 (posit32-div a b))]
    [(expr-generic-div (expr-posit64 a) (expr-posit64 b)) (expr-posit64 (posit64-div a b))]

    ;; generic-lt
    [(expr-generic-lt (expr-int a) (expr-int b))
     (if (< a b) (expr-true) (expr-false))]
    [(expr-generic-lt (expr-rat a) (expr-rat b))
     (if (< a b) (expr-true) (expr-false))]
    [(expr-generic-lt (expr-posit8 a) (expr-posit8 b))
     (if (posit8-lt? a b) (expr-true) (expr-false))]
    [(expr-generic-lt (expr-posit16 a) (expr-posit16 b))
     (if (posit16-lt? a b) (expr-true) (expr-false))]
    [(expr-generic-lt (expr-posit32 a) (expr-posit32 b))
     (if (posit32-lt? a b) (expr-true) (expr-false))]
    [(expr-generic-lt (expr-posit64 a) (expr-posit64 b))
     (if (posit64-lt? a b) (expr-true) (expr-false))]

    ;; generic-le
    [(expr-generic-le (expr-int a) (expr-int b))
     (if (<= a b) (expr-true) (expr-false))]
    [(expr-generic-le (expr-rat a) (expr-rat b))
     (if (<= a b) (expr-true) (expr-false))]
    [(expr-generic-le (expr-posit8 a) (expr-posit8 b))
     (if (posit8-le? a b) (expr-true) (expr-false))]
    [(expr-generic-le (expr-posit16 a) (expr-posit16 b))
     (if (posit16-le? a b) (expr-true) (expr-false))]
    [(expr-generic-le (expr-posit32 a) (expr-posit32 b))
     (if (posit32-le? a b) (expr-true) (expr-false))]
    [(expr-generic-le (expr-posit64 a) (expr-posit64 b))
     (if (posit64-le? a b) (expr-true) (expr-false))]

    ;; generic-gt (swap operands for posit — no dedicated gt? predicate)
    [(expr-generic-gt (expr-int a) (expr-int b))
     (if (> a b) (expr-true) (expr-false))]
    [(expr-generic-gt (expr-rat a) (expr-rat b))
     (if (> a b) (expr-true) (expr-false))]
    [(expr-generic-gt (expr-posit8 a) (expr-posit8 b))
     (if (posit8-lt? b a) (expr-true) (expr-false))]
    [(expr-generic-gt (expr-posit16 a) (expr-posit16 b))
     (if (posit16-lt? b a) (expr-true) (expr-false))]
    [(expr-generic-gt (expr-posit32 a) (expr-posit32 b))
     (if (posit32-lt? b a) (expr-true) (expr-false))]
    [(expr-generic-gt (expr-posit64 a) (expr-posit64 b))
     (if (posit64-lt? b a) (expr-true) (expr-false))]

    ;; generic-ge (swap operands for posit)
    [(expr-generic-ge (expr-int a) (expr-int b))
     (if (>= a b) (expr-true) (expr-false))]
    [(expr-generic-ge (expr-rat a) (expr-rat b))
     (if (>= a b) (expr-true) (expr-false))]
    [(expr-generic-ge (expr-posit8 a) (expr-posit8 b))
     (if (posit8-le? b a) (expr-true) (expr-false))]
    [(expr-generic-ge (expr-posit16 a) (expr-posit16 b))
     (if (posit16-le? b a) (expr-true) (expr-false))]
    [(expr-generic-ge (expr-posit32 a) (expr-posit32 b))
     (if (posit32-le? b a) (expr-true) (expr-false))]
    [(expr-generic-ge (expr-posit64 a) (expr-posit64 b))
     (if (posit64-le? b a) (expr-true) (expr-false))]

    ;; generic-eq
    [(expr-generic-eq (expr-int a) (expr-int b))
     (if (= a b) (expr-true) (expr-false))]
    [(expr-generic-eq (expr-rat a) (expr-rat b))
     (if (= a b) (expr-true) (expr-false))]
    [(expr-generic-eq (expr-posit8 a) (expr-posit8 b))
     (if (posit8-eq? a b) (expr-true) (expr-false))]
    [(expr-generic-eq (expr-posit16 a) (expr-posit16 b))
     (if (posit16-eq? a b) (expr-true) (expr-false))]
    [(expr-generic-eq (expr-posit32 a) (expr-posit32 b))
     (if (posit32-eq? a b) (expr-true) (expr-false))]
    [(expr-generic-eq (expr-posit64 a) (expr-posit64 b))
     (if (posit64-eq? a b) (expr-true) (expr-false))]

    ;; generic-mod (no Posit — modulo not meaningful for approximate types)
    [(expr-generic-mod (expr-int a) (expr-int b))
     (if (zero? b) e (expr-int (remainder a b)))]
    ;; Rat mod: skip — Racket's remainder requires integer args

    ;; generic-negate (no Nat — excluded at type level)
    [(expr-generic-negate (expr-int a)) (expr-int (- a))]
    [(expr-generic-negate (expr-rat a)) (expr-rat (- a))]
    [(expr-generic-negate (expr-posit8 a)) (expr-posit8 (posit8-neg a))]
    [(expr-generic-negate (expr-posit16 a)) (expr-posit16 (posit16-neg a))]
    [(expr-generic-negate (expr-posit32 a)) (expr-posit32 (posit32-neg a))]
    [(expr-generic-negate (expr-posit64 a)) (expr-posit64 (posit64-neg a))]

    ;; generic-abs
    [(expr-generic-abs (expr-int a)) (expr-int (abs a))]
    [(expr-generic-abs (expr-rat a)) (expr-rat (abs a))]
    [(expr-generic-abs (expr-posit8 a)) (expr-posit8 (posit8-abs a))]
    [(expr-generic-abs (expr-posit16 a)) (expr-posit16 (posit16-abs a))]
    [(expr-generic-abs (expr-posit32 a)) (expr-posit32 (posit32-abs a))]
    [(expr-generic-abs (expr-posit64 a)) (expr-posit64 (posit64-abs a))]

    ;; ---- Float same-type generic arith (Numerics N3d) ----
    [(expr-generic-add (expr-float32 a) (expr-float32 b)) (expr-float32 (float32-add a b))]
    [(expr-generic-add (expr-float64 a) (expr-float64 b)) (expr-float64 (float64-add a b))]
    [(expr-generic-sub (expr-float32 a) (expr-float32 b)) (expr-float32 (float32-sub a b))]
    [(expr-generic-sub (expr-float64 a) (expr-float64 b)) (expr-float64 (float64-sub a b))]
    [(expr-generic-mul (expr-float32 a) (expr-float32 b)) (expr-float32 (float32-mul a b))]
    [(expr-generic-mul (expr-float64 a) (expr-float64 b)) (expr-float64 (float64-mul a b))]
    [(expr-generic-div (expr-float32 a) (expr-float32 b)) (expr-float32 (float32-div a b))]
    [(expr-generic-div (expr-float64 a) (expr-float64 b)) (expr-float64 (float64-div a b))]
    [(expr-generic-lt (expr-float32 a) (expr-float32 b)) (if (float32-lt? a b) (expr-true) (expr-false))]
    [(expr-generic-lt (expr-float64 a) (expr-float64 b)) (if (float64-lt? a b) (expr-true) (expr-false))]
    [(expr-generic-le (expr-float32 a) (expr-float32 b)) (if (float32-le? a b) (expr-true) (expr-false))]
    [(expr-generic-le (expr-float64 a) (expr-float64 b)) (if (float64-le? a b) (expr-true) (expr-false))]
    [(expr-generic-gt (expr-float32 a) (expr-float32 b)) (if (float32-lt? b a) (expr-true) (expr-false))]
    [(expr-generic-gt (expr-float64 a) (expr-float64 b)) (if (float64-lt? b a) (expr-true) (expr-false))]
    [(expr-generic-ge (expr-float32 a) (expr-float32 b)) (if (float32-le? b a) (expr-true) (expr-false))]
    [(expr-generic-ge (expr-float64 a) (expr-float64 b)) (if (float64-le? b a) (expr-true) (expr-false))]
    [(expr-generic-eq (expr-float32 a) (expr-float32 b)) (if (float32-eq? a b) (expr-true) (expr-false))]
    [(expr-generic-eq (expr-float64 a) (expr-float64 b)) (if (float64-eq? a b) (expr-true) (expr-false))]
    [(expr-generic-negate (expr-float32 a)) (expr-float32 (float32-neg a))]
    [(expr-generic-negate (expr-float64 a)) (expr-float64 (float64-neg a))]
    [(expr-generic-abs (expr-float32 a)) (expr-float32 (float32-abs a))]
    [(expr-generic-abs (expr-float64 a)) (expr-float64 (float64-abs a))]

    ;; generic-from-int: Int -> TargetType conversion based on target type
    [(expr-generic-from-int (expr-Int) (expr-int v))  (expr-int v)]             ; identity
    [(expr-generic-from-int (expr-Rat) (expr-int v))  (expr-rat v)]             ; Int -> Rat
    [(expr-generic-from-int (expr-Posit8) (expr-int v))  (expr-posit8 (posit8-encode v))]
    [(expr-generic-from-int (expr-Posit16) (expr-int v)) (expr-posit16 (posit16-encode v))]
    [(expr-generic-from-int (expr-Posit32) (expr-int v)) (expr-posit32 (posit32-encode v))]
    [(expr-generic-from-int (expr-Posit64) (expr-int v)) (expr-posit64 (posit64-encode v))]
    [(expr-generic-from-int (expr-Float32) (expr-int v)) (expr-float32 (flsingle (exact->inexact v)))]  ; Int -> Float32 (N3e)
    [(expr-generic-from-int (expr-Float64) (expr-int v)) (expr-float64 (exact->inexact v))]              ; Int -> Float64 (N3e)

    ;; generic-from-rat: Rat -> TargetType conversion based on target type
    [(expr-generic-from-rat (expr-Rat) (expr-rat v))  (expr-rat v)]             ; identity
    [(expr-generic-from-rat (expr-Posit8) (expr-rat v))  (expr-posit8 (posit8-encode v))]
    [(expr-generic-from-rat (expr-Posit16) (expr-rat v)) (expr-posit16 (posit16-encode v))]
    [(expr-generic-from-rat (expr-Posit32) (expr-rat v)) (expr-posit32 (posit32-encode v))]
    [(expr-generic-from-rat (expr-Posit64) (expr-rat v)) (expr-posit64 (posit64-encode v))]
    [(expr-generic-from-rat (expr-Float32) (expr-rat v)) (expr-float32 (flsingle (exact->inexact v)))]  ; Rat -> Float32 (N3e, DEMO-P1)
    [(expr-generic-from-rat (expr-Float64) (expr-rat v)) (expr-float64 (exact->inexact v))]              ; Rat -> Float64 (N3e, DEMO-P1)

    ;; ---- Generic arithmetic stuck-term reduction ----
    ;; Binary ops: reduce operands
    [(expr-generic-add a b) (reduce-generic-binary expr-generic-add a b)]
    [(expr-generic-sub a b) (reduce-generic-binary expr-generic-sub a b)]
    [(expr-generic-mul a b) (reduce-generic-binary expr-generic-mul a b)]
    [(expr-generic-div a b) (reduce-generic-binary expr-generic-div a b)]
    [(expr-generic-lt a b) (reduce-generic-binary expr-generic-lt a b)]
    [(expr-generic-le a b) (reduce-generic-binary expr-generic-le a b)]
    [(expr-generic-gt a b) (reduce-generic-binary expr-generic-gt a b)]
    [(expr-generic-ge a b) (reduce-generic-binary expr-generic-ge a b)]
    [(expr-generic-eq a b) (reduce-generic-binary expr-generic-eq a b)]
    [(expr-generic-mod a b) (reduce-generic-binary expr-generic-mod a b)]
    ;; Unary ops: reduce operand
    [(expr-generic-negate a) (reduce-generic-unary expr-generic-negate a)]
    [(expr-generic-abs a) (reduce-generic-unary expr-generic-abs a)]
    ;; Generic conversion stuck-term: reduce arg, retry
    [(expr-generic-from-int t a)
     (let ([a* (whnf a)])
       (if (equal? a* a) e (whnf (expr-generic-from-int t a*))))]
    [(expr-generic-from-rat t a)
     (let ([a* (whnf a)])
       (if (equal? a* a) e (whnf (expr-generic-from-rat t a*))))]

    ;; Symbol — no reduction (atoms are values)
    ;; (no clauses needed for expr-Symbol or expr-symbol — they're values)

    ;; Keyword — no reduction (atoms are values)
    ;; (no clauses needed for expr-Keyword or expr-keyword — they're values)

    ;; ---- Map iota rules: compute when arguments are champ values ----
    ;; map-empty reduces to champ(champ-empty) — the runtime representation
    [(expr-map-empty _ _) (expr-champ champ-empty)]

    [(expr-map-assoc (expr-champ c) k v)
     (let ([k* (whnf k)] [v* (whnf v)])
       (expr-champ (champ-insert c (equal-hash-code k*) k* v*)))]
    ;; CIU T6 P2.b slice 4: THE FORK. The champ miss arm is type-blind (rows
    ;; and dicts share the champ), so the tier decision arrives MATERIALIZED in
    ;; the strictness slot: (expr-true) = typing proved the subject (Map K V)
    ;; on the user's direct projection → the miss is a LOUD panic naming the
    ;; key and the available keys (the closed-row diagnostic's quality bar).
    ;; Anything else (#f raw/lowered/dynamic-tier · an unsolved meta · dyn-row
    ;; subjects, whose slot typing never solves) → the permissive (expr-error),
    ;; exactly today's shape (D19 pins: route-soundness B1/B2, records ;;77).
    [(expr-map-get (expr-champ c) k a)
     (let ([k* (whnf k)])
       (let ([result (champ-lookup c (equal-hash-code k*) k*)])
         (cond
           [(not (eq? result 'none)) (whnf result)]
           [(expr-true? a)
            ;; D4.P4b-ii-2b (the verify, M1): this now CALLS the shared helper
            ;; instead of inlining a second copy. The extraction's comment
            ;; claimed "ONE definition and two consumers" while map-get still
            ;; had its own — so the anti-drift property was asserted, not
            ;; established. Now it is established.
            (expr-panic (expr-string (assertive-miss-message "map-get" k* c)))]
           [else (expr-error)])))]

    ;; CIU T6 P2.b (SITE 7): a PVec/tuple subject PROJECTS by position.
    ;; The typing side already does this — `record-project`'s nat-literal arm
    ;; returns the position's exact field type — but the VALUE side had no arm
    ;; at all, so it fell through to the stuck-term degradation and fabricated
    ;; `none` at that correctly-projected type. Delegating to `expr-get` (rather
    ;; than re-implementing rrb indexing here) is the point: map-get and get now
    ;; agree BY CONSTRUCTION on the same carrier, which is exactly the
    ;; divergence site 7 was. `expr-get`'s arm already handles the Nat-or-Int
    ;; key gate and out-of-bounds.
    [(expr-map-get (? expr-rrb? v) k a) (whnf (expr-get v k a))]

    ;; CIU T6 D4.P3a: the select-block redex (Q_T1 Route A).
    ;; The subject is evaluated ONCE — subj* is computed a single time and
    ;; reused across every branch (the design's no-let/fn obligation).
    ;; Typing (select-project, Q_T2 Horn D) guaranteed every selected field is
    ;; sourced-'present, and the parser guaranteed duplicate-free branches —
    ;; so a runtime miss here is an INVARIANT VIOLATION and panics loudly
    ;; (never fabricate), and champ-insert is never asked to last-win.
    ;; Stuck subject → the node stays stuck (the map-get/validate precedent).
    [(expr-select subject (expr-path branches sort) tier)
     (let ([subj* (whnf subject)])
       (cond
         ;; D4.P3c: rrb subjects admitted — ordinal branches select over
         ;; vectors/tuples (`het{2 0}`); per-branch dispatch inside.
         [(or (expr-champ? subj*) (expr-rrb? subj*)) (select-reduce subj* branches sort tier)]
         ;; D4.P3a verify hardening: a GROUND non-map subject can never
         ;; become a champ — panic per the node's own tier discipline
         ;; (the nested descent one level down is already loud; only the
         ;; top level silently stuck). Stuck NEUTRALS still fall through.
         ;; ⭐ D4.P4b-ii-2b, THE VERIFY'S BLOCKING FIND (two skeptics, independently,
         ;; by A/B against a baseline tree). This arm is the SUBJECT-kind
         ;; sibling of the keyed-miss fork below, and the first cut tier-gated
         ;; only the miss — so a `.field` on a union whose runtime value is a
         ;; non-map component PANICKED where `[map-get u :a]` degrades to
         ;; `none` at ZERO errors (reduction's own comment on that arm names
         ;; this exact scenario: "map-get on an Int from a mixed-type union").
         ;; That is the permissive→panic conversion this whole slice exists to
         ;; prevent, one arm above where I looked.
         ;;
         ;; The tier decides it, exactly as it decides the miss:
         ;;   tier = #f  — the BLOCK sort. P3a's hardening stands: typing
         ;;                admitted the block, so a non-map subject IS an
         ;;                invariant violation and the panic is honest.
         ;;   otherwise  — the PATH sort. Match `map-get`: degrade to `none`.
         ;;                An ASSERTIVE path tier cannot reach here (typing
         ;;                proved a Map, so the value cannot be a non-map), so
         ;;                no arm is owed for it — and inventing one would be
         ;;                the speculative-scaffolding shape.
         [(definitely-not-map? subj*)
          (if tier
              (expr-fvar 'none)
              (expr-panic
               (expr-string
                "select: the subject is not a map at runtime (invariant violation — typing admitted the block)")))]
         [(equal? subj* subject) e]
         ;; D4.P4b-ii-1: the re-construction must PRESERVE the sort — dropping
         ;; it here would silently re-sort a `'path` selector as a `'block`
         ;; one on any subject that takes a whnf step (the R6 constructor
         ;; hazard's runtime half: this call compiles clean either way).
         [else (whnf (expr-select subj* (expr-path branches sort) tier))]))]

    ;; CIU T6 F1b.5-s2 (D27): validate — the runtime tabulation redex.
    ;; Subject whnf's to exactly two classes (spines/map-empty collapse to
    ;; champs): champ → tabulate; stuck → the node stays stuck (the map-get
    ;; [else e] precedent; safe at top level, pp arm renders it).
    [(expr-validate sname closed? plan subject names)
     (let ([subj* (whnf subject)])
       (cond
         [(expr-champ? subj*) (validate-tabulate sname closed? plan subj* names)]
         [(equal? subj* subject) e]
         [else (whnf (expr-validate sname closed? plan subj* names))]))]
    ;; Generic get: dispatch by collection type
    [(expr-get coll key sa)
     (let ([c* (whnf coll)])
       ;; Extract numeric index from Nat or Int key
       (define (index-value k)
         (or (nat-value k)
             (and (expr-int? k) (let ([v (expr-int-val k)]) (and (>= v 0) v)))))
       (match c*
         ;; Map (CHAMP) → delegate to map-get (the strictness slot RIDES the
         ;; delegation — a one-node slot would be dropped exactly here)
         [(expr-champ _) (whnf (expr-map-get c* (whnf key) sa))]
         ;; PVec (RRB) → index by nat/int
         ;; CIU T6 P2.b slice 2: OOB is a LOUD assertive-tier error (was a
         ;; silent `(expr-error)` behind a with-handlers). The explicit bounds
         ;; check replaces the handler — index-value guarantees n ≥ 0, so an
         ;; in-bounds rrb-get cannot range-fail; anything else raising there
         ;; would be a real invariant violation that must not be swallowed.
         ;; A non-literal index still exits STUCK (the arm below), which is
         ;; what keeps guarded/honest-tier reads insulated.
         [(expr-rrb r)
          (let* ([k* (whnf key)]
                 [n (index-value k*)])
            (cond
              [(not n) (expr-get c* k* sa)]
              [(< n (rrb-size r)) (whnf (rrb-get r n))]
              [else (expr-panic
                     (expr-string
                      (format "get: index ~a out of bounds for PVec of length ~a"
                              n (rrb-size r))))]))]
         ;; List (cons chain) → walk to nth
         ;; CIU T6 P2.b slice 3: the SPLIT. This arm CONFLATED "index is not a
         ;; literal" with "out of bounds" — both fell to one `(expr-error)`.
         ;; The non-literal half was a LIVE bug: nf descends under binders, so
         ;; a lambda body `[get xs i]` (i a bvar) was destroyed to `<error>`
         ;; in the DISPLAY while the stored whnf value stayed intact — a
         ;; silent lie about the value. Non-literal now stays STUCK (mirroring
         ;; the rrb arm above); true OOB joins the assertive tier, LOUD.
         [_
          (let ([elems (prologos-list->racket-list c*)])
            (if elems
                (let* ([k* (whnf key)]
                       [n (index-value k*)])
                  (cond
                    [(not n) (expr-get c* k* sa)]
                    [(< n (length elems)) (whnf (list-ref elems n))]
                    [else (expr-panic
                           (expr-string
                            (format "get: index ~a out of bounds for List of length ~a"
                                    n (length elems))))]))
                ;; Not yet reduced → try reducing
                (if (not (equal? c* coll))
                    (whnf (expr-get c* key sa))
                    (expr-get c* key sa))))]))]
    ;; nil?: nil → true, ground non-nil value → false
    [(expr-nil-check (? expr-nil?)) (expr-true)]
    [(expr-nil-check a)
     (let ([a* (whnf a)])
       (cond
         [(expr-nil? a*) (expr-true)]
         ;; Ground values that are definitely not nil → false
         [(or (expr-true? a*) (expr-false? a*) (expr-unit? a*)
              (expr-zero? a*) (expr-suc? a*) (expr-nat-val? a*) (expr-int? a*) (expr-rat? a*)
              (expr-string? a*) (expr-keyword? a*) (expr-char? a*)
              (expr-champ? a*) (expr-hset? a*) (expr-rrb? a*)
              (expr-posit8? a*) (expr-posit16? a*) (expr-posit32? a*)
              (expr-posit64? a*) (expr-pair? a*) (expr-fvar? a*))
          (expr-false)]
         [(not (equal? a* a)) (whnf (expr-nil-check a*))]
         [else e]))]

    ;; nil-safe-get: nil input → nil, champ lookup → value or nil on miss
    [(expr-nil-safe-get (? expr-nil?) _) (expr-nil)]
    [(expr-nil-safe-get (expr-champ c) k)
     (let ([k* (whnf k)])
       (let ([result (champ-lookup c (equal-hash-code k*) k*)])
         (if (eq? result 'none)
             (expr-nil)
             (whnf result))))]
    [(expr-map-dissoc (expr-champ c) k)
     (let ([k* (whnf k)])
       (expr-champ (champ-delete c (equal-hash-code k*) k*)))]
    [(expr-map-size (expr-champ c))
     (nat->expr (champ-size c))]
    [(expr-map-has-key (expr-champ c) k)
     (let ([k* (whnf k)])
       (if (champ-has-key? c (equal-hash-code k*) k*)
           (expr-true)
           (expr-false)))]
    [(expr-map-keys (expr-champ c))
     (racket-list->prologos-list (champ-keys c))]
    [(expr-map-vals (expr-champ c))
     (racket-list->prologos-list (champ-vals c))]

    ;; ---- PVec iota rules ----
    [(expr-pvec-empty _) (expr-rrb rrb-empty)]

    [(expr-pvec-push (expr-rrb r) x)
     (let ([x* (whnf x)])
       (expr-rrb (rrb-push r x*)))]

    ;; CIU T6 P2.b slice 2: OOB is a LOUD assertive-tier error. This was THE
    ;; DIVERGENT leg — it returned the stuck term `e` where expr-get's rrb arm
    ;; returned `(expr-error)`: two different silences for one carrier. Both
    ;; now unify on the same panic shape. Non-literal index stays stuck.
    [(expr-pvec-nth (expr-rrb r) i)
     (let* ([i* (whnf i)]
            [n (nat-value i*)])
       (cond
         [(not n) e]
         [(< n (rrb-size r)) (whnf (rrb-get r n))]
         [else (expr-panic
                (expr-string
                 (format "pvec-nth: index ~a out of bounds for PVec of length ~a"
                         n (rrb-size r))))]))]

    [(expr-pvec-update (expr-rrb r) i x)
     (let* ([i* (whnf i)]
            [n (nat-value i*)]
            [x* (whnf x)])
       (if n
           (with-handlers ([exn:fail? (lambda (_) e)])
             (expr-rrb (rrb-set r n x*)))
           e))]

    [(expr-pvec-length (expr-rrb r))
     (nat->expr (rrb-size r))]

    [(expr-pvec-to-list (expr-rrb r))
     (racket-list->prologos-list (rrb-to-list r))]

    [(expr-pvec-from-list v)
     (let ([elems (prologos-list->racket-list v)])
       (if elems
           (expr-rrb (rrb-from-list elems))
           ;; try reducing v first
           (let ([v* (whnf v)])
             (if (equal? v* v) e (whnf (expr-pvec-from-list v*))))))]

    [(expr-pvec-pop (expr-rrb r))
     (with-handlers ([exn:fail? (lambda (_) e)])
       (expr-rrb (rrb-pop r)))]

    [(expr-pvec-concat (expr-rrb r1) (expr-rrb r2))
     (expr-rrb (rrb-concat r1 r2))]

    [(expr-pvec-slice (expr-rrb r) lo hi)
     (let* ([lo* (whnf lo)] [hi* (whnf hi)]
            [lo-n (nat-value lo*)] [hi-n (nat-value hi*)])
       (if (and lo-n hi-n)
           (expr-rrb (rrb-slice r lo-n hi-n))
           e))]

    ;; pvec-fold : left fold over RRB — f takes (accumulator, element)
    ;; rrb-fold passes (value, acc), so we call f(acc, elem)
    [(expr-pvec-fold f init (expr-rrb r))
     (let ([init* (whnf init)]
           [f* (whnf f)])
       (rrb-fold r
                 (lambda (elem acc)
                   (whnf (expr-app (expr-app f* acc) elem)))
                 init*))]

    ;; pvec-map : map over RRB via fold + transient push
    [(expr-pvec-map f (expr-rrb r))
     (let ([f* (whnf f)])
       (let ([t (rrb-transient rrb-empty)])
         (rrb-fold r
                   (lambda (elem _acc)
                     (trrb-push! t (whnf (expr-app f* elem))))
                   (void))
         (expr-rrb (trrb-freeze t))))]

    ;; pvec-filter : filter over RRB via fold + conditional transient push
    [(expr-pvec-filter pred (expr-rrb r))
     (let ([pred* (whnf pred)])
       (let ([t (rrb-transient rrb-empty)])
         (rrb-fold r
                   (lambda (elem _acc)
                     (let ([result (whnf (expr-app pred* elem))])
                       (when (expr-true? result)
                         (trrb-push! t elem))))
                   (void))
         (expr-rrb (trrb-freeze t))))]

    ;; set-fold : left fold over CHAMP set — f takes (accumulator, element)
    ;; champ-fold passes (key, #t, acc); for sets we ignore the value
    [(expr-set-fold f init (expr-hset c))
     (let ([init* (whnf init)]
           [f* (whnf f)])
       (champ-fold c
                   (lambda (k _v acc)
                     (whnf (expr-app (expr-app f* acc) k)))
                   init*))]

    ;; set-filter : filter over CHAMP set
    [(expr-set-filter pred (expr-hset c))
     (let ([pred* (whnf pred)])
       (let ([t (champ-transient champ-empty)])
         (champ-fold c
                     (lambda (k _v _acc)
                       (let ([result (whnf (expr-app pred* k))])
                         (when (expr-true? result)
                           (tchamp-insert! t (equal-hash-code k) k #t))))
                     (void))
         (expr-hset (tchamp-freeze t))))]

    ;; map-fold-entries : left fold over CHAMP map — f takes (accumulator, key, value)
    [(expr-map-fold-entries f init (expr-champ c))
     (let ([init* (whnf init)]
           [f* (whnf f)])
       (champ-fold c
                   (lambda (k v acc)
                     (whnf (expr-app (expr-app (expr-app f* acc) k) v)))
                   init*))]

    ;; map-filter-entries : filter map entries via fold + conditional insert
    [(expr-map-filter-entries pred (expr-champ c))
     (let ([pred* (whnf pred)])
       (let ([t (champ-transient champ-empty)])
         (champ-fold c
                     (lambda (k v _acc)
                       (let ([result (whnf (expr-app (expr-app pred* k) v))])
                         (when (expr-true? result)
                           (tchamp-insert! t (equal-hash-code k) k v))))
                     (void))
         (expr-champ (tchamp-freeze t))))]

    ;; map-map-vals : map values via fold + insert with new value
    [(expr-map-map-vals f (expr-champ c))
     (let ([f* (whnf f)])
       (let ([t (champ-transient champ-empty)])
         (champ-fold c
                     (lambda (k v _acc)
                       (tchamp-insert! t (equal-hash-code k) k (whnf (expr-app f* v))))
                     (void))
         (expr-champ (tchamp-freeze t))))]

    ;; ---- PVec stuck-term reduction ----
    ;; CIU T6 F1a-col: literal-extent node lowers to the push chain (runtime identical).
    ;; The seed's elem-type slot is reduction-ignored (see the pvec-empty arm above).
    [(expr-pvec-literal elems)
     (whnf (for/fold ([acc (expr-pvec-empty (expr-hole))]) ([el (in-list elems)])
             (expr-pvec-push acc el)))]
    ;; CIU T6 F1a-col-2: the list literal's runtime IS its elaborated cons chain.
    [(expr-list-literal _ chain) (whnf chain)]
    [(expr-map-literal _ _ chain) (whnf chain)]
    [(expr-pvec-push v x)
     (let ([v* (whnf v)])
       (if (equal? v* v) e (whnf (expr-pvec-push v* x))))]
    [(expr-pvec-nth v i)
     (let ([v* (whnf v)])
       (if (equal? v* v) e (whnf (expr-pvec-nth v* i))))]
    [(expr-pvec-update v i x)
     (let ([v* (whnf v)])
       (if (equal? v* v) e (whnf (expr-pvec-update v* i x))))]
    [(expr-pvec-length v)
     (let ([v* (whnf v)])
       (if (equal? v* v) e (whnf (expr-pvec-length v*))))]
    [(expr-pvec-to-list v)
     (let ([v* (whnf v)])
       (if (equal? v* v) e (whnf (expr-pvec-to-list v*))))]
    [(expr-pvec-pop v)
     (let ([v* (whnf v)])
       (if (equal? v* v) e (whnf (expr-pvec-pop v*))))]
    [(expr-pvec-concat v1 v2)
     (let ([v1* (whnf v1)])
       (if (not (equal? v1* v1))
           (whnf (expr-pvec-concat v1* v2))
           (let ([v2* (whnf v2)])
             (if (not (equal? v2* v2))
                 (whnf (expr-pvec-concat v1 v2*))
                 e))))]
    [(expr-pvec-slice v lo hi)
     (let ([v* (whnf v)])
       (if (equal? v* v) e (whnf (expr-pvec-slice v* lo hi))))]
    [(expr-pvec-fold f init vec)
     (let ([vec* (whnf vec)])
       (if (equal? vec* vec) e (whnf (expr-pvec-fold f init vec*))))]
    [(expr-pvec-map f vec)
     (let ([vec* (whnf vec)])
       (if (equal? vec* vec) e (whnf (expr-pvec-map f vec*))))]
    [(expr-pvec-filter pred vec)
     (let ([vec* (whnf vec)])
       (if (equal? vec* vec) e (whnf (expr-pvec-filter pred vec*))))]
    [(expr-set-fold f init set)
     (let ([set* (whnf set)])
       (if (equal? set* set) e (whnf (expr-set-fold f init set*))))]
    [(expr-set-filter pred set)
     (let ([set* (whnf set)])
       (if (equal? set* set) e (whnf (expr-set-filter pred set*))))]
    [(expr-map-fold-entries f init map)
     (let ([map* (whnf map)])
       (if (equal? map* map) e (whnf (expr-map-fold-entries f init map*))))]
    [(expr-map-filter-entries pred map)
     (let ([map* (whnf map)])
       (if (equal? map* map) e (whnf (expr-map-filter-entries pred map*))))]
    [(expr-map-map-vals f map)
     (let ([map* (whnf map)])
       (if (equal? map* map) e (whnf (expr-map-map-vals f map*))))]

    ;; ---- Transient Builder iota rules ----
    ;; Generic transient: dispatch on underlying value
    [(expr-transient (expr-rrb r))
     (expr-trrb (rrb-transient r))]
    [(expr-transient (expr-champ c))
     (expr-tchamp (champ-transient c))]
    [(expr-transient (expr-hset c))
     (expr-thset (champ-transient c))]
    ;; Generic persist: dispatch on transient value
    [(expr-persist (expr-trrb t))
     (expr-rrb (trrb-freeze t))]
    [(expr-persist (expr-tchamp t))
     (expr-champ (tchamp-freeze t))]
    [(expr-persist (expr-thset t))
     (expr-hset (tchamp-freeze t))]
    ;; Generic stuck-term reduction
    [(expr-transient c)
     (let ([c* (whnf c)])
       (if (equal? c* c) e (whnf (expr-transient c*))))]
    [(expr-persist c)
     (let ([c* (whnf c)])
       (if (equal? c* c) e (whnf (expr-persist c*))))]
    ;; Vec: transient/persist (specific)
    [(expr-transient-vec (expr-rrb r))
     (expr-trrb (rrb-transient r))]
    [(expr-persist-vec (expr-trrb t))
     (expr-rrb (trrb-freeze t))]
    ;; Vec: mutation
    [(expr-tvec-push! (expr-trrb t) x)
     (let ([x* (whnf x)])
       (expr-trrb (trrb-push! t x*)))]
    [(expr-tvec-update! (expr-trrb t) i x)
     (let* ([i* (whnf i)]
            [n (nat-value i*)]
            [x* (whnf x)])
       (if n
           (with-handlers ([exn:fail? (lambda (_) e)])
             (expr-trrb (trrb-update! t n x*)))
           e))]
    ;; Map: transient/persist
    [(expr-transient-map (expr-champ c))
     (expr-tchamp (champ-transient c))]
    [(expr-persist-map (expr-tchamp t))
     (expr-champ (tchamp-freeze t))]
    ;; Map: mutation
    [(expr-tmap-assoc! (expr-tchamp t) k v)
     (let ([k* (nf k)] [v* (whnf v)])
       (expr-tchamp (tchamp-insert! t (equal-hash-code k*) k* v*)))]
    [(expr-tmap-dissoc! (expr-tchamp t) k)
     (let ([k* (nf k)])
       (expr-tchamp (tchamp-delete! t (equal-hash-code k*) k*)))]
    ;; Set: transient/persist (set uses tchamp with val=#t)
    [(expr-transient-set (expr-hset c))
     (expr-thset (champ-transient c))]
    [(expr-persist-set (expr-thset t))
     (expr-hset (tchamp-freeze t))]
    ;; Set: mutation
    [(expr-tset-insert! (expr-thset t) a)
     (let ([a* (nf a)])
       (expr-thset (tchamp-insert! t (equal-hash-code a*) a* #t)))]
    [(expr-tset-delete! (expr-thset t) a)
     (let ([a* (nf a)])
       (expr-thset (tchamp-delete! t (equal-hash-code a*) a*)))]

    ;; ---- Transient Builder stuck-term reduction ----
    [(expr-transient-vec v)
     (let ([v* (whnf v)])
       (if (equal? v* v) e (whnf (expr-transient-vec v*))))]
    [(expr-persist-vec t)
     (let ([t* (whnf t)])
       (if (equal? t* t) e (whnf (expr-persist-vec t*))))]
    [(expr-tvec-push! t x)
     (let ([t* (whnf t)])
       (if (equal? t* t) e (whnf (expr-tvec-push! t* x))))]
    [(expr-tvec-update! t i x)
     (let ([t* (whnf t)])
       (if (equal? t* t) e (whnf (expr-tvec-update! t* i x))))]
    [(expr-transient-map m)
     (let ([m* (whnf m)])
       (if (equal? m* m) e (whnf (expr-transient-map m*))))]
    [(expr-persist-map t)
     (let ([t* (whnf t)])
       (if (equal? t* t) e (whnf (expr-persist-map t*))))]
    [(expr-tmap-assoc! t k v)
     (let ([t* (whnf t)])
       (if (equal? t* t) e (whnf (expr-tmap-assoc! t* k v))))]
    [(expr-tmap-dissoc! t k)
     (let ([t* (whnf t)])
       (if (equal? t* t) e (whnf (expr-tmap-dissoc! t* k))))]
    [(expr-transient-set s)
     (let ([s* (whnf s)])
       (if (equal? s* s) e (whnf (expr-transient-set s*))))]
    [(expr-persist-set t)
     (let ([t* (whnf t)])
       (if (equal? t* t) e (whnf (expr-persist-set t*))))]
    [(expr-tset-insert! t a)
     (let ([t* (whnf t)])
       (if (equal? t* t) e (whnf (expr-tset-insert! t* a))))]
    [(expr-tset-delete! t a)
     (let ([t* (whnf t)])
       (if (equal? t* t) e (whnf (expr-tset-delete! t* a))))]

    ;; ---- Map stuck-term reduction (try reducing subexpressions) ----
    [(expr-map-assoc m k v)
     (let ([m* (whnf m)])
       (if (equal? m* m) e (whnf (expr-map-assoc m* k v))))]
    [(expr-map-get m k a)
     (let ([m* (whnf m)])
       (cond
         [(not (equal? m* m)) (whnf (expr-map-get m* k a))]
         ;; If m* is a concrete non-map value, return none (graceful degradation).
         ;; This handles cases like map-get on an Int from a mixed-type union.
         [(definitely-not-map? m*) (expr-fvar 'none)]
         [else e]))]
    [(expr-nil-safe-get m k)
     (let ([m* (whnf m)])
       (cond
         [(expr-nil? m*) (expr-nil)]
         [(not (equal? m* m)) (whnf (expr-nil-safe-get m* k))]
         ;; If m* is a concrete non-map value, return nil (safe degradation)
         [(definitely-not-map? m*) (expr-nil)]
         [else e]))]
    [(expr-map-dissoc m k)
     (let ([m* (whnf m)])
       (if (equal? m* m) e (whnf (expr-map-dissoc m* k))))]
    ;; ---- Dynamic path ops (2026-07-16 P6 value-loss fix) ----
    ;; These previously reduced only in nf; with no whnf arm a dynamic
    ;; update-in/get-in result was whnf-stuck, and map-get's graceful
    ;; degradation silently converted it to none (see definitely-not-map?,
    ;; which now also exempts both nodes for the genuinely-stuck case).
    ;; Semantics mirror the nf arms at whnf strength.
    [(expr-get-in target paths)
     (let ([nt (whnf target)]
           [np (whnf paths)])
       (cond
         [(and (expr-path? np) (pair? (expr-path-branches np)))
          (foldl (lambda (seg acc) (whnf (expr-map-get acc (expr-keyword seg) #f)))
                 nt (car (expr-path-branches np)))]
         [(and (equal? nt target) (equal? np paths)) e]
         [else (expr-get-in nt np)]))]
    [(expr-update-in target paths fn)
     (let ([nt (whnf target)]
           [np (whnf paths)])
       (cond
         [(and (expr-path? np) (pair? (expr-path-branches np)))
          ;; F1b.3 (D24 guard): a ZERO-segment dynamic path would apply fn to
          ;; the WHOLE map (spine keys can vanish — P6), which the D24 typing
          ;; posture (labels stable, 'present) cannot cover. Host error, per
          ;; the path-ops empty-path precedent. (Inside build, null segs is
          ;; the legitimate recursion base — the guard is entry-only.)
          (when (null? (car (expr-path-branches np)))
            (error 'update-in "dynamic path has zero segments — an empty path would replace the entire map"))
          (let build ([base nt] [segs (car (expr-path-branches np))])
            (cond
              [(null? segs) (whnf (expr-app fn base))]
              [else
               (let* ([key (expr-keyword (car segs))]
                      [sub (whnf (expr-map-get base key #f))]
                      [updated (build sub (cdr segs))])
                 (whnf (expr-map-assoc base key updated)))]))]
         [(and (equal? nt target) (equal? np paths)) e]
         [else (expr-update-in nt np fn)]))]
    ;; expr-broadcast-get: RETIRED at CIU T6 D4.P1a (ruling Q_L3) — the P2.a
    ;; whnf arm that lived here is unwound with the node.
    [(expr-map-size m)
     (let ([m* (whnf m)])
       (if (equal? m* m) e (whnf (expr-map-size m*))))]
    [(expr-map-has-key m k)
     (let ([m* (whnf m)])
       (if (equal? m* m) e (whnf (expr-map-has-key m* k))))]
    [(expr-map-keys m)
     (let ([m* (whnf m)])
       (if (equal? m* m) e (whnf (expr-map-keys m*))))]
    [(expr-map-vals m)
     (let ([m* (whnf m)])
       (if (equal? m* m) e (whnf (expr-map-vals m*))))]

    ;; ---- Set iota rules: compute when arguments are hset (champ with #t sentinel) ----
    ;; set-empty reduces to hset(champ-empty) — the runtime representation
    [(expr-set-empty _) (expr-hset champ-empty)]

    [(expr-set-insert s a)
     (define s* (whnf s))
     (match s*
       [(expr-hset c)
        (define a* (nf a))
        (expr-hset (champ-insert c (equal-hash-code a*) a* #t))]
       [_ (expr-set-insert s* a)])]

    [(expr-set-member s a)
     (define s* (whnf s))
     (match s*
       [(expr-hset c)
        (define a* (nf a))
        (if (champ-has-key? c (equal-hash-code a*) a*)
            (expr-true)
            (expr-false))]
       [_ (expr-set-member s* a)])]

    [(expr-set-delete s a)
     (define s* (whnf s))
     (match s*
       [(expr-hset c)
        (define a* (nf a))
        (expr-hset (champ-delete c (equal-hash-code a*) a*))]
       [_ (expr-set-delete s* a)])]

    [(expr-set-size s)
     (define s* (whnf s))
     (match s*
       [(expr-hset c) (nat->expr (champ-size c))]
       [_ (expr-set-size s*)])]

    [(expr-set-union s1 s2)
     (define s1* (whnf s1))
     (define s2* (whnf s2))
     (match (list s1* s2*)
       [(list (expr-hset c1) (expr-hset c2))
        (expr-hset (champ-fold c2 (lambda (k _v acc) (champ-insert acc (equal-hash-code k) k #t)) c1))]
       [_ (expr-set-union s1* s2*)])]

    [(expr-set-intersect s1 s2)
     (define s1* (whnf s1))
     (define s2* (whnf s2))
     (match (list s1* s2*)
       [(list (expr-hset c1) (expr-hset c2))
        (expr-hset (champ-fold c1
                     (lambda (k _v acc)
                       (if (champ-has-key? c2 (equal-hash-code k) k)
                           (champ-insert acc (equal-hash-code k) k #t)
                           acc))
                     champ-empty))]
       [_ (expr-set-intersect s1* s2*)])]

    [(expr-set-diff s1 s2)
     (define s1* (whnf s1))
     (define s2* (whnf s2))
     (match (list s1* s2*)
       [(list (expr-hset c1) (expr-hset c2))
        (expr-hset (champ-fold c2 (lambda (k _v acc) (champ-delete acc (equal-hash-code k) k)) c1))]
       [_ (expr-set-diff s1* s2*)])]

    [(expr-set-to-list s)
     (define s* (whnf s))
     (match s*
       [(expr-hset c)
        (racket-list->prologos-list (champ-keys c))]  ;; Set stores keys with #t sentinel
       [_ (expr-set-to-list s*)])]

    ;; ---- PropNetwork iota rules ----
    ;; Type constructors are self-values
    [(expr-net-type) e]
    [(expr-cell-id-type) e]
    [(expr-prop-id-type) e]
    ;; Runtime wrappers are self-values
    [(expr-prop-network _) e]
    [(expr-cell-id _) e]
    [(expr-prop-id _) e]

    ;; net-new : Int -> PropNetwork
    [(expr-net-new fuel)
     (let ([fuel* (whnf fuel)])
       (cond
         [(expr-int? fuel*)
          (expr-prop-network (make-prop-network (expr-int-val fuel*)))]
         ;; Nat coercion: try nat-value
         [(nat-value fuel*)
          => (lambda (k) (expr-prop-network (make-prop-network k)))]
         [(equal? fuel* fuel) e]
         [else (whnf (expr-net-new fuel*))]))]

    ;; net-new-cell : PropNetwork -> A -> (A A -> A) -> [PropNetwork * CellId]
    [(expr-net-new-cell net init merge)
     (let ([net* (whnf net)])
       (match net*
         [(expr-prop-network rnet)
          (let* ([init* (whnf init)]
                 ;; Bridge the Prologos merge function to Racket:
                 ;; merge-fn(old, new) = whnf(app(app(merge, old), new))
                 [merge* (whnf merge)]
                 [racket-merge (lambda (old new)
                                 (whnf (expr-app (expr-app merge* old) new)))])
            (let-values ([(net2 cid) (net-new-cell rnet init* racket-merge)])
              (expr-pair (expr-prop-network net2) (expr-cell-id cid))))]
         [_ (if (equal? net* net) e (whnf (expr-net-new-cell net* init merge)))]))]

    ;; net-new-cell-widen : PropNetwork -> A -> (A A -> A) -> (A A -> A) -> (A A -> A) -> [PropNetwork * CellId]
    [(expr-net-new-cell-widen net init merge widen-fn narrow-fn)
     (let ([net* (whnf net)])
       (match net*
         [(expr-prop-network rnet)
          (let* ([init* (whnf init)]
                 [merge* (whnf merge)]
                 [widen* (whnf widen-fn)]
                 [narrow* (whnf narrow-fn)]
                 [racket-merge (lambda (old new)
                                 (whnf (expr-app (expr-app merge* old) new)))]
                 [racket-widen (lambda (old new)
                                 (whnf (expr-app (expr-app widen* old) new)))]
                 [racket-narrow (lambda (old new)
                                  (whnf (expr-app (expr-app narrow* old) new)))])
            (let-values ([(net2 cid) (net-new-cell-widen rnet init* racket-merge
                                                          racket-widen racket-narrow)])
              (expr-pair (expr-prop-network net2) (expr-cell-id cid))))]
         [_ (if (equal? net* net) e (whnf (expr-net-new-cell-widen net* init merge widen-fn narrow-fn)))]))]

    ;; net-cell-read : PropNetwork -> CellId -> A
    [(expr-net-cell-read net cell)
     (let ([net* (whnf net)] [cell* (whnf cell)])
       (match* (net* cell*)
         [((expr-prop-network rnet) (expr-cell-id cid))
          (net-cell-read rnet cid)]
         [(_ _)
          (cond
            [(not (equal? net* net)) (whnf (expr-net-cell-read net* cell))]
            [(not (equal? cell* cell)) (whnf (expr-net-cell-read net cell*))]
            [else e])]))]

    ;; net-cell-write : PropNetwork -> CellId -> A -> PropNetwork
    [(expr-net-cell-write net cell val)
     (let ([net* (whnf net)] [cell* (whnf cell)])
       (match* (net* cell*)
         [((expr-prop-network rnet) (expr-cell-id cid))
          (let ([val* (whnf val)])
            (expr-prop-network (net-cell-write rnet cid val*)))]
         [(_ _)
          (cond
            [(not (equal? net* net)) (whnf (expr-net-cell-write net* cell val))]
            [(not (equal? cell* cell)) (whnf (expr-net-cell-write net cell* val))]
            [else e])]))]

    ;; net-add-prop : PropNetwork -> List CellId -> List CellId -> (PropNetwork -> PropNetwork) -> [PropNetwork * PropId]
    [(expr-net-add-prop net ins outs fn)
     (let ([net* (whnf net)])
       (match net*
         [(expr-prop-network rnet)
          (let* ([ins-list (prologos-list->racket-list (whnf ins))]
                 [outs-list (prologos-list->racket-list (whnf outs))])
            (if (and ins-list outs-list)
                (let* ([fn* (whnf fn)]
                       ;; Unwrap cell-ids from Prologos AST wrappers
                       [in-cids (map (lambda (e) (expr-cell-id-cell-id-value (whnf e))) ins-list)]
                       [out-cids (map (lambda (e) (expr-cell-id-cell-id-value (whnf e))) outs-list)]
                       ;; Bridge fire function: unwrap -> apply -> re-wrap
                       [racket-fire (lambda (rnet)
                                      (let ([result (whnf (expr-app fn* (expr-prop-network rnet)))])
                                        (match result
                                          [(expr-prop-network rnet2) rnet2]
                                          [_ rnet])))])  ;; stuck: return unchanged
                  (let-values ([(net2 pid) (net-add-propagator rnet in-cids out-cids racket-fire)])
                    (expr-pair (expr-prop-network net2) (expr-prop-id pid))))
                ;; Lists not yet reduced — try reducing net
                (if (equal? net* net) e (whnf (expr-net-add-prop net* ins outs fn)))))]
         [_ (if (equal? net* net) e (whnf (expr-net-add-prop net* ins outs fn)))]))]

    ;; net-run : PropNetwork -> PropNetwork
    [(expr-net-run net)
     (let ([net* (whnf net)])
       (match net*
         [(expr-prop-network rnet)
          (define cell-metas (build-cell-metas-from-network rnet 'user 'lattice))
          (expr-prop-network (capture-network rnet 'user "user:net-run" cell-metas))]
         [_ (if (equal? net* net) e (whnf (expr-net-run net*)))]))]

    ;; net-snapshot : PropNetwork -> PropNetwork (identity on persistent data)
    [(expr-net-snapshot net)
     (let ([net* (whnf net)])
       (match net*
         [(expr-prop-network _) net*]
         [_ (if (equal? net* net) e (whnf (expr-net-snapshot net*)))]))]

    ;; net-contradiction : PropNetwork -> Bool
    [(expr-net-contradiction net)
     (let ([net* (whnf net)])
       (match net*
         [(expr-prop-network rnet)
          (if (net-contradiction? rnet) (expr-true) (expr-false))]
         [_ (if (equal? net* net) e (whnf (expr-net-contradiction net*)))]))]

    ;; ---- UnionFind ----
    ;; Type constructor and runtime wrapper are self-values
    [(expr-uf-type) e]
    [(expr-uf-store _) e]

    ;; uf-empty : UnionFind
    [(expr-uf-empty)
     (expr-uf-store (uf-empty))]

    ;; uf-make-set : UnionFind -> Nat -> A -> UnionFind
    [(expr-uf-make-set store id val)
     (let ([store* (whnf store)])
       (match store*
         [(expr-uf-store rstore)
          (let ([id* (whnf id)])
            (cond
              [(nat-value id*)
               => (lambda (n)
                    (let ([val* (whnf val)])
                      (expr-uf-store (uf-make-set rstore n val*))))]
              [(equal? id* id) (if (equal? store* store) e (whnf (expr-uf-make-set store* id val)))]
              [else (whnf (expr-uf-make-set store* id* val))]))]
         [_ (if (equal? store* store) e (whnf (expr-uf-make-set store* id val)))]))]

    ;; uf-find : UnionFind -> Nat -> [Nat * UnionFind]
    [(expr-uf-find store id)
     (let ([store* (whnf store)] [id* (whnf id)])
       (match store*
         [(expr-uf-store rstore)
          (cond
            [(nat-value id*)
             => (lambda (n)
                  (let-values ([(root updated) (uf-find rstore n)])
                    (expr-pair (racket-nat->expr root) (expr-uf-store updated))))]
            [(not (equal? id* id)) (whnf (expr-uf-find store* id*))]
            [else e])]
         [_ (cond
              [(not (equal? store* store)) (whnf (expr-uf-find store* id))]
              [(not (equal? id* id)) (whnf (expr-uf-find store id*))]
              [else e])]))]

    ;; uf-union : UnionFind -> Nat -> Nat -> UnionFind
    [(expr-uf-union store id1 id2)
     (let ([store* (whnf store)])
       (match store*
         [(expr-uf-store rstore)
          (let ([id1* (whnf id1)] [id2* (whnf id2)])
            (cond
              [(and (nat-value id1*) (nat-value id2*))
               (let ([n1 (nat-value id1*)] [n2 (nat-value id2*)])
                 (expr-uf-store (uf-union rstore n1 n2)))]
              [(not (equal? id1* id1)) (whnf (expr-uf-union store* id1* id2))]
              [(not (equal? id2* id2)) (whnf (expr-uf-union store* id1 id2*))]
              [else (if (equal? store* store) e (whnf (expr-uf-union store* id1 id2)))]))]
         [_ (if (equal? store* store) e (whnf (expr-uf-union store* id1 id2)))]))]

    ;; uf-value : UnionFind -> Nat -> A
    [(expr-uf-value store id)
     (let ([store* (whnf store)] [id* (whnf id)])
       (match store*
         [(expr-uf-store rstore)
          (cond
            [(nat-value id*)
             => (lambda (n)
                  (let-values ([(val _updated) (uf-value rstore n)])
                    val))]
            [(not (equal? id* id)) (whnf (expr-uf-value store* id*))]
            [else e])]
         [_ (cond
              [(not (equal? store* store)) (whnf (expr-uf-value store* id))]
              [(not (equal? id* id)) (whnf (expr-uf-value store id*))]
              [else e])]))]

    ;; ---- Tabling (SLG-style memoization) ----

    ;; Type constructor and runtime wrapper are self-values
    [(expr-table-store-type) e]
    [(expr-table-store-val _) e]

    ;; Opaque FFI values are self-values (already reduced)
    [(expr-opaque _ _) e]

    ;; table-new : PropNetwork -> TableStore
    [(expr-table-new network)
     (let ([network* (whnf network)])
       (match network*
         [(expr-prop-network rnet)
          (expr-table-store-val (table-store-empty rnet))]
         [_ (if (equal? network* network) e (whnf (expr-table-new network*)))]))]

    ;; table-register : TableStore -> Keyword -> Keyword -> [TableStore * CellId]
    [(expr-table-register store name mode)
     (let ([store* (whnf store)])
       (match store*
         [(expr-table-store-val rstore)
          (let ([name* (whnf name)] [mode* (whnf mode)])
            (define sym (if (expr-keyword? name*)
                            (expr-keyword-name name*)
                            'unknown))
            (define mode-sym (if (expr-keyword? mode*)
                                 (expr-keyword-name mode*)
                                 'all))
            (define-values (new-ts cid) (table-register rstore sym mode-sym))
            (expr-pair (expr-table-store-val new-ts) (expr-cell-id cid)))]
         [_ (if (equal? store* store) e (whnf (expr-table-register store* name mode)))]))]

    ;; table-add : TableStore -> Keyword -> A -> TableStore
    [(expr-table-add store name answer)
     (let ([store* (whnf store)])
       (match store*
         [(expr-table-store-val rstore)
          (let ([name* (whnf name)] [answer* (whnf answer)])
            (define sym (if (expr-keyword? name*)
                            (expr-keyword-name name*)
                            'unknown))
            (expr-table-store-val (table-add rstore sym answer*)))]
         [_ (if (equal? store* store) e (whnf (expr-table-add store* name answer)))]))]

    ;; table-answers : TableStore -> Keyword -> List _
    [(expr-table-answers store name)
     (let ([store* (whnf store)])
       (match store*
         [(expr-table-store-val rstore)
          (let ([name* (whnf name)])
            (define sym (if (expr-keyword? name*)
                            (expr-keyword-name name*)
                            'unknown))
            (racket-list->prologos-list (table-answers rstore sym)))]
         [_ (if (equal? store* store) e (whnf (expr-table-answers store* name)))]))]

    ;; table-freeze : TableStore -> Keyword -> TableStore
    [(expr-table-freeze store name)
     (let ([store* (whnf store)])
       (match store*
         [(expr-table-store-val rstore)
          (let ([name* (whnf name)])
            (define sym (if (expr-keyword? name*)
                            (expr-keyword-name name*)
                            'unknown))
            (expr-table-store-val (table-freeze rstore sym)))]
         [_ (if (equal? store* store) e (whnf (expr-table-freeze store* name)))]))]

    ;; table-complete? : TableStore -> Keyword -> Bool
    [(expr-table-complete store name)
     (let ([store* (whnf store)])
       (match store*
         [(expr-table-store-val rstore)
          (let ([name* (whnf name)])
            (define sym (if (expr-keyword? name*)
                            (expr-keyword-name name*)
                            'unknown))
            (if (table-complete? rstore sym) (expr-true) (expr-false)))]
         [_ (if (equal? store* store) e (whnf (expr-table-complete store* name)))]))]

    ;; table-run : TableStore -> TableStore
    [(expr-table-run store)
     (let ([store* (whnf store)])
       (match store*
         [(expr-table-store-val rstore)
          (expr-table-store-val (table-run rstore))]
         [_ (if (equal? store* store) e (whnf (expr-table-run store*)))]))]

    ;; table-lookup : TableStore -> Keyword -> A -> Bool
    [(expr-table-lookup store name answer)
     (let ([store* (whnf store)])
       (match store*
         [(expr-table-store-val rstore)
          (let ([name* (whnf name)] [answer* (whnf answer)])
            (define sym (if (expr-keyword? name*)
                            (expr-keyword-name name*)
                            'unknown))
            (if (table-lookup rstore sym answer*) (expr-true) (expr-false)))]
         [_ (if (equal? store* store) e (whnf (expr-table-lookup store* name answer)))]))]

    ;; ---- Relational language (Phase 7) ----
    ;; Type constructors are self-values
    [(expr-solver-type) e]
    [(expr-goal-type) e]
    [(expr-derivation-type) e]
    [(expr-answer-type _) e]
    [(expr-relation-type _) e]
    [(expr-cut) e]
    ;; Runtime wrapper is a self-value
    [(expr-solver-config _) e]
    ;; Structural values — don't reduce during WHNF
    [(expr-logic-var _ _) e]
    [(expr-defr _ _ _) e]
    [(expr-defr-variant _ _) e]
    [(expr-rel _ _) e]
    [(expr-clause _) e]
    [(expr-fact-block _) e]
    [(expr-fact-row _) e]
    [(expr-goal-app _ _) e]
    [(expr-unify-goal _ _) e]
    [(expr-is-goal _ _) e]
    [(expr-not-goal _) e]
    [(expr-guard _ _) e]
    ;; Solve/Explain iota rules: reduce goal then dispatch to runtime solver
    [(expr-solve goal)
     (run-solve-goal goal default-solver-config)]

    [(expr-solve-with solver overrides goal)
     (define base-cfg
       (if solver
           (let ([s (whnf solver)])
             (if (expr-solver-config? s)
                 (expr-solver-config-config-map s)
                 default-solver-config))
           default-solver-config))
     (define cfg
       (if overrides
           (let ([o (whnf overrides)])
             (if (expr-solver-config? o)
                 (solver-config-merge base-cfg
                                      (solver-config-options (expr-solver-config-config-map o)))
                 base-cfg))
           base-cfg))
     (run-solve-goal goal cfg)]

    [(expr-solve-one goal)
     (run-solve-one-goal goal default-solver-config)]

    [(expr-explain goal)
     (run-explain-goal goal default-solver-config 'full)]

    [(expr-explain-with solver overrides goal)
     (define base-cfg
       (if solver
           (let ([s (whnf solver)])
             (if (expr-solver-config? s)
                 (expr-solver-config-config-map s)
                 default-solver-config))
           default-solver-config))
     (define cfg
       (if overrides
           (let ([o (whnf overrides)])
             (if (expr-solver-config? o)
                 (solver-config-merge base-cfg
                                      (solver-config-options (expr-solver-config-config-map o)))
                 base-cfg))
           base-cfg))
     (run-explain-goal goal cfg 'full)]

    ;; Narrow: DT-guided narrowing search (Phase 1d)
    [(expr-narrow func args target vars)
     (run-narrowing func args target vars)]

    ;; Constraint forms (Phase 3c) — pass through (consumed by solve dispatch)
    [(expr-all-different _) e]
    [(expr-element _ _ _) e]
    [(expr-cumulative _ _) e]
    [(expr-minimize _) e]

    ;; Union types: pass through (types don't reduce)
    [(expr-union _ _) e]

    ;; Reduce: structural pattern matching.
    ;; Decompose scrutinee as constructor, substitute field values into
    ;; matching arm body. Handles user-defined constructors (fvar applications)
    ;; and built-in constructors (expr-zero, expr-suc, expr-true, expr-false).
    ;; With native constructors, constructor fvars are never unfolded,
    ;; so the scrutinee is always a constructor application (not a lambda).
    [(expr-reduce scrutinee arms _structural?)
     (define scrut-whnf* (whnf scrutinee))
     (define struct-result (or (try-structural-reduce scrutinee arms)
                               (try-structural-reduce scrut-whnf* arms)
                               (try-builtin-reduce scrut-whnf* arms)))
     (if struct-result
         (whnf struct-result)
         e)]  ;; stuck — scrutinee is neutral

    ;; Free variable: unfold global definition if available.
    ;; Constructor and type-name fvars are canonical — do NOT unfold.
    ;; This keeps constructor applications as (fvar 'cons arg1 arg2) in WHNF,
    ;; allowing structural PM (try-structural-reduce) to decompose them.
    [(expr-fvar name)
     (if (or (lookup-ctor name) (lookup-ctor (ctor-short-name name))
             (lookup-type-ctors name) (lookup-type-ctors (ctor-short-name name)))
         e  ;; constructor or type name: canonical, don't unfold
         (let ([val (global-env-lookup-value name)])
           (if val (whnf val) e)))]

    ;; Metavariable: if solved, reduce solution; if unsolved, stuck
    ;; PPN Track 4 Phase 4b: use cell-id fast path (cells authoritative)
    [(expr-meta id cell-id)
     (let ([sol (meta-solution/cell-id cell-id id)])
       (if sol (whnf sol) e))]

    ;; N4: numeric literal — collapse to its concrete node once alpha is solved (so
    ;; primitive ops reducing their args see concrete values); stuck if unsolved.
    [(expr-num-lit val integral? _origin alpha)
     (define resolved
       (match alpha
         [(expr-meta id cell-id) (or (meta-solution/cell-id cell-id id) alpha)]
         [_ alpha]))
     (or (num-lit->concrete val integral? resolved) e)]

    ;; Everything else is already in WHNF
    [_ e]))

;; ========================================
;; Full Normalization
;; First reduce to WHNF, then normalize all subterms.
;; Per-command memoization: when current-nf-cache is active,
;; cache nf results keyed by expr (transparent structs → equal?-based hashing).
;; ========================================
(define current-nf-cache (make-parameter #f))

;; ========================================
;; SUB.3: NbE open-the-binder normalization (ruling D)
;; docs/tracking/2026-07-24_SUBSTITUTION_CONTAINMENT_DEFECT.md §3
;; ========================================
;; nf normalizes under binders by OPENING them: bvar0 is substituted with a
;; deterministic depth-keyed NbE fvar (#%nbe0, #%nbe1, … — `#%` names are
;; unwritable in surface syntax so no user collision; deterministic names keep
;; the nf cache sound/hit-capable and display output stable), the body
;; normalizes in that open context — whnf's container mints (map-assoc→champ,
;; set-insert→hset, pvec→rrb) then capture only FVARS, on which shift/subst
;; are already identity, so the champ-closed-leaf contract holds BY
;; CONSTRUCTION — and re-abstraction converts the NbE fvar back to bvar0.
;; A container that captured the NbE var is rebuilt as its SPINE form
;; (map-assoc / set-insert chains, pvec-literal — the traversal-safe open
;; representation); containers that did not are kept eq?-identical.

(define current-nbe-depth (make-parameter 0))

(define (nbe-fvar-name d) (string->symbol (format "#%nbe~a" d)))

(define (nf-under-binder body)
  ;; Fast path: normalize in place. When the result contains no open
  ;; container (the overwhelmingly common case — bodies whose reduction
  ;; mints no map/set/vec around a bound var), the in-place result is
  ;; exactly what the NbE path would produce, at one walk instead of three.
  ;; The detector is the SUB.1 tripwire predicate — exact and read-only —
  ;; so this is one semantics with two execution strategies, not a dual
  ;; path: any mint routes to the NbE open-the-binder normalization.
  (define fast (nf body))
  (if (nbe-scan-poisoned? fast)
      (nbe-open-nf body)
      fast))

;; Verdict memo for the fast-path scan, eq?-keyed on the nf RESULT (the nf
;; cache returns shared objects, so repeated normalization of the same binder
;; body within a command re-verifies for free). Weak: entries die with their
;; terms. Sound: a term's open-container verdict is a pure function of its
;; identity (exprs are immutable). Caveat, pinned: TRANSIENTS are #:mutable,
;; so a verdict on a transient-bearing term could go stale — but no surface
;; construct can place a transient value inside a binder body (transients are
;; bracket-protocol runtime values, not literals), and the SUB.1 tripwire at
;; the persist boundaries guards the claim.
(define nbe-scan-cache (make-weak-hasheq))

(define (nbe-scan-poisoned? e)
  (define cached (hash-ref nbe-scan-cache e 'miss))
  (cond
    [(eq? cached 'miss)
     (define verdict (contains-open-container? e))
     (hash-set! nbe-scan-cache e verdict)
     verdict]
    [else cached]))

(define (nbe-open-nf body)
  (define d (current-nbe-depth))
  (define fv-name (nbe-fvar-name d))
  (define opened (subst 0 (expr-fvar fv-name) body))
  (define body*
    (parameterize ([current-nbe-depth (add1 d)])
      (nf opened)))
  (re-abstract fv-name body*))

;; re-abstract: fv-name → bvar(depth); free bvar i ≥ depth → i+1 (restoring
;; the indices `subst 0` decremented at opening). Explicit arms ONLY for
;; bvar/fvar, the four binder forms (substitution.rkt shift's authoritative
;; inventory), and the runtime containers; every other node rebuilds
;; GENERICALLY via struct-info + struct-type-make-constructor (all expr
;; structs are #:transparent) — like the SUB.1 tripwire, this walker
;; structurally cannot have the missing-arm defect it exists to fix.
;; eq?-preserving on unchanged subtrees.
(define (re-abstract fv-name e)
  ;; deterministic entry order for rebuilt spines (champ order is hash-order)
  (define (sorted-entries c)
    (sort (champ-entries c) string<? #:key (lambda (kv) (format "~a" (car kv)))))
  (define (walk v d)
    (cond
      [(expr-fvar? v)
       (if (eq? (expr-fvar-name v) fv-name) (expr-bvar d) v)]
      [(expr-bvar? v)
       (let ([i (expr-bvar-index v)])
         (if (>= i d) (expr-bvar (add1 i)) v))]
      ;; binder forms — body positions at d+1 (or +binding-count)
      [(expr-lam? v)
       (let ([t* (walk (expr-lam-type v) d)]
             [b* (walk (expr-lam-body v) (add1 d))])
         (if (and (eq? t* (expr-lam-type v)) (eq? b* (expr-lam-body v)))
             v
             (expr-lam (expr-lam-mult v) t* b*)))]
      [(expr-Pi? v)
       (let ([dm* (walk (expr-Pi-domain v) d)]
             [cd* (walk (expr-Pi-codomain v) (add1 d))])
         (if (and (eq? dm* (expr-Pi-domain v)) (eq? cd* (expr-Pi-codomain v)))
             v
             (expr-Pi (expr-Pi-mult v) dm* cd*)))]
      [(expr-Sigma? v)
       (let ([f* (walk (expr-Sigma-fst-type v) d)]
             [s* (walk (expr-Sigma-snd-type v) (add1 d))])
         (if (and (eq? f* (expr-Sigma-fst-type v)) (eq? s* (expr-Sigma-snd-type v)))
             v
             (expr-Sigma f* s*)))]
      [(expr-reduce? v)
       (let ([sc* (walk (expr-reduce-scrutinee v) d)]
             [arms* (for/list ([arm (in-list (expr-reduce-arms v))])
                      (let ([b* (walk (expr-reduce-arm-body arm)
                                      (+ d (expr-reduce-arm-binding-count arm)))])
                        (if (eq? b* (expr-reduce-arm-body arm))
                            arm
                            (expr-reduce-arm (expr-reduce-arm-ctor-name arm)
                                             (expr-reduce-arm-binding-count arm)
                                             b*))))])
         (if (and (eq? sc* (expr-reduce-scrutinee v))
                  (andmap eq? arms* (expr-reduce-arms v)))
             v
             (expr-reduce sc* arms* (expr-reduce-structural? v))))]
      ;; runtime containers — contents walk at the SAME depth (containers do
      ;; not bind); a changed container rebuilds as its SPINE form
      [(expr-champ? v)
       (let* ([entries (sorted-entries (expr-champ-racket-champ v))]
              [entries* (for/list ([kv (in-list entries)])
                          (cons (walk (car kv) d) (walk (cdr kv) d)))])
         (if (andmap (lambda (a b) (and (eq? (car a) (car b)) (eq? (cdr a) (cdr b))))
                     entries entries*)
             v
             (for/fold ([acc (expr-map-empty (expr-hole) (expr-hole))])
                       ([kv (in-list entries*)])
               (expr-map-assoc acc (car kv) (cdr kv)))))]
      [(expr-hset? v)
       (let* ([entries (sorted-entries (expr-hset-racket-champ v))]
              [elems (map car entries)]
              [elems* (for/list ([el (in-list elems)]) (walk el d))])
         (if (andmap eq? elems elems*)
             v
             (for/fold ([acc (expr-set-empty (expr-hole))])
                       ([el (in-list elems*)])
               (expr-set-insert acc el))))]
      [(expr-rrb? v)
       (let* ([elems (rrb-to-list (expr-rrb-racket-rrb v))]
              [elems* (for/list ([el (in-list elems)]) (walk el d))])
         (if (andmap eq? elems elems*)
             v
             (expr-pvec-literal elems*)))]
      ;; transients: nothing mints them under a binder (SUB.1 tripwire guards
      ;; the claim); their payloads are mutable Racket structures a rebuild
      ;; cannot express — leave untouched
      [(or (expr-trrb? v) (expr-tchamp? v) (expr-thset? v)) v]
      ;; generic transparent-struct rebuild
      [(struct? v)
       (define-values (st _skipped?) (struct-info v))
       (define vec (struct->vector v))
       (define fields (for/list ([i (in-range 1 (vector-length vec))])
                        (vector-ref vec i)))
       (define fields* (for/list ([f (in-list fields)]) (walk f d)))
       (if (andmap eq? fields fields*)
           v
           (apply (struct-type-make-constructor st) fields*))]
      [(pair? v)
       (let ([a* (walk (car v) d)] [b* (walk (cdr v) d)])
         (if (and (eq? a* (car v)) (eq? b* (cdr v))) v (cons a* b*)))]
      [else v]))
  (walk e 0))

(define (nf e)
  (define cache (current-nf-cache))
  (cond
    [(and cache (hash-ref cache e #f))
     => values]
    [else
     (define result (nf-whnf (whnf e)))
     ;; POL.10 hardening: match whnf's Issue-#70 guard — never cache a result
     ;; that IS an unsolved meta (its pre-solve identity would go stale after
     ;; solve-meta!). whnf's cache had this guard; nf's lacked it.
     (when (and cache (not (expr-meta? result)))
       (hash-set! cache e result))
     result]))

;; Helper: normalize a term that is already in WHNF
(define (nf-whnf e)
  (match e
    ;; Atoms / leaves — already normal
    [(expr-bvar _) e]
    [(expr-fvar _) e]
    [(expr-zero) (expr-nat-val 0)]  ;; normalize legacy zero to native
    [(expr-nat-val _) e]
    [(expr-refl) e]
    [(expr-Nat) e]
    [(expr-Bool) e]
    [(expr-true) e]
    [(expr-false) e]
    [(expr-Unit) e]
    [(expr-unit) e]
    [(expr-Nil) e]
    [(expr-nil) e]
    [(expr-Type _) e]
    [(expr-hole) e]
    [(expr-typed-hole _) e]
    [(expr-meta _ _) e]
    ;; N4: numeric literal — collapse when alpha solved (mirror whnf); else identity.
    [(expr-num-lit val integral? _origin alpha)
     (define resolved
       (match alpha
         [(expr-meta id cell-id) (or (meta-solution/cell-id cell-id id) alpha)]
         [_ alpha]))
     (or (num-lit->concrete val integral? resolved) e)]
    [(expr-error) e]
    [(? ns-context?) e]  ;; namespace metadata — pass-through
    [(expr-panic msg) (expr-panic (nf msg))]  ;; reduce msg, stay stuck
    [(expr-tycon _) e]  ;; Unapplied type constructor (HKT) — already normal

    ;; Structured terms: normalize subterms
    [(expr-suc e1)
     (let ([inner (nf e1)])
       (cond
         [(expr-nat-val? inner) (expr-nat-val (+ (expr-nat-val-n inner) 1))]
         [(expr-zero? inner)    (expr-nat-val 1)]
         [else                  (expr-suc inner)]))]
    ;; SUB.3 (ruling D): binder bodies normalize via NbE open-the-binder —
    ;; never a naked (nf body), which minted OPEN champs (the substitution
    ;; containment defect's root, formerly this arm).
    [(expr-lam m t body) (expr-lam m (nf t) (nf-under-binder body))]
    [(expr-Pi m dom cod) (expr-Pi m (nf dom) (nf-under-binder cod))]
    [(expr-Sigma t1 t2) (expr-Sigma (nf t1) (nf-under-binder t2))]
    [(expr-pair e1 e2) (expr-pair (nf e1) (nf e2))]
    [(expr-Eq t e1 e2) (expr-Eq (nf t) (nf e1) (nf e2))]

    ;; Application that didn't reduce (neutral term)
    [(expr-app e1 e2) (expr-app (nf e1) (nf e2))]
    ;; Projection that didn't reduce (neutral)
    [(expr-fst e1) (expr-fst (nf e1))]
    [(expr-snd e1) (expr-snd (nf e1))]

    ;; Annotation erasure (shouldn't usually appear in WHNF, but handle it)
    [(expr-ann e1 _) (nf e1)]

    ;; Eliminators stuck on neutral — lazy branch normalization
    ;; Only normalize the scrutinee (target/proof); if it resolves, take the
    ;; appropriate branch. Otherwise leave branches unnormalized to avoid
    ;; exponential unfolding of recursive functions.
    [(expr-natrec mot base step target)
     (let ([target* (nf target)])
       (match target*
         [(expr-nat-val n) #:when (= n 0) (nf base)]
         [(expr-nat-val n) #:when (> n 0)
          (nf (expr-app (expr-app step (expr-nat-val (- n 1)))
                        (expr-natrec mot base step (expr-nat-val (- n 1)))))]
         [(expr-zero) (nf base)]
         [(expr-suc n) (nf (expr-app (expr-app step n) (expr-natrec mot base step n)))]
         [_ (expr-natrec (nf mot) base step target*)]))]
    [(expr-J mot base left right proof)
     (let ([proof* (nf proof)])
       (match proof*
         [(expr-refl) (nf (expr-app base left))]
         [_ (expr-J (nf mot) (nf base) (nf left) (nf right) proof*)]))]
    [(expr-boolrec mot tc fc target)
     (let ([target* (nf target)])
       (match target*
         [(expr-true)  (nf tc)]
         [(expr-false) (nf fc)]
         [_ (expr-boolrec (nf mot) tc fc target*)]))]

    ;; Vec/Fin normalization
    [(expr-Vec t n) (expr-Vec (nf t) (nf n))]
    [(expr-vnil t) (expr-vnil (nf t))]
    [(expr-vcons t n hd tl) (expr-vcons (nf t) (nf n) (nf hd) (nf tl))]
    [(expr-Fin n) (expr-Fin (nf n))]
    [(expr-fzero n) (expr-fzero (nf n))]
    [(expr-fsuc n i) (expr-fsuc (nf n) (nf i))]
    [(expr-vhead t n v) (expr-vhead (nf t) (nf n) (nf v))]
    [(expr-vtail t n v) (expr-vtail (nf t) (nf n) (nf v))]
    [(expr-vindex t n i v) (expr-vindex (nf t) (nf n) (nf i) (nf v))]

    ;; Int normalization
    [(expr-Int) e]
    [(expr-int _) e]
    [(expr-int-add a b) (expr-int-add (nf a) (nf b))]
    [(expr-int-sub a b) (expr-int-sub (nf a) (nf b))]
    [(expr-int-mul a b) (expr-int-mul (nf a) (nf b))]
    [(expr-int-div a b) (expr-int-div (nf a) (nf b))]
    [(expr-int-mod a b) (expr-int-mod (nf a) (nf b))]
    [(expr-int-neg a) (expr-int-neg (nf a))]
    [(expr-int-abs a) (expr-int-abs (nf a))]
    [(expr-int-lt a b) (expr-int-lt (nf a) (nf b))]
    [(expr-int-le a b) (expr-int-le (nf a) (nf b))]
    [(expr-int-eq a b) (expr-int-eq (nf a) (nf b))]
    [(expr-from-nat n) (expr-from-nat (nf n))]

    ;; Rat normalization
    [(expr-Rat) e]
    [(expr-rat _) e]
    [(expr-rat-add a b) (expr-rat-add (nf a) (nf b))]
    [(expr-rat-sub a b) (expr-rat-sub (nf a) (nf b))]
    [(expr-rat-mul a b) (expr-rat-mul (nf a) (nf b))]
    [(expr-rat-div a b) (expr-rat-div (nf a) (nf b))]
    [(expr-rat-neg a) (expr-rat-neg (nf a))]
    [(expr-rat-abs a) (expr-rat-abs (nf a))]
    [(expr-rat-lt a b) (expr-rat-lt (nf a) (nf b))]
    [(expr-rat-le a b) (expr-rat-le (nf a) (nf b))]
    [(expr-rat-eq a b) (expr-rat-eq (nf a) (nf b))]
    [(expr-from-int n) (expr-from-int (nf n))]
    [(expr-rat-numer a) (expr-rat-numer (nf a))]
    [(expr-rat-denom a) (expr-rat-denom (nf a))]

    ;; Posit8 normalization
    [(expr-Posit8) e]
    [(expr-posit8 _) e]
    [(expr-p8-add a b) (expr-p8-add (nf a) (nf b))]
    [(expr-p8-sub a b) (expr-p8-sub (nf a) (nf b))]
    [(expr-p8-mul a b) (expr-p8-mul (nf a) (nf b))]
    [(expr-p8-div a b) (expr-p8-div (nf a) (nf b))]
    [(expr-p8-neg a) (expr-p8-neg (nf a))]
    [(expr-p8-abs a) (expr-p8-abs (nf a))]
    [(expr-p8-sqrt a) (expr-p8-sqrt (nf a))]
    [(expr-p8-lt a b) (expr-p8-lt (nf a) (nf b))]
    [(expr-p8-le a b) (expr-p8-le (nf a) (nf b))]
    [(expr-p8-eq a b) (expr-p8-eq (nf a) (nf b))]
    [(expr-p8-from-nat n) (expr-p8-from-nat (nf n))]
    [(expr-p8-to-rat a) (expr-p8-to-rat (nf a))]
    [(expr-p8-from-rat a) (expr-p8-from-rat (nf a))]
    [(expr-p8-from-int a) (expr-p8-from-int (nf a))]
    [(expr-p8-if-nar t nc vc v)
     (expr-p8-if-nar (nf t) (nf nc) (nf vc) (nf v))]

    ;; Posit16 normalization
    [(expr-Posit16) e]
    [(expr-posit16 _) e]
    [(expr-p16-add a b) (expr-p16-add (nf a) (nf b))]
    [(expr-p16-sub a b) (expr-p16-sub (nf a) (nf b))]
    [(expr-p16-mul a b) (expr-p16-mul (nf a) (nf b))]
    [(expr-p16-div a b) (expr-p16-div (nf a) (nf b))]
    [(expr-p16-neg a) (expr-p16-neg (nf a))]
    [(expr-p16-abs a) (expr-p16-abs (nf a))]
    [(expr-p16-sqrt a) (expr-p16-sqrt (nf a))]
    [(expr-p16-lt a b) (expr-p16-lt (nf a) (nf b))]
    [(expr-p16-le a b) (expr-p16-le (nf a) (nf b))]
    [(expr-p16-eq a b) (expr-p16-eq (nf a) (nf b))]
    [(expr-p16-from-nat n) (expr-p16-from-nat (nf n))]
    [(expr-p16-to-rat a) (expr-p16-to-rat (nf a))]
    [(expr-p16-from-rat a) (expr-p16-from-rat (nf a))]
    [(expr-p16-from-int a) (expr-p16-from-int (nf a))]
    [(expr-p16-if-nar t nc vc v)
     (expr-p16-if-nar (nf t) (nf nc) (nf vc) (nf v))]

    ;; Posit32 normalization
    [(expr-Posit32) e]
    [(expr-posit32 _) e]
    ;; Float (Numerics N3) — leaf normalization
    [(expr-Float32) e]
    [(expr-float32 _) e]
    [(expr-Float64) e]
    [(expr-float64 _) e]
    ;; Float ops (Numerics N3b)
    [(expr-f32-add a b) (expr-f32-add (nf a) (nf b))]
    [(expr-f32-sub a b) (expr-f32-sub (nf a) (nf b))]
    [(expr-f32-mul a b) (expr-f32-mul (nf a) (nf b))]
    [(expr-f32-div a b) (expr-f32-div (nf a) (nf b))]
    [(expr-f32-neg a) (expr-f32-neg (nf a))]
    [(expr-f32-abs a) (expr-f32-abs (nf a))]
    [(expr-f32-sqrt a) (expr-f32-sqrt (nf a))]
    [(expr-f32-lt a b) (expr-f32-lt (nf a) (nf b))]
    [(expr-f32-le a b) (expr-f32-le (nf a) (nf b))]
    [(expr-f32-eq a b) (expr-f32-eq (nf a) (nf b))]
    [(expr-f64-add a b) (expr-f64-add (nf a) (nf b))]
    [(expr-f64-sub a b) (expr-f64-sub (nf a) (nf b))]
    [(expr-f64-mul a b) (expr-f64-mul (nf a) (nf b))]
    [(expr-f64-div a b) (expr-f64-div (nf a) (nf b))]
    [(expr-f64-neg a) (expr-f64-neg (nf a))]
    [(expr-f64-abs a) (expr-f64-abs (nf a))]
    [(expr-f64-sqrt a) (expr-f64-sqrt (nf a))]
    [(expr-f64-lt a b) (expr-f64-lt (nf a) (nf b))]
    [(expr-f64-le a b) (expr-f64-le (nf a) (nf b))]
    [(expr-f64-eq a b) (expr-f64-eq (nf a) (nf b))]
    ;; Cross-width Float conversions (Numerics N3e-rest)
    [(expr-float-finite a) (expr-float-finite (nf a))]
    [(expr-float-to-rat a) (expr-float-to-rat (nf a))]
    [(expr-float-to-int a) (expr-float-to-int (nf a))]
    [(expr-float-to-float32 a) (expr-float-to-float32 (nf a))]
    [(expr-p32-add a b) (expr-p32-add (nf a) (nf b))]
    [(expr-p32-sub a b) (expr-p32-sub (nf a) (nf b))]
    [(expr-p32-mul a b) (expr-p32-mul (nf a) (nf b))]
    [(expr-p32-div a b) (expr-p32-div (nf a) (nf b))]
    [(expr-p32-neg a) (expr-p32-neg (nf a))]
    [(expr-p32-abs a) (expr-p32-abs (nf a))]
    [(expr-p32-sqrt a) (expr-p32-sqrt (nf a))]
    [(expr-p32-lt a b) (expr-p32-lt (nf a) (nf b))]
    [(expr-p32-le a b) (expr-p32-le (nf a) (nf b))]
    [(expr-p32-eq a b) (expr-p32-eq (nf a) (nf b))]
    [(expr-p32-from-nat n) (expr-p32-from-nat (nf n))]
    [(expr-p32-to-rat a) (expr-p32-to-rat (nf a))]
    [(expr-p32-from-rat a) (expr-p32-from-rat (nf a))]
    [(expr-p32-from-int a) (expr-p32-from-int (nf a))]
    [(expr-p32-if-nar t nc vc v)
     (expr-p32-if-nar (nf t) (nf nc) (nf vc) (nf v))]

    ;; Posit64 normalization
    [(expr-Posit64) e]
    [(expr-posit64 _) e]
    [(expr-p64-add a b) (expr-p64-add (nf a) (nf b))]
    [(expr-p64-sub a b) (expr-p64-sub (nf a) (nf b))]
    [(expr-p64-mul a b) (expr-p64-mul (nf a) (nf b))]
    [(expr-p64-div a b) (expr-p64-div (nf a) (nf b))]
    [(expr-p64-neg a) (expr-p64-neg (nf a))]
    [(expr-p64-abs a) (expr-p64-abs (nf a))]
    [(expr-p64-sqrt a) (expr-p64-sqrt (nf a))]
    [(expr-p64-lt a b) (expr-p64-lt (nf a) (nf b))]
    [(expr-p64-le a b) (expr-p64-le (nf a) (nf b))]
    [(expr-p64-eq a b) (expr-p64-eq (nf a) (nf b))]
    [(expr-p64-from-nat n) (expr-p64-from-nat (nf n))]
    [(expr-p64-to-rat a) (expr-p64-to-rat (nf a))]
    [(expr-p64-from-rat a) (expr-p64-from-rat (nf a))]
    [(expr-p64-from-int a) (expr-p64-from-int (nf a))]
    [(expr-p64-if-nar t nc vc v)
     (expr-p64-if-nar (nf t) (nf nc) (nf vc) (nf v))]

    ;; Quire normalization
    [(expr-Quire8) e]
    [(expr-quire8-val _) e]
    [(expr-quire8-fma q a b) (expr-quire8-fma (nf q) (nf a) (nf b))]
    [(expr-quire8-to q) (expr-quire8-to (nf q))]
    [(expr-Quire16) e]
    [(expr-quire16-val _) e]
    [(expr-quire16-fma q a b) (expr-quire16-fma (nf q) (nf a) (nf b))]
    [(expr-quire16-to q) (expr-quire16-to (nf q))]
    [(expr-Quire32) e]
    [(expr-quire32-val _) e]
    [(expr-quire32-fma q a b) (expr-quire32-fma (nf q) (nf a) (nf b))]
    [(expr-quire32-to q) (expr-quire32-to (nf q))]
    [(expr-Quire64) e]
    [(expr-quire64-val _) e]
    [(expr-quire64-fma q a b) (expr-quire64-fma (nf q) (nf a) (nf b))]
    [(expr-quire64-to q) (expr-quire64-to (nf q))]

    ;; Generic arithmetic normalization
    [(expr-generic-add a b) (expr-generic-add (nf a) (nf b))]
    [(expr-generic-sub a b) (expr-generic-sub (nf a) (nf b))]
    [(expr-generic-mul a b) (expr-generic-mul (nf a) (nf b))]
    [(expr-generic-div a b) (expr-generic-div (nf a) (nf b))]
    [(expr-generic-lt a b) (expr-generic-lt (nf a) (nf b))]
    [(expr-generic-le a b) (expr-generic-le (nf a) (nf b))]
    [(expr-generic-gt a b) (expr-generic-gt (nf a) (nf b))]
    [(expr-generic-ge a b) (expr-generic-ge (nf a) (nf b))]
    [(expr-generic-eq a b) (expr-generic-eq (nf a) (nf b))]
    [(expr-generic-mod a b) (expr-generic-mod (nf a) (nf b))]
    [(expr-generic-negate a) (expr-generic-negate (nf a))]
    [(expr-generic-abs a) (expr-generic-abs (nf a))]
    [(expr-generic-from-int t a) (expr-generic-from-int (nf t) (nf a))]
    [(expr-generic-from-rat t a) (expr-generic-from-rat (nf t) (nf a))]

    ;; Symbol normalization
    [(expr-Symbol) e]
    [(expr-symbol _) e]

    ;; Keyword normalization
    [(expr-Keyword) e]
    [(expr-keyword _) e]

    ;; Path normalization
    [(expr-Path) e]
    [(expr-path _ _) e]
    ;; Dynamic path operations — reduce target/path, then navigate
    [(expr-get-in target paths)
     (define nt (nf target))
     (define np (nf paths))
     (cond
       ;; Static path on concrete target: walk segments
       [(and (expr-path? np) (pair? (expr-path-branches np)))
        (define segs (car (expr-path-branches np)))
        (foldl (lambda (seg acc) (nf (expr-map-get acc (expr-keyword seg) #f))) nt segs)]
       [else (expr-get-in nt np)])]
    [(expr-update-in target paths fn)
     (define nt (nf target))
     (define np (nf paths))
     (define nf-fn (nf fn))
     (cond
       [(and (expr-path? np) (pair? (expr-path-branches np)))
        (define segs (car (expr-path-branches np)))
        ;; F1b.3 (D24 guard): entry-only zero-segment error (see the whnf arm).
        (when (null? segs)
          (error 'update-in "dynamic path has zero segments — an empty path would replace the entire map"))
        (define (build base segs)
          (cond
            [(null? segs) (nf (expr-app nf-fn base))]
            [else
             (define key (expr-keyword (car segs)))
             (define sub (nf (expr-map-get base key #f)))
             (define updated (build sub (cdr segs)))
             ;; 2026-07-16: normalize the spine (was returned as a raw
             ;; map-assoc stuck term, leaving map-keys/map-size stuck on
             ;; dynamic update-in results — the P6 wart).
             (nf (expr-map-assoc base key updated))]))
        (build nt segs)]
       [else (expr-update-in nt np nf-fn)])]
    ;; expr-broadcast-get: RETIRED at CIU T6 D4.P1a (ruling Q_L3).

    ;; Char normalization
    [(expr-Char) e]
    [(expr-char _) e]

    ;; String normalization
    [(expr-String) e]
    [(expr-string _) e]

    ;; Record/tuple type normalization: normalize field types
    [(? expr-Record? rec) (record-map-field-types nf rec)]
    ;; Map normalization
    [(expr-Map k v) (expr-Map (nf k) (nf v))]
    [(expr-champ _) e]
    [(expr-map-empty k v) (expr-map-empty (nf k) (nf v))]
    [(expr-map-assoc m k v) (expr-map-assoc (nf m) (nf k) (nf v))]
    [(expr-map-get m k a) (expr-map-get (nf m) (nf k) (if (expr? a) (nf a) a))]
    ;; CIU T6 F1b.5-s2: a validate that survived whnf is stuck — nf the
    ;; expr slots (subject + plan defaults/preds) via the single helper
    [(? expr-validate? v) (validate-map-exprs nf v)]
    ;; CIU T6 D4.P3a: a select reaching nf-whnf is STUCK (whnf fired the
    ;; redex already) — rebuild the subject, branches are static data
    [(? expr-select? v) (select-map-exprs nf v)]
    [(expr-get c k a) (expr-get (nf c) (nf k) (if (expr? a) (nf a) a))]
    [(expr-nil-safe-get m k) (expr-nil-safe-get (nf m) (nf k))]
    [(expr-nil-check a) (expr-nil-check (nf a))]
    [(expr-map-dissoc m k) (expr-map-dissoc (nf m) (nf k))]
    [(expr-map-size m) (expr-map-size (nf m))]
    [(expr-map-has-key m k) (expr-map-has-key (nf m) (nf k))]
    [(expr-map-keys m) (expr-map-keys (nf m))]
    [(expr-map-vals m) (expr-map-vals (nf m))]

    ;; Set normalization
    [(expr-Set a) (expr-Set (nf a))]
    [(expr-hset _) e]
    [(expr-set-empty a) (expr-set-empty (nf a))]
    [(expr-set-insert s a) (expr-set-insert (nf s) (nf a))]
    [(expr-set-member s a) (expr-set-member (nf s) (nf a))]
    [(expr-set-delete s a) (expr-set-delete (nf s) (nf a))]
    [(expr-set-size s) (expr-set-size (nf s))]
    [(expr-set-union s1 s2) (expr-set-union (nf s1) (nf s2))]
    [(expr-set-intersect s1 s2) (expr-set-intersect (nf s1) (nf s2))]
    [(expr-set-diff s1 s2) (expr-set-diff (nf s1) (nf s2))]
    [(expr-set-to-list s) (expr-set-to-list (nf s))]

    ;; PVec normalization
    [(expr-PVec a) (expr-PVec (nf a))]
    [(expr-rrb r)
     ;; Normalize all elements inside the RRB tree
     (expr-rrb (rrb-from-list (map nf (rrb-to-list r))))]
    [(expr-pvec-empty a) (expr-pvec-empty (nf a))]
    [(expr-pvec-push v x) (expr-pvec-push (nf v) (nf x))]
    [(expr-pvec-literal elems) (expr-pvec-literal (map nf elems))]
    [(expr-list-literal elems chain) (expr-list-literal (map nf elems) (nf chain))]
    [(expr-map-literal keys vals chain)
     (expr-map-literal (map nf keys) (map nf vals) (nf chain))]
    [(expr-pvec-nth v i) (expr-pvec-nth (nf v) (nf i))]
    [(expr-pvec-update v i x) (expr-pvec-update (nf v) (nf i) (nf x))]
    [(expr-pvec-length v) (expr-pvec-length (nf v))]
    [(expr-pvec-to-list v) (expr-pvec-to-list (nf v))]
    [(expr-pvec-from-list v) (expr-pvec-from-list (nf v))]
    [(expr-pvec-pop v) (expr-pvec-pop (nf v))]
    [(expr-pvec-concat v1 v2) (expr-pvec-concat (nf v1) (nf v2))]
    [(expr-pvec-slice v lo hi) (expr-pvec-slice (nf v) (nf lo) (nf hi))]
    [(expr-pvec-fold f init vec) (expr-pvec-fold (nf f) (nf init) (nf vec))]
    [(expr-pvec-map f vec) (expr-pvec-map (nf f) (nf vec))]
    [(expr-pvec-filter pred vec) (expr-pvec-filter (nf pred) (nf vec))]
    [(expr-set-fold f init set) (expr-set-fold (nf f) (nf init) (nf set))]
    [(expr-set-filter pred set) (expr-set-filter (nf pred) (nf set))]
    [(expr-map-fold-entries f init map) (expr-map-fold-entries (nf f) (nf init) (nf map))]
    [(expr-map-filter-entries pred map) (expr-map-filter-entries (nf pred) (nf map))]
    [(expr-map-map-vals f map) (expr-map-map-vals (nf f) (nf map))]

    ;; Transient Builder normalization
    [(expr-transient c) (expr-transient (nf c))]
    [(expr-persist c) (expr-persist (nf c))]
    [(expr-TVec a) (expr-TVec (nf a))]
    [(expr-TMap k v) (expr-TMap (nf k) (nf v))]
    [(expr-TSet a) (expr-TSet (nf a))]
    [(expr-trrb _) e]
    [(expr-tchamp _) e]
    [(expr-thset _) e]
    [(expr-transient-vec v) (expr-transient-vec (nf v))]
    [(expr-persist-vec t) (expr-persist-vec (nf t))]
    [(expr-transient-map m) (expr-transient-map (nf m))]
    [(expr-persist-map t) (expr-persist-map (nf t))]
    [(expr-transient-set s) (expr-transient-set (nf s))]
    [(expr-persist-set t) (expr-persist-set (nf t))]
    [(expr-tvec-push! t x) (expr-tvec-push! (nf t) (nf x))]
    [(expr-tvec-update! t i x) (expr-tvec-update! (nf t) (nf i) (nf x))]
    [(expr-tmap-assoc! t k v) (expr-tmap-assoc! (nf t) (nf k) (nf v))]
    [(expr-tmap-dissoc! t k) (expr-tmap-dissoc! (nf t) (nf k))]
    [(expr-tset-insert! t a) (expr-tset-insert! (nf t) (nf a))]
    [(expr-tset-delete! t a) (expr-tset-delete! (nf t) (nf a))]

    ;; PropNetwork normalization
    ;; Type constructors and runtime wrappers are self-values
    [(expr-net-type) e]
    [(expr-cell-id-type) e]
    [(expr-prop-id-type) e]
    [(expr-prop-network _) e]
    [(expr-cell-id _) e]
    [(expr-prop-id _) e]
    ;; Operations: structural recursion into fields
    [(expr-net-new fuel) (expr-net-new (nf fuel))]
    [(expr-net-new-cell n init merge) (expr-net-new-cell (nf n) (nf init) (nf merge))]
    [(expr-net-new-cell-widen n init merge wf nf*) (expr-net-new-cell-widen (nf n) (nf init) (nf merge) (nf wf) (nf nf*))]
    [(expr-net-cell-read n cell) (expr-net-cell-read (nf n) (nf cell))]
    [(expr-net-cell-write n cell val) (expr-net-cell-write (nf n) (nf cell) (nf val))]
    [(expr-net-add-prop n ins outs fn) (expr-net-add-prop (nf n) (nf ins) (nf outs) (nf fn))]
    [(expr-net-run n) (expr-net-run (nf n))]
    [(expr-net-snapshot n) (expr-net-snapshot (nf n))]
    [(expr-net-contradiction n) (expr-net-contradiction (nf n))]

    ;; UnionFind: type constructor, wrapper, and uf-empty are self-values
    [(expr-uf-type) e]
    [(expr-uf-store _) e]
    [(expr-uf-empty) e]  ;; reduces to (expr-uf-store ...) in whnf, but if stuck, it's a value
    ;; Operations: structural recursion into fields
    [(expr-uf-make-set st id val) (expr-uf-make-set (nf st) (nf id) (nf val))]
    [(expr-uf-find st id) (expr-uf-find (nf st) (nf id))]
    [(expr-uf-union st id1 id2) (expr-uf-union (nf st) (nf id1) (nf id2))]
    [(expr-uf-value st id) (expr-uf-value (nf st) (nf id))]

    ;; Tabling: type constructor + runtime wrapper are self-values
    [(expr-table-store-type) e]
    [(expr-table-store-val _) e]
    ;; Operations: structural recursion into fields
    [(expr-table-new net) (expr-table-new (nf net))]
    [(expr-table-register st n m) (expr-table-register (nf st) (nf n) (nf m))]
    [(expr-table-add st n a) (expr-table-add (nf st) (nf n) (nf a))]
    [(expr-table-answers st n) (expr-table-answers (nf st) (nf n))]
    [(expr-table-freeze st n) (expr-table-freeze (nf st) (nf n))]
    [(expr-table-complete st n) (expr-table-complete (nf st) (nf n))]
    [(expr-table-run st) (expr-table-run (nf st))]
    [(expr-table-lookup st n a) (expr-table-lookup (nf st) (nf n) (nf a))]

    ;; Opaque FFI values are normal forms
    [(expr-opaque _ _) e]

    ;; Relational language (Phase 7)
    [(expr-solver-type) e] [(expr-goal-type) e] [(expr-derivation-type) e] [(expr-cut) e]
    [(expr-logic-var _ _) e]
    [(expr-answer-type t) (if t (expr-answer-type (nf t)) e)]
    [(expr-relation-type pts) (expr-relation-type (map nf pts))]
    [(expr-solver-config m) (expr-solver-config (nf m))]
    [(expr-defr nm sc vs) (expr-defr nm (and sc (nf sc)) (map nf vs))]
    [(expr-defr-variant ps bd) (expr-defr-variant ps (map nf bd))]
    [(expr-rel ps cls) (expr-rel ps (map nf cls))]
    [(expr-clause gs) (expr-clause (map nf gs))]
    [(expr-fact-block rs) (expr-fact-block (map nf rs))]
    [(expr-fact-row ts) (expr-fact-row (map nf ts))]
    [(expr-goal-app nm as) (expr-goal-app nm (map nf as))]  ;; nm is a symbol, not an expr
    [(expr-unify-goal l r) (expr-unify-goal (nf l) (nf r))]
    [(expr-is-goal v ex) (expr-is-goal (nf v) (nf ex))]
    [(expr-not-goal g) (expr-not-goal (nf g))]
    [(expr-guard cond goal) (expr-guard (nf cond) (and goal (nf goal)))]
    [(expr-solve g) (expr-solve (nf g))]
    [(expr-solve-with sv ov g) (expr-solve-with (and sv (nf sv)) (and ov (nf ov)) (nf g))]
    [(expr-solve-one g) (expr-solve-one (nf g))]
    [(expr-explain g) (expr-explain (nf g))]
    [(expr-explain-with sv ov g) (expr-explain-with (and sv (nf sv)) (and ov (nf ov)) (nf g))]
    [(expr-narrow func args target vars)
     (expr-narrow (nf func) (map nf args) (nf target) vars)]

    ;; Foreign function: opaque leaf (already in WHNF)
    [(expr-foreign-fn _ _ _ _ _ _ _ _) e]

    ;; Union types: normalize components
    [(expr-union l r) (expr-union (nf l) (nf r))]

    ;; Reduce: if we reach here, whnf couldn't fire any arm (scrutinee is stuck).
    ;; Only normalize the scrutinee. Do NOT normalize arm bodies — they may
    ;; contain recursive function calls that produce infinite unfolding when
    ;; the scrutinee is neutral (e.g., an unresolvable fvar). Since no arm
    ;; will be selected, normalizing arm bodies is wasteful and risks divergence.
    [(expr-reduce scrut arms structural?)
     (expr-reduce (nf scrut) arms structural?)]))

;; ========================================
;; Definitional Equality (conversion)
;; Two terms are definitionally equal iff their normal forms
;; are syntactically identical.
;; (#:transparent structs give us deep structural equal?)
;; ========================================
(define (conv e1 e2)
  (conv-nf (nf e1) (nf e2)))

;; Deep structural equality with hole-as-wildcard.
;; expr-hole on either side matches anything.
;; Uses struct->vector for generic traversal of #:transparent structs.
(define (conv-nf a b)
  (cond
    [(expr-hole? a) #t]
    [(expr-hole? b) #t]
    [(expr-typed-hole? a) #t]
    [(expr-typed-hole? b) #t]
    ;; Unsolved metavariables: equal only if same ID
    ;; (solved metas are already eliminated by nf→whnf)
    [(expr-meta? a)
     (and (expr-meta? b) (eq? (expr-meta-id a) (expr-meta-id b)))]
    [(expr-meta? b) #f]
    ;; D4.P4d slice 0: unions are SET-LIKE in this system's definitional
    ;; equality — unify's own union path (`classify-whnf-problem` routes
    ;; union×union to `unify-union-components`, which SORTS and DEDUPS), so
    ;; `<Int|String>` ≡ `<String|Int>` and `<Int|Int|String>` ≡ `<Int|String>`.
    ;; The generic struct arm below compared union spines POSITIONALLY,
    ;; disagreeing with the engine's own equality (caught by the slice-0
    ;; adversarial verify: the pvec-literal probe's conv leg reclassified
    ;; spelled-differently union pairs as heterogeneous). Mutual containment
    ;; under conv-nf itself — no sort key needed, unions are tiny. Union vs
    ;; NON-union deliberately stays with the struct arm (#f): unify's classify
    ;; sends that pair to its conv fallback too (the flavor-B widen case is
    ;; deferred there), so the two equalities agree in BOTH directions.
    [(and (expr-union? a) (expr-union? b))
     (let ([as (flatten-union a)] [bs (flatten-union b)])
       (and (for/and ([x (in-list as)])
              (for/or ([y (in-list bs)]) (conv-nf x y)))
            (for/and ([y (in-list bs)])
              (for/or ([x (in-list as)]) (conv-nf x y)))))]
    [(and (struct? a) (struct? b))
     (let ([va (struct->vector a)]
           [vb (struct->vector b)])
       (and (eq? (vector-ref va 0) (vector-ref vb 0))     ; same struct type
            (= (vector-length va) (vector-length vb))
            (for/and ([i (in-range 1 (vector-length va))]) ; skip struct-name at 0
              (conv-nf (vector-ref va i) (vector-ref vb i)))))]
    [else (equal? a b)]))

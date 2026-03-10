#lang racket/base

;;;
;;; PROLOGOS ELABORATOR
;;; Transforms surface AST (named variables) to core AST (de Bruijn indices).
;;; Performs name resolution, scope checking, and desugaring.
;;;

(require racket/match
         racket/list
         racket/string
         "prelude.rkt"
         "syntax.rkt"
         "source-location.rkt"
         "surface-syntax.rkt"
         "errors.rkt"
         "global-env.rkt"
         "namespace.rkt"
         "metavar-store.rkt"
         "pretty-print.rkt"
         "performance-counters.rkt"
         "multi-dispatch.rkt"
         "foreign.rkt"
         "posit-impl.rkt"
         "champ.rkt"
         "macros.rkt"             ;; Phase C: for lookup-trait (trait constraint detection)
         "substitution.rkt"      ;; Phase C: for subst (Pi codomain substitution)
         "warnings.rkt"          ;; Phase 2: for capability warnings (W2001)
         "sessions.rkt"          ;; Phase S3: session type constructors (elaboration target)
         "processes.rkt")        ;; Phase S3: process constructors (elaboration target)

(provide elaborate
         elaborate-top-level
         ;; Relational scoping (Phase 7)
         current-relational-env
         ;; Phase D: method name resolution in bodies
         where-method-entry
         where-method-entry?
         where-method-entry-method-name
         where-method-entry-accessor-name
         where-method-entry-trait-name
         where-method-entry-type-var-names
         where-method-entry-dict-param-name
         current-where-context
         is-dict-param-name?
         parse-dict-param-name
         dict-param->where-entries
         resolve-method-from-where
         ;; HKT-9: Constraint inference from usage
         current-infer-constraints-mode?
         build-method-reverse-index
         method-reverse-index-entry
         method-reverse-index-entry?
         method-reverse-index-entry-trait-name
         method-reverse-index-entry-method-name
         method-reverse-index-entry-accessor-name
         method-reverse-index-entry-trait-params)

;; ========================================
;; Relational scoping context
;; ========================================
;; When inside a defr variant or solve/explain goal, logic variables from
;; the param list are in scope. They resolve to expr-logic-var nodes, not
;; de Bruijn bvars. This parameter holds a hasheq: symbol → expr-logic-var.
(define current-relational-env (make-parameter #f))

;; When #t, unresolved variables in relational context become free logic
;; variables (expr-logic-var with mode 'free) instead of "Unbound variable"
;; errors. Used by solve/explain to allow query variables.
(define current-relational-fallback? (make-parameter #f))

;; ========================================
;; Elaboration environment
;; ========================================
;; An environment is a list of (cons name depth) pairs, most recent first.
;; When we look up a name at current depth D, we find its binding depth BD,
;; and the de Bruijn index is D - BD - 1.

;; Lookup a name in the environment, returning de Bruijn index or #f
(define (env-lookup env name depth)
  (cond
    [(null? env) #f]
    [(eq? (caar env) name)
     (- depth (cdar env) 1)]
    [else (env-lookup (cdr env) name depth)]))

;; Extend environment with a new binding
(define (env-extend env name depth)
  (cons (cons name depth) env))

;; Sprint 9: Convert elaborator env to a de Bruijn name stack for error messages.
;; The env stores (name . depth), most recent first — same order as pp-expr's names.
(define (env->name-stack env)
  (map (lambda (pair) (symbol->string (car pair))) env))

;; ========================================
;; Phase D: Method name resolution in bodies
;; ========================================
;; When a function has `where (Eq A)`, the elaborator detects the dict param
;; `$Eq-A` and populates a context so bare method names like `eq?` resolve
;; to partially-applied accessor calls: (Eq-eq? A $Eq-A).

(struct where-method-entry
  (method-name      ;; symbol — bare method name, e.g., 'eq?
   accessor-name    ;; symbol — full accessor name, e.g., 'Eq-eq?
   trait-name       ;; symbol — the trait, e.g., 'Eq
   type-var-names   ;; (listof symbol) — type params, e.g., '(A)
   dict-param-name  ;; symbol — dict param name, e.g., '$Eq-A
  ) #:transparent)

;; Active where-constraint context for method name resolution.
;; Populated when entering lambda bodies whose binders are dict params.
(define current-where-context (make-parameter '()))

;; Check if a symbol looks like a dict param name: starts with $
(define (is-dict-param-name? name)
  (let ([s (symbol->string name)])
    (and (> (string-length s) 1)
         (char=? (string-ref s 0) #\$))))

;; Parse a dict param name into trait name + type var names.
;; "$Eq-A" → (list 'Eq 'A)
;; "$Convertible-A-B" → (list 'Convertible 'A 'B)
;; Tries progressively longer hyphen-joined prefixes as the trait name.
;; Returns (cons trait-name type-var-names) or #f.
(define (parse-dict-param-name name)
  (define parts (string-split (substring (symbol->string name) 1) "-"))
  (let loop ([n 1])
    (cond
      [(> n (length parts)) #f]
      [else
       (define trait-sym (string->symbol (string-join (take parts n) "-")))
       (if (lookup-trait trait-sym)
           (let ([tvs (drop parts n)])
             (if (null? tvs) #f
                 (cons trait-sym (map string->symbol tvs))))
           (loop (add1 n)))])))

;; Build where-method-entry list from a dict param name. Returns list or #f.
(define (dict-param->where-entries dict-param-name)
  (define parsed (parse-dict-param-name dict-param-name))
  (if (not parsed)
      #f
      (let ([trait-name (car parsed)]
            [type-var-names (cdr parsed)])
        (define tm (lookup-trait trait-name))
        (if (not tm)
            #f
            (for/list ([method (in-list (trait-meta-methods tm))])
              (where-method-entry
                (trait-method-name method)
                (string->symbol
                 (string-append (symbol->string trait-name)
                                "-"
                                (symbol->string (trait-method-name method))))
                trait-name type-var-names dict-param-name))))))

;; Resolve a bare method name to a partially-applied accessor expression
;; using the active where-context.
;; Returns an expr, a prologos-error, or #f.
(define (resolve-method-from-where name env depth)
  (define ctx (current-where-context))
  ;; Find all matching entries (for ambiguity detection)
  (define matches
    (filter (lambda (e) (eq? (where-method-entry-method-name e) name)) ctx))
  (cond
    [(null? matches) #f]
    [(> (length matches) 1)
     ;; Ambiguous: same method name in multiple traits
     (ambiguous-method-error #f
       (format "Ambiguous method '~a'" name)
       name (map where-method-entry-trait-name matches))]
    [else
     (define entry (car matches))
     (define accessor-name (where-method-entry-accessor-name entry))
     (define dict-param-name (where-method-entry-dict-param-name entry))
     (cond
       ;; Phase 3a: Direct HasMethod evidence — the param IS the method function
       [(not accessor-name)
        (define dict-idx (env-lookup env dict-param-name depth))
        (and dict-idx (expr-bvar dict-idx))]
       ;; Standard accessor-based resolution
       [else
        (define type-var-names (where-method-entry-type-var-names entry))
        ;; Look up de Bruijn indices for type vars and dict param
        (define tv-indices
          (for/list ([tv (in-list type-var-names)])
            (env-lookup env tv depth)))
        (define dict-idx (env-lookup env dict-param-name depth))
        ;; All must be found in the environment
        (if (and (andmap (lambda (x) x) tv-indices) dict-idx)
            ;; Build: (app ... (app (fvar accessor) (bvar tv1)) ... (bvar dict))
            (let* ([base (expr-fvar accessor-name)]
                   [with-types
                    (foldl (lambda (idx acc) (expr-app acc (expr-bvar idx)))
                           base tv-indices)]
                   [with-dict (expr-app with-types (expr-bvar dict-idx))])
              with-dict)
            ;; Type vars or dict not in scope — fall through
            #f)])]))

;; ========================================
;; HKT-9: Constraint inference from usage
;; ========================================
;; When enabled, bare trait method names (like `eq?`, `to-seq`) that are
;; NOT in the current where-context can trigger automatic constraint generation.
;; This is gated behind a feature flag because no mainstream language does this
;; and it adds complexity to the elaboration process.

;; Feature flag — off by default. Enable with (current-infer-constraints-mode? #t).
(define current-infer-constraints-mode? (make-parameter #f))

;; Reverse index entry: method-name → trait info
(struct method-reverse-index-entry
  (trait-name       ;; symbol — e.g., 'Eq
   method-name      ;; symbol — e.g., 'eq?
   accessor-name    ;; symbol — e.g., 'Eq-eq?
   trait-params     ;; list of (name . kind-datum) pairs from trait-meta-params
  ) #:transparent)

;; Build a reverse index from method names → list of traits that define them.
;; Uses the current trait registry. Returns a hasheq: symbol → (listof method-reverse-index-entry).
(define (build-method-reverse-index)
  (for/fold ([idx (hasheq)])
            ([(trait-name tm) (in-hash (current-trait-registry))])
    (for/fold ([idx idx])
              ([method (in-list (trait-meta-methods tm))])
      (define mname (trait-method-name method))
      (define accessor-name
        (string->symbol
          (string-append (symbol->string trait-name)
                         "-"
                         (symbol->string mname))))
      (define entry
        (method-reverse-index-entry trait-name mname accessor-name
                                     (trait-meta-params tm)))
      (hash-set idx mname
        (cons entry (hash-ref idx mname '()))))))

;; Try to generate a constraint from a bare method name.
;; Returns an expr (the resolved accessor application) or #f.
;; This is called when:
;;   1. current-infer-constraints-mode? is #t
;;   2. The name wasn't found in env, global env, or where-context
;;   3. The name exists in the method reverse index
;;
;; For now, this is a minimal implementation that only works when the
;; method maps to exactly one trait (no ambiguity). It creates fresh metas
;; for the type variables and a dict meta, registers the trait constraint,
;; and returns the accessor expression applied to those metas.
(define (try-infer-constraint-from-method name loc env depth)
  (define idx (build-method-reverse-index))
  (define entries (hash-ref idx name #f))
  (cond
    [(not entries) #f]
    [(null? entries) #f]
    [(> (length entries) 1)
     ;; Ambiguous — same method name in multiple traits
     (ambiguous-method-error loc
       (format "Ambiguous method '~a' found in traits: ~a. Use a spec with explicit where-clause."
               name
               (string-join (map (lambda (e) (symbol->string (method-reverse-index-entry-trait-name e)))
                                 entries)
                            ", "))
       name (map method-reverse-index-entry-trait-name entries))]
    [else
     ;; Unique match — generate constraint
     (define entry (car entries))
     (define trait-name (method-reverse-index-entry-trait-name entry))
     (define accessor-name (method-reverse-index-entry-accessor-name entry))
     (define trait-params (method-reverse-index-entry-trait-params entry))
     ;; Create fresh metas for each trait type parameter
     (define type-var-metas
       (for/list ([p (in-list trait-params)])
         (fresh-meta ctx-empty (expr-hole)
           (meta-source-info loc 'inferred-type-var
             (format "inferred type var for ~a from method ~a" trait-name name)
             #f (env->name-stack env)))))
     ;; Create a fresh meta for the dict parameter
     (define dict-meta
       (fresh-meta ctx-empty (expr-hole)
         (meta-source-info loc 'trait-constraint
           (format "inferred ~a constraint from method ~a" trait-name name)
           #f (env->name-stack env))))
     ;; Register the trait constraint
     (register-trait-constraint!
       (expr-meta-id dict-meta)
       (trait-constraint-info trait-name type-var-metas))
     ;; Build the accessor application: (Trait-method TypeVar1 ... DictMeta)
     (let* ([base (expr-fvar accessor-name)]
            [with-types
             (foldl (lambda (m acc) (expr-app acc m))
                    base type-var-metas)]
            [with-dict (expr-app with-types dict-meta)])
       with-dict)]))

;; ========================================
;; Implicit argument helpers
;; ========================================

;; Walk a core Pi chain and collect the multiplicity of each binder.
;; Returns a list of multiplicities ('m0 or 'mw).
(define (collect-pi-mults type)
  (match type
    [(expr-Pi m _ cod) (cons m (collect-pi-mults cod))]
    [_ '()]))

;; Count leading m0 (implicit/erased) parameters.
(define (leading-m0-count mults)
  (length (takef mults (lambda (m) (eq? m 'm0)))))

;; ========================================
;; Trait constraint detection helpers (Phase C)
;; ========================================

;; Extract the head of a core expression (strips applications).
;; (app (app (fvar 'Eq) X) Y) → (fvar 'Eq)
(define (expr-head e)
  (match e
    [(expr-app f _) (expr-head f)]
    [_ e]))

;; Decompose a core expression into head and arguments.
;; (app (app (fvar 'Eq) X) Y) → (values (fvar 'Eq) (list X Y))
(define (decompose-app-acc e acc)
  (match e
    [(expr-app f a) (decompose-app-acc f (cons a acc))]
    [_ (values e acc)]))

;; Check if a core type expression is a trait application.
;; A type is a trait application if its head is an fvar whose name
;; is registered as a trait in the trait registry.
(define (is-trait-type? dom)
  (define head (expr-head dom))
  (and (expr-fvar? head)
       (lookup-trait (expr-fvar-name head))
       #t))

;; Decompose a trait type into its trait name and type argument expressions.
;; (app (fvar 'Eq) (fvar 'Nat)) → (values 'Eq (list (fvar 'Nat)))
(define (decompose-trait-type dom)
  (define-values (head args) (decompose-app-acc dom '()))
  (values (expr-fvar-name head) args))

;; Insert N implicit metas for a function, walking the Pi chain to detect
;; and tag trait-constraint metas. Uses substitution to correctly compute
;; codomain types as each meta is created.
;; Returns the expression with N implicit args applied.
;;
;; Trait constraint detection strategy:
;; 1. First check is-trait-type? on the Pi domain (works for multi-method traits).
;; 2. If that fails, check if the function has a spec with where-constraints.
;;    For a function with N m0 binders and C where-constraints, the last C
;;    m0 binders are trait constraint params (the first N-C are type variable binders).
;;
;; Phase 4: Capability constraint resolution:
;; 3. If the domain is a capability type (neither trait nor type variable),
;;    search current-capability-scope for a matching binding and resolve eagerly.
;;    If no match, tag as capability-constraint-info for E2001 error reporting.
(define (insert-implicits-with-tagging base-expr func-type n-holes fname loc env
                                       #:depth [current-depth 0]
                                       #:default-kind [default-kind 'implicit-app])
  ;; Look up spec where-constraints for position-based trait detection.
  ;; The function name may be namespace-qualified (e.g., 'ns::my-neq),
  ;; but specs are registered with bare names. Strip the NS prefix.
  (define bare-fname
    (let ([s (symbol->string fname)])
      (define idx (let loop ([i (- (string-length s) 1)])
                    (cond [(< i 1) #f]
                          [(and (char=? (string-ref s i) #\:)
                                (char=? (string-ref s (sub1 i)) #\:))
                           i]
                          [else (loop (sub1 i))])))
      (if idx (string->symbol (substring s (add1 idx))) fname)))
  (define spec-entry (lookup-spec bare-fname))
  (define where-constraints
    (if (and spec-entry (spec-entry? spec-entry))
        (spec-entry-where-constraints spec-entry)
        '()))
  (define n-constraints (length where-constraints))
  ;; Trait constraint positions: the last n-constraints of the n-holes implicit metas.
  ;; Position index starts at 0 for the first m0 binder.
  ;; Positions [n-holes - n-constraints, n-holes) are trait constraints.
  (define constraint-start (- n-holes n-constraints))
  ;; Collect type-variable metas by position for spec-based constraint type-arg lookup.
  ;; The first (n-holes - n-constraints) m0 binders are type variables;
  ;; the last n-constraints are trait constraints.
  (define type-var-metas (make-vector (max 0 constraint-start) #f))
  ;; Build name→position mapping from implicit binders for constraint type-arg resolution.
  ;; E.g., for spec {A : Type} {C : Type -> Type} (Seqable C) -> ...,
  ;; implicit-binder-names = (A C), so type-var-name→pos = {A → 0, C → 1}.
  ;; This is critical for HKT: constraint (Seqable C) must map C to position 1 (not 0).
  (define type-var-name->pos
    (if (and spec-entry (spec-entry? spec-entry)
             (spec-entry-implicit-binders spec-entry))
        (let ([ib (spec-entry-implicit-binders spec-entry)])
          (for/hasheq ([bp (in-list ib)]
                       [i (in-naturals)])
            (values (car bp) i)))
        (hasheq)))
  (let loop ([acc base-expr] [ty func-type] [remaining n-holes] [pos 0])
    (cond
      [(zero? remaining) acc]
      [(expr-Pi? ty)
       (define dom (expr-Pi-domain ty))
       (define cod (expr-Pi-codomain ty))
       ;; Is this position a trait constraint?
       ;; Method 1: domain type is a trait application (works for multi-method traits)
       ;; Method 2: position matches where-constraint index (works for single-method traits too)
       (define constraint-idx (- pos constraint-start))
       (define trait-from-dom? (is-trait-type? dom))
       (define trait-from-spec? (and (>= constraint-idx 0)
                                     (< constraint-idx n-constraints)))
       (define trait? (or trait-from-dom? trait-from-spec?))
       (define meta-expr
         (fresh-meta ctx-empty (expr-hole)
           (meta-source-info loc
             (if trait? 'trait-constraint default-kind)
             (format "implicit argument for ~a" fname)
             #f (env->name-stack env))))
       ;; Track type-variable metas by position
       (when (< pos constraint-start)
         (vector-set! type-var-metas pos meta-expr))
       ;; Tag trait constraints in the auxiliary map
       (when trait?
         (cond
           ;; From domain type: decompose the application to get trait name + type args
           [trait-from-dom?
            (define-values (trait-name type-args) (decompose-trait-type dom))
            (register-trait-constraint!
              (expr-meta-id meta-expr)
              (trait-constraint-info trait-name type-args))]
           ;; From spec position: use the where-constraint to get trait name + type arg metas
           ;; The where-constraint is e.g. (Eq A) — trait name 'Eq, type vars '(A).
           ;; The type vars correspond to auto-implicit positions.
           ;; Simple approach: for (Eq A), the type arg is the meta at position 0 (first type var).
           ;; For (Eq A, Ord B), the first constraint has type arg at pos 0, second at pos 1.
           [trait-from-spec?
            (define wc (list-ref where-constraints constraint-idx))
            (cond
              ;; Phase 3a: HasMethod constraint marker — (HasMethod trait-var method-name)
              ;; Register hasmethod-constraint-info instead of trait-constraint-info.
              ;; The evidence meta will be solved by resolve-hasmethod-constraints! after
              ;; the trait variable P is unified with a concrete trait.
              [(and (pair? wc) (eq? (car wc) 'HasMethod))
               (define hm-trait-var-name (cadr wc))
               (define hm-method-name (caddr wc))
               ;; Get the trait variable meta from type-var-metas
               (define trait-var-pos (hash-ref type-var-name->pos hm-trait-var-name #f))
               (define trait-var-meta
                 (and trait-var-pos
                      (< trait-var-pos (vector-length type-var-metas))
                      (vector-ref type-var-metas trait-var-pos)))
               ;; Get type arg metas (all type vars except the trait var)
               (define type-arg-metas
                 (for/list ([i (in-range (vector-length type-var-metas))]
                            #:when (not (equal? i trait-var-pos)))
                   (vector-ref type-var-metas i)))
               (when trait-var-meta
                 (register-hasmethod-constraint!
                   (expr-meta-id meta-expr)
                   (hasmethod-constraint-info
                     trait-var-meta
                     hm-method-name
                     type-arg-metas
                     #f)))]  ;; dict-meta-id: not needed, resolve via impl registry
              [else
               ;; Standard trait constraint — (Eq A), (Seqable C), etc.
               (define trait-name (car wc))
               (define type-var-names (cdr wc))
               ;; Map each type var name to its corresponding meta using name→position mapping.
               ;; For (Seqable C) with {A : Type} {C : Type -> Type}, C maps to position 1.
               ;; Falls back to positional index if name not found (backward compatibility).
               (define type-arg-metas
                 (for/list ([tv-name (in-list type-var-names)]
                            [i (in-naturals)])
                   (define pos (hash-ref type-var-name->pos tv-name #f))
                   (define effective-pos (or pos i))
                   (if (< effective-pos (vector-length type-var-metas))
                       (vector-ref type-var-metas effective-pos)
                       (expr-hole))))  ;; shouldn't happen — fallback
               (register-trait-constraint!
                 (expr-meta-id meta-expr)
                 (trait-constraint-info trait-name type-arg-metas))])]))
       ;; Phase 4/7: Capability constraint resolution (lexical scope)
       ;; If the domain is a capability type (not a trait), try to resolve from scope.
       ;; Phase 7: handles both simple caps (ReadCap) and dependent caps (FileCap "/data").
       ;; Resolution is by functor name — the type checker verifies indices.
       (let ([cap-name (capability-type-expr? dom)])
         (when (and (not trait?) cap-name)
           (define scope (current-capability-scope))
           ;; Search scope: prefer exact functor match, then subtype match.
           ;; Scope entries are (cons depth type-expr) where type-expr may be
           ;; an fvar (simple cap) or expr-app chain (dependent cap).
           (define exact-depth
             (for/or ([entry (in-list scope)])
               (define entry-name (capability-type-expr? (cdr entry)))
               (and entry-name (eq? cap-name entry-name) (car entry))))
           (cond
             [exact-depth
              ;; Functor match — solve meta to the capability binding.
              ;; De Bruijn index: current-depth - intro-depth - 1
              (define bvar-idx (- current-depth exact-depth 1))
              (solve-meta! (expr-meta-id meta-expr) (expr-bvar bvar-idx))]
             [(find-capability-in-scope dom scope)
              ;; Subtype match — capability IS available via a supertype in scope.
              ;; Leave meta unsolved: type checker accepts (expr-meta) optimistically,
              ;; QTT assigns zero usage (:0 erased), zonk-final leaves as-is.
              (void)]
             [else
              ;; No capability in scope — tag for E2001 error reporting.
              (register-capability-constraint!
                (expr-meta-id meta-expr)
                (capability-constraint-info cap-name dom))])))
       ;; Substitute meta into codomain for next iteration
       ;; (shift and replace de Bruijn index 0 with the new meta)
       (define next-ty (subst 0 meta-expr cod))
       (loop (expr-app acc meta-expr) next-ty (sub1 remaining) (add1 pos))]
      [else
       ;; Type isn't a Pi — shouldn't happen, but safe fallback
       (for/fold ([a acc]) ([_ (in-range remaining)])
         (expr-app a (fresh-meta ctx-empty (expr-hole)
                       (meta-source-info loc default-kind
                         (format "implicit argument for ~a" fname)
                         #f (env->name-stack env)))))])))

;; Auto-apply holes for a bare variable whose type has ALL m0 parameters.
;; e.g., nil : Pi(A :0 Type 0, List A) → (app (fvar nil) hole)
;; Only applies when ALL Pi binders are m0 (fully implicit).
;; For mixed types (like cons : Pi(A :0 Type 0, A -> List A -> List A)),
;; we don't auto-apply — the user must use application syntax.
(define (maybe-auto-apply-implicits fvar-expr resolved-name loc env depth)
  (define ftype (global-env-lookup-type resolved-name))
  (if ftype
      (let ([mults (collect-pi-mults ftype)])
        (if (and (not (null? mults))
                 (andmap (lambda (m) (eq? m 'm0)) mults))
            ;; All params are implicit → auto-apply with Pi-chain-walking tagging
            (insert-implicits-with-tagging fvar-expr ftype (length mults)
                                           resolved-name loc env
                                           #:depth depth
                                           #:default-kind 'implicit)
            fvar-expr))
      fvar-expr))

;; Given a function's global type and the number of user-supplied args,
;; return the number of implicit holes to prepend (or 0 if no insertion needed).
;; Rules:
;;   - total-arity = length of Pi chain
;;   - n-implicit = count of leading m0 binders
;;   - n-explicit = total-arity - n-implicit
;;   - If user provides n-explicit args → prepend n-implicit holes
;;   - If user provides total-arity args → no insertion (backward compat)
;;   - Otherwise → no insertion (let type checker report arity error)
;; Count "implicit" params for a function: leading m0 binders PLUS
;; any immediately following where-constraint params (which may be mw).
;; The fname is used to look up the spec's where-constraints.
(define (implicit-param-count func-type fname)
  (define mults (collect-pi-mults func-type))
  (define n-m0 (leading-m0-count mults))
  ;; Check if function has spec with where-constraints
  (define bare-name
    (let ([s (symbol->string fname)])
      (define idx (let loop ([i (- (string-length s) 1)])
                    (cond [(< i 1) #f]
                          [(and (char=? (string-ref s i) #\:)
                                (char=? (string-ref s (sub1 i)) #\:))
                           i]
                          [else (loop (sub1 i))])))
      (if idx (string->symbol (substring s (add1 idx))) fname)))
  (define spec (lookup-spec bare-name))
  (define n-constraints
    (if (and spec (spec-entry? spec))
        (length (spec-entry-where-constraints spec))
        0))
  ;; Total implicit: leading m0 binders + where-constraint params that follow
  ;; (The where-constraints follow the auto-implicit type vars)
  (+ n-m0 n-constraints))

(define (implicit-holes-needed func-type n-user-args [fname #f])
  (define mults (collect-pi-mults func-type))
  (define total (length mults))
  (define n-m0 (leading-m0-count mults))
  (define n-imp
    (if fname
        (implicit-param-count func-type fname)
        n-m0))
  (define n-exp (- total n-imp))
  ;; Three valid argument counts:
  ;; 1. total: user provides everything → no insertion
  ;; 2. total - n-imp: user provides only explicit args → insert all implicit (m0 + where-constraints)
  ;; 3. total - n-m0: user provides explicit + dict args → insert only m0 type-var binders
  ;;    (only when n-imp > n-m0, i.e., there are where-constraints beyond type vars)
  (cond
    [(= n-user-args total) 0]         ; user gave all args → backward compat, no insertion
    [(and (> n-imp 0)                 ; has implicit params
          (= n-user-args n-exp))      ; user gave explicit-only count
     n-imp]                           ; → insert all implicits (type vars + constraint dicts)
    [(and (> n-imp n-m0)              ; has where-constraints beyond leading m0
          (= n-user-args (- total n-m0)))  ; user gave explicit + dict args
     n-m0]                            ; → insert only type-var m0 binders
    [else 0]))                        ; mismatch → don't insert, let checker error

;; ========================================
;; Arity checking helpers
;; ========================================

;; Count explicit (non-m0) parameters in a Pi chain.
(define (count-explicit-params type)
  (match type
    [(expr-Pi m _ cod)
     (if (eq? m 'm0)
         (count-explicit-params cod)
         (add1 (count-explicit-params cod)))]
    [_ 0]))

;; Count total parameters (implicit + explicit) in a Pi chain.
(define (total-params type)
  (match type
    [(expr-Pi _ _ cod) (add1 (total-params cod))]
    [_ 0]))

;; ========================================
;; Varargs: build surface-level list literal from excess args
;; ========================================
;; Constructs nested cons/nil at the surface level:
;;   (make-varargs-list-literal (list a b c) loc)
;;   → (surf-app cons (list a (surf-app cons (list b (surf-app cons (list c (surf-var nil)))))))
;; The elaborator will insert implicit type args for cons/nil automatically.
(define (make-varargs-list-literal surf-args loc)
  (foldr (lambda (arg rest)
           (surf-app (surf-var 'cons loc) (list arg rest) loc))
         (surf-var 'nil loc)
         surf-args))

;; Check if a function name has a variadic spec (rest-type non-#f).
;; Strips namespace prefix to find the bare name for lookup.
(define (varargs-spec-info fname)
  (define bare-name
    (let ([s (symbol->string fname)])
      (define idx (let loop ([i (- (string-length s) 1)])
                    (cond [(< i 1) #f]
                          [(and (char=? (string-ref s i) #\:)
                                (char=? (string-ref s (sub1 i)) #\:))
                           i]
                          [else (loop (sub1 i))])))
      (if idx (string->symbol (substring s (add1 idx))) fname)))
  (define spec (lookup-spec bare-name))
  (and spec (spec-entry? spec) (spec-entry-rest-type spec) spec))

;; ========================================
;; Main elaboration: surface -> core
;; ========================================

;; Resolve a surf-var to a core expression.
;; When auto-apply? is #t and the global has ALL m0 params, auto-apply with holes.
;; When auto-apply? is #f (function position), just return the fvar.
(define (elaborate-var name loc env depth auto-apply?)
  (let ([idx (env-lookup env name depth)])
    (cond
      [idx (expr-bvar idx)]
      ;; Relational context: logic variable from defr params or solve query
      [(and (current-relational-env)
            (hash-ref (current-relational-env) name #f))
       => (lambda (lv) lv)]
      ;; Relational fallback: when inside solve/explain/defr goals, bare names
      ;; become free logic variables — even if they happen to be bound in the
      ;; global env (e.g., prelude's `code` from char module).
      ;; This must come BEFORE global env resolution because in relational context
      ;; `(...)` contains logic variables by default. To reference a global value
      ;; inside a relational goal, use `[...]` (functional expression) or `is`.
      [(current-relational-fallback?)
       (expr-logic-var name 'free)]
      ;; Own-namespace definition takes priority over imports (including prelude).
      ;; This ensures `def map ...` in `ns foo` resolves to `foo::map`, not the
      ;; prelude's `prologos::data::list::map`.
      [(and (current-ns-context)
            (let ([own-fqn (qualify-name name
                             (ns-context-current-ns (current-ns-context)))])
              (and (global-env-lookup-type own-fqn) own-fqn)))
       => (lambda (own-fqn)
            (if auto-apply?
                (maybe-auto-apply-implicits (expr-fvar own-fqn) own-fqn loc env depth)
                (expr-fvar own-fqn)))]
      ;; Phase D: resolve bare trait method names from where-context.
      ;; This MUST come before namespace/global resolution so that `add` inside
      ;; a `where (Add A)` body resolves through the dict parameter, not the
      ;; concrete global `prologos::data::nat::add`.
      [(resolve-method-from-where name env depth)
       => (lambda (resolved) resolved)]
      ;; When namespace context is active, try FQN resolution (imports, refer-map).
      [(and (current-ns-context)
            (let ([resolved (resolve-name name (current-ns-context))])
              (and resolved
                   (not (eq? resolved name))
                   (global-env-lookup-type resolved)
                   resolved)))
       => (lambda (resolved)
            (if auto-apply?
                (maybe-auto-apply-implicits (expr-fvar resolved) resolved loc env depth)
                (expr-fvar resolved)))]
      ;; Fall back to bare name
      [(global-env-lookup-type name)
       (if auto-apply?
           (maybe-auto-apply-implicits (expr-fvar name) name loc env depth)
           (expr-fvar name))]
      ;; Multi-body function: base name exists in dispatch registry but not in global env.
      ;; Must be applied (bare reference is ambiguous — which arity?).
      [(lookup-multi-defn name)
       => (lambda (info)
            (prologos-error loc
              (format "Multi-body function '~a' must be applied; available arities: ~a"
                      name (string-join (map number->string (multi-defn-info-arities info)) ", "))))]
      ;; HKT-9: Constraint inference from usage (feature-flagged)
      ;; If enabled, try to resolve the name as a trait method and generate
      ;; a constraint automatically. This is gated by current-infer-constraints-mode?.
      [(and (current-infer-constraints-mode?)
            (try-infer-constraint-from-method name loc env depth))
       => (lambda (resolved) resolved)]
      [else (unbound-variable-error loc "Unbound variable" name)])))

;; elaborate: surface-expr, env, depth -> (or/c expr? prologos-error?)
(define (elaborate surf [env '()] [depth 0])
  (perf-inc-elaborate!)
  (match surf
    ;; Variable: look up name, compute de Bruijn index
    ;; For globals with ALL-implicit type params (e.g., nil : Pi(A :0 Type). List A),
    ;; auto-apply with holes so bare `nil` becomes `(nil _)`.
    ;; This auto-apply is suppressed when the var is in function position of surf-app.
    [(surf-var name loc)
     (elaborate-var name loc env depth #t)]

    ;; Nat literal: native O(1) representation
    [(surf-nat-lit n loc)
     (expr-nat-val n)]

    ;; Constants
    [(surf-zero _) (expr-nat-val 0)]
    [(surf-suc pred loc)
     (let ([e (elaborate pred env depth)])
       (cond
         [(prologos-error? e) e]
         [(expr-nat-val? e) (expr-nat-val (+ (expr-nat-val-n e) 1))]
         [else (expr-suc e)]))]  ;; symbolic: suc of bound variable
    [(surf-true _) (expr-true)]
    [(surf-false _) (expr-false)]
    [(surf-unit _) (expr-unit)]
    ;; nil: overloaded — if the list nil constructor is registered, elaborate as fvar
    ;; (preserving auto-implicit application: bare nil → (nil _)). Otherwise, use expr-nil.
    [(surf-nil loc)
     (if (global-env-lookup-type 'nil)
         (elaborate-var 'nil loc env depth #t)
         (expr-nil))]
    [(surf-refl _) (expr-refl)]
    [(surf-nat-type _) (expr-Nat)]
    [(surf-bool-type _) (expr-Bool)]
    [(surf-unit-type _) (expr-Unit)]
    [(surf-nil-type _) (expr-Nil)]

    ;; Type hole (inferred during checking)
    [(surf-hole loc)
     (expr-hole)]

    ;; Typed hole (?? or ??name — reports expected type)
    [(surf-typed-hole name _)
     (expr-typed-hole name)]

    ;; Type universe — Sprint 6: #f means infer level
    [(surf-type n loc)
     (if n
         (expr-Type (nat->level n))
         (expr-Type (fresh-level-meta (meta-source-info loc 'bare-Type "universe level" #f #f))))]

    ;; Arrow (non-dependent): (-> A B) -> Pi(mw, elab-A, elab-B-shifted)
    ;; Pi introduces a binder, so codomain is under a binder even for arrows.
    ;; We elaborate B at depth+1 (under a dummy binding) so that references
    ;; to outer variables get the correct de Bruijn indices.
    [(surf-arrow raw-mult dom cod loc)
     (let* ([m (or raw-mult 'mw)]  ;; #f defaults to unrestricted
            [a (elaborate dom env depth)]
            [b (elaborate cod env (+ depth 1))])
       (cond
         [(prologos-error? a) a]
         [(prologos-error? b) b]
         [else (expr-Pi m a b)]))]

    ;; Pi type: (Pi (x :m A) B) -> Pi(m, elab-A, elab-B) with x bound in B
    ;; Sprint 7: #f mult → fresh-mult-meta
    [(surf-pi binder body loc)
     (let* ([name (binder-info-name binder)]
            [raw-mult (binder-info-mult binder)]
            [mult (if raw-mult raw-mult
                     (fresh-mult-meta (meta-source-info loc 'pi-param "multiplicity of Pi parameter" #f #f)))]
            [ty-surf (binder-info-type binder)]
            [ty (elaborate ty-surf env depth)])
       (if (prologos-error? ty) ty
           (begin
             ;; W2001: warn if capability type used with unrestricted (:w) multiplicity.
             ;; Capabilities are authority proofs — :0 (erased) or :1 (linear transfer) are preferred.
             (when (and (eq? mult 'mw)
                        (capability-type-expr? ty))
               (emit-capability-warning! (capability-type-expr? ty) 'mw))
             ;; Phase 4: track capability-typed bindings in scope
             ;; Phase 7: store full type expr (not just functor name) to support
             ;; dependent capabilities like (FileCap "/data").
             (let* ([new-env (env-extend env name depth)]
                    [new-depth (+ depth 1)]
                    [cap-scope (if (capability-type-expr? ty)
                                   (cons (cons depth ty)
                                         (current-capability-scope))
                                   (current-capability-scope))]
                    [bod (parameterize ([current-capability-scope cap-scope])
                           (elaborate body new-env new-depth))])
               (if (prologos-error? bod) bod
                   (expr-Pi mult ty bod))))))]

    ;; Lambda: (lam (x :m A) body) -> lam(m, elab-A, elab-body) with x bound
    ;; Sprint 7: #f mult → fresh-mult-meta
    [(surf-lam binder body loc)
     (let* ([name (binder-info-name binder)]
            [raw-mult (binder-info-mult binder)]
            [mult (if raw-mult raw-mult
                     (fresh-mult-meta (meta-source-info loc 'lambda-param "multiplicity of lambda parameter" #f #f)))]
            [ty-surf (binder-info-type binder)]
            [ty (elaborate ty-surf env depth)])
       (if (prologos-error? ty) ty
           (let* ([new-env (env-extend env name depth)]
                  [new-depth (+ depth 1)]
                  ;; Phase D: detect dict param binders and populate where-context
                  ;; Phase 3a: also detect $hm- prefixed HasMethod evidence params
                  [body-ctx (let ([name-str (symbol->string name)])
                              (cond
                                ;; HasMethod evidence: $hm-METHOD → direct where-method-entry
                                [(and (> (string-length name-str) 4)
                                      (string=? (substring name-str 0 4) "$hm-"))
                                 (let ([method-name (string->symbol (substring name-str 4))])
                                   (append (current-where-context)
                                           (list (where-method-entry
                                                   method-name
                                                   #f      ;; accessor-name: direct reference
                                                   #f      ;; trait-name: unknown (abstract P)
                                                   '()     ;; type-var-names: not needed
                                                   name))))] ;; dict-param-name: evidence param
                                ;; Standard dict param detection
                                [(is-dict-param-name? name)
                                 (let ([entries (dict-param->where-entries name)])
                                   (if entries
                                       (append (current-where-context) entries)
                                       (current-where-context)))]
                                [else (current-where-context)]))]
                  ;; Phase 4: track capability-typed bindings in scope
                  ;; Phase 7: store full type expr for dependent cap support
                  [cap-scope (if (capability-type-expr? ty)
                                 (cons (cons depth ty)
                                       (current-capability-scope))
                                 (current-capability-scope))]
                  [bod (parameterize ([current-where-context body-ctx]
                                     [current-capability-scope cap-scope])
                         (elaborate body new-env new-depth))])
             (if (prologos-error? bod) bod
                 (expr-lam mult ty bod)))))]

    ;; Sigma: (Sigma (x : A) B) -> Sigma(elab-A, elab-B) with x bound in B
    [(surf-sigma binder body loc)
     (let* ([name (binder-info-name binder)]
            [ty-surf (binder-info-type binder)]
            [ty (elaborate ty-surf env depth)])
       (if (prologos-error? ty) ty
           (let* ([new-env (env-extend env name depth)]
                  [new-depth (+ depth 1)]
                  [bod (elaborate body new-env new-depth)])
             (if (prologos-error? bod) bod
                 (expr-Sigma ty bod)))))]

    ;; Application: (f a b c) -> app(app(app(elab-f, elab-a), elab-b), elab-c)
    ;; When the function resolves to an expr-fvar, check its type for leading
    ;; implicit (m0) parameters and auto-insert holes if the user provided
    ;; only the explicit arguments.
    ;; The function is elaborated WITHOUT auto-apply (auto-apply? = #f) to avoid
    ;; double-application — the implicit insertion here handles ALL cases.
    [(surf-app func args loc)
     ;; Multi-defn dispatch: resolve base name to internal clause by arity
     (cond
       [(and (surf-var? func)
             (lookup-multi-defn (surf-var-name func)))
        => (lambda (multi-info)
             (define n-user-args (length args))
             (define resolved-name (resolve-multi-defn (surf-var-name func) n-user-args))
             (cond
               [resolved-name
                ;; Elaborate as if the user wrote the internal name
                (elaborate (surf-app (surf-var resolved-name (surf-var-srcloc func))
                                     args loc)
                           env depth)]
               [else
                (multi-arity-error loc
                  (format "No matching clause for '~a' with ~a argument~a"
                          (surf-var-name func) n-user-args
                          (if (= n-user-args 1) "" "s"))
                  (surf-var-name func) n-user-args
                  (multi-defn-info-arities multi-info))]))]
       [else
        ;; Normal application path
        ;; surf-nil in function position → elaborate as fvar 'nil with auto-apply? = #f
        ;; (same as surf-var, to avoid double auto-application of implicit params)
        (let ([ef (cond
                    [(surf-var? func)
                     (elaborate-var (surf-var-name func) (surf-var-srcloc func)
                                    env depth #f)]
                    [(surf-nil? func)
                     (if (global-env-lookup-type 'nil)
                         (elaborate-var 'nil (surf-nil-srcloc func) env depth #f)
                         (expr-nil))]
                    [else (elaborate func env depth)])])
          (if (prologos-error? ef) ef
              ;; Check for implicit parameters, arity, and insert fresh metavariables
              (if (expr-fvar? ef)
                  (let ([ftype (global-env-lookup-type (expr-fvar-name ef))])
                    (if ftype
                        (let* ([fname (expr-fvar-name ef)]
                               [n-user-args (length args)]
                               [mults (collect-pi-mults ftype)]
                               [n-total (length mults)]
                               [n-m0 (leading-m0-count mults)]
                               [n-imp (implicit-param-count ftype fname)]
                               [n-exp (- n-total n-imp)]
                               ;; Varargs: check if this function is variadic
                               [vspec (and (> n-total 0)
                                           (varargs-spec-info fname))]
                               ;; Collect args into list literal for variadic functions
                               ;; n-fixed = n-exp - 1 (the last explicit param is the List param)
                               [effective-args
                                (if vspec
                                    (let ([n-fixed (- n-exp 1)])
                                      (cond
                                        ;; Too few args for even the fixed params
                                        [(< n-user-args n-fixed)
                                         args]  ;; let arity check handle it
                                        ;; Exactly n-fixed or more: collect rest into list
                                        [else
                                         (let ([fixed (take args n-fixed)]
                                               [rest-args (drop args n-fixed)])
                                           (append fixed
                                                   (list (make-varargs-list-literal rest-args loc))))]))
                                    args)]
                               [n-effective (length effective-args)]
                               [n-holes (implicit-holes-needed ftype n-effective fname)])
                          ;; Arity check: reject over-application for known globals
                          ;; Valid arg counts: n-exp, (total - n-m0) if where-constraints, total
                          (cond
                            ;; Too many args: more than explicit count, and not a valid count
                            [(and (> n-effective n-exp)
                                  (not (= n-effective n-total))
                                  (not (= n-effective (- n-total n-m0)))  ;; explicit + dict args
                                  (> n-total 0))
                             (arity-error loc
                               (format "Too many arguments to '~a'" fname)
                               fname n-exp n-user-args
                               (pp-function-signature ftype))]
                            ;; Insert implicits if needed (Pi-chain-walking for trait tagging)
                            [(> n-holes 0)
                             (let ([with-metas
                                    (insert-implicits-with-tagging ef ftype n-holes
                                                                    fname loc env
                                                                    #:depth depth)])
                               (elaborate-args with-metas effective-args env depth loc))]
                            ;; Normal case: no insertion needed, proceed
                            [else
                             (elaborate-args ef effective-args env depth loc)]))
                        (elaborate-args ef args env depth loc)))
                  (elaborate-args ef args env depth loc))))])]

    ;; Pair
    [(surf-pair e1 e2 loc)
     (let ([a (elaborate e1 env depth)]
           [b (elaborate e2 env depth)])
       (cond [(prologos-error? a) a]
             [(prologos-error? b) b]
             [else (expr-pair a b)]))]

    ;; Projections
    [(surf-fst e loc)
     (let ([e1 (elaborate e env depth)])
       (if (prologos-error? e1) e1 (expr-fst e1)))]
    [(surf-snd e loc)
     (let ([e1 (elaborate e env depth)])
       (if (prologos-error? e1) e1 (expr-snd e1)))]

    ;; Annotation: (the T e) -> ann(elab-e, elab-T)
    [(surf-ann type term loc)
     (let ([t (elaborate type env depth)]
           [e (elaborate term env depth)])
       (cond [(prologos-error? t) t]
             [(prologos-error? e) e]
             [else (expr-ann e t)]))]

    ;; Equality type
    [(surf-eq type lhs rhs loc)
     (let ([t (elaborate type env depth)]
           [l (elaborate lhs env depth)]
           [r (elaborate rhs env depth)])
       (cond [(prologos-error? t) t]
             [(prologos-error? l) l]
             [(prologos-error? r) r]
             [else (expr-Eq t l r)]))]

    ;; Union type
    [(surf-union left right loc)
     (let ([l (elaborate left env depth)]
           [r (elaborate right env depth)])
       (cond [(prologos-error? l) l]
             [(prologos-error? r) r]
             [else (expr-union l r)]))]

    ;; boolrec
    [(surf-boolrec mot tc fc target loc)
     (let ([m (elaborate mot env depth)]
           [t (elaborate tc env depth)]
           [f (elaborate fc env depth)]
           [tgt (elaborate target env depth)])
       (cond [(prologos-error? m) m]
             [(prologos-error? t) t]
             [(prologos-error? f) f]
             [(prologos-error? tgt) tgt]
             [else (expr-boolrec m t f tgt)]))]

    ;; natrec
    [(surf-natrec mot base step target loc)
     (let ([m (elaborate mot env depth)]
           [b (elaborate base env depth)]
           [s (elaborate step env depth)]
           [tgt (elaborate target env depth)])
       (cond [(prologos-error? m) m]
             [(prologos-error? b) b]
             [(prologos-error? s) s]
             [(prologos-error? tgt) tgt]
             [else (expr-natrec m b s tgt)]))]

    ;; J
    [(surf-J mot base left right proof loc)
     (let ([m (elaborate mot env depth)]
           [b (elaborate base env depth)]
           [l (elaborate left env depth)]
           [r (elaborate right env depth)]
           [p (elaborate proof env depth)])
       (cond [(prologos-error? m) m]
             [(prologos-error? b) b]
             [(prologos-error? l) l]
             [(prologos-error? r) r]
             [(prologos-error? p) p]
             [else (expr-J m b l r p)]))]

    ;; Vec/Fin
    [(surf-vec-type t n loc)
     (let ([a (elaborate t env depth)]
           [len (elaborate n env depth)])
       (cond [(prologos-error? a) a]
             [(prologos-error? len) len]
             [else (expr-Vec a len)]))]
    [(surf-vnil t loc)
     (let ([a (elaborate t env depth)])
       (if (prologos-error? a) a (expr-vnil a)))]
    [(surf-vcons t n hd tl loc)
     (let ([a (elaborate t env depth)]
           [len (elaborate n env depth)]
           [h (elaborate hd env depth)]
           [tail (elaborate tl env depth)])
       (cond [(prologos-error? a) a]
             [(prologos-error? len) len]
             [(prologos-error? h) h]
             [(prologos-error? tail) tail]
             [else (expr-vcons a len h tail)]))]
    [(surf-fin-type n loc)
     (let ([bound (elaborate n env depth)])
       (if (prologos-error? bound) bound (expr-Fin bound)))]
    [(surf-fzero n loc)
     (let ([bound (elaborate n env depth)])
       (if (prologos-error? bound) bound (expr-fzero bound)))]
    [(surf-fsuc n inner loc)
     (let ([bound (elaborate n env depth)]
           [i (elaborate inner env depth)])
       (cond [(prologos-error? bound) bound]
             [(prologos-error? i) i]
             [else (expr-fsuc bound i)]))]
    [(surf-vhead t n v loc)
     (let ([a (elaborate t env depth)]
           [len (elaborate n env depth)]
           [vec (elaborate v env depth)])
       (cond [(prologos-error? a) a]
             [(prologos-error? len) len]
             [(prologos-error? vec) vec]
             [else (expr-vhead a len vec)]))]
    [(surf-vtail t n v loc)
     (let ([a (elaborate t env depth)]
           [len (elaborate n env depth)]
           [vec (elaborate v env depth)])
       (cond [(prologos-error? a) a]
             [(prologos-error? len) len]
             [(prologos-error? vec) vec]
             [else (expr-vtail a len vec)]))]
    [(surf-vindex t n i v loc)
     (let ([a (elaborate t env depth)]
           [len (elaborate n env depth)]
           [idx (elaborate i env depth)]
           [vec (elaborate v env depth)])
       (cond [(prologos-error? a) a]
             [(prologos-error? len) len]
             [(prologos-error? idx) idx]
             [(prologos-error? vec) vec]
             [else (expr-vindex a len idx vec)]))]

    ;; ---- Int ----
    [(surf-int-type loc) (expr-Int)]
    [(surf-int-lit v loc) (expr-int v)]
    [(surf-int-add a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-int-add ea eb)]))]
    [(surf-int-sub a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-int-sub ea eb)]))]
    [(surf-int-mul a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-int-mul ea eb)]))]
    [(surf-int-div a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-int-div ea eb)]))]
    [(surf-int-mod a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-int-mod ea eb)]))]
    [(surf-int-neg a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-int-neg ea)))]
    [(surf-int-abs a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-int-abs ea)))]
    [(surf-int-lt a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-int-lt ea eb)]))]
    [(surf-int-le a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-int-le ea eb)]))]
    [(surf-int-eq a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-int-eq ea eb)]))]
    [(surf-from-nat n loc)
     (let ([en (elaborate n env depth)])
       (if (prologos-error? en) en (expr-from-nat en)))]

    ;; ---- Rat ----
    [(surf-rat-type loc) (expr-Rat)]
    [(surf-rat-lit v loc) (expr-rat v)]
    [(surf-rat-add a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-rat-add ea eb)]))]
    [(surf-rat-sub a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-rat-sub ea eb)]))]
    [(surf-rat-mul a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-rat-mul ea eb)]))]
    [(surf-rat-div a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-rat-div ea eb)]))]
    [(surf-rat-neg a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-rat-neg ea)))]
    [(surf-rat-abs a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-rat-abs ea)))]
    [(surf-rat-lt a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-rat-lt ea eb)]))]
    [(surf-rat-le a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-rat-le ea eb)]))]
    [(surf-rat-eq a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-rat-eq ea eb)]))]
    [(surf-from-int n loc)
     (let ([en (elaborate n env depth)])
       (if (prologos-error? en) en (expr-from-int en)))]
    [(surf-rat-numer a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-rat-numer ea)))]
    [(surf-rat-denom a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-rat-denom ea)))]

    ;; ---- Generic arithmetic operators ----
    [(surf-generic-add a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-generic-add ea eb)]))]
    [(surf-generic-sub a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-generic-sub ea eb)]))]
    [(surf-generic-mul a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-generic-mul ea eb)]))]
    [(surf-generic-div a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-generic-div ea eb)]))]
    [(surf-generic-lt a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-generic-lt ea eb)]))]
    [(surf-generic-le a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-generic-le ea eb)]))]
    [(surf-generic-eq a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-generic-eq ea eb)]))]
    [(surf-generic-negate a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-generic-negate ea)))]
    [(surf-generic-abs a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-generic-abs ea)))]
    [(surf-generic-from-int target-type arg loc)
     (let ([et (elaborate target-type env depth)]
           [ea (elaborate arg env depth)])
       (cond [(prologos-error? et) et]
             [(prologos-error? ea) ea]
             [else (expr-generic-from-int et ea)]))]
    [(surf-generic-from-rat target-type arg loc)
     (let ([et (elaborate target-type env depth)]
           [ea (elaborate arg env depth)])
       (cond [(prologos-error? et) et]
             [(prologos-error? ea) ea]
             [else (expr-generic-from-rat et ea)]))]

    ;; ---- Posit8 ----
    [(surf-posit8-type loc) (expr-Posit8)]
    [(surf-posit8 v loc) (expr-posit8 v)]
    [(surf-p8-add a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p8-add ea eb)]))]
    [(surf-p8-sub a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p8-sub ea eb)]))]
    [(surf-p8-mul a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p8-mul ea eb)]))]
    [(surf-p8-div a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p8-div ea eb)]))]
    [(surf-p8-neg a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-p8-neg ea)))]
    [(surf-p8-abs a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-p8-abs ea)))]
    [(surf-p8-sqrt a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-p8-sqrt ea)))]
    [(surf-p8-lt a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p8-lt ea eb)]))]
    [(surf-p8-le a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p8-le ea eb)]))]
    [(surf-p8-eq a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p8-eq ea eb)]))]
    [(surf-p8-from-nat n loc)
     (let ([en (elaborate n env depth)])
       (if (prologos-error? en) en (expr-p8-from-nat en)))]
    [(surf-p8-to-rat a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-p8-to-rat ea)))]
    [(surf-p8-from-rat a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-p8-from-rat ea)))]
    [(surf-p8-from-int a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-p8-from-int ea)))]
    [(surf-p8-if-nar tp nc vc v loc)
     (let ([etp (elaborate tp env depth)]
           [enc (elaborate nc env depth)]
           [evc (elaborate vc env depth)]
           [ev (elaborate v env depth)])
       (cond [(prologos-error? etp) etp]
             [(prologos-error? enc) enc]
             [(prologos-error? evc) evc]
             [(prologos-error? ev) ev]
             [else (expr-p8-if-nar etp enc evc ev)]))]

    ;; ---- Posit16 ----
    [(surf-posit16-type loc) (expr-Posit16)]
    [(surf-posit16 v loc) (expr-posit16 v)]
    [(surf-p16-add a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p16-add ea eb)]))]
    [(surf-p16-sub a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p16-sub ea eb)]))]
    [(surf-p16-mul a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p16-mul ea eb)]))]
    [(surf-p16-div a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p16-div ea eb)]))]
    [(surf-p16-neg a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-p16-neg ea)))]
    [(surf-p16-abs a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-p16-abs ea)))]
    [(surf-p16-sqrt a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-p16-sqrt ea)))]
    [(surf-p16-lt a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p16-lt ea eb)]))]
    [(surf-p16-le a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p16-le ea eb)]))]
    [(surf-p16-eq a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p16-eq ea eb)]))]
    [(surf-p16-from-nat n loc)
     (let ([en (elaborate n env depth)])
       (if (prologos-error? en) en (expr-p16-from-nat en)))]
    [(surf-p16-to-rat a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-p16-to-rat ea)))]
    [(surf-p16-from-rat a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-p16-from-rat ea)))]
    [(surf-p16-from-int a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-p16-from-int ea)))]
    [(surf-p16-if-nar tp nc vc v loc)
     (let ([etp (elaborate tp env depth)]
           [enc (elaborate nc env depth)]
           [evc (elaborate vc env depth)]
           [ev (elaborate v env depth)])
       (cond [(prologos-error? etp) etp]
             [(prologos-error? enc) enc]
             [(prologos-error? evc) evc]
             [(prologos-error? ev) ev]
             [else (expr-p16-if-nar etp enc evc ev)]))]

    ;; ---- Posit32 ----
    [(surf-posit32-type loc) (expr-Posit32)]
    [(surf-posit32 v loc) (expr-posit32 v)]
    [(surf-p32-add a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p32-add ea eb)]))]
    [(surf-p32-sub a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p32-sub ea eb)]))]
    [(surf-p32-mul a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p32-mul ea eb)]))]
    [(surf-p32-div a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p32-div ea eb)]))]
    [(surf-p32-neg a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-p32-neg ea)))]
    [(surf-p32-abs a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-p32-abs ea)))]
    [(surf-p32-sqrt a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-p32-sqrt ea)))]
    [(surf-p32-lt a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p32-lt ea eb)]))]
    [(surf-p32-le a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p32-le ea eb)]))]
    [(surf-p32-eq a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p32-eq ea eb)]))]
    [(surf-p32-from-nat n loc)
     (let ([en (elaborate n env depth)])
       (if (prologos-error? en) en (expr-p32-from-nat en)))]
    [(surf-p32-to-rat a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-p32-to-rat ea)))]
    [(surf-p32-from-rat a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-p32-from-rat ea)))]
    [(surf-p32-from-int a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-p32-from-int ea)))]
    [(surf-p32-if-nar tp nc vc v loc)
     (let ([etp (elaborate tp env depth)]
           [enc (elaborate nc env depth)]
           [evc (elaborate vc env depth)]
           [ev (elaborate v env depth)])
       (cond [(prologos-error? etp) etp]
             [(prologos-error? enc) enc]
             [(prologos-error? evc) evc]
             [(prologos-error? ev) ev]
             [else (expr-p32-if-nar etp enc evc ev)]))]

    ;; ---- Posit64 ----
    [(surf-posit64-type loc) (expr-Posit64)]
    [(surf-posit64 v loc) (expr-posit64 v)]
    [(surf-p64-add a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p64-add ea eb)]))]
    [(surf-p64-sub a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p64-sub ea eb)]))]
    [(surf-p64-mul a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p64-mul ea eb)]))]
    [(surf-p64-div a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p64-div ea eb)]))]
    [(surf-p64-neg a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-p64-neg ea)))]
    [(surf-p64-abs a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-p64-abs ea)))]
    [(surf-p64-sqrt a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-p64-sqrt ea)))]
    [(surf-p64-lt a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p64-lt ea eb)]))]
    [(surf-p64-le a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p64-le ea eb)]))]
    [(surf-p64-eq a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p64-eq ea eb)]))]
    [(surf-p64-from-nat n loc)
     (let ([en (elaborate n env depth)])
       (if (prologos-error? en) en (expr-p64-from-nat en)))]
    [(surf-p64-to-rat a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-p64-to-rat ea)))]
    [(surf-p64-from-rat a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-p64-from-rat ea)))]
    [(surf-p64-from-int a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-p64-from-int ea)))]
    [(surf-p64-if-nar tp nc vc v loc)
     (let ([etp (elaborate tp env depth)]
           [enc (elaborate nc env depth)]
           [evc (elaborate vc env depth)]
           [ev (elaborate v env depth)])
       (cond [(prologos-error? etp) etp]
             [(prologos-error? enc) enc]
             [(prologos-error? evc) evc]
             [(prologos-error? ev) ev]
             [else (expr-p64-if-nar etp enc evc ev)]))]

    ;; ---- Quire operations ----
    ;; Types
    [(surf-quire8-type loc) (expr-Quire8)]
    [(surf-quire16-type loc) (expr-Quire16)]
    [(surf-quire32-type loc) (expr-Quire32)]
    [(surf-quire64-type loc) (expr-Quire64)]
    ;; Zero constructors → quireW-val with 0
    [(surf-quire8-zero loc) (expr-quire8-val 0)]
    [(surf-quire16-zero loc) (expr-quire16-val 0)]
    [(surf-quire32-zero loc) (expr-quire32-val 0)]
    [(surf-quire64-zero loc) (expr-quire64-val 0)]
    ;; FMA: (qW-fma q a b)
    [(surf-quire8-fma q a b loc)
     (let ([eq (elaborate q env depth)]
           [ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? eq) eq]
             [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-quire8-fma eq ea eb)]))]
    [(surf-quire16-fma q a b loc)
     (let ([eq (elaborate q env depth)]
           [ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? eq) eq]
             [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-quire16-fma eq ea eb)]))]
    [(surf-quire32-fma q a b loc)
     (let ([eq (elaborate q env depth)]
           [ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? eq) eq]
             [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-quire32-fma eq ea eb)]))]
    [(surf-quire64-fma q a b loc)
     (let ([eq (elaborate q env depth)]
           [ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? eq) eq]
             [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-quire64-fma eq ea eb)]))]
    ;; TO: (qW-to q)
    [(surf-quire8-to q loc)
     (let ([eq (elaborate q env depth)])
       (if (prologos-error? eq) eq (expr-quire8-to eq)))]
    [(surf-quire16-to q loc)
     (let ([eq (elaborate q env depth)])
       (if (prologos-error? eq) eq (expr-quire16-to eq)))]
    [(surf-quire32-to q loc)
     (let ([eq (elaborate q env depth)])
       (if (prologos-error? eq) eq (expr-quire32-to eq)))]
    [(surf-quire64-to q loc)
     (let ([eq (elaborate q env depth)])
       (if (prologos-error? eq) eq (expr-quire64-to eq)))]

    ;; Approximate literal: ~N → default Posit32
    ;; Context-aware width selection happens in the type checker (check mode).
    ;; At elaboration time, we default to Posit32.
    [(surf-approx-literal v loc)
     (expr-posit32 (posit32-encode (if (exact? v) v (inexact->exact v))))]

    ;; ---- Symbol type and literal ----
    [(surf-symbol-type loc)
     (expr-Symbol)]
    [(surf-symbol name loc)
     (expr-symbol name)]

    ;; ---- Keyword type and literal ----
    [(surf-keyword-type loc)
     (expr-Keyword)]
    [(surf-keyword name loc)
     (expr-keyword name)]

    ;; ---- Char type and literal ----
    [(surf-char-type loc)
     (expr-Char)]
    [(surf-char val loc)
     (expr-char val)]

    ;; ---- String type and literal ----
    [(surf-string-type loc)
     (expr-String)]
    [(surf-string val loc)
     (expr-string val)]

    ;; ---- Map type and operations ----
    [(surf-map-type k v loc)
     (let ([ek (elaborate k env depth)]
           [ev (elaborate v env depth)])
       (cond [(prologos-error? ek) ek]
             [(prologos-error? ev) ev]
             [else (expr-Map ek ev)]))]

    [(surf-map-literal entries loc)
     ;; Elaborate to nested map-assoc on map-empty.
     ;; entries is a list of (parsed-key . parsed-val) pairs.
     ;; Key and value types use fresh metas — unification will resolve them.
     (if (null? entries)
         ;; Empty map: fresh metas for key/value types
         (let ([km (fresh-meta ctx-empty (expr-hole)
                     (meta-source-info loc 'map-key-type "key type of empty map literal" #f (env->name-stack env)))]
               [vm (fresh-meta ctx-empty (expr-hole)
                     (meta-source-info loc 'map-val-type "value type of empty map literal" #f (env->name-stack env)))])
           (expr-map-empty km vm))
         ;; Non-empty: elaborate all entries, then fold into map-assoc
         (let ([km (fresh-meta ctx-empty (expr-hole)
                     (meta-source-info loc 'map-key-type "key type of map literal" #f (env->name-stack env)))]
               [vm (fresh-meta ctx-empty (expr-hole)
                     (meta-source-info loc 'map-val-type "value type of map literal" #f (env->name-stack env)))])
           (let loop ([remaining entries]
                      [result (expr-map-empty km vm)])
             (cond
               [(null? remaining)
                result]
               [else
                (define entry (car remaining))
                (define ek (elaborate (car entry) env depth))
                (define ev (elaborate (cdr entry) env depth))
                (cond
                  [(prologos-error? ek) ek]
                  [(prologos-error? ev) ev]
                  [else
                   (loop (cdr remaining)
                         (expr-map-assoc result ek ev))])]))))]

    [(surf-map-empty k v loc)
     (let ([ek (elaborate k env depth)]
           [ev (elaborate v env depth)])
       (cond [(prologos-error? ek) ek]
             [(prologos-error? ev) ev]
             [else (expr-map-empty ek ev)]))]

    [(surf-map-assoc m k v loc)
     (let ([em (elaborate m env depth)]
           [ek (elaborate k env depth)]
           [ev (elaborate v env depth)])
       (cond [(prologos-error? em) em]
             [(prologos-error? ek) ek]
             [(prologos-error? ev) ev]
             [else (expr-map-assoc em ek ev)]))]

    [(surf-map-get m k loc)
     (let ([em (elaborate m env depth)]
           [ek (elaborate k env depth)])
       (cond [(prologos-error? em) em]
             [(prologos-error? ek) ek]
             [else (expr-map-get em ek)]))]

    [(surf-nil-safe-get m k loc)
     (let ([em (elaborate m env depth)]
           [ek (elaborate k env depth)])
       (cond [(prologos-error? em) em]
             [(prologos-error? ek) ek]
             [else (expr-nil-safe-get em ek)]))]

    [(surf-nil-check arg loc)
     (let ([ea (elaborate arg env depth)])
       (if (prologos-error? ea) ea
           (expr-nil-check ea)))]

    [(surf-map-dissoc m k loc)
     (let ([em (elaborate m env depth)]
           [ek (elaborate k env depth)])
       (cond [(prologos-error? em) em]
             [(prologos-error? ek) ek]
             [else (expr-map-dissoc em ek)]))]

    [(surf-map-size m loc)
     (let ([em (elaborate m env depth)])
       (if (prologos-error? em) em
           (expr-map-size em)))]

    [(surf-map-has-key m k loc)
     (let ([em (elaborate m env depth)]
           [ek (elaborate k env depth)])
       (cond [(prologos-error? em) em]
             [(prologos-error? ek) ek]
             [else (expr-map-has-key em ek)]))]

    [(surf-map-keys m loc)
     (let ([em (elaborate m env depth)])
       (if (prologos-error? em) em
           (expr-map-keys em)))]

    [(surf-map-vals m loc)
     (let ([em (elaborate m env depth)])
       (if (prologos-error? em) em
           (expr-map-vals em)))]

    ;; get-in: desugar to chained map-get calls
    ;; Single path:   (get-in m :a.b.c) → (map-get (map-get (map-get m :a) :b) :c)
    ;; Multiple paths: (get-in m :a.{b c}) → {kw-b (map-get (map-get m :a) :b)
    ;;                                         kw-c (map-get (map-get m :a) :c)}
    [(surf-get-in target paths loc)
     (let ([et (elaborate target env depth)])
       (if (prologos-error? et) et
           (let ()
             ;; Path segments are Racket keywords (#:zip); expr-keyword takes symbols
             (define (seg->kw seg)
               (expr-keyword (string->symbol (keyword->string seg))))
             ;; Build a chained map-get for a single path
             (define (path->chain base segs)
               (foldl (lambda (seg acc)
                        (expr-map-get acc (seg->kw seg)))
                      base segs))
             (cond
               ;; Single path → return the leaf value
               [(= (length paths) 1)
                (path->chain et (car paths))]
               ;; Multiple paths → build a map literal {leaf-key value ...}
               [else
                ;; Create fresh metas for the map literal's key/value types
                (define km (fresh-meta ctx-empty (expr-hole)
                             (meta-source-info loc 'map-key-type "key type of get-in projection" #f (env->name-stack env))))
                (define vm (fresh-meta ctx-empty (expr-hole)
                             (meta-source-info loc 'map-val-type "value type of get-in projection" #f (env->name-stack env))))
                (let build-map ([remaining paths]
                                [result (expr-map-empty km vm)])
                  (cond
                    [(null? remaining) result]
                    [else
                     (define path (car remaining))
                     (define leaf-key (last path))  ;; last segment is the map key
                     (define chain (path->chain et path))
                     (build-map (cdr remaining)
                                (expr-map-assoc result (seg->kw leaf-key) chain))]))]))))]

    ;; update-in: desugar to nested map-get + map-assoc
    ;; (update-in m :a.b.c f) →
    ;;   (map-assoc m :a
    ;;     (map-assoc (map-get m :a) :b
    ;;       (map-assoc (map-get (map-get m :a) :b) :c
    ;;         (f (map-get (map-get (map-get m :a) :b) :c)))))
    [(surf-update-in target paths fn-expr loc)
     (let ([et (elaborate target env depth)]
           [ef (elaborate fn-expr env depth)])
       (cond
         [(prologos-error? et) et]
         [(prologos-error? ef) ef]
         ;; update-in only makes sense for a single path
         [(not (= (length paths) 1))
          (parse-error loc "update-in requires exactly one path (no branching)" #f)]
         [else
          (let ([segs (car paths)])
            ;; Path segments are Racket keywords (#:zip); expr-keyword takes symbols
            (define (seg->kw seg)
              (expr-keyword (string->symbol (keyword->string seg))))
            ;; Build the nested update structure
            (define (build-update base segs)
              (cond
                [(null? segs) (expr-app ef base)]  ;; leaf: apply fn
                [else
                 (define key (car segs))
                 (define sub-val (expr-map-get base (seg->kw key)))
                 (define updated (build-update sub-val (cdr segs)))
                 (expr-map-assoc base (seg->kw key) updated)]))
            (build-update et segs))]))]

    ;; ---- Set type and operations ----
    [(surf-set-type a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea
           (expr-Set ea)))]

    [(surf-set-literal elems loc)
     ;; Elaborate to nested set-insert on set-empty.
     ;; Element type uses a fresh meta — unification will resolve it.
     (let ([am (fresh-meta ctx-empty (expr-hole)
                 (meta-source-info loc 'set-elem-type "element type of set literal" #f (env->name-stack env)))])
       (if (null? elems)
           (expr-set-empty am)
           (let loop ([remaining elems]
                      [result (expr-set-empty am)])
             (cond
               [(null? remaining) result]
               [else
                (define ea (elaborate (car remaining) env depth))
                (if (prologos-error? ea) ea
                    (loop (cdr remaining)
                          (expr-set-insert result ea)))]))))]

    [(surf-set-empty a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea
           (expr-set-empty ea)))]

    [(surf-set-insert s a loc)
     (let ([es (elaborate s env depth)]
           [ea (elaborate a env depth)])
       (cond [(prologos-error? es) es]
             [(prologos-error? ea) ea]
             [else (expr-set-insert es ea)]))]

    [(surf-set-member s a loc)
     (let ([es (elaborate s env depth)]
           [ea (elaborate a env depth)])
       (cond [(prologos-error? es) es]
             [(prologos-error? ea) ea]
             [else (expr-set-member es ea)]))]

    [(surf-set-delete s a loc)
     (let ([es (elaborate s env depth)]
           [ea (elaborate a env depth)])
       (cond [(prologos-error? es) es]
             [(prologos-error? ea) ea]
             [else (expr-set-delete es ea)]))]

    [(surf-set-size s loc)
     (let ([es (elaborate s env depth)])
       (if (prologos-error? es) es
           (expr-set-size es)))]

    [(surf-set-union s1 s2 loc)
     (let ([es1 (elaborate s1 env depth)]
           [es2 (elaborate s2 env depth)])
       (cond [(prologos-error? es1) es1]
             [(prologos-error? es2) es2]
             [else (expr-set-union es1 es2)]))]

    [(surf-set-intersect s1 s2 loc)
     (let ([es1 (elaborate s1 env depth)]
           [es2 (elaborate s2 env depth)])
       (cond [(prologos-error? es1) es1]
             [(prologos-error? es2) es2]
             [else (expr-set-intersect es1 es2)]))]

    [(surf-set-diff s1 s2 loc)
     (let ([es1 (elaborate s1 env depth)]
           [es2 (elaborate s2 env depth)])
       (cond [(prologos-error? es1) es1]
             [(prologos-error? es2) es2]
             [else (expr-set-diff es1 es2)]))]

    [(surf-set-to-list s loc)
     (let ([es (elaborate s env depth)])
       (if (prologos-error? es) es
           (expr-set-to-list es)))]

    ;; ---- PVec type and operations ----
    [(surf-pvec-type a loc)
     (let ([ea (elaborate a env depth)])
       (cond [(prologos-error? ea) ea]
             [else (expr-PVec ea)]))]

    [(surf-pvec-literal elems loc)
     ;; Desugar @[e1 e2 e3] → pvec-push(pvec-push(pvec-push(pvec-empty(meta), e1), e2), e3)
     (let ([am (fresh-meta ctx-empty (expr-hole)
                 (meta-source-info loc 'pvec-elem-type "element type of PVec literal" #f (env->name-stack env)))])
       (let loop ([remaining elems]
                  [result (expr-pvec-empty am)])
         (cond
           [(null? remaining) result]
           [else
            (define ex (elaborate (car remaining) env depth))
            (cond
              [(prologos-error? ex) ex]
              [else (loop (cdr remaining)
                          (expr-pvec-push result ex))])])))]

    [(surf-pvec-empty a loc)
     (let ([ea (elaborate a env depth)])
       (cond [(prologos-error? ea) ea]
             [else (expr-pvec-empty ea)]))]

    [(surf-pvec-push v x loc)
     (let ([ev (elaborate v env depth)]
           [ex (elaborate x env depth)])
       (cond [(prologos-error? ev) ev]
             [(prologos-error? ex) ex]
             [else (expr-pvec-push ev ex)]))]

    [(surf-pvec-nth v i loc)
     (let ([ev (elaborate v env depth)]
           [ei (elaborate i env depth)])
       (cond [(prologos-error? ev) ev]
             [(prologos-error? ei) ei]
             [else (expr-pvec-nth ev ei)]))]

    [(surf-pvec-update v i x loc)
     (let ([ev (elaborate v env depth)]
           [ei (elaborate i env depth)]
           [ex (elaborate x env depth)])
       (cond [(prologos-error? ev) ev]
             [(prologos-error? ei) ei]
             [(prologos-error? ex) ex]
             [else (expr-pvec-update ev ei ex)]))]

    [(surf-pvec-length v loc)
     (let ([ev (elaborate v env depth)])
       (cond [(prologos-error? ev) ev]
             [else (expr-pvec-length ev)]))]

    [(surf-pvec-pop v loc)
     (let ([ev (elaborate v env depth)])
       (cond [(prologos-error? ev) ev]
             [else (expr-pvec-pop ev)]))]

    [(surf-pvec-concat v1 v2 loc)
     (let ([ev1 (elaborate v1 env depth)]
           [ev2 (elaborate v2 env depth)])
       (cond [(prologos-error? ev1) ev1]
             [(prologos-error? ev2) ev2]
             [else (expr-pvec-concat ev1 ev2)]))]

    [(surf-pvec-slice v lo hi loc)
     (let ([ev (elaborate v env depth)]
           [elo (elaborate lo env depth)]
           [ehi (elaborate hi env depth)])
       (cond [(prologos-error? ev) ev]
             [(prologos-error? elo) elo]
             [(prologos-error? ehi) ehi]
             [else (expr-pvec-slice ev elo ehi)]))]

    [(surf-pvec-to-list v loc)
     (let ([ev (elaborate v env depth)])
       (cond [(prologos-error? ev) ev]
             [else (expr-pvec-to-list ev)]))]

    [(surf-pvec-from-list v loc)
     (let ([ev (elaborate v env depth)])
       (cond [(prologos-error? ev) ev]
             [else (expr-pvec-from-list ev)]))]

    [(surf-pvec-fold f init vec loc)
     (let ([ef    (elaborate f    env depth)]
           [einit (elaborate init env depth)]
           [evec  (elaborate vec  env depth)])
       (cond [(prologos-error? ef)    ef]
             [(prologos-error? einit) einit]
             [(prologos-error? evec)  evec]
             [else (expr-pvec-fold ef einit evec)]))]

    [(surf-pvec-map f vec loc)
     (let ([ef   (elaborate f   env depth)]
           [evec (elaborate vec env depth)])
       (cond [(prologos-error? ef)   ef]
             [(prologos-error? evec) evec]
             [else (expr-pvec-map ef evec)]))]

    [(surf-pvec-filter pred vec loc)
     (let ([ep   (elaborate pred env depth)]
           [evec (elaborate vec  env depth)])
       (cond [(prologos-error? ep)   ep]
             [(prologos-error? evec) evec]
             [else (expr-pvec-filter ep evec)]))]

    [(surf-set-fold f init set loc)
     (let ([ef    (elaborate f    env depth)]
           [einit (elaborate init env depth)]
           [eset  (elaborate set  env depth)])
       (cond [(prologos-error? ef)    ef]
             [(prologos-error? einit) einit]
             [(prologos-error? eset)  eset]
             [else (expr-set-fold ef einit eset)]))]

    [(surf-set-filter pred set loc)
     (let ([ep   (elaborate pred env depth)]
           [eset (elaborate set  env depth)])
       (cond [(prologos-error? ep)   ep]
             [(prologos-error? eset) eset]
             [else (expr-set-filter ep eset)]))]

    [(surf-map-fold-entries f init map loc)
     (let ([ef    (elaborate f    env depth)]
           [einit (elaborate init env depth)]
           [emap  (elaborate map  env depth)])
       (cond [(prologos-error? ef)    ef]
             [(prologos-error? einit) einit]
             [(prologos-error? emap)  emap]
             [else (expr-map-fold-entries ef einit emap)]))]

    [(surf-map-filter-entries pred map loc)
     (let ([ep   (elaborate pred env depth)]
           [emap (elaborate map  env depth)])
       (cond [(prologos-error? ep)   ep]
             [(prologos-error? emap) emap]
             [else (expr-map-filter-entries ep emap)]))]

    [(surf-map-map-vals f map loc)
     (let ([ef   (elaborate f   env depth)]
           [emap (elaborate map env depth)])
       (cond [(prologos-error? ef)   ef]
             [(prologos-error? emap) emap]
             [else (expr-map-map-vals ef emap)]))]

    ;; ---- Transient Builders ----
    ;; Transient type constructors: (TVec A), (TMap K V), (TSet A)
    [(surf-transient-type kind args loc)
     (case kind
       [(TVec)
        (let ([ea (elaborate args env depth)])
          (cond [(prologos-error? ea) ea]
                [else (expr-TVec ea)]))]
       [(TMap)
        (let ([ek (elaborate (car args) env depth)]
              [ev (elaborate (cadr args) env depth)])
          (cond [(prologos-error? ek) ek]
                [(prologos-error? ev) ev]
                [else (expr-TMap ek ev)]))]
       [(TSet)
        (let ([ea (elaborate args env depth)])
          (cond [(prologos-error? ea) ea]
                [else (expr-TSet ea)]))]
       [else (prologos-error loc (format "Unknown transient type: ~a" kind) #f)])]

    ;; `transient` is generic: elaborator produces expr-transient,
    ;; type checker resolves to expr-transient-vec/map/set based on arg type
    [(surf-transient coll loc)
     (let ([ec (elaborate coll env depth)])
       (cond [(prologos-error? ec) ec]
             [else (expr-transient ec)]))]

    ;; `persist!` is generic: elaborator produces expr-persist,
    ;; type checker resolves to expr-persist-vec/map/set based on arg type
    [(surf-persist coll loc)
     (let ([ec (elaborate coll env depth)])
       (cond [(prologos-error? ec) ec]
             [else (expr-persist ec)]))]

    ;; `panic` — runtime abort, inhabits any type
    [(surf-panic msg loc)
     (let ([em (elaborate msg env depth)])
       (cond [(prologos-error? em) em]
             [else (expr-panic em)]))]

    [(surf-tvec-push! t x loc)
     (let ([et (elaborate t env depth)]
           [ex (elaborate x env depth)])
       (cond [(prologos-error? et) et]
             [(prologos-error? ex) ex]
             [else (expr-tvec-push! et ex)]))]

    [(surf-tvec-update! t i x loc)
     (let ([et (elaborate t env depth)]
           [ei (elaborate i env depth)]
           [ex (elaborate x env depth)])
       (cond [(prologos-error? et) et]
             [(prologos-error? ei) ei]
             [(prologos-error? ex) ex]
             [else (expr-tvec-update! et ei ex)]))]

    [(surf-tmap-assoc! t k v loc)
     (let ([et (elaborate t env depth)]
           [ek (elaborate k env depth)]
           [ev (elaborate v env depth)])
       (cond [(prologos-error? et) et]
             [(prologos-error? ek) ek]
             [(prologos-error? ev) ev]
             [else (expr-tmap-assoc! et ek ev)]))]

    [(surf-tmap-dissoc! t k loc)
     (let ([et (elaborate t env depth)]
           [ek (elaborate k env depth)])
       (cond [(prologos-error? et) et]
             [(prologos-error? ek) ek]
             [else (expr-tmap-dissoc! et ek)]))]

    [(surf-tset-insert! t a loc)
     (let ([et (elaborate t env depth)]
           [ea (elaborate a env depth)])
       (cond [(prologos-error? et) et]
             [(prologos-error? ea) ea]
             [else (expr-tset-insert! et ea)]))]

    [(surf-tset-delete! t a loc)
     (let ([et (elaborate t env depth)]
           [ea (elaborate a env depth)])
       (cond [(prologos-error? et) et]
             [(prologos-error? ea) ea]
             [else (expr-tset-delete! et ea)]))]

    ;; ---- PropNetwork (persistent propagator network) ----
    [(surf-net-type _loc) (expr-net-type)]
    [(surf-cell-id-type _loc) (expr-cell-id-type)]
    [(surf-prop-id-type _loc) (expr-prop-id-type)]

    [(surf-net-new fuel loc)
     (let ([ef (elaborate fuel env depth)])
       (if (prologos-error? ef) ef
           (expr-net-new ef)))]

    [(surf-net-new-cell net init merge loc)
     (let ([en (elaborate net env depth)]
           [ei (elaborate init env depth)]
           [em (elaborate merge env depth)])
       (cond [(prologos-error? en) en]
             [(prologos-error? ei) ei]
             [(prologos-error? em) em]
             [else (expr-net-new-cell en ei em)]))]

    [(surf-net-new-cell-widen net init merge widen-fn narrow-fn loc)
     (let ([en (elaborate net env depth)]
           [ei (elaborate init env depth)]
           [em (elaborate merge env depth)]
           [ew (elaborate widen-fn env depth)]
           [enr (elaborate narrow-fn env depth)])
       (cond [(prologos-error? en) en]
             [(prologos-error? ei) ei]
             [(prologos-error? em) em]
             [(prologos-error? ew) ew]
             [(prologos-error? enr) enr]
             [else (expr-net-new-cell-widen en ei em ew enr)]))]

    [(surf-net-cell-read net cell loc)
     (let ([en (elaborate net env depth)]
           [ec (elaborate cell env depth)])
       (cond [(prologos-error? en) en]
             [(prologos-error? ec) ec]
             [else (expr-net-cell-read en ec)]))]

    [(surf-net-cell-write net cell val loc)
     (let ([en (elaborate net env depth)]
           [ec (elaborate cell env depth)]
           [ev (elaborate val env depth)])
       (cond [(prologos-error? en) en]
             [(prologos-error? ec) ec]
             [(prologos-error? ev) ev]
             [else (expr-net-cell-write en ec ev)]))]

    [(surf-net-add-prop net ins outs fn loc)
     (let ([en (elaborate net env depth)]
           [ei (elaborate ins env depth)]
           [eo (elaborate outs env depth)]
           [ef (elaborate fn env depth)])
       (cond [(prologos-error? en) en]
             [(prologos-error? ei) ei]
             [(prologos-error? eo) eo]
             [(prologos-error? ef) ef]
             [else (expr-net-add-prop en ei eo ef)]))]

    [(surf-net-run net loc)
     (let ([en (elaborate net env depth)])
       (if (prologos-error? en) en
           (expr-net-run en)))]

    [(surf-net-snapshot net loc)
     (let ([en (elaborate net env depth)])
       (if (prologos-error? en) en
           (expr-net-snapshot en)))]

    [(surf-net-contradiction net loc)
     (let ([en (elaborate net env depth)])
       (if (prologos-error? en) en
           (expr-net-contradiction en)))]

    ;; ---- UnionFind (persistent disjoint sets) ----
    [(surf-uf-type _loc) (expr-uf-type)]

    [(surf-uf-empty _loc) (expr-uf-empty)]

    [(surf-uf-make-set store id val loc)
     (let ([es (elaborate store env depth)]
           [ei (elaborate id env depth)]
           [ev (elaborate val env depth)])
       (cond [(prologos-error? es) es]
             [(prologos-error? ei) ei]
             [(prologos-error? ev) ev]
             [else (expr-uf-make-set es ei ev)]))]

    [(surf-uf-find store id loc)
     (let ([es (elaborate store env depth)]
           [ei (elaborate id env depth)])
       (cond [(prologos-error? es) es]
             [(prologos-error? ei) ei]
             [else (expr-uf-find es ei)]))]

    [(surf-uf-union store id1 id2 loc)
     (let ([es (elaborate store env depth)]
           [e1 (elaborate id1 env depth)]
           [e2 (elaborate id2 env depth)])
       (cond [(prologos-error? es) es]
             [(prologos-error? e1) e1]
             [(prologos-error? e2) e2]
             [else (expr-uf-union es e1 e2)]))]

    [(surf-uf-value store id loc)
     (let ([es (elaborate store env depth)]
           [ei (elaborate id env depth)])
       (cond [(prologos-error? es) es]
             [(prologos-error? ei) ei]
             [else (expr-uf-value es ei)]))]

    ;; ---- ATMS (hypothetical reasoning) ----
    [(surf-atms-type _loc) (expr-atms-type)]
    [(surf-assumption-id-type _loc) (expr-assumption-id-type)]

    [(surf-atms-new network loc)
     (let ([en (elaborate network env depth)])
       (if (prologos-error? en) en
           (expr-atms-new en)))]

    [(surf-atms-assume atms name datum loc)
     (let ([ea (elaborate atms env depth)]
           [en (elaborate name env depth)]
           [ed (elaborate datum env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? en) en]
             [(prologos-error? ed) ed]
             [else (expr-atms-assume ea en ed)]))]

    [(surf-atms-retract atms aid loc)
     (let ([ea (elaborate atms env depth)]
           [ei (elaborate aid env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? ei) ei]
             [else (expr-atms-retract ea ei)]))]

    [(surf-atms-nogood atms aids loc)
     (let ([ea (elaborate atms env depth)]
           [el (elaborate aids env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? el) el]
             [else (expr-atms-nogood ea el)]))]

    [(surf-atms-amb atms alternatives loc)
     (let ([ea (elaborate atms env depth)]
           [el (elaborate alternatives env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? el) el]
             [else (expr-atms-amb ea el)]))]

    [(surf-atms-solve-all atms goal loc)
     (let ([ea (elaborate atms env depth)]
           [eg (elaborate goal env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eg) eg]
             [else (expr-atms-solve-all ea eg)]))]

    [(surf-atms-read atms cell loc)
     (let ([ea (elaborate atms env depth)]
           [ec (elaborate cell env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? ec) ec]
             [else (expr-atms-read ea ec)]))]

    [(surf-atms-write atms cell val support loc)
     (let ([ea (elaborate atms env depth)]
           [ec (elaborate cell env depth)]
           [ev (elaborate val env depth)]
           [es (elaborate support env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? ec) ec]
             [(prologos-error? ev) ev]
             [(prologos-error? es) es]
             [else (expr-atms-write ea ec ev es)]))]

    [(surf-atms-consistent atms aids loc)
     (let ([ea (elaborate atms env depth)]
           [el (elaborate aids env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? el) el]
             [else (expr-atms-consistent ea el)]))]

    [(surf-atms-worldview atms aids loc)
     (let ([ea (elaborate atms env depth)]
           [el (elaborate aids env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? el) el]
             [else (expr-atms-worldview ea el)]))]

    ;; ---- Tabling operations ----

    [(surf-table-store-type loc)
     (expr-table-store-type)]

    [(surf-table-new network loc)
     (let ([en (elaborate network env depth)])
       (if (prologos-error? en) en
           (expr-table-new en)))]

    [(surf-table-register store name mode loc)
     (let ([es (elaborate store env depth)]
           [en (elaborate name env depth)]
           [em (elaborate mode env depth)])
       (cond [(prologos-error? es) es]
             [(prologos-error? en) en]
             [(prologos-error? em) em]
             [else (expr-table-register es en em)]))]

    [(surf-table-add store name answer loc)
     (let ([es (elaborate store env depth)]
           [en (elaborate name env depth)]
           [ea (elaborate answer env depth)])
       (cond [(prologos-error? es) es]
             [(prologos-error? en) en]
             [(prologos-error? ea) ea]
             [else (expr-table-add es en ea)]))]

    [(surf-table-answers store name loc)
     (let ([es (elaborate store env depth)]
           [en (elaborate name env depth)])
       (cond [(prologos-error? es) es]
             [(prologos-error? en) en]
             [else (expr-table-answers es en)]))]

    [(surf-table-freeze store name loc)
     (let ([es (elaborate store env depth)]
           [en (elaborate name env depth)])
       (cond [(prologos-error? es) es]
             [(prologos-error? en) en]
             [else (expr-table-freeze es en)]))]

    [(surf-table-complete store name loc)
     (let ([es (elaborate store env depth)]
           [en (elaborate name env depth)])
       (cond [(prologos-error? es) es]
             [(prologos-error? en) en]
             [else (expr-table-complete es en)]))]

    [(surf-table-run store loc)
     (let ([es (elaborate store env depth)])
       (if (prologos-error? es) es
           (expr-table-run es)))]

    [(surf-table-lookup store name answer loc)
     (let ([es (elaborate store env depth)]
           [en (elaborate name env depth)]
           [ea (elaborate answer env depth)])
       (cond [(prologos-error? es) es]
             [(prologos-error? en) en]
             [(prologos-error? ea) ea]
             [else (expr-table-lookup es en ea)]))]

    ;; ---- Relational language (Phase 7) ----

    ;; Type constructors — no sub-expressions to elaborate
    [(surf-solver-type loc)
     (expr-solver-type)]

    [(surf-goal-type loc)
     (expr-goal-type)]

    [(surf-derivation-type loc)
     (expr-derivation-type)]

    [(surf-answer-type val-type loc)
     (if val-type
         (let ([ev (elaborate val-type env depth)])
           (if (prologos-error? ev) ev
               (expr-answer-type ev)))
         (expr-answer-type #f))]

    ;; defr — named relation definition
    ;; At expression level, elaborate variants into expr-defr
    [(surf-defr name schema variants loc)
     (let ([es (and schema (elaborate schema env depth))])
       (cond
         [(and es (prologos-error? es)) es]
         [else
          (define elab-variants
            (for/list ([v (in-list variants)])
              (elaborate-defr-variant v env depth)))
          (define first-err (findf prologos-error? elab-variants))
          (if first-err first-err
              (expr-defr name (or es #f) elab-variants))]))]

    ;; rel — anonymous relation
    [(surf-rel params clauses loc)
     (let ([elab-clauses
            (for/list ([c (in-list clauses)])
              (elaborate c env depth))])
       (define first-err (findf prologos-error? elab-clauses))
       (if first-err first-err
           (expr-rel params elab-clauses)))]

    ;; clause — rule clause (&> goals...)
    [(surf-clause goals loc)
     (let ([elab-goals
            (for/list ([g (in-list goals)])
              (elaborate g env depth))])
       (define first-err (findf prologos-error? elab-goals))
       (if first-err first-err
           (expr-clause elab-goals)))]

    ;; facts — ground fact block (|| rows...)
    [(surf-facts rows loc)
     (let ([elab-rows
            (for/list ([r (in-list rows)])
              (elaborate r env depth))])
       (define first-err (findf prologos-error? elab-rows))
       (if first-err first-err
           (expr-fact-block elab-rows)))]

    ;; fact-row — single fact row
    [(surf-fact-row terms loc)
     (let ([elab-terms
            (for/list ([t (in-list terms)])
              (elaborate t env depth))])
       (define first-err (findf prologos-error? elab-terms))
       (if first-err first-err
           (expr-fact-row elab-terms)))]

    ;; goal-app — relational goal application (name args...)
    [(surf-goal-app name args loc)
     (let ([elab-args
            (for/list ([a (in-list args)])
              (elaborate a env depth))])
       (define first-err (findf prologos-error? elab-args))
       (if first-err first-err
           (expr-goal-app name elab-args)))]

    ;; unify — unification goal (= lhs rhs)
    [(surf-unify lhs rhs loc)
     (let ([el (elaborate lhs env depth)]
           [er (elaborate rhs env depth)])
       (cond [(prologos-error? el) el]
             [(prologos-error? er) er]
             [else (expr-unify-goal el er)]))]

    ;; is — functional eval (is var [expr])
    [(surf-is var expr loc)
     (let ([ev (elaborate var env depth)]
           [ee (elaborate expr env depth)])
       (cond [(prologos-error? ev) ev]
             [(prologos-error? ee) ee]
             [else (expr-is-goal ev ee)]))]

    ;; not — negation-as-failure
    [(surf-not goal loc)
     (let ([eg (elaborate goal env depth)])
       (if (prologos-error? eg) eg
           (expr-not-goal eg)))]

    ;; solve — bare solve
    ;; Goal is elaborated in relational-fallback mode: unresolved names become
    ;; free query variables (expr-logic-var with mode 'free).
    [(surf-solve goal loc)
     (let ([eg (parameterize ([current-relational-fallback? #t])
                 (elaborate goal env depth))])
       (if (prologos-error? eg) eg
           (expr-solve eg)))]

    ;; solve-with — parameterized solve
    [(surf-solve-with solver overrides goal loc)
     (let ([es (elaborate solver env depth)]
           [eo (and overrides (elaborate overrides env depth))]
           [eg (parameterize ([current-relational-fallback? #t])
                 (elaborate goal env depth))])
       (cond [(prologos-error? es) es]
             [(and eo (prologos-error? eo)) eo]
             [(prologos-error? eg) eg]
             [else (expr-solve-with es (or eo #f) eg)]))]

    ;; explain — bare explain
    [(surf-explain goal loc)
     (let ([eg (parameterize ([current-relational-fallback? #t])
                 (elaborate goal env depth))])
       (if (prologos-error? eg) eg
           (expr-explain eg)))]

    ;; explain-with — parameterized explain
    [(surf-explain-with solver overrides goal loc)
     (let ([es (elaborate solver env depth)]
           [eo (and overrides (elaborate overrides env depth))]
           [eg (parameterize ([current-relational-fallback? #t])
                 (elaborate goal env depth))])
       (cond [(prologos-error? es) es]
             [(and eo (prologos-error? eo)) eo]
             [(prologos-error? eg) eg]
             [else (expr-explain-with es (or eo #f) eg)]))]

    ;; ---- Constraint forms (Phase 3c) ----

    ;; all-different — all variables must have distinct values
    [(surf-all-different vars loc)
     (define elab-vars
       (for/list ([v (in-list vars)])
         (parameterize ([current-relational-fallback? #t])
           (elaborate v env depth))))
     (define errs (filter prologos-error? elab-vars))
     (cond
       [(pair? errs) (car errs)]
       [else
        (define var-names
          (for/list ([ev (in-list elab-vars)])
            (if (expr-logic-var? ev) (expr-logic-var-name ev)
                (gensym 'ad))))
        (expr-all-different var-names)])]

    ;; element — v = xs[i]
    [(surf-element index list-expr var loc)
     (define ei (parameterize ([current-relational-fallback? #t])
                  (elaborate index env depth)))
     (define exs (elaborate list-expr env depth))
     (define ev (parameterize ([current-relational-fallback? #t])
                  (elaborate var env depth)))
     (cond
       [(prologos-error? ei) ei]
       [(prologos-error? exs) exs]
       [(prologos-error? ev) ev]
       [else
        (define i-name (if (expr-logic-var? ei) (expr-logic-var-name ei) (gensym 'ei)))
        (define v-name (if (expr-logic-var? ev) (expr-logic-var-name ev) (gensym 'ev)))
        (expr-element i-name exs v-name)])]

    ;; cumulative — task scheduling
    [(surf-cumulative tasks capacity loc)
     (define et (elaborate tasks env depth))
     (define ec (elaborate capacity env depth))
     (cond
       [(prologos-error? et) et]
       [(prologos-error? ec) ec]
       [else (expr-cumulative et ec)])]

    ;; minimize — BB-min cost variable
    [(surf-minimize cost-var loc)
     (define ecv (parameterize ([current-relational-fallback? #t])
                   (elaborate cost-var env depth)))
     (cond
       [(prologos-error? ecv) ecv]
       [else
        (define cv-name (if (expr-logic-var? ecv) (expr-logic-var-name ecv) (gensym 'cost)))
        (expr-minimize cv-name)])]

    ;; narrow — functional-logic narrowing: [f ?x ?y] = target
    ;; ?-prefixed variables are bound as logic variables in the env before
    ;; elaborating sub-expressions. The LHS must be a function application;
    ;; we extract func + args for the solver to look up definitional trees.
    [(surf-narrow lhs rhs vars loc)
     (let* ([strip-? (lambda (sym)
                       (let ([s (symbol->string sym)])
                         (if (and (> (string-length s) 1) (char=? (string-ref s 0) #\?))
                             (string->symbol (substring s 1))
                             sym)))]
            [narrow-rel-env
             (for/fold ([h (or (current-relational-env) (hasheq))]) ([v (in-list vars)])
               (hash-set h v (expr-logic-var (strip-? v) 'free)))]
            [stripped-vars (map strip-? vars)]
            [elab-rhs (parameterize ([current-relational-env narrow-rel-env])
                        (elaborate rhs env depth))])
       (cond
         [(prologos-error? elab-rhs) elab-rhs]
         [(surf-app? lhs)
          (let* ([func-surf (surf-app-func lhs)]
                 [args-surf (surf-app-args lhs)]
                 [elab-func (parameterize ([current-relational-env narrow-rel-env])
                              (elaborate func-surf env depth))]
                 [elab-args (parameterize ([current-relational-env narrow-rel-env])
                              (for/list ([a (in-list args-surf)])
                                (elaborate a env depth)))])
            (cond
              [(prologos-error? elab-func) elab-func]
              [(findf prologos-error? elab-args) => values]
              [else (expr-narrow elab-func elab-args elab-rhs stripped-vars)]))]
         ;; LHS is not a function call but RHS is → swap (func on RHS, target on LHS)
         [(surf-app? rhs)
          (let* ([func-surf (surf-app-func rhs)]
                 [args-surf (surf-app-args rhs)]
                 [elab-lhs (parameterize ([current-relational-env narrow-rel-env])
                             (elaborate lhs env depth))]
                 [elab-func (parameterize ([current-relational-env narrow-rel-env])
                              (elaborate func-surf env depth))]
                 [elab-args (parameterize ([current-relational-env narrow-rel-env])
                              (for/list ([a (in-list args-surf)])
                                (elaborate a env depth)))])
            (cond
              [(prologos-error? elab-lhs) elab-lhs]
              [(prologos-error? elab-func) elab-func]
              [(findf prologos-error? elab-args) => values]
              ;; Swapped: func+args from RHS, target from LHS
              [else (expr-narrow elab-func elab-args elab-lhs stripped-vars)]))]
         [else
          ;; Neither side is a function call
          (let ([elab-lhs (parameterize ([current-relational-env narrow-rel-env])
                            (elaborate lhs env depth))])
            (if (prologos-error? elab-lhs) elab-lhs
                (expr-narrow elab-lhs '() elab-rhs stripped-vars)))]))]

    ;; Reduce: ML-style pattern matching
    ;; Each arm's body must be elaborated with binding names in scope.
    ;; We add dummy binders (the actual types come from the type checker).
    [(surf-reduce scrutinee arms loc)
     (let ([elab-scrutinee (elaborate scrutinee env depth)])
       (if (prologos-error? elab-scrutinee) elab-scrutinee
           (let ([elab-arms
                  (for/list ([arm (in-list arms)])
                    (elaborate-reduce-arm arm env depth))])
             (define first-err (findf prologos-error? elab-arms))
             (if first-err first-err
                 ;; All match/reduce uses structural PM with native constructors.
                 ;; No Church fold desugaring path needed.
                 (expr-reduce elab-scrutinee elab-arms #t)))))]

    ;; Foreign escape block: racket{ code } [captures] -> [exports]
    ;; Desugar to expr-foreign-fn application:
    ;; 1. Build a Racket lambda from code + capture names
    ;; 2. Eval it in a Racket namespace
    ;; 3. Wrap as expr-foreign-fn
    ;; 4. Apply to elaborated capture expressions
    [(surf-foreign-block lang code-datums captures return-type loc)
     (elaborate-foreign-block lang code-datums captures return-type loc env depth)]

    ;; Fallback
    [_ (prologos-error srcloc-unknown (format "Cannot elaborate: ~a" surf))]))

;; ========================================
;; Elaborate a list of arguments into nested application
;; ========================================
(define (elaborate-args func-expr arg-surfs env depth loc)
  (if (null? arg-surfs)
      func-expr
      (let ([arg (elaborate (car arg-surfs) env depth)])
        (if (prologos-error? arg) arg
            (elaborate-args (expr-app func-expr arg)
                           (cdr arg-surfs) env depth loc)))))

;; ========================================
;; Elaborate a reduce arm
;; ========================================
;; Bindings are added to the environment (with dummy types) so
;; the body's variable references get correct de Bruijn indices.
;; The actual types are resolved by the type checker.
(define (elaborate-reduce-arm arm env depth)
  (match arm
    [(reduce-arm ctor-name bindings body-surf loc)
     ;; Add each binding name to the environment
     ;; Sprint 10: Wildcard `_` — skip env-extend but still increment depth
     ;; so de Bruijn indices for subsequent bindings remain correct.
     (define-values (new-env new-depth)
       (for/fold ([e env] [d depth])
                 ([name (in-list bindings)])
         (if (eq? name '_)
             (values e (+ d 1))               ;; wildcard: skip binding, bump depth
             (values (env-extend e name d) (+ d 1)))))
     (define elab-body (elaborate body-surf new-env new-depth))
     (if (prologos-error? elab-body) elab-body
         (expr-reduce-arm ctor-name (length bindings) elab-body))]))

;; ========================================
;; Elaborate a foreign escape block
;; ========================================
;; Transforms: racket{ code } [captures] -> [exports]
;; into: (expr-app ... (expr-foreign-fn gensym proc arity () marshal-in marshal-out) cap1 cap2 ...)
;;
;; The strategy:
;; 1. Elaborate capture types to core types
;; 2. Build a Racket lambda: (lambda (cap-names...) code-datums...)
;; 3. Eval the lambda in a Racket namespace
;; 4. Determine return type (from annotation or hole for checking context)
;; 5. Build type: Cap1Type -> Cap2Type -> ... -> ReturnType
;; 6. Create expr-foreign-fn with marshallers
;; 7. Apply to elaborated capture expressions
(define (elaborate-foreign-block lang code-datums captures return-type loc env depth)
  ;; Step 1: Elaborate capture types
  (define elab-captures
    (for/list ([cap (in-list captures)])
      (define name (car cap))
      (define type-surf (cadr cap))
      (define type-core (elaborate type-surf env depth))
      (list name type-surf type-core)))

  ;; Check for errors in capture type elaboration
  (define cap-type-error
    (for/or ([cap (in-list elab-captures)])
      (and (prologos-error? (caddr cap)) (caddr cap))))

  (cond
    [cap-type-error cap-type-error]
    [else
     ;; Step 2: Elaborate return type (if provided)
     (define ret-type-core
       (if return-type
           (elaborate return-type env depth)
           #f))  ;; #f = no explicit return type

     (cond
       [(and ret-type-core (prologos-error? ret-type-core)) ret-type-core]
       [else
        (define capture-names (map car captures))
        (define capture-types-core (map caddr elab-captures))

        ;; Step 3: Build a Racket lambda from the code datums
        (define rkt-lambda-expr
          (if (null? capture-names)
              `(lambda () ,@code-datums)
              `(lambda ,capture-names ,@code-datums)))

        ;; Step 4: Eval in a Racket namespace
        (define rkt-ns (make-base-namespace))
        (define rkt-proc
          (with-handlers ([exn:fail? (lambda (e)
                                       (prologos-error loc
                                         (format "foreign block eval error: ~a" (exn-message e))))])
            (eval rkt-lambda-expr rkt-ns)))

        (cond
          [(prologos-error? rkt-proc) rkt-proc]
          [else
           ;; Step 5: Determine return type
           ;; If no explicit return type AND no captures, eval immediately
           ;; and auto-detect the Prologos type from the Racket result
           (define-values (actual-ret-type-core result-val)
             (cond
               ;; Explicit return type provided
               [ret-type-core (values ret-type-core #f)]
               ;; No return type, no captures: eval thunk immediately and detect type
               [(null? capture-names)
                (define rkt-result
                  (with-handlers ([exn:fail? (lambda (e)
                                               (prologos-error loc
                                                 (format "foreign block runtime error: ~a" (exn-message e))))])
                    (rkt-proc)))
                (cond
                  [(prologos-error? rkt-result) (values #f rkt-result)]
                  [(and (exact-integer? rkt-result) (>= rkt-result 0))
                   (values (expr-Nat) (integer->nat rkt-result))]
                  [(boolean? rkt-result)
                   (values (expr-Bool) (if rkt-result (expr-true) (expr-false)))]
                  [(void? rkt-result)
                   (values (expr-Unit) (expr-unit))]
                  [else
                   (values #f
                     (prologos-error loc
                       (format "foreign block: cannot auto-detect type of Racket result: ~a" rkt-result)))])]
               ;; No return type, with captures: error — need explicit type
               [else
                (values #f
                  (prologos-error loc
                    "foreign block with captures requires explicit return type"))]))

           (cond
             ;; If result-val is an error, propagate it
             [(and result-val (prologos-error? result-val)) result-val]
             ;; If we eagerly evaluated (zero captures, auto-detect), return the result directly
             [result-val result-val]
             ;; Normal path: build expr-foreign-fn with marshallers
             [else
              ;; Build the full type: Cap1Type -> Cap2Type -> ... -> ReturnType
              (define full-type
                (foldr (lambda (cap-type rest-type)
                         (expr-Pi 'mw cap-type rest-type))
                       actual-ret-type-core
                       capture-types-core))

              ;; Build marshaller pair from the type
              (define parsed-type (parse-foreign-type full-type))
              (define-values (marshal-in marshal-out) (make-marshaller-pair parsed-type))
              (define arity (length capture-names))

              ;; Create the foreign-fn with a gensym name
              (define fn-name (gensym 'foreign-block))
              (define foreign-fn-val
                (expr-foreign-fn fn-name rkt-proc arity '() marshal-in marshal-out))

              ;; Register the type in global-env so the infer case can find it
              (current-global-env
               (global-env-add (current-global-env) fn-name full-type foreign-fn-val))

              ;; Elaborate capture expressions (they reference variables in scope)
              (define elab-cap-exprs
                (for/list ([cap (in-list captures)])
                  (define name (car cap))
                  (elaborate (surf-var name loc) env depth)))

              ;; Check for errors in capture elaboration
              (define cap-expr-error
                (for/or ([e (in-list elab-cap-exprs)])
                  (and (prologos-error? e) e)))

              (cond
                [cap-expr-error cap-expr-error]
                [else
                 ;; Apply the foreign-fn to all capture expressions
                 (foldl (lambda (cap-expr acc)
                          (expr-app acc cap-expr))
                        foreign-fn-val
                        elab-cap-exprs)])])])])]))

;; ========================================
;; Helper: natural -> level
;; ========================================
(define (nat->level n)
  (if (= n 0) (lzero) (lsuc (nat->level (- n 1)))))

;; ========================================
;; Elaborate a defr variant (Phase 7)
;; ========================================
;; Each variant has params (list of (name . mode) pairs) and body (list of clauses/facts).
;; The params are symbolic (not expressions), so we pass them through.
;; The body elements need elaboration in a relational env where param names
;; resolve to expr-logic-var nodes (not de Bruijn bvars).
(define (elaborate-defr-variant v env depth)
  (match v
    [(surf-defr-variant params body loc)
     ;; Build relational env from params: name → expr-logic-var
     (define rel-env
       (for/hasheq ([p (in-list params)])
         (define name (car p))
         (define mode (or (cdr p) 'free))
         (values name (expr-logic-var name mode))))
     (let ([elab-body
            (parameterize ([current-relational-env rel-env]
                           [current-relational-fallback? #t])
              (for/list ([b (in-list body)])
                (elaborate b env depth)))])
       (define first-err (findf prologos-error? elab-body))
       (if first-err first-err
           (expr-defr-variant params elab-body)))]
    [_ (prologos-error srcloc-unknown (format "Invalid defr variant: ~a" v))]))

;; ========================================
;; Phase E: Process subtype declaration
;; ========================================
;; (subtype Sub Super) — auto-infer coercion for single-field wrappers
;; (subtype Sub Super via fn) — explicit coercion function
;;
;; Registers in both the subtype registry (for type-checker subtype?) and
;; the coercion registry (for reducer try-coerce-via-registry).
;; Also computes transitive closure with existing subtype relationships.
(define (process-subtype-declaration sub-sym super-sym via-fn-sym loc)
  ;; Qualify names with current namespace prefix (if any)
  (define ns-ctx (current-ns-context))
  (define (qualify name)
    (if ns-ctx
        (qualify-name name (ns-context-current-ns ns-ctx))
        name))
  ;; FQN keys for the subtype/coercion registries (used by subtype? via type-key)
  (define sub-fqn (qualify sub-sym))
  ;; Built-in types don't need qualification — they use short names in the registry
  (define super-fqn
    (case super-sym
      [(Int) 'Int] [(Rat) 'Rat] [(Nat) 'Nat]
      [(Posit8) 'Posit8] [(Posit16) 'Posit16]
      [(Posit32) 'Posit32] [(Posit64) 'Posit64]
      [else (qualify super-sym)]))
  ;; Short-name keys (used by try-coerce-via-registry via ctor-meta-type-name)
  (define sub-short sub-sym)
  (define super-short super-sym)

  ;; Build coercion function
  (define coerce-fn
    (cond
      ;; Capability types: no runtime coercion needed — capabilities are
      ;; erased authority proofs (:0 multiplicity). Only the subtype-pair?
      ;; relationship matters for type-level checking.
      [(and (capability-type? sub-sym) (capability-type? super-sym))
       #f]  ;; no coercion for capability subtypes
      ;; Also check FQN forms in case short names don't match
      [(and (capability-type? sub-fqn) (capability-type? super-fqn))
       #f]
      ;; Explicit via function: look up and build a coercion that applies it
      [via-fn-sym
       (define via-qualified (qualify via-fn-sym))
       ;; Build a coercion that constructs (via-fn e) as an application expression.
       ;; The reducer's whnf call in reduce-int-binary/reduce-rat-binary will
       ;; eventually reduce this application to the coerced value.
       (lambda (e)
         (expr-app (expr-fvar via-qualified) e))]
      [else
       ;; Auto-infer: look up constructor metadata for the sub-type
       ;; type-meta is keyed by SHORT name (registered by process-data at preparse time)
       (define ctors (lookup-type-ctors sub-short))
       (cond
         [(and ctors (= (length ctors) 1))
          (define ctor-name (car ctors))
          (define meta (lookup-ctor ctor-name))
          (cond
            ;; Single-field constructor → unwrap
            [(and meta (= (length (ctor-meta-field-types meta)) 1))
             (lambda (e)
               (match e
                 [(expr-app (expr-fvar _) inner) inner]
                 [_ #f]))]
            ;; Nullary constructor — can't auto-infer
            [(and meta (= (length (ctor-meta-field-types meta)) 0))
             (prologos-error loc
               (format "subtype ~a ~a: nullary constructor ~a requires explicit 'via' coercion"
                       sub-sym super-sym ctor-name))]
            [else
             (prologos-error loc
               (format "subtype ~a ~a: constructor ~a has ~a fields, auto-inference requires exactly 1"
                       sub-sym super-sym ctor-name (length (ctor-meta-field-types meta))))])]
         [else
          (prologos-error loc
            (format "subtype ~a ~a: type ~a must have exactly 1 constructor for auto-inference (has ~a)"
                    sub-sym super-sym sub-sym (if ctors (length ctors) 0)))])]))

  (cond
    [(prologos-error? coerce-fn) coerce-fn]
    [else
     ;; Register the direct subtype pair under BOTH FQN and short-name keys.
     ;; FQN: for subtype? in typing-core.rkt (type-key extracts FQN from expr-fvar)
     ;; Short: for try-coerce-via-registry in reduction.rkt (ctor-meta-type-name = short name)
     (register-subtype-pair! sub-fqn super-fqn)
     (when coerce-fn
       (register-coercion! sub-fqn super-fqn coerce-fn))
     (unless (eq? sub-fqn sub-short)
       (register-subtype-pair! sub-short super-short)
       (when coerce-fn
         (register-coercion! sub-short super-short coerce-fn))
       ;; Also register cross-combinations for mixed lookups
       (register-subtype-pair! sub-short super-fqn)
       (when coerce-fn
         (register-coercion! sub-short super-fqn coerce-fn)))

     ;; Compute transitive closure:
     ;; For each existing super of super-fqn (or super-short), register sub as sub of that too
     (define all-supers
       (remove-duplicates
        (append (all-supertypes super-fqn)
                (all-supertypes super-short))))
     (for ([super-of-super (in-list all-supers)])
       (unless (subtype-pair? sub-fqn super-of-super)
         (register-subtype-pair! sub-fqn super-of-super)
         (unless (eq? sub-fqn sub-short)
           (register-subtype-pair! sub-short super-of-super))
         ;; Compose coercions: first coerce sub→super, then super→super-of-super
         ;; Skip coercion composition when coerce-fn is #f (capability subtypes)
         (when coerce-fn
           (define super-coerce (or (lookup-coercion super-fqn super-of-super)
                                    (lookup-coercion super-short super-of-super)))
           (when super-coerce
             (define composed
               (lambda (e)
                 (define intermediate (coerce-fn e))
                 (and intermediate (super-coerce intermediate))))
             (register-coercion! sub-fqn super-of-super composed)
             (unless (eq? sub-fqn sub-short)
               (register-coercion! sub-short super-of-super composed))))))

     ;; For each existing sub of sub-fqn (or sub-short), register them as sub of super too
     (define all-subs
       (remove-duplicates
        (append (all-subtypes sub-fqn)
                (all-subtypes sub-short))))
     (for ([sub-of-sub (in-list all-subs)])
       (unless (subtype-pair? sub-of-sub super-fqn)
         (register-subtype-pair! sub-of-sub super-fqn)
         (register-subtype-pair! sub-of-sub super-short)
         ;; Skip coercion composition when coerce-fn is #f (capability subtypes)
         (when coerce-fn
           (define sub-coerce (or (lookup-coercion sub-of-sub sub-fqn)
                                  (lookup-coercion sub-of-sub sub-short)))
           (when sub-coerce
             (define composed
               (lambda (e)
                 (define intermediate (sub-coerce e))
                 (and intermediate (coerce-fn intermediate))))
             (register-coercion! sub-of-sub super-fqn composed)
             (register-coercion! sub-of-sub super-short composed)))))

     ;; Return — declaration only, no elaborated form to process
     (list 'subtype sub-fqn super-fqn)]))

;; ========================================
;; Capability declaration (Capabilities as Types)
;; ========================================
;; (capability ReadCap) — registers as a capability type.
;; Capabilities are type-level markers used in QTT binders to express
;; authority requirements. At :0 they are erased; at :1 they are linear.
;;
;; Registers in the capability registry (for kind-marker checking) and
;; returns a 'capability result so the driver can install the name as a type.
;; ========================================
;; Process selection declaration
;; ========================================
;; :includes resolution helpers
;; ========================================

;; Resolve :includes — look up each included selection, validate parent schema match,
;; collect their requires/provides paths.
;; Returns (values incl-req incl-prov error-or-#f)
(define (resolve-includes incl-names expected-schema-fqn sel-name loc)
  (let loop ([remaining incl-names] [req-acc '()] [prov-acc '()])
    (cond
      [(null? remaining)
       (values req-acc prov-acc #f)]
      [else
       (define incl-sym (car remaining))
       ;; Look up the included selection (try qualified and bare names)
       (define ns-ctx (current-ns-context))
       (define incl-fqn (if ns-ctx
                             (qualify-name incl-sym (ns-context-current-ns ns-ctx))
                             incl-sym))
       (define incl-sel (or (lookup-selection incl-fqn)
                            (lookup-selection incl-sym)))
       (cond
         [(not incl-sel)
          (values '() '()
                  (prologos-error loc
                                  (format "selection ~a: :includes references unknown selection ~a"
                                          sel-name incl-sym)))]
         ;; Verify included selection is from the same schema
         [(not (or (eq? (selection-entry-schema-name incl-sel) expected-schema-fqn)
                   ;; Also compare short names in case of qualification mismatch
                   (let-values ([(_p1 s1) (split-qualified-name (selection-entry-schema-name incl-sel))]
                                [(_p2 s2) (split-qualified-name expected-schema-fqn)])
                     (and s1 s2 (eq? s1 s2)))))
          (values '() '()
                  (prologos-error loc
                                  (format "selection ~a: :includes ~a is from schema ~a, expected ~a"
                                          sel-name incl-sym
                                          (selection-entry-schema-name incl-sel)
                                          expected-schema-fqn)))]
         [else
          (loop (cdr remaining)
                (append req-acc (selection-entry-requires-paths incl-sel))
                (append prov-acc (selection-entry-provides-paths incl-sel)))])])))

;; Path union: deduplicate paths, applying join semantics (§11.3).
;; - If both (#:address #:zip) and (#:address *) exist, keep only (#:address *)
;;   because * ⊇ any specific field.
;; - If (#:address #:zip) and (#:address #:city), keep both.
;; - Identical paths are deduplicated.
(define (path-union paths)
  (define (path-subsumes? broader narrower)
    ;; Does broader subsume narrower?
    ;; (#:address *) subsumes (#:address #:zip) — wildcard covers all fields
    ;; (#:address **) subsumes (#:address #:foo #:bar) — globstar covers all depths
    (cond
      [(null? broader) #t]  ;; empty prefix subsumes nothing... actually if both empty, equal
      [(null? narrower) #f]  ;; broader still has segments but narrower exhausted
      [else
       (define b-seg (car broader))
       (define n-seg (car narrower))
       (cond
         ;; Wildcard at this level: subsumes everything at this depth
         [(eq? b-seg '*)
          (null? (cdr broader))]  ;; * must be terminal
         ;; Globstar: subsumes everything from here down
         [(eq? b-seg '**)
          #t]
         ;; Same segment: continue deeper
         [(equal? b-seg n-seg)
          (path-subsumes? (cdr broader) (cdr narrower))]
         ;; Different segments: no subsumption
         [else #f])]))
  ;; Remove paths that are subsumed by a broader path in the set
  (define unique (remove-duplicates paths equal?))
  (filter (lambda (path)
            ;; Keep this path unless some OTHER path in unique subsumes it
            (not (for/or ([other (in-list unique)])
                   (and (not (equal? other path))
                        (path-subsumes? other path)))))
          unique))

;; ========================================
;; Process selection declaration
;; ========================================
;; Validates:
;;   1. Parent schema exists in schema registry
;;   2. Required/provided field paths are valid fields in the schema
;;   3. :includes references resolve to existing selections from same schema
;; Then registers the selection with resolved paths and returns a 'selection result.
(define (process-selection-declaration name schema-name req prov incl loc)
  (define ns-ctx (current-ns-context))
  (define (qualify sym)
    (if ns-ctx
        (qualify-name sym (ns-context-current-ns ns-ctx))
        sym))
  (define name-fqn (qualify name))
  (define name-short name)
  ;; Look up the parent schema (try both qualified and bare names)
  (define schema-fqn (qualify schema-name))
  (define schema (or (lookup-schema schema-fqn)
                     (lookup-schema schema-name)))
  (cond
    [(not schema)
     (prologos-error loc
                     (format "selection ~a: schema ~a not found" name schema-name))]
    [else
     ;; Validate field paths against schema fields (deep validation).
     ;; Paths are structured lists: (#:name) or (#:address #:zip) or (#:address *).
     ;; For multi-segment paths, each segment is validated against the schema at that level.
     ;; e.g., :address.zip → validate :address in User, then validate :zip in Address.
     ;;
     ;; validate-path: validate a single structured path against a schema.
     ;; Returns #f if valid, or a prologos-error.
     (define (validate-path path current-schema current-schema-name)
       (cond
         [(null? path) #f]  ;; fully consumed path — valid
         [else
          (define seg (car path))
          (define rest (cdr path))
          (define fields (schema-entry-fields current-schema))
          (define field-kws
            (for/list ([f (in-list fields)])
              (string->keyword (symbol->string (schema-field-keyword f)))))
          (cond
            ;; Wildcard: valid if schema has any fields (no deeper validation)
            [(or (eq? seg '*) (eq? seg '**))
             (if (null? fields)
                 (prologos-error loc
                                 (format "selection ~a: wildcard on schema ~a with no fields"
                                         name current-schema-name))
                 #f)]
            ;; Keyword segment
            [(keyword? seg)
             (if (not (member seg field-kws))
                 (prologos-error loc
                                 (format "selection ~a: field :~a not found in schema ~a"
                                         name (keyword->string seg) current-schema-name))
                 ;; Field exists — if more segments remain, validate deeper
                 (if (null? rest)
                     #f  ;; leaf field, valid
                     ;; Find the field's type and check if it's a schema for deeper validation
                     (let* ([kw-sym (string->symbol (keyword->string seg))]
                            [field (for/first ([f (in-list fields)]
                                              #:when (eq? (schema-field-keyword f) kw-sym))
                                     f)]
                            [type-datum (schema-field-type-datum field)])
                       ;; Type datum might be a symbol (schema name) or compound type
                       (cond
                         [(symbol? type-datum)
                          (define nested-schema
                            (or (lookup-schema type-datum)
                                ;; Try without namespace prefix (short name lookup)
                                (let-values ([(_prefix short) (split-qualified-name type-datum)])
                                  (and short (lookup-schema short)))))
                          (if nested-schema
                              (validate-path rest nested-schema type-datum)
                              ;; Type is not a schema — can't traverse deeper
                              (prologos-error loc
                                              (format "selection ~a: field :~a in ~a has type ~a which is not a schema (cannot traverse deeper with :~a)"
                                                      name (keyword->string seg) current-schema-name
                                                      type-datum
                                                      (string-join (map (lambda (s)
                                                                          (if (keyword? s)
                                                                              (keyword->string s)
                                                                              (format "~a" s)))
                                                                        rest) "."))))]
                         [else
                          ;; Compound type — can't traverse into non-schema types
                          (prologos-error loc
                                          (format "selection ~a: field :~a in ~a has compound type ~v which is not a schema"
                                                  name (keyword->string seg) current-schema-name type-datum))]))))]
            [else
             (prologos-error loc
                             (format "selection ~a: unexpected path segment ~v"
                                     name seg))])]))
     ;; Validate all paths
     (define field-err
       (for/or ([path (in-list (append req prov))])
         (cond
           [(not (pair? path))
            (prologos-error loc
                            (format "selection ~a: malformed path ~v" name path))]
           [else (validate-path path schema schema-name)])))
     (cond
       [(prologos-error? field-err) field-err]
       [else
        ;; Resolve :includes — look up each included selection, collect their paths
        (define-values (incl-req incl-prov incl-err)
          (resolve-includes incl schema-fqn name loc))
        (cond
          [(prologos-error? incl-err) incl-err]
          [else
           ;; Compute effective paths: union of own + included
           (define eff-req (path-union (append req incl-req)))
           (define eff-prov (path-union (append prov incl-prov)))
           ;; Register the selection with effective (resolved) paths
           (register-selection! name-fqn
                                (selection-entry name-fqn schema-fqn eff-req eff-prov incl loc))
           (unless (eq? name-fqn name-short)
             (register-selection! name-short
                                  (selection-entry name-short schema-fqn eff-req eff-prov incl loc)))
           ;; Return result for driver to install as type in global-env
           (list 'selection name-fqn name-short schema-name)])])]))

(define (process-capability-declaration name params loc)
  ;; Qualify name with current namespace prefix
  (define ns-ctx (current-ns-context))
  (define (qualify sym)
    (if ns-ctx
        (qualify-name sym (ns-context-current-ns ns-ctx))
        sym))
  (define name-fqn (qualify name))
  (define name-short name)

  ;; Build the capability's kind type.
  ;; Nullary: (expr-Type 0)
  ;; Dependent: Pi(p :0 T1, Pi(q :0 T2, ... (expr-Type 0)))
  ;; Indices use :0 multiplicity — they are computationally irrelevant.
  (define cap-type
    (if (null? params)
        (expr-Type 0)
        ;; Elaborate each param's type and build a Pi chain.
        ;; Thread env/depth so later params can reference earlier ones.
        (let loop ([ps params] [env (hasheq)] [depth 0])
          (cond
            [(null? ps) (expr-Type 0)]
            [else
             (define bi (car ps))
             (define param-name (binder-info-name bi))
             (define ty-surf (binder-info-type bi))
             (define ty (elaborate ty-surf env depth))
             (if (prologos-error? ty)
                 ty  ;; propagate error
                 (let* ([rest (loop (cdr ps)
                                    (env-extend env param-name depth)
                                    (+ depth 1))])
                   (if (prologos-error? rest)
                       rest
                       (expr-Pi 'm0 ty rest))))]))))

  (if (prologos-error? cap-type)
      cap-type
      (let ([meta (capability-meta name-fqn params (hasheq))])
        ;; Register in the capability registry under both FQN and short name.
        ;; This enables capability-type? to check either form.
        (register-capability! name-fqn meta)
        (unless (eq? name-fqn name-short)
          (register-capability! name-short meta))
        ;; Return: driver installs the name as a type in the global env
        (list 'capability name-fqn name-short cap-type))))

;; ========================================
;; Phase S3: Session type elaboration
;; Converts surf-sess-* tree → sess-* tree (de Bruijn indices for recursion)
;; ========================================

;; S3d: Expression-level scope for dependent session binders.
;; When !: or ?: introduces a binder, the name must be in scope when
;; elaborating types in the continuation.  Racket parameters let us
;; thread this through without changing every call site.
(define current-sess-expr-env   (make-parameter '()))
(define current-sess-expr-depth (make-parameter 0))

;; S3c: Wrap a session step in an error-offer when :throws is active.
;; Protocol step S becomes (sess-offer ((:ok S) (:error (sess-send ErrorType (sess-end)))))
(define (maybe-wrap-throws step throws-type)
  (if throws-type
      (sess-offer (list (cons ':ok step) (cons ':error (sess-send throws-type (sess-end)))))
      step))

;; Elaborate a session body.
;; rec-stack: list of (label . depth) for named recursion variables.
;; depth: current recursion nesting depth (for de Bruijn indexing of session vars).
;; throws-type: #f or elaborated error type for :throws desugaring (S3c).
(define (elaborate-session-body surf rec-stack depth [session-name #f] [throws-type #f])
  (match surf
    [(surf-sess-send type-surf cont-surf _loc)
     (let ([ty (elaborate type-surf (current-sess-expr-env) (current-sess-expr-depth))])
       (if (prologos-error? ty) ty
           (let ([cont (elaborate-session-body cont-surf rec-stack depth session-name throws-type)])
             (if (prologos-error? cont) cont
                 (maybe-wrap-throws (sess-send ty cont) throws-type)))))]

    [(surf-sess-recv type-surf cont-surf _loc)
     (let ([ty (elaborate type-surf (current-sess-expr-env) (current-sess-expr-depth))])
       (if (prologos-error? ty) ty
           (let ([cont (elaborate-session-body cont-surf rec-stack depth session-name throws-type)])
             (if (prologos-error? cont) cont
                 (maybe-wrap-throws (sess-recv ty cont) throws-type)))))]

    [(surf-sess-async-send type-surf cont-surf _loc)
     (let ([ty (elaborate type-surf (current-sess-expr-env) (current-sess-expr-depth))])
       (if (prologos-error? ty) ty
           (let ([cont (elaborate-session-body cont-surf rec-stack depth session-name throws-type)])
             (if (prologos-error? cont) cont
                 (maybe-wrap-throws (sess-async-send ty cont) throws-type)))))]

    [(surf-sess-async-recv type-surf cont-surf _loc)
     (let ([ty (elaborate type-surf (current-sess-expr-env) (current-sess-expr-depth))])
       (if (prologos-error? ty) ty
           (let ([cont (elaborate-session-body cont-surf rec-stack depth session-name throws-type)])
             (if (prologos-error? cont) cont
                 (maybe-wrap-throws (sess-async-recv ty cont) throws-type)))))]

    [(surf-sess-dsend name type-surf cont-surf _loc)
     (let ([ty (elaborate type-surf (current-sess-expr-env) (current-sess-expr-depth))])
       (if (prologos-error? ty) ty
           ;; Dependent send: binder goes into scope for continuation elaboration.
           ;; env-extend + depth+1 gives name de Bruijn index 0 in the continuation.
           (let ([cont (parameterize ([current-sess-expr-env
                                       (env-extend (current-sess-expr-env) name (current-sess-expr-depth))]
                                      [current-sess-expr-depth
                                       (+ (current-sess-expr-depth) 1)])
                         (elaborate-session-body cont-surf rec-stack depth session-name throws-type))])
             (if (prologos-error? cont) cont
                 (maybe-wrap-throws (sess-dsend ty cont) throws-type)))))]

    [(surf-sess-drecv name type-surf cont-surf _loc)
     (let ([ty (elaborate type-surf (current-sess-expr-env) (current-sess-expr-depth))])
       (if (prologos-error? ty) ty
           ;; Dependent recv: same binder scoping as dsend.
           (let ([cont (parameterize ([current-sess-expr-env
                                       (env-extend (current-sess-expr-env) name (current-sess-expr-depth))]
                                      [current-sess-expr-depth
                                       (+ (current-sess-expr-depth) 1)])
                         (elaborate-session-body cont-surf rec-stack depth session-name throws-type))])
             (if (prologos-error? cont) cont
                 (maybe-wrap-throws (sess-drecv ty cont) throws-type)))))]

    [(surf-sess-choice branches-surf _loc)
     (let ([branches (elaborate-session-branches branches-surf rec-stack depth session-name throws-type)])
       (if (prologos-error? branches) branches
           (sess-choice branches)))]

    [(surf-sess-offer branches-surf _loc)
     (let ([branches (elaborate-session-branches branches-surf rec-stack depth session-name throws-type)])
       (if (prologos-error? branches) branches
           (sess-offer branches)))]

    [(surf-sess-rec label body-surf _loc)
     ;; Push the recursion label onto the rec-stack at current depth.
     ;; For anonymous Mu (label=#f), use the session name if available;
     ;; this supports (session Loop (Mu (Send Nat (SVar Loop)))) pattern.
     ;; Also register 'rec as an alias for unnamed Mus so WS-mode bare
     ;; `rec` as recursion variable works (e.g., `| :inc -> ! Nat -> rec`).
     (let* ([effective-label (or label session-name (gensym 'μ))]
            [base-stack (cons (cons effective-label depth) rec-stack)]
            [new-stack (if (not label)
                          ;; Unnamed Mu: also register 'rec so WS `rec` resolves
                          (cons (cons 'rec depth) base-stack)
                          base-stack)]
            [body (elaborate-session-body body-surf new-stack (add1 depth) session-name throws-type)])
       (if (prologos-error? body) body
           (sess-mu body)))]

    [(surf-sess-var name _loc)
     ;; Look up the named recursion variable in the stack and compute de Bruijn index
     (let loop ([stack rec-stack])
       (cond
         [(null? stack)
          (prologos-error _loc (format "Unbound session recursion variable: ~a" name))]
         [(eq? (caar stack) name)
          (sess-svar (- (sub1 depth) (cdar stack)))]
         [else (loop (cdr stack))]))]

    [(surf-sess-end _loc)
     (sess-end)]

    [(surf-sess-shared body-surf _loc)
     ;; shared is an annotation; for now, elaborate the body and mark as :w
     ;; Multiplicity annotation is deferred to S4 (propagator integration)
     (elaborate-session-body body-surf rec-stack depth session-name throws-type)]

    [(surf-sess-ref name _loc)
     ;; Named session reference: look up in session registry
     (let ([entry (lookup-session name)])
       (if entry
           (session-entry-session-type entry)
           ;; Also check if it could be a recursion variable for implicit rec
           (let loop ([stack rec-stack])
             (cond
               [(null? stack)
                (prologos-error _loc (format "Unknown session type: ~a" name))]
               [(eq? (caar stack) name)
                (sess-svar (- (sub1 depth) (cdar stack)))]
               [else (loop (cdr stack))]))))]

    [_ (prologos-error #f (format "Unknown session body form: ~a" surf))]))

;; Elaborate a list of session branches (for choice/offer).
;; Each branch is a surf-sess-branch.
;; Returns: assoc list of (cons label sess-tree), or prologos-error.
(define (elaborate-session-branches branches-surf rec-stack depth session-name [throws-type #f])
  (let loop ([remaining branches-surf] [acc '()])
    (cond
      [(null? remaining) (reverse acc)]
      [else
       (define branch (car remaining))
       (define label (surf-sess-branch-label branch))
       (define cont (elaborate-session-body (surf-sess-branch-cont branch) rec-stack depth session-name throws-type))
       (if (prologos-error? cont) cont
           (loop (cdr remaining) (cons (cons label cont) acc)))])))

;; ========================================
;; Phase S5a: Capability binder elaboration for processes
;; ========================================

;; Elaborate a list of binder-info structs (capability binders from process headers).
;; Each binder-info has: name, mult, type (surf form).
;; Returns: list of (cons name elaborated-type), or prologos-error on first failure.
;; Also emits W2001 warning for :w multiplicity on capability types.
(define (elaborate-cap-binders cap-binders loc)
  (if (null? cap-binders) '()
      (let loop ([remaining cap-binders] [acc '()])
        (if (null? remaining) (reverse acc)
            (let* ([bi (car remaining)]
                   [name (binder-info-name bi)]
                   [mult (or (binder-info-mult bi) 'm0)] ;; default to :0 for caps
                   [ty-surf (binder-info-type bi)]
                   [ty (elaborate ty-surf)])
              (if (prologos-error? ty) ty
                  (begin
                    ;; W2001: warn if capability with :w multiplicity
                    (when (and (eq? mult 'mw) (capability-type-expr? ty))
                      (emit-capability-warning! (capability-type-expr? ty) 'mw))
                    (loop (cdr remaining)
                          (cons (list name mult ty) acc)))))))))

;; Build capability scope entries from elaborated cap binders.
;; Each cap binder (name mult type) where type is a capability → push into scope.
;; Scope entries are (cons depth type-expr); for process caps, depth is 0
;; (they're at the top-level of the process, not inside any Pi/lambda).
(define (build-cap-scope elab-caps existing-scope)
  (for/fold ([scope existing-scope]) ([cap (in-list elab-caps)])
    (define ty (third cap))
    (if (capability-type-expr? ty)
        (cons (cons 0 ty) scope)
        scope)))

;; ========================================
;; Phase S5b: Boundary operation elaboration helper
;; ========================================

;; Elaborate a boundary operation (open/connect/listen).
;; Elaborates the argument expression and session type, resolves the cap
;; in the current capability scope, then builds the core proc struct.
(define (elaborate-boundary-op kind arg-surf sess-type-surf cap-sym cont-surf)
  (define arg (elaborate arg-surf))
  (if (prologos-error? arg) arg
      (let ([sess-ty (elaborate sess-type-surf)])
        (if (prologos-error? sess-ty) sess-ty
            (let ([cont (elaborate-proc-body cont-surf)])
              (if (prologos-error? cont) cont
                  ;; Resolve capability: look up cap-sym in the capability scope
                  (let* ([cap-type (if cap-sym
                                       (let ([scope (current-capability-scope)])
                                         ;; Look for a binding with this name in caps from
                                         ;; the enclosing process header
                                         (expr-fvar cap-sym))
                                       #f)])
                    (case kind
                      [(open)    (proc-open    arg sess-ty cap-type cont)]
                      [(connect) (proc-connect arg sess-ty cap-type cont)]
                      [(listen)  (proc-listen  arg sess-ty cap-type cont)]))))))))

;; ========================================
;; Phase S3: Process elaboration
;; Converts surf-proc-* tree → proc-* tree
;; ========================================

;; Elaborate a process body.
;; Returns: proc-* tree, or prologos-error.
(define (elaborate-proc-body surf)
  (match surf
    [(surf-proc-send chan expr-surf cont-surf _loc)
     (let ([expr (elaborate expr-surf)])
       (if (prologos-error? expr) expr
           (let ([cont (elaborate-proc-body cont-surf)])
             (if (prologos-error? cont) cont
                 (proc-send expr chan cont)))))]

    [(surf-proc-recv var chan cont-surf _loc)
     ;; recv binds a variable; preserve binding name for data-flow analysis (AD-A0).
     ;; proc-recv takes (chan binding type cont):
     ;;   binding = symbol (variable name) | #f
     ;;   type annotation is #f when unspecified (typing judgment infers from session context)
     (let ([cont (elaborate-proc-body cont-surf)])
       (if (prologos-error? cont) cont
           (proc-recv chan var #f cont)))]

    [(surf-proc-select chan label cont-surf _loc)
     (let ([cont (elaborate-proc-body cont-surf)])
       (if (prologos-error? cont) cont
           (proc-sel chan label cont)))]

    [(surf-proc-offer chan branches-surf _loc)
     (let ([branches (elaborate-proc-branches branches-surf)])
       (if (prologos-error? branches) branches
           (proc-case chan branches)))]

    [(surf-proc-stop _loc)
     (proc-stop)]

    [(surf-proc-new channels session-type-surf body-surf _loc)
     (let ([sess-ty (if session-type-surf (elaborate session-type-surf) #f)])
       (if (and sess-ty (prologos-error? sess-ty)) sess-ty
           (let ([body (elaborate-proc-body body-surf)])
             (if (prologos-error? body) body
                 ;; For now, session type is the elaborated type expression
                 ;; proc-new takes (session cont) — we'll use the type expr as session placeholder
                 (proc-new (or sess-ty (expr-Type 0)) body)))))]

    [(surf-proc-par left-surf right-surf _loc)
     (let ([left (elaborate-proc-body left-surf)])
       (if (prologos-error? left) left
           (let ([right (elaborate-proc-body right-surf)])
             (if (prologos-error? right) right
                 (proc-par left right)))))]

    [(surf-proc-link chan1 chan2 _loc)
     (proc-link chan1 chan2)]

    [(surf-proc-rec _label _loc)
     ;; Tail recursion marker — at process level, this is a jump back
     ;; In the core AST, we don't have a direct rec process form;
     ;; for now emit as a sentinel that typing-sessions can handle
     (proc-stop)]  ;; TODO: S4 will add proper process recursion propagator

    ;; S5b: Boundary operations
    [(surf-proc-open path-surf sess-type-surf cap-sym cont-surf _loc)
     (elaborate-boundary-op 'open path-surf sess-type-surf cap-sym cont-surf)]
    [(surf-proc-connect addr-surf sess-type-surf cap-sym cont-surf _loc)
     (elaborate-boundary-op 'connect addr-surf sess-type-surf cap-sym cont-surf)]
    [(surf-proc-listen port-surf sess-type-surf cap-sym cont-surf _loc)
     (elaborate-boundary-op 'listen port-surf sess-type-surf cap-sym cont-surf)]

    [_ (prologos-error #f (format "Unknown process body form: ~a" surf))]))

;; Elaborate process offer branches.
;; Returns: assoc list of (cons label proc-tree), or prologos-error.
(define (elaborate-proc-branches branches-surf)
  (let loop ([remaining branches-surf] [acc '()])
    (cond
      [(null? remaining) (reverse acc)]
      [else
       (define branch (car remaining))
       (define label (surf-proc-offer-branch-label branch))
       (define body (elaborate-proc-body (surf-proc-offer-branch-body branch)))
       (if (prologos-error? body) body
           (loop (cdr remaining) (cons (cons label body) acc)))])))

;; ========================================
;; Elaborate top-level commands
;; Returns the surface command + elaborated expressions,
;; or a prologos-error
;; ========================================
(define (elaborate-top-level surf)
  (match surf
    [(surf-def name type-surf body-surf loc)
     (cond
       ;; Sprint 10: No type annotation — elaborate body only
       [(not type-surf)
        (let ([bd (elaborate body-surf)])
          (if (prologos-error? bd) bd
              (list 'def name #f bd)))]
       [else
        (let ([ty (elaborate type-surf)]
              [bd (elaborate body-surf)])
          (cond
            [(prologos-error? ty) ty]
            [(prologos-error? bd) bd]
            [else (list 'def name ty bd)]))])]

    [(surf-check expr-surf type-surf loc)
     (let ([e (elaborate expr-surf)]
           [t (elaborate type-surf)])
       (cond
         [(prologos-error? e) e]
         [(prologos-error? t) t]
         [else (list 'check e t)]))]

    [(surf-eval expr-surf loc)
     (let ([e (elaborate expr-surf)])
       (if (prologos-error? e) e
           (list 'eval e)))]

    [(surf-infer expr-surf loc)
     (let ([e (elaborate expr-surf)])
       (if (prologos-error? e) e
           (list 'infer e)))]

    ;; Inspection: expand — datum passes through, handled in driver
    [(surf-expand datum loc)
     (list 'expand datum)]

    ;; Inspection: expand-1 — single-step expansion, datum passes through
    [(surf-expand-1 datum loc)
     (list 'expand-1 datum)]

    ;; Inspection: expand-full — all transforms, datum passes through
    [(surf-expand-full datum loc)
     (list 'expand-full datum)]

    ;; Inspection: parse — surface AST passes through, shown directly
    [(surf-parse expr-surf loc)
     (list 'parse expr-surf)]

    ;; Inspection: elaborate — elaborate the sub-expression
    [(surf-elaborate expr-surf loc)
     (let ([e (elaborate expr-surf)])
       (if (prologos-error? e) e
           (list 'elaborate e)))]

    ;; defr — named relation definition (Phase 7)
    ;; Elaborate to (list 'defr name expr-defr-node) for driver processing
    [(surf-defr name schema variants loc)
     (let ([elab (elaborate surf)])
       (if (prologos-error? elab) elab
           (list 'defr name elab)))]

    [(surf-defn name _ _ _ loc)
     (prologos-error loc "defn should have been expanded by the macro system before elaboration")]

    [(surf-the-fn _ _ _ loc)
     (prologos-error loc "the-fn should have been expanded by the macro system before elaboration")]

    ;; Phase E: subtype declaration
    ;; (subtype Sub Super) or (subtype Sub Super via coerce-fn)
    ;; Registers in subtype + coercion registries; no elaborated AST.
    [(surf-subtype sub-type super-type via-fn loc)
     (process-subtype-declaration sub-type super-type via-fn loc)]

    ;; Selection declaration
    ;; (selection Name from Schema :requires [...] :provides [...] :includes [...])
    ;; Validates schema exists, validates field paths, registers selection, creates type.
    [(surf-selection name schema-name req prov incl loc)
     (process-selection-declaration name schema-name req prov incl loc)]

    ;; Capability declaration
    ;; (capability Name) — registers in capability registry + as a zero-field type.
    [(surf-capability name params loc)
     (process-capability-declaration name params loc)]

    ;; Capability inference REPL commands (Phase 5)
    [(surf-cap-closure name _loc)
     (list 'cap-closure name)]

    [(surf-cap-audit name cap-name _loc)
     (list 'cap-audit name cap-name)]

    [(surf-cap-verify name _loc)
     (list 'cap-verify name)]

    [(surf-cap-bridge name _loc)
     (list 'cap-bridge name)]

    ;; Phase S3: Session type declaration
    ;; Elaborate body to sess-* tree, register in session registry.
    ;; S3c: Extract :throws metadata for error-offer desugaring.
    [(surf-session name metadata body-surf loc)
     ;; S3c: Check for :throws in metadata and elaborate the error type
     (let* ([throws-pair (assq ':throws metadata)]
            [throws-type
             (if throws-pair
                 (let ([ty (elaborate (cdr throws-pair))])
                   (if (prologos-error? ty) ty ty))
                 #f)])
       (if (and throws-type (prologos-error? throws-type)) throws-type
           (let ([sess-body (elaborate-session-body body-surf '() 0 name throws-type)])
             (if (prologos-error? sess-body) sess-body
                 (begin
                   ;; Register in session registry (both bare and FQN)
                   (register-session! name (session-entry name sess-body loc))
                   (when (current-ns-context)
                     (define fqn (qualify-name name
                                   (ns-context-current-ns (current-ns-context))))
                     (register-session! fqn (session-entry fqn sess-body loc)))
                   (list 'session name sess-body))))))]

    ;; Phase S3+S5a: Process definition
    ;; Elaborate session type annotation (if any), elaborate capability binders,
    ;; elaborate process body with capabilities in scope.
    [(surf-defproc name session-type-surf channels caps body-surf loc)
     (let ([sess-ty (if session-type-surf (elaborate session-type-surf) #f)])
       (if (and sess-ty (prologos-error? sess-ty)) sess-ty
           ;; S5a: Elaborate capability binders and push into scope
           (let ([elab-caps (elaborate-cap-binders caps loc)])
             (if (prologos-error? elab-caps) elab-caps
                 (let ([cap-scope (build-cap-scope elab-caps (current-capability-scope))])
                   (define proc-body
                     (parameterize ([current-capability-scope cap-scope])
                       (elaborate-proc-body body-surf)))
                   (if (prologos-error? proc-body) proc-body
                       (list 'defproc name sess-ty channels elab-caps proc-body)))))))]

    ;; Phase S3+S5a: Anonymous process
    [(surf-proc session-type-surf channels caps body-surf loc)
     (let ([sess-ty (if session-type-surf (elaborate session-type-surf) #f)])
       (if (and sess-ty (prologos-error? sess-ty)) sess-ty
           ;; S5a: Elaborate capability binders and push into scope
           (let ([elab-caps (elaborate-cap-binders caps loc)])
             (if (prologos-error? elab-caps) elab-caps
                 (let ([cap-scope (build-cap-scope elab-caps (current-capability-scope))])
                   (define proc-body
                     (parameterize ([current-capability-scope cap-scope])
                       (elaborate-proc-body body-surf)))
                   (if (prologos-error? proc-body) proc-body
                       (list 'proc sess-ty channels elab-caps proc-body)))))))]

    ;; Phase S3: dual — compute dual of a named session type
    [(surf-dual session-ref-surf loc)
     (let ([sess-ref (elaborate session-ref-surf)])
       (if (prologos-error? sess-ref) sess-ref
           ;; Look up the session name and apply dual
           (let* ([name (if (expr-fvar? sess-ref) (expr-fvar-name sess-ref)
                            (if (symbol? session-ref-surf) session-ref-surf #f))]
                  [entry (and name (lookup-session name))])
             (if entry
                 (list 'dual name (dual (session-entry-session-type entry)))
                 (prologos-error loc (format "Unknown session type for dual: ~a" sess-ref))))))]

    ;; Phase S6: Strategy declaration
    ;; Validate properties, register in strategy registry.
    [(surf-strategy name raw-props loc)
     ;; Convert raw property pairs (cons key val) to flat keyword list
     (define flat-props
       (apply append (map (lambda (p) (list (car p) (cdr p))) raw-props)))
     (define-values (props err) (parse-strategy-properties flat-props))
     (if err
         (prologos-error loc err)
         (begin
           (register-strategy! name (strategy-entry name props loc))
           (when (current-ns-context)
             (define fqn (qualify-name name
                           (ns-context-current-ns (current-ns-context))))
             (register-strategy! fqn (strategy-entry fqn props loc)))
           (list 'strategy name props)))]

    ;; Phase S7c: Spawn command — execute a registered or inline process
    [(surf-spawn target _strategy loc)
     (cond
       ;; Named process: look up from process registry
       [(surf-var? target)
        (define name (surf-var-name target))
        (define entry (lookup-process name))
        ;; Also try FQN
        (define fqn-entry
          (and (not entry) (current-ns-context)
               (lookup-process
                (qualify-name name
                  (ns-context-current-ns (current-ns-context))))))
        (define resolved (or entry fqn-entry))
        (if resolved
            (list 'spawn name
                  (process-entry-session-type resolved)
                  (process-entry-proc-body resolved)
                  (process-entry-caps resolved))
            (prologos-error loc
              (format "Unknown process: ~a" name)))]
       ;; Anonymous process (surf-proc): elaborate inline
       [(surf-proc? target)
        (define elab (elaborate-top-level target))
        (if (prologos-error? elab) elab
            (match elab
              [(list 'proc sess-ty _channels caps proc-body)
               (list 'spawn #f sess-ty proc-body caps)]
              [_ (prologos-error loc "spawn target must be a process")]))]
       [else
        (prologos-error loc "spawn requires a process name or inline process")])]

    ;; Phase S7d: Spawn-with command — execute a process with strategy
    [(surf-spawn-with strategy-ref raw-overrides target loc)
     ;; 1. Resolve base strategy properties
     (define base-props
       (cond
         [(not strategy-ref) strategy-defaults]
         [else
          (define entry (lookup-strategy strategy-ref))
          (define fqn-entry
            (and (not entry) (current-ns-context)
                 (lookup-strategy
                  (qualify-name strategy-ref
                    (ns-context-current-ns (current-ns-context))))))
          (define resolved (or entry fqn-entry))
          (if resolved
              (strategy-entry-properties resolved)
              (prologos-error loc
                (format "Unknown strategy: ~a" strategy-ref)))]))
     (if (prologos-error? base-props) base-props
         (let ()
           ;; 2. Merge overrides into base properties (last one wins)
           (define final-props
             (if raw-overrides
                 (for/fold ([props base-props])
                           ([pair (in-list raw-overrides)])
                   (hash-set props (car pair) (cdr pair)))
                 base-props))
           ;; 3. Resolve process target (same as surf-spawn)
           (define proc-result
             (cond
               [(surf-var? target)
                (define name (surf-var-name target))
                (define entry (lookup-process name))
                (define fqn-entry
                  (and (not entry) (current-ns-context)
                       (lookup-process
                        (qualify-name name
                          (ns-context-current-ns (current-ns-context))))))
                (define resolved (or entry fqn-entry))
                (if resolved
                    (list name
                          (process-entry-session-type resolved)
                          (process-entry-proc-body resolved)
                          (process-entry-caps resolved))
                    (prologos-error loc
                      (format "Unknown process: ~a" name)))]
               [(surf-proc? target)
                (define elab (elaborate-top-level target))
                (if (prologos-error? elab) elab
                    (match elab
                      [(list 'proc sess-ty _channels caps proc-body)
                       (list #f sess-ty proc-body caps)]
                      [_ (prologos-error loc "spawn-with target must be a process")]))]
               [else
                (prologos-error loc "spawn-with requires a process name or inline process")]))
           (if (prologos-error? proc-result) proc-result
               (match proc-result
                 [(list proc-name sess-ty proc-body caps)
                  (list 'spawn-with proc-name sess-ty proc-body caps final-props)]))))]

    [_ (prologos-error srcloc-unknown (format "Unknown top-level form: ~a" surf))]))

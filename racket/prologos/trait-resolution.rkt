#lang racket/base

;;;
;;; PROLOGOS TRAIT RESOLUTION
;;; Resolves trait-constraint metavariables to concrete dictionary expressions.
;;; After type-checking, walks the trait-constraint map and solves metas
;;; whose type arguments are fully ground.
;;;

(require racket/match
         racket/list
         racket/string
         "syntax.rkt"
         "prelude.rkt"
         "metavar-store.rkt"
         "performance-counters.rkt"
         "macros.rkt"
         "zonk.rkt"
         "unify.rkt"
         "errors.rkt"
         "source-location.rkt"
         "pretty-print.rkt")

(provide resolve-trait-constraints!
         resolve-hasmethod-constraints!
         check-unresolved-trait-constraints
         check-unresolved-capability-constraints
         ;; Track 2 Phase 7: shared error builder for resolution callbacks
         build-trait-error
         ;; Exposed for testing
         try-monomorphic-resolve
         try-parametric-resolve
         expr->impl-key-str
         ground-expr?
         match-type-pattern
         match-one
         build-parametric-dict-expr
         project-method
         trait-expr->name
         find-trait-with-method
         ;; Track 2 Phase 9a: ambiguity detection
         detect-parametric-ambiguity)

;; ========================================
;; Ground expression check
;; ========================================

;; Check whether an expression contains no unsolved metavariables.
;; Uses structural recursion on the common expression forms.
;; PM 8F Phase 6: unified ground-expr? using cell-id fast path.
;; A meta is ground when its cell has a non-bot value (= solved).
;; Follows solutions recursively (a solved meta whose solution
;; contains unsolved metas is NOT ground).
(define (ground-expr? e)
  (match e
    [(expr-meta id cell-id)
     (let ([sol (meta-solution/cell-id cell-id id)])
       (and sol (ground-expr? sol)))]
    [(expr-app f a) (and (ground-expr? f) (ground-expr? a))]
    [(expr-Pi m d c) (and (ground-expr? d) (ground-expr? c))]
    [(expr-lam m d b) (and (ground-expr? d) (ground-expr? b))]
    [(expr-Sigma d c) (and (ground-expr? d) (ground-expr? c))]
    [(expr-pair e1 e2) (and (ground-expr? e1) (ground-expr? e2))]
    ;; Built-in parameterized types: check their sub-expressions
    [(expr-PVec a) (ground-expr? a)]
    [(expr-Set a) (ground-expr? a)]
    [(expr-Map k v) (and (ground-expr? k) (ground-expr? v))]
    [_ #t]))  ;; atoms, fvar, bvar, tycon, etc. are always ground

;; ========================================
;; Core expression → impl key string
;; ========================================

;; Convert a core expression to the string format used by process-impl's
;; key generation (e.g., expr-Nat → "Nat", (app (fvar List) Nat) → "List-Nat")
(define (expr->impl-key-str e)
  (match e
    [(expr-Nat) "Nat"]
    [(expr-Bool) "Bool"]
    [(expr-Int) "Int"]
    [(expr-Rat) "Rat"]
    [(expr-Posit8) "Posit8"]
    [(expr-Posit16) "Posit16"]
    [(expr-Posit32) "Posit32"]
    [(expr-Posit64) "Posit64"]
    [(expr-Keyword) "Keyword"]
    [(expr-Char) "Char"]
    [(expr-String) "String"]
    [(expr-net-type) "PropNetwork"]
    [(expr-cell-id-type) "CellId"]
    [(expr-prop-id-type) "PropId"]
    [(expr-uf-type) "UnionFind"]
    [(expr-atms-type) "ATMS"]
    [(expr-assumption-id-type) "AssumptionId"]
    [(expr-table-store-type) "TableStore"]
    [(expr-solver-type) "Solver"]
    [(expr-goal-type) "Goal"]
    [(expr-derivation-type) "DerivationTree"]
    [(expr-schema-type name) (format "Schema:~a" name)]
    [(expr-answer-type _) "Answer"]
    [(expr-relation-type _) "Relation"]
    ;; HKT: unapplied type constructor
    [(expr-tycon name) (symbol->string name)]
    ;; Built-in parameterized types: extract constructor name
    [(expr-PVec _) "PVec"]
    [(expr-Set _) "Set"]
    [(expr-Map _ _) "Map"]
    [(expr-fvar name) (symbol->string (strip-ns name))]
    [(expr-app f a)
     (string-append (expr->impl-key-str f) "-" (expr->impl-key-str a))]
    [(expr-bvar k)
     ;; Use standard type variable names for display
     (define var-names #("A" "B" "C" "D" "E" "F" "G" "H"))
     (if (< k (vector-length var-names))
         (vector-ref var-names k)
         (format "T~a" k))]
    ;; PPN Track 4 Phase 4b: cell-id fast path (cells authoritative)
    [(expr-meta id cell-id)
     (let ([sol (meta-solution/cell-id cell-id id)])
       (if sol
           (expr->impl-key-str sol)
           (format "?~a" id)))]
    [_ (pp-expr e)]))

;; ========================================
;; Monomorphic resolution
;; ========================================

;; Try to resolve a trait constraint to a concrete (monomorphic) impl dict.
;; Returns (expr-fvar dict-name) on success, #f on failure.
(define (try-monomorphic-resolve trait-name type-args)
  (define type-arg-str
    (string-join (map expr->impl-key-str type-args) "-"))
  (define impl-key
    (string->symbol (string-append type-arg-str "--" (symbol->string trait-name))))
  (define entry (lookup-impl impl-key))
  (and entry (expr-fvar (impl-entry-dict-name entry))))

;; ========================================
;; Parametric resolution (pattern matching)
;; ========================================

;; Helper: decompose a core expression application into head + args.
(define (decompose-app-core e acc)
  (match e
    [(expr-app f a) (decompose-app-core f (cons a acc))]
    [_ (values e acc)]))

;; Strip namespace qualifier from a symbol: 'ns::name → 'name
(define (strip-ns sym)
  (define s (symbol->string sym))
  (define idx (let loop ([i (- (string-length s) 1)])
                (cond [(< i 1) #f]
                      [(and (char=? (string-ref s i) #\:)
                            (char=? (string-ref s (sub1 i)) #\:))
                       i]
                      [else (loop (sub1 i))])))
  (if idx (string->symbol (substring s (add1 idx))) sym))

;; Match a symbol against a pattern symbol, considering namespace qualifiers.
;; 'prologos::data::list::List matches pattern 'List
(define (symbol-matches? pattern name)
  (or (eq? pattern name)
      (eq? pattern (strip-ns name))))

;; Match a single core expression against a single datum pattern.
;; pvars: list of pattern variable symbols.
;; bindings: hasheq of pattern-var → core-expr.
;; Returns updated bindings on success, #f on failure.
(define (match-one core-expr pattern pvars bindings)
  (cond
    ;; Pattern variable: bind or check consistency
    [(and (symbol? pattern) (memq pattern pvars))
     (define existing (hash-ref bindings pattern #f))
     (if existing
         (and (expr-equal? existing core-expr) bindings)
         (hash-set bindings pattern core-expr))]
    ;; Concrete symbol: match builtin or fvar or tycon
    [(symbol? pattern)
     (match core-expr
       [(expr-Nat) (and (eq? pattern 'Nat) bindings)]
       [(expr-Bool) (and (eq? pattern 'Bool) bindings)]
       [(expr-Int) (and (eq? pattern 'Int) bindings)]
       [(expr-Rat) (and (eq? pattern 'Rat) bindings)]
       [(expr-Posit8) (and (eq? pattern 'Posit8) bindings)]
       [(expr-Posit16) (and (eq? pattern 'Posit16) bindings)]
       [(expr-Posit32) (and (eq? pattern 'Posit32) bindings)]
       [(expr-Posit64) (and (eq? pattern 'Posit64) bindings)]
       [(expr-Keyword) (and (eq? pattern 'Keyword) bindings)]
       [(expr-Char) (and (eq? pattern 'Char) bindings)]
       [(expr-String) (and (eq? pattern 'String) bindings)]
       ;; HKT: unapplied type constructor matches its name
       [(expr-tycon name) (and (symbol-matches? pattern name) bindings)]
       [(expr-fvar n) (and (symbol-matches? pattern n) bindings)]
       [_ #f])]
    ;; Compound pattern: (Constructor Args...)
    [(list? pattern)
     (define-values (head args) (decompose-app-core core-expr '()))
     (define phead (car pattern))
     (define pargs (cdr pattern))
     (and (= (length args) (length pargs))
          (let ([hb (match-one head phead pvars bindings)])
            (and hb
                 (let loop ([as args] [ps pargs] [bs hb])
                   (cond
                     [(null? as) bs]
                     [else
                      (define nb (match-one (car as) (car ps) pvars bs))
                      (and nb (loop (cdr as) (cdr ps) nb))])))))]
    [else #f]))

;; Structural expression equality (simple, no alpha-equivalence needed here
;; since we're comparing ground types).
(define (expr-equal? a b)
  (equal? a b))  ;; #:transparent structs → structural equality via equal?

;; Match core type-arg expressions against a param-impl-entry's type patterns.
;; Returns hasheq of (pattern-var → core-expr) on success, #f on failure.
(define (match-type-pattern type-args pentry)
  (define patterns (param-impl-entry-type-pattern pentry))
  (define pvars (param-impl-entry-pattern-vars pentry))
  (and (= (length type-args) (length patterns))
       (let loop ([cs type-args] [ps patterns] [bindings (hasheq)])
         (cond
           [(null? cs) bindings]
           [else
            (define nb (match-one (car cs) (car ps) pvars bindings))
            (and nb (loop (cdr cs) (cdr ps) nb))]))))

;; Resolve sub-constraints from a parametric impl's where clause.
;; Returns (listof dict-expr) or #f if any unresolvable.
(define (resolve-sub-constraints where-constraints bindings)
  (let loop ([remaining where-constraints] [acc '()])
    (cond
      [(null? remaining) (reverse acc)]
      [else
       (define c (car remaining))
       (define trait (car c))
       (define type-vars (cdr c))
       ;; Look up concrete type args from bindings
       (define concrete-args
         (for/list ([tv (in-list type-vars)])
           (hash-ref bindings tv #f)))
       ;; If any binding is missing, can't resolve
       (if (ormap not concrete-args)
           #f
           (let ([resolved
                  (or (try-monomorphic-resolve trait concrete-args)
                      (try-parametric-resolve trait concrete-args))])
             (if resolved
                 (loop (cdr remaining) (cons resolved acc))
                 #f)))])))

;; Build the parametric dict expression:
;; (app (app ... (app (fvar dict-fn) type-arg1) type-arg2) ... sub-dict1) ... sub-dictN)
(define (build-parametric-dict-expr pentry bindings sub-dicts)
  (define base (expr-fvar (param-impl-entry-dict-name pentry)))
  ;; Apply pattern-var bindings as type args
  (define with-types
    (for/fold ([acc base]) ([pv (in-list (param-impl-entry-pattern-vars pentry))])
      (expr-app acc (hash-ref bindings pv))))
  ;; Apply sub-constraint dicts
  (for/fold ([acc with-types]) ([sd (in-list sub-dicts)])
    (expr-app acc sd)))

;; Try to resolve a trait constraint using parametric impl entries.
;; Returns a dict expression on success, #f on failure.
;; HKT-4: Most-specific-wins resolution for parametric impls.
;; Collects ALL matching entries and picks the most specific (fewest pattern vars).
;; If multiple matches have the same specificity, picks the first (future: ambiguity error in HKT-7).
(define (try-parametric-resolve trait-name type-args)
  (define param-impls (lookup-param-impls trait-name))
  ;; Collect ALL matching entries with their bindings and sub-dicts
  (define matches
    (for/fold ([acc '()])
              ([pentry (in-list param-impls)])
      (define bindings (match-type-pattern type-args pentry))
      (if (not bindings)
          acc
          (let ([sub-dicts (resolve-sub-constraints
                             (param-impl-entry-where-constraints pentry)
                             bindings)])
            (if (not sub-dicts)
                acc
                (cons (list pentry bindings sub-dicts) acc))))))
  (cond
    [(null? matches) #f]
    [(= (length matches) 1)
     (apply build-parametric-dict-expr (car matches))]
    [else
     ;; Multiple matches: pick most specific (fewest pattern vars)
     (define sorted
       (sort matches <
         #:key (lambda (m)
                 (length (param-impl-entry-pattern-vars (car m))))))
     (define best-specificity
       (length (param-impl-entry-pattern-vars (car (car sorted)))))
     (define ties
       (filter (lambda (m)
                 (= (length (param-impl-entry-pattern-vars (car m)))
                    best-specificity))
               sorted))
     (if (= (length ties) 1)
         (apply build-parametric-dict-expr (car sorted))
         ;; Track 2 Phase 9a (HKT-7): same-specificity ambiguity — reject.
         ;; Multiple instances match with equal specificity; resolving would
         ;; be nondeterministic. Return #f so the caller reports an error.
         #f)]))

;; ========================================
;; Main resolution entry point
;; ========================================

;; Walk all trait-constraint metas and resolve those with ground type args.
;; HKT: normalize type args via normalize-for-resolution so that built-in
;; types like (expr-PVec A) are converted to (expr-app (expr-tycon 'PVec) A)
;; and type constructor fvars like (expr-fvar 'List) become (expr-tycon 'List).
(define (resolve-trait-constraints!)
  ;; Track 1 Phase 2a: read from cell (primary) with parameter fallback.
  (for ([(meta-id tc-info) (in-hash (read-trait-constraints))])
    (unless (meta-solved? meta-id)
      (perf-inc-trait-resolve!)
      (define trait-name (trait-constraint-info-trait-name tc-info))
      (define type-args (map (lambda (e) (normalize-for-resolution e))
                             (trait-constraint-info-type-arg-exprs tc-info)))
      (when (andmap ground-expr? type-args)
        (define dict-expr
          (or (try-monomorphic-resolve trait-name type-args)
              (try-parametric-resolve trait-name type-args)))
        (when dict-expr
          (solve-meta! meta-id dict-expr))))))

;; ========================================
;; Unresolved constraint checking
;; ========================================

;; Return a list of no-instance-error structs for trait constraints that
;; have ground type args but remain unsolved (i.e., no matching impl found).
;; Each error includes the source location from the meta that created it.
;; Enhanced with available instance listing, kind mismatch detection, and hints.
;; Track 2 Phase 7: Build a no-instance-error for a trait constraint.
;; Extracted as shared helper — used by both resolution callbacks (eager error writing)
;; and check-unresolved-trait-constraints (post-fixpoint sweep).
;; meta-id: the dict meta's symbol
;; trait-name: symbol (e.g., 'Add)
;; type-args: (listof expr) — already normalized and zonked
(define (build-trait-error meta-id trait-name type-args)
  (define type-args-str
    (string-join (map expr->impl-key-str type-args) " "))
  ;; Recover source location from the meta's source info
  (define minfo (meta-lookup meta-id))
  (define src (and minfo (meta-info-source minfo)))
  (define loc
    (if (and src (meta-source-info? src))
        (meta-source-info-loc src)
        srcloc-unknown))

  ;; Enhanced error: detect kind mismatch, ambiguity, and list available instances
  (define kind-mismatch (detect-kind-mismatch trait-name type-args))
  (define available (collect-available-instances trait-name))
  ;; Track 2 Phase 9a (HKT-7): detect same-specificity ambiguity for better error.
  (define ambiguity (detect-parametric-ambiguity trait-name type-args))

  (define message
    (cond
      ;; Kind mismatch — e.g., (Seqable Int) when Seqable expects Type -> Type
      [kind-mismatch
       (format "Kind mismatch in constraint (~a ~a): ~a"
               trait-name type-args-str kind-mismatch)]
      ;; HKT-7: ambiguous instances — multiple same-specificity matches
      [ambiguity
       (format "Ambiguous instances for ~a ~a: ~a"
               trait-name type-args-str ambiguity)]
      ;; No instance — list available instances and provide hint
      [else
       (define avail-str
         (if (null? available)
             ""
             (format "\n  Available instances: ~a"
                     (string-join
                      (map (lambda (i) (format "~a ~a" trait-name i))
                           available)
                      ", "))))
       (define hint
         (let ([tm (lookup-trait trait-name)])
           (if tm
               (let ([methods (trait-meta-methods tm)])
                 (format "\n  Hint: Define 'impl ~a ~a' with method~a ~a."
                         trait-name type-args-str
                         (if (> (length methods) 1) "s" "")
                         (string-join (map (lambda (m) (format "'~a'" (trait-method-name m))) methods)
                                      ", ")))
               "")))
       (format "No instance of ~a for ~a~a~a"
               trait-name type-args-str avail-str hint)]))

  (no-instance-error loc message trait-name type-args-str))

(define (check-unresolved-trait-constraints)
  ;; Track 2 Phase 7c: read pre-computed errors from resolution propagators first.
  ;; These were written by the trait resolution callback on failure — no need to
  ;; re-zonk or re-scan for constraints that already attempted resolution.
  (define cell-errors (read-error-descriptors))
  ;; Sweep remaining unsolved constraints not covered by cell errors.
  ;; Belt-and-suspenders: catches constraints whose type-args never became ground
  ;; during elaboration (the resolution callback never fires for non-ground args).
  (define sweep-errors
    (for/list ([(meta-id tc-info) (in-hash (read-trait-constraints))]
               #:when (not (meta-solved? meta-id))
               #:when (not (hash-has-key? cell-errors meta-id))
               #:when (andmap ground-expr?
                             (map (lambda (e) (normalize-for-resolution e))
                                  (trait-constraint-info-type-arg-exprs tc-info))))
      (define trait-name (trait-constraint-info-trait-name tc-info))
      (define type-args (map (lambda (e) (normalize-for-resolution e))
                             (trait-constraint-info-type-arg-exprs tc-info)))
      (build-trait-error meta-id trait-name type-args)))
  ;; Filter cell errors: only include errors for metas that are still unsolved.
  ;; Resolution may have succeeded on a later attempt (e.g., after more instances
  ;; were loaded), solving the meta. The error descriptor stays in the cell
  ;; (monotone merge) but is stale.
  (define active-cell-errors
    (for/list ([(meta-id err) (in-hash cell-errors)]
               #:when (not (meta-solved? meta-id)))
      err))
  ;; Cell errors first (they have resolution-time context), then sweep errors.
  (append active-cell-errors sweep-errors))

;; ========================================
;; Unresolved capability constraint checking (Phase 4)
;; ========================================

;; Return a list of no-instance-error structs for capability constraints that
;; remain unsolved (i.e., no matching capability found in lexical scope).
;; E2001: "Required capability ~a not available in scope."
(define (check-unresolved-capability-constraints)
  ;; Track 1 Phase 2c: read from cell (primary) with parameter fallback.
  (for/list ([(meta-id cc-info) (in-hash (read-capability-constraints))]
             #:when (not (meta-solved? meta-id)))
    (define cap-name (capability-constraint-info-cap-name cc-info))
    (define cap-type (capability-constraint-info-cap-type-expr cc-info))
    ;; Recover source location from the meta's source info
    (define minfo (meta-lookup meta-id))
    (define src (and minfo (meta-info-source minfo)))
    (define loc
      (if (and src (meta-source-info? src))
          (meta-source-info-loc src)
          srcloc-unknown))
    ;; Use the full type expression for dependent caps in the error message.
    ;; For simple caps, cap-type is just (expr-fvar 'ReadCap), so cap-name suffices.
    ;; For dependent caps like (FileCap "/data"), show the full type.
    (define display-name
      (if (and cap-type (expr-fvar? cap-type))
          cap-name  ;; simple cap — just the name
          (or (and cap-type (pp-expr cap-type)) cap-name)))
    (define message
      (format "E2001: Required capability ~a not available in scope. Add it as a function parameter: {cap :0 ~a}"
              display-name display-name))
    (no-instance-error loc message cap-name (symbol->string cap-name))))

;; ========================================
;; Phase 3a: HasMethod constraint resolution
;; ========================================

;; Extract trait name from a ground type expression.
;; After zonking, the trait variable should be a concrete type constructor or fvar.
(define (trait-expr->name expr)
  (match expr
    [(expr-tycon name) name]
    [(expr-fvar name) (strip-ns name)]
    [_ #f]))

;; Project a method from a dict expression by index within the trait.
;; Single-method traits: dict IS the function (identity projection).
;; Multi-method traits: nested pairs (sigma product), projection via fst/snd chain.
;; Method ordering follows the trait definition: method 0 is first, etc.
;; For N methods: pair structure is (pair m0 (pair m1 (pair m2 ... mN-1)))
;; Method 0 → (fst dict), Method 1 → (fst (snd dict)), ..., Method N-1 → (snd (snd ... dict))
(define (project-method dict-expr trait-meta method-idx)
  (define n-methods (length (trait-meta-methods trait-meta)))
  (cond
    [(= n-methods 1) dict-expr]  ;; single-method: dict IS the function
    [else
     ;; Multi-method: nested pairs, project by position
     (let loop ([d dict-expr] [remaining method-idx])
       (cond
         [(zero? remaining)
          (if (= method-idx (sub1 n-methods))
              d  ;; last element: already at the tail
              (expr-fst d))]
         [else (loop (expr-snd d) (sub1 remaining))]))]))

;; Walk all HasMethod constraint metas and resolve those with ground type args.
;; Resolution strategy:
;; 1. If the trait variable P is already ground → use it directly
;; 2. If P is NOT ground → search all traits for one that has the required method
;;    AND has an impl for the given type args. This discovers P from the method name.
;; After finding the trait:
;; - Resolve the dict via impl resolution (monomorphic or parametric)
;; - Project the method from the dict
;; - Solve both the evidence meta and the trait variable meta
(define (resolve-hasmethod-constraints!)
  ;; Track 1 Phase 2b: read from cell (primary) with parameter fallback.
  (for ([(meta-id hm-info) (in-hash (read-hasmethod-constraints))])
    (unless (meta-solved? meta-id)
      (define method-name (hasmethod-constraint-info-method-name hm-info))
      (define type-args
        (map (lambda (e) (normalize-for-resolution e))
             (hasmethod-constraint-info-type-arg-exprs hm-info)))
      (when (andmap ground-expr? type-args)
        ;; Strategy 1: P is already ground
        (define trait-expr (zonk (hasmethod-constraint-info-trait-var-expr hm-info)))
        (define known-trait-name (and (ground-expr? trait-expr) (trait-expr->name trait-expr)))
        ;; Strategy 2: P is not ground — search all traits for the method name
        (define resolved-trait-name
          (or known-trait-name
              (find-trait-with-method method-name type-args)))
        (when resolved-trait-name
          (define tm (lookup-trait resolved-trait-name))
          (when tm
            (define methods (trait-meta-methods tm))
            (define method-idx
              (for/or ([m (in-list methods)] [i (in-naturals)])
                (and (eq? (trait-method-name m) method-name) i)))
            (when method-idx
              ;; Resolve the dict via standard impl resolution
              (define dict-expr
                (or (try-monomorphic-resolve resolved-trait-name type-args)
                    (try-parametric-resolve resolved-trait-name type-args)))
              (when dict-expr
                ;; Solve the trait variable P if it's still a meta
                (define trait-var-expr (hasmethod-constraint-info-trait-var-expr hm-info))
                (when (and (expr-meta? trait-var-expr)
                           (not (meta-solved? (expr-meta-id trait-var-expr))))
                  (solve-meta! (expr-meta-id trait-var-expr) (expr-fvar resolved-trait-name)))
                ;; Optionally solve the dict meta if present
                (define dict-meta-id (hasmethod-constraint-info-dict-meta-id hm-info))
                (when (and dict-meta-id (not (meta-solved? dict-meta-id)))
                  (solve-meta! dict-meta-id dict-expr))
                ;; Project the method and solve the evidence meta
                (define projected (project-method dict-expr tm method-idx))
                (solve-meta! meta-id projected)))))))))

;; Search all traits for one that has a method with the given name
;; AND has an impl for the given type args. Returns the trait name or #f.
;; If multiple traits match, returns #f (ambiguity — future: error).
(define (find-trait-with-method method-name type-args)
  (define candidates
    (for/list ([(name tm) (in-hash (read-trait-registry))]
               #:when (ormap (lambda (m) (eq? (trait-method-name m) method-name))
                             (trait-meta-methods tm))
               #:when (or (try-monomorphic-resolve name type-args)
                          (try-parametric-resolve name type-args)))
      name))
  (and (= (length candidates) 1) (car candidates)))

;; Collect all registered instances for a trait, returning short display strings.
;; Checks both monomorphic registry (e.g., "Nat--Eq" → "Nat") and
;; parametric registry (e.g., param-impl for "(List A)" → "(List A)").
(define (collect-available-instances trait-name)
  (define trait-str (symbol->string trait-name))
  (define suffix (string-append "--" trait-str))
  ;; Monomorphic instances: extract type name from "TypeName--TraitName" keys
  (define mono-instances
    (for/list ([(k _v) (in-hash (read-impl-registry))]
               #:when (let ([ks (symbol->string k)])
                        (and (> (string-length ks) (string-length suffix))
                             (string-suffix? ks suffix))))
      (define ks (symbol->string k))
      (substring ks 0 (- (string-length ks) (string-length suffix)))))
  ;; Parametric instances: show the type pattern
  (define param-instances
    (for/list ([pe (in-list (lookup-param-impls trait-name))])
      (define pat (param-impl-entry-type-pattern pe))
      (if (and (list? pat) (= (length pat) 1))
          (format "~a" (car pat))
          (format "(~a)" (string-join (map (lambda (x) (format "~a" x)) pat) " ")))))
  (append mono-instances param-instances))

;; Detect kind mismatch: returns a descriptive string or #f.
;; A kind mismatch occurs when a trait expects a higher-kinded argument
;; (e.g., Type -> Type) but receives a ground type (e.g., Nat, Int).
(define (detect-kind-mismatch trait-name type-args)
  (define tm (lookup-trait trait-name))
  (and tm
       (not (null? (trait-meta-params tm)))
       (let ([expected-kind (cdr (car (trait-meta-params tm)))])
         ;; Check if trait expects a type constructor (kind includes ->)
         (and (list? expected-kind)
              (memq '-> expected-kind)
              (not (null? type-args))
              (let ([ta (car type-args)])
                ;; Ground types that are NOT type constructors
                (and (not (expr-tycon? ta))
                     (not (expr-fvar? ta))
                     (not (expr-app? ta))
                     ;; It's a concrete ground type like Nat, Int, Bool
                     (let ([ta-str (expr->impl-key-str ta)]
                           [expected-str (format "~a" expected-kind)])
                       (format "~a expects a type constructor (kind ~a), but ~a has kind Type"
                               trait-name expected-str ta-str))))))))

;; Track 2 Phase 9a (HKT-7): Detect same-specificity parametric ambiguity.
;; Returns a descriptive string or #f.
;; Ambiguity occurs when multiple parametric impls match the given type-args
;; with the same number of pattern variables (same specificity level).
(define (detect-parametric-ambiguity trait-name type-args)
  (define param-impls (lookup-param-impls trait-name))
  (define matches
    (for/fold ([acc '()])
              ([pentry (in-list param-impls)])
      (define bindings (match-type-pattern type-args pentry))
      (if (not bindings)
          acc
          (let ([sub-dicts (resolve-sub-constraints
                             (param-impl-entry-where-constraints pentry)
                             bindings)])
            (if (not sub-dicts)
                acc
                (cons pentry acc))))))
  (cond
    [(<= (length matches) 1) #f]  ;; 0 or 1 match — no ambiguity
    [else
     (define sorted
       (sort matches <
         #:key (lambda (m) (length (param-impl-entry-pattern-vars m)))))
     (define best (length (param-impl-entry-pattern-vars (car sorted))))
     (define ties (filter (lambda (m) (= (length (param-impl-entry-pattern-vars m)) best))
                          sorted))
     (if (<= (length ties) 1)
         #f  ;; unique most-specific match
         (format "~a matching instances with ~a type variable~a each: ~a"
                 (length ties) best (if (= best 1) "" "s")
                 (string-join
                  (map (lambda (pe)
                         (define pat (param-impl-entry-type-pattern pe))
                         (if (and (list? pat) (= (length pat) 1))
                             (format "~a" (car pat))
                             (format "(~a)" (string-join (map (lambda (x) (format "~a" x)) pat) " "))))
                       ties)
                  ", ")))]))

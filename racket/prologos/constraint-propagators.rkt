#lang racket/base

;;;
;;; constraint-propagators.rkt — Propagators wiring constraint cells into
;;; the propagator network.
;;;
;;; Provides:
;;; 1. Registry query: build initial constraint cell from impl registry
;;; 2. Direct refinement: narrow constraint by type tag (no prop-network)
;;; 3. P1-P4 propagator constructors: wire constraint cells into a prop-network
;;; 4. Narrowing dispatch: replace static generic-narrowing-dispatch table
;;;
;;; Designed for use in:
;;; - Phase 2c: narrowing dispatch via constraint cells (this phase)
;;; - Phase 2d: ATMS multi-candidate search
;;; - Phase 3c: constraint chain syntax
;;; - Phase 3d: incremental trait resolution
;;;

(require racket/string
         racket/set
         "constraint-cell.rkt"
         "global-env.rkt"
         "macros.rkt"
         "propagator.rkt"
         "syntax.rkt")

(provide
 ;; Registry query
 build-trait-constraint
 ;; Direct refinement (no prop-network)
 refine-constraint-by-type-tag
 type-args-match-tag?
 ;; Narrowing dispatch
 infer-narrowing-type-tag
 resolve-generic-narrowing
 ;; Multi-candidate dispatch (Phase 2d)
 candidate->func-name
 resolve-generic-narrowing-candidates
 ;; Propagator constructors
 install-type->constraint-propagator
 install-constraint->type-propagator
 install-constraint->method-propagator
 install-result->constraint-propagator)

;; ========================================
;; Registry query: build constraint from impl registry
;; ========================================

;; Build a constraint lattice value from all monomorphic impls of a trait.
;; Parametric impls are excluded from narrowing (require sub-constraint resolution).
;; Takes the impl registry as an explicit argument to avoid parameter coupling.
(define (build-trait-constraint trait-name [impl-reg (current-impl-registry)])
  (define trait-str (symbol->string trait-name))
  (define suffix (string-append "--" trait-str))
  (define candidates
    (for/list ([(k v) (in-hash impl-reg)]
               #:when (let ([ks (symbol->string k)])
                        (and (> (string-length ks) (string-length suffix))
                             (string-suffix? ks suffix))))
      (constraint-candidate trait-name
                            (impl-entry-type-args v)
                            (impl-entry-dict-name v))))
  (constraint-from-candidates candidates))

;; ========================================
;; Direct refinement (no propagator network)
;; ========================================

;; Check if an impl's type-args match a type tag symbol.
;; type-args is a list of datum symbols from impl-entry-type-args, e.g., '(Nat).
;; type-tag is a symbol like 'Nat, 'Int, etc.
(define (type-args-match-tag? type-args type-tag)
  (and (pair? type-args)
       (let ([first-arg (car type-args)])
         (and (symbol? first-arg)
              (eq? first-arg type-tag)))))

;; Refine a constraint value by keeping only candidates matching type-tag.
(define (refine-constraint-by-type-tag cv type-tag)
  (define cs (constraint-candidates cv))
  (cond
    [(not cs) cv]  ;; bot or top — no candidates to filter
    [else
     (define matching
       (for/list ([c (in-list cs)]
                  #:when (type-args-match-tag?
                          (constraint-candidate-type-args c)
                          type-tag))
         c))
     (constraint-merge cv (constraint-from-candidates matching))]))

;; ========================================
;; Narrowing type tag inference
;; ========================================

;; Check if an expression is a Nat literal (zero, suc, nat-val).
;; Minimal inline version of reduction.rkt's nat-value (avoids circular dep).
(define (nat-literal? e)
  (or (expr-zero? e)
      (expr-suc? e)
      (expr-nat-val? e)))

;; Infer a registry-compatible type tag from narrowing argument expressions.
;; Returns a symbol like 'Nat, 'Int, etc. for matching against impl-entry-type-args.
;; For narrowing, both Nat literals AND non-negative Int literals map to 'Nat
;; since narrowing operates on Nat's definitional tree.
(define (infer-narrowing-type-tag args)
  (for/or ([a (in-list args)])
    (cond
      [(nat-literal? a) 'Nat]
      [(and (expr-int? a) (exact-nonnegative-integer? (expr-int-val a))) 'Nat]
      [(and (expr-int? a) (not (exact-nonnegative-integer? (expr-int-val a)))) 'Int]
      [(expr-rat? a) 'Rat]
      [(expr-string? a) 'String]
      [else #f])))

;; ========================================
;; Narrowing dispatch via constraint cells
;; ========================================

;; Resolve a generic operator to a concrete FQN for narrowing.
;; Replaces the static generic-narrowing-dispatch table from Phase 2a.
;;
;; The impl registry stores dict names (e.g., 'Nat--Add--dict), but narrowing
;; needs the actual function with a definitional tree (e.g., 'prologos::data::nat::add).
;; For single-method traits, the dict wraps the method helper which calls the
;; real function. We resolve the dict name to a FQN by looking up in the global env.
;;
;; HOWEVER: the dict's body is a wrapper that calls the real function, not the
;; function itself. Unwrapping arbitrary dict bodies is fragile and unnecessary.
;; Instead, we use a direct mapping from the resolved impl's dict-name to the
;; actual narrowable function. The method helper name follows a predictable pattern:
;;   TypeArg--TraitName--method-name → namespace-qualified → body calls real fn
;;
;; For Phase 2c: we look up the single method name from the trait registry,
;; then search the global env for the FQN matching that method name with the
;; correct type args.
;;
;; Simpler approach: Build the constraint cell, resolve it, then extract the
;; method helper's FQN from the global env. The method helper name is:
;;   TypeArg--TraitName--method-name (where method-name comes from trait-meta).
;; This is namespace-qualified when stored in the global env.
;; Map a constraint candidate to its narrowable function name.
;; Returns symbol (FQN) or #f.
(define (candidate->func-name trait-name cand)
  (define tm (lookup-trait trait-name))
  (cond
    [(not tm) #f]
    [(null? (trait-meta-methods tm)) #f]
    [else
     ;; For single-method traits, the method helper name is
     ;; TypeArg--TraitName--methodName.
     (define method-name (trait-method-name (car (trait-meta-methods tm))))
     (define type-arg-str
       (string-join
        (map (lambda (ta)
               (if (symbol? ta) (symbol->string ta) (format "~a" ta)))
             (constraint-candidate-type-args cand))
        "-"))
     (define helper-name
       (string->symbol
        (string-append type-arg-str "--"
                       (symbol->string trait-name)
                       "--"
                       (symbol->string method-name))))
     ;; Look up the FQN in the global env
     (define fqn (find-fqn-for-local-name helper-name))
     (or fqn
         ;; Fallback: try the dict-name directly
         (find-fqn-for-local-name
          (constraint-candidate-dict-name cand)))]))

(define (resolve-generic-narrowing trait-name args [target #f])
  ;; 1. Build initial constraint from all impls
  (define cv0 (build-trait-constraint trait-name))
  (cond
    [(or (constraint-bot? cv0) (constraint-top? cv0)) #f]
    [else
     ;; 2. Infer type tag from args, fallback to target
     (define arg-tag (infer-narrowing-type-tag args))
     (define target-tag (and (not arg-tag) target
                             (infer-narrowing-type-tag (list target))))
     (define type-tag (or arg-tag target-tag))
     ;; 3. Refine constraint
     (define cv1 (if type-tag
                     (refine-constraint-by-type-tag cv0 type-tag)
                     cv0))
     ;; 4. Check resolution
     (define resolved (constraint-resolved-candidate cv1))
     (cond
       [(not resolved) #f]
       [else (candidate->func-name trait-name resolved)])]))

;; Returns (listof (cons constraint-candidate symbol)) for all remaining
;; candidates after refinement. Used by multi-candidate dispatch (Phase 2d).
(define (resolve-generic-narrowing-candidates trait-name args [target #f])
  (define cv0 (build-trait-constraint trait-name))
  (cond
    [(or (constraint-bot? cv0) (constraint-top? cv0)) '()]
    [else
     (define type-tag (or (infer-narrowing-type-tag args)
                          (and target (infer-narrowing-type-tag (list target)))))
     (define cv1 (if type-tag (refine-constraint-by-type-tag cv0 type-tag) cv0))
     (define candidates (constraint-candidates cv1))
     (if candidates
         (filter (lambda (p) p)
                 (map (lambda (c)
                        (define f (candidate->func-name trait-name c))
                        (and f (cons c f)))
                      candidates))
         '())]))

;; Find a fully-qualified name in the global env matching a local name suffix.
;; E.g., 'Nat--Add--add → 'prologos::core::arithmetic::Nat--Add--add
(define (find-fqn-for-local-name local-name)
  (define local-str (symbol->string local-name))
  (define suffix (string-append "::" local-str))
  (for/or ([(k _v) (in-hash (current-prelude-env))])
    (let ([ks (symbol->string k)])
      (and (string-suffix? ks suffix) k))))

;; ========================================
;; Propagator constructors (P1-P4)
;; ========================================
;; These create propagators for use with propagator.rkt's prop-network.
;; Infrastructure for Phase 2d (ATMS), 3c (constraint chains), 3d (incremental).

;; P1: Type → Constraint
;; When type-cell refines, eliminate non-matching candidates from constraint-cell.
;; type-tag-fn extracts a type tag symbol from the type cell value.
(define (install-type->constraint-propagator net type-cell constraint-cell type-tag-fn)
  (net-add-propagator
   net
   (list type-cell)       ;; inputs: watch the type cell
   (list constraint-cell) ;; outputs: write to constraint cell
   (lambda (n)
     (define type-val (net-cell-read n type-cell))
     (define tag (type-tag-fn type-val))
     (if tag
         (let* ([cv (net-cell-read n constraint-cell)]
                [refined (refine-constraint-by-type-tag cv tag)])
           (net-cell-write n constraint-cell refined))
         n))))

;; P2: Constraint → Type
;; When constraint narrows, compute union of remaining types and write to type cell.
;; type-from-candidate-fn converts a constraint-candidate to a type value.
(define (install-constraint->type-propagator net constraint-cell type-cell type-from-candidate-fn)
  (net-add-propagator
   net
   (list constraint-cell) ;; inputs: watch constraint cell
   (list type-cell)        ;; outputs: write to type cell
   (lambda (n)
     (define cv (net-cell-read n constraint-cell))
     (cond
       [(constraint-one? cv)
        ;; Resolved to single candidate — write concrete type
        (define ty (type-from-candidate-fn (constraint-one-candidate cv)))
        (if ty (net-cell-write n type-cell ty) n)]
       [else n]))))  ;; Multiple candidates: no type info yet

;; P3: Constraint → Method (Conditional Activation)
;; When constraint resolves to one candidate, call install-fn to set up
;; the concrete function's propagators.
;; install-fn: (net × constraint-candidate → net)
;; PAR Track 1 CALM contract: install-fn may call net-add-propagator.
;; Under BSP, the fire function emits a callback-topology-request instead
;; of calling install-fn inline. The topology stratum calls the callback
;; outside BSP fire rounds, where net-add-propagator schedules normally.
;; NOTE: Currently unused (no callers in production). The hasmethod path
;; goes through resolution.rkt → metavar-store.rkt, not through P3.
(define (install-constraint->method-propagator net constraint-cell install-fn)
  (net-add-propagator
   net
   (list constraint-cell) ;; inputs
   '()                     ;; outputs: install-fn may add its own
   (lambda (n)
     (define cv (net-cell-read n constraint-cell))
     (if (constraint-one? cv)
         ;; PAR Track 1 D.4: dual-path BSP/DFS
         (if (current-bsp-fire-round?)
             ;; BSP: emit callback request to constraint-propagators topology cell
             ;; (A1: per-subsystem topology cell, was shared decomp-request-cell-id)
             (net-cell-write n constraint-propagators-topology-cell-id
                             (set (callback-topology-request
                                   (lambda (net2) (install-fn net2 (constraint-one-candidate cv)))
                                   (list 'constraint-method constraint-cell))))
             ;; DFS: call install-fn inline (unchanged)
             (install-fn n (constraint-one-candidate cv)))
         n))))

;; P4: Result → Constraint
;; When result-cell gets a value, infer type and eliminate non-matching candidates.
;; result-type-tag-fn extracts a type tag from the result cell value.
(define (install-result->constraint-propagator net result-cell constraint-cell result-type-tag-fn)
  (net-add-propagator
   net
   (list result-cell)     ;; inputs: watch result cell
   (list constraint-cell) ;; outputs: write to constraint cell
   (lambda (n)
     (define result-val (net-cell-read n result-cell))
     (define tag (result-type-tag-fn result-val))
     (if tag
         (let* ([cv (net-cell-read n constraint-cell)]
                [refined (refine-constraint-by-type-tag cv tag)])
           (net-cell-write n constraint-cell refined))
         n))))

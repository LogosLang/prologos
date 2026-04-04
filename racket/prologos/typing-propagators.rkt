#lang racket/base

;;;
;;; typing-propagators.rkt — PPN Track 4: Elaboration as Attribute Evaluation
;;;
;;; Propagator-native type inference. Typing propagators are installed via
;;; net-add-propagator. They read type-map positions from the form cell's PU
;;; value and write computed types back. Information flows through cells —
;;; no function-call dispatch, no delegation, no imperative wrappers.
;;;
;;; Phase 1c: Context lattice — typing context as cells.
;;; Phase 2 (D.4): Propagator fire functions + install-typing-network.
;;; Phase 4b-i: Fan-in meta-readiness.
;;; Phase 6: Constraint lattice.
;;;

(require racket/match
         racket/set
         "syntax.rkt"
         "prelude.rkt"
         "substitution.rkt"
         "global-env.rkt"
         "propagator.rkt"
         "surface-rewrite.rkt"
         (only-in "subtype-predicate.rkt" type-tensor-core)
         (only-in "type-lattice.rkt" type-bot type-bot? type-top type-top?)
         (only-in "metavar-store.rkt" meta-solution/cell-id))

(provide
 ;; Phase 1c: Context lattice
 (struct-out context-cell-value)
 context-empty-value
 context-extend-value
 context-lookup-type
 context-lookup-mult
 context-cell-merge
 context-cell-contradicts?
 ;; Phase 2 (D.4): Propagator-native typing
 install-typing-network
 make-literal-fire-fn
 make-universe-fire-fn
 make-app-fire-fn
 make-bvar-fire-fn
 make-fvar-fire-fn
 make-lam-fire-fn
 make-pi-fire-fn
 ;; Phase 4b-i: Fan-in meta-readiness infrastructure
 (struct-out meta-readiness-value)
 meta-readiness-empty
 meta-readiness-register
 meta-readiness-solve
 meta-readiness-unsolved
 meta-readiness-all-solved?
 meta-readiness-merge
 meta-readiness-contradicts?
 ;; Phase 6: Constraint SRE domain
 (struct-out constraint-cell-value)
 constraint-pending
 constraint-resolved
 constraint-contradicted
 constraint-pending?
 constraint-resolved?
 constraint-contradicted?
 constraint-cell-merge
 constraint-cell-meet
 constraint-cell-contradicts?)


;; ============================================================
;; Phase 1c: Context Lattice
;; ============================================================
;;
;; The typing context IS a cell. Its PU value is a binding stack
;; (list of (type . mult) pairs using de Bruijn indices).
;;
;; Lattice structure:
;;   bot = empty context (no bindings)
;;   merge = pointwise on bindings at each position
;;   tensor (extension) = prepend new binding (creates child cell)
;;
;; This parallels Module Theory (SRE Track 7): a typing context
;; is a "local module" with positional exports.

;; A context cell's value. Wraps the binding stack with metadata
;; for lattice operations (parent tracking for scope nesting).
(struct context-cell-value
  (bindings    ;; (listof (cons type mult)): de Bruijn binding stack
   depth)      ;; Nat: nesting depth (0 = top-level)
  #:transparent)

;; Bot: empty context (top-level scope)
(define context-empty-value
  (context-cell-value '() 0))

;; Tensor: extend context with a new binding (enter a binder scope).
;; Returns a new context-cell-value (for writing to a child context cell).
;; The child is at depth+1.
(define (context-extend-value ctx-val type mult)
  (context-cell-value
   (cons (cons type mult)
         (context-cell-value-bindings ctx-val))
   (add1 (context-cell-value-depth ctx-val))))

;; Lookup type at de Bruijn position k.
;; Returns the type, or expr-error if k is out of bounds.
(define (context-lookup-type ctx-val k)
  (define bindings (context-cell-value-bindings ctx-val))
  (if (< k (length bindings))
      (car (list-ref bindings k))
      (expr-error)))

;; Lookup multiplicity at de Bruijn position k.
;; Returns the mult, or #f if k is out of bounds.
(define (context-lookup-mult ctx-val k)
  (define bindings (context-cell-value-bindings ctx-val))
  (if (< k (length bindings))
      (cdr (list-ref bindings k))
      #f))

;; Merge function for context cells.
(define (context-cell-merge old new)
  (cond
    [(null? (context-cell-value-bindings old)) new]
    [(null? (context-cell-value-bindings new)) old]
    [(= (context-cell-value-depth old) (context-cell-value-depth new))
     (context-cell-value
      (map (lambda (ob nb)
             (cons
              (if (equal? (car ob) (car nb)) (car ob) (car nb))
              (if (equal? (cdr ob) (cdr nb)) (cdr ob) (cdr nb))))
           (context-cell-value-bindings old)
           (context-cell-value-bindings new))
      (context-cell-value-depth old))]
    [(> (context-cell-value-depth new) (context-cell-value-depth old)) new]
    [else old]))

(define (context-cell-contradicts? v) #f)


;; ============================================================
;; Phase 2 (D.4 redo): Propagator-Native Typing
;; ============================================================
;;
;; Each typing propagator is a fire-fn: (prop-network → prop-network).
;; It reads type-map positions from the form cell's PU value via
;; net-cell-read, computes a type, and writes the result back to the
;; form cell via net-cell-write.
;;
;; Network Reality Check:
;;   1. net-add-propagator: YES — install-typing-network calls it per position
;;   2. net-cell-write produces result: YES — fire-fns write to type-map
;;   3. Cell trace: form cell (type-map ⊥) → propagator fires → cell write
;;      (type) → cascade → quiescence → cell read (result)
;;
;; The type-map is a hasheq inside the form cell's PU value
;; (form-pipeline-value-type-map). Positions are expr object identities.
;; Component-indexed firing (Phase 1a) selectively schedules propagators.

;; --- Helpers: read/write type-map positions on a form cell ---

;; Read a type-map position from the form cell's PU value.
;; Returns type-bot if the position doesn't exist (= ⊥).
(define (type-map-read net form-cid position)
  (define pv (net-cell-read net form-cid))
  (if (form-pipeline-value? pv)
      (hash-ref (form-pipeline-value-type-map pv) position type-bot)
      type-bot))

;; Write a type to a type-map position on the form cell.
;; Constructs an updated form-pipeline-value and writes via net-cell-write.
;; The form cell's merge function (form-pipeline-merge) handles the
;; pointwise type-map merge. Component-indexed firing ensures only
;; propagators watching this position are scheduled.
(define (type-map-write net form-cid position type-val)
  (define pv (net-cell-read net form-cid))
  (if (form-pipeline-value? pv)
      (let* ([tm (form-pipeline-value-type-map pv)]
             [new-tm (hash-set tm position type-val)]
             [new-pv (struct-copy form-pipeline-value pv [type-map new-tm])])
        (net-cell-write net form-cid new-pv))
      net))

;; --- Fire functions: one per AST node kind ---
;; Each returns a (lambda (net) ...) that reads inputs, computes, writes output.
;; The form-cid and position keys are captured in the closure.

;; Literal: write a fixed type immediately.
(define (make-literal-fire-fn form-cid position result-type)
  (lambda (net)
    (type-map-write net form-cid position result-type)))

;; Universe: Type(l) → Type(lsuc(l))
(define (make-universe-fire-fn form-cid position level)
  (lambda (net)
    (type-map-write net form-cid position (expr-Type (lsuc level)))))

;; Bound variable: read from context cell at de Bruijn position k.
(define (make-bvar-fire-fn form-cid position k ctx-val)
  (lambda (net)
    (define raw-type (context-lookup-type ctx-val k))
    (if (expr-error? raw-type)
        net  ;; out of bounds — leave at ⊥
        (type-map-write net form-cid position (shift (+ k 1) 0 raw-type)))))

;; Free variable: read from global environment.
(define (make-fvar-fire-fn form-cid position name)
  (lambda (net)
    (define ty (global-env-lookup-type name))
    (if ty
        (type-map-write net form-cid position ty)
        net)))  ;; not found — leave at ⊥

;; Application (tensor): read func-type and arg-type, write tensor result.
(define (make-app-fire-fn form-cid position func-pos arg-pos)
  (lambda (net)
    (define func-type (type-map-read net form-cid func-pos))
    (define arg-type (type-map-read net form-cid arg-pos))
    (cond
      [(or (type-bot? func-type) (type-bot? arg-type)) net]  ;; wait for inputs
      [else
       (define result (type-tensor-core func-type arg-type))
       (cond
         [(type-bot? result) net]   ;; inapplicable — no info to write
         [(type-top? result)        ;; contradiction
          (type-map-write net form-cid position type-top)]
         [else
          (type-map-write net form-cid position result)])])))

;; Lambda: read domain type (must be Type(l)) and body type, write Pi.
(define (make-lam-fire-fn form-cid position dom-pos body-pos mult)
  (lambda (net)
    (define dom-type (type-map-read net form-cid dom-pos))
    (define body-type (type-map-read net form-cid body-pos))
    (cond
      [(or (type-bot? dom-type) (type-bot? body-type)) net]  ;; wait
      [else
       ;; dom-type should be the domain TYPE ITSELF (from dom-pos),
       ;; not the type-of-domain. The lambda propagator assembles Pi
       ;; from the domain and body types.
       (define dom-expr dom-pos)  ;; the domain expression
       (type-map-write net form-cid position
                       (expr-Pi mult dom-expr body-type))])))

;; Pi formation: read domain and codomain types (both must be Type(l)).
(define (make-pi-fire-fn form-cid position dom-pos cod-pos)
  (lambda (net)
    (define dom-type (type-map-read net form-cid dom-pos))
    (define cod-type (type-map-read net form-cid cod-pos))
    (cond
      [(or (type-bot? dom-type) (type-bot? cod-type)) net]
      [(not (expr-Type? dom-type)) net]  ;; domain not a type
      [(not (expr-Type? cod-type)) net]  ;; codomain not a type
      [else
       (type-map-write net form-cid position
                       (expr-Type (lmax (expr-Type-level dom-type)
                                        (expr-Type-level cod-type))))])))

;; --- install-typing-network: the core Phase 2 deliverable ---
;;
;; Takes a prop-network, a form cell id, and a core expr (from elaborate-top-level).
;; Structurally decomposes the expr into sub-expression positions.
;; For each position:
;;   1. Writes type-bot to the type-map (initial ⊥)
;;   2. Installs a typing propagator via net-add-propagator
;;
;; Returns: (values updated-network root-position)
;;
;; The network then runs to quiescence. The result type is at root-position
;; in the type-map.
;;
;; Network Reality Check:
;;   - net-add-propagator: called once per sub-expression
;;   - net-cell-write: each fire-fn writes to type-map
;;   - Trace: type-map[pos] = ⊥ → propagator fires → writes type → cascade → read

(define (install-typing-network net form-cid expr ctx-val)
  ;; Recursive structural decomposition.
  ;; For each sub-expression, assign it as its own position key (eq? identity),
  ;; install the appropriate propagator, return updated network.
  (let install ([net net] [e expr] [ctx ctx-val])
    (match e
      ;; --- Literals: immediate type, no inputs ---
      [(expr-int v)
       (define-values (net1 _pid)
         (net-add-propagator net (list form-cid) (list form-cid)
                             (make-literal-fire-fn form-cid e (expr-Int))
                             #:component-paths (list)))
       net1]

      [(expr-nat-val _)
       (define-values (net1 _pid)
         (net-add-propagator net (list form-cid) (list form-cid)
                             (make-literal-fire-fn form-cid e (expr-Nat))))
       net1]

      [(expr-true)
       (define-values (net1 _pid)
         (net-add-propagator net (list form-cid) (list form-cid)
                             (make-literal-fire-fn form-cid e (expr-Bool))))
       net1]

      [(expr-false)
       (define-values (net1 _pid)
         (net-add-propagator net (list form-cid) (list form-cid)
                             (make-literal-fire-fn form-cid e (expr-Bool))))
       net1]

      ;; --- Type constructors: Type(lzero) ---
      [(expr-Int)
       (define-values (net1 _pid)
         (net-add-propagator net (list form-cid) (list form-cid)
                             (make-literal-fire-fn form-cid e (expr-Type (lzero)))))
       net1]

      [(expr-Nat)
       (define-values (net1 _pid)
         (net-add-propagator net (list form-cid) (list form-cid)
                             (make-literal-fire-fn form-cid e (expr-Type (lzero)))))
       net1]

      [(expr-Bool)
       (define-values (net1 _pid)
         (net-add-propagator net (list form-cid) (list form-cid)
                             (make-literal-fire-fn form-cid e (expr-Type (lzero)))))
       net1]

      [(expr-String)
       (define-values (net1 _pid)
         (net-add-propagator net (list form-cid) (list form-cid)
                             (make-literal-fire-fn form-cid e (expr-Type (lzero)))))
       net1]

      ;; --- Universe ---
      [(expr-Type l)
       (define-values (net1 _pid)
         (net-add-propagator net (list form-cid) (list form-cid)
                             (make-universe-fire-fn form-cid e l)))
       net1]

      ;; --- Bound variable ---
      [(expr-bvar k)
       (define-values (net1 _pid)
         (net-add-propagator net (list form-cid) (list form-cid)
                             (make-bvar-fire-fn form-cid e k ctx)
                             #:component-paths (list)))
       net1]

      ;; --- Free variable ---
      [(expr-fvar name)
       (define-values (net1 _pid)
         (net-add-propagator net (list form-cid) (list form-cid)
                             (make-fvar-fire-fn form-cid e name)))
       net1]

      ;; --- Application (tensor) ---
      [(expr-app func arg)
       ;; Install sub-expression propagators first
       (define net1 (install net func ctx))
       (define net2 (install net1 arg ctx))
       ;; Install app propagator watching func and arg positions
       (define-values (net3 _pid)
         (net-add-propagator net2 (list form-cid) (list form-cid)
                             (make-app-fire-fn form-cid e func arg)
                             #:component-paths
                             (list (cons form-cid func)
                                   (cons form-cid arg))))
       net3]

      ;; --- Lambda ---
      [(expr-lam m dom body)
       ;; Install domain propagator
       (define net1 (install net dom ctx))
       ;; Install body propagator with extended context
       (define child-ctx (context-extend-value ctx dom m))
       (define net2 (install net1 body child-ctx))
       ;; Install lambda propagator watching dom and body positions
       (define-values (net3 _pid)
         (net-add-propagator net2 (list form-cid) (list form-cid)
                             (make-lam-fire-fn form-cid e dom body m)
                             #:component-paths
                             (list (cons form-cid dom)
                                   (cons form-cid body))))
       net3]

      ;; --- Pi formation ---
      [(expr-Pi m dom cod)
       (define net1 (install net dom ctx))
       (define net2 (install net1 cod ctx))
       (define-values (net3 _pid)
         (net-add-propagator net2 (list form-cid) (list form-cid)
                             (make-pi-fire-fn form-cid e dom cod)
                             #:component-paths
                             (list (cons form-cid dom)
                                   (cons form-cid cod))))
       net3]

      ;; --- Fallthrough: unknown expr kind, leave at ⊥ ---
      [_ net])))


;; ============================================================
;; Phase 4b-i: Fan-In Meta-Readiness Infrastructure
;; ============================================================
;;
;; A meta-readiness cell per form tracks which metas are solved
;; via a set-based monotone value. At S2 commit time, a single
;; threshold propagator reads the unsolved set and writes defaults
;; (lzero for levels, mw for multiplicities, sess-end for sessions).
;;
;; This replaces the tree-walking `default-metas` function in
;; freeze (zonk.rkt:939-1352). Instead of walking a tree, the
;; S2 handler reads a cell.
;;
;; The merge is set-union (monotone: solved set only grows).
;; When all registered metas are in the solved set, all-solved? = #t.

(struct meta-readiness-value
  (registered  ;; hasheq: meta-id → meta-class
   solved)     ;; seteq: solved meta-ids
  #:transparent)

(define meta-readiness-empty
  (meta-readiness-value (hasheq) (seteq)))

(define (meta-readiness-register rv meta-id meta-class)
  (meta-readiness-value
   (hash-set (meta-readiness-value-registered rv) meta-id meta-class)
   (meta-readiness-value-solved rv)))

(define (meta-readiness-solve rv meta-id)
  (meta-readiness-value
   (meta-readiness-value-registered rv)
   (set-add (meta-readiness-value-solved rv) meta-id)))

(define (meta-readiness-unsolved rv)
  (define registered (meta-readiness-value-registered rv))
  (define solved (meta-readiness-value-solved rv))
  (for/list ([(id cls) (in-hash registered)]
             #:unless (set-member? solved id))
    (cons id cls)))

(define (meta-readiness-all-solved? rv)
  (= (hash-count (meta-readiness-value-registered rv))
     (set-count (meta-readiness-value-solved rv))))

(define (meta-readiness-merge old new)
  (meta-readiness-value
   (for/fold ([result (meta-readiness-value-registered old)])
             ([(id cls) (in-hash (meta-readiness-value-registered new))])
     (hash-set result id cls))
   (set-union (meta-readiness-value-solved old)
              (meta-readiness-value-solved new))))

(define (meta-readiness-contradicts? v) #f)


;; ============================================================
;; Phase 6: Constraint SRE Domain
;; ============================================================
;;
;; Trait constraints as a lattice: pending (⊥) → resolved(instance) → contradicted (⊤).

(struct constraint-cell-value
  (status    ;; 'pending | 'resolved | 'contradicted
   instance) ;; resolved instance value, or #f
  #:transparent)

(define constraint-pending (constraint-cell-value 'pending #f))
(define (constraint-resolved instance) (constraint-cell-value 'resolved instance))
(define constraint-contradicted (constraint-cell-value 'contradicted #f))

(define (constraint-pending? v)
  (and (constraint-cell-value? v) (eq? (constraint-cell-value-status v) 'pending)))
(define (constraint-resolved? v)
  (and (constraint-cell-value? v) (eq? (constraint-cell-value-status v) 'resolved)))
(define (constraint-contradicted? v)
  (and (constraint-cell-value? v) (eq? (constraint-cell-value-status v) 'contradicted)))

(define (constraint-cell-merge old new)
  (cond
    [(constraint-contradicted? old) old]
    [(constraint-contradicted? new) new]
    [(constraint-pending? old) new]
    [(constraint-pending? new) old]
    [(and (constraint-resolved? old) (constraint-resolved? new))
     (if (equal? (constraint-cell-value-instance old)
                 (constraint-cell-value-instance new))
         old
         constraint-contradicted)]
    [else constraint-contradicted]))

(define (constraint-cell-meet a b)
  (cond
    [(constraint-contradicted? a) b]
    [(constraint-contradicted? b) a]
    [(constraint-pending? a) a]
    [(constraint-pending? b) b]
    [(and (constraint-resolved? a) (constraint-resolved? b))
     (if (equal? (constraint-cell-value-instance a)
                 (constraint-cell-value-instance b))
         a
         constraint-pending)]
    [else constraint-pending]))

(define (constraint-cell-contradicts? v)
  (constraint-contradicted? v))

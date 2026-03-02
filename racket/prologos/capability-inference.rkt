#lang racket/base

;;;
;;; capability-inference.rkt — Capability Inference via Propagator Network
;;;
;;; Computes transitive capability closures for all functions in a module
;;; using the persistent propagator network (propagator.rkt / champ.rkt).
;;; Each function gets a cell in the network, seeded with its declared
;;; capabilities. Call edges become propagators: when callee g's cell
;;; changes, g's cap-set is written to caller f's cell (joined via
;;; set-union). run-to-quiescence computes the fixed point.
;;;
;;; Domain: PowerSet(CapabilityName) — finite lattice, monotone join.
;;; Termination: guaranteed by monotone cap-set-join + finite cap names.
;;;
;;; Design reference: docs/tracking/2026-03-01_1500_CAPABILITIES_AS_TYPES_DESIGN.md §4.6
;;;

(require racket/match
         racket/set
         "macros.rkt"         ;; capability-type?, subtype-pair?
         "syntax.rkt"         ;; expr structs
         "global-env.rkt"     ;; current-global-env
         "propagator.rkt")    ;; prop-network, cells, propagators, run-to-quiescence

(provide ;; CapabilitySet lattice
         cap-set
         cap-set?
         cap-set-members
         cap-set-bot
         cap-set-join
         cap-set-subsumes?
         ;; Expression analysis
         extract-fvar-names
         extract-capability-requirements
         ;; Inference
         run-capability-inference
         ;; Query API
         capability-closure
         capability-audit-trail
         ;; Result struct
         cap-inference-result
         cap-inference-result?
         cap-inference-result-closures
         cap-inference-result-call-graph)

;; ========================================
;; CapabilitySet Lattice
;; ========================================
;;
;; Domain: PowerSet(CapabilityName) where CapabilityName is a symbol.
;; Bot: empty set (pure function — no capabilities required).
;; Join: set-union (monotone — capabilities only accumulate).
;; Subsumption: every required cap is subtype of some available cap.

(struct cap-set (members) #:transparent)
;; members: (seteq of symbols)

(define cap-set-bot (cap-set (seteq)))

(define (cap-set-join a b)
  (cap-set (set-union (cap-set-members a) (cap-set-members b))))

;; Does `available` subsume `required`?
;; Every capability in `required` must be either equal to or a subtype of
;; some capability in `available`.
(define (cap-set-subsumes? available required)
  (for/and ([req (in-set (cap-set-members required))])
    (for/or ([avail (in-set (cap-set-members available))])
      (or (eq? req avail)
          (subtype-pair? req avail)))))

;; ========================================
;; Expression Analysis: Extract Free Variable Names
;; ========================================
;;
;; Generic walker over the AST using struct->vector. This avoids
;; matching on 100+ expression struct types. All expr structs are
;; #:transparent, so struct->vector returns all fields.

(define (extract-fvar-names expr)
  (define result (mutable-seteq))
  (let walk ([e expr])
    (cond
      [(expr-fvar? e)
       (set-add! result (expr-fvar-name e))]
      [(struct? e)
       (define v (struct->vector e))
       ;; v = #(struct-name field1 field2 ...)
       (for ([i (in-range 1 (vector-length v))])
         (walk (vector-ref v i)))]
      [(list? e)
       (for-each walk e)]
      [(pair? e)
       (walk (car e))
       (walk (cdr e))]
      [else (void)]))
  (for/seteq ([x (in-set result)]) x))

;; ========================================
;; Type Analysis: Extract Capability Requirements
;; ========================================
;;
;; Walk a function's type (Pi chain) to find :0 binders whose domain
;; is a capability type. Returns the set of capability names.

(define (extract-capability-requirements type)
  (let loop ([ty type] [caps (seteq)])
    (match ty
      [(expr-Pi mult dom cod)
       (define new-caps
         (if (and (eq? mult 'm0)
                  (expr-fvar? dom)
                  (capability-type? (expr-fvar-name dom)))
             (set-add caps (expr-fvar-name dom))
             caps))
       (loop cod new-caps)]
      [_ caps])))

;; ========================================
;; Call Graph Construction
;; ========================================

(define (build-call-graph env)
  ;; env: hasheq of name → (cons type body)
  ;; Returns: hasheq of name → (seteq of callee-names)
  (for/hasheq ([(name entry) (in-hash env)]
               #:when (and (pair? entry) (cdr entry)))
    (define body (cdr entry))
    (values name (extract-fvar-names body))))

;; ========================================
;; Propagator Network-Based Inference
;; ========================================
;;
;; Algorithm:
;; 1. Build call graph from global env.
;; 2. Create a propagator network cell per function, seeded with declared caps.
;; 3. For each call edge (caller → callee), add a propagator:
;;    when callee's cell changes, write callee's cap-set to caller's cell.
;;    The cell's merge function (cap-set-join) handles set-union.
;; 4. run-to-quiescence computes the transitive closure.
;; 5. Read final cell values → capability closures.
;;
;; Converges because: cap-set-join is monotone, capability name set is finite,
;; and net-cell-write's no-change guard stops propagation when join is idempotent.

(struct cap-inference-result
  (closures       ;; hasheq: function-name → (seteq of capability names)
   call-graph)    ;; hasheq: function-name → (seteq callee-names)
  #:transparent)

(define (run-capability-inference [env (current-global-env)])
  ;; Step 1: Build call graph
  (define call-graph (build-call-graph env))

  ;; Step 2: Create propagator network with a cell per function.
  ;; Each cell's initial value is the function's declared capabilities.
  ;; Merge function is cap-set-join (set-union — monotone, commutative).
  (define-values (net0 name->cid)
    (for/fold ([net (make-prop-network)]
               [mapping (hasheq)])
              ([(name _) (in-hash call-graph)])
      (define entry (hash-ref env name #f))
      (define initial-caps
        (if (and entry (pair? entry))
            (cap-set (extract-capability-requirements (car entry)))
            cap-set-bot))
      (define-values (net* cid) (net-new-cell net initial-caps cap-set-join))
      (values net* (hash-set mapping name cid))))

  ;; Step 3: Add propagators for each call edge.
  ;; For caller → callee: propagator watches callee-cell, writes to caller-cell.
  ;; When callee's caps change, caller's cell gets callee's caps joined in.
  (define net1
    (for/fold ([net net0])
              ([(caller callees) (in-hash call-graph)])
      (define caller-cid (hash-ref name->cid caller #f))
      (if (not caller-cid)
          net  ;; defensive: caller not in network (shouldn't happen)
          (for/fold ([net net])
                    ([callee (in-set callees)]
                     #:when (hash-ref name->cid callee #f))
            (define callee-cid (hash-ref name->cid callee))
            (define-values (net* _pid)
              (net-add-propagator net
                (list callee-cid)    ;; inputs: watch callee's cell
                (list caller-cid)    ;; outputs: may write to caller's cell
                (lambda (n)
                  (define callee-caps (net-cell-read n callee-cid))
                  (net-cell-write n caller-cid callee-caps))))
            net*))))

  ;; Step 4: Run to quiescence (fixed point)
  (define net-final (run-to-quiescence net1))

  ;; Step 5: Extract closures from final cell values
  (define closures
    (for/hasheq ([(name cid) (in-hash name->cid)])
      (define caps (net-cell-read net-final cid))
      (values name (cap-set-members caps))))

  (cap-inference-result closures call-graph))

;; ========================================
;; Query API
;; ========================================

;; Get the capability closure for a function.
(define (capability-closure result func-name)
  (hash-ref (cap-inference-result-closures result) func-name (seteq)))

;; Trace why a function requires a specific capability.
;; Returns a list of (caller callee) pairs forming the call chain.
;; Uses BFS to find the shortest path to a function that directly declares it.
(define (capability-audit-trail result func-name cap-name)
  (define closures (cap-inference-result-closures result))
  (define call-graph (cap-inference-result-call-graph result))

  ;; Check if func even requires this cap
  (define closure (capability-closure result func-name))
  (cond
    [(not (set-member? closure cap-name)) '()]
    [else
     ;; Is this function a direct declarer?
     (define (direct-declarer? name)
       (define entry (hash-ref (current-global-env) name #f))
       (and entry (pair? entry)
            (set-member? (extract-capability-requirements (car entry)) cap-name)))

     ;; BFS with parent tracking
     (define visited (mutable-seteq))
     (define parent (make-hasheq))
     (set-add! visited func-name)

     (let bfs ([q (list func-name)])
       (cond
         [(null? q) '()]
         [else
          (define current (car q))
          (define rest (cdr q))
          (cond
            [(and (not (eq? current func-name))
                  (direct-declarer? current))
             ;; Reconstruct path
             (let reconstruct ([name current] [path '()])
               (define pred (hash-ref parent name #f))
               (if pred
                   (reconstruct pred (cons (list pred name) path))
                   path))]
            [else
             ;; Expand: callees that have this cap in their closure
             (define callees (hash-ref call-graph current (seteq)))
             (define new-q
               (for/fold ([acc rest])
                         ([callee (in-set callees)]
                          #:when (not (set-member? visited callee))
                          #:when (set-member?
                                   (hash-ref closures callee (seteq))
                                   cap-name))
                 (set-add! visited callee)
                 (hash-set! parent callee current)
                 (append acc (list callee))))
             (bfs new-q)])]))]))

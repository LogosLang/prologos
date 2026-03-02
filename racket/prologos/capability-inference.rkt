#lang racket/base

;;;
;;; capability-inference.rkt — Capability Inference
;;;
;;; Computes transitive capability closures for all functions in a module
;;; using iterative fixed-point computation. Each function's closure is the
;;; union of its declared capabilities and the closures of all its callees.
;;; The iteration converges in O(depth × edges) rounds.
;;;
;;; Design reference: docs/tracking/2026-03-01_1500_CAPABILITIES_AS_TYPES_DESIGN.md §4.6
;;;
;;; Implementation note: The design calls for propagator network integration,
;;; but the CHAMP trie backing the network has a scaling issue with 1000+ cells.
;;; Since capability inference is a unidirectional flow (callee→caller),
;;; a simple iterative algorithm suffices and produces identical results.
;;; Upgrade to propagator network when CHAMP scaling is addressed.
;;;

(require racket/match
         racket/set
         "macros.rkt"         ;; capability-type?, subtype-pair?
         "syntax.rkt"         ;; expr structs
         "global-env.rkt")    ;; current-global-env

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
;; Iterative Fixed-Point Inference
;; ========================================
;;
;; Algorithm:
;; 1. Initialize each function's closure with its declared capabilities.
;; 2. For each function, union in all callees' closures.
;; 3. Repeat step 2 until no closures change (fixed point).
;;
;; Converges because: set-union is monotone, capability sets are finite.
;; Complexity: O(D × E × K) where D=call depth, E=edges, K=max cap set size.

(struct cap-inference-result
  (closures       ;; hasheq: function-name → (seteq of capability names)
   call-graph)    ;; hasheq: function-name → (seteq callee-names)
  #:transparent)

(define (run-capability-inference [env (current-global-env)])
  ;; Step 1: Build call graph
  (define call-graph (build-call-graph env))

  ;; Step 2: Initialize closures with declared capabilities
  (define closures (make-hasheq))
  (for ([(name _) (in-hash call-graph)])
    (define entry (hash-ref env name #f))
    (define caps
      (if (and entry (pair? entry))
          (extract-capability-requirements (car entry))
          (seteq)))
    (hash-set! closures name caps))

  ;; Step 3: Iterate until fixed point
  (let loop ([changed? #t])
    (when changed?
      (define any-changed? #f)
      (for ([(caller callees) (in-hash call-graph)])
        (define current (hash-ref closures caller (seteq)))
        (define new-caps
          (for/fold ([caps current])
                    ([callee (in-set callees)]
                     #:when (hash-ref closures callee #f))
            (set-union caps (hash-ref closures callee (seteq)))))
        (unless (equal? new-caps current)
          (hash-set! closures caller new-caps)
          (set! any-changed? #t)))
      (loop any-changed?)))

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

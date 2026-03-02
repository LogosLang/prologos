#lang racket/base

;;;
;;; capability-inference.rkt — Capability Inference via Propagator Network + ATMS Provenance
;;;
;;; Computes transitive capability closures for all functions in a module
;;; using the persistent propagator network (propagator.rkt / champ.rkt).
;;; Each function gets a cell in the network, seeded with its declared
;;; capabilities. Call edges become propagators: when callee g's cell
;;; changes, g's cap-set is written to caller f's cell (joined via
;;; set-union). run-to-quiescence computes the fixed point.
;;;
;;; After convergence, ATMS provenance (atms.rkt) records WHY each
;;; capability ended up in each function's closure. One ATMS assumption
;;; per (function, capability) direct declaration; support sets propagate
;;; through the call graph. This enables "why does f require ReadCap?"
;;; queries with full derivation trees.
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
         "propagator.rkt"     ;; prop-network, cells, propagators, run-to-quiescence
         "atms.rkt")          ;; ATMS for provenance tracking

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
         capability-audit-roots
         ;; Result struct
         cap-inference-result
         cap-inference-result?
         cap-inference-result-closures
         cap-inference-result-call-graph
         cap-inference-result-provenance-atms
         cap-inference-result-provenance-roots
         atms-cell-key)

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
;; 6. Build ATMS provenance from converged closures + call graph.
;;
;; Converges because: cap-set-join is monotone, capability name set is finite,
;; and net-cell-write's no-change guard stops propagation when join is idempotent.

(struct cap-inference-result
  (closures              ;; hasheq: function-name → (seteq of capability names)
   call-graph            ;; hasheq: function-name → (seteq callee-names)
   provenance-atms       ;; atms: ATMS with provenance assumptions and supported values
   provenance-roots)     ;; hasheq: (cons func cap) → (seteq declaring-func-names)
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

  ;; Step 6: Build ATMS provenance
  (define-values (prov-atms prov-roots)
    (build-capability-provenance closures call-graph env))

  (cap-inference-result closures call-graph prov-atms prov-roots))

;; ========================================
;; ATMS Provenance Construction
;; ========================================
;;
;; After the propagator network computes capability closures, we build
;; ATMS provenance to track WHY each capability ended up in each closure.
;;
;; Algorithm:
;; 1. Identify direct declarations: functions whose type spec includes
;;    :0 capability binders. Each (function, cap) pair → ATMS assumption.
;;
;; 2. Build reverse call graph: callee → set of callers.
;;
;; 3. For each direct declarer h with cap c, reverse-BFS through callers:
;;    every function that transitively calls h AND has c in its closure
;;    gets h added to its provenance-roots for c.
;;
;; 4. Populate ATMS cells: for each (func, cap) pair, write supported
;;    values with support sets pointing to the root assumptions.
;;    Each root gets a SEPARATE supported value, enabling future
;;    retraction analysis ("what if h no longer requires ReadCap?").
;;
;; This gives us:
;;   - All declaring roots (not just shortest-path BFS first hit)
;;   - ATMS support sets for principled truth maintenance
;;   - Foundation for future what-if / retraction queries

;; Helper: extract unqualified name from a potentially namespace-qualified symbol.
;; E.g., 'test-ns::foo → 'foo, 'foo → 'foo
(define (unqualify-name name)
  (define s (symbol->string name))
  (define m (regexp-match #rx"::([^:]+)$" s))
  (if m
      (string->symbol (cadr m))
      name))

;; Helper: create an interned symbol key for ATMS cells from (func-name, cap-name).
;; The ATMS tms-cells hash uses hasheq (eq?-based), so we need symbols (interned)
;; rather than cons pairs (which create fresh allocations every time).
(define (atms-cell-key func-name cap-name)
  (string->symbol (format "~a:~a" func-name cap-name)))

(define (build-capability-provenance closures call-graph env)
  ;; Step 1: Find all direct declarations: (func-name . cap-name) pairs
  ;; NOTE: Uses equal?-based hash because keys are cons pairs (not eq?-comparable).
  (define direct-decls  ;; hash: (cons func cap) → #t
    (for*/hash ([(name caps) (in-hash closures)]
                [c (in-set caps)]
                [entry (in-value (hash-ref env name #f))]
                [declared (in-value
                           (if (and entry (pair? entry))
                               (extract-capability-requirements (car entry))
                               (seteq)))]
                #:when (set-member? declared c))
      (values (cons name c) #t)))

  ;; Step 2: Build reverse call graph (callee → set of callers)
  (define rev-graph
    (for*/fold ([rev (hasheq)])
               ([(caller callees) (in-hash call-graph)]
                [callee (in-set callees)])
      (hash-update rev callee
                   (lambda (s) (set-add s caller))
                   (seteq))))

  ;; Step 3: Create ATMS with one assumption per direct declaration
  ;; The assumptions map uses equal?-based hash (cons-pair keys).
  ;; ATMS cell keys use interned symbols via atms-cell-key (ATMS uses hasheq internally).
  (define-values (a0 assumptions)  ;; hash: (cons func cap) → assumption-id
    (for/fold ([a (atms-empty)] [mapping (hash)])
              ([(key _) (in-hash direct-decls)])
      (define func-name (car key))
      (define cap-name (cdr key))
      (define-values (a* aid)
        (atms-assume a
                     (string->symbol (format "~a:~a" func-name cap-name))
                     key))
      ;; Also seed the ATMS cell for this direct declaration
      (define cell-k (atms-cell-key func-name cap-name))
      (define a** (atms-write-cell a* cell-k #t (hasheq aid #t)))
      (values a** (hash-set mapping key aid))))

  ;; Step 4: For each direct declarer (h, c), reverse-BFS to find all
  ;; functions that transitively call h and have c in their closure.
  ;; Build provenance-roots: (cons func cap) → (seteq declaring-func-names)
  (define provenance-roots  ;; mutable hasheq for accumulation
    (make-hash))

  ;; Helper: add a root to a (func, cap) provenance entry
  (define (add-root! func-name cap-name root-name)
    (define key (cons func-name cap-name))
    (define current (hash-ref provenance-roots key (seteq)))
    (hash-set! provenance-roots key (set-add current root-name)))

  ;; For each direct declaration, BFS through reverse call graph
  (for ([(decl-key _) (in-hash direct-decls)])
    (define h (car decl-key))      ;; declaring function
    (define c (cdr decl-key))      ;; capability name

    ;; h is a root for itself
    (add-root! h c h)

    ;; Reverse-BFS: find all callers (transitively) that have c in closure
    (define visited (mutable-seteq))
    (set-add! visited h)

    (let bfs ([q (set->list (hash-ref rev-graph h (seteq)))])
      (unless (null? q)
        (define current (car q))
        (define rest (cdr q))
        (cond
          [(set-member? visited current)
           (bfs rest)]
          [else
           (set-add! visited current)
           ;; Only add root if this function actually has c in its closure
           (define func-closure (hash-ref closures current (seteq)))
           (cond
             [(set-member? func-closure c)
              (add-root! current c h)
              ;; Continue BFS to callers of current
              (define callers (hash-ref rev-graph current (seteq)))
              (bfs (append rest
                           (for/list ([caller (in-set callers)]
                                      #:when (not (set-member? visited caller)))
                             caller)))]
             [else
              ;; This function doesn't have c — don't propagate further
              (bfs rest)])]))))

  ;; Step 5: Normalize provenance-roots: expand root sets to include both
  ;; qualified and unqualified name forms. The call graph uses qualified names
  ;; (e.g., test-ns::foo) but queries typically use unqualified names (foo).
  ;; Normalization ensures both forms are present for consistent lookup.
  (for ([(key roots) (in-hash provenance-roots)])
    (define expanded
      (for/fold ([expanded roots])
                ([r (in-set roots)])
        (define short (unqualify-name r))
        (if (eq? short r)
            expanded
            (set-add expanded short))))
    (unless (equal? expanded roots)
      (hash-set! provenance-roots key expanded)))

  ;; Step 6: Convert provenance-roots to immutable hash (equal?-based for cons keys)
  (define prov-roots-imm
    (for/hash ([(key roots) (in-hash provenance-roots)])
      (values key roots)))

  ;; Step 7: Populate ATMS cells with supported values
  ;; For each (func, cap) with provenance roots, write one supported-value
  ;; per root (enabling independent retraction of each root's declaration).
  ;; Uses atms-cell-key (interned symbols) for ATMS cell keys.
  (define a-final
    (for/fold ([a a0])
              ([(key roots) (in-hash prov-roots-imm)])
      (define func-name (car key))
      (define cap-name (cdr key))
      (define cell-k (atms-cell-key func-name cap-name))
      (for/fold ([a a])
                ([root (in-set roots)])
        (define root-key (cons root cap-name))
        (define aid (hash-ref assumptions root-key #f))
        (if aid
            (atms-write-cell a cell-k #t (hasheq aid #t))
            a))))  ;; root may be unqualified form — assumption might only have qualified

  (values a-final prov-roots-imm))

;; ========================================
;; Query API
;; ========================================

;; Get the capability closure for a function.
(define (capability-closure result func-name)
  (hash-ref (cap-inference-result-closures result) func-name (seteq)))

;; Get the set of functions that directly declared a capability,
;; causing it to appear in func-name's closure.
;; Returns (seteq of function-name symbols), or empty set if not found.
(define (capability-audit-roots result func-name cap-name)
  (define key (cons func-name cap-name))
  (hash-ref (cap-inference-result-provenance-roots result) key (seteq)))

;; Trace why a function requires a specific capability.
;; Returns a list of (caller callee) pairs forming a call chain from
;; func-name to a direct declarer of cap-name.
;;
;; Uses ATMS provenance roots to identify the declaring function(s),
;; then BFS through the call graph to find the shortest path to the
;; nearest root. Compared to the pre-ATMS BFS approach, this is both
;; more correct (uses ground-truth provenance) and more informative
;; (all roots are known, not just the first BFS hit).
(define (capability-audit-trail result func-name cap-name)
  (define closures (cap-inference-result-closures result))
  (define call-graph (cap-inference-result-call-graph result))

  ;; Check if func even requires this cap
  (define closure (capability-closure result func-name))
  (cond
    [(not (set-member? closure cap-name)) '()]
    [else
     ;; Use provenance roots to identify direct declarers
     (define roots (capability-audit-roots result func-name cap-name))

     (cond
       ;; Function itself is a root (direct declarer)
       [(set-member? roots func-name) '()]

       ;; No roots found (shouldn't happen if closure is correct)
       [(set-empty? roots) '()]

       [else
        ;; BFS from func-name through the call graph to find shortest
        ;; path to ANY root. Constrained to functions with cap in closure.
        (define visited (mutable-seteq))
        (define parent (make-hasheq))
        (set-add! visited func-name)

        (let bfs ([q (list func-name)])
          (cond
            [(null? q) '()]
            [else
             (define current (car q))
             (define rest-q (cdr q))
             (cond
               ;; Found a root (but not the start — that's handled above)
               [(and (not (eq? current func-name))
                     (set-member? roots current))
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
                  (for/fold ([acc rest-q])
                            ([callee (in-set callees)]
                             #:when (not (set-member? visited callee))
                             #:when (set-member?
                                      (hash-ref closures callee (seteq))
                                      cap-name))
                    (set-add! visited callee)
                    (hash-set! parent callee current)
                    (append acc (list callee))))
                (bfs new-q)])]))])]))

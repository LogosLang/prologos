#lang racket/base
;;; extraction.rkt — PReduce Track 4 Phase 1: cost-guided extraction as a
;;; propagator fixpoint (the design's §2 centerpiece; ledger iter 29).
;;;
;;; Q-valued extraction-cost cells (min-lattice under q-better? — monotone
;;; descent toward the optimum is monotone ascent in the min-lattice; CALM) +
;;; REFIREABLE cost-recompute propagators per e-node descriptor (the precision
;;; contract: cascades must re-fire) + a PURE top-down argmin read at
;;; quiescence. LAZY: cells + propagators allocate at the extraction REQUEST
;;; over the reachable subgraph (the burst rides the quiescence call already
;;; being made — design §6 Q1).
;;;
;;; The Q interface (derived from owner D7 — design §1): v1 = tropical (min,+);
;;; multi-dimensional cost = a later q-instance, no schema change.
(require racket/set
         racket/list
         "tropical-fuel-primitives.rkt"  ;; Phase 3 (iter 31): the left-residual's
                                          ;; FIRST production consumer (leaf module
                                          ;; — no cycle; PPN 4C 1B inheritance)
         "eclass-graph.rkt"
         "eclass-cell.rkt"
         "propagator.rkt"
         "sre-core.rkt"
         "merge-fn-registry.rkt")

(provide (struct-out q-instance)
         tropical-q
         tropical-cost-merge
         extract
         extract/budgeted)

(struct q-instance (combine better? identity top criterion-id) #:transparent)
(define tropical-q (q-instance + < 0 +inf.0 'tropical-v1))

;; cost-cell value: (cons cost winning-descriptor-or-#f); #f = the class's own
;; literal alt (its ':best form). Merge keeps the BETTER cost (tie → old, for
;; determinism). v1 registers the TROPICAL instance concretely (the Q-generic
;; merge is a closure; SRE registration wants a fixed fn — same posture as the
;; eclass merges).
(define (tropical-cost-merge old new)
  (if (< (car new) (car old)) new old))

(define extraction-cost-sre-domain
  (make-sre-domain
   #:name 'extraction-cost
   #:merge-registry (lambda (r)
                      (case r
                        [(equality) tropical-cost-merge]
                        [else (error 'extraction-cost-merge
                                     "no merge for relation ~a on 'extraction-cost" r)]))
   #:contradicts? (lambda (v) #f)
   #:bot? (lambda (v) (and (pair? v) (= (car v) +inf.0)))
   #:bot-value (cons +inf.0 #f)))
(register-domain! extraction-cost-sre-domain)
(register-merge-fn!/lattice tropical-cost-merge #:for-domain 'extraction-cost)

;; --- the reachable subgraph (descriptor scan; v1 projection note in
;;     eclass-graph.rkt's parent-index header) ---

(define (all-descriptors net pidx-cid)
  (define idx (net-cell-read net pidx-cid))
  (if (hash? idx)
      (for/fold ([acc (set)]) ([(_k descs) (in-hash idx)])
        (set-union acc descs))
      (set)))

;; CANONICALIZATION (the e-graph fundamental, gate-caught at the diamond:
;; descriptors carry pre-union member cell-ids; union means SAME CLASS — every
;; identity in extraction goes through ':canonical, the min-alloc class NAME).
;; reachable: canonical → representative member cid, walked DOWN through
;; canonicalized descriptor edges.
(define (reachable-canon net root-cid descriptors)
  (define (canon cid) (eclass-canonical net cid))
  (let loop ([frontier (list root-cid)] [seen (hash)])
    (cond
      [(null? frontier) seen]
      [else
       (define cid (car frontier))
       (define k (canon cid))
       (cond
         [(hash-ref seen k #f) (loop (cdr frontier) seen)]
         [else
          (define children
            (for*/list ([d (in-set descriptors)]
                        #:when (equal? (canon (caddr d)) k)
                        [c (in-list (cadr d))])
              c))
          (loop (append children (cdr frontier)) (hash-set seen k cid))])])))

;; --- the extraction request: lazy fixpoint + pure read ---
;; → (values net' cost form-tree)  — form-tree rebuilds through winning
;; descriptors; #f-descriptor leaves serve the class's own ':best form.
(define (extract net hashcons-cid pidx-cid root-cid #:q [q tropical-q])
  (define descriptors (all-descriptors net pidx-cid))
  (define canon->rep (reachable-canon net root-cid descriptors))
  (define (canon cid) (eclass-canonical net cid))
  ;; 1. lazy cost cells, seeded with each class's LOCAL best (its literal alt)
  (define (literal-best n cid)
    ;; a class's ':best seeds the fixpoint ONLY if it is a LITERAL alt — a
    ;; node-born best (#(enode op ...) vector) carries the NODE-LOCAL cost,
    ;; which is not a valid total (gate-caught at first diamond run, iter 29:
    ;; the local 2 beat the compositional 3 and served a non-form)
    (define best (hash-ref (eclass-read n cid) ':best #f))
    (and best
         (not (and (vector? (cdr best))
                   (> (vector-length (cdr best)) 0)
                   (eq? (vector-ref (cdr best) 0) 'enode)))
         best))
  ;; ONE cost cell per CANONICAL (union members share the joined class value,
  ;; so the representative's literal-best speaks for the whole class)
  (define-values (net1 cost-cells)
    (for/fold ([n net] [cells (hash)]) ([(k rep) (in-hash canon->rep)])
      (define lb (literal-best n rep))
      (define seed (if lb (cons (car lb) #f) (cons (q-instance-top q) #f)))
      (define-values (n1 cc) (net-new-cell n (cons (q-instance-top q) #f)
                                           tropical-cost-merge))
      (values (net-cell-write n1 cc seed) (hash-set cells k cc))))
  ;; 2. REFIREABLE cost-recompute propagators per reachable descriptor
  (define net2
    (for/fold ([n net1]) ([d (in-set descriptors)]
                          #:when (hash-ref canon->rep (canon (caddr d)) #f))
      (define ccs (for/list ([c (in-list (cadr d))])
                    (hash-ref cost-cells (canon c))))
      (define parent-cc (hash-ref cost-cells (canon (caddr d))))
      (define node-cost (if (and (list? d) (= (length d) 4)) (cadddr d) 1))
      (define (fire fnet)
        (define child-costs (for/list ([cc (in-list ccs)])
                              (car (net-cell-read fnet cc))))
        (if (for/or ([c (in-list child-costs)]) (= c (q-instance-top q)))
            fnet  ;; a child is still unreachable — wait (refire on its drop)
            (net-cell-write fnet parent-cc
                            (cons (for/fold ([acc node-cost]) ([c (in-list child-costs)])
                                    ((q-instance-combine q) acc c))
                                  d))))
      (define-values (n1 _pid) (net-add-propagator n ccs (list parent-cc) fire))
      n1))
  ;; 3. quiescence = the fixpoint
  (define net3 (run-to-quiescence net2))
  ;; 4. the pure top-down read
  (define (form-of cid)
    (define k (canon cid))
    (define cc (hash-ref cost-cells k))
    (define entry (net-cell-read net3 cc))
    (define d (cdr entry))
    (cond
      [(not d)  ;; the class's own LITERAL alt (the seed's source)
       (define lb (literal-best net3 (hash-ref canon->rep k)))
       (and lb (cdr lb))]
      [else (cons (car d) (for/list ([c (in-list (cadr d))]) (form-of c)))]))
  (define root-entry (net-cell-read net3 (hash-ref cost-cells (canon root-cid))))
  (values net3 (car root-entry) (form-of root-cid)))

;; --- Phase 3 (iter 31): budget-bounded extraction — residuation's first
;;     production consumer ---
;; The left-residual (tropical-left-residual a b = b ⊖ a, truncated at 0) is
;; the quantale's answer to "what budget remains after paying a out of b";
;; infeasibility is the COMPARISON (cost > budget), not a sign (the algebra
;; floors). Over CONVERGED exact costs the root feasibility check decides the
;; whole tree (every sub-allocation fits by construction when the optimum
;; fits); the per-level residual threading is the read-time pruning instrument
;; that earns its keep under PARTIAL costs / multi-criteria Q instances — the
;; named growth path, not built speculatively.
;; → (values net' cost form residual)  |  (values net' #f #f #f) when the
;; optimum exceeds the budget (NOT an error — an infeasible question).
(define (extract/budgeted net hashcons-cid pidx-cid root-cid
                          #:budget budget #:q [q tropical-q])
  (define-values (net1 cost form) (extract net hashcons-cid pidx-cid root-cid #:q q))
  (if (> cost budget)
      (values net1 #f #f #f)
      (values net1 cost form (tropical-left-residual cost budget))))

#lang racket/base
;;; eclass-graph.rkt — PReduce Track 1 GREEN SLICE (D.1 §2.4 / §3.2; ledger iter 9).
;;;
;;; The hashcons registry + intern + union-emitter over e-class cells:
;;;
;;;   - REGISTRY: an on-network cell mapping PCE ground digest → (alloc . cell-id),
;;;     equal?-keyed (digests are bytes), hash-union merge with per-key MIN-BY-ALLOC
;;;     (racing interns of the same term resolve deterministically to the
;;;     first-allocated cell — ACI, CALM-safe; the loser cell is unreachable
;;;     garbage, not an error).
;;;   - INTERN: content-address the term via pce.rkt (the single hasher — D.3 §2),
;;;     reuse the registered class or allocate a fresh product cell. The
;;;     ':canonical component = the cell-id's allocation number (network cell-ids
;;;     are allocated monotonically — the min-join over them IS first-allocation
;;;     order; no separate counter, no off-network state).
;;;   - UNION: e-graph union = installing an 'eclass-refine relate propagator
;;;     between two class cells (SM2 D2: relations are propagator KINDS). The
;;;     coarsening join happens at BSP quiescence — racing unions converge to one
;;;     fixpoint by CALM, exercised by the racing test.
;;;
;;; Three keys, never conflated (D.1 §2.1 three-key separation): canonical NAME
;;; (min alloc) ≠ cost-best FORM (':best argmin) ≠ content-address KEY (PCE digest).
(require racket/set
         "pce.rkt"
         "eclass-cell.rkt"
         "sre-core.rkt"
         "propagator.rkt")

(provide make-eclass-graph
         eclass-registry-merge
         eclass-intern
         eclass-union
         eclass-lookup
         eclass-read
         ;; congruence engine (PReduce Track 1, iter 11a — D.1 §2.1)
         eclass-canonical
         eclass-node-signature
         eclass-intern-node
         eclass-congruence-collisions
         eclass-union-all)

;; --- the hashcons registry cell ---

;; per-key min-by-alloc hash-union: deterministic winner for racing interns
(define (eclass-registry-merge old new)
  (cond
    [(not (hash? old)) new]
    [(not (hash? new)) old]
    [else
     (for/fold ([acc old]) ([(k v) (in-hash new)])
       (define e (hash-ref acc k #f))
       (cond
         [(not e) (hash-set acc k v)]
         [(<= (car e) (car v)) acc]
         [else (hash-set acc k v)]))]))

;; → (values net' registry-cid)
(define (make-eclass-graph net)
  (net-new-cell net (hash) eclass-registry-merge))

;; --- intern ---

;; → (values net' class-cid digest)
(define (eclass-intern net reg-cid term
                       #:cost [cost 1]
                       #:regime [regime 'ground]
                       #:provenance [provenance (seteq 'intern)])
  (define digest (pce-persistable-digest PCE-KIND-GROUND-TERM term))
  (define reg (net-cell-read net reg-cid))
  (define existing (and (hash? reg) (hash-ref reg digest #f)))
  (cond
    [existing (values net (cdr existing) digest)]
    [else
     (define-values (net1 cid) (net-new-cell net eclass-bot eclass-merge))
     (define alloc (cell-id-n cid))
     (define v0 (make-eclass-value #:best (cons cost term)
                                   #:alts (set digest)
                                   #:canonical alloc
                                   #:provenance provenance
                                   #:regime regime))
     (define net2 (net-cell-write net1 cid v0))
     (define net3 (net-cell-write net2 reg-cid (hash digest (cons alloc cid))))
     (values net3 cid digest)]))

;; --- union-emitter ---

;; e-graph union = an 'eclass-refine relate install; the join lands at quiescence.
;; → net' (propagator installed; caller drives run-to-quiescence)
(define (eclass-union net cid-a cid-b)
  (define fire (sre-make-structural-relate-propagator term-carrier-sre-domain
                                                      cid-a cid-b
                                                      #:relation sre-eclass-refine))
  (define-values (net1 _pid)
    (net-add-propagator net (list cid-a cid-b) (list cid-a cid-b) fire))
  net1)

;; --- reads ---

(define (eclass-lookup net reg-cid digest)
  (define reg (net-cell-read net reg-cid))
  (define e (and (hash? reg) (hash-ref reg digest #f)))
  (and e (cdr e)))

(define (eclass-read net cid)
  (net-cell-read net cid))

;; ========================================================================
;; Congruence engine (PReduce Track 1, iter 11a — D.1 §2.1)
;;
;; E-NODES are decomposed applications: (op, child-class...). A node's
;; SIGNATURE is the PCE digest of (vector 'enode op canonical(child)...) —
;; canonicals are the min-alloc NAMES, PCE-encodable integers.
;;
;; SOUND-IF-STALE (the load-bearing argument, ledger iter 11): classes only
;; COARSEN (unions never split), so two nodes whose signatures were equal at
;; ANY point are congruent FOREVER — stale signature-index entries can never
;; cause a wrong union. An intern keyed by a STALE canonical merely allocates
;; a duplicate class for the same node; the congruence scan detects the
;; signature collision and unions the duplicate away. Wasteful-but-sound is
;; the CALM-compatible failure mode; precision returns at quiescence.
;;
;; 11a = the ENGINE (signatures, decomposed intern, collision scan, batch
;; union) — pure + cell-level, fully testable. 11b = the reactive wiring
;; (parent watchers + topology-tier collision handler).
;; ========================================================================

;; the canonical NAME of a class (min-alloc component of the product)
(define (eclass-canonical net cid)
  (define v (net-cell-read net cid))
  (and (hash? v) (hash-ref v ':canonical #f)))

;; signature = content address of (op, canonical children...)
(define (eclass-node-signature net op child-cids)
  (define canon (for/list ([c (in-list child-cids)]) (eclass-canonical net c)))
  (pce-persistable-digest PCE-KIND-GROUND-TERM
                          (list->vector (cons 'enode (cons op canon)))))

;; Decomposed intern: a node keyed by its CURRENT signature. Returns the node
;; DESCRIPTOR (list op child-cids class-cid) alongside — 11b's watchers and the
;; collision scan consume descriptors.
;; → (values net' class-cid descriptor)
(define (eclass-intern-node net reg-cid op child-cids
                            #:cost [cost 1]
                            #:regime [regime 'ground])
  (define sig (eclass-node-signature net op child-cids))
  (define reg (net-cell-read net reg-cid))
  (define existing (and (hash? reg) (hash-ref reg sig #f)))
  (cond
    [existing (values net (cdr existing) (list op child-cids (cdr existing)))]
    [else
     (define-values (net1 cid) (net-new-cell net eclass-bot eclass-merge))
     (define alloc (cell-id-n cid))
     ;; the node's FORM for cost purposes: the signature vector itself at v1
     ;; (real terms attach when reduction rules intern concrete exprs)
     (define form (list->vector (cons 'enode (cons op (map cell-id-n child-cids)))))
     (define v0 (make-eclass-value #:best (cons cost form)
                                   #:alts (set sig)
                                   #:canonical alloc
                                   #:provenance (seteq 'intern-node)
                                   #:regime regime))
     (define net2 (net-cell-write net1 cid v0))
     (define net3 (net-cell-write net2 reg-cid (hash sig (cons alloc cid))))
     (values net3 cid (list op child-cids cid))]))

;; Collision scan: recompute every descriptor's signature against CURRENT
;; canonicals; group classes whose nodes now share a signature. Returns a list
;; of class-cid groups (each ≥2 distinct classes) needing union.
(define (eclass-congruence-collisions net descriptors)
  (define by-sig
    (for/fold ([acc (hash)]) ([d (in-list descriptors)])
      (define sig (eclass-node-signature net (car d) (cadr d)))
      (hash-update acc sig (lambda (s) (set-add s (caddr d))) (set))))
  (for/list ([(sig cids) (in-hash by-sig)]
             #:when (> (set-count cids) 1))
    (set->list cids)))

;; Batch union: chain 'eclass-refine relates across each group.
(define (eclass-union-all net groups)
  (for/fold ([n net]) ([group (in-list groups)])
    (for/fold ([n2 n]) ([a (in-list group)] [b (in-list (cdr group))])
      (eclass-union n2 a b))))

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
         eclass-read)

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

#lang racket/base
;;; extraction-store.rkt — PReduce Track 4 Phase 2: the question-keyed rewrites
;;; store (SM6 §7.4, the owner-registered schema FIXED; design §3/§6-Q3;
;;; ledger iter 30).
;;;
;;; A CACHE LATTICE, named as such — NOT a registry: it holds DERIVED optima
;;; (keep-better merge, monotone under q-better?; recomputable from primary
;;; cells by construction; eviction = whole-cell reset at the SM6 invalidation
;;; boundaries). The rules registry's dedup-or-error contract does NOT apply
;;; here and the two are never conflated (separate module, separate domain).
;;;
;;; KEY (the owner schema): (source-e-class-content-hash, cost-criterion-id,
;;; worldview-bitmask?) — the worldview slot is RESERVED (#f; ground-only day
;;; one per the SM6 lock; schema frozen WITH the slot). The content hash is the
;;; PCE digest of the class's SORTED alt-digest set — content-defined: the same
;;; alternative set is the same QUESTION regardless of cell identity.
(require racket/set
         racket/list
         "extraction.rkt"
         "eclass-graph.rkt"
         "eclass-cell.rkt"
         "propagator.rkt"
         "pce.rkt"
         "sre-core.rkt"
         "merge-fn-registry.rkt")

(provide extraction-store-merge
         current-extraction-store-cell-id
         init-extraction-store-cell!
         eclass-question-key
         extract/cached)

;; per-key keep-better (v1 tropical; the Q-generic form parameterizes later
;; with the same SRE-fixed-fn posture as the other merges)
(define (extraction-store-merge old new)
  (cond
    [(not (hash? old)) new]
    [(not (hash? new)) old]
    [else
     (for/fold ([acc old]) ([(k v) (in-hash new)])
       (define e (hash-ref acc k #f))
       (if (or (not e) (< (hash-ref v 'cost) (hash-ref e 'cost)))
           (hash-set acc k v)
           acc))]))

(define extraction-store-sre-domain
  (make-sre-domain
   #:name 'extraction-store
   #:merge-registry (lambda (r)
                      (case r
                        [(equality) extraction-store-merge]
                        [else (error 'extraction-store-merge
                                     "no merge for relation ~a on 'extraction-store" r)]))
   #:contradicts? (lambda (v) #f)
   #:bot? (lambda (v) (and (hash? v) (zero? (hash-count v))))
   #:bot-value (hash)))
(register-domain! extraction-store-sre-domain)
(register-merge-fn!/lattice extraction-store-merge #:for-domain 'extraction-store)

(define current-extraction-store-cell-id (make-parameter #f))
(define (init-extraction-store-cell! prn-box)
  (when prn-box
    (define-values (pnet* cid)
      (net-new-cell (unbox prn-box) (hash) extraction-store-merge))
    (current-extraction-store-cell-id cid)
    (set-box! prn-box pnet*)))

;; the QUESTION key: content-defined class identity × criterion × reserved slot
(define (eclass-question-key net root-cid criterion-id)
  (define alts (hash-ref (eclass-read net root-cid) ':alts (set)))
  (define content-hash
    (pce-digest PCE-KIND-GROUND-TERM
                (list->vector (sort (set->list alts) bytes<?))))
  (list content-hash criterion-id #f))  ;; worldview RESERVED

;; consult-before-extract + record-after.
;; → (values net' cost form 'hit|'miss)
(define (extract/cached net hashcons-cid pidx-cid store-cid root-cid
                        #:q [q tropical-q])
  (define key (eclass-question-key net root-cid (q-instance-criterion-id q)))
  (define store (net-cell-read net store-cid))
  (define entry (and (hash? store) (hash-ref store key #f)))
  (cond
    [entry
     (values net (hash-ref entry 'cost) (hash-ref entry 'form) 'hit)]
    [else
     (define-values (net1 cost form) (extract net hashcons-cid pidx-cid root-cid #:q q))
     (define net2 (net-cell-write net1 store-cid
                                  (hash key (hash 'cost cost 'form form
                                                  'regime 'ground))))
     (values net2 cost form 'miss)]))

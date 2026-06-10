#lang racket/base
;;; eclass-cell.rkt — PReduce Track 1: the e-class cell value + the 'term carrier domain.
;;;
;;; Realizes the SM2 lock (D.1 §2.1, amended §7.3): ONE componentwise-ACI product on a
;;; join-semilattice where MERGE IS THE ORDER (sre-core.rkt design note honored —
;;; no order field anywhere):
;;;
;;;   eclass-value := { ':best       (cost . form) | #f   argmin by cost; tie-break PCE digest
;;;                     ':alts       seteq of e-nodes      set-union
;;;                     ':canonical  allocation-id | #f    min-join over the total order
;;;;                    ':provenance seteq                 set-union (idempotent — NOT append)
;;;                     ':regime     confidence symbol     max toward 'ground (D.1 §7.3) }
;;;
;;; Q-polymorphic cost (owner D7): v1 carrier = real-number cost with < as the Q order;
;;; the Q interface generalization arrives with Track 4's composition decision — the
;;; component shape (cost . form) is Q-shape-agnostic by construction.
;;;
;;; The 'term carrier domain hosts BOTH 'equality (flat) and 'eclass-refine
;;; (coarsening join) relations on the same carrier — the SM2 D2 owner decision
;;; (shared term carrier; relations are PROPAGATOR kinds, per the T5 census:
;;; cells bind ONE merge at creation; relate-layer merges select per relation).
(require racket/set
         "pce.rkt"
         "sre-core.rkt"
         "merge-fn-registry.rkt")

(provide eclass-bot
         eclass-bot?
         eclass-merge
         eclass-contradiction?
         make-eclass-value
         regime-rank
         term-flat-merge
         term-carrier-sre-domain)

;; --- the product value ---

(define eclass-bot
  (hasheq ':best #f
          ':alts (seteq)
          ':canonical #f
          ':provenance (seteq)
          ':regime 'retraction-eligible))

(define (make-eclass-value #:best [best #f]
                           #:alts [alts (seteq)]
                           #:canonical [canonical #f]
                           #:provenance [provenance (seteq)]
                           #:regime [regime 'retraction-eligible])
  (hasheq ':best best ':alts alts ':canonical canonical
          ':provenance provenance ':regime regime))

(define (regime-rank r)
  (case r
    [(retraction-eligible) 0]
    [(contextual) 1]
    [(ground) 2]
    [else (error 'regime-rank "unknown regime (the chain is closed — D.1 §7.1): ~a" r)]))

;; ':best — argmin by cost; tie-break by PCE ground digest of the form (D3: the
;; tie-break is the CONTENT-ADDRESS key, never object identity).
(define (best-merge a b)
  (cond
    [(not a) b]
    [(not b) a]
    [(< (car a) (car b)) a]
    [(< (car b) (car a)) b]
    [(equal? (cdr a) (cdr b)) a]
    [else (if (bytes<? (pce-digest PCE-KIND-GROUND-TERM (cdr a))
                       (pce-digest PCE-KIND-GROUND-TERM (cdr b)))
              a b)]))

(define (canonical-merge a b)
  (cond [(not a) b] [(not b) a] [else (min a b)]))

(define (regime-merge a b)
  (if (>= (regime-rank a) (regime-rank b)) a b))

;; The componentwise-ACI product join. MERGE IS THE ORDER.
(define (eclass-merge old new)
  (cond
    [(not (hash? old)) new]
    [(not (hash? new)) old]
    [else
     (hasheq ':best       (best-merge (hash-ref old ':best #f) (hash-ref new ':best #f))
             ':alts       (set-union (hash-ref old ':alts (seteq))
                                     (hash-ref new ':alts (seteq)))
             ':canonical  (canonical-merge (hash-ref old ':canonical #f)
                                           (hash-ref new ':canonical #f))
             ':provenance (set-union (hash-ref old ':provenance (seteq))
                                     (hash-ref new ':provenance (seteq)))
             ':regime     (regime-merge (hash-ref old ':regime 'retraction-eligible)
                                        (hash-ref new ':regime 'retraction-eligible)))]))

(define (eclass-bot? v) (equal? v eclass-bot))

;; The product has no ⊤ — contradiction surfaces per-component upstream
;; (e.g., :eclass-link's facet-level ⊤ in the attribute map, D.1 §8.3).
(define (eclass-contradiction? v) #f)

;; --- the 'term carrier domain ---
;; 'equality on this carrier = flat merge (equal → keep; differ → 'term-top).
(define (term-flat-merge a b)
  (if (equal? a b) a 'term-top))

(define term-carrier-sre-domain
  (make-sre-domain
   #:name 'term
   #:merge-registry (lambda (r)
                      (case r
                        [(equality) term-flat-merge]
                        [(eclass-refine) eclass-merge]
                        [else (error 'term-carrier-merge
                                     "no merge registered for relation ~a on the 'term carrier" r)]))
   #:contradicts? (lambda (v) (eq? v 'term-top))
   #:bot? eclass-bot?
   #:bot-value eclass-bot))
(register-domain! term-carrier-sre-domain)
(register-merge-fn!/lattice eclass-merge #:for-domain 'term)

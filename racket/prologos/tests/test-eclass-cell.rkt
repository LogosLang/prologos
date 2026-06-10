#lang racket/base
;; PReduce Track 1 — e-class product merge + 'term carrier + 'eclass-refine relation
;; (SM2 lock D.1 §2.1/§7.3; ledger iter 8).
(require rackunit racket/set
         "../eclass-cell.rkt"
         "../pce.rkt"
         "../sre-core.rkt"
         "../propagator.rkt"
         "../syntax.rkt")

;; --- componentwise-ACI laws (spot checks) ---

(define v1 (make-eclass-value #:best (cons 5 (expr-int 1))
                              #:alts (set 'n1)
                              #:canonical 10
                              #:provenance (seteq 'r1)
                              #:regime 'contextual))
(define v2 (make-eclass-value #:best (cons 3 (expr-int 2))
                              #:alts (set 'n2)
                              #:canonical 7
                              #:provenance (seteq 'r2)
                              #:regime 'ground))

;; commutativity
(check-equal? (eclass-merge v1 v2) (eclass-merge v2 v1))
;; idempotence
(check-equal? (eclass-merge v1 v1) v1)
;; associativity (sample)
(define v3 (make-eclass-value #:best (cons 4 (expr-int 3)) #:alts (set 'n3)))
(check-equal? (eclass-merge (eclass-merge v1 v2) v3)
              (eclass-merge v1 (eclass-merge v2 v3)))
;; bot is the identity
(check-equal? (eclass-merge eclass-bot v1) v1)
(check-equal? (eclass-merge v1 eclass-bot) v1)
(check-true (eclass-bot? eclass-bot))
(check-false (eclass-bot? v1))

;; --- per-component semantics ---

(define m (eclass-merge v1 v2))
(check-equal? (hash-ref m ':best) (cons 3 (expr-int 2)))          ;; argmin by cost
(check-equal? (hash-ref m ':alts) (set 'n1 'n2))                 ;; set-union (equal?-based)
(check-equal? (hash-ref m ':canonical) 7)                         ;; min allocation order
(check-equal? (hash-ref m ':provenance) (seteq 'r1 'r2))          ;; set-union
(check-equal? (hash-ref m ':regime) 'ground)                      ;; max toward ground

;; best tie-break: equal costs, different forms → PCE-digest order, symmetric
(define ta (make-eclass-value #:best (cons 5 (expr-int 100))))
(define tb (make-eclass-value #:best (cons 5 (expr-int 200))))
(check-equal? (hash-ref (eclass-merge ta tb) ':best)
              (hash-ref (eclass-merge tb ta) ':best))
;; the winner is whichever form has the smaller PCE ground digest
(define expected-winner
  (if (bytes<? (pce-digest PCE-KIND-GROUND-TERM (expr-int 100))
               (pce-digest PCE-KIND-GROUND-TERM (expr-int 200)))
      (cons 5 (expr-int 100))
      (cons 5 (expr-int 200))))
(check-equal? (hash-ref (eclass-merge ta tb) ':best) expected-winner)

;; regime chain is closed
(check-exn exn:fail? (lambda () (regime-rank 'nonsense)))

;; --- the 'term carrier domain registry dispatch ---

(check-equal? ((sre-domain-merge term-carrier-sre-domain sre-eclass-refine) v1 v2)
              (eclass-merge v1 v2))
(check-equal? ((sre-domain-merge term-carrier-sre-domain sre-equality) 'x 'x) 'x)
(check-equal? ((sre-domain-merge term-carrier-sre-domain sre-equality) 'x 'y) 'term-top)

;; --- the relate-layer propagator: symmetric coarsening on a live network ---

(let*-values ([(net0 cid-a) (net-new-cell (make-prop-network) eclass-bot eclass-merge)]
              [(net1 cid-b) (net-new-cell net0 eclass-bot eclass-merge)])
  (define net2 (net-cell-write net1 cid-a v1))
  (define net3 (net-cell-write net2 cid-b v2))
  ;; through the PUBLIC dispatcher — exercises the propagator-ctor-table entry
  (define fire (sre-make-structural-relate-propagator term-carrier-sre-domain
                                                      cid-a cid-b
                                                      #:relation sre-eclass-refine))
  (define net4 (fire net3))
  (define joined (eclass-merge v1 v2))
  (check-equal? (net-cell-read net4 cid-a) joined "cell-a coarsened to the join")
  (check-equal? (net-cell-read net4 cid-b) joined "cell-b coarsened to the join")
  ;; idempotent re-fire: no further change
  (define net5 (fire net4))
  (check-equal? (net-cell-read net5 cid-a) joined)
  (check-equal? (net-cell-read net5 cid-b) joined))

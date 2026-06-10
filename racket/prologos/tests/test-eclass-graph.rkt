#lang racket/base
;; PReduce Track 1 GREEN SLICE tests (D.1 §2.4; ledger iter 9):
;; the literal trace, racing unions → one fixpoint, the consuming read.
(require rackunit racket/set
         "../eclass-graph.rkt"
         "../eclass-cell.rkt"
         "../pce.rkt"
         "../propagator.rkt"
         "../typing-propagators.rkt"
         "../syntax.rkt")

(define ta (expr-app (expr-app (expr-bvar 0) (expr-int 1)) (expr-int 2)))  ;; (+ 1 2) shape
(define tb (expr-int 3))
(define tc (expr-app (expr-bvar 1) (expr-int 3)))                          ;; (id 3) shape

;; ---- the LITERAL TRACE: create → intern → union install → quiescence → reads ----

(let*-values ([(net0 reg) (make-eclass-graph (make-prop-network))]
              [(net1 cid-a dig-a) (eclass-intern net0 reg ta #:cost 5)]
              [(net2 cid-b dig-b) (eclass-intern net1 reg tb #:cost 1)])
  ;; hashcons: re-interning the same term returns the SAME cell, no new allocation
  (let-values ([(net2x cid-a2 dig-a2) (eclass-intern net2 reg ta #:cost 5)])
    (check-equal? cid-a2 cid-a "hashcons hit returns the existing class")
    (check-equal? dig-a2 dig-a)
    (check-eq? net2x net2 "hashcons hit allocates nothing"))
  ;; registry lookup by digest
  (check-equal? (eclass-lookup net2 reg dig-a) cid-a)
  (check-equal? (eclass-lookup net2 reg dig-b) cid-b)
  (check-false (eclass-lookup net2 reg (pce-digest PCE-KIND-GROUND-TERM tc)))
  ;; union + quiescence: both cells converge to the coarsening join
  (define net3 (run-to-quiescence (eclass-union net2 cid-a cid-b)))
  (define va (eclass-read net3 cid-a))
  (define vb (eclass-read net3 cid-b))
  (check-equal? va vb "both class cells hold the join at quiescence")
  (check-equal? (hash-ref va ':best) (cons 1 tb) "cost-best form wins (argmin)")
  (check-equal? (hash-ref va ':canonical)
                (min (cell-id-n cid-a) (cell-id-n cid-b))
                "canonical NAME = first allocation (min-join)")
  (check-equal? (hash-ref va ':alts) (set dig-a dig-b) "alts union (digest dedup)")
  (check-equal? (hash-ref va ':regime) 'ground))

;; ---- RACING UNIONS: a~b and b~c installed before quiescence → ONE fixpoint ----

(define (run-triple order)
  (let*-values ([(net0 reg) (make-eclass-graph (make-prop-network))]
                [(net1 ca da) (eclass-intern net0 reg ta #:cost 5)]
                [(net2 cb db) (eclass-intern net1 reg tb #:cost 1)]
                [(net3 cc dc) (eclass-intern net2 reg tc #:cost 9)])
    (define net4
      (for/fold ([n net3]) ([pr (in-list order)])
        (eclass-union n (if (eq? (car pr) 'a) ca (if (eq? (car pr) 'b) cb cc))
                        (if (eq? (cdr pr) 'a) ca (if (eq? (cdr pr) 'b) cb cc)))))
    (define net5 (run-to-quiescence net4))
    (list (eclass-read net5 ca) (eclass-read net5 cb) (eclass-read net5 cc))))

(define fix1 (run-triple (list (cons 'a 'b) (cons 'b 'c))))
(define fix2 (run-triple (list (cons 'b 'c) (cons 'a 'b))))  ;; permuted install order
;; transitive convergence through the shared cell: all three equal
(check-equal? (car fix1) (cadr fix1))
(check-equal? (cadr fix1) (caddr fix1))
;; order-independence: permuted installs reach the SAME fixpoint (CALM)
(check-equal? fix1 fix2 "racing unions converge to one fixpoint regardless of order")
(check-equal? (hash-ref (car fix1) ':best) (cons 1 tb) "triple join keeps the global argmin")

;; ---- the CONSUMING READ: :eclass-link facet → registry → class best ----

(let*-values ([(net0 reg) (make-eclass-graph (make-prop-network))]
              [(net1 cid dig) (eclass-intern net0 reg ta #:cost 5)]
              [(net2 cid-b dig-b) (eclass-intern net1 reg tb #:cost 1)])
  (define net3 (run-to-quiescence (eclass-union net2 cid cid-b)))
  ;; a production position links to the class by CONTENT-ADDRESS KEY (D.1 §8.3)
  (define am (attribute-map-merge-fn (hasheq)
                                     (hasheq 'pos7 (hasheq ':eclass-link dig))))
  (define linked-digest (that-read am 'pos7 ':eclass-link))
  (check-equal? linked-digest dig "arity-3 read returns the raw link key")
  (define linked-cid (eclass-lookup net3 reg linked-digest))
  (check-equal? linked-cid cid)
  (check-equal? (hash-ref (eclass-read net3 linked-cid) ':best) (cons 1 tb)
                "the consuming read reaches the class's cost-best form")
  ;; and the link stays OUT of the user-facing arity-2 view
  (check-false (hash-has-key? (that-read am 'pos7) ':eclass-link)))

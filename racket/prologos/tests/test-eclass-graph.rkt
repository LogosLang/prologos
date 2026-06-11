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

;; ---- CONGRUENCE ENGINE (iter 11a): f(a), f(b) union after a ∪ b ----

(let*-values ([(net0 reg) (make-eclass-graph (make-prop-network))]
              [(net1 ca da) (eclass-intern net0 reg ta #:cost 5)]
              [(net2 cb db) (eclass-intern net1 reg tb #:cost 1)])
  ;; intern parent nodes f(a), f(b): different child classes → different sigs
  (define-values (net3 cfa dfa) (eclass-intern-node net2 reg 'f (list ca) #:cost 2))
  (define-values (net4 cfb dfb) (eclass-intern-node net3 reg 'f (list cb) #:cost 3))
  (check-not-equal? cfa cfb "distinct children ⇒ distinct parent classes")
  ;; re-intern of the SAME node is a hashcons hit
  (let-values ([(net4x cfa2 _) (eclass-intern-node net4 reg 'f (list ca))])
    (check-equal? cfa2 cfa)
    (check-eq? net4x net4 "node hashcons hit allocates nothing"))
  ;; no collisions before the child union
  (check-equal? (eclass-congruence-collisions net4 (list dfa dfb)) '())
  ;; union the children + quiesce: canonicals coarsen to the shared min
  (define net5 (run-to-quiescence (eclass-union net4 ca cb)))
  (check-equal? (eclass-canonical net5 ca) (eclass-canonical net5 cb))
  ;; the scan now detects the f-collision
  (define groups (eclass-congruence-collisions net5 (list dfa dfb)))
  (check-equal? (length groups) 1)
  (check-equal? (list->seteq (car groups)) (seteq cfa cfb))
  ;; the cascade: union the collided group + quiesce → parents converge
  (define net6 (run-to-quiescence (eclass-union-all net5 groups)))
  (check-equal? (eclass-read net6 cfa) (eclass-read net6 cfb)
                "congruent parents hold one joined class value")
  (check-equal? (car (hash-ref (eclass-read net6 cfa) ':best)) 2
                "the cheaper parent form wins the joined class")
  ;; idempotence: a second scan over CURRENT state finds the same (already-
  ;; unioned) group — re-unioning is a no-op at quiescence
  (define net7 (run-to-quiescence
                (eclass-union-all net6 (eclass-congruence-collisions net6 (list dfa dfb)))))
  (check-equal? (eclass-read net7 cfa) (eclass-read net6 cfa)))

;; sound-if-stale: an intern keyed by a STALE canonical allocates a duplicate,
;; and the congruence scan heals it (the documented wasteful-but-sound mode)
(let*-values ([(net0 reg) (make-eclass-graph (make-prop-network))]
              [(net1 ca _da) (eclass-intern net0 reg ta #:cost 5)]
              [(net2 cb _db) (eclass-intern net1 reg tb #:cost 1)]
              ;; the parent watches the LATER-allocated child: its canonical is the
              ;; one the union CHANGES (min-join pulls it down to ca's alloc) —
              ;; the first-allocated child's canonical survives unions unchanged
              ;; (asserted by the first iteration-11a test's hashcons hit)
              [(net3 cfa dfa) (eclass-intern-node net2 reg 'g (list cb))])
  (define net4 (run-to-quiescence (eclass-union net3 ca cb)))
  ;; same node g(b) re-interned AFTER the union: canonical changed → new sig
  ;; → duplicate class (NOT the old cell)
  (define-values (net5 cfa2 dfa2) (eclass-intern-node net4 reg 'g (list cb)))
  (check-not-equal? cfa2 cfa "stale-key miss allocates a duplicate (documented)")
  ;; the scan detects the duplicate pair and the cascade heals it
  (define groups (eclass-congruence-collisions net5 (list dfa dfa2)))
  (check-equal? (length groups) 1)
  (define net6 (run-to-quiescence (eclass-union-all net5 groups)))
  (check-equal? (eclass-read net6 cfa) (eclass-read net6 cfa2)
                "the duplicate is unioned away — wasteful-but-sound"))

;; ---- 11b REACTIVE: a ∪ b auto-unions f(a), f(b) at quiescence — NO manual scan ----

(let*-values ([(net0 reg) (make-eclass-graph (make-prop-network))]
              [(net1 ca _da) (eclass-intern net0 reg ta #:cost 5)]
              [(net2 cb _db) (eclass-intern net1 reg tb #:cost 1)]
              [(net3 cfa _dfa) (eclass-intern-node net2 reg 'f (list ca) #:cost 2)]
              [(net4 cfb _dfb) (eclass-intern-node net3 reg 'f (list cb) #:cost 3)])
  (check-not-equal? (eclass-read net4 cfa) (eclass-read net4 cfb))
  ;; ONE union + ONE quiescence: watchers recompute sigs, the topology-tier
  ;; handler installs the relate, the join lands — fully automatic
  (define net5 (run-to-quiescence (eclass-union net4 ca cb)))
  (check-equal? (eclass-read net5 cfa) (eclass-read net5 cfb)
                "congruent parents auto-union at quiescence (reactive cascade)")
  (check-equal? (car (hash-ref (eclass-read net5 cfa) ':best)) 2
                "the cheaper parent form wins automatically"))

;; two-LEVEL cascade: the f-union must itself wake g's watchers
(let*-values ([(net0 reg) (make-eclass-graph (make-prop-network))]
              [(net1 ca _x1) (eclass-intern net0 reg ta #:cost 5)]
              [(net2 cb _x2) (eclass-intern net1 reg tb #:cost 1)]
              [(net3 cfa _x3) (eclass-intern-node net2 reg 'f (list ca))]
              [(net4 cfb _x4) (eclass-intern-node net3 reg 'f (list cb))]
              [(net5 cga _x5) (eclass-intern-node net4 reg 'g (list cfa))]
              [(net6 cgb _x6) (eclass-intern-node net5 reg 'g (list cfb))])
  (define net7 (run-to-quiescence (eclass-union net6 ca cb)))
  (check-equal? (eclass-read net7 cfa) (eclass-read net7 cfb)
                "level 1: f-parents converge")
  (check-equal? (eclass-read net7 cga) (eclass-read net7 cgb)
                "level 2: the f-union cascades through to g-parents"))

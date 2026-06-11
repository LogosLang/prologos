#lang racket/base
;; PReduce Track 4 Phase 1 — extraction as a propagator fixpoint (design §2;
;; ledger iter 29): the DIAMOND (cheap path wins at quiescence) + the two-level
;; cascade + the cost-best form tree.
(require rackunit racket/set
         "../extraction-store.rkt"
         "../extraction.rkt"
         "../eclass-graph.rkt"
         "../eclass-cell.rkt"
         "../propagator.rkt"
         "../syntax.rkt")

;; fixture: a graph with the parent index live
(define (fresh-graph)
  (define-values (net0 hc) (make-eclass-graph (make-prop-network)))
  (define prn-box (box net0))
  (init-parent-index-cell! prn-box)
  (values (unbox prn-box) hc (current-parent-index-cell-id)))

;; ---- the DIAMOND: f(x) cost 10 and g(x) cost 2 unioned into ONE class ----
(parameterize ([current-parent-index-cell-id #f])
  (define-values (net0 hc pidx) (fresh-graph))
  (parameterize ([current-parent-index-cell-id pidx])
    (define-values (net1 cx _dx) (eclass-intern net0 hc '(lit x) #:cost 1))
    (define-values (net2 cf _df) (eclass-intern-node net1 hc 'f (list cx) #:cost 10))
    (define-values (net3 cg _dg) (eclass-intern-node net2 hc 'g (list cx) #:cost 2))
    ;; union the two parents: ONE class with two node alts
    (define net4 (run-to-quiescence (eclass-union net3 cf cg)))
    (define-values (net5 cost form) (extract net4 hc pidx cf))
    (check-equal? cost 3 "g-path wins: 2 (g) + 1 (x) = 3, vs f's 11")
    (check-equal? form '(g (lit x)) "the cost-best FORM tree is the cheap alt")))

;; ---- two-LEVEL fixpoint: h(P) where P = {f(x), g(x)} — the cascade descends ----
(parameterize ([current-parent-index-cell-id #f])
  (define-values (net0 hc pidx) (fresh-graph))
  (parameterize ([current-parent-index-cell-id pidx])
    (define-values (net1 cx _dx) (eclass-intern net0 hc '(lit x) #:cost 1))
    (define-values (net2 cf _df) (eclass-intern-node net1 hc 'f (list cx) #:cost 10))
    (define-values (net3 cg _dg) (eclass-intern-node net2 hc 'g (list cx) #:cost 2))
    (define net4 (run-to-quiescence (eclass-union net3 cf cg)))
    (define-values (net5 ch _dh) (eclass-intern-node net4 hc 'h (list cf) #:cost 1))
    (define-values (net6 cost form) (extract net5 hc pidx ch))
    (check-equal? cost 4 "h(g(x)): 1 + (2 + 1) — the fixpoint descends two levels")
    (check-equal? form '(h (g (lit x))))))

;; ---- a cheaper LITERAL alt in the parent class beats both node alts ----
(parameterize ([current-parent-index-cell-id #f])
  (define-values (net0 hc pidx) (fresh-graph))
  (parameterize ([current-parent-index-cell-id pidx])
    (define-values (net1 cx _dx) (eclass-intern net0 hc '(lit x) #:cost 1))
    (define-values (net2 cf _df) (eclass-intern-node net1 hc 'f (list cx) #:cost 10))
    ;; union the f-class with a folded literal class of cost 1
    (define-values (net3 clit _dl) (eclass-intern net2 hc '(lit folded) #:cost 1))
    (define net4 (run-to-quiescence (eclass-union net3 cf clit)))
    (define-values (net5 cost form) (extract net4 hc pidx cf))
    (check-equal? cost 1 "the literal alt (the e-graph's folded form) wins")
    (check-equal? form '(lit folded))))

;; ---- determinism: extracting twice yields identical results ----
(parameterize ([current-parent-index-cell-id #f])
  (define-values (net0 hc pidx) (fresh-graph))
  (parameterize ([current-parent-index-cell-id pidx])
    (define-values (net1 cx _dx) (eclass-intern net0 hc '(lit x) #:cost 1))
    (define-values (net2 cg _dg) (eclass-intern-node net1 hc 'g (list cx) #:cost 2))
    (define-values (net3 c1 f1) (extract net2 hc pidx cg))
    (define-values (net4 c2 f2) (extract net3 hc pidx cg))
    (check-equal? (list c1 f1) (list c2 f2) "extraction is deterministic")))

;; ---- Phase 2 (iter 30): the question-keyed CACHE lattice ----
(parameterize ([current-parent-index-cell-id #f]
               [current-extraction-store-cell-id #f])
  (define-values (net0 hc pidx) (fresh-graph))
  (parameterize ([current-parent-index-cell-id pidx])
    (define pb (box net0))
    (init-extraction-store-cell! pb)
    (define store (current-extraction-store-cell-id))
    (define-values (net1 cx _dx) (eclass-intern (unbox pb) hc '(lit x) #:cost 1))
    (define-values (net2 cg _dg) (eclass-intern-node net1 hc 'g (list cx) #:cost 2))
    ;; MISS: full fixpoint runs + the answer records
    (define-values (net3 c1 f1 v1) (extract/cached net2 hc pidx store cg))
    (check-equal? v1 'miss)
    (check-equal? (list c1 f1) (list 3 '(g (lit x))))
    ;; HIT: served from the store — NO fixpoint (observable: zero new cells)
    (define cells-before (prop-network-next-cell-id net3))
    (define-values (net4 c2 f2 v2) (extract/cached net3 hc pidx store cg))
    (check-equal? v2 'hit)
    (check-equal? (list c2 f2) (list c1 f1) "the hit serves the recorded answer")
    (check-equal? (prop-network-next-cell-id net4) cells-before
                  "a hit allocates NOTHING — no fixpoint ran")
    ;; CRITERION ISOLATION: a different Q instance is a different QUESTION
    (define q2 (q-instance + < 0 +inf.0 'other-criterion))
    (define-values (net5 c3 f3 v3) (extract/cached net4 hc pidx store cg #:q q2))
    (check-equal? v3 'miss "a different criterion-id misses (key isolation)")
    ;; KEEP-BETTER: a better entry under the same key wins; a worse one is absorbed
    (define key (eclass-question-key net5 cg 'tropical-v1))
    (define net6 (net-cell-write net5 store
                                 (hash key (hash 'cost 999 'form '(worse) 'regime 'ground))))
    (check-equal? (hash-ref (hash-ref (net-cell-read net6 store) key) 'cost) 3
                  "a WORSE write is absorbed — keep-better is the lattice")
    (define net7 (net-cell-write net6 store
                                 (hash key (hash 'cost 1 'form '(better) 'regime 'ground))))
    (check-equal? (hash-ref (hash-ref (net-cell-read net7 store) key) 'cost) 1
                  "a BETTER write updates — monotone toward the optimum")))

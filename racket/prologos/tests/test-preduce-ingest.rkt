#lang racket/base
;; PReduce Track 2 — the ingestion hook (iter 22): gated OFF by default; when ON,
;; whnf's int folds route through the e-graph and land the same answers, with the
;; classes observable afterward.
(require rackunit racket/set
         "../reduction.rkt"
         "../syntax.rkt"
         "../eclass-graph.rkt"
         "../rule-registry.rkt"
         "../kernel-rules-seed.rkt"
         "../propagator.rkt"
         (only-in "../metavar-store.rkt" current-persistent-registry-net-box)
         (only-in "../pce.rkt" pce-digest PCE-KIND-GROUND-TERM))

;; OFF (the default): native fold; no e-graph involvement
(check-equal? (whnf (expr-int-add (expr-int 1) (expr-int 2))) (expr-int 3))
(check-false (current-preduce-ingest?) "default is OFF")

;; ON with no plumbing: still the native answers (the hook is total)
(parameterize ([current-preduce-ingest? #t])
  (check-equal? (whnf (expr-int-add (expr-int 1) (expr-int 2))) (expr-int 3))
  (check-equal? (whnf (expr-int-mul (expr-int 6) (expr-int 7))) (expr-int 42)))

;; ON with full plumbing: same answers, AND the e-graph holds the folded classes
(define prn-box (box (make-prop-network)))
(parameterize ([current-rule-registry-cell-id #f]
               [current-eclass-hashcons-cell-id #f]
               [current-persistent-registry-net-box prn-box])
  (init-rule-registry-cell! prn-box)
  (set-box! prn-box (run-to-quiescence
                     (register-arithmetic-seed! (unbox prn-box)
                                                (current-rule-registry-cell-id))))
  (init-eclass-hashcons-cell! prn-box)
  (parameterize ([current-preduce-ingest? #t])
    (check-equal? (whnf (expr-int-add (expr-int 1) (expr-int 2))) (expr-int 3)
                  "e-graph path lands the same fold")
    (check-equal? (whnf (expr-int-sub (expr-int 10) (expr-int 3))) (expr-int 7))
    (check-equal? (whnf (expr-int-mul (expr-int 6) (expr-int 7))) (expr-int 42)))
  ;; the classes are now IN the e-graph (the memo exists)
  (define net (unbox prn-box))
  (define hc (current-eclass-hashcons-cell-id))
  (define dig (pce-digest PCE-KIND-GROUND-TERM '(int+ (lit 1) (lit 2))))
  (define cid (eclass-lookup net hc dig))
  (check-true (and cid #t) "the ingested class persists in the per-file e-graph")
  (check-equal? (hash-ref (eclass-read net cid) ':best) (cons 1 '(lit 3))
                "the class best is the folded literal")
  ;; re-whnf of the same shape is a hashcons HIT (no new class)
  (define n-classes-before (hash-count (net-cell-read net hc)))
  (parameterize ([current-preduce-ingest? #t])
    (whnf (expr-int-add (expr-int 1) (expr-int 2))))
  (check-equal? (hash-count (net-cell-read (unbox prn-box) hc)) n-classes-before
                "re-ingestion of the same position is a memo hit"))

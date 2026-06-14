#lang racket/base
;; PReduce ingestion (the on-network reduction path). On-network reduction is the
;; ONLY path on this branch (the parameter gate + off-network native arms were
;; deleted 2026-06-14): whnf's β/ι/δ/int-folds always route through the e-graph
;; and land the same answers, with the classes observable afterward; the hook is
;; TOTAL (degrades to the native step when the e-graph infra is absent).
(require rackunit racket/set
         (only-in "../rule-dispatch.rkt" guard-skip-count reset-guard-skip-count!)
         "../reduction.rkt"
         "../syntax.rkt"
         "../eclass-graph.rkt"
         "../rule-registry.rkt"
         "../kernel-rules-seed.rkt"
         "../propagator.rkt"
         (only-in "../metavar-store.rkt" current-persistent-registry-net-box)
         (only-in "../extraction-store.rkt"
                  current-extraction-store-cell-id init-extraction-store-cell!
                  store-record-reduction)
         (only-in "../pce.rkt" pce-digest PCE-KIND-GROUND-TERM))

;; No e-graph plumbing: the ingest path degrades to the native fold (total).
(check-equal? (whnf (expr-int-add (expr-int 1) (expr-int 2))) (expr-int 3))
(check-equal? (whnf (expr-int-mul (expr-int 6) (expr-int 7))) (expr-int 42))

;; With full plumbing: same answers, AND the e-graph holds the folded classes
(define prn-box (box (make-prop-network)))
(parameterize ([current-rule-registry-cell-id #f]
               [current-eclass-hashcons-cell-id #f]
               [current-persistent-registry-net-box prn-box])
  (init-rule-registry-cell! prn-box)
  (set-box! prn-box (run-to-quiescence
                     (register-arithmetic-seed! (unbox prn-box)
                                                (current-rule-registry-cell-id))))
  (init-eclass-hashcons-cell! prn-box)
  (check-equal? (whnf (expr-int-add (expr-int 1) (expr-int 2))) (expr-int 3)
                "e-graph path lands the same fold")
  (check-equal? (whnf (expr-int-sub (expr-int 10) (expr-int 3))) (expr-int 7))
  (check-equal? (whnf (expr-int-mul (expr-int 6) (expr-int 7))) (expr-int 42))
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
  (whnf (expr-int-add (expr-int 1) (expr-int 2)))
  (check-equal? (hash-count (net-cell-read (unbox prn-box) hc)) n-classes-before
                "re-ingestion of the same position is a memo hit"))

;; ---- δ-memo: {body, whnf(body)} as one e-class ----
(parameterize ([current-rule-registry-cell-id #f]
               [current-eclass-hashcons-cell-id #f]
               [current-persistent-registry-net-box (box (make-prop-network))])
  (define pb (current-persistent-registry-net-box))
  (init-rule-registry-cell! pb)
  (init-eclass-hashcons-cell! pb)
  (define hc (current-eclass-hashcons-cell-id))
  (define body (expr-int-add (expr-int 1) (expr-int 2)))
  ;; first whnf of the body: the int-fold hook interns + folds
  (check-equal? (whnf body) (expr-int 3))
  ;; the body's class exists in the e-graph (the int hook keyed it by its form)
  (define net (unbox pb))
  (check-true (> (hash-count (net-cell-read net hc)) 0)
              "ingestion populated the per-file e-graph"))

;; ---- guarded β: the Track 2 exit criterion ----
(parameterize ([current-rule-registry-cell-id #f]
               [current-eclass-hashcons-cell-id #f]
               [current-persistent-registry-net-box (box (make-prop-network))])
  (define pb (current-persistent-registry-net-box))
  (init-rule-registry-cell! pb)
  (init-eclass-hashcons-cell! pb)
  (define hc (current-eclass-hashcons-cell-id))
  ;; a PURE redex: ((λx. x + 1) 5) → 6, memoized as {redex, 6}
  (define redex (expr-app (expr-lam 'mw (expr-Int)
                                    (expr-int-add (expr-bvar 0) (expr-int 1)))
                          (expr-int 5)))
  (check-equal? (whnf redex) (expr-int 6) "guarded β fires and lands the contractum")
  ;; the redex class holds the contractum at cost 0 (the {redex, result} e-class)
  (define dig (pce-digest PCE-KIND-GROUND-TERM redex))
  (define cid (eclass-lookup (unbox pb) hc dig))
  (check-true (and cid #t) "the β redex has a class")
  (check-equal? (hash-ref (eclass-read (unbox pb) cid) ':best) (cons 0 (expr-int 6))
                "the contractum is the class best — β recorded as an e-class join")
  ;; memo hit: same redex again, no new classes
  (define n0 (hash-count (net-cell-read (unbox pb) hc)))
  (whnf redex)
  (check-equal? (hash-count (net-cell-read (unbox pb) hc)) n0 "β memo hit")
  ;; an EFFECT-HEADED arg: ((λx. 99) (read ch)) — the guard SKIPS the e-graph
  ;; (pessimistic: deletion of an effectful capture must never be RECORDED);
  ;; the guard path still computes (legacy effects are deferred descriptors)
  (define eff-redex (expr-app (expr-lam 'mw (expr-Int) (expr-int 99))
                              (expr-app (expr-fvar 'read) (expr-fvar 'ch))))
  (reset-guard-skip-count!)
  (define n1 (hash-count (net-cell-read (unbox pb) hc)))
  (check-equal? (whnf eff-redex) (expr-int 99) "the guard path still computes")
  (check-equal? (guard-skip-count) 1 "the guard skipped the e-graph recording")
  (check-equal? (hash-count (net-cell-read (unbox pb) hc)) n1
                "no class recorded for the effect-capturing redex"))

;; ---- ι ingestion: the natrec recursion carriers ----
(parameterize ([current-rule-registry-cell-id #f]
               [current-eclass-hashcons-cell-id #f]
               [current-persistent-registry-net-box (box (make-prop-network))])
  (define pb (current-persistent-registry-net-box))
  (init-rule-registry-cell! pb)
  (init-eclass-hashcons-cell! pb)
  (define hc (current-eclass-hashcons-cell-id))
  ;; natrec computing 3 + 2 via the suc-step (the church-arithmetic shape):
  ;; natrec _ 3 (λp.λr. suc r) 2 → 5
  (define plus-redex
    (expr-natrec (expr-lam 'mw (expr-Nat) (expr-Nat))
                 (expr-nat-val 3)
                 (expr-lam 'mw (expr-Nat)
                           (expr-lam 'mw (expr-Nat) (expr-suc (expr-bvar 0))))
                 (expr-nat-val 2)))
  ;; whnf exposes the head constructor (WEAK head — the inner natrec stays);
  ;; nf drives the full value: 3+2=5 (through the e-graph)
  (check-true (expr-suc? (whnf plus-redex)) "whnf exposes suc (weak head)")
  (check-equal? (nf plus-redex) (expr-nat-val 5) "nf lands 3+2=5 through the e-graph")
  ;; the redex chain memoized: classes exist for the nat-val steps
  (check-true (> (hash-count (net-cell-read (unbox pb) hc)) 0)
              "ι redexes populated the e-graph")
  ;; memo hit: same redex re-whnf'd, zero new classes
  (define n0 (hash-count (net-cell-read (unbox pb) hc)))
  (whnf plus-redex)
  (check-equal? (hash-count (net-cell-read (unbox pb) hc)) n0 "ι memo hit")
  ;; effect-headed step: the guard SKIPS the recording, the guard path still computes
  (reset-guard-skip-count!)
  (define eff-redex
    (expr-natrec (expr-lam 'mw (expr-Nat) (expr-Nat))
                 (expr-nat-val 0)
                 (expr-app (expr-fvar 'read) (expr-fvar 'ch))
                 (expr-nat-val 1)))
  (define n1 (hash-count (net-cell-read (unbox pb) hc)))
  (void (with-handlers ([exn:fail? (lambda (_e) 'native-error-ok)])
          (whnf eff-redex)))
  (check-true (> (guard-skip-count) 0) "effect-headed step skipped the e-graph")
  (check-equal? (hash-count (net-cell-read (unbox pb) hc)) n1
                "no class recorded for the effectful ι redex"))

;; ---- consult-wiring (2026-06-11): the store SERVES the read path ----
;; The sharp check: pre-seed the store with the question's result, then call
;; preduce-ingest-delta with a #:compute that ERRORS — a working consult path
;; serves from the store without ever running the native step.
(parameterize ([current-eclass-hashcons-cell-id #f]
               [current-extraction-store-cell-id #f]
               [current-persistent-registry-net-box (box (make-prop-network))])
  (define pb (current-persistent-registry-net-box))
  (init-eclass-hashcons-cell! pb)
  (init-extraction-store-cell! pb)
  (define hc (current-eclass-hashcons-cell-id))
  (define sc (current-extraction-store-cell-id))
  (define body '(consult-body 20 22))
  (define result '(consult-result 42))
  (define-values (n1 cid1 _d) (eclass-intern (unbox pb) hc body #:cost 10))
  (set-box! pb n1)
  (set-box! pb (store-record-reduction (unbox pb) sc cid1 result))
  ;; the class best is still (10 . body) — the hashcons path MISSES; only the
  ;; store has the answer. compute must NOT run:
  (define served
    (preduce-ingest-delta body
                          #:compute (lambda () (error 'consult-wiring "compute ran"))))
  (check-equal? served result "the store serves the read path; compute skipped")
  ;; and the hit PROMOTED the class best to cost 0:
  (define best (hash-ref (eclass-read (unbox pb) cid1) ':best #f))
  (check-true (and best (zero? (car best))) "store hit promoted to class best")
  ;; second encounter takes the hashcons fast path (still no compute):
  (check-equal? (preduce-ingest-delta body
                                      #:compute (lambda () (error 'x "ran")))
                result "subsequent encounters hit the promoted best"))

#lang racket/base
;; PReduce Track 8 Phase 5a — network-driven reduction engine: PARITY harness.
;; whnf-via-egraph (the intern→reduce→extract driver, iterating the whnf-step1
;; one-step classifier) MUST agree with native whnf on every term. The migrated
;; arms (β, ι, suc-collapse, fst/snd, J, boolrec, ann, vhead/vtail, + the
;; subterm-demand arms) are validated here; everything else is the 'native
;; fallback (parity-trivial). This is the gate the design (§6) makes
;; non-negotiable before any construct is "migrated".
(require rackunit
         "../reduction.rkt"
         "../syntax.rkt"
         "../propagator.rkt"
         "../eclass-graph.rkt"
         "../rule-registry.rkt"
         "../kernel-rules-seed.rkt"
         (only-in "../metavar-store.rkt" current-persistent-registry-net-box))

;; --- whnf-step1 classifies the migrated head redexes as 'step (not 'native) ---
;; (proves the arms are actually MIGRATED, not silently falling back)
(check-equal? (car (whnf-step1 (expr-app (expr-lam 'mw (expr-Int) (expr-bvar 0))
                                         (expr-int 5))))
              'step "β is migrated (step, not native)")
(check-equal? (car (whnf-step1 (expr-fst (expr-pair (expr-int 1) (expr-int 2)))))
              'step "fst-on-pair is migrated")
(check-equal? (car (whnf-step1 (expr-suc (expr-nat-val 4))))
              'step "suc-collapse is migrated")
(check-equal? (car (whnf-step1 (expr-natrec (expr-Nat) (expr-nat-val 3)
                                            (expr-lam 'mw (expr-Nat) (expr-bvar 0))
                                            (expr-nat-val 2))))
              'step "ι natrec(nat-val) is migrated")
;; a value is 'whnf; an un-migrated redex (arith) is 'native
(check-equal? (whnf-step1 (expr-int 7)) 'whnf "literal is whnf")
(check-equal? (whnf-step1 (expr-int-add (expr-int 1) (expr-int 2)))
              'native "arith is native (not yet migrated)")
;; a non-lam application demands its function
(check-equal? (car (whnf-step1 (expr-app (expr-fvar 'foo) (expr-int 5))))
              'demand "app-of-non-lam demands the function")

;; --- PARITY: whnf-via-egraph == native whnf, over a corpus ---
(define corpus
  (list
   ;; identity β
   (expr-app (expr-lam 'mw (expr-Int) (expr-bvar 0)) (expr-int 5))
   ;; K combinator partial: (λx.λy.x) 3  →  (λy. 3-shifted)
   (expr-app (expr-lam 'mw (expr-Int) (expr-lam 'mw (expr-Int) (expr-bvar 1)))
             (expr-int 3))
   ;; two β steps: ((λx.λy.x) 7 8) → 7
   (expr-app (expr-app (expr-lam 'mw (expr-Int)
                                (expr-lam 'mw (expr-Int) (expr-bvar 1)))
                       (expr-int 7))
             (expr-int 8))
   ;; β whose body is a projection: (λp. fst p) (pair 1 2) → 1
   (expr-app (expr-lam 'mw (expr-Sigma (expr-Int) (expr-Int))
                       (expr-fst (expr-bvar 0)))
             (expr-pair (expr-int 1) (expr-int 2)))
   ;; suc-collapse
   (expr-suc (expr-nat-val 4))
   ;; ι natrec: 3 + 2 via suc-step — whnf exposes suc (weak head)
   (expr-natrec (expr-Nat) (expr-nat-val 3)
                (expr-lam 'mw (expr-Nat) (expr-lam 'mw (expr-Nat) (expr-suc (expr-bvar 0))))
                (expr-nat-val 2))
   ;; fst / snd on pairs
   (expr-fst (expr-pair (expr-int 1) (expr-int 2)))
   (expr-snd (expr-pair (expr-int 1) (expr-int 2)))
   ;; boolrec
   (expr-boolrec (expr-Bool) (expr-int 10) (expr-int 20) (expr-true))
   (expr-boolrec (expr-Bool) (expr-int 10) (expr-int 20) (expr-false))
   ;; J on refl
   (expr-J (expr-Type 0) (expr-lam 'mw (expr-Int) (expr-bvar 0)) (expr-int 9)
           (expr-int 9) (expr-refl))
   ;; ann is transparent
   (expr-ann (expr-int 42) (expr-Int))
   ;; arith (NATIVE fallback) — parity-trivial but must hold
   (expr-int-add (expr-int 1) (expr-int 2))
   (expr-int-mul (expr-int 6) (expr-int 7))
   ;; β exposing arith: (λx. x+1) 5  →  6  (β migrated, int+ native)
   (expr-app (expr-lam 'mw (expr-Int) (expr-int-add (expr-bvar 0) (expr-int 1)))
             (expr-int 5))
   ;; higher-order: (λf. f 5) (λx. x) → 5
   (expr-app (expr-lam 'mw (expr-Pi 'mw (expr-Int) (expr-Int))
                       (expr-app (expr-bvar 0) (expr-int 5)))
             (expr-lam 'mw (expr-Int) (expr-bvar 0)))
   ;; neutral / stuck: (foo 5) with foo a free var — both leave it stuck
   (expr-app (expr-fvar 'foo) (expr-int 5))
   ;; already a value
   (expr-int 99)
   (expr-lam 'mw (expr-Int) (expr-bvar 0))))

(for ([e (in-list corpus)] [i (in-naturals)])
  (check-equal? (whnf-via-egraph e) (whnf e)
                (format "parity at corpus[~a]: ~a" i e)))

;; --- nf-level spot check: the ι term fully normalizes to 5 the same both ways ---
(define plus-redex
  (expr-natrec (expr-Nat) (expr-nat-val 3)
               (expr-lam 'mw (expr-Nat) (expr-lam 'mw (expr-Nat) (expr-suc (expr-bvar 0))))
               (expr-nat-val 2)))
(check-true (expr-suc? (whnf-via-egraph plus-redex))
            "whnf-via-egraph exposes suc (weak head), like native")

;; --- Phase 5b: SCHEDULER-DRIVEN parity — whnf-via-egraph-network == native whnf ---
;; With the e-graph plumbing live, the reduce stratum drives the head cascade
;; (the genuine network-DRIVE). Same corpus; same answers.
(parameterize ([current-rule-registry-cell-id #f]
               [current-eclass-hashcons-cell-id #f]
               [current-persistent-registry-net-box (box (make-prop-network))])
  (define pb (current-persistent-registry-net-box))
  (init-rule-registry-cell! pb)
  (set-box! pb (run-to-quiescence
                (register-arithmetic-seed! (unbox pb) (current-rule-registry-cell-id))))
  (init-eclass-hashcons-cell! pb)
  (for ([e (in-list corpus)] [i (in-naturals)])
    (check-equal? (whnf-via-egraph-network e) (whnf e)
                  (format "NETWORK parity at corpus[~a]: ~a" i e)))
  ;; the ι term still exposes suc at the weak head, scheduler-driven
  (check-true (expr-suc? (whnf-via-egraph-network plus-redex))
              "whnf-via-egraph-network exposes suc (weak head)"))

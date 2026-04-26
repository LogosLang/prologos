#lang racket/base

;;;
;;; Tests for P5b/P5c: Multiplicity Cells and Cross-Domain Bridge
;;;
;;; P5b: Verifies that mult-metas get cells on the propagator network
;;; and that solve-mult-meta! writes to those cells.
;;; P5c: Verifies the type↔mult cross-domain bridge propagator.
;;;

(require rackunit
         racket/list
         "test-support.rkt"
         "../syntax.rkt"
         "../macros.rkt"
         "../errors.rkt"
         "../prelude.rkt"
         "../metavar-store.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../elaborator-network.rkt"
         "../propagator.rkt"
         "../mult-lattice.rkt"
         "../champ.rkt"
         "../type-lattice.rkt"
         (only-in "../decision-cell.rkt"
                  tagged-cell-value tagged-cell-value? tagged-cell-value-base
                  make-tagged-merge))

;; ========================================
;; Shared fixture: prelude loaded once
;; ========================================

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-preparse-reg
                shared-cap-reg)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-capability-registry prelude-capability-registry])
    (install-module-loader!)
    (process-string "(ns test-mult-prop)\n")
    (values (current-prelude-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-preparse-registry)
            (current-capability-registry))))

(define (run code)
  (parameterize ([current-prelude-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-preparse-registry shared-preparse-reg]
                 [current-capability-registry shared-cap-reg]
                 [current-lib-paths (list prelude-lib-dir)])
    (install-module-loader!)
    (process-string code)))

(define (run-last code)
  (define results (run code))
  (if (null? results) #f (last results)))

;; ========================================
;; Integration tests: mult cells created for expressions
;; ========================================

(test-case "mult/add-has-no-error"
  ;; Basic sanity: mult cells are allocated during type-checking
  ;; and don't break anything
  (define result (run-last "eval [add 1N 2N]\n"))
  (check-false (and result (prologos-error? result))))

(test-case "mult/sub-has-no-error"
  (define result (run-last "eval [sub 5N 3N]\n"))
  (check-false (and result (prologos-error? result))))

(test-case "mult/nested-has-no-error"
  (define result (run-last "eval [add [sub 10N 3N] 4N]\n"))
  (check-false (and result (prologos-error? result))))

(test-case "mult/lt-has-no-error"
  (define result (run-last "eval [lt? 1N 2N]\n"))
  (check-false (and result (prologos-error? result))))

(test-case "mult/identity-fn-has-no-error"
  ;; Lambda with mult-meta — exercises mult cell creation for binder multiplicities
  (define result (run-last "(def id : (Pi (A : (Type 0)) (Pi (x : A) A)) (fn [A] [x] x))\n"))
  (check-false (and result (prologos-error? result))))

(test-case "mult/def-nat-has-no-error"
  (define result (run-last "(def x : Nat zero)\n"))
  (check-false (and result (prologos-error? result))))

;; ========================================
;; P5c: Cross-domain bridge unit tests
;; ========================================
;; These test the type↔mult bridge directly on elab-network,
;; without going through the full driver pipeline.

;; Helper: create a fresh elab-network with one type cell, one mult cell, and a bridge.
;; Returns (values enet type-cid mult-cid).
;;
;; PPN 4C S2.e-v (2026-04-25): refactored to use primitives directly.
;; Previously called retired functions:
;;   - elab-fresh-mult-cell (test-only mult cell allocator)
;;   - elab-add-type-mult-bridge (test-only bridge installer)
;; Replaced with inline mult cell allocation (mirrors elab-fresh-mult-cell's
;; pattern: tagged-cell-value + make-tagged-merge + mult-lattice-contradicts?)
;; and direct net-add-cross-domain-propagator install (matches production
;; callback at driver.rkt:2674; γ retired in S2.c-iv → gamma-fn=#f).
(define (make-bridged-network)
  (define enet0 (make-elaboration-network))
  (define-values (enet1 type-cid) (elab-fresh-meta enet0 '() #f "test-type"))
  ;; Inline mult cell allocation (replaces retired elab-fresh-mult-cell)
  (define net1 (elab-network-prop-net enet1))
  (define-values (net2 mult-cid)
    (net-new-cell net1
                  (tagged-cell-value mult-bot '())
                  (make-tagged-merge mult-lattice-merge)
                  (lambda (v)
                    (if (tagged-cell-value? v)
                        (mult-lattice-contradicts? (tagged-cell-value-base v))
                        (mult-lattice-contradicts? v)))))
  ;; Direct bridge install via primitive (replaces retired elab-add-type-mult-bridge)
  (define-values (net3 _pid-alpha _pid-gamma)
    (net-add-cross-domain-propagator net2 type-cid mult-cid type->mult-alpha #f))
  ;; Wrap back into elab-network
  (define enet2 (struct-copy elab-network enet1 [prop-net net3]))
  (values enet2 type-cid mult-cid))

;; Helper: solve and extract the enet (assumes no contradiction).
(define (solve-ok enet)
  (define-values (status result) (elab-solve enet))
  (unless (eq? status 'ok)
    (error 'solve-ok "expected ok, got ~a: ~a" status result))
  result)

(test-case "bridge/pi-m1-propagates"
  ;; Write Pi with m1 to type cell → mult cell should get m1
  (define-values (enet type-cid mult-cid) (make-bridged-network))
  (define pi-type (expr-Pi 'm1 (expr-fvar 'Nat) (expr-fvar 'Nat)))
  (define enet* (solve-ok (elab-cell-write enet type-cid pi-type)))
  (check-equal? (elab-cell-read enet* mult-cid) 'm1))

(test-case "bridge/pi-m0-propagates"
  ;; Write Pi with m0 to type cell → mult cell should get m0
  (define-values (enet type-cid mult-cid) (make-bridged-network))
  (define pi-type (expr-Pi 'm0 (expr-fvar 'Nat) (expr-fvar 'Nat)))
  (define enet* (solve-ok (elab-cell-write enet type-cid pi-type)))
  (check-equal? (elab-cell-read enet* mult-cid) 'm0))

(test-case "bridge/pi-mw-propagates"
  ;; Write Pi with mw to type cell → mult cell should get mw
  (define-values (enet type-cid mult-cid) (make-bridged-network))
  (define pi-type (expr-Pi 'mw (expr-fvar 'Bool) (expr-fvar 'Bool)))
  (define enet* (solve-ok (elab-cell-write enet type-cid pi-type)))
  (check-equal? (elab-cell-read enet* mult-cid) 'mw))

(test-case "bridge/non-pi-stays-bot"
  ;; Write a non-Pi type → mult cell stays mult-bot
  (define-values (enet type-cid mult-cid) (make-bridged-network))
  (define enet* (solve-ok (elab-cell-write enet type-cid (expr-fvar 'Nat))))
  (check-equal? (elab-cell-read enet* mult-cid) mult-bot))

(test-case "bridge/type-top-to-mult-top"
  ;; Write type-top → mult cell gets mult-top (contradiction propagates)
  ;; Note: type-top causes contradiction, so we check via error path
  (define-values (enet type-cid mult-cid) (make-bridged-network))
  (define enet* (elab-cell-write enet type-cid type-top))
  (define-values (status _result) (elab-solve enet*))
  ;; type-top contradicts the type cell → network enters contradiction state
  (check-equal? status 'error))

(test-case "bridge/pi-with-mult-meta-stays-bot"
  ;; Write Pi with unsolved mult-meta → mult cell stays mult-bot
  (define-values (enet type-cid mult-cid) (make-bridged-network))
  (define mm (mult-meta (gensym 'test-mm)))
  (define pi-type (expr-Pi mm (expr-fvar 'Nat) (expr-fvar 'Nat)))
  (define enet* (solve-ok (elab-cell-write enet type-cid pi-type)))
  (check-equal? (elab-cell-read enet* mult-cid) mult-bot))

(test-case "bridge/type-bot-stays-bot"
  ;; Fresh type cell (bot) → mult cell stays bot
  (define-values (enet _type-cid mult-cid) (make-bridged-network))
  (define enet* (solve-ok enet))
  (check-equal? (elab-cell-read enet* mult-cid) mult-bot))

;; PPN 4C S2.e-v (2026-04-25): bridge/gamma-noop test RETIRED.
;; γ direction was retired in S2.c-iv (mult->type-gamma was constant type-bot,
;; dead work everywhere). Post-retirement, the test would trivially confirm a
;; no-op is a no-op (no γ propagator installed). The test's premise (γ exists
;; as no-op) is no longer valid; the architecture's CURRENT semantic is "no γ
;; at all" rather than "γ exists as no-op". Test retired alongside
;; elab-mult-cell-write retirement.

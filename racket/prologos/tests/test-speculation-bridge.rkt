#lang racket/base

;;;
;;; test-speculation-bridge.rkt — Tests for the speculation bridge
;;;
;;; Tests always-on network, speculative rollback, union type speculation,
;;; map widening speculation, QTT union speculation, and full pipeline integration.
;;;
;;; Phase 5 of the type inference refactoring.
;;;

(require racket/list
         racket/port
         rackunit
         rackunit/text-ui
         "test-support.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../type-lattice.rkt"
         "../propagator.rkt"
         "../elaborator-network.rkt"
         "../elab-shadow.rkt"
         "../elab-speculation-bridge.rkt"
         "../metavar-store.rkt"
         "../driver.rkt"
         "../global-env.rkt"
         "../errors.rkt")

;; ========================================
;; Test Helpers
;; ========================================

;; Run a command through the driver (no prelude), suppress stderr.
(define (run-simple s)
  (parameterize ([current-global-env (hasheq)]
                 [current-error-port (open-output-nowhere)])
    (process-string s)))

;; Run with prelude (via test-support), suppress stderr.
(define (run-ns s)
  (parameterize ([current-error-port (open-output-nowhere)])
    (run-ns-last s)))

;; ========================================
;; Suite 1: Always-On Network
;; ========================================

(define always-on-tests
  (test-suite
   "Always-on network"

   (test-case "simple def — shadow always runs"
     (define result (run-simple "(def x : Nat 0N)"))
     (check-equal? (last result) "x : Nat defined."))

   (test-case "type error — shadow still runs, teardown happens"
     (define result (run-simple "(def x : Nat true)"))
     ;; Should produce a type error
     (check-true (prologos-error? (last result))))

   (test-case "implicit args with prelude — metas mirrored"
     (define result (run-ns "(ns test) (def x : Nat [add 1N 2N])"))
     (check-false (prologos-error? result)))))

;; ========================================
;; Suite 2: Speculative Rollback
;; ========================================

(define rollback-tests
  (test-suite
   "Speculative rollback"

   (test-case "success — keeps meta-state and network"
     (parameterize ([current-meta-store (make-hash)]
                    [current-shadow-fresh-hook #f]
                    [current-shadow-solve-hook #f]
                    [current-shadow-constraint-hook #f]
                    [current-shadow-network #f]
                    [current-shadow-id-map #f]
                    [current-speculation-failures #f])
       (shadow-init!)
       (init-speculation-tracking!)
       ;; Create a meta and solve it inside speculation
       (define m (fresh-meta '() (expr-Nat) "test"))
       (define id (expr-meta-id m))
       (define result
         (with-speculative-rollback
           (lambda ()
             (solve-meta! id (expr-Bool))
             #t)
           values
           "test-success"))
       (check-equal? result #t)
       ;; Meta should be solved (kept)
       (check-true (meta-solved? id))
       (check-equal? (meta-solution id) (expr-Bool))
       ;; No failures recorded
       (check-equal? (get-speculation-failures) '())
       (shadow-teardown!)))

   (test-case "failure — restores meta-state and network"
     (parameterize ([current-meta-store (make-hash)]
                    [current-shadow-fresh-hook #f]
                    [current-shadow-solve-hook #f]
                    [current-shadow-constraint-hook #f]
                    [current-shadow-network #f]
                    [current-shadow-id-map #f]
                    [current-speculation-failures #f])
       (shadow-init!)
       (init-speculation-tracking!)
       ;; Create a meta
       (define m (fresh-meta '() (expr-Nat) "test"))
       (define id (expr-meta-id m))
       ;; Solve it inside a failing speculation
       (define result
         (with-speculative-rollback
           (lambda ()
             (solve-meta! id (expr-Bool))
             #f)  ;; returns #f → failure
           values
           "test-failure"))
       (check-false result)
       ;; Meta should be UNSOLVED (restored)
       (check-false (meta-solved? id))
       ;; One failure recorded
       (define failures (get-speculation-failures))
       (check-equal? (length failures) 1)
       (check-equal? (speculation-failure-label (car failures)) "test-failure")
       (shadow-teardown!)))

   (test-case "network fork/restore precision"
     (parameterize ([current-meta-store (make-hash)]
                    [current-shadow-fresh-hook #f]
                    [current-shadow-solve-hook #f]
                    [current-shadow-constraint-hook #f]
                    [current-shadow-network #f]
                    [current-shadow-id-map #f]
                    [current-speculation-failures #f])
       (shadow-init!)
       (init-speculation-tracking!)
       ;; Create a meta
       (define m (fresh-meta '() (expr-Nat) "test"))
       (define id (expr-meta-id m))
       (define cid (hash-ref (current-shadow-id-map) id))
       ;; Solve inside failing speculation
       (with-speculative-rollback
         (lambda ()
           (solve-meta! id (expr-Bool))
           #f)
         values
         "network-test")
       ;; Shadow network cell should be at bot (restored to fork point)
       (define enet (unbox (current-shadow-network)))
       (check-true (type-bot? (elab-cell-read enet cid)))
       (shadow-teardown!)))

   (test-case "multiple failures accumulate"
     (parameterize ([current-meta-store (make-hash)]
                    [current-shadow-fresh-hook #f]
                    [current-shadow-solve-hook #f]
                    [current-shadow-constraint-hook #f]
                    [current-shadow-network #f]
                    [current-shadow-id-map #f]
                    [current-speculation-failures #f])
       (shadow-init!)
       (init-speculation-tracking!)
       (with-speculative-rollback (lambda () #f) values "fail-1")
       (with-speculative-rollback (lambda () #f) values "fail-2")
       (with-speculative-rollback (lambda () #t) values "success")
       (define failures (get-speculation-failures))
       (check-equal? (length failures) 2)
       (check-equal? (speculation-failure-label (car failures)) "fail-1")
       (check-equal? (speculation-failure-label (cadr failures)) "fail-2")
       (shadow-teardown!)))))

;; ========================================
;; Suite 3: Union Type Speculation (Integration)
;; ========================================

(define union-tests
  (test-suite
   "Union type speculation"

   (test-case "check e : (A | B) where left succeeds"
     (define result (run-ns "(ns test) (def x <Nat | Bool> 42N)"))
     (check-false (prologos-error? result)))

   (test-case "check e : (A | B) where left fails, right succeeds"
     (define result (run-ns "(ns test) (def x <Nat | Bool> true)"))
     (check-false (prologos-error? result)))

   (test-case "check e : (A | B) both fail"
     ;; Use a type that doesn't match either Nat or Bool
     (define result
       (run-simple "(def f : <(x : Nat) -> Nat> (fn [x] x)) (check [f true] <Nat | Bool>)"))
     ;; Should error (Bool doesn't check against Nat in the fn)
     (check-true (prologos-error? (last result))))

   (test-case "nested union (A | B) | C"
     (define result (run-ns "(ns test) (def x <<Nat | Bool> | (List Nat)> true)"))
     (check-false (prologos-error? result)))))

;; ========================================
;; Suite 4: Map Widening Speculation (Integration)
;; ========================================

(define map-widening-tests
  (test-suite
   "Map widening speculation"

   (test-case "map assoc where value fits — no widening"
     (define result (run-ns "(ns test) (eval (the (Map Keyword Nat) {:a 1N :b 2N}))"))
     (check-false (prologos-error? result)))

   (test-case "map assoc where value doesn't fit — widen to union"
     (define result (run-ns "(ns test) (eval (the (Map Keyword <Nat | Bool>) {:a 1N :b true}))"))
     (check-false (prologos-error? result)))))

;; ========================================
;; Suite 5: QTT Union Speculation (Integration)
;; ========================================

(define qtt-tests
  (test-suite
   "QTT union speculation"

   (test-case "checkQ e : (A | B) left succeeds"
     ;; QTT runs on zonked terms after type-check; union speculation happens during checkQ
     (define result (run-ns "(ns test) (def x <Nat | Bool> 42N)"))
     (check-false (prologos-error? result)))

   (test-case "checkQ e : (A | B) left fails, right succeeds"
     (define result (run-ns "(ns test) (def x <Nat | Bool> true)"))
     (check-false (prologos-error? result)))))

;; ========================================
;; Suite 6: Full Pipeline Integration
;; ========================================

(define pipeline-tests
  (test-suite
   "Full pipeline integration"

   (test-case "program with union types compiles with always-on network"
     (define result
       (run-ns
        (string-append
         "(ns test)\n"
         "(def id : <{A : Type} (x : A) -> A> (fn [x] x))\n"
         "(def y <Nat | Bool> [id 42N])\n")))
     (check-false (prologos-error? result)))

   (test-case "program with multiple defs compiles"
     (define result
       (run-ns
        (string-append
         "(ns test)\n"
         "(def a : Nat 1N)\n"
         "(def b : Bool true)\n"
         "(def c <Nat | Bool> 2N)\n")))
     (check-false (prologos-error? result)))))

;; ========================================
;; Run all suites
;; ========================================

(run-tests always-on-tests)
(run-tests rollback-tests)
(run-tests union-tests)
(run-tests map-widening-tests)
(run-tests qtt-tests)
(run-tests pipeline-tests)

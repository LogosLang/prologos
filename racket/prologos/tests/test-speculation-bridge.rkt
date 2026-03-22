#lang racket/base

;;;
;;; test-speculation-bridge.rkt — Tests for the speculation bridge
;;;
;;; Tests speculative rollback, union type speculation,
;;; map widening speculation, QTT union speculation, and full pipeline integration.
;;;
;;; Phase 5+8c of the type inference refactoring.
;;;

(require racket/list
         racket/port
         racket/string
         rackunit
         rackunit/text-ui
         "test-support.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
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
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
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

   (test-case "simple def — propagator network active"
     (define result (run-simple "(def x : Nat 0N)"))
     (check-equal? (last result) "x : Nat defined."))

   (test-case "type error — network still runs, cleanup happens"
     (define result (run-simple "(def x : Nat true)"))
     ;; Should produce a type error
     (check-true (prologos-error? (last result))))

   (test-case "implicit args with prelude — metas on network"
     (define result (run-ns "(ns test) (def x : Nat [add 1N 2N])"))
     (check-false (prologos-error? result)))))

;; ========================================
;; Suite 2: Speculative Rollback
;; ========================================

(define rollback-tests
  (test-suite
   "Speculative rollback"

   (test-case "success — keeps meta-state"
     (with-fresh-meta-env
       (parameterize ([current-speculation-failures #f])
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
         (check-equal? (get-speculation-failures) '()))))

   (test-case "failure — restores meta-state"
     (with-fresh-meta-env
       (parameterize ([current-speculation-failures #f])
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
         (check-equal? (speculation-failure-label (car failures)) "test-failure"))))

   (test-case "network rollback — cell value restored"
     (with-fresh-meta-env
       (parameterize ([current-speculation-failures #f])
         (init-speculation-tracking!)
         ;; Create a meta
         (define m (fresh-meta '() (expr-Nat) "test"))
         (define id (expr-meta-id m))
         ;; Solve inside failing speculation
         (with-speculative-rollback
           (lambda ()
             (solve-meta! id (expr-Bool))
             #f)
           values
           "network-test")
         ;; Meta should be unsolved (network state restored)
         (check-false (meta-solved? id))
         (check-false (meta-solution id)))))

   (test-case "multiple failures accumulate"
     (with-fresh-meta-env
       (parameterize ([current-speculation-failures #f])
         (init-speculation-tracking!)
         (with-speculative-rollback (lambda () #f) values "fail-1")
         (with-speculative-rollback (lambda () #f) values "fail-2")
         (with-speculative-rollback (lambda () #t) values "success")
         (define failures (get-speculation-failures))
         (check-equal? (length failures) 2)
         (check-equal? (speculation-failure-label (car failures)) "fail-1")
         (check-equal? (speculation-failure-label (cadr failures)) "fail-2"))))))

;; ========================================
;; Suite 2b: Constraint Store Isolation (Phase 4b)
;; ========================================

(define constraint-isolation-tests
  (test-suite
   "Constraint store isolation (Phase 4b)"

   (test-case "failed speculation restores constraint store"
     (with-fresh-meta-env
       (parameterize ([current-speculation-failures #f])
         (init-speculation-tracking!)
         ;; Pre-speculation: empty constraint store
         (check-equal? (read-constraint-store) '())
         ;; Speculation that adds a constraint then fails
         (define m (fresh-meta '() (expr-Nat) "cstore-test"))
         (define result
           (with-speculative-rollback
             (lambda ()
               ;; Manually add a constraint (simulates unify → pattern-check failure)
               (add-constraint! (expr-meta (expr-meta-id m))
                                (expr-Bool)
                                '()
                                #f)
               ;; Verify constraint was added during speculation
               (check-equal? (length (read-constraint-store)) 1)
               #f)  ;; fail
             values
             "constraint-leak-test"))
         (check-false result)
         ;; Track 8 B1: worldview-aware reads handle CHAMP entries (meta-info, id-map).
         ;; Scoped infrastructure cells (constraint store) still need S(-1) for cleanup.
         ;; Run S(-1) to clean tagged constraint entries.
         (run-retraction-stratum!)
         ;; Phase 4b: constraint store should be clean after S(-1)
         (check-equal? (read-constraint-store) '()
                       "constraint store leaked after failed speculation"))))

   (test-case "successful speculation keeps constraints"
     (with-fresh-meta-env
       (parameterize ([current-speculation-failures #f])
         (init-speculation-tracking!)
         (check-equal? (read-constraint-store) '())
         (define m (fresh-meta '() (expr-Nat) "cstore-keep"))
         (define result
           (with-speculative-rollback
             (lambda ()
               (add-constraint! (expr-meta (expr-meta-id m))
                                (expr-Bool)
                                '()
                                #f)
               #t)  ;; success
             values
             "constraint-keep-test"))
         (check-true result)
         ;; Constraints should be KEPT on success
         (check-equal? (length (read-constraint-store)) 1))))

   (test-case "nested speculation — inner failure restores, outer keeps"
     (with-fresh-meta-env
       (parameterize ([current-speculation-failures #f])
         (init-speculation-tracking!)
         (check-equal? (read-constraint-store) '())
         (define m1 (fresh-meta '() (expr-Nat) "outer"))
         (define m2 (fresh-meta '() (expr-Nat) "inner"))
         (define result
           (with-speculative-rollback
             (lambda ()
               ;; Outer adds a constraint
               (add-constraint! (expr-meta (expr-meta-id m1))
                                (expr-Bool) '() #f)
               (check-equal? (length (read-constraint-store)) 1)
               ;; Inner speculation adds another then fails
               (with-speculative-rollback
                 (lambda ()
                   (add-constraint! (expr-meta (expr-meta-id m2))
                                    (expr-Nat) '() #f)
                   (check-equal? (length (read-constraint-store)) 2)
                   #f)  ;; inner fails
                 values
                 "inner-fail")
               ;; Track 8 B1: run S(-1) for scoped cell cleanup
               (run-retraction-stratum!)
               ;; After inner failure + S(-1): only outer constraint remains
               (check-equal? (length (read-constraint-store)) 1)
               #t)  ;; outer succeeds
             values
             "outer-success"))
         (check-true result)
         ;; Outer constraint kept, inner constraint restored
         (check-equal? (length (read-constraint-store)) 1))))))

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

   (test-case "program with union types compiles with propagator network"
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
;; Suite 7: Error Improvement (Phase 6)
;; ========================================

(define error-improvement-tests
  (test-suite
   "Error improvement"

   (test-case "union exhaustion error — simple (A | B)"
     (define result (run-simple "(def x <Nat | Bool> \"hello\")"))
     (check-true (union-exhaustion-error? (last result)))
     (define err (last result))
     (check-equal? (length (union-exhaustion-error-branches err)) 2)
     (define formatted (format-error err))
     (check-true (string-contains? formatted "E1006"))
     (check-true (string-contains? formatted "tried")))

   (test-case "union exhaustion error — nested (A | B | C)"
     (define result (run-ns "(ns test) (def x <<Nat | Bool> | (List Nat)> \"hello\")"))
     (check-true (union-exhaustion-error? result))
     ;; 3 branches after flattening
     (check-equal? (length (union-exhaustion-error-branches result)) 3))

   (test-case "non-union mismatch still produces type-mismatch-error"
     (define result (run-simple "(def x : Nat true)"))
     (check-true (type-mismatch-error? (last result))))

   (test-case "union success — no error produced"
     (define result (run-ns "(ns test) (def x <Nat | Bool> 42N)"))
     (check-false (prologos-error? result)))

   (test-case "formatted error includes branch details"
     (define result (run-simple "(def x <Nat | Bool> \"hello\")"))
     (define formatted (format-error (last result)))
     (check-true (string-contains? formatted "Nat"))
     (check-true (string-contains? formatted "Bool"))
     (check-true (string-contains? formatted "help")))

   ;; Phase 7a: per-branch re-checking tests

   (test-case "per-branch re-checking — no 'matched' for fully-failing union"
     ;; "hello" doesn't match Nat or Bool — both branches should fail, none "matched"
     (define result (run-simple "(def x <Nat | Bool> \"hello\")"))
     (check-true (union-exhaustion-error? (last result)))
     (define mismatches (union-exhaustion-error-branch-mismatches (last result)))
     (for ([mm (in-list mismatches)])
       (check-false (string=? mm "matched"))))

   (test-case "per-branch re-checking — each branch reports actual type"
     ;; "hello" has type String; each branch should report it
     (define result (run-simple "(def x <Nat | Bool> \"hello\")"))
     (check-true (union-exhaustion-error? (last result)))
     (define mismatches (union-exhaustion-error-branch-mismatches (last result)))
     ;; Both branches should mention String
     (for ([mm (in-list mismatches)])
       (check-true (string-contains? mm "String"))))))

;; ========================================
;; Run all suites
;; ========================================

(run-tests always-on-tests)
(run-tests rollback-tests)
(run-tests constraint-isolation-tests)
(run-tests union-tests)
(run-tests map-widening-tests)
(run-tests qtt-tests)
(run-tests pipeline-tests)
(run-tests error-improvement-tests)

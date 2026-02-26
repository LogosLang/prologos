#lang racket/base

;;;
;;; test-elab-shadow.rkt — Tests for the shadow propagator network
;;;
;;; Tests hook installation, meta mirroring, constraint mirroring,
;;; shadow validation, and integration with the driver pipeline.
;;;
;;; Phase 3 of the type inference refactoring.
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
         "../metavar-store.rkt"
         "../driver.rkt"
         "../global-env.rkt"
         "../errors.rkt")

;; ========================================
;; Suite 1: Hook Installation
;; ========================================

(define hook-tests
  (test-suite
   "Hook installation"

   (test-case "hooks are #f by default"
     (check-false (current-shadow-fresh-hook))
     (check-false (current-shadow-solve-hook))
     (check-false (current-shadow-constraint-hook)))

   (test-case "shadow-init! installs hooks"
     (parameterize ([current-shadow-fresh-hook #f]
                    [current-shadow-solve-hook #f]
                    [current-shadow-constraint-hook #f]
                    [current-shadow-network #f]
                    [current-shadow-id-map #f])
       (shadow-init!)
       (check-true (procedure? (current-shadow-fresh-hook)))
       (check-true (procedure? (current-shadow-solve-hook)))
       (check-true (procedure? (current-shadow-constraint-hook)))
       (check-true (box? (current-shadow-network)))
       (check-true (hash? (current-shadow-id-map)))
       (shadow-teardown!)))

   (test-case "shadow-teardown! uninstalls hooks"
     (parameterize ([current-shadow-fresh-hook #f]
                    [current-shadow-solve-hook #f]
                    [current-shadow-constraint-hook #f]
                    [current-shadow-network #f]
                    [current-shadow-id-map #f])
       (shadow-init!)
       (shadow-teardown!)
       (check-false (current-shadow-fresh-hook))
       (check-false (current-shadow-solve-hook))
       (check-false (current-shadow-constraint-hook))
       (check-false (current-shadow-network))
       (check-false (current-shadow-id-map))))))

;; ========================================
;; Suite 2: Meta Mirroring
;; ========================================

(define mirroring-tests
  (test-suite
   "Meta mirroring"

   (test-case "fresh-meta mirrors to shadow cell at type-bot"
     (parameterize ([current-meta-store (make-hasheq)]
                    [current-shadow-fresh-hook #f]
                    [current-shadow-solve-hook #f]
                    [current-shadow-constraint-hook #f]
                    [current-shadow-network #f]
                    [current-shadow-id-map #f])
       (shadow-init!)
       (define m (fresh-meta '() (expr-Type (lzero)) "test"))
       (define id (expr-meta-id m))
       ;; Check shadow has a cell for this meta
       (define cid (hash-ref (current-shadow-id-map) id #f))
       (check-true (cell-id? cid))
       ;; Shadow cell should be at type-bot (unsolved)
       (define enet (unbox (current-shadow-network)))
       (check-true (type-bot? (elab-cell-read enet cid)))
       (shadow-teardown!)))

   (test-case "solve-meta! writes solution to shadow cell"
     (parameterize ([current-meta-store (make-hasheq)]
                    [current-constraint-store '()]
                    [current-wakeup-registry (make-hasheq)]
                    [current-retry-unify #f]
                    [current-shadow-fresh-hook #f]
                    [current-shadow-solve-hook #f]
                    [current-shadow-constraint-hook #f]
                    [current-shadow-network #f]
                    [current-shadow-id-map #f])
       (shadow-init!)
       (define m (fresh-meta '() (expr-Type (lzero)) "test"))
       (define id (expr-meta-id m))
       (solve-meta! id (expr-Nat))
       ;; Shadow cell should now have Nat
       (define cid (hash-ref (current-shadow-id-map) id))
       (define enet (unbox (current-shadow-network)))
       (check-equal? (elab-cell-read enet cid) (expr-Nat))
       (shadow-teardown!)))

   (test-case "multiple metas all mirrored"
     (parameterize ([current-meta-store (make-hasheq)]
                    [current-shadow-fresh-hook #f]
                    [current-shadow-solve-hook #f]
                    [current-shadow-constraint-hook #f]
                    [current-shadow-network #f]
                    [current-shadow-id-map #f])
       (shadow-init!)
       (define m1 (fresh-meta '() (expr-Type (lzero)) "test1"))
       (define m2 (fresh-meta '() (expr-Type (lzero)) "test2"))
       (define m3 (fresh-meta '() (expr-Type (lzero)) "test3"))
       ;; All three should have shadow cells
       (check-equal? (hash-count (current-shadow-id-map)) 3)
       (shadow-teardown!)))

   (test-case "solved meta with ground type matches shadow"
     (parameterize ([current-meta-store (make-hasheq)]
                    [current-constraint-store '()]
                    [current-wakeup-registry (make-hasheq)]
                    [current-retry-unify #f]
                    [current-shadow-fresh-hook #f]
                    [current-shadow-solve-hook #f]
                    [current-shadow-constraint-hook #f]
                    [current-shadow-network #f]
                    [current-shadow-id-map #f])
       (shadow-init!)
       (define m (fresh-meta '() (expr-Type (lzero)) "test"))
       (define id (expr-meta-id m))
       (solve-meta! id (expr-Bool))
       ;; Validate: should report ok
       (define report (shadow-validate!))
       (check-true (shadow-report-ok? report))
       (check-equal? (shadow-report-total-metas report) 1)
       (check-equal? (shadow-report-total-solved report) 1)
       (check-equal? (shadow-report-contradictions report) 0)
       (shadow-teardown!)))))

;; ========================================
;; Suite 3: Constraint Mirroring
;; ========================================

(define constraint-tests
  (test-suite
   "Constraint mirroring"

   (test-case "constraint between two metas adds propagator"
     (parameterize ([current-meta-store (make-hasheq)]
                    [current-constraint-store '()]
                    [current-wakeup-registry (make-hasheq)]
                    [current-retry-unify #f]
                    [current-shadow-fresh-hook #f]
                    [current-shadow-solve-hook #f]
                    [current-shadow-constraint-hook #f]
                    [current-shadow-network #f]
                    [current-shadow-id-map #f])
       (shadow-init!)
       (define m1 (fresh-meta '() (expr-Type (lzero)) "test1"))
       (define m2 (fresh-meta '() (expr-Type (lzero)) "test2"))
       ;; Add constraint between the two metas
       (add-constraint! m1 m2 '() "test-constraint")
       ;; Solve m1 to Nat
       (solve-meta! (expr-meta-id m1) (expr-Nat))
       ;; Shadow should propagate Nat to m2's cell via the unify propagator
       (define report (shadow-validate!))
       (check-true (shadow-report-ok? report))
       (shadow-teardown!)))

   (test-case "no crash when constraint references unknown metas"
     (parameterize ([current-meta-store (make-hasheq)]
                    [current-constraint-store '()]
                    [current-wakeup-registry (make-hasheq)]
                    [current-retry-unify #f]
                    [current-shadow-fresh-hook #f]
                    [current-shadow-solve-hook #f]
                    [current-shadow-constraint-hook #f]
                    [current-shadow-network #f]
                    [current-shadow-id-map #f])
       (shadow-init!)
       ;; Constraint with an unknown meta (not created via fresh-meta)
       (define fake-meta (expr-meta (gensym 'fake)))
       (define m (fresh-meta '() (expr-Type (lzero)) "real"))
       ;; This should not crash — unknown metas are skipped
       (add-constraint! fake-meta m '() "test-safe")
       (shadow-teardown!)))

   (test-case "constraint with nested meta expressions"
     (parameterize ([current-meta-store (make-hasheq)]
                    [current-constraint-store '()]
                    [current-wakeup-registry (make-hasheq)]
                    [current-retry-unify #f]
                    [current-shadow-fresh-hook #f]
                    [current-shadow-solve-hook #f]
                    [current-shadow-constraint-hook #f]
                    [current-shadow-network #f]
                    [current-shadow-id-map #f])
       (shadow-init!)
       (define m1 (fresh-meta '() (expr-Type (lzero)) "test1"))
       (define m2 (fresh-meta '() (expr-Type (lzero)) "test2"))
       ;; Constraint with metas nested inside app expressions
       (add-constraint! (expr-app (expr-fvar 'List) m1)
                        (expr-app (expr-fvar 'List) m2)
                        '() "nested-constraint")
       ;; Should add propagator between m1 and m2 cells
       (define report (shadow-validate!))
       (check-true (shadow-report-ok? report))
       (shadow-teardown!)))))

;; ========================================
;; Suite 4: Validation
;; ========================================

(define validation-tests
  (test-suite
   "Shadow validation"

   (test-case "all-ground solved metas report ok"
     (parameterize ([current-meta-store (make-hasheq)]
                    [current-constraint-store '()]
                    [current-wakeup-registry (make-hasheq)]
                    [current-retry-unify #f]
                    [current-shadow-fresh-hook #f]
                    [current-shadow-solve-hook #f]
                    [current-shadow-constraint-hook #f]
                    [current-shadow-network #f]
                    [current-shadow-id-map #f])
       (shadow-init!)
       (define m1 (fresh-meta '() (expr-Type (lzero)) "t1"))
       (define m2 (fresh-meta '() (expr-Type (lzero)) "t2"))
       (solve-meta! (expr-meta-id m1) (expr-Nat))
       (solve-meta! (expr-meta-id m2) (expr-Bool))
       (define report (shadow-validate!))
       (check-true (shadow-report-ok? report))
       (check-equal? (shadow-report-total-metas report) 2)
       (check-equal? (shadow-report-total-solved report) 2)
       (shadow-teardown!)))

   (test-case "contradictory solutions detected"
     (parameterize ([current-meta-store (make-hasheq)]
                    [current-constraint-store '()]
                    [current-wakeup-registry (make-hasheq)]
                    [current-retry-unify #f]
                    [current-shadow-fresh-hook #f]
                    [current-shadow-solve-hook #f]
                    [current-shadow-constraint-hook #f]
                    [current-shadow-network #f]
                    [current-shadow-id-map #f])
       (shadow-init!)
       (define m1 (fresh-meta '() (expr-Type (lzero)) "t1"))
       (define m2 (fresh-meta '() (expr-Type (lzero)) "t2"))
       ;; Add constraint linking m1 and m2
       (add-constraint! m1 m2 '() "link")
       ;; Solve m1 to Nat
       (solve-meta! (expr-meta-id m1) (expr-Nat))
       ;; Now force m2's shadow cell to Bool (contradiction)
       ;; We do this by directly writing to the shadow cell
       (define cid2 (hash-ref (current-shadow-id-map) (expr-meta-id m2)))
       (define enet (unbox (current-shadow-network)))
       (set-box! (current-shadow-network) (elab-cell-write enet cid2 (expr-Bool)))
       (define report (shadow-validate!))
       ;; Should detect contradiction (Nat vs Bool on same cell)
       (check-false (shadow-report-ok? report))
       (shadow-teardown!)))

   (test-case "consistent chain: 3 metas solved to same type"
     (parameterize ([current-meta-store (make-hasheq)]
                    [current-constraint-store '()]
                    [current-wakeup-registry (make-hasheq)]
                    [current-retry-unify #f]
                    [current-shadow-fresh-hook #f]
                    [current-shadow-solve-hook #f]
                    [current-shadow-constraint-hook #f]
                    [current-shadow-network #f]
                    [current-shadow-id-map #f])
       (shadow-init!)
       (define m1 (fresh-meta '() (expr-Type (lzero)) "t1"))
       (define m2 (fresh-meta '() (expr-Type (lzero)) "t2"))
       (define m3 (fresh-meta '() (expr-Type (lzero)) "t3"))
       (solve-meta! (expr-meta-id m1) (expr-Nat))
       (solve-meta! (expr-meta-id m2) (expr-Nat))
       (solve-meta! (expr-meta-id m3) (expr-Nat))
       (define report (shadow-validate!))
       (check-true (shadow-report-ok? report))
       (check-equal? (shadow-report-total-solved report) 3)
       (shadow-teardown!)))

   (test-case "unsolved metas are not errors"
     (parameterize ([current-meta-store (make-hasheq)]
                    [current-constraint-store '()]
                    [current-wakeup-registry (make-hasheq)]
                    [current-retry-unify #f]
                    [current-shadow-fresh-hook #f]
                    [current-shadow-solve-hook #f]
                    [current-shadow-constraint-hook #f]
                    [current-shadow-network #f]
                    [current-shadow-id-map #f])
       (shadow-init!)
       (define m1 (fresh-meta '() (expr-Type (lzero)) "t1"))
       (define m2 (fresh-meta '() (expr-Type (lzero)) "t2"))
       ;; Only solve m1, leave m2 unsolved
       (solve-meta! (expr-meta-id m1) (expr-Nat))
       (define report (shadow-validate!))
       (check-true (shadow-report-ok? report))
       (check-equal? (shadow-report-total-metas report) 2)
       (check-equal? (shadow-report-total-solved report) 1)
       (shadow-teardown!)))))

;; ========================================
;; Suite 5: Driver Integration
;; ========================================

;; Helper: run without prelude (simple sexp mode).
;; Phase 5: network is always-on; suppress validation logging in tests.
(define (run-shadow-simple s)
  (parameterize ([current-global-env (hasheq)]
                 [current-error-port (open-output-nowhere)])
    (process-string s)))

;; Helper: run with prelude (via test-support), suppress validation logging.
(define (run-shadow-ns s)
  (parameterize ([current-error-port (open-output-nowhere)])
    (run-ns-last s)))

(define integration-tests
  (test-suite
   "Driver integration"

   (test-case "simple def with shadow mode"
     (define result (run-shadow-simple "(def x : Nat 0N)"))
     (check-equal? (last result) "x : Nat defined."))

   (test-case "infer with shadow mode"
     (define result (run-shadow-simple "(infer 0N)"))
     (check-equal? (last result) "Nat"))

   (test-case "eval with shadow mode"
     (define result (run-shadow-simple "(eval 0N)"))
     (check-equal? (last result) "0N : Nat"))

   (test-case "implicit args with shadow mode (prelude)"
     (define result (run-shadow-ns "(ns test) (def x : Nat [add 1N 2N])"))
     ;; Should produce no errors (shadow validates agreement)
     (check-false (prologos-error? result)))))

;; ========================================
;; Run all suites
;; ========================================

(run-tests hook-tests)
(run-tests mirroring-tests)
(run-tests constraint-tests)
(run-tests validation-tests)
(run-tests integration-tests)

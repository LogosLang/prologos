#lang racket/base

;;;
;;; test-infra-cell-constraint-01.rkt — Phase 1a/1b: Constraint store + trait cells
;;;
;;; Validates that constraint and trait constraint cells in the elab-network
;;; accumulate data via merge functions, mirror legacy parameter stores,
;;; and are properly reset per-command.
;;;

(require rackunit
         racket/list
         "../propagator.rkt"
         "../infra-cell.rkt"
         "../elaborator-network.rkt"
         "../metavar-store.rkt"
         "../syntax.rkt"
         "../champ.rkt"
         "../driver.rkt")

;; Phase 6e: with-fresh-meta-env is now redundant — with-fresh-meta-env
;; creates the propagator network via reset-meta-store! when callbacks
;; are installed (which they are, via driver.rkt).

;; ========================================
;; Helper: make-test-env (direct cell tests, no metavar-store)
;; ========================================

(define (make-test-env)
  (define enet0 (make-elaboration-network))
  (define-values (enet1 cstore-cid) (elab-new-infra-cell enet0 '() merge-list-append))
  (values enet1 cstore-cid))

;; ========================================
;; Phase 1a: Direct cell tests
;; ========================================

(test-case "constraint cell: created empty"
  (define-values (enet cid) (make-test-env))
  (check-equal? (elab-cell-read enet cid) '()))

(test-case "constraint cell: single write appends"
  (define-values (enet0 cid) (make-test-env))
  (define c1 (constraint (gensym 'cst) (expr-Nat) (expr-Nat) '() "test" 'postponed '() '()))
  (define enet1 (elab-cell-write enet0 cid (list c1)))
  (check-equal? (length (elab-cell-read enet1 cid)) 1)
  (check-eq? (car (elab-cell-read enet1 cid)) c1))

(test-case "constraint cell: multiple writes accumulate"
  (define-values (enet0 cid) (make-test-env))
  (define c1 (constraint (gensym 'cst) (expr-Nat) (expr-Nat) '() "first" 'postponed '() '()))
  (define c2 (constraint (gensym 'cst) (expr-Bool) (expr-Bool) '() "second" 'postponed '() '()))
  (define enet1 (elab-cell-write enet0 cid (list c1)))
  (define enet2 (elab-cell-write enet1 cid (list c2)))
  (define contents (elab-cell-read enet2 cid))
  (check-equal? (length contents) 2)
  (check-eq? (first contents) c1)
  (check-eq? (second contents) c2))

(test-case "constraint cell: immutable — old network unaffected"
  (define-values (enet0 cid) (make-test-env))
  (define c1 (constraint (gensym 'cst) (expr-Nat) (expr-Nat) '() "test" 'postponed '() '()))
  (define enet1 (elab-cell-write enet0 cid (list c1)))
  (check-equal? (elab-cell-read enet0 cid) '())
  (check-equal? (length (elab-cell-read enet1 cid)) 1))

;; ========================================
;; Phase 1a: Integration with metavar-store
;; ========================================

(test-case "constraint cell: created by reset-meta-store!"
  (with-fresh-meta-env
    (check-not-false (current-constraint-cell-id))
    (check-not-false (current-prop-net-box))
    (define enet (unbox (current-prop-net-box)))
    (define cid (current-constraint-cell-id))
    ;; Track 6 Phase 1c: constraint store is now a hasheq.
    (check-equal? (elab-cell-read enet cid) (hasheq))))

;; Track 6 Phase 1c: constraint store is now a hasheq keyed by constraint cid.
(test-case "constraint cell: add-constraint! cell-primary writes"
  (with-fresh-meta-env
    (define c (add-constraint! (expr-Nat) (expr-Bool) '() "test-cell-primary"))
    (define cell-contents (elab-cell-read (unbox (current-prop-net-box))
                                          (current-constraint-cell-id)))
    (check-equal? (hash-count cell-contents) 1)
    ;; Track 7 Phase 4: cell values are tagged-entry; unwrap for comparison
    (check-eq? (tagged-entry-value (hash-ref cell-contents (constraint-cid c))) c)))

(test-case "constraint cell: multiple adds accumulate"
  (with-fresh-meta-env
    (define c1 (add-constraint! (expr-Nat) (expr-Nat) '() "first"))
    (define c2 (add-constraint! (expr-Bool) (expr-Bool) '() "second"))
    (define c3 (add-constraint! (expr-Nat) (expr-Bool) '() "third"))
    (define cell-contents (elab-cell-read (unbox (current-prop-net-box))
                                          (current-constraint-cell-id)))
    (check-equal? (hash-count cell-contents) 3)
    (check-eq? (tagged-entry-value (hash-ref cell-contents (constraint-cid c1))) c1)
    (check-eq? (tagged-entry-value (hash-ref cell-contents (constraint-cid c2))) c2)
    (check-eq? (tagged-entry-value (hash-ref cell-contents (constraint-cid c3))) c3)))

(test-case "constraint cell: read-constraint-store reads from cell"
  (with-fresh-meta-env
    (add-constraint! (expr-Nat) (expr-Bool) '() "test")
    (check-equal? (length (read-constraint-store)) 1)))

(test-case "constraint cell: reset recreates cell"
  (with-fresh-meta-env
    (add-constraint! (expr-Nat) (expr-Bool) '() "before-reset")
    (reset-meta-store!)
    (check-not-false (current-constraint-cell-id))
    (check-equal? (elab-cell-read (unbox (current-prop-net-box))
                                  (current-constraint-cell-id)) (hasheq))))

;; ========================================
;; Phase 1b: Trait/HasMethod/Capability constraint cells
;; ========================================

(test-case "Phase 1b: all 4 registry cells created by reset-meta-store!"
  (with-fresh-meta-env
    (check-not-false (current-trait-constraint-cell-id))
    (check-not-false (current-trait-cell-map-cell-id))
    (check-not-false (current-hasmethod-constraint-cell-id))
    (check-not-false (current-capability-constraint-cell-id))
    ;; All cells are distinct
    (define ids (list (current-constraint-cell-id)
                      (current-trait-constraint-cell-id)
                      (current-trait-cell-map-cell-id)
                      (current-hasmethod-constraint-cell-id)
                      (current-capability-constraint-cell-id)))
    (check-equal? (length (remove-duplicates ids equal?)) 5)))

(test-case "Phase 1b: trait constraint dual-write"
  (with-fresh-meta-env
    (define info (trait-constraint-info 'Eq (list (expr-Nat))))
    (register-trait-constraint! 'test-meta-id info)
    ;; Legacy hash has it
    (check-not-false (lookup-trait-constraint 'test-meta-id))
    ;; Cell also has it
    (define enet (unbox (current-prop-net-box)))
    (define tc-cell (elab-cell-read enet (current-trait-constraint-cell-id)))
    (check-not-false (hash-ref tc-cell 'test-meta-id #f))
    ;; Track 7 Phase 4: cell values are tagged-entry; unwrap for access
    (check-equal? (trait-constraint-info-trait-name
                   (tagged-entry-value (hash-ref tc-cell 'test-meta-id)))
                  'Eq)))

(test-case "Phase 1b: hasmethod constraint dual-write"
  (with-fresh-meta-env
    (define info (hasmethod-constraint-info (expr-fvar 'P) 'eq? (list (expr-Nat)) 'dict-id #f))
    (register-hasmethod-constraint! 'hm-meta info)
    ;; Legacy hash has it
    (check-not-false (lookup-hasmethod-constraint 'hm-meta))
    ;; Cell also has it
    (define enet (unbox (current-prop-net-box)))
    (define hm-cell (elab-cell-read enet (current-hasmethod-constraint-cell-id)))
    (check-not-false (hash-ref hm-cell 'hm-meta #f))
    (check-equal? (hasmethod-constraint-info-method-name
                   (tagged-entry-value (hash-ref hm-cell 'hm-meta)))
                  'eq?)))

(test-case "Phase 1b: capability constraint dual-write"
  (with-fresh-meta-env
    (define info (capability-constraint-info 'ReadCap (expr-fvar 'ReadCap)))
    (register-capability-constraint! 'cap-meta info)
    ;; Legacy hash has it
    (check-not-false (lookup-capability-constraint 'cap-meta))
    ;; Cell also has it
    (define enet (unbox (current-prop-net-box)))
    (define cap-cell (elab-cell-read enet (current-capability-constraint-cell-id)))
    (check-not-false (hash-ref cap-cell 'cap-meta #f))
    (check-equal? (capability-constraint-info-cap-name
                   (tagged-entry-value (hash-ref cap-cell 'cap-meta)))
                  'ReadCap)))

(test-case "Phase 1b: multiple trait constraints accumulate in cell"
  (with-fresh-meta-env
    (register-trait-constraint! 'm1 (trait-constraint-info 'Eq (list (expr-Nat))))
    (register-trait-constraint! 'm2 (trait-constraint-info 'Ord (list (expr-Bool))))
    (register-trait-constraint! 'm3 (trait-constraint-info 'Add (list (expr-Nat))))
    ;; Cell has all 3 (via merge-hasheq-union)
    (define enet (unbox (current-prop-net-box)))
    (define tc-cell (elab-cell-read enet (current-trait-constraint-cell-id)))
    (check-equal? (hash-count tc-cell) 3)
    (check-equal? (trait-constraint-info-trait-name (tagged-entry-value (hash-ref tc-cell 'm1))) 'Eq)
    (check-equal? (trait-constraint-info-trait-name (tagged-entry-value (hash-ref tc-cell 'm2))) 'Ord)
    (check-equal? (trait-constraint-info-trait-name (tagged-entry-value (hash-ref tc-cell 'm3))) 'Add)))

(test-case "Phase 1b: registry cells are empty after reset"
  (with-fresh-meta-env
    (register-trait-constraint! 'm1 (trait-constraint-info 'Eq (list (expr-Nat))))
    (register-hasmethod-constraint! 'hm1 (hasmethod-constraint-info (expr-fvar 'P) 'eq? '() #f #f))
    (register-capability-constraint! 'cap1 (capability-constraint-info 'R (expr-fvar 'R)))
    ;; Reset
    (reset-meta-store!)
    ;; All cells should be empty (new network, new cells)
    (define enet (unbox (current-prop-net-box)))
    (check-equal? (hash-count (elab-cell-read enet (current-trait-constraint-cell-id))) 0)
    (check-equal? (hash-count (elab-cell-read enet (current-hasmethod-constraint-cell-id))) 0)
    (check-equal? (hash-count (elab-cell-read enet (current-capability-constraint-cell-id))) 0)))

;; ========================================
;; Phase 1c: Wakeup registry cells — RETIRED 2026-08-05
;; ========================================
;;
;; Three test cases lived here, asserting that the wakeup-registry, trait-wakeup
;; and hasmethod-wakeup cells existed, were distinct, and stayed empty. The cells
;; were retired 2026-08-05 as write-only: instrumenting the examples corpus found
;; 6-11 writes per file and ZERO reads on all 51, and the three
;; collect-ready-*-for-meta readers they fed had no callers in the tree.
;;
;; The cases went with them rather than being weakened, because two of the three
;; asserted only that the cells were empty — which was true precisely BECAUSE
;; nothing used them, and would have gone on passing forever.
;;
;; The surviving distinctness check below covers the five real constraint cells.

(test-case "the five constraint cells are distinct"
  (with-fresh-meta-env
    (define ids (list (current-constraint-cell-id)
                      (current-trait-constraint-cell-id)
                      (current-trait-cell-map-cell-id)
                      (current-hasmethod-constraint-cell-id)
                      (current-capability-constraint-cell-id)))
    (check-equal? (length (remove-duplicates ids equal?)) 5
                  "each constraint cell must have its own id")))

(test-case "all constraint cells empty after reset"
  (with-fresh-meta-env
    (register-trait-constraint! 'm1 (trait-constraint-info 'Eq (list (expr-Nat))))
    (register-hasmethod-constraint! 'hm1 (hasmethod-constraint-info (expr-fvar 'P) 'eq? '() #f #f))
    (register-capability-constraint! 'cap1 (capability-constraint-info 'R (expr-fvar 'R)))
    (reset-meta-store!)
    (define enet (unbox (current-prop-net-box)))
    ;; The two wakeup-cell assertions that used to live here went with the cells
    ;; (retired 2026-08-05). The five real constraint cells still have to come
    ;; back empty, which is what this case was actually for.
    (check-equal? (hash-count (elab-cell-read enet (current-constraint-cell-id))) 0)
    (check-equal? (hash-count (elab-cell-read enet (current-trait-constraint-cell-id))) 0)
    (check-equal? (hash-count (elab-cell-read enet (current-trait-cell-map-cell-id))) 0)
    (check-equal? (hash-count (elab-cell-read enet (current-hasmethod-constraint-cell-id))) 0)
    (check-equal? (hash-count (elab-cell-read enet (current-capability-constraint-cell-id))) 0)))

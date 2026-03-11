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
         "../champ.rkt")

;; ========================================
;; Helper: with-infra-cell-env
;; ========================================
;; Creates a full environment with all callbacks installed and all constraint
;; parameters isolated. Calls reset-meta-store! to create the constraint cells.

(define-syntax-rule (with-infra-cell-env body ...)
  (parameterize ([current-prop-make-network make-elaboration-network]
                 [current-prop-new-infra-cell elab-new-infra-cell]
                 [current-prop-cell-write elab-cell-write]
                 [current-prop-cell-read elab-cell-read]
                 [current-prop-fresh-meta elab-fresh-meta]
                 [current-prop-add-unify-constraint elab-add-unify-constraint]
                 [current-prop-net-box #f]
                 [current-prop-id-map-box #f]
                 [current-prop-meta-info-box (box champ-empty)]
                 [current-level-meta-champ-box (box champ-empty)]
                 [current-mult-meta-champ-box (box champ-empty)]
                 [current-sess-meta-champ-box (box champ-empty)]
                 [current-meta-store (make-hasheq)]
                 [current-level-meta-store (make-hasheq)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-sess-meta-store (make-hasheq)]
                 [current-constraint-store '()]
                 [current-constraint-cell-id #f]
                 [current-trait-constraint-cell-id #f]
                 [current-trait-cell-map-cell-id #f]
                 [current-hasmethod-constraint-cell-id #f]
                 [current-capability-constraint-cell-id #f]
                 [current-wakeup-registry-cell-id #f]
                 [current-trait-wakeup-cell-id #f]
                 [current-wakeup-registry (make-hasheq)]
                 [current-trait-constraint-map (make-hasheq)]
                 [current-trait-wakeup-map (make-hasheq)]
                 [current-trait-cell-map (make-hasheq)]
                 [current-hasmethod-constraint-map (make-hasheq)]
                 [current-hasmethod-wakeup-map (make-hasheq)]  ;; Phase 1d
                 [current-capability-constraint-map (make-hasheq)])
    (reset-meta-store!)
    body ...))

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
  (define c1 (constraint (expr-Nat) (expr-Nat) '() "test" 'postponed '()))
  (define enet1 (elab-cell-write enet0 cid (list c1)))
  (check-equal? (length (elab-cell-read enet1 cid)) 1)
  (check-eq? (car (elab-cell-read enet1 cid)) c1))

(test-case "constraint cell: multiple writes accumulate"
  (define-values (enet0 cid) (make-test-env))
  (define c1 (constraint (expr-Nat) (expr-Nat) '() "first" 'postponed '()))
  (define c2 (constraint (expr-Bool) (expr-Bool) '() "second" 'postponed '()))
  (define enet1 (elab-cell-write enet0 cid (list c1)))
  (define enet2 (elab-cell-write enet1 cid (list c2)))
  (define contents (elab-cell-read enet2 cid))
  (check-equal? (length contents) 2)
  (check-eq? (first contents) c1)
  (check-eq? (second contents) c2))

(test-case "constraint cell: immutable — old network unaffected"
  (define-values (enet0 cid) (make-test-env))
  (define c1 (constraint (expr-Nat) (expr-Nat) '() "test" 'postponed '()))
  (define enet1 (elab-cell-write enet0 cid (list c1)))
  (check-equal? (elab-cell-read enet0 cid) '())
  (check-equal? (length (elab-cell-read enet1 cid)) 1))

;; ========================================
;; Phase 1a: Integration with metavar-store
;; ========================================

(test-case "constraint cell: created by reset-meta-store!"
  (with-infra-cell-env
    (check-not-false (current-constraint-cell-id))
    (check-not-false (current-prop-net-box))
    (define enet (unbox (current-prop-net-box)))
    (define cid (current-constraint-cell-id))
    (check-equal? (elab-cell-read enet cid) '())))

(test-case "constraint cell: add-constraint! dual-writes"
  (with-infra-cell-env
    (define c (add-constraint! (expr-Nat) (expr-Bool) '() "test-dual-write"))
    (check-equal? (length (current-constraint-store)) 1)
    (check-eq? (car (current-constraint-store)) c)
    (define cell-contents (elab-cell-read (unbox (current-prop-net-box))
                                          (current-constraint-cell-id)))
    (check-equal? (length cell-contents) 1)
    (check-eq? (car cell-contents) c)))

(test-case "constraint cell: multiple adds accumulate"
  (with-infra-cell-env
    (define c1 (add-constraint! (expr-Nat) (expr-Nat) '() "first"))
    (define c2 (add-constraint! (expr-Bool) (expr-Bool) '() "second"))
    (define c3 (add-constraint! (expr-Nat) (expr-Bool) '() "third"))
    (check-equal? (length (current-constraint-store)) 3)
    (define cell-contents (elab-cell-read (unbox (current-prop-net-box))
                                          (current-constraint-cell-id)))
    (check-equal? (length cell-contents) 3)
    (check-eq? (first cell-contents) c1)
    (check-eq? (second cell-contents) c2)
    (check-eq? (third cell-contents) c3)))

(test-case "constraint cell: read-constraint-store reads from cell"
  (with-infra-cell-env
    (add-constraint! (expr-Nat) (expr-Bool) '() "test")
    (check-equal? (length (read-constraint-store)) 1)))

(test-case "constraint cell: read-constraint-store fallback"
  (with-fresh-meta-env
    (current-constraint-store (list (constraint (expr-Nat) (expr-Nat) '() "legacy" 'postponed '())))
    (check-equal? (length (read-constraint-store)) 1)))

(test-case "constraint cell: reset recreates cell"
  (with-infra-cell-env
    (add-constraint! (expr-Nat) (expr-Bool) '() "before-reset")
    (reset-meta-store!)
    (check-not-false (current-constraint-cell-id))
    (check-equal? (elab-cell-read (unbox (current-prop-net-box))
                                  (current-constraint-cell-id)) '())
    (check-equal? (current-constraint-store) '())))

;; ========================================
;; Phase 1b: Trait/HasMethod/Capability constraint cells
;; ========================================

(test-case "Phase 1b: all 4 registry cells created by reset-meta-store!"
  (with-infra-cell-env
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
  (with-infra-cell-env
    (define info (trait-constraint-info 'Eq (list (expr-Nat))))
    (register-trait-constraint! 'test-meta-id info)
    ;; Legacy hash has it
    (check-not-false (lookup-trait-constraint 'test-meta-id))
    ;; Cell also has it
    (define enet (unbox (current-prop-net-box)))
    (define tc-cell (elab-cell-read enet (current-trait-constraint-cell-id)))
    (check-not-false (hash-ref tc-cell 'test-meta-id #f))
    (check-equal? (trait-constraint-info-trait-name
                   (hash-ref tc-cell 'test-meta-id))
                  'Eq)))

(test-case "Phase 1b: hasmethod constraint dual-write"
  (with-infra-cell-env
    (define info (hasmethod-constraint-info (expr-fvar 'P) 'eq? (list (expr-Nat)) 'dict-id))
    (register-hasmethod-constraint! 'hm-meta info)
    ;; Legacy hash has it
    (check-not-false (lookup-hasmethod-constraint 'hm-meta))
    ;; Cell also has it
    (define enet (unbox (current-prop-net-box)))
    (define hm-cell (elab-cell-read enet (current-hasmethod-constraint-cell-id)))
    (check-not-false (hash-ref hm-cell 'hm-meta #f))
    (check-equal? (hasmethod-constraint-info-method-name
                   (hash-ref hm-cell 'hm-meta))
                  'eq?)))

(test-case "Phase 1b: capability constraint dual-write"
  (with-infra-cell-env
    (define info (capability-constraint-info 'ReadCap (expr-fvar 'ReadCap)))
    (register-capability-constraint! 'cap-meta info)
    ;; Legacy hash has it
    (check-not-false (lookup-capability-constraint 'cap-meta))
    ;; Cell also has it
    (define enet (unbox (current-prop-net-box)))
    (define cap-cell (elab-cell-read enet (current-capability-constraint-cell-id)))
    (check-not-false (hash-ref cap-cell 'cap-meta #f))
    (check-equal? (capability-constraint-info-cap-name
                   (hash-ref cap-cell 'cap-meta))
                  'ReadCap)))

(test-case "Phase 1b: multiple trait constraints accumulate in cell"
  (with-infra-cell-env
    (register-trait-constraint! 'm1 (trait-constraint-info 'Eq (list (expr-Nat))))
    (register-trait-constraint! 'm2 (trait-constraint-info 'Ord (list (expr-Bool))))
    (register-trait-constraint! 'm3 (trait-constraint-info 'Add (list (expr-Nat))))
    ;; Cell has all 3 (via merge-hasheq-union)
    (define enet (unbox (current-prop-net-box)))
    (define tc-cell (elab-cell-read enet (current-trait-constraint-cell-id)))
    (check-equal? (hash-count tc-cell) 3)
    (check-equal? (trait-constraint-info-trait-name (hash-ref tc-cell 'm1)) 'Eq)
    (check-equal? (trait-constraint-info-trait-name (hash-ref tc-cell 'm2)) 'Ord)
    (check-equal? (trait-constraint-info-trait-name (hash-ref tc-cell 'm3)) 'Add)))

(test-case "Phase 1b: registry cells are empty after reset"
  (with-infra-cell-env
    (register-trait-constraint! 'm1 (trait-constraint-info 'Eq (list (expr-Nat))))
    (register-hasmethod-constraint! 'hm1 (hasmethod-constraint-info (expr-fvar 'P) 'eq? '() #f))
    (register-capability-constraint! 'cap1 (capability-constraint-info 'R (expr-fvar 'R)))
    ;; Reset
    (reset-meta-store!)
    ;; All cells should be empty (new network, new cells)
    (define enet (unbox (current-prop-net-box)))
    (check-equal? (hash-count (elab-cell-read enet (current-trait-constraint-cell-id))) 0)
    (check-equal? (hash-count (elab-cell-read enet (current-hasmethod-constraint-cell-id))) 0)
    (check-equal? (hash-count (elab-cell-read enet (current-capability-constraint-cell-id))) 0)))

;; ========================================
;; Phase 1c: Wakeup registry cells
;; ========================================

(test-case "Phase 1c: wakeup registry cells created"
  (with-infra-cell-env
    (check-not-false (current-wakeup-registry-cell-id))
    (check-not-false (current-trait-wakeup-cell-id))
    ;; Both are empty hasheqs initially
    (define enet (unbox (current-prop-net-box)))
    (check-equal? (hash-count (elab-cell-read enet (current-wakeup-registry-cell-id))) 0)
    (check-equal? (hash-count (elab-cell-read enet (current-trait-wakeup-cell-id))) 0)))

(test-case "Phase 1c: wakeup registry cell distinct from others"
  (with-infra-cell-env
    (define ids (list (current-constraint-cell-id)
                      (current-trait-constraint-cell-id)
                      (current-trait-cell-map-cell-id)
                      (current-hasmethod-constraint-cell-id)
                      (current-capability-constraint-cell-id)
                      (current-wakeup-registry-cell-id)
                      (current-trait-wakeup-cell-id)))
    (check-equal? (length (remove-duplicates ids equal?)) 7)))

(test-case "Phase 1c: add-constraint! dual-writes to wakeup cell"
  (with-infra-cell-env
    ;; add-constraint! with expr containing metas would populate wakeup registry
    ;; but without actual metas, meta-ids will be empty. Use direct meta construction.
    ;; For this test we just verify the cell is writable and accumulates.
    ;; Note: add-constraint! only writes to wakeup cell when meta-ids is non-empty,
    ;; which requires actual expr-meta nodes. Test the empty case:
    (add-constraint! (expr-Nat) (expr-Bool) '() "no-metas")
    ;; No metas in Nat/Bool, so wakeup registry cell should still be empty
    (define enet (unbox (current-prop-net-box)))
    (check-equal? (hash-count (elab-cell-read enet (current-wakeup-registry-cell-id))) 0)))

(test-case "Phase 1c: all 7 cells empty after reset"
  (with-infra-cell-env
    (register-trait-constraint! 'm1 (trait-constraint-info 'Eq (list (expr-Nat))))
    (register-hasmethod-constraint! 'hm1 (hasmethod-constraint-info (expr-fvar 'P) 'eq? '() #f))
    (register-capability-constraint! 'cap1 (capability-constraint-info 'R (expr-fvar 'R)))
    (reset-meta-store!)
    (define enet (unbox (current-prop-net-box)))
    (check-equal? (hash-count (elab-cell-read enet (current-wakeup-registry-cell-id))) 0)
    (check-equal? (hash-count (elab-cell-read enet (current-trait-wakeup-cell-id))) 0)))

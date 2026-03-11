#lang racket/base

;;;
;;; test-infra-cell-constraint-01.rkt — Phase 1a: Constraint store cell tests
;;;
;;; Validates that the constraint store cell in the elab-network accumulates
;;; constraints via merge-list-append, mirrors the legacy parameter store,
;;; and is properly reset per-command.
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
;; Helper: set up a minimal network environment
;; ========================================

;; Creates a fresh elab-network environment with constraint cell,
;; mimicking what the driver does at startup.
(define (make-test-env)
  (define enet0 (make-elaboration-network))
  (define-values (enet1 cstore-cid) (elab-new-infra-cell enet0 '() merge-list-append))
  (values enet1 cstore-cid))

;; ========================================
;; Direct cell tests (no metavar-store integration)
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
  ;; Both constraints present (merge-list-append preserves order)
  (check-eq? (first contents) c1)
  (check-eq? (second contents) c2))

(test-case "constraint cell: immutable — old network unaffected"
  (define-values (enet0 cid) (make-test-env))
  (define c1 (constraint (expr-Nat) (expr-Nat) '() "test" 'postponed '()))
  (define enet1 (elab-cell-write enet0 cid (list c1)))
  ;; Original network still empty
  (check-equal? (elab-cell-read enet0 cid) '())
  ;; New network has one constraint
  (check-equal? (length (elab-cell-read enet1 cid)) 1))

;; ========================================
;; Integration with metavar-store infrastructure
;; ========================================

(test-case "constraint cell: created by reset-meta-store! when callbacks installed"
  ;; Install callbacks
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
                 [current-wakeup-registry (make-hasheq)]
                 [current-trait-constraint-map (make-hasheq)]
                 [current-trait-wakeup-map (make-hasheq)]
                 [current-trait-cell-map (make-hasheq)]
                 [current-hasmethod-constraint-map (make-hasheq)])
    (reset-meta-store!)
    ;; After reset, constraint cell should be created
    (check-not-false (current-constraint-cell-id))
    (check-not-false (current-prop-net-box))
    ;; Cell contents should be empty
    (define enet (unbox (current-prop-net-box)))
    (define cid (current-constraint-cell-id))
    (check-equal? (elab-cell-read enet cid) '())))

(test-case "constraint cell: add-constraint! writes to both parameter and cell"
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
                 [current-wakeup-registry (make-hasheq)]
                 [current-trait-constraint-map (make-hasheq)]
                 [current-trait-wakeup-map (make-hasheq)]
                 [current-trait-cell-map (make-hasheq)]
                 [current-hasmethod-constraint-map (make-hasheq)])
    (reset-meta-store!)
    ;; Add a constraint
    (define c (add-constraint! (expr-Nat) (expr-Bool) '() "test-dual-write"))
    ;; Legacy parameter has it
    (check-equal? (length (current-constraint-store)) 1)
    (check-eq? (car (current-constraint-store)) c)
    ;; Cell also has it
    (define enet (unbox (current-prop-net-box)))
    (define cid (current-constraint-cell-id))
    (define cell-contents (elab-cell-read enet cid))
    (check-equal? (length cell-contents) 1)
    (check-eq? (car cell-contents) c)))

(test-case "constraint cell: multiple adds accumulate in cell"
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
                 [current-wakeup-registry (make-hasheq)]
                 [current-trait-constraint-map (make-hasheq)]
                 [current-trait-wakeup-map (make-hasheq)]
                 [current-trait-cell-map (make-hasheq)]
                 [current-hasmethod-constraint-map (make-hasheq)])
    (reset-meta-store!)
    (define c1 (add-constraint! (expr-Nat) (expr-Nat) '() "first"))
    (define c2 (add-constraint! (expr-Bool) (expr-Bool) '() "second"))
    (define c3 (add-constraint! (expr-Nat) (expr-Bool) '() "third"))
    ;; Legacy parameter has all 3 (reversed — cons prepends)
    (check-equal? (length (current-constraint-store)) 3)
    ;; Cell also has all 3 (appended — merge-list-append)
    (define cell-contents (elab-cell-read (unbox (current-prop-net-box))
                                          (current-constraint-cell-id)))
    (check-equal? (length cell-contents) 3)
    ;; Cell preserves insertion order (append)
    (check-eq? (first cell-contents) c1)
    (check-eq? (second cell-contents) c2)
    (check-eq? (third cell-contents) c3)))

(test-case "constraint cell: read-constraint-store reads from cell when available"
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
                 [current-wakeup-registry (make-hasheq)]
                 [current-trait-constraint-map (make-hasheq)]
                 [current-trait-wakeup-map (make-hasheq)]
                 [current-trait-cell-map (make-hasheq)]
                 [current-hasmethod-constraint-map (make-hasheq)])
    (reset-meta-store!)
    (add-constraint! (expr-Nat) (expr-Bool) '() "test")
    ;; read-constraint-store should return cell contents
    (define cs (read-constraint-store))
    (check-equal? (length cs) 1)))

(test-case "constraint cell: read-constraint-store falls back to parameter when no cell"
  (with-fresh-meta-env
    ;; No network, no cell — falls back to legacy parameter
    (current-constraint-store (list (constraint (expr-Nat) (expr-Nat) '() "legacy" 'postponed '())))
    (define cs (read-constraint-store))
    (check-equal? (length cs) 1)))

(test-case "constraint cell: reset recreates cell"
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
                 [current-wakeup-registry (make-hasheq)]
                 [current-trait-constraint-map (make-hasheq)]
                 [current-trait-wakeup-map (make-hasheq)]
                 [current-trait-cell-map (make-hasheq)]
                 [current-hasmethod-constraint-map (make-hasheq)])
    (reset-meta-store!)
    (define cid1 (current-constraint-cell-id))
    (add-constraint! (expr-Nat) (expr-Bool) '() "before-reset")
    ;; Reset again — should get fresh cell
    (reset-meta-store!)
    (define cid2 (current-constraint-cell-id))
    ;; New cell ID (new network)
    (check-not-false cid2)
    ;; Cell is empty after reset
    (define cell-contents (elab-cell-read (unbox (current-prop-net-box)) cid2))
    (check-equal? cell-contents '())
    ;; Legacy parameter also empty
    (check-equal? (current-constraint-store) '())))

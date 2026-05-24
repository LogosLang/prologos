#lang racket/base

;;;
;;; test-error-explanation.rkt — PPN 4C Addendum Phase 3C.a tests
;;;
;;; Tests for `static-reverse-walk` primitive + derivation-chain/-step
;;; structs per §9.5.2 mini-design (8 test cases T1-T8).
;;;
;;; Test strategy: synthetic dep-graphs constructed via make-prop-network +
;;; net-new-cell + net-add-propagator. No firing required for graph-walk
;;; tests (T1-T7); T8 directly writes tagged-cell-value via net-cell-write
;;; to verify aid decoding.
;;;

(require rackunit
         racket/list
         "../atms.rkt"
         "../decision-cell.rkt"
         "../error-explanation.rkt"
         "../propagator.rkt"
         "../source-location.rkt")

;; ========================================
;; Test helpers
;; ========================================

;; Simple flat-lattice merge for synthetic test cells.
;; 'bot is identity; otherwise new wins.
(define (flat-merge old new)
  (cond [(eq? old 'bot) new]
        [(eq? new 'bot) old]
        [else new]))

;; No-op fire function for test propagators — we don't fire during
;; graph-walk tests; the network's STRUCTURAL graph is what matters.
(define (noop-fire net) net)

;; Helper: install a propagator with optional srcloc; return new net + pid.
(define (install-prop net inputs outputs [srcloc-arg #f])
  (net-add-propagator net inputs outputs noop-fire #:srcloc srcloc-arg))

;; ========================================
;; T1 — Single propagator outputs to target cell
;; ========================================

(test-case "T1: single propagator → 1-step chain with correct prop-id + srcloc"
  (define net0 (make-prop-network))
  (define-values (net1 cell-input) (net-new-cell net0 'bot flat-merge))
  (define-values (net2 cell-target) (net-new-cell net1 'bot flat-merge))
  (define test-srcloc (srcloc "T1-test.rkt" 10 5 20))
  (define-values (net3 pid) (install-prop net2 (list cell-input) (list cell-target) test-srcloc))

  (define chain (static-reverse-walk net3 cell-target))
  (check-true (derivation-chain? chain))
  (define steps (derivation-chain-steps chain))
  (check-equal? (length steps) 1)
  (define step (car steps))
  (check-true (derivation-step? step))
  (check-equal? (derivation-step-propagator-id step) pid)
  (check-equal? (derivation-step-srcloc step) test-srcloc)
  ;; No tagged-cell-value at cell-target → empty aids
  (check-equal? (derivation-step-assumption-ids step) '())
  ;; Primitive sets assumption-names='() and residual-cost=#f
  (check-equal? (derivation-step-assumption-names step) '())
  (check-false (derivation-step-residual-cost step)))

;; ========================================
;; T2 — Linear chain (causal order: deepest first)
;; ========================================

(test-case "T2: linear chain (P1→A→P2→B); walk from B → 2 steps, P1 first (deepest)"
  (define net0 (make-prop-network))
  (define-values (net1 cell-input) (net-new-cell net0 'bot flat-merge))
  (define-values (net2 cell-a) (net-new-cell net1 'bot flat-merge))
  (define-values (net3 cell-b) (net-new-cell net2 'bot flat-merge))
  ;; P1: cell-input → cell-a
  (define srcloc-p1 (srcloc "P1.rkt" 1 0 10))
  (define-values (net4 pid-1) (install-prop net3 (list cell-input) (list cell-a) srcloc-p1))
  ;; P2: cell-a → cell-b
  (define srcloc-p2 (srcloc "P2.rkt" 2 0 10))
  (define-values (net5 pid-2) (install-prop net4 (list cell-a) (list cell-b) srcloc-p2))

  (define chain (static-reverse-walk net5 cell-b))
  (define steps (derivation-chain-steps chain))
  (check-equal? (length steps) 2)
  ;; Causal reading order: deepest cause first (P1) → symptom last (P2)
  (check-equal? (derivation-step-propagator-id (first steps)) pid-1)
  (check-equal? (derivation-step-propagator-id (second steps)) pid-2)
  (check-equal? (derivation-step-srcloc (first steps)) srcloc-p1)
  (check-equal? (derivation-step-srcloc (second steps)) srcloc-p2))

;; ========================================
;; T3 — Multi-writer (set-equality assertion per D-3C.a-2)
;; ========================================

(test-case "T3: multi-writer (P1,P2 both → A); walk from A → 2 steps (set-equal)"
  (define net0 (make-prop-network))
  (define-values (net1 cell-input-1) (net-new-cell net0 'bot flat-merge))
  (define-values (net2 cell-input-2) (net-new-cell net1 'bot flat-merge))
  (define-values (net3 cell-a) (net-new-cell net2 'bot flat-merge))
  (define-values (net4 pid-1) (install-prop net3 (list cell-input-1) (list cell-a)))
  (define-values (net5 pid-2) (install-prop net4 (list cell-input-2) (list cell-a)))

  (define chain (static-reverse-walk net5 cell-a))
  (define steps (derivation-chain-steps chain))
  (check-equal? (length steps) 2)
  ;; Set equality (champ-fold order non-deterministic across runs per D-3C.a-2)
  (define step-pids (map derivation-step-propagator-id steps))
  (check-true (and (member pid-1 step-pids) #t))
  (check-true (and (member pid-2 step-pids) #t)))

;; ========================================
;; T4 — Cycle detection
;; ========================================

(test-case "T4: cycle (P1↔P2 via shared cells); cycle detection halts walk"
  (define net0 (make-prop-network))
  (define-values (net1 cell-a) (net-new-cell net0 'bot flat-merge))
  (define-values (net2 cell-b) (net-new-cell net1 'bot flat-merge))
  ;; P1: cell-b → cell-a (reads B, writes A)
  (define-values (net3 pid-1) (install-prop net2 (list cell-b) (list cell-a)))
  ;; P2: cell-a → cell-b (reads A, writes B)
  (define-values (net4 pid-2) (install-prop net3 (list cell-a) (list cell-b)))

  ;; Walk from cell-a: should find P1 (writes A), recurse on B (P1's input),
  ;; find P2 (writes B), recurse on A (P2's input) — but A's writer P1 is
  ;; already visited → cycle broken. Walk terminates with 2 steps.
  (define chain (static-reverse-walk net4 cell-a))
  (define steps (derivation-chain-steps chain))
  (check-equal? (length steps) 2)
  (define step-pids (map derivation-step-propagator-id steps))
  (check-true (and (member pid-1 step-pids) #t))
  (check-true (and (member pid-2 step-pids) #t)))

;; ========================================
;; T5 — Depth bound truncation
;; ========================================

(test-case "T5: chain of 5 propagators, #:max-depth 3 → walk truncates at depth 3"
  (define net0 (make-prop-network))
  ;; Build a linear chain: cell-0 → P1 → cell-1 → P2 → cell-2 → P3 → cell-3 → P4 → cell-4 → P5 → cell-5
  (define-values (net1 cell-0) (net-new-cell net0 'bot flat-merge))
  (define-values (net2 cell-1) (net-new-cell net1 'bot flat-merge))
  (define-values (net3 cell-2) (net-new-cell net2 'bot flat-merge))
  (define-values (net4 cell-3) (net-new-cell net3 'bot flat-merge))
  (define-values (net5 cell-4) (net-new-cell net4 'bot flat-merge))
  (define-values (net6 cell-5) (net-new-cell net5 'bot flat-merge))
  (define-values (net7 _pid-1) (install-prop net6 (list cell-0) (list cell-1)))
  (define-values (net8 _pid-2) (install-prop net7 (list cell-1) (list cell-2)))
  (define-values (net9 _pid-3) (install-prop net8 (list cell-2) (list cell-3)))
  (define-values (netA _pid-4) (install-prop net9 (list cell-3) (list cell-4)))
  (define-values (netB _pid-5) (install-prop netA (list cell-4) (list cell-5)))

  ;; Walk from cell-5 with max-depth=3: visit P5 (depth 0), recurse to cell-4
  ;; (depth 1), visit P4, recurse to cell-3 (depth 2), visit P3, recurse to
  ;; cell-2 (depth 3 = max → halt). Chain has 3 steps (P3, P4, P5 in causal order).
  (define chain (static-reverse-walk netB cell-5 #:max-depth 3))
  (define steps (derivation-chain-steps chain))
  (check-equal? (length steps) 3
                "Walk should truncate at depth 3 (3 steps from chain of 5)"))

;; ========================================
;; T6 — filter-fn excludes prop-id
;; ========================================

(test-case "T6: filter-fn excludes one prop-id → chain excludes filtered step"
  (define net0 (make-prop-network))
  (define-values (net1 cell-input) (net-new-cell net0 'bot flat-merge))
  (define-values (net2 cell-a) (net-new-cell net1 'bot flat-merge))
  (define-values (net3 cell-b) (net-new-cell net2 'bot flat-merge))
  (define-values (net4 pid-1) (install-prop net3 (list cell-input) (list cell-a)))
  (define-values (net5 pid-2) (install-prop net4 (list cell-a) (list cell-b)))

  ;; Filter excludes pid-1
  (define excluded-pid pid-1)
  (define chain
    (static-reverse-walk net5 cell-b
                         #:filter-fn (lambda (step)
                                       (not (equal? (derivation-step-propagator-id step)
                                                    excluded-pid)))))
  (define steps (derivation-chain-steps chain))
  ;; Filter applied at step decoration; excluded step removed (P1 filtered out)
  ;; Note: filter happens BEFORE recursion in current impl, so excluding P1
  ;; also stops recursion through P1's inputs. Chain has 1 step (P2 only).
  (check-equal? (length steps) 1)
  (check-equal? (derivation-step-propagator-id (car steps)) pid-2))

;; ========================================
;; T7 — Propagator without srcloc (graceful degradation per D-3C-7)
;; ========================================

(test-case "T7: propagator without #:srcloc → step.srcloc = #f"
  (define net0 (make-prop-network))
  (define-values (net1 cell-input) (net-new-cell net0 'bot flat-merge))
  (define-values (net2 cell-target) (net-new-cell net1 'bot flat-merge))
  ;; Install with srcloc=#f (default)
  (define-values (net3 _pid) (install-prop net2 (list cell-input) (list cell-target) #f))

  (define chain (static-reverse-walk net3 cell-target))
  (define steps (derivation-chain-steps chain))
  (check-equal? (length steps) 1)
  (check-false (derivation-step-srcloc (car steps))
               "srcloc field should be #f for propagator installed without #:srcloc"))

;; ========================================
;; T8 — Tagged-cell-value aid decoding
;; ========================================

(test-case "T8: tagged-cell-value entries → assumption-ids decoded"
  (define net0 (make-prop-network))
  (define-values (net1 cell-input) (net-new-cell net0 'bot flat-merge))
  ;; Cell-target uses identity-or-bot merge that accepts tagged-cell-value
  (define (tagged-aware-merge old new)
    (cond [(eq? old 'bot) new]
          [(tagged-cell-value? new) new]  ;; accept tagged writes
          [else new]))
  (define-values (net2 cell-target) (net-new-cell net1 'bot tagged-aware-merge))
  (define-values (net3 _pid) (install-prop net2 (list cell-input) (list cell-target)))
  ;; Write a tagged-cell-value with bitmask = #b011 (bit 0 + bit 1 set)
  ;; Note: net-cell-write applies merge; tagged-aware-merge passes through.
  (define tagged-val (tagged-cell-value 'base-val (list (cons #b011 'some-val))))
  (define net4 (net-cell-write net3 cell-target tagged-val))

  (define chain (static-reverse-walk net4 cell-target))
  (define steps (derivation-chain-steps chain))
  (check-equal? (length steps) 1)
  (define step (car steps))
  (define aids (derivation-step-assumption-ids step))
  (check-equal? (length aids) 2 "Two bits set → 2 aids decoded")
  ;; Both aids should be (assumption-id 0) and (assumption-id 1) in some order
  (define aid-ns (sort (map assumption-id-n aids) <))
  (check-equal? aid-ns '(0 1)
                "Bit positions 0 and 1 decoded into assumption-ids"))

;; ========================================
;; Module-level smoke: chain struct shape stable
;; ========================================

(test-case "smoke: derivation-chain + derivation-step structs are transparent + LSP-ready"
  (define s (derivation-step (prop-id 42) #f '() '() #f))
  (define c (derivation-chain (list s)))
  ;; Transparency: equal? compares field-by-field
  (check-equal? c (derivation-chain (list (derivation-step (prop-id 42) #f '() '() #f))))
  ;; Field access via auto-generated accessors
  (check-equal? (derivation-step-propagator-id s) (prop-id 42))
  (check-equal? (derivation-step-residual-cost s) #f)
  (check-equal? (derivation-chain-steps c) (list s)))

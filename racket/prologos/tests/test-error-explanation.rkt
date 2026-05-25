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
         racket/set
         "../atms.rkt"
         "../decision-cell.rkt"
         "../elab-speculation-bridge.rkt"
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

;; ============================================================
;; PPN 4C Phase 3C.b.3 (2026-05-23): derivation-chain-for/union-contradict
;; ============================================================
;; Wrapper consumes 3C.a's static-reverse-walk; filters by branch-aid-set;
;; enriches steps with assumption-names from solver-state-assumptions.
;; D-3C.b-1 mitigation: name-decoding prefers string datum (Phase 3A amb
;; pattern) over symbol name; falls back to name symbol for non-string datums.

;; Test helper: synthetic tagged-aware merge for tests that write
;; tagged-cell-value entries to dep-graph cells.
(define (tagged-aware-flat-merge old new)
  (cond [(eq? old 'bot) new]
        [(tagged-cell-value? new) new]
        [else new]))

;; ========================================
;; T-B.1 — Wrapper produces enriched chain for matching aids
;; ========================================
;;
;; Synthetic setup: dep graph with 2 propagators (P1 → A → P2 → tm-cell).
;; tm-cell has tagged-cell-value entry with aid-0 bit set. branch-aid-set
;; contains aid-0. Expect chain to include the step with assumption-names
;; populated via solver-state-assumptions lookup.

(test-case "T-B.1: derivation-chain-for/union-contradict — filters by aid-set + enriches names"
  (define net0 (make-prop-network))
  (define-values (net1 cell-input) (net-new-cell net0 'bot tagged-aware-flat-merge))
  (define-values (net2 tm-cell) (net-new-cell net1 'bot tagged-aware-flat-merge))
  (define test-srcloc (srcloc "wrapper-test.rkt" 1 0 10))
  (define-values (net3 _pid)
    (net-add-propagator net2 (list cell-input) (list tm-cell)
                        (lambda (n) n)
                        #:srcloc test-srcloc))
  ;; Write tagged-cell-value at tm-cell with bit 0 set (aid-0 tag)
  (define tagged-val (tagged-cell-value 'base (list (cons #b001 'val))))
  (define net4 (net-cell-write net3 tm-cell tagged-val))

  ;; Set up current-command-atms with an aid that has a string datum
  ;; (Phase 3A label pattern: `(format "branch-~a-at-~v" i position)`)
  (parameterize ([current-command-atms (box (make-solver-state (make-prop-network)))])
    (define atms-box (current-command-atms))
    (define-values (atms* aid-0)
      (solver-state-assume (unbox atms-box) 'h0 "branch-0-at-position-X"))
    (set-box! atms-box atms*)
    ;; Verify the aid matches the bit position we wrote (assumption-id 0 → bit 0)
    (check-equal? (assumption-id-n aid-0) 0
                  "Test precondition: solver-state-assume returns aid-0 first")

    ;; Invoke wrapper with branch-aid-set = (seteq aid-0); request-info has tm-cid
    (define request-info (hasheq 'tm-cid tm-cell))
    (define chain
      (derivation-chain-for/union-contradict net4 (seteq aid-0) request-info))

    (check-true (derivation-chain? chain) "Returns derivation-chain struct")
    (define steps (derivation-chain-steps chain))
    (check-equal? (length steps) 1 "1 step in chain (1 matching propagator)")
    (define step (car steps))
    ;; Step has aid-0 decoded
    (check-equal? (derivation-step-assumption-ids step) (list aid-0)
                  "Step's assumption-ids = (list aid-0)")
    ;; Names ENRICHED: prefers string datum ("branch-0-at-position-X")
    (check-equal? (derivation-step-assumption-names step) (list "branch-0-at-position-X")
                  "Step's assumption-names populated with string datum (D-3C.b-1 mitigation)")
    ;; Residual-cost stays #f per Q-B.4 (defer to 3C.d)
    (check-false (derivation-step-residual-cost step)
                 "Residual-cost stays #f (deferred to 3C.d per Q-B.4)")))

;; ========================================
;; T-B.2 — Wrapper falls back to symbol name when datum is non-string
;; ========================================
;;
;; Verifies D-3C.b-1 mitigation: when assumption-datum is NOT a string
;; (e.g., context assumption per elab-speculation-bridge.rkt:164 stores
;; descriptive non-string values), wrapper falls back to formatting the
;; name symbol.

(test-case "T-B.2: derivation-chain-for/union-contradict — falls back to name symbol when datum is non-string"
  (define net0 (make-prop-network))
  (define-values (net1 cell-input) (net-new-cell net0 'bot tagged-aware-flat-merge))
  (define-values (net2 tm-cell) (net-new-cell net1 'bot tagged-aware-flat-merge))
  (define-values (net3 _pid)
    (net-add-propagator net2 (list cell-input) (list tm-cell) (lambda (n) n)))
  (define tagged-val (tagged-cell-value 'base (list (cons #b001 'val))))
  (define net4 (net-cell-write net3 tm-cell tagged-val))

  (parameterize ([current-command-atms (box (make-solver-state (make-prop-network)))])
    (define atms-box (current-command-atms))
    ;; Datum is a symbol (NOT a string) — simulates context assumption pattern
    (define-values (atms* aid-0)
      (solver-state-assume (unbox atms-box) 'def-type-annotation 'some-non-string-datum))
    (set-box! atms-box atms*)

    (define request-info (hasheq 'tm-cid tm-cell))
    (define chain
      (derivation-chain-for/union-contradict net4 (seteq aid-0) request-info))
    (define step (car (derivation-chain-steps chain)))
    ;; Names fall back to formatting the name symbol
    (check-equal? (derivation-step-assumption-names step) (list "def-type-annotation")
                  "Step's assumption-names = list with name symbol formatted (datum non-string fallback)")))

;; ========================================
;; T-B.3 — Wrapper filters out propagators whose aids don't intersect aid-set
;; ========================================
;;
;; Verifies filter-fn semantic: only steps whose aids intersect branch-aid-set
;; are included. D-3C.b-5 verified — filter applies BEFORE recursion, pruning
;; walk through unrelated propagators.

(test-case "T-B.3: derivation-chain-for/union-contradict — filter excludes non-matching aid steps"
  (define net0 (make-prop-network))
  (define-values (net1 cell-input) (net-new-cell net0 'bot tagged-aware-flat-merge))
  (define-values (net2 cell-a) (net-new-cell net1 'bot tagged-aware-flat-merge))
  (define-values (net3 tm-cell) (net-new-cell net2 'bot tagged-aware-flat-merge))
  ;; P1: cell-input → cell-a; tagged with aid-99 (NOT in branch-aid-set)
  (define-values (net4 _pid-1)
    (net-add-propagator net3 (list cell-input) (list cell-a) (lambda (n) n)))
  ;; P2: cell-a → tm-cell; tagged with aid-0 (IN branch-aid-set)
  (define-values (net5 _pid-2)
    (net-add-propagator net4 (list cell-a) (list tm-cell) (lambda (n) n)))
  ;; cell-a tagged with aid-99 bit (bit 99 would overflow 30-bit; use bit 5 as non-zero non-matching)
  (define net6 (net-cell-write net5 cell-a (tagged-cell-value 'base (list (cons #b100000 'val)))))
  ;; tm-cell tagged with aid-0 bit
  (define net7 (net-cell-write net6 tm-cell (tagged-cell-value 'base (list (cons #b001 'val)))))

  (parameterize ([current-command-atms (box (make-solver-state (make-prop-network)))])
    (define atms-box (current-command-atms))
    (define-values (atms* aid-0)
      (solver-state-assume (unbox atms-box) 'h0 "branch-0"))
    (set-box! atms-box atms*)

    (define request-info (hasheq 'tm-cid tm-cell))
    (define chain
      (derivation-chain-for/union-contradict net7 (seteq aid-0) request-info))
    (define steps (derivation-chain-steps chain))
    ;; Only P2 (aid-0-tagged) included; P1 (aid-5-tagged) excluded by filter
    ;; AND walk pruned at P1 → cell-input doesn't get visited
    (check-equal? (length steps) 1
                  "Chain has only 1 step (P2 matching aid-0); P1 (aid-5) filtered + walk pruned")))

;; ========================================
;; T-B.4 — Defensive: missing tm-cid returns empty chain
;; ========================================

(test-case "T-B.4: derivation-chain-for/union-contradict — defensive on missing tm-cid"
  (define net (make-prop-network))
  (parameterize ([current-command-atms (box (make-solver-state (make-prop-network)))])
    (define request-info (hasheq))  ;; NO 'tm-cid key
    (define chain
      (derivation-chain-for/union-contradict net (seteq) request-info))
    (check-true (derivation-chain? chain) "Returns derivation-chain struct")
    (check-equal? (derivation-chain-steps chain) '()
                  "Empty chain when tm-cid missing from request-info")))

;; ========================================
;; T-B.5 — Defensive: no current-command-atms set → empty assumption-names
;; ========================================
;;
;; Wrapper degrades gracefully when ATMS is not active (returns synthetic
;; "aid-N" names via decode-aid-name fallback at decode point).

(test-case "T-B.5: derivation-chain-for/union-contradict — graceful when no ATMS active"
  (define net0 (make-prop-network))
  (define-values (net1 cell-input) (net-new-cell net0 'bot tagged-aware-flat-merge))
  (define-values (net2 tm-cell) (net-new-cell net1 'bot tagged-aware-flat-merge))
  (define-values (net3 _pid)
    (net-add-propagator net2 (list cell-input) (list tm-cell) (lambda (n) n)))
  (define net4 (net-cell-write net3 tm-cell (tagged-cell-value 'base (list (cons #b001 'val)))))

  ;; NO parameterize — current-command-atms = #f
  (define aid-0 (assumption-id 0))
  (define request-info (hasheq 'tm-cid tm-cell))
  (define chain
    (derivation-chain-for/union-contradict net4 (seteq aid-0) request-info))
  (define step (car (derivation-chain-steps chain)))
  ;; Names fall back to synthetic "aid-N" format (decode-aid-name no-asn branch)
  (check-equal? (derivation-step-assumption-names step) (list "aid-0")
                "Empty assumptions hash → decode falls back to \"aid-N\" format"))

;; ============================================================
;; PPN 4C Phase 3C.c.1 (2026-05-24): derivation-chain-for/union-check
;; ============================================================
;;
;; Tests for sexp-mode translator wrapper. Direct parallel to retired
;; build-derivation-chain (typing-errors.rkt:127); takes sub-failures list
;; (children of latest speculation-failure at branch's check); returns
;; derivation-chain struct.
;;
;; Per §9.5.4.5.1 audit lock (α): sub-failures input matches retired
;; function shape; atomic case (empty sub-failures) returns empty chain
;; (UX parity with today); nested case (populated sub-failures) returns
;; flattened DFS pre-order chain.
;;
;; Field mapping per speculation-failure → derivation-step:
;;   propagator-id    — #f (sexp has no propagator)
;;   srcloc           — #f (D-3C.c-1 capture for Phase 11b / Track 4D)
;;   assumption-ids   — (list hypothesis-id) or '() when hyp-id #f
;;   assumption-names — decoded via decode-aid-name (string-datum preferred);
;;                      fallback to (list speculation-failure-label) when no aid
;;   residual-cost    — #f (3C.d may populate via tropical annotation)

;; ========================================
;; T-C.c-1.1 — Empty input handling (#f + '())
;; ========================================

(test-case "T-C.c-1.1a: derivation-chain-for/union-check — #f input returns empty chain"
  (define chain (derivation-chain-for/union-check #f))
  (check-true (derivation-chain? chain))
  (check-equal? (derivation-chain-steps chain) '()
                "Empty chain for #f input (defensive — graceful degradation)"))

(test-case "T-C.c-1.1b: derivation-chain-for/union-check — '() input returns empty chain"
  (define chain (derivation-chain-for/union-check '()))
  (check-true (derivation-chain? chain))
  (check-equal? (derivation-chain-steps chain) '()
                "Empty chain for '() input (matches today's build-derivation-chain semantic for atomic checks)"))

;; ========================================
;; T-C.c-1.2 — Single sub-failure WITH aid + ATMS (string datum)
;; ========================================
;;
;; Verifies the with-speculative-rollback consumer shape: assumption-name is
;; a symbol (`(string->symbol label)`), assumption-datum is the label string.
;; decode-aid-name returns the string-datum (the label) via string-preference
;; path. This matches sexp speculation's actual behavior at
;; elab-speculation-bridge.rkt:213-217.

(test-case "T-C.c-1.2: single sub-failure with aid → string-datum name decoded"
  (parameterize ([current-command-atms (box (make-solver-state (make-prop-network)))])
    (define atms-box (current-command-atms))
    ;; Mirror with-speculative-rollback: name=string->symbol of label, datum=label
    (define-values (atms* aid-0)
      (solver-state-assume (unbox atms-box) 'union-branch-Nat "union-branch-Nat"))
    (set-box! atms-box atms*)

    ;; Single speculation-failure with the aid; no nested sub-failures
    (define sf (speculation-failure "union-branch-Nat" aid-0 #f '()))
    (define chain (derivation-chain-for/union-check (list sf)))

    (check-true (derivation-chain? chain))
    (define steps (derivation-chain-steps chain))
    (check-equal? (length steps) 1 "Single step from single speculation-failure")
    (define step (car steps))
    (check-false (derivation-step-propagator-id step) "propagator-id = #f for sexp")
    (check-false (derivation-step-srcloc step) "srcloc = #f for sexp (D-3C.c-1)")
    (check-equal? (derivation-step-assumption-ids step) (list aid-0))
    (check-equal? (derivation-step-assumption-names step) (list "union-branch-Nat")
                  "Name decoded via string-datum preference (matches with-speculative-rollback consumer pattern)")
    (check-false (derivation-step-residual-cost step) "residual-cost = #f")))

;; ========================================
;; T-C.c-1.3 — Single sub-failure WITHOUT aid (hyp-id=#f)
;; ========================================
;;
;; Defensive case: speculation-failure with hypothesis-id=#f. Wouldn't arise
;; under with-speculative-rollback (which always passes hyp-id) but possible
;; for direct record-speculation-failure! callers. Fallback to label string.

(test-case "T-C.c-1.3: single sub-failure without aid → label fallback"
  (define sf (speculation-failure "manual-label" #f #f '()))
  (define chain (derivation-chain-for/union-check (list sf)))
  (check-true (derivation-chain? chain))
  (define steps (derivation-chain-steps chain))
  (check-equal? (length steps) 1)
  (define step (car steps))
  (check-equal? (derivation-step-assumption-ids step) '()
                "Empty aids when hypothesis-id is #f")
  (check-equal? (derivation-step-assumption-names step) (list "manual-label")
                "Name falls back to speculation-failure-label when no aid"))

;; ========================================
;; T-C.c-1.4 — Nested speculation tree (depth 2)
;; ========================================
;;
;; Verifies DFS pre-order flatten: parent failure first, then nested children.
;; This is the structurally-rich case where chain captures the speculation
;; tree (vs atomic case where chain is empty).

(test-case "T-C.c-1.4: nested sub-failure (depth 2) → DFS pre-order [parent, child]"
  (define child (speculation-failure "child-label" #f #f '()))
  (define parent (speculation-failure "parent-label" #f #f (list child)))
  (define chain (derivation-chain-for/union-check (list parent)))
  (define steps (derivation-chain-steps chain))
  (check-equal? (length steps) 2 "2 steps: parent + child")
  ;; DFS pre-order: parent first (head of list), then child
  (check-equal? (derivation-step-assumption-names (first steps))
                (list "parent-label")
                "First step is parent (label fallback — no aid)")
  (check-equal? (derivation-step-assumption-names (second steps))
                (list "child-label")
                "Second step is child"))

;; ========================================
;; T-C.c-1.5 — Multi-root forest with deeper nesting (depth 3, branching)
;; ========================================
;;
;; Forest:
;;   ROOT-A: label="A" → sub: [A1, A2]
;;     A1: label="A1" → sub: [A1.1]
;;       A1.1: label="A1.1" → sub: []
;;     A2: label="A2" → sub: []
;;   ROOT-B: label="B" → sub: []
;;
;; DFS pre-order across forest: [A, A1, A1.1, A2, B]

(test-case "T-C.c-1.5: multi-root forest with depth 3 → DFS pre-order across all"
  (define a1.1 (speculation-failure "A1.1" #f #f '()))
  (define a1 (speculation-failure "A1" #f #f (list a1.1)))
  (define a2 (speculation-failure "A2" #f #f '()))
  (define root-a (speculation-failure "A" #f #f (list a1 a2)))
  (define root-b (speculation-failure "B" #f #f '()))

  (define chain (derivation-chain-for/union-check (list root-a root-b)))
  (define steps (derivation-chain-steps chain))
  (check-equal? (length steps) 5 "5 steps total across forest")
  ;; Names in DFS pre-order across forest
  (define names (map (lambda (s) (car (derivation-step-assumption-names s))) steps))
  (check-equal? names '("A" "A1" "A1.1" "A2" "B")
                "DFS pre-order traversal: root-A first, then its sub-tree (A1, A1.1, A2), then root-B"))

;; ========================================
;; T-C.c-1.6 — Defensive: no ATMS active (current-command-atms=#f)
;; ========================================
;;
;; Verifies graceful degradation when ATMS isn't active: aid lookup falls
;; back to "aid-N" format via decode-aid-name's no-asn branch.

(test-case "T-C.c-1.6: no ATMS active → aid name falls back to \"aid-N\""
  ;; NO parameterize — current-command-atms = #f
  (define aid-0 (assumption-id 0))
  (define sf (speculation-failure "atomic-label" aid-0 #f '()))
  (define chain (derivation-chain-for/union-check (list sf)))
  (define step (car (derivation-chain-steps chain)))
  (check-equal? (derivation-step-assumption-ids step) (list aid-0))
  (check-equal? (derivation-step-assumption-names step) (list "aid-0")
                "Empty assumptions hash → decode falls back to \"aid-N\" format"))

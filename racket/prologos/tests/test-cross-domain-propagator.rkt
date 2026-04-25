#lang racket/base

;;;
;;; Tests for Phase 6c: Cross-Domain Propagation (Racket level)
;;; Tests: alpha/gamma directions, bidirectional, no-change guard,
;;; BSP compatibility, chains/diamonds.
;;;

(require rackunit
         racket/list
         "../propagator.rkt"
         "../champ.rkt")

;; ========================================
;; Domain Helpers
;; ========================================

;; "Interval-like" concrete domain (max-merge, numbers)
(define (max-merge old new) (max old new))

;; "Bool-like" abstract domain (or-merge, #f = bot)
(define (or-merge old new) (or old new))

;; Interval→Bool alpha: 0 = unconstrained (false), anything else = constrained (true)
(define (iv-alpha val)
  (not (= val 0)))

;; Bool→Interval gamma: false = 0 (unconstrained), true = +inf.0 (most constrained)
(define (iv-gamma val)
  (if val +inf.0 0))

;; ========================================
;; 1. Alpha Direction: C → A
;; ========================================

(test-case "alpha propagation: c-cell change updates a-cell"
  (define net0 (make-prop-network 100))
  (define-values (net1 c-cell) (net-new-cell net0 0 max-merge))
  (define-values (net2 a-cell) (net-new-cell net1 #f or-merge))
  (define-values (net3 _p-alpha _p-gamma)
    (net-add-cross-domain-propagator net2 c-cell a-cell iv-alpha iv-gamma))
  ;; Write 42 to c-cell
  (define net4 (net-cell-write net3 c-cell 42))
  (define result (run-to-quiescence net4))
  ;; a-cell should be #t (alpha(42) = true)
  (check-equal? (net-cell-read result a-cell) #t))

;; ========================================
;; 2. Gamma Direction: A → C
;; ========================================

(test-case "gamma propagation: a-cell change updates c-cell"
  (define net0 (make-prop-network 100))
  (define-values (net1 c-cell) (net-new-cell net0 0 max-merge))
  (define-values (net2 a-cell) (net-new-cell net1 #f or-merge))
  (define-values (net3 _p-alpha _p-gamma)
    (net-add-cross-domain-propagator net2 c-cell a-cell iv-alpha iv-gamma))
  ;; Write #t to a-cell
  (define net4 (net-cell-write net3 a-cell #t))
  (define result (run-to-quiescence net4))
  ;; c-cell should be +inf.0 (gamma(true) = +inf.0, max(0, +inf.0) = +inf.0)
  (check-equal? (net-cell-read result c-cell) +inf.0))

;; ========================================
;; 3. Bidirectional
;; ========================================

(test-case "bidirectional: c-cell write propagates to a-cell and back stabilizes"
  (define net0 (make-prop-network 100))
  (define-values (net1 c-cell) (net-new-cell net0 0 max-merge))
  (define-values (net2 a-cell) (net-new-cell net1 #f or-merge))
  (define-values (net3 _p-alpha _p-gamma)
    (net-add-cross-domain-propagator net2 c-cell a-cell iv-alpha iv-gamma))
  ;; Write 42 to c-cell
  (define net4 (net-cell-write net3 c-cell 42))
  (define result (run-to-quiescence net4))
  ;; a-cell = true, c-cell = max(42, gamma(true)) = max(42, +inf.0) = +inf.0
  (check-equal? (net-cell-read result a-cell) #t)
  (check-equal? (net-cell-read result c-cell) +inf.0)
  ;; Should not exhaust fuel (converges quickly)
  (check-true (> (prop-network-fuel result) 50)))

;; ========================================
;; 4. No-Change Guard
;; ========================================

(test-case "no-change: writing same value doesn't trigger propagation"
  (define net0 (make-prop-network 100))
  (define-values (net1 c-cell) (net-new-cell net0 0 max-merge))
  (define-values (net2 a-cell) (net-new-cell net1 #f or-merge))
  (define-values (net3 _p-alpha _p-gamma)
    (net-add-cross-domain-propagator net2 c-cell a-cell iv-alpha iv-gamma))
  ;; Write 0 to c-cell (same as init) → alpha(0) = false, same as a-cell init
  (define net4 (net-cell-write net3 c-cell 0))
  (define result (run-to-quiescence net4))
  ;; Nothing should change
  (check-equal? (net-cell-read result c-cell) 0)
  (check-equal? (net-cell-read result a-cell) #f))

;; ========================================
;; 5. Chain Topology: C1 → A1 → C2
;; ========================================

(test-case "chain: two cross-domain connections in sequence"
  ;; C1 ←→ A1, then A1 → C2 via a copy propagator
  (define net0 (make-prop-network 200))
  (define-values (net1 c1) (net-new-cell net0 0 max-merge))
  (define-values (net2 a1) (net-new-cell net1 #f or-merge))
  (define-values (net3 c2) (net-new-cell net2 0 max-merge))
  ;; Cross-domain: C1 ←→ A1
  (define-values (net4 _p1 _p2)
    (net-add-cross-domain-propagator net3 c1 a1 iv-alpha iv-gamma))
  ;; Copy: A1 → C2 (if a1 is true, write 999 to c2)
  (define-values (net5 _p3)
    (net-add-propagator net4
      (list a1) (list c2)
      (lambda (net)
        (if (net-cell-read net a1)
            (net-cell-write net c2 999)
            net))))
  ;; Trigger: write 42 to C1
  (define net6 (net-cell-write net5 c1 42))
  (define result (run-to-quiescence net6))
  ;; C1=42→alpha→A1=true→copy→C2=999
  ;; Plus gamma(true)=+inf.0 back to C1
  (check-equal? (net-cell-read result a1) #t)
  (check-equal? (net-cell-read result c2) 999)
  (check-equal? (net-cell-read result c1) +inf.0))

;; ========================================
;; 6. Diamond Topology: C ←→ A1, C ←→ A2
;; ========================================

(test-case "diamond: one concrete cell connected to two abstract cells"
  ;; Two different abstractions of the same concrete cell
  (define net0 (make-prop-network 200))
  (define-values (net1 c-cell) (net-new-cell net0 0 max-merge))
  (define-values (net2 a1) (net-new-cell net1 #f or-merge))
  (define-values (net3 a2) (net-new-cell net2 0 max-merge))
  ;; Alpha1: 0→false, else→true (Bool abstraction)
  (define-values (net4 _pa1 _pg1)
    (net-add-cross-domain-propagator net3 c-cell a1 iv-alpha iv-gamma))
  ;; Alpha2: identity (numeric abstraction)
  (define-values (net5 _pa2 _pg2)
    (net-add-cross-domain-propagator net4 c-cell a2
      (lambda (v) v)      ;; alpha = identity
      (lambda (v) v)))    ;; gamma = identity
  ;; Write 42 to c-cell
  (define net6 (net-cell-write net5 c-cell 42))
  (define result (run-to-quiescence net6))
  ;; a1 = true (Bool abstraction), a2 = max(42, +inf.0) = +inf.0
  ;; c-cell = max(42, gamma(true), +inf.0) = +inf.0
  (check-equal? (net-cell-read result a1) #t)
  (check-equal? (net-cell-read result c-cell) +inf.0))

;; ========================================
;; 7. BSP Compatibility
;; ========================================

(test-case "cross-domain works with BSP scheduler"
  (define net0 (make-prop-network 200))
  (define-values (net1 c-cell) (net-new-cell net0 0 max-merge))
  (define-values (net2 a-cell) (net-new-cell net1 #f or-merge))
  (define-values (net3 _p1 _p2)
    (net-add-cross-domain-propagator net2 c-cell a-cell iv-alpha iv-gamma))
  (define net4 (net-cell-write net3 c-cell 10))
  (define result (run-to-quiescence-bsp net4))
  (check-equal? (net-cell-read result a-cell) #t)
  (check-equal? (net-cell-read result c-cell) +inf.0))

;; ========================================
;; 8. With Widening
;; ========================================

(test-case "cross-domain with widening-aware fixpoint"
  (define net0 (make-prop-network 200))
  (define (simple-widen old new) (if (> new old) +inf.0 new))
  (define (simple-narrow old new) (min old new))
  (define-values (net1 c-cell)
    (net-new-cell-widen net0 0 max-merge simple-widen simple-narrow))
  (define-values (net2 a-cell) (net-new-cell net1 #f or-merge))
  (define-values (net3 _p1 _p2)
    (net-add-cross-domain-propagator net2 c-cell a-cell iv-alpha iv-gamma))
  (define net4 (net-cell-write net3 c-cell 10))
  (define result (run-to-quiescence-widen net4))
  (check-equal? (net-cell-read result a-cell) #t))

;; ========================================
;; 8. Component-paths kwargs (PPN 4C S2.precursor, 2026-04-24)
;; ========================================
;;
;; Verify the new kwargs (#:c-component-paths, #:a-component-paths,
;; #:assumption, #:decision-cell, #:srcloc) are accepted and forwarded
;; to the underlying net-add-propagator calls without breaking existing
;; behavior. Behavioral component-path FILTERING under universe cells
;; is tested for real in S2.c-v (when actual universe-cell migration
;; lands); here we verify the contract: kwargs accepted, defaults
;; preserve backward compat, the bridge functions correctly with them.

(test-case "S2.precursor: existing callers without kwargs work unchanged"
  ;; Backward compat: the most common pattern (no kwargs) must produce
  ;; the same behavior as pre-precursor. Mirror test-case 1.
  (define net0 (make-prop-network 100))
  (define-values (net1 c-cell) (net-new-cell net0 0 max-merge))
  (define-values (net2 a-cell) (net-new-cell net1 #f or-merge))
  (define-values (net3 _p-alpha _p-gamma)
    (net-add-cross-domain-propagator net2 c-cell a-cell iv-alpha iv-gamma))
  (define net4 (net-cell-write net3 c-cell 42))
  (define result (run-to-quiescence net4))
  (check-equal? (net-cell-read result a-cell) #t))

(test-case "S2.precursor: kwargs accepted; bridge fires correctly with empty paths"
  ;; Pass empty-list paths explicitly + null assumption — equivalent to defaults.
  ;; Must produce same behavior as no-kwargs case.
  (define net0 (make-prop-network 100))
  (define-values (net1 c-cell) (net-new-cell net0 0 max-merge))
  (define-values (net2 a-cell) (net-new-cell net1 #f or-merge))
  (define-values (net3 _p-alpha _p-gamma)
    (net-add-cross-domain-propagator net2 c-cell a-cell iv-alpha iv-gamma
      #:c-component-paths '()
      #:a-component-paths '()
      #:assumption #f
      #:decision-cell #f
      #:srcloc #f))
  (define net4 (net-cell-write net3 c-cell 42))
  (define result (run-to-quiescence net4))
  (check-equal? (net-cell-read result a-cell) #t))

(test-case "S2.c-iv: kwargs accepted with non-default values; bridge installs (UPDATED for tightened contract)"
  ;; Pass non-default values for path kwargs. Under S2.c-iv's tightened
  ;; contract (correct-by-construction for compound cells), declaring
  ;; component-paths means compound-keyed access. The primitive uses
  ;; compound-cell-component-{ref,write}/pnet for the declared sides.
  ;;
  ;; This test passes cons-pair component-paths for a NON-compound cell
  ;; (max-merge cell holding integer 0). Under S2.c-iv, the primitive
  ;; honors the declaration: it tries compound-keyed access; the cell
  ;; value isn't a hasheq → read returns #f → α doesn't propagate.
  ;; This is the CORRECT contract behavior — declaring component-paths
  ;; commits to compound access; misusing on a non-compound cell is
  ;; visible as no-propagation, not silent whole-cell read/write.
  (define net0 (make-prop-network 100))
  (define-values (net1 c-cell) (net-new-cell net0 0 max-merge))
  (define-values (net2 a-cell) (net-new-cell net1 #f or-merge))
  (define-values (net3 pid-alpha pid-gamma)
    (net-add-cross-domain-propagator net2 c-cell a-cell iv-alpha iv-gamma
      #:c-component-paths (list (cons c-cell 'some-key))
      #:a-component-paths (list (cons a-cell 'other-key))))
  ;; Both propagator IDs valid — install succeeded
  (check-not-false pid-alpha)
  (check-not-false pid-gamma)
  ;; Under S2.c-iv: declaring component-paths means compound-keyed access.
  ;; c-cell isn't a hasheq → compound-cell-component-ref returns #f →
  ;; α's `(cond [(not c-val) net] ...)` skips propagation. a-cell stays #f.
  ;; (Pre-S2.c-iv backward-compat: paths were inert; α fired with whole-
  ;; cell read; a-cell became #t. That permissive behavior was the gap
  ;; that S2.c-iv's CBC contract closes.)
  (define net4 (net-cell-write net3 c-cell 42))
  (define result (run-to-quiescence net4))
  (check-equal? (net-cell-read result a-cell) #f))

(test-case "S2.c-iv: gamma-fn = #f → α-only bridge install"
  ;; When γ direction is dead work (e.g., type↔mult bridge's mult->type-gamma
  ;; was constant type-bot — retired in S2.c-iv), pass gamma-fn=#f to skip
  ;; the γ propagator install entirely. Returns (values net pid-alpha #f).
  (define net0 (make-prop-network 100))
  (define-values (net1 c-cell) (net-new-cell net0 0 max-merge))
  (define-values (net2 a-cell) (net-new-cell net1 #f or-merge))
  (define-values (net3 pid-alpha pid-gamma)
    (net-add-cross-domain-propagator net2 c-cell a-cell iv-alpha #f))
  ;; α installed (non-#f), γ skipped (#f)
  (check-not-false pid-alpha)
  (check-equal? pid-gamma #f)
  ;; α direction works as expected — write to c-cell propagates
  (define net4 (net-cell-write net3 c-cell 42))
  (define result (run-to-quiescence net4))
  (check-equal? (net-cell-read result a-cell) #t))

(test-case "S2.c-iv: extract-bridge-component-key validates path shape"
  ;; The primitive validates component-paths at install time:
  ;;   '() — non-compound; raw access
  ;;   (list (cons cell-id key)) — compound; component-keyed
  ;;   (list bare-key) — error (S2.b-iv §7.5.12.5 deprecation)
  ;;   (list path1 path2) — error (single-key restriction; multi-component
  ;;     bridges should compose multiple primitive installs)
  (define net0 (make-prop-network 100))
  (define-values (net1 c-cell) (net-new-cell net0 0 max-merge))
  (define-values (net2 a-cell) (net-new-cell net1 #f or-merge))
  ;; Bare-key path → error
  (check-exn exn:fail?
    (lambda ()
      (net-add-cross-domain-propagator net2 c-cell a-cell iv-alpha iv-gamma
        #:c-component-paths (list 'bare-key))))
  ;; Multi-path → error
  (check-exn exn:fail?
    (lambda ()
      (net-add-cross-domain-propagator net2 c-cell a-cell iv-alpha iv-gamma
        #:c-component-paths (list (cons c-cell 'k1) (cons c-cell 'k2))))))

(test-case "S2.c-iv: cons-pair cell-id mismatch → error at install"
  ;; If the cons-pair path declares a cell-id that doesn't match the
  ;; bridge's c-cell or a-cell, the primitive errors at install time.
  ;; Catches caller-side declaration mistakes early.
  (define net0 (make-prop-network 100))
  (define-values (net1 c-cell) (net-new-cell net0 0 max-merge))
  (define-values (net2 a-cell) (net-new-cell net1 #f or-merge))
  (define-values (net3 wrong-cell) (net-new-cell net2 0 max-merge))
  (check-exn exn:fail?
    (lambda ()
      (net-add-cross-domain-propagator net3 c-cell a-cell iv-alpha iv-gamma
        ;; Declaring path against wrong-cell, not c-cell — error
        #:c-component-paths (list (cons wrong-cell 'some-key))))))

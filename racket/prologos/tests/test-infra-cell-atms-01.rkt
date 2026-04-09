#lang racket/base

;;;
;;; test-infra-cell-atms-01.rkt — Tests for ATMS assumption bridge in infra-cell.rkt
;;;
;;; Phase 0b of the Propagator-First Migration Sprint.
;;; Tests assumption lifecycle, assumed cell operations, retraction, and commit.
;;;

(require rackunit
         racket/set
         "../propagator.rkt"
         "../atms.rkt"
         "../decision-cell.rkt"
         "../infra-cell.rkt")

;; Helper: build the "believed" set from a solver-state's decisions cell.
;; Returns hasheq: assumption-id -> #t for all committed (non-narrowed) assumptions.
(define (solver-state-believed ss)
  (define dec-cid (solver-context-decisions-cid (solver-state-ctx ss)))
  (define ds (net-cell-read-raw (solver-state-net ss) dec-cid))
  (if (decisions-state? ds)
      (for/fold ([acc (hasheq)]) ([(_gid dv) (in-hash (decisions-state-components ds))])
        (if (decision-committed? dv)
            (hash-set acc (decision-committed-assumption dv) #t)
            acc))
      (hasheq)))

;; ========================================
;; infra-state Construction
;; ========================================

(test-case "make-infra-state: creates fresh state"
  (define is (make-infra-state))
  (check-true (infra-state? is))
  (check-true (solver-state? (infra-state-atms is)))
  (check-equal? (infra-state-names is) (hasheq)))

(test-case "make-infra-state: wraps existing prop-network"
  (define net (make-prop-network 5000))
  (define is (make-infra-state net))
  (check-equal? (prop-network-fuel (solver-state-net (infra-state-atms is))) 5000))

(test-case "make-infra-state: with initial names"
  (define names (hasheq 'foo (cell-id 0)))
  (define is (make-infra-state #f names))
  (check-true (net-has-named-cell? (infra-state-names is) 'foo)))

;; ========================================
;; Assumption Lifecycle
;; ========================================

(test-case "infra-assume: creates assumption and returns aid"
  (define is0 (make-infra-state))
  (define-values (is1 aid) (infra-assume is0 'test-assumption))
  (check-true (assumption-id? aid))
  ;; Assumption should be in the believed set
  (check-true (hash-has-key? (solver-state-believed (infra-state-atms is1)) aid)))

(test-case "infra-assume: multiple assumptions coexist"
  (define is0 (make-infra-state))
  (define-values (is1 aid1) (infra-assume is0 'first))
  (define-values (is2 aid2) (infra-assume is1 'second))
  (check-not-equal? aid1 aid2)
  (check-true (hash-has-key? (solver-state-believed (infra-state-atms is2)) aid1))
  (check-true (hash-has-key? (solver-state-believed (infra-state-atms is2)) aid2)))

(test-case "infra-retract: removes assumption from believed"
  (define is0 (make-infra-state))
  (define-values (is1 aid) (infra-assume is0 'temp))
  (define is2 (infra-retract is1 aid))
  (check-false (hash-has-key? (solver-state-believed (infra-state-atms is2)) aid)))

(test-case "infra-commit: is a no-op (assumption stays believed)"
  (define is0 (make-infra-state))
  (define-values (is1 aid) (infra-assume is0 'persistent))
  (define is2 (infra-commit is1 aid))
  (check-true (hash-has-key? (solver-state-believed (infra-state-atms is2)) aid)))

;; ========================================
;; Assumed Cell Write + Read
;; ========================================

(test-case "infra-write-assumed + infra-read-believed roundtrip"
  (define is0 (make-infra-state))
  (define-values (is1 aid) (infra-assume is0 'cmd-1))
  (define is2 (infra-write-assumed is1 'global:foo 42 aid))
  (check-equal? (infra-read-believed is2 'global:foo) 42))

(test-case "infra-read-believed: returns infra-bot for unwritten cell"
  (define is0 (make-infra-state))
  (check-equal? (infra-read-believed is0 'nonexistent) 'infra-bot))

(test-case "infra-write-assumed: uses current-infra-assumption parameter"
  (define is0 (make-infra-state))
  (define-values (is1 aid) (infra-assume is0 'auto-scope))
  (define is2
    (parameterize ([current-infra-assumption aid])
      (infra-write-assumed is1 'my-cell 'hello)))
  (check-equal? (infra-read-believed is2 'my-cell) 'hello))

(test-case "infra-write-assumed: errors without active assumption"
  (check-exn exn:fail?
    (lambda ()
      (define is0 (make-infra-state))
      (infra-write-assumed is0 'cell 'val))))

;; ========================================
;; Retraction Semantics
;; ========================================

(test-case "retracted assumption: value persists (solver-state last-write-wins)"
  ;; In solver-state model, retraction narrows the decision component but
  ;; does NOT hide written cell values (no per-value assumption tagging).
  (define is0 (make-infra-state))
  (define-values (is1 aid) (infra-assume is0 'temp-def))
  (define is2 (infra-write-assumed is1 'def:collatz 'collatz-fn aid))
  ;; Value visible before retraction
  (check-equal? (infra-read-believed is2 'def:collatz) 'collatz-fn)
  ;; Retract — decision narrowed but cell value persists
  (define is3 (infra-retract is2 aid))
  (check-equal? (infra-read-believed is3 'def:collatz) 'collatz-fn)
  ;; Assumption is no longer in believed set
  (check-false (hash-has-key? (solver-state-believed (infra-state-atms is3)) aid)))

(test-case "retraction of one assumption: both values persist (last-write-wins)"
  ;; In solver-state model, values persist after retraction (no TMS filtering).
  (define is0 (make-infra-state))
  (define-values (is1 aid1) (infra-assume is0 'cmd-1))
  (define-values (is2 aid2) (infra-assume is1 'cmd-2))
  (define is3 (infra-write-assumed is2 'def:foo 'foo-v1 aid1))
  (define is4 (infra-write-assumed is3 'def:bar 'bar-v1 aid2))
  ;; Both visible
  (check-equal? (infra-read-believed is4 'def:foo) 'foo-v1)
  (check-equal? (infra-read-believed is4 'def:bar) 'bar-v1)
  ;; Retract only aid2 — values persist, but aid2 not in believed set
  (define is5 (infra-retract is4 aid2))
  (check-equal? (infra-read-believed is5 'def:foo) 'foo-v1)
  (check-equal? (infra-read-believed is5 'def:bar) 'bar-v1)
  ;; Verify assumption state
  (check-true (hash-has-key? (solver-state-believed (infra-state-atms is5)) aid1))
  (check-false (hash-has-key? (solver-state-believed (infra-state-atms is5)) aid2)))

(test-case "multiple values on same cell — last write wins (solver-state)"
  ;; In solver-state model, writes are last-write-wins. No TMS multi-value.
  (define is0 (make-infra-state))
  (define-values (is1 aid1) (infra-assume is0 'v1))
  (define-values (is2 aid2) (infra-assume is1 'v2))
  ;; Write v1 under aid1, then v2 under aid2 to same cell
  (define is3 (infra-write-assumed is2 'def:x 'value-1 aid1))
  (define is4 (infra-write-assumed is3 'def:x 'value-2 aid2))
  ;; Latest write (value-2) wins
  (check-equal? (infra-read-believed is4 'def:x) 'value-2)
  ;; Retract aid2 — value-2 STILL wins (last-write-wins, no TMS retraction)
  (define is5 (infra-retract is4 aid2))
  (check-equal? (infra-read-believed is5 'def:x) 'value-2))

(test-case "retract and re-assume: new write overwrites old (last-write-wins)"
  ;; In solver-state model, retraction doesn't hide values. New write overwrites.
  (define is0 (make-infra-state))
  (define-values (is1 aid1) (infra-assume is0 'round-1))
  (define is2 (infra-write-assumed is1 'def:y 'old-val aid1))
  ;; Retract — value persists (no TMS hiding)
  (define is3 (infra-retract is2 aid1))
  (check-equal? (infra-read-believed is3 'def:y) 'old-val)
  ;; New assumption + new write overwrites
  (define-values (is4 aid2) (infra-assume is3 'round-2))
  (define is5 (infra-write-assumed is4 'def:y 'new-val aid2))
  (check-equal? (infra-read-believed is5 'def:y) 'new-val))

;; ========================================
;; Nested Assumptions (Speculation)
;; ========================================

(test-case "nested assumptions: both values persist after inner retraction"
  ;; In solver-state model, retraction narrows decision but doesn't hide cell values.
  (define is0 (make-infra-state))
  ;; Outer assumption (per-command)
  (define-values (is1 outer-aid) (infra-assume is0 'per-command))
  (define is2 (infra-write-assumed is1 'def:base 'base-val outer-aid))
  ;; Inner assumption (speculation)
  (define-values (is3 spec-aid) (infra-assume is2 'speculation))
  (define is4 (infra-write-assumed is3 'def:spec 'spec-val spec-aid))
  ;; Both visible
  (check-equal? (infra-read-believed is4 'def:base) 'base-val)
  (check-equal? (infra-read-believed is4 'def:spec) 'spec-val)
  ;; Retract speculation — values persist, assumption state changes
  (define is5 (infra-retract is4 spec-aid))
  (check-equal? (infra-read-believed is5 'def:base) 'base-val)
  (check-equal? (infra-read-believed is5 'def:spec) 'spec-val)
  ;; Verify assumption state
  (check-true (hash-has-key? (solver-state-believed (infra-state-atms is5)) outer-aid))
  (check-false (hash-has-key? (solver-state-believed (infra-state-atms is5)) spec-aid)))

(test-case "nested assumptions: last write wins on same cell"
  ;; In solver-state model, last-write-wins. Retraction doesn't resurface old value.
  (define is0 (make-infra-state))
  (define-values (is1 outer-aid) (infra-assume is0 'outer))
  (define is2 (infra-write-assumed is1 'def:x 'outer-val outer-aid))
  ;; Speculation overwrites
  (define-values (is3 spec-aid) (infra-assume is2 'spec))
  (define is4 (infra-write-assumed is3 'def:x 'spec-val spec-aid))
  ;; Spec value visible (most recent write)
  (check-equal? (infra-read-believed is4 'def:x) 'spec-val)
  ;; Retract spec — spec-val still wins (last-write-wins, no TMS)
  (define is5 (infra-retract is4 spec-aid))
  (check-equal? (infra-read-believed is5 'def:x) 'spec-val))

;; ========================================
;; infra-read-all-supported
;; ========================================

(test-case "infra-read-all-supported: deprecated, returns empty list"
  (define is0 (make-infra-state))
  (define-values (is1 aid1) (infra-assume is0 'a1))
  (define-values (is2 aid2) (infra-assume is1 'a2))
  (define is3 (infra-write-assumed is2 'my-cell 'val-1 aid1))
  (define is4 (infra-write-assumed is3 'my-cell 'val-2 aid2))
  ;; Retract a2 — values persist (last-write-wins, no TMS filtering)
  (define is5 (infra-retract is4 aid2))
  ;; Last write (val-2) still visible
  (check-equal? (infra-read-believed is5 'my-cell) 'val-2)
  ;; infra-read-all-supported is deprecated — returns empty list
  (define all-svs (infra-read-all-supported is5 'my-cell))
  (check-equal? all-svs '()))

(test-case "infra-read-all-supported: empty for unwritten cell"
  (define is0 (make-infra-state))
  (check-equal? (infra-read-all-supported is0 'nothing) '()))

;; ========================================
;; Monotonic + Assumed Cells Coexist
;; ========================================

(test-case "monotonic prop-network cells coexist with ATMS TMS cells"
  (define is0 (make-infra-state))
  ;; Create monotonic registry cell in the prop-network
  (define net0 (solver-state-net (infra-state-atms is0)))
  (define-values (net1 reg-cid) (net-new-registry-cell net0))
  ;; Update the solver-state with modified network
  (define is1
    (struct-copy infra-state is0
      [atms (struct-copy solver-state (infra-state-atms is0) [net net1])]))
  ;; Write to monotonic cell
  (define net2 (net-cell-write (solver-state-net (infra-state-atms is1))
                               reg-cid (hasheq 'key 'val)))
  (define is2
    (struct-copy infra-state is1
      [atms (struct-copy solver-state (infra-state-atms is1) [net net2])]))
  ;; Write to solver-state cell
  (define-values (is3 aid) (infra-assume is2 'cmd))
  (define is4 (infra-write-assumed is3 'def:bar 'bar-val aid))
  ;; Both readable
  (check-equal? (hash-ref (net-cell-read (solver-state-net (infra-state-atms is4)) reg-cid) 'key) 'val)
  (check-equal? (infra-read-believed is4 'def:bar) 'bar-val))

;; ========================================
;; current-infra-assumption Scoping
;; ========================================

(test-case "current-infra-assumption: parameterize scope"
  (define is0 (make-infra-state))
  (define-values (is1 aid) (infra-assume is0 'scoped))
  ;; Outside parameterize: no assumption
  (check-false (current-infra-assumption))
  ;; Inside parameterize: assumption active
  (define is2
    (parameterize ([current-infra-assumption aid])
      (check-equal? (current-infra-assumption) aid)
      (infra-write-assumed is1 'cell-a 'val-a)))
  ;; After parameterize: no assumption again
  (check-false (current-infra-assumption))
  (check-equal? (infra-read-believed is2 'cell-a) 'val-a))

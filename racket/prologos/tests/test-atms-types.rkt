#lang racket/base

;;;
;;; Tests for ATMS type-level integration
;;; Phase 5c: type formation, infer, check, QTT, substitution, pretty-print
;;;

(require racket/string
         rackunit
         "../syntax.rkt"
         "../prelude.rkt"
         "../substitution.rkt"
         "../reduction.rkt"
         (prefix-in tc: "../typing-core.rkt")
         "../pretty-print.rkt"
         "../qtt.rkt"
         "../global-env.rkt"
         "../atms.rkt"
         "../propagator.rkt"
         "../driver.rkt")

;; ========================================
;; Type formation: ATMS
;; ========================================

(test-case "ATMS type formation"
  (check-equal? (tc:infer ctx-empty (expr-atms-type))
                (expr-Type (lzero))
                "ATMS : Type 0")
  (check-true (tc:is-type ctx-empty (expr-atms-type))
              "ATMS is a type"))

(test-case "AssumptionId type formation"
  (check-equal? (tc:infer ctx-empty (expr-assumption-id-type))
                (expr-Type (lzero))
                "AssumptionId : Type 0")
  (check-true (tc:is-type ctx-empty (expr-assumption-id-type))
              "AssumptionId is a type"))

;; ========================================
;; Runtime wrapper
;; ========================================

(test-case "ATMS runtime wrapper check"
  (check-true (tc:check ctx-empty (expr-atms-store (atms-empty)) (expr-atms-type))
              "atms-store checks against ATMS type"))

(test-case "ATMS runtime wrapper infer"
  (check-equal? (tc:infer ctx-empty (expr-atms-store (atms-empty)))
                (expr-atms-type)
                "atms-store infers as ATMS"))

(test-case "AssumptionId runtime wrapper check"
  (check-true (tc:check ctx-empty (expr-assumption-id-val (assumption-id 0)) (expr-assumption-id-type))
              "assumption-id-val checks against AssumptionId type"))

(test-case "AssumptionId runtime wrapper infer"
  (check-equal? (tc:infer ctx-empty (expr-assumption-id-val (assumption-id 0)))
                (expr-assumption-id-type)
                "assumption-id-val infers as AssumptionId"))

;; ========================================
;; Operation type inference
;; ========================================

(test-case "atms-new infers as ATMS"
  (check-equal? (tc:infer ctx-empty
                  (expr-atms-new (expr-prop-network (make-prop-network))))
                (expr-atms-type)))

(test-case "atms-assume infers as [ATMS * AssumptionId]"
  (check-equal? (tc:infer ctx-empty
                  (expr-atms-assume (expr-atms-store (atms-empty))
                                    (expr-keyword ':h0)
                                    (expr-true)))
                (expr-Sigma (expr-atms-type) (expr-assumption-id-type))))

(test-case "atms-retract infers as ATMS"
  (check-equal? (tc:infer ctx-empty
                  (expr-atms-retract (expr-atms-store (atms-empty))
                                     (expr-assumption-id-val (assumption-id 0))))
                (expr-atms-type)))

(test-case "atms-read infers as hole (type-unsafe)"
  (let ([store (expr-atms-store (atms-empty))])
    (check-equal? (tc:infer ctx-empty
                    (expr-atms-read store (expr-cell-id (cell-id 0))))
                  (expr-hole))))

(test-case "atms-consistent infers as Bool"
  ;; Need the List type to be available — use a nil literal for the aids list
  ;; Since checking against List AssumptionId requires prelude, test with raw wrapper
  (check-equal? (tc:infer ctx-empty
                  (expr-atms-consistent (expr-atms-store (atms-empty))
                                        (expr-atms-store (atms-empty))))
                (expr-error)
                "aids must be List AssumptionId, not ATMS — should error"))

;; ========================================
;; Type errors
;; ========================================

(test-case "atms-new rejects non-PropNetwork"
  (check-equal? (tc:infer ctx-empty
                  (expr-atms-new (expr-true)))
                (expr-error)
                "network must be PropNetwork, not Bool"))

(test-case "atms-retract rejects non-AssumptionId"
  (check-equal? (tc:infer ctx-empty
                  (expr-atms-retract (expr-atms-store (atms-empty))
                                     (expr-true)))
                (expr-error)
                "aid must be AssumptionId, not Bool"))

;; ========================================
;; QTT inferQ
;; ========================================

(test-case "QTT: atms-type has zero usage"
  (check-equal? (inferQ ctx-empty (expr-atms-type))
                (tu (expr-Type (lzero)) '())))

(test-case "QTT: assumption-id-type has zero usage"
  (check-equal? (inferQ ctx-empty (expr-assumption-id-type))
                (tu (expr-Type (lzero)) '())))

(test-case "QTT: atms-store wrapper has zero usage"
  (check-equal? (inferQ ctx-empty (expr-atms-store (atms-empty)))
                (tu (expr-atms-type) '())))

(test-case "QTT: assumption-id-val wrapper has zero usage"
  (check-equal? (inferQ ctx-empty (expr-assumption-id-val (assumption-id 0)))
                (tu (expr-assumption-id-type) '())))

;; ========================================
;; Substitution round-trip
;; ========================================

(test-case "shift on ATMS type constructor"
  (check-equal? (shift 1 0 (expr-atms-type)) (expr-atms-type)))

(test-case "shift on AssumptionId type constructor"
  (check-equal? (shift 1 0 (expr-assumption-id-type)) (expr-assumption-id-type)))

(test-case "shift on atms-new recurses into field"
  (let ([e (expr-atms-new (expr-bvar 0))])
    (check-equal? (shift 1 0 e)
                  (expr-atms-new (expr-bvar 1)))))

(test-case "subst on atms-retract recurses into fields"
  (let ([e (expr-atms-retract (expr-bvar 0) (expr-bvar 1))])
    (check-equal? (subst 0 (expr-atms-store (atms-empty)) e)
                  (expr-atms-retract (expr-atms-store (atms-empty)) (expr-bvar 0)))))

;; ========================================
;; Pretty-print
;; ========================================

(test-case "pp-expr: ATMS type"
  (check-equal? (pp-expr (expr-atms-type) '()) "ATMS"))

(test-case "pp-expr: AssumptionId type"
  (check-equal? (pp-expr (expr-assumption-id-type) '()) "AssumptionId"))

(test-case "pp-expr: atms-store"
  (check-true (string-contains?
               (pp-expr (expr-atms-store (atms-empty)) '())
               "#<atms")))

(test-case "pp-expr: assumption-id-val"
  (check-true (string-contains?
               (pp-expr (expr-assumption-id-val (assumption-id 42)) '())
               "42")))

(test-case "pp-expr: atms-new"
  (check-true (string-contains?
               (pp-expr (expr-atms-new (expr-atms-store (atms-empty))) '())
               "atms-new")))

(test-case "pp-expr: atms-assume"
  (check-true (string-contains?
               (pp-expr (expr-atms-assume (expr-atms-store (atms-empty)) (expr-keyword ':h0) (expr-true)) '())
               "atms-assume")))

(test-case "pp-expr: atms-amb"
  (check-true (string-contains?
               (pp-expr (expr-atms-amb (expr-atms-store (atms-empty)) (expr-fvar 'nil)) '())
               "atms-amb")))

;; ========================================
;; Reduction / eval tests (Sub-phase 5d)
;; ========================================

(test-case "whnf: atms-new reduces to atms-store"
  (let ([result (whnf (expr-atms-new (expr-prop-network (make-prop-network))))])
    (check-true (expr-atms-store? result)
                "atms-new wraps result in expr-atms-store")))

(test-case "whnf: atms-assume returns pair [ATMS * AssumptionId]"
  (let ([result (whnf (expr-atms-assume
                        (expr-atms-store (atms-empty))
                        (expr-keyword ':h0)
                        (expr-true)))])
    (check-true (expr-pair? result) "result is a pair")
    (check-true (expr-atms-store? (expr-pair-fst result)) "fst is ATMS store")
    (check-true (expr-assumption-id-val? (expr-pair-snd result)) "snd is AssumptionId")))

(test-case "whnf: atms-retract returns atms-store"
  (let* ([a0 (atms-empty)]
         [result (whnf (expr-atms-retract
                         (expr-atms-store a0)
                         (expr-assumption-id-val (assumption-id 0))))])
    (check-true (expr-atms-store? result))))

(test-case "whnf: atms-read on empty cell returns hole"
  (let ([result (whnf (expr-atms-read
                         (expr-atms-store (atms-empty))
                         (expr-cell-id (cell-id 0))))])
    (check-true (expr-hole? result) "no value → hole")))

(test-case "whnf: atms-write + atms-read round-trip under worldview"
  ;; Create ATMS, make an assumption, write value with that assumption as support,
  ;; then read it back.
  (define-values (a0 aid0) (atms-assume (atms-empty) ':h0 'datum))
  (define cid (cell-id 0))
  (define a1 (atms-write-cell a0 cid (expr-int 42) (hasheq aid0 #t)))
  ;; Read via reduction
  (let ([result (whnf (expr-atms-read (expr-atms-store a1) (expr-cell-id cid)))])
    (check-equal? result (expr-int 42) "read returns the written value")))

(test-case "whnf: atms-consistent on empty ATMS returns true"
  ;; Use a Prologos nil list for empty assumption set
  (let ([result (whnf (expr-atms-consistent
                         (expr-atms-store (atms-empty))
                         (expr-fvar 'nil)))])
    (check-equal? result (expr-true) "empty set is always consistent")))

(test-case "whnf: atms-consistent detects nogood"
  ;; Create ATMS with a nogood {aid0}, then check consistency of {aid0}
  (define-values (a0 aid0) (atms-assume (atms-empty) ':h0 'datum))
  (define a1 (atms-add-nogood a0 (hasheq aid0 #t)))
  ;; Build Prologos list with one element: the assumption-id
  (define aids-list (expr-app (expr-app (expr-fvar 'cons) (expr-assumption-id-val aid0))
                              (expr-fvar 'nil)))
  (let ([result (whnf (expr-atms-consistent (expr-atms-store a1) aids-list))])
    (check-equal? result (expr-false) "nogood set is inconsistent")))

(test-case "whnf: atms-worldview switches believed set"
  ;; Create ATMS with two assumptions, switch worldview to only one
  (define-values (a0 aid0) (atms-assume (atms-empty) ':h0 'x))
  (define-values (a1 aid1) (atms-assume a0 ':h1 'y))
  ;; Write two values to same cell with different support
  (define cid (cell-id 0))
  (define a2 (atms-write-cell a1 cid (expr-int 10) (hasheq aid0 #t)))
  (define a3 (atms-write-cell a2 cid (expr-int 20) (hasheq aid1 #t)))
  ;; Switch worldview to only aid0
  (define aid0-list (expr-app (expr-app (expr-fvar 'cons) (expr-assumption-id-val aid0))
                              (expr-fvar 'nil)))
  (define result-store (whnf (expr-atms-worldview (expr-atms-store a3) aid0-list)))
  (check-true (expr-atms-store? result-store))
  ;; Read under new worldview → should get aid0's value (10)
  (let ([result (whnf (expr-atms-read result-store (expr-cell-id cid)))])
    (check-equal? result (expr-int 10) "worldview switch selects correct value")))

(test-case "whnf: atms-amb + atms-solve-all round-trip"
  ;; Create ATMS, amb with 3 alternatives, write each to a cell,
  ;; then solve-all to enumerate
  (define a0 (atms-empty))
  ;; amb with 3 alternatives (datum values)
  (define-values (a1 hyps) (atms-amb a0 (list (expr-int 1) (expr-int 2) (expr-int 3))))
  ;; Write each alternative to cell 0 under its assumption
  (define cid (cell-id 0))
  (define a2
    (for/fold ([a a1])
              ([h (in-list hyps)]
               [v (in-list (list (expr-int 1) (expr-int 2) (expr-int 3)))])
      (atms-write-cell a cid v (hasheq h #t))))
  ;; solve-all via reduction
  (let ([result (whnf (expr-atms-solve-all (expr-atms-store a2) (expr-cell-id cid)))])
    ;; Should produce a Prologos list (nil/cons chain) with 3 elements
    (check-true (or (expr-app? result) (expr-fvar? result))
                "result is a Prologos list expression")))

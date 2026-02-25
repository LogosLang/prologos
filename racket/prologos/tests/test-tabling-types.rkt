#lang racket/base

;;;
;;; Tests for Tabling type-level integration
;;; Phase 6c: type formation, infer, check, QTT, substitution, pretty-print
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
         "../tabling.rkt"
         "../propagator.rkt")

;; ========================================
;; Type formation: TableStore
;; ========================================

(test-case "TableStore type formation"
  (check-equal? (tc:infer ctx-empty (expr-table-store-type))
                (expr-Type (lzero))
                "TableStore : Type 0")
  (check-true (tc:is-type ctx-empty (expr-table-store-type))
              "TableStore is a type"))

;; ========================================
;; Runtime wrapper
;; ========================================

(test-case "TableStore runtime wrapper check"
  (check-true (tc:check ctx-empty (expr-table-store-val (table-store-empty)) (expr-table-store-type))
              "table-store-val checks against TableStore type"))

(test-case "TableStore runtime wrapper infer"
  (check-equal? (tc:infer ctx-empty (expr-table-store-val (table-store-empty)))
                (expr-table-store-type)
                "table-store-val infers as TableStore"))

;; ========================================
;; Operation type inference
;; ========================================

(test-case "table-new infers as TableStore"
  (check-equal? (tc:infer ctx-empty
                  (expr-table-new (expr-prop-network (make-prop-network))))
                (expr-table-store-type)))

(test-case "table-register infers as [TableStore * CellId]"
  (check-equal? (tc:infer ctx-empty
                  (expr-table-register (expr-table-store-val (table-store-empty))
                                       (expr-keyword ':ancestor)
                                       (expr-keyword ':all)))
                (expr-Sigma (expr-table-store-type) (expr-cell-id-type))))

(test-case "table-add infers as TableStore"
  (check-equal? (tc:infer ctx-empty
                  (expr-table-add (expr-table-store-val (table-store-empty))
                                  (expr-keyword ':p)
                                  (expr-true)))
                (expr-table-store-type)))

(test-case "table-answers infers as hole (type-unsafe)"
  (check-equal? (tc:infer ctx-empty
                  (expr-table-answers (expr-table-store-val (table-store-empty))
                                      (expr-keyword ':p)))
                (expr-hole)))

(test-case "table-freeze infers as TableStore"
  (check-equal? (tc:infer ctx-empty
                  (expr-table-freeze (expr-table-store-val (table-store-empty))
                                     (expr-keyword ':p)))
                (expr-table-store-type)))

(test-case "table-complete? infers as Bool"
  (check-equal? (tc:infer ctx-empty
                  (expr-table-complete (expr-table-store-val (table-store-empty))
                                       (expr-keyword ':p)))
                (expr-Bool)))

(test-case "table-run infers as TableStore"
  (check-equal? (tc:infer ctx-empty
                  (expr-table-run (expr-table-store-val (table-store-empty))))
                (expr-table-store-type)))

(test-case "table-lookup infers as Bool"
  (check-equal? (tc:infer ctx-empty
                  (expr-table-lookup (expr-table-store-val (table-store-empty))
                                     (expr-keyword ':p)
                                     (expr-true)))
                (expr-Bool)))

;; ========================================
;; Type errors
;; ========================================

(test-case "table-new rejects non-PropNetwork"
  (check-equal? (tc:infer ctx-empty
                  (expr-table-new (expr-true)))
                (expr-error)
                "network must be PropNetwork, not Bool"))

(test-case "table-register rejects non-TableStore"
  (check-equal? (tc:infer ctx-empty
                  (expr-table-register (expr-true)
                                       (expr-keyword ':p)
                                       (expr-keyword ':all)))
                (expr-error)
                "store must be TableStore, not Bool"))

(test-case "table-add rejects non-Keyword name"
  (check-equal? (tc:infer ctx-empty
                  (expr-table-add (expr-table-store-val (table-store-empty))
                                  (expr-true)
                                  (expr-true)))
                (expr-error)
                "name must be Keyword, not Bool"))

;; ========================================
;; QTT inferQ
;; ========================================

(test-case "QTT: table-store-type has zero usage"
  (check-equal? (inferQ ctx-empty (expr-table-store-type))
                (tu (expr-Type (lzero)) '())))

(test-case "QTT: table-store-val wrapper has zero usage"
  (check-equal? (inferQ ctx-empty (expr-table-store-val (table-store-empty)))
                (tu (expr-table-store-type) '())))

;; ========================================
;; Substitution round-trip
;; ========================================

(test-case "shift on TableStore type constructor"
  (check-equal? (shift 1 0 (expr-table-store-type)) (expr-table-store-type)))

(test-case "shift on table-store-val wrapper"
  (check-equal? (shift 1 0 (expr-table-store-val (table-store-empty)))
                (expr-table-store-val (table-store-empty))))

(test-case "shift on table-new recurses into field"
  (let ([e (expr-table-new (expr-bvar 0))])
    (check-equal? (shift 1 0 e)
                  (expr-table-new (expr-bvar 1)))))

(test-case "subst on table-register recurses into fields"
  (let ([e (expr-table-register (expr-bvar 0) (expr-keyword ':p) (expr-keyword ':all))])
    (check-equal? (subst 0 (expr-table-store-val (table-store-empty)) e)
                  (expr-table-register (expr-table-store-val (table-store-empty))
                                       (expr-keyword ':p) (expr-keyword ':all)))))

;; ========================================
;; Pretty-print
;; ========================================

(test-case "pp-expr: TableStore type"
  (check-equal? (pp-expr (expr-table-store-type) '()) "TableStore"))

(test-case "pp-expr: table-store-val"
  (check-true (string-contains?
               (pp-expr (expr-table-store-val (table-store-empty)) '())
               "#<table-store")))

(test-case "pp-expr: table-new"
  (check-true (string-contains?
               (pp-expr (expr-table-new (expr-table-store-val (table-store-empty))) '())
               "table-new")))

(test-case "pp-expr: table-register"
  (check-true (string-contains?
               (pp-expr (expr-table-register (expr-table-store-val (table-store-empty))
                                             (expr-keyword ':p)
                                             (expr-keyword ':all))
                        '())
               "table-register")))

;; ========================================
;; Reduction / eval tests (Sub-phase 6d)
;; ========================================

(test-case "whnf: table-new reduces to table-store-val"
  (let ([result (whnf (expr-table-new (expr-prop-network (make-prop-network))))])
    (check-true (expr-table-store-val? result)
                "table-new wraps result in expr-table-store-val")))

(test-case "whnf: table-register returns pair [TableStore * CellId]"
  (let ([result (whnf (expr-table-register
                         (expr-table-store-val (table-store-empty))
                         (expr-keyword ':p)
                         (expr-keyword ':all)))])
    (check-true (expr-pair? result) "result is a pair")
    (check-true (expr-table-store-val? (expr-pair-fst result)) "fst is TableStore")
    (check-true (expr-cell-id? (expr-pair-snd result)) "snd is CellId")))

(test-case "whnf: table-add + table-answers round-trip"
  ;; Register table, add answer, read answers back
  (let* ([ts0 (table-store-empty)]
         [pair-result (whnf (expr-table-register
                              (expr-table-store-val ts0)
                              (expr-keyword ':p)
                              (expr-keyword ':all)))]
         [ts1 (expr-table-store-val-store-value (expr-pair-fst pair-result))]
         [add-result (whnf (expr-table-add
                             (expr-table-store-val ts1)
                             (expr-keyword ':p)
                             (expr-keyword ':alice)))]
         [ts2 (expr-table-store-val-store-value add-result)]
         [answers-result (whnf (expr-table-answers
                                 (expr-table-store-val ts2)
                                 (expr-keyword ':p)))])
    ;; answers-result should be a Prologos list containing :alice
    ;; A cons chain: (app (app cons :alice) nil)
    (check-true (expr-app? answers-result) "answers result is a cons chain")))

(test-case "whnf: table-lookup finds added answer"
  (let* ([ts0 (table-store-empty)]
         [pair-result (whnf (expr-table-register
                              (expr-table-store-val ts0)
                              (expr-keyword ':p)
                              (expr-keyword ':all)))]
         [ts1 (expr-table-store-val-store-value (expr-pair-fst pair-result))]
         [add-result (whnf (expr-table-add
                             (expr-table-store-val ts1)
                             (expr-keyword ':p)
                             (expr-keyword ':alice)))]
         [ts2 (expr-table-store-val-store-value add-result)])
    (check-equal? (whnf (expr-table-lookup
                           (expr-table-store-val ts2)
                           (expr-keyword ':p)
                           (expr-keyword ':alice)))
                  (expr-true)
                  "lookup finds :alice")
    (check-equal? (whnf (expr-table-lookup
                           (expr-table-store-val ts2)
                           (expr-keyword ':p)
                           (expr-keyword ':bob)))
                  (expr-false)
                  "lookup doesn't find :bob")))

(test-case "whnf: table-freeze + table-complete? round-trip"
  (let* ([ts0 (table-store-empty)]
         [pair-result (whnf (expr-table-register
                              (expr-table-store-val ts0)
                              (expr-keyword ':p)
                              (expr-keyword ':all)))]
         [ts1 (expr-table-store-val-store-value (expr-pair-fst pair-result))])
    ;; Before freeze: not complete
    (check-equal? (whnf (expr-table-complete
                           (expr-table-store-val ts1)
                           (expr-keyword ':p)))
                  (expr-false)
                  "active table is not complete")
    ;; Freeze
    (let* ([freeze-result (whnf (expr-table-freeze
                                  (expr-table-store-val ts1)
                                  (expr-keyword ':p)))]
           [ts2 (expr-table-store-val-store-value freeze-result)])
      (check-equal? (whnf (expr-table-complete
                             (expr-table-store-val ts2)
                             (expr-keyword ':p)))
                    (expr-true)
                    "frozen table is complete"))))

(test-case "whnf: table-run reaches quiescence"
  (let ([result (whnf (expr-table-run (expr-table-store-val (table-store-empty))))])
    (check-true (expr-table-store-val? result)
                "table-run returns a table-store-val")))

(test-case "whnf: first answer mode keeps only first"
  (let* ([ts0 (table-store-empty)]
         [pair-result (whnf (expr-table-register
                              (expr-table-store-val ts0)
                              (expr-keyword ':p)
                              (expr-keyword ':first)))]
         [ts1 (expr-table-store-val-store-value (expr-pair-fst pair-result))]
         ;; Add two answers
         [add1 (whnf (expr-table-add (expr-table-store-val ts1) (expr-keyword ':p) (expr-keyword ':alice)))]
         [ts2 (expr-table-store-val-store-value add1)]
         [add2 (whnf (expr-table-add (expr-table-store-val ts2) (expr-keyword ':p) (expr-keyword ':bob)))]
         [ts3 (expr-table-store-val-store-value add2)])
    ;; Lookup: :alice should be found, :bob should not
    (check-equal? (whnf (expr-table-lookup (expr-table-store-val ts3) (expr-keyword ':p) (expr-keyword ':alice)))
                  (expr-true)
                  "first answer :alice found")
    (check-equal? (whnf (expr-table-lookup (expr-table-store-val ts3) (expr-keyword ':p) (expr-keyword ':bob)))
                  (expr-false)
                  "second answer :bob rejected in first mode")))

#lang racket/base

;;;
;;; Tests for PropNetwork type-level integration
;;; Phase 3b: type formation, infer, check, QTT, substitution, pretty-print
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
         "../propagator.rkt")

;; ========================================
;; Type formation: PropNetwork, CellId, PropId
;; ========================================

(test-case "PropNetwork type formation"
  (check-equal? (tc:infer ctx-empty (expr-net-type))
                (expr-Type (lzero))
                "PropNetwork : Type 0")
  (check-true (tc:is-type ctx-empty (expr-net-type))
              "PropNetwork is a type"))

(test-case "CellId type formation"
  (check-equal? (tc:infer ctx-empty (expr-cell-id-type))
                (expr-Type (lzero))
                "CellId : Type 0")
  (check-true (tc:is-type ctx-empty (expr-cell-id-type))
              "CellId is a type"))

(test-case "PropId type formation"
  (check-equal? (tc:infer ctx-empty (expr-prop-id-type))
                (expr-Type (lzero))
                "PropId : Type 0")
  (check-true (tc:is-type ctx-empty (expr-prop-id-type))
              "PropId is a type"))

;; ========================================
;; Type levels
;; ========================================

(test-case "PropNetwork/CellId/PropId type levels"
  (check-equal? (tc:infer-level ctx-empty (expr-net-type))
                (tc:just-level (lzero))
                "PropNetwork at level 0")
  (check-equal? (tc:infer-level ctx-empty (expr-cell-id-type))
                (tc:just-level (lzero))
                "CellId at level 0")
  (check-equal? (tc:infer-level ctx-empty (expr-prop-id-type))
                (tc:just-level (lzero))
                "PropId at level 0"))

;; ========================================
;; Runtime wrapper typing (infer + check)
;; ========================================

(test-case "prop-network wrapper typing"
  (let ([net (make-prop-network 100)])
    (check-equal? (tc:infer ctx-empty (expr-prop-network net))
                  (expr-net-type)
                  "prop-network wrapper : PropNetwork")
    (check-true (tc:check ctx-empty (expr-prop-network net) (expr-net-type))
                "check prop-network : PropNetwork")))

(test-case "cell-id wrapper typing"
  (let ([cid (cell-id 0)])
    (check-equal? (tc:infer ctx-empty (expr-cell-id cid))
                  (expr-cell-id-type)
                  "cell-id wrapper : CellId")
    (check-true (tc:check ctx-empty (expr-cell-id cid) (expr-cell-id-type))
                "check cell-id : CellId")))

(test-case "prop-id wrapper typing"
  (let ([pid (prop-id 0)])
    (check-equal? (tc:infer ctx-empty (expr-prop-id pid))
                  (expr-prop-id-type)
                  "prop-id wrapper : PropId")
    (check-true (tc:check ctx-empty (expr-prop-id pid) (expr-prop-id-type))
                "check prop-id : PropId")))

;; ========================================
;; Operation typing: net-new
;; ========================================

(test-case "net-new typing (Int -> PropNetwork)"
  (check-equal? (tc:infer ctx-empty (expr-net-new (expr-int 1000)))
                (expr-net-type)
                "net-new(1000) : PropNetwork"))

(test-case "net-new rejects non-type arg"
  (check-true (expr-error? (tc:infer ctx-empty (expr-net-new (expr-true))))
              "net-new(true) should fail — Bool is not Int"))

;; ========================================
;; Operation typing: net-new-cell
;; ========================================

(test-case "net-new-cell typing (PropNetwork -> A -> (A A -> A) -> Sigma PropNetwork CellId)"
  (let* ([net (make-prop-network 100)]
         [merge-fn (expr-lam mw (expr-Nat)
                     (expr-lam mw (expr-Nat)
                       (expr-bvar 0)))]  ;; trivial merge: take second
         [e (expr-net-new-cell (expr-prop-network net) (expr-zero) merge-fn)])
    (check-equal? (tc:infer ctx-empty e)
                  (expr-Sigma (expr-net-type) (expr-cell-id-type))
                  "net-new-cell returns [PropNetwork * CellId]")))

;; ========================================
;; Operation typing: net-cell-read
;; ========================================

(test-case "net-cell-read typing (PropNetwork -> CellId -> ?)"
  (let* ([net (make-prop-network 100)]
         [cid (cell-id 0)]
         [e (expr-net-cell-read (expr-prop-network net) (expr-cell-id cid))])
    ;; net-cell-read returns expr-hole (type-unsafe by design)
    (let ([ty (tc:infer ctx-empty e)])
      (check-true (not (expr-error? ty))
                  "net-cell-read should not be an error"))))

;; ========================================
;; Operation typing: net-cell-write
;; ========================================

(test-case "net-cell-write typing (PropNetwork -> CellId -> A -> PropNetwork)"
  (let* ([net (make-prop-network 100)]
         [cid (cell-id 0)]
         [e (expr-net-cell-write (expr-prop-network net) (expr-cell-id cid) (expr-zero))])
    (check-equal? (tc:infer ctx-empty e)
                  (expr-net-type)
                  "net-cell-write returns PropNetwork")))

;; ========================================
;; Operation typing: net-run
;; ========================================

(test-case "net-run typing (PropNetwork -> PropNetwork)"
  (let* ([net (make-prop-network 100)])
    (check-equal? (tc:infer ctx-empty (expr-net-run (expr-prop-network net)))
                  (expr-net-type)
                  "net-run returns PropNetwork")))

;; ========================================
;; Operation typing: net-snapshot
;; ========================================

(test-case "net-snapshot typing (PropNetwork -> PropNetwork)"
  (let* ([net (make-prop-network 100)])
    (check-equal? (tc:infer ctx-empty (expr-net-snapshot (expr-prop-network net)))
                  (expr-net-type)
                  "net-snapshot returns PropNetwork")))

;; ========================================
;; Operation typing: net-contradiction
;; ========================================

(test-case "net-contradiction typing (PropNetwork -> Bool)"
  (let* ([net (make-prop-network 100)])
    (check-equal? (tc:infer ctx-empty (expr-net-contradiction (expr-prop-network net)))
                  (expr-Bool)
                  "net-contradiction returns Bool")))

;; ========================================
;; QTT: inferQ for type constructors + operations
;; ========================================

(test-case "QTT: type constructors have zero usage"
  (check-equal? (inferQ ctx-empty (expr-net-type))
                (tu (expr-Type (lzero)) '())
                "inferQ PropNetwork → zero usage")
  (check-equal? (inferQ ctx-empty (expr-cell-id-type))
                (tu (expr-Type (lzero)) '())
                "inferQ CellId → zero usage")
  (check-equal? (inferQ ctx-empty (expr-prop-id-type))
                (tu (expr-Type (lzero)) '())
                "inferQ PropId → zero usage"))

(test-case "QTT: runtime wrappers have zero usage"
  (let ([net (make-prop-network 100)]
        [cid (cell-id 0)]
        [pid (prop-id 0)])
    (check-equal? (inferQ ctx-empty (expr-prop-network net))
                  (tu (expr-net-type) '()))
    (check-equal? (inferQ ctx-empty (expr-cell-id cid))
                  (tu (expr-cell-id-type) '()))
    (check-equal? (inferQ ctx-empty (expr-prop-id pid))
                  (tu (expr-prop-id-type) '()))))

(test-case "QTT: net-new usage"
  (let ([r (inferQ ctx-empty (expr-net-new (expr-int 1000)))])
    (check-true (tu? r) "inferQ net-new succeeds")
    (check-equal? (tu-type r) (expr-net-type))))

(test-case "QTT: checkQ runtime wrappers"
  (let ([net (make-prop-network 100)]
        [cid (cell-id 0)]
        [pid (prop-id 0)])
    (check-equal? (checkQ ctx-empty (expr-prop-network net) (expr-net-type))
                  (bu #t '()))
    (check-equal? (checkQ ctx-empty (expr-cell-id cid) (expr-cell-id-type))
                  (bu #t '()))
    (check-equal? (checkQ ctx-empty (expr-prop-id pid) (expr-prop-id-type))
                  (bu #t '()))))

;; ========================================
;; Substitution round-trip
;; ========================================

(test-case "substitution: type constructors are leaves"
  (check-equal? (shift 5 0 (expr-net-type)) (expr-net-type))
  (check-equal? (shift 5 0 (expr-cell-id-type)) (expr-cell-id-type))
  (check-equal? (shift 5 0 (expr-prop-id-type)) (expr-prop-id-type)))

(test-case "substitution: runtime wrappers are leaves"
  (let ([net (make-prop-network 100)])
    (check-equal? (shift 5 0 (expr-prop-network net)) (expr-prop-network net))))

(test-case "substitution: operations recurse into fields"
  (let ([e (expr-net-new (expr-bvar 0))])
    ;; shift by 1 should bump the bvar
    (check-equal? (shift 1 0 e) (expr-net-new (expr-bvar 1)))))

;; ========================================
;; Pretty-print
;; ========================================

(test-case "pretty-print: type constructors"
  (check-equal? (pp-expr (expr-net-type) '()) "PropNetwork")
  (check-equal? (pp-expr (expr-cell-id-type) '()) "CellId")
  (check-equal? (pp-expr (expr-prop-id-type) '()) "PropId"))

(test-case "pretty-print: runtime wrappers"
  (let ([net (make-prop-network 100)]
        [cid (cell-id 0)]
        [pid (prop-id 0)])
    (check-true (string-contains? (pp-expr (expr-prop-network net) '()) "#<prop-network"))
    (check-true (string-contains? (pp-expr (expr-cell-id cid) '()) "#<cell-id"))
    (check-true (string-contains? (pp-expr (expr-prop-id pid) '()) "#<prop-id"))))

(test-case "pretty-print: operations"
  (check-true (string-contains?
               (pp-expr (expr-net-new (expr-int 1000)) '())
               "net-new"))
  (let ([net (make-prop-network 100)])
    (check-true (string-contains?
                 (pp-expr (expr-net-run (expr-prop-network net)) '())
                 "net-run"))
    (check-true (string-contains?
                 (pp-expr (expr-net-contradiction (expr-prop-network net)) '())
                 "net-contradict?"))))

;; ========================================
;; Reduction: eval tests
;; ========================================

(test-case "eval: net-new reduces to prop-network wrapper"
  (let ([result (whnf (expr-net-new (expr-int 1000)))])
    (check-true (expr-prop-network? result)
                "net-new(1000) reduces to prop-network wrapper")))

(test-case "eval: net-contradiction on fresh network is false"
  (let ([result (whnf (expr-net-contradiction (expr-net-new (expr-int 1000))))])
    (check-equal? result (expr-false)
                  "fresh network has no contradiction")))

(test-case "eval: net-new-cell returns pair of [PropNetwork * CellId]"
  (let* ([merge-fn (expr-lam mw (expr-Nat)
                     (expr-lam mw (expr-Nat)
                       (expr-bvar 0)))]  ;; trivial: take second
         [result (whnf (expr-net-new-cell (expr-net-new (expr-int 1000))
                                          (expr-zero)
                                          merge-fn))])
    (check-true (expr-pair? result) "returns a pair")
    (check-true (expr-prop-network? (expr-pair-fst result)) "fst is PropNetwork")
    (check-true (expr-cell-id? (expr-pair-snd result)) "snd is CellId")))

(test-case "eval: cell read returns initial value"
  (let* ([merge-fn (expr-lam mw (expr-Nat)
                     (expr-lam mw (expr-Nat)
                       (expr-bvar 0)))]
         [pair (whnf (expr-net-new-cell (expr-net-new (expr-int 1000))
                                        (expr-zero)
                                        merge-fn))]
         [net (expr-pair-fst pair)]
         [cid (expr-pair-snd pair)]
         [val (whnf (expr-net-cell-read net cid))])
    (check-equal? val (expr-zero)
                  "reading cell returns initial value zero")))

(test-case "eval: cell write + read with merge"
  (let* ([;; merge = max(old, new) via suc comparison — just use "take second" for simplicity
          merge-fn (expr-lam mw (expr-Nat)
                     (expr-lam mw (expr-Nat)
                       (expr-bvar 0)))]
         [pair (whnf (expr-net-new-cell (expr-net-new (expr-int 1000))
                                        (expr-zero)
                                        merge-fn))]
         [net1 (expr-pair-fst pair)]
         [cid (expr-pair-snd pair)]
         ;; Write suc(zero) to the cell
         [net2 (whnf (expr-net-cell-write net1 cid (expr-suc (expr-zero))))]
         ;; Read back
         [val (whnf (expr-net-cell-read net2 cid))])
    (check-true (expr-prop-network? net2) "write returns PropNetwork")
    ;; With "take second" merge, writing suc(zero) should give suc(zero)
    (check-equal? val (expr-nat-val 1)
                  "cell value is suc(zero) after write")))

(test-case "eval: net-run on fresh network (no propagators)"
  (let ([result (whnf (expr-net-run (expr-net-new (expr-int 1000))))])
    (check-true (expr-prop-network? result)
                "net-run returns PropNetwork")))

(test-case "eval: net-snapshot is identity on persistent data"
  (let ([net (whnf (expr-net-new (expr-int 1000)))])
    (check-true (expr-prop-network? (whnf (expr-net-snapshot net)))
                "net-snapshot returns PropNetwork")))

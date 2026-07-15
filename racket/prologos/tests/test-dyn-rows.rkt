#lang racket/base

;;;
;;; DYN-TAILED ROWS — CIU T6 F1a.2 p1a synthetic unit tests.
;;;
;;; Nothing mints 'dyn until p1b, so every row here is HAND-BUILT and every
;;; test is dead-code-safe against production flows. This file pins the §12.4
;;; consumer semantics BEFORE the mint-flip, including the NEGATIVE
;;; differentiating probes: rejection cases the old expr-Open wildcard
;;; (unify classify :579, deleted at p2) structurally cannot produce — it can
;;; only ever answer "ok", so a rejection PROVES the dyn arms are live.
;;;

(require rackunit
         racket/list
         "../prelude.rkt"
         "../syntax.rkt"
         "../metavar-store.rkt"
         "../reduction.rkt"
         "../unify.rkt"
         (only-in "../typing-core.rkt"
                  record-<:-map? record-project union-record-component-vt
                  record-value-bound record-value-union)
         (only-in "../subtype-predicate.rkt" record-subtypes-map?)
         "../union-types.rkt"
         "../global-env.rkt"
         "../driver.rkt")

;; ---- row builders (test-record-node.rkt pattern) ----
(define (krow tail . flds)   ; flds = (label . type-expr) ...
  (make-record 'keyword
               (for/list ([f (in-list flds)])
                 (cons (car f) (record-field (cdr f) 'present)))
               tail))

(define (dynrow . flds) (apply krow 'dyn flds))
(define (closedrow . flds) (apply krow 'closed flds))

;; ========================================
;; unify: the C_Cons row-vs-row arm
;; ========================================

(test-case "unify: dyn-vs-closed — shared field unifies, closed extras absorbed"
  (with-fresh-meta-env
   (check-true (unify ctx-empty
                      (dynrow (cons 'a (expr-Int)))
                      (closedrow (cons 'a (expr-Int)) (cons 'b (expr-String)))))))

(test-case "unify NEGATIVE: dyn-vs-closed shared-field TYPE conflict rejects (wildcard could never)"
  (with-fresh-meta-env
   (check-false (unify ctx-empty
                       (dynrow (cons 'a (expr-String)))
                       (closedrow (cons 'a (expr-Int)))))))

(test-case "unify NEGATIVE: dyn-known label absent from a CLOSED side rejects (containment)"
  (with-fresh-meta-env
   (check-false (unify ctx-empty
                       (dynrow (cons 'a (expr-Int)) (cons 'x (expr-Bool)))
                       (closedrow (cons 'a (expr-Int)))))))

(test-case "unify: dyn-vs-dyn with disjoint labels — both tails absorb"
  (with-fresh-meta-env
   (check-true (unify ctx-empty
                      (dynrow (cons 'a (expr-Int)))
                      (dynrow (cons 'b (expr-String)))))))

(test-case "unify: dyn-vs-dyn shared field SOLVES a field meta (solve-first)"
  (with-fresh-meta-env
   (define m (fresh-meta ctx-empty (expr-Type (lzero)) "test"))
   (check-true (unify ctx-empty
                      (dynrow (cons 'a m))
                      (dynrow (cons 'a (expr-Int)) (cons 'b (expr-Bool)))))
   (check-true (meta-solved? (expr-meta-id m)))
   (check-equal? (meta-solution (expr-meta-id m)) (expr-Int))))

(test-case "unify: dyn-vs-dyn SAME labels rides the B3 arm (tail eq) and solves"
  (with-fresh-meta-env
   (define m (fresh-meta ctx-empty (expr-Type (lzero)) "test"))
   (check-true (unify ctx-empty
                      (dynrow (cons 'a m))
                      (dynrow (cons 'a (expr-Int)))))
   (check-true (meta-solved? (expr-meta-id m)))))

(test-case "unify: dyn row vs bare META solves the meta to the row (flex-rigid, solve-first)"
  (with-fresh-meta-env
   (define m (fresh-meta ctx-empty (expr-Type (lzero)) "test"))
   (define r (dynrow (cons 'a (expr-Int))))
   (check-true (unify ctx-empty m r))
   (check-true (meta-solved? (expr-meta-id m)))
   (check-equal? (meta-solution (expr-meta-id m)) r)))

;; ========================================
;; pure layer: record-subtypes-map? (the C_ConsL absorption)
;; ========================================

(test-case "pure α: dyn row's KNOWNS satisfy (Map Keyword Int); remainder absorbed"
  (check-true (record-subtypes-map? (dynrow (cons 'a (expr-Int)))
                                    (expr-Map (expr-Keyword) (expr-Int)))))

(test-case "pure α NEGATIVE: dyn row's known field violating V rejects"
  (check-false (record-subtypes-map? (dynrow (cons 'a (expr-String)))
                                     (expr-Map (expr-Keyword) (expr-Int)))))

;; ========================================
;; typing-core adapters: meta-V refusal + projection hooks + the bound
;; ========================================

(test-case "record-<:-map?: meta V REFUSED from a dyn row (stays unsolved)"
  (with-fresh-meta-env
   (define v (fresh-meta ctx-empty (expr-Type (lzero)) "test-V"))
   (check-false (record-<:-map? ctx-empty (dynrow (cons 'a (expr-Int)))
                                (expr-Keyword) v))
   (check-false (meta-solved? (expr-meta-id v)))))

(test-case "record-<:-map?: meta V still SOLVES to ⋃fields from a CLOSED row"
  (with-fresh-meta-env
   (define v (fresh-meta ctx-empty (expr-Type (lzero)) "test-V"))
   (check-true (record-<:-map? ctx-empty (closedrow (cons 'a (expr-Int)))
                               (expr-Keyword) v))
   (check-true (meta-solved? (expr-meta-id v)))))

(test-case "record-project: literal miss on 'dyn → fresh META; on 'closed → error"
  (with-fresh-meta-env
   (define pd (record-project ctx-empty (dynrow (cons 'a (expr-Int))) (expr-keyword 'z)))
   (check-true (expr-meta? pd) (format "expected a fresh meta, got ~a" pd))
   (define pc (record-project ctx-empty (closedrow (cons 'a (expr-Int))) (expr-keyword 'z)))
   (check-true (expr-error? pc))))

(test-case "record-project: literal HIT on 'dyn stays exact"
  (with-fresh-meta-env
   (check-equal? (record-project ctx-empty (dynrow (cons 'a (expr-Int))) (expr-keyword 'a))
                 (expr-Int))))

(test-case "record-project: dynamic key on EMPTY dyn row still projects (fresh meta)"
  (with-fresh-meta-env
   (define m (fresh-meta ctx-empty (expr-Keyword) "some-key"))
   (define p (record-project ctx-empty (dynrow) m))
   (check-false (expr-error? p))))

(test-case "record-value-bound: closed = ⋃fields; dyn = ⋃knowns ∪ fresh meta"
  (with-fresh-meta-env
   (define c (closedrow (cons 'a (expr-Int))))
   (check-equal? (record-value-bound ctx-empty c) (record-value-union c))
   (define b (record-value-bound ctx-empty (dynrow (cons 'a (expr-Int)))))
   (check-true (expr-union? b) (format "expected a union bound, got ~a" b))
   (check-true (ormap expr-meta? (flatten-union b)))))

(test-case "union-record-component-vt: literal miss — closed FILTERS (#f), dyn contributes a meta"
  (with-fresh-meta-env
   (check-false (union-record-component-vt ctx-empty
                                           (closedrow (cons 'a (expr-Int)))
                                           (expr-keyword 'z)))
   (define d (union-record-component-vt ctx-empty
                                        (dynrow (cons 'a (expr-Int)))
                                        (expr-keyword 'z)))
   (check-true (expr-meta? d) (format "expected a fresh meta, got ~a" d))))

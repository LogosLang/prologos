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
                  record-value-bound record-value-union
                  record-width-applicable? record-width-discharge?)
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

;; ========================================
;; CIU T6 F1b.3 — THE GRID AMENDMENT (D21 width + D24 presence)
;; ========================================

;; marked-row builder: every field presence='unknown, dyn tail (the
;; dissoc-dynamic shape — record-mark-all-unknown's output).
(define (unkrow . flds)
  (make-record 'keyword
               (for/list ([f (in-list flds)])
                 (cons (car f) (record-field (cdr f) 'unknown)))
               'dyn))

;; ---- D21: the width discharge (shared predicates) ----

(test-case "width: wider closed actual discharges against narrower closed expected"
  (with-fresh-meta-env
   (define expected (closedrow (cons 'a (expr-Int))))
   (define actual (closedrow (cons 'a (expr-Int)) (cons 'b (expr-String))))
   (check-true (record-width-applicable? expected actual))
   (check-true (record-width-discharge? ctx-empty expected actual))))

(test-case "width NEGATIVE: missing expected label is statically inapplicable (no fork)"
  (with-fresh-meta-env
   (define expected (closedrow (cons 'a (expr-Int)) (cons 'b (expr-Int))))
   (define actual (closedrow (cons 'a (expr-Int))))
   (check-false (record-width-applicable? expected actual))))

(test-case "width NEGATIVE: shared-label type conflict rejects through the relaxed goals"
  (with-fresh-meta-env
   (define expected (closedrow (cons 'a (expr-Int))))
   (define actual (closedrow (cons 'a (expr-String)) (cons 'b (expr-Int))))
   (check-true (record-width-applicable? expected actual))
   (check-false (record-width-discharge? ctx-empty expected actual))))

(test-case "width: empty-closed expected accepts any closed keyword actual (closure erased)"
  (with-fresh-meta-env
   (define expected (make-record 'keyword '() 'closed))
   (define actual (closedrow (cons 'x (expr-Int))))
   (check-true (record-width-applicable? expected actual))
   (check-true (record-width-discharge? ctx-empty expected actual))))

(test-case "width NEGATIVE: 'nat rows (tuples) are exact — never width-applicable"
  (with-fresh-meta-env
   (define expected (make-record 'nat (list (cons 0 (record-field (expr-Int) 'present))) 'closed))
   (define actual (make-record 'nat (list (cons 0 (record-field (expr-Int) 'present))
                                          (cons 1 (record-field (expr-Int) 'present))) 'closed))
   (check-false (record-width-applicable? expected actual))))

(test-case "width NEGATIVE: dyn-tailed sides are not the discharge's business (primary-unify turf)"
  (with-fresh-meta-env
   (check-false (record-width-applicable? (dynrow (cons 'a (expr-Int)))
                                          (closedrow (cons 'a (expr-Int)) (cons 'b (expr-Int)))))))

(test-case "width: discharge solves field metas at equality depth (the D21 residue)"
  (with-fresh-meta-env
   (define m (fresh-meta ctx-empty (expr-Type (lzero)) "width-test"))
   (define expected (closedrow (cons 'a m)))
   (define actual (closedrow (cons 'a (expr-Int)) (cons 'b (expr-Bool))))
   (check-true (record-width-discharge? ctx-empty expected actual))))

;; ---- D24: the acceptance-preserving containment relaxation ----

(test-case "presence: 'unknown labels are NOT required of a closed side (acceptance-preserving)"
  ;; The marked row {:a? Int | _} vs closed {:b Int}: 'a is unknown → not
  ;; demanded. Under presence-blind containment this REJECTED — the exact
  ;; regression-vs-{| _} the D24 guard exists to prevent.
  (with-fresh-meta-env
   (check-true (unify ctx-empty
                      (unkrow (cons 'a (expr-Int)))
                      (closedrow (cons 'b (expr-Int)))))))

(test-case "presence NEGATIVE: 'present dyn-known labels stay REQUIRED (case-3 semantics hold)"
  (with-fresh-meta-env
   (check-false (unify ctx-empty
                       (dynrow (cons 'a (expr-Int)) (cons 'x (expr-Bool)))
                       (closedrow (cons 'a (expr-Int)))))))

(test-case "presence: shared 'unknown label still unifies TYPES (type-if-present is a fact)"
  (with-fresh-meta-env
   (check-false (unify ctx-empty
                       (unkrow (cons 'a (expr-String)))
                       (closedrow (cons 'a (expr-Int)) (cons 'b (expr-Int)))))))

;; ---- D24/Q7: gated-identically projection ----

(test-case "presence: an 'unknown HIT projects as a fresh meta, never the retained type"
  (with-fresh-meta-env
   (define r (record-project ctx-empty (unkrow (cons 'a (expr-Int))) (expr-keyword 'a)))
   (check-true (expr-meta? r) "courtesy upgrade rejected — fresh meta like a tail miss")))

(test-case "presence: a 'present HIT on a dyn row stays exact (case-13 sibling holds)"
  (with-fresh-meta-env
   (define r (record-project ctx-empty (dynrow (cons 'a (expr-Int))) (expr-keyword 'a)))
   (check-true (expr-Int? r))))

;; ---- D24: the comparison-precision payoff (knowns walks are presence-blind) ----

(test-case "presence: marked rows' retained types get checked against V (the payoff)"
  (with-fresh-meta-env
   ;; {:a? Int | _} <: (Map Keyword Int) — Int fits
   (check-true (record-subtypes-map? (unkrow (cons 'a (expr-Int)))
                                     (expr-Map (expr-Keyword) (expr-Int))))
   ;; {:a? String | _} <: (Map Keyword Int) — retained String REJECTS
   (check-false (record-subtypes-map? (unkrow (cons 'a (expr-String)))
                                      (expr-Map (expr-Keyword) (expr-Int))))))

;; ---- D24: union mechanics (tiebreak + absorption) ----

(test-case "presence: the 'present twin absorbs into the 'unknown twin ({P} into {P,A})"
  (with-fresh-meta-env
   (define u (build-union-type
              (list (dynrow (cons 'a (expr-Int)))
                    (unkrow (cons 'a (expr-Int))))))
   (check-true (expr-Record? u) "one branch survives — no duplicate twins")
   (check-true (eq? (record-field-presence (cdr (car (expr-Record-fields u)))) 'unknown)
               "the more-general 'unknown branch is the survivor")))

(test-case "presence: distinct-type rows do NOT absorb (types differ, no subsumption)"
  (with-fresh-meta-env
   (define u (build-union-type
              (list (dynrow (cons 'a (expr-Int)))
                    (unkrow (cons 'a (expr-String))))))
   (check-true (expr-union? u) "both branches survive")))

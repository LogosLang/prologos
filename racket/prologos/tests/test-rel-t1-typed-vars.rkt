#lang racket/base

;;;
;;; Tests for Rel Track 1 Aspect C — typed logic vars (`?x:Int` = Curry-Howard Int(x) = type).
;;;
;;; C.a (representation substrate): the `type-pred` value + the `param-info` `type`
;;; field via the #:name-redirect smart-constructor. These are pure-substrate unit
;;; tests — they guard the subtle smart-constructor idiom (the one load-bearing edit,
;;; whose naive form fails to compile) against regression, and seed the Aspect-C
;;; test file that C.b/C.c/C.d grow. Direct struct tests, so relations.rkt is required
;;; by RELATIVE path (never the collection path — see testing.md).
;;;

(require rackunit
         "../relations.rkt"
         "../syntax.rkt")

;; ========================================
;; type-pred value (the predicate SET, list-of-type-EXPR)
;; ========================================

(test-case "type-pred: constructs from a list of type-EXPRs and round-trips"
  ;; `?x:Int` → (type-pred (list (expr-Int)))
  (define tp (type-pred (list (expr-Int))))
  (check-true (type-pred? tp))
  (check-equal? (length (type-pred-preds tp)) 1)
  (check-true (expr-Int? (car (type-pred-preds tp)))))

(test-case "type-pred: conjunction carries multiple predicates in the list slot"
  ;; `?x:Int:Even`-shaped conjunction → two type-EXPRs (Even elided here to Int twice)
  (define tp (type-pred (list (expr-Int) (expr-Int))))
  (check-equal? (length (type-pred-preds tp)) 2))

(test-case "type-pred: empty predicate set is representable (still a type-pred, not #f)"
  (define tp (type-pred '()))
  (check-true (type-pred? tp))
  (check-equal? (type-pred-preds tp) '()))

;; ========================================
;; param-info smart-constructor: 2-arg legacy vs 3-arg typed
;; ========================================

(test-case "param-info: 2-arg construction defaults type to #f (legacy sites untouched)"
  (define p (param-info 'x 'free))
  (check-equal? (param-info-name p) 'x)
  (check-equal? (param-info-mode p) 'free)
  (check-false (param-info-type p)))

(test-case "param-info: 3-arg construction carries a type-pred"
  (define tp (type-pred (list (expr-Int))))
  (define p (param-info 'x 'free tp))
  (check-equal? (param-info-name p) 'x)
  (check-equal? (param-info-mode p) 'free)
  (check-eq? (param-info-type p) tp)
  ;; the type-EXPR is reachable through the param
  (check-true (expr-Int? (car (type-pred-preds (param-info-type p))))))

(test-case "param-info: predicate + transparency preserved under the #:name-redirect"
  (define p (param-info 'y 'in))
  (check-true (param-info? p))
  (check-false (param-info? 'not-a-param))
  ;; #:transparent equal? holds for legacy 2-arg twins (both type=#f)
  (check-equal? (param-info 'z 'free) (param-info 'z 'free))
  ;; a typed param and its untyped twin are NOT equal? (the type field participates)
  (check-not-equal? (param-info 'z 'free (type-pred (list (expr-Int))))
                    (param-info 'z 'free)))

#lang racket/base

;;; test-attribute-record.rkt — Track 4B Phase 1: Attribute Record PU
;;; Tests for the 5-facet nested hasheq structure, merge functions,
;;; that-read/that-write API, and facet bot values.

(require rackunit
         rackunit/text-ui
         prologos/propagator
         prologos/typing-propagators
         prologos/syntax
         prologos/prelude
         prologos/type-lattice
         (only-in prologos/constraint-cell
                  constraint-candidate constraint-from-candidates
                  constraint-one? constraint-bot? constraint-bot))

(define attribute-record-tests
  (test-suite
   "Track 4B Phase 1: Attribute Record PU"

   (test-case "facet-bot: each facet has a distinct bot value"
     (check-equal? (facet-bot ':type) type-bot)
     (check-equal? (facet-bot ':context) #f)
     (check-true (constraint-bot? (facet-bot ':constraints)))
     (check-equal? (facet-bot ':usage) '())
     (check-equal? (facet-bot ':warnings) '()))

   (test-case "facet-bot?: correctly detects bot for each facet"
     (check-true (facet-bot? ':type type-bot))
     (check-false (facet-bot? ':type (expr-Int)))
     (check-true (facet-bot? ':context #f))
     (check-false (facet-bot? ':context context-empty-value))
     (check-true (facet-bot? ':usage '()))
     (check-false (facet-bot? ':usage '(m0)))
     (check-true (facet-bot? ':warnings '()))
     (check-false (facet-bot? ':warnings '(w1))))

   (test-case "context-bot is #f, not context-empty-value"
     (check-false (facet-bot ':context))
     (check-true (context-cell-value? context-empty-value))
     (check-false (context-cell-value? #f)))

   (test-case "that-read: reads facet from nested attribute map"
     (define am (hasheq 'pos-a (hasheq ':type (expr-Int) ':usage '(m0 m1))))
     (check-equal? (that-read am 'pos-a ':type) (expr-Int))
     (check-equal? (that-read am 'pos-a ':usage) '(m0 m1))
     (check-equal? (that-read am 'pos-a ':warnings) '())
     (check-equal? (that-read am 'pos-b ':type) type-bot))

   (test-case "that-write + merge: creates nested records"
     (define net0 (make-prop-network))
     (define-values (net1 cid) (net-new-cell net0 (hasheq) attribute-map-merge-fn))
     (define net2 (that-write net1 cid 'pos-a ':type (expr-Int)))
     (define am (net-cell-read net2 cid))
     (check-equal? (that-read am 'pos-a ':type) (expr-Int))
     (define net3 (that-write net2 cid 'pos-a ':usage '(m0)))
     (define am2 (net-cell-read net3 cid))
     (check-equal? (that-read am2 'pos-a ':type) (expr-Int))
     (check-equal? (that-read am2 'pos-a ':usage) '(m0)))

   (test-case "attribute-map-merge-fn: two-level pointwise"
     (define old (hasheq 'pos-a (hasheq ':type (expr-Int))))
     (define new (hasheq 'pos-b (hasheq ':type (expr-Bool))))
     (define merged (attribute-map-merge-fn old new))
     (check-equal? (that-read merged 'pos-a ':type) (expr-Int))
     (check-equal? (that-read merged 'pos-b ':type) (expr-Bool)))

   (test-case "facet-merge :type uses type-lattice-merge"
     (check-equal? (facet-merge ':type type-bot (expr-Int)) (expr-Int))
     (check-equal? (facet-merge ':type (expr-Int) (expr-Int)) (expr-Int))
     (check-true (type-top? (facet-merge ':type (expr-Int) (expr-Bool)))))

   (test-case "facet-merge :constraints uses constraint-merge (intersection)"
     (define c1 (constraint-from-candidates
                  (list (constraint-candidate 'Add '(Nat) 'Nat--Add--dict))))
     (define c2 (constraint-from-candidates
                  (list (constraint-candidate 'Add '(Nat) 'Nat--Add--dict)
                        (constraint-candidate 'Add '(Int) 'Int--Add--dict))))
     (define merged (facet-merge ':constraints c1 c2))
     (check-true (constraint-one? merged)))

   (test-case "facet-merge :usage uses pointwise mult-add"
     (check-equal? (facet-merge ':usage '(m0 m1) '(m1 m0)) '(m1 m1)))

   (test-case "facet-merge :warnings uses append"
     (check-equal? (facet-merge ':warnings '(a) '(b)) '(a b)))))

(run-tests attribute-record-tests)

#lang racket/base

;;; test-sre-coverage.rkt — Track 4B Phase 9: SRE Expression Coverage
;;; Tests for custom match cases added to install-typing-network:
;;; ann, tycon, reduce, pair, generic ops, from-int/from-rat,
;;; coercion detection, and contradiction propagation.

(require rackunit
         rackunit/text-ui
         prologos/propagator
         prologos/typing-propagators
         prologos/syntax
         prologos/prelude
         prologos/type-lattice)

(define sre-coverage-tests
  (test-suite
   "Track 4B Phase 9: SRE expression coverage"

   (test-case "ann: (the Int 42) → Int"
     (parameterize ([current-attribute-map-cell-id #f])
       (define e (expr-ann (expr-int 42) (expr-Int)))
       (define net0 (make-prop-network))
       (define-values (_net ty _sols _warns)
         (infer-on-network net0 e (context-cell-value '() 0)))
       (check-equal? ty (expr-Int))))

   (test-case "tycon: List has Pi kind if arity registered"
     (parameterize ([current-attribute-map-cell-id #f])
       (define e (expr-tycon 'List))
       (define net0 (make-prop-network))
       (define-values (_net ty _sols _warns)
         (infer-on-network net0 e (context-cell-value '() 0)))
       (if (tycon-arity 'List)
           (check-true (expr-Pi? ty))
           (check-equal? ty type-bot))))

   (test-case "pair: (pair 42 true) → Sigma(Int, Bool)"
     (parameterize ([current-attribute-map-cell-id #f])
       (define e (expr-pair (expr-int 42) (expr-true)))
       (define net0 (make-prop-network))
       (define-values (_net ty _sols _warns)
         (infer-on-network net0 e (context-cell-value '() 0)))
       (check-true (expr-Sigma? ty))
       (when (expr-Sigma? ty)
         (check-equal? (expr-Sigma-fst-type ty) (expr-Int))
         (check-equal? (expr-Sigma-snd-type ty) (expr-Bool)))))

   (test-case "generic-add: (+ 1 2) → Int via numeric-join"
     (parameterize ([current-attribute-map-cell-id #f])
       (define e (expr-generic-add (expr-int 1) (expr-int 2)))
       (define net0 (make-prop-network))
       (define-values (_net ty _sols _warns)
         (infer-on-network net0 e (context-cell-value '() 0)))
       (check-equal? ty (expr-Int))))

   (test-case "generic-add cross-family: (+ Int Nat) → Int (wider exact)"
     (parameterize ([current-attribute-map-cell-id #f])
       (define e (expr-generic-add (expr-int 1) (expr-nat-val 2)))
       (define net0 (make-prop-network))
       (define-values (_net ty _sols _warns)
         (infer-on-network net0 e (context-cell-value '() 0)))
       (check-equal? ty (expr-Int))))

   (test-case "generic-lt: comparison → Bool"
     (parameterize ([current-attribute-map-cell-id #f])
       (define e (expr-generic-lt (expr-int 1) (expr-int 2)))
       (define net0 (make-prop-network))
       (define-values (_net ty _sols _warns)
         (infer-on-network net0 e (context-cell-value '() 0)))
       (check-equal? ty (expr-Bool))))

   (test-case "generic-negate: unary → same type as arg"
     (parameterize ([current-attribute-map-cell-id #f])
       (define e (expr-generic-negate (expr-int 5)))
       (define net0 (make-prop-network))
       (define-values (_net ty _sols _warns)
         (infer-on-network net0 e (context-cell-value '() 0)))
       (check-equal? ty (expr-Int))))

   (test-case "reduce: (reduce zero | zero -> 42 | suc x -> 0) → Int"
     (parameterize ([current-attribute-map-cell-id #f])
       (define scrutinee (expr-zero))
       (define arm1 (expr-reduce-arm 'zero 0 (expr-int 42)))
       (define arm2 (expr-reduce-arm 'suc 1 (expr-int 0)))
       (define e (expr-reduce scrutinee (list arm1 arm2) #t))
       (define net0 (make-prop-network))
       (define-values (_net ty _sols _warns)
         (infer-on-network net0 e (context-cell-value '() 0)))
       (check-equal? ty (expr-Int))))

   (test-case "contradiction: APP f(true) where f : Int→Int → type-top"
     (parameterize ([current-attribute-map-cell-id #f])
       (define func-e (expr-fvar 'f))
       (define arg-e (expr-true))
       (define app-e (expr-app func-e arg-e))
       (define net0 (make-prop-network))
       (define-values (net1 tm-cid)
         (net-new-cell net0
           (hasheq func-e (hasheq ':type (expr-Pi 'mw (expr-Int) (expr-Int))))
           attribute-map-merge-fn))
       (define net2 (install-typing-network net1 tm-cid app-e
                      (context-cell-value '() 0)))
       (define net3 (run-to-quiescence net2))
       (define tm (net-cell-read net3 tm-cid))
       (check-true (type-top? (that-read tm app-e ':type)))))))

(run-tests sre-coverage-tests)

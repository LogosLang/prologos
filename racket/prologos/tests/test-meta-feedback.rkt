#lang racket/base

;;; test-meta-feedback.rkt — Track 4B Phase 3: Meta-feedback + coercion
;;; Tests for simple meta-feedback, structural meta-feedback,
;;; type-family classification, and coercion detection propagator.

(require rackunit
         rackunit/text-ui
         prologos/propagator
         prologos/typing-propagators
         prologos/syntax
         prologos/prelude
         prologos/type-lattice)

(define meta-feedback-tests
  (test-suite
   "Track 4B Phase 3: Meta-feedback mechanisms"

   (test-case "simple meta-feedback: domain meta gets arg type"
     (parameterize ([current-attribute-map-cell-id #f])
       (define meta-a (expr-meta 'mf-test-a (cell-id 99)))
       (define func-e (expr-fvar 'f))
       (define arg-e (expr-nat-val 5))
       (define app-e (expr-app func-e arg-e))
       (define net0 (make-prop-network))
       (define-values (net1 tm-cid)
         (net-new-cell net0
           (hasheq func-e (hasheq ':type (expr-Pi 'mw meta-a (expr-Bool))))
           attribute-map-merge-fn))
       (define net2 (install-typing-network net1 tm-cid app-e
                      (context-cell-value '() 0)))
       (define net3 (run-to-quiescence net2))
       (define tm (net-cell-read net3 tm-cid))
       ;; Feedback: ?A → Nat
       (check-equal? (that-read tm meta-a ':type) (expr-Nat))))

   (test-case "Option C: downward write skipped for meta arg positions"
     ;; When arg-pos is a meta, the downward domain write is skipped
     ;; to prevent kind/solution conflicts
     (parameterize ([current-attribute-map-cell-id #f])
       (define meta-arg (expr-meta 'opt-c-test (cell-id 98)))
       (define func-e (expr-fvar 'g))
       (define app-e (expr-app func-e meta-arg))
       (define net0 (make-prop-network))
       ;; func type: Pi(m0, Type(0), Bool) — domain is Type(0)
       (define-values (net1 tm-cid)
         (net-new-cell net0
           (hasheq func-e (hasheq ':type (expr-Pi 'm0 (expr-Type (lzero)) (expr-Bool))))
           attribute-map-merge-fn))
       (define net2 (install-typing-network net1 tm-cid app-e
                      (context-cell-value '() 0)))
       (define net3 (run-to-quiescence net2))
       (define tm (net-cell-read net3 tm-cid))
       ;; Option C: meta-arg's :type should NOT be Type(0)
       ;; It should be bot (skipped) or the feedback solution
       (define meta-type (that-read tm meta-arg ':type))
       (check-false (and (expr-Type? meta-type)
                         (equal? (expr-Type-level meta-type) (lzero)))
                    "Option C: Type(0) should NOT be written to meta arg")))))

(define coercion-tests
  (test-suite
   "Track 4B Phase 7: Type family + coercion detection"

   (test-case "type-family: exact types"
     (check-equal? (type-family (expr-Int)) 'exact)
     (check-equal? (type-family (expr-Nat)) 'exact))

   (test-case "type-family: approximate types"
     (check-equal? (type-family (expr-Posit8)) 'approximate)
     (check-equal? (type-family (expr-Posit16)) 'approximate)
     (check-equal? (type-family (expr-Posit32)) 'approximate)
     (check-equal? (type-family (expr-Posit64)) 'approximate))

   (test-case "type-family: other types"
     (check-equal? (type-family (expr-Bool)) 'other)
     (check-equal? (type-family (expr-String)) 'other)
     (check-equal? (type-family type-bot) 'other))

   (test-case "coercion-detection: cross-family → warning"
     (parameterize ([current-attribute-map-cell-id #f])
       (define net0 (make-prop-network))
       (define-values (net1 tm-cid)
         (net-new-cell net0 (hasheq) attribute-map-merge-fn))
       (define pos-a (gensym 'ca))
       (define pos-b (gensym 'cb))
       (define pos-op (gensym 'cop))
       (define net2 (that-write net1 tm-cid pos-a ':type (expr-Int)))
       (define net3 (that-write net2 tm-cid pos-b ':type (expr-Posit32)))
       (define-values (net4 _pid)
         (net-add-propagator net3 (list tm-cid) (list tm-cid)
           (make-coercion-detection-fire-fn tm-cid pos-op pos-a pos-b)
           #:component-paths
           (list (cons tm-cid (cons pos-a ':type))
                 (cons tm-cid (cons pos-b ':type)))))
       (define net5 (run-to-quiescence net4))
       (define tm (net-cell-read net5 tm-cid))
       (define warns (that-read tm pos-op ':warnings))
       (check-true (pair? warns))
       (check-equal? (car (car warns)) 'coercion-warning)))

   (test-case "coercion-detection: same-family → no warning"
     (parameterize ([current-attribute-map-cell-id #f])
       (define net0 (make-prop-network))
       (define-values (net1 tm-cid)
         (net-new-cell net0 (hasheq) attribute-map-merge-fn))
       (define pos-a (gensym 'sa))
       (define pos-b (gensym 'sb))
       (define pos-op (gensym 'sop))
       (define net2 (that-write net1 tm-cid pos-a ':type (expr-Int)))
       (define net3 (that-write net2 tm-cid pos-b ':type (expr-Nat)))
       (define-values (net4 _pid)
         (net-add-propagator net3 (list tm-cid) (list tm-cid)
           (make-coercion-detection-fire-fn tm-cid pos-op pos-a pos-b)
           #:component-paths
           (list (cons tm-cid (cons pos-a ':type))
                 (cons tm-cid (cons pos-b ':type)))))
       (define net5 (run-to-quiescence net4))
       (define tm (net-cell-read net5 tm-cid))
       (check-equal? (that-read tm pos-op ':warnings) '())))))

(run-tests meta-feedback-tests)
(run-tests coercion-tests)

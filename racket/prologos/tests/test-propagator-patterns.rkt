#lang racket/base

;;; test-propagator-patterns.rkt — Track 4B: P1/P2/P3 Propagator Patterns
;;; Tests for initial writes, fire-once guard, and per-command cleanup.

(require rackunit
         rackunit/text-ui
         prologos/propagator
         prologos/typing-propagators
         prologos/syntax
         prologos/prelude
         prologos/type-lattice)

(define propagator-pattern-tests
  (test-suite
   "Track 4B: Propagator patterns P1/P2/P3"

   (test-case "P1: initial write — no propagator, immediate availability"
     (parameterize ([current-attribute-map-cell-id #f])
       (define net0 (make-prop-network))
       (define-values (net1 tm-cid)
         (net-new-cell net0 (hasheq) attribute-map-merge-fn))
       (define lit-e (expr-int 42))
       (define net2 (that-write net1 tm-cid lit-e ':type (expr-Int)))
       (check-equal? (that-read (net-cell-read net2 tm-cid) lit-e ':type) (expr-Int))))

   (test-case "P2: fire-once — fires once then instant no-op"
     (parameterize ([current-attribute-map-cell-id #f])
       (define fire-count (box 0))
       (define net0 (make-prop-network))
       (define-values (net1 cid)
         (net-new-cell net0 0 (lambda (a b) (+ a b))))
       (define-values (net2 _pid)
         (net-add-fire-once-propagator net1 (list cid) (list cid)
           (lambda (n)
             (set-box! fire-count (add1 (unbox fire-count)))
             (net-cell-write n cid 1))
           cid))
       (define net3 (run-to-quiescence net2))
       (check-equal? (net-cell-read net3 cid) 1)
       (check-equal? (unbox fire-count) 1)
       ;; Trigger another change — fire-once should NOT fire again
       (define net4 (net-cell-write net3 cid 10))
       (define net5 (run-to-quiescence net4))
       (check-equal? (unbox fire-count) 1)))

   (test-case "P2: fire-once — no-op fire doesn't set flag"
     (parameterize ([current-attribute-map-cell-id #f])
       (define fire-count (box 0))
       (define net0 (make-prop-network))
       (define-values (net1 cid)
         (net-new-cell net0 type-bot (lambda (a b) (if (type-bot? a) b a))))
       ;; Propagator waits for non-bot, then fires
       (define-values (net2 _pid)
         (net-add-fire-once-propagator net1 (list cid) (list cid)
           (lambda (n)
             (define v (net-cell-read n cid))
             (if (type-bot? v)
                 n  ;; no-op: input not ready
                 (begin
                   (set-box! fire-count (add1 (unbox fire-count)))
                   (net-cell-write n cid (expr-Int)))))
           cid))
       ;; First quiescence: cell is bot, propagator no-ops
       (define net3 (run-to-quiescence net2))
       (check-equal? (unbox fire-count) 0)
       ;; Write a value, propagator should fire NOW
       (define net4 (net-cell-write net3 cid (expr-Nat)))
       (define net5 (run-to-quiescence net4))
       (check-equal? (unbox fire-count) 1)))

   (test-case "P3: net-clear-dependents — clears propagators, retains value"
     (define net0 (make-prop-network))
     (define-values (net1 cid) (net-new-cell net0 42 max))
     (define-values (net2 _pid)
       (net-add-propagator net1 (list cid) (list cid) (lambda (n) n)))
     (define net3 (net-clear-dependents net2 cid))
     (check-equal? (net-cell-read net3 cid) 42))

   (test-case "that-read/that-write: attribute record API"
     (parameterize ([current-attribute-map-cell-id #f])
       (define net0 (make-prop-network))
       (define-values (net1 tm-cid)
         (net-new-cell net0 (hasheq) attribute-map-merge-fn))
       (define e (expr-int 1))
       (check-equal? (that-read (net-cell-read net1 tm-cid) e ':type) type-bot)
       (define net2 (that-write net1 tm-cid e ':type (expr-Int)))
       (check-equal? (that-read (net-cell-read net2 tm-cid) e ':type) (expr-Int))))))

(run-tests propagator-pattern-tests)

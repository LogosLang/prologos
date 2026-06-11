#lang racket/base
;; PReduce Track 1 — #:after stratum-ordering substrate (stratification.md CAUTION
;; discharged; ledger iter 10). Tests the PURE order-stratum-entries directly.
(require rackunit
         "../propagator.rkt")

;; entry shape: (list request-cell-id handler-fn tier reset-value after keep-pending?)
(define (E n #:tier [tier 'value] #:after [after '()] #:keep [keep #f])
  (list (cell-id n) (lambda (net pending) net) tier (hasheq)
        (map cell-id after) keep))

(define (order-of entries)
  (for/list ([e (in-list (order-stratum-entries entries))]) (cell-id-n (car e))))

;; chain: B #:after A → A before B, regardless of registration order
(check-equal? (order-of (list (E 2 #:after '(1)) (E 1))) '(1 2))
(check-equal? (order-of (list (E 1) (E 2 #:after '(1)))) '(1 2))

;; stability: unconstrained entries keep registration order
(check-equal? (order-of (list (E 3) (E 1) (E 2))) '(3 1 2))

;; stability under partial constraints: only the constrained pair reorders
(check-equal? (order-of (list (E 5 #:after '(7)) (E 6) (E 7))) '(6 7 5))

;; diamond: D after B,C; B,C after A
(check-equal? (order-of (list (E 4 #:after '(2 3)) (E 2 #:after '(1))
                              (E 3 #:after '(1)) (E 1)))
              '(1 2 3 4))

;; cycle errors loudly at sort time (= registration time in production)
(check-exn exn:fail?
  (lambda () (order-stratum-entries (list (E 1 #:after '(2)) (E 2 #:after '(1))))))

;; unknown #:after target is inert (the target may register later; the box
;; re-sorts on every registration, so the edge takes effect when it arrives)
(check-equal? (order-of (list (E 2 #:after '(99)) (E 1))) '(2 1))

;; tiers sort independently; a value entry's after on a TOPOLOGY cid is inert
;; (topology tier already runs first by construction)
(let* ([sorted (order-stratum-entries
                (list (E 10 #:tier 'value #:after '(20))
                      (E 20 #:tier 'topology)
                      (E 11 #:tier 'value)))]
       [tiers (for/list ([e (in-list sorted)]) (caddr e))])
  ;; reassembly: topology entries first, then value — and value order unchanged
  (check-equal? tiers '(topology value value))
  (check-equal? (for/list ([e (in-list sorted)]) (cell-id-n (car e))) '(20 10 11)))

;; keep-pending? accessor round-trips through the sort
(let ([sorted (order-stratum-entries (list (E 1 #:keep #t) (E 2)))])
  (check-true (list-ref (car sorted) 5))
  (check-false (list-ref (cadr sorted) 5)))

#lang racket/base
;;;
;;; test-bsp-fire-protocol.rkt — DEFERRED 147: the BSP fire protocol's bookkeeping
;;;
;;; 147 replaced three pieces of per-fire / per-write bookkeeping with cheaper
;;; equivalents (measured: read-only fire 1 313 → 928 B, read+write 2 746 →
;;; 2 231 B on the census workload). Each pin below fails if the replacement
;;; is NOT equivalent:
;;;   - dedup-pids: a mutable hasheqv keyed by prop-id-n instead of a persistent
;;;     CHAMP set — same relation (prop-id is a one-field struct), first-occurrence
;;;     order kept;
;;;   - fire-and-collect-writes: declared-output membership by `memq` instead of a
;;;     per-fire for/hasheq — a declared write misclassified as undeclared would
;;;     be direct-set (last writer wins) instead of merged;
;;;   - net-cell-write slow path: one fold computing the component-path and
;;;     assumption flags, skipped when there are no dependents (covered by the
;;;     component-paths / per-nogood / retraction suites; pinned here for the
;;;     no-dependents and plain-dependents cases).

(require rackunit
         rackcheck
         racket/list
         "../propagator.rkt"
         "../champ.rkt")
(require/expose "../propagator.rkt" (dedup-pids))

(define (set-merge old new)
  (let loop ([items new] [result old])
    (cond
      [(null? items) result]
      [(member (car items) result) (loop (cdr items) result)]
      [else (loop (cdr items) (cons (car items) result))])))

;; ---- dedup-pids -------------------------------------------------------------
(test-case "147: dedup-pids — property: first occurrence by prop-id-n, order kept, fresh equal ids collapse"
  (check-property
   (make-config #:tests 300)
   (property ([ns (gen:list (gen:integer-in 0 15) #:max-length 40)])
     (define ps (for/list ([n (in-list ns)]) (prop-id n)))   ;; fresh instances: equal?, never eq?
     (define got (dedup-pids ps))
     (define want (remove-duplicates ps #:key prop-id-n))
     (check-equal? (map prop-id-n got) (map prop-id-n want))
     ;; and each kept element IS the first occurrence (not merely equal to it)
     (for ([g (in-list got)] [w (in-list want)]) (check-eq? g w)))))

(test-case "147: a propagator enqueued twice in one round fires once"
  (define fires (box 0))
  (define net0 (make-prop-network))
  (define-values (n1 ca) (net-new-cell net0 0 max))
  (define-values (n2 cb) (net-new-cell n1 0 max))
  (define-values (n3 cd) (net-new-cell n2 0 max))
  (define-values (n4 _p)
    (net-add-propagator n3 (list ca cb) (list cd)
                        (lambda (net)
                          (set-box! fires (add1 (unbox fires)))
                          (net-cell-write net cd (+ (net-cell-read net ca) (net-cell-read net cb))))))
  ;; installing the propagator schedules it once; drain that first
  (define n5 (run-to-quiescence-bsp n4))
  (set-box! fires 0)
  ;; writing BOTH inputs puts the propagator on the worklist twice
  (define n6 (net-cell-write (net-cell-write n5 ca 3) cb 4))
  (check-equal? (length (prop-network-worklist n6)) 2)
  (define n7 (run-to-quiescence-bsp n6))
  (check-equal? (unbox fires) 1)
  (check-equal? (net-cell-read n7 cd) 7))

;; ---- declared-output classification -----------------------------------------
(test-case "147: two propagators writing one DECLARED output in the same round are both merged"
  (define net0 (make-prop-network))
  (define-values (n1 trig) (net-new-cell net0 #f (lambda (a b) (or a b))))
  (define-values (n2 out) (net-new-cell n1 '() set-merge))
  (define-values (n3 _p1) (net-add-propagator n2 (list trig) (list out)
                            (lambda (net) (if (net-cell-read net trig) (net-cell-write net out '(a)) net))))
  (define-values (n4 _p2) (net-add-propagator n3 (list trig) (list out)
                            (lambda (net) (if (net-cell-read net trig) (net-cell-write net out '(b)) net))))
  (define result (run-to-quiescence-bsp (net-cell-write (run-to-quiescence-bsp n4) trig #t)))
  (check-equal? (sort (net-cell-read result out) symbol<?) '(a b)))

;; ---- slow-path dependent flags ----------------------------------------------
(test-case "147: a write to a cell with NO dependents changes the value and enqueues nothing"
  (define net0 (make-prop-network))
  (define-values (n1 c) (net-new-cell net0 0 max))
  (define n2 (net-cell-write n1 c 5))
  (check-equal? (net-cell-read n2 c) 5)
  (check-equal? (prop-network-worklist n2) '()))

(test-case "147: plain dependents (no paths, no assumptions) are all enqueued, in dependents order"
  (define net0 (make-prop-network))
  (define-values (n1 c) (net-new-cell net0 0 max))
  (define-values (n2 pids)
    (for/fold ([net n1] [pids '()]) ([i 5])
      (define-values (net2 out) (net-new-cell net 0 max))
      (define-values (net3 pid) (net-add-propagator net2 (list c) (list out) (lambda (net) net)))
      (values net3 (cons pid pids))))
  (define n3 (run-to-quiescence-bsp n2))
  (define n4 (net-cell-write n3 c 9))
  (check-equal? (sort (map prop-id-n (prop-network-worklist n4)) <)
                (sort (map prop-id-n pids) <)))

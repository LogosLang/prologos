#lang racket/base
;; PReduce Track 1 SM1.1b — shape-P delta-notify microbench (§5.8 obligation).
;;
;; Measures the slow-path write cost (component-path dependent present → diff
;; computed) on an attribute-map cell at N positions, for a 1-position delta.
;; BEFORE shape-P: pu-value-diff iterates ALL merged keys → O(N) per write.
;; AFTER shape-P ('pointwise-compound storage): changed-paths from the DELTA's
;; keys → O(|delta|) per write. Run before AND after the change; record both
;; in the autonomy ledger (microbench-claim verification, workflow.md).
(require racket/match
         "../../syntax.rkt"
         "../../propagator.rkt"
         "../../typing-propagators.rkt")

(define-syntax-rule (bench-ns label N-val body)
  (let* ([N N-val]
         [_ (for ([i (in-range (quotient N 10))]) body)]  ;; warmup
         [t0 (current-inexact-monotonic-milliseconds)])
    (for ([i (in-range N)]) body)
    (let* ([t1 (current-inexact-monotonic-milliseconds)]
           [ns-per (/ (* (- t1 t0) 1e6) N)])
      (printf "~a: ~a ns/op  (~a ops, ~a ms)\n"
              label (real->decimal-string ns-per 0) N
              (real->decimal-string (- t1 t0) 1))
      ns-per)))

(define (make-fixture n-positions #:pointwise? [pointwise? #f])
  (define net0 (make-prop-network))
  (define-values (net1 cid)
    (if pointwise?
        (let-values ([(n c) (net-register-specialized-cell net0 (hasheq)
                              attribute-map-merge-fn
                              #:tier 'warm
                              #:storage 'pointwise-compound
                              #:fires-on 'any-change)])
          (values n c))
        (net-new-cell net0 (hasheq) attribute-map-merge-fn)))
  (define positions (for/list ([i (in-range n-positions)]) (string->symbol (format "pos~a" i))))
  ;; Populate N positions (one batched write)
  (define big-delta
    (for/hasheq ([p (in-list positions)])
      (values p (hasheq ':type (expr-Int)))))
  (define net2 (net-cell-write net1 cid big-delta))
  ;; ONE dependent with component-paths → has-component-paths? = #t → diff runs
  (define-values (net3 _pid)
    (net-add-fire-once-propagator net2 (list cid) (list cid)
      (lambda (net) net)
      #:component-paths (list (cons cid (cons (car positions) ':type)))))
  (values net3 cid (car positions)))

(define (run-suite #:pointwise? [pointwise? #f])
  (printf "== ~a ==\n" (if pointwise? "pointwise-compound (shape-P)" "plain (pu-value-diff)"))
  (for ([n (in-list '(100 1000 5000))])
    (define-values (net cid pos) (make-fixture n #:pointwise? pointwise?))
    (define delta (hasheq pos (hasheq ':type (expr-Bool))))
    (bench-ns (format "write 1-pos delta @ N=~a" n) 2000
              (net-cell-write net cid delta))))

(module+ main
  (run-suite #:pointwise? #f)
  ;; The pointwise variant only differs once shape-P lands; harmless before
  ;; (storage enum unknown to the diff dispatch → identical slow path).
  (run-suite #:pointwise? #t))

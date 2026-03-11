#lang racket/base

;;;
;;; test-infra-cell-parallel-01.rkt — Parallel propagation verification + benchmarks
;;;
;;; Phase 0d of the Propagator-First Migration Sprint.
;;; Verifies that infrastructure cells produce identical results under
;;; sequential, BSP, and parallel schedulers. Benchmarks overhead.
;;;

(require rackunit
         racket/set
         racket/format
         "../propagator.rkt"
         "../infra-cell.rkt")

;; ========================================
;; Helper: Build a test network with N independent registry cells
;; ========================================

;; Creates N registry cells, each with a propagator that copies from
;; a source cell. Returns (values network source-cid (list result-cid ...))
(define (make-independent-network n)
  (define net0 (make-prop-network))
  ;; Source cell — write triggers all propagators
  (define-values (net1 source-cid) (net-new-registry-cell net0))
  ;; Create N result cells + propagators
  (let loop ([net net1] [i 0] [result-cids '()])
    (if (>= i n)
        (values net source-cid (reverse result-cids))
        (let-values ([(net2 rcid) (net-new-registry-cell net)])
          (let-values ([(net3 _pid)
                        (net-add-propagator net2 (list source-cid) (list rcid)
                          (lambda (net)
                            (define src (net-cell-read net source-cid))
                            (if (hash-empty? src) net
                                (net-cell-write net rcid
                                  (hasheq (string->symbol (format "from-~a" i))
                                          (hash-count src))))))])
            (loop net3 (+ i 1) (cons rcid result-cids)))))))

;; ========================================
;; Correctness: Sequential vs BSP vs Parallel produce same results
;; ========================================

(test-case "10 independent propagators: sequential = BSP"
  (define-values (net0 src-cid result-cids) (make-independent-network 10))
  (define net1 (net-cell-write net0 src-cid (hasheq 'trigger 1)))
  ;; Sequential
  (define net-seq (run-to-quiescence net1))
  ;; BSP (sequential executor)
  (define net-bsp (run-to-quiescence-bsp net1))
  ;; Compare all result cells
  (for ([rcid (in-list result-cids)])
    (check-equal? (net-cell-read net-seq rcid)
                  (net-cell-read net-bsp rcid)
                  (format "cell ~a mismatch" rcid))))

(test-case "10 independent propagators: sequential = parallel"
  (define-values (net0 src-cid result-cids) (make-independent-network 10))
  (define net1 (net-cell-write net0 src-cid (hasheq 'trigger 1)))
  ;; Sequential
  (define net-seq (run-to-quiescence net1))
  ;; BSP with parallel executor
  (define parallel-exec (make-parallel-fire-all 2))
  (define net-par (run-to-quiescence-bsp net1 #:executor parallel-exec))
  ;; Compare
  (for ([rcid (in-list result-cids)])
    (check-equal? (net-cell-read net-seq rcid)
                  (net-cell-read net-par rcid)
                  (format "cell ~a mismatch" rcid))))

;; ========================================
;; Dependent Chain: Correctness
;; ========================================

(test-case "dependent chain A → B → C: BSP converges correctly"
  (define net0 (make-prop-network))
  (define-values (net1 cid-a) (net-new-replace-cell net0))
  (define-values (net2 cid-b) (net-new-replace-cell net1))
  (define-values (net3 cid-c) (net-new-replace-cell net2))
  ;; A → B: double the value
  (define-values (net4 _p1)
    (net-add-propagator net3 (list cid-a) (list cid-b)
      (lambda (net)
        (define a (net-cell-read net cid-a))
        (if (eq? a 'infra-bot) net
            (net-cell-write net cid-b (* a 2))))))
  ;; B → C: add 10
  (define-values (net5 _p2)
    (net-add-propagator net4 (list cid-b) (list cid-c)
      (lambda (net)
        (define b (net-cell-read net cid-b))
        (if (eq? b 'infra-bot) net
            (net-cell-write net cid-c (+ b 10))))))
  ;; Write 5 to A
  (define net6 (net-cell-write net5 cid-a 5))
  ;; Sequential
  (define net-seq (run-to-quiescence net6))
  ;; BSP
  (define net-bsp (run-to-quiescence-bsp net6))
  ;; A=5, B=10, C=20
  (check-equal? (net-cell-read net-seq cid-a) 5)
  (check-equal? (net-cell-read net-seq cid-b) 10)
  (check-equal? (net-cell-read net-seq cid-c) 20)
  ;; BSP matches
  (check-equal? (net-cell-read net-bsp cid-a) 5)
  (check-equal? (net-cell-read net-bsp cid-b) 10)
  (check-equal? (net-cell-read net-bsp cid-c) 20))

;; ========================================
;; Mixed Cell Types: Correctness Under BSP
;; ========================================

(test-case "mixed cell types (registry + list + set) converge under BSP"
  (define net0 (make-prop-network))
  (define-values (net1 reg-cid) (net-new-registry-cell net0))
  (define-values (net2 log-cid) (net-new-list-cell net1))
  (define-values (net3 tag-cid) (net-new-set-cell net2))
  ;; reg → log: log the count
  (define-values (net4 _p1)
    (net-add-propagator net3 (list reg-cid) (list log-cid)
      (lambda (net)
        (define r (net-cell-read net reg-cid))
        (if (hash-empty? r) net
            (net-cell-write net log-cid
                            (list (format "count=~a" (hash-count r))))))))
  ;; reg → tag: add key names as symbols to set
  (define-values (net5 _p2)
    (net-add-propagator net4 (list reg-cid) (list tag-cid)
      (lambda (net)
        (define r (net-cell-read net reg-cid))
        (if (hash-empty? r) net
            (net-cell-write net tag-cid
                            (list->seteq (hash-keys r)))))))
  ;; Write to registry
  (define net6 (net-cell-write net5 reg-cid (hasheq 'alpha 1 'beta 2)))
  ;; Sequential
  (define net-seq (run-to-quiescence net6))
  ;; BSP
  (define net-bsp (run-to-quiescence-bsp net6))
  ;; Parallel
  (define net-par (run-to-quiescence-bsp net6 #:executor (make-parallel-fire-all 1)))
  ;; All should agree
  (for ([label '("seq" "bsp" "par")]
        [net (list net-seq net-bsp net-par)])
    (check-true (pair? (net-cell-read net log-cid))
                (format "~a: log empty" label))
    (check-true (set-member? (net-cell-read net tag-cid) 'alpha)
                (format "~a: alpha missing" label))
    (check-true (set-member? (net-cell-read net tag-cid) 'beta)
                (format "~a: beta missing" label))))

;; ========================================
;; Benchmark: Sequential vs BSP vs Parallel
;; ========================================

(test-case "benchmark: overhead characterization (100 cells, 50 propagators)"
  ;; Build a network with 50 source cells, 50 result cells, 50 propagators
  (define net0 (make-prop-network 10000000))
  (define-values (net-built sources results)
    (let loop ([net net0] [i 0] [srcs '()] [ress '()])
      (if (>= i 50)
          (values net (reverse srcs) (reverse ress))
          (let-values ([(net1 s) (net-new-registry-cell net)])
            (let-values ([(net2 r) (net-new-list-cell net1)])
              (let-values ([(net3 _pid)
                            (net-add-propagator net2 (list s) (list r)
                              (lambda (net)
                                (define v (net-cell-read net s))
                                (if (hash-empty? v) net
                                    (net-cell-write net r (list i)))))])
                (loop net3 (+ i 1) (cons s srcs) (cons r ress))))))))
  ;; Write to all sources
  (define net-written
    (for/fold ([net net-built])
              ([s (in-list sources)]
               [i (in-naturals)])
      (net-cell-write net s (hasheq (string->symbol (format "k~a" i)) i))))
  ;; Time sequential
  (define-values (seq-result seq-ms _seq-gc1 _seq-gc2)
    (time-apply (lambda () (run-to-quiescence net-written)) '()))
  ;; Time BSP
  (define-values (bsp-result bsp-ms _bsp-gc1 _bsp-gc2)
    (time-apply (lambda () (run-to-quiescence-bsp net-written)) '()))
  ;; Time parallel
  (define parallel-exec (make-parallel-fire-all 4))
  (define-values (par-result par-ms _par-gc1 _par-gc2)
    (time-apply (lambda () (run-to-quiescence-bsp net-written #:executor parallel-exec)) '()))
  ;; Print results for characterization
  (printf "  Benchmark (50 propagators, 100 cells):\n")
  (printf "    Sequential: ~a ms\n" seq-ms)
  (printf "    BSP:        ~a ms\n" bsp-ms)
  (printf "    Parallel:   ~a ms\n" par-ms)
  ;; Verify correctness: all results should have entries
  (for ([r (in-list results)])
    (check-true (pair? (net-cell-read (car seq-result) r)))))

;; ========================================
;; Order Independence
;; ========================================

(test-case "order independence: same result regardless of write order"
  (define-values (net0 src-cid result-cids) (make-independent-network 5))
  ;; Write 1 then write 2
  (define net-a
    (run-to-quiescence
     (net-cell-write
      (net-cell-write net0 src-cid (hasheq 'first 1))
      src-cid (hasheq 'second 2))))
  ;; Write 2 then write 1
  (define net-b
    (run-to-quiescence
     (net-cell-write
      (net-cell-write net0 src-cid (hasheq 'second 2))
      src-cid (hasheq 'first 1))))
  ;; Same final state
  (for ([rcid (in-list result-cids)])
    (check-equal? (net-cell-read net-a rcid)
                  (net-cell-read net-b rcid))))

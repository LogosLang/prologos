#lang racket/base

;;; eigentrust-propagators-fine-float.rkt — fine-grained per-peer
;;; FLOAT variant. Like `eigentrust-propagators-fine.rkt` but uses
;;; Racket flonums (flvector) instead of exact rationals.
;;;
;;; Topology: K·n propagators total. At iteration k, n independent
;;; per-peer propagators each compute one element of the new trust
;;; vector. WITHIN a BSP round, those n propagators are independent
;;; — the BSP scheduler can fire them in parallel via a pool /
;;; parallel-thread executor. This is the parallel-friendly variant.
;;;
;;; Cell layout: (K+1) × n trust cells, each holding a single
;;; flonum. m-cid (vector of flvectors), p-cid (flvector),
;;; alpha-cid (flonum) constants on top.

(require "../../propagator.rkt"
         "eigentrust-propagators-float.rkt"
         racket/flonum)

(provide
 build-eigentrust-network-fine-fl
 run-eigentrust-propagators-fine-fl)


;; ============================================================
;; Per-peer kernel (off-network; called from each peer-fire fn).
;;   t_{k,i} = (1 − α) · sum_j M[i,j] · t_prev[j]  +  α · p[i]
;; m-row : flvector (length n), p-i : flonum, alpha : flonum,
;; t-prev : flvector. Returns flonum.
;; ============================================================

(define (peer-step-kernel-fl m-row p-i alpha t-prev)
  (define n (flvector-length m-row))
  (define dot
    (for/fold ([acc 0.0]) ([j (in-range n)])
      (fl+ acc (fl* (flvector-ref m-row j)
                    (flvector-ref t-prev j)))))
  (fl+ (fl* (fl- 1.0 alpha) dot)
       (fl* alpha p-i)))


;; ============================================================
;; Network construction
;; ============================================================

(define (lww old new) new)

(define (build-eigentrust-network-fine-fl m p alpha k)
  (unless (col-stochastic-fl? m)
    (error 'build-eigentrust-network-fine-fl
           "M must be column-stochastic (within tolerance)"))
  (define n (flvector-length p))
  (define net0 (make-prop-network))
  (define-values (net1 m-cid)     (net-new-cell net0 m     lww))
  (define-values (net2 p-cid)     (net-new-cell net1 p     lww))
  (define-values (net3 alpha-cid) (net-new-cell net2 alpha lww))

  ;; Allocate (K+1) × n trust cells. Row 0 holds p[i] for each i;
  ;; rows 1..K hold 0.0 and are written by their step propagator.
  (define t-cids (make-vector (add1 k) #f))
  (define-values (net4 row0)
    (let alloc ([net net3] [i 0] [acc '()])
      (cond
        [(>= i n) (values net (list->vector (reverse acc)))]
        [else
         (define-values (net* cid)
           (net-new-cell net (flvector-ref p i) lww))
         (alloc net* (add1 i) (cons cid acc))])))
  (vector-set! t-cids 0 row0)

  (define-values (net5 _ignore)
    (let row-alloc ([net net4] [step 1])
      (cond
        [(> step k) (values net 'done)]
        [else
         (define-values (net* row)
           (let alloc ([net net] [i 0] [acc '()])
             (cond
               [(>= i n) (values net (list->vector (reverse acc)))]
               [else
                (define-values (net** cid) (net-new-cell net 0.0 lww))
                (alloc net** (add1 i) (cons cid acc))])))
         (vector-set! t-cids step row)
         (row-alloc net* (add1 step))])))

  ;; Install K · n peer-step propagators.
  (define-values (net-final last-row)
    (let step-loop ([net net5] [step 1])
      (cond
        [(> step k) (values net (vector-ref t-cids k))]
        [else
         (define prev-row (vector-ref t-cids (sub1 step)))
         (define next-row (vector-ref t-cids step))
         (define net*
           (let peer-loop ([net net] [i 0])
             (cond
               [(>= i n) net]
               [else
                ;; Capture i, prev-row, next-row by value via let binding.
                (define peer-idx i)
                (define prev-cids prev-row)
                (define next-cid (vector-ref next-row peer-idx))
                (define (fire net-param)
                  (define m-val (net-cell-read net-param m-cid))
                  (define p-val (net-cell-read net-param p-cid))
                  (define alpha-val (net-cell-read net-param alpha-cid))
                  ;; Build the previous trust vector by reading each
                  ;; per-peer cell (n cell reads).
                  (define t-prev (make-flvector n))
                  (for ([j (in-range n)])
                    (flvector-set! t-prev j
                      (net-cell-read net-param (vector-ref prev-cids j))))
                  (define m-row (vector-ref m-val peer-idx))
                  (define p-i (flvector-ref p-val peer-idx))
                  (define t-i (peer-step-kernel-fl m-row p-i alpha-val t-prev))
                  (net-cell-write net-param next-cid t-i))
                (define inputs
                  (cons m-cid
                    (cons p-cid
                      (cons alpha-cid
                        (for/list ([j (in-range n)])
                          (vector-ref prev-cids j))))))
                (define-values (net** _pid)
                  (net-add-propagator net inputs (list next-cid) fire))
                (peer-loop net** (add1 i))])))
         (step-loop net* (add1 step))])))

  (values net-final last-row))


;; Read result row into an flvector of length n.
(define (read-row net cids)
  (define n (vector-length cids))
  (define out (make-flvector n))
  (for ([i (in-range n)])
    (flvector-set! out i (net-cell-read net (vector-ref cids i))))
  out)

(define (run-eigentrust-propagators-fine-fl m p alpha k)
  (define-values (net last-row) (build-eigentrust-network-fine-fl m p alpha k))
  (define net* (run-to-quiescence-bsp net))
  (read-row net* last-row))


;; ============================================================
;; Smoke
;; ============================================================

(module+ main
  (define result (run-eigentrust-propagators-fine-fl
                  m-ring-4-fl p-seed-0-fl 0.3 4))
  (printf "ring-4 / α=0.3 / k=4 (fine-flonum):~n  ~s~n" result)
  (define expected (flvector 0.5401 0.21 0.147 0.1029))
  (define tol 1e-9)
  (define ok?
    (for/and ([i (in-range 4)])
      (< (abs (- (flvector-ref result i) (flvector-ref expected i))) tol)))
  (unless ok?
    (error 'main "result not within ~e of expected~n  expected: ~s~n  got: ~s"
           tol expected result))
  (printf "matches coarse-float W3 within ~e ✓~n" tol))

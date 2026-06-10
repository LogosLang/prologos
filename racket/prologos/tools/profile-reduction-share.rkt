#lang racket/base
;; PReduce §5.8 baseline instrument — reduction-share via sampling profiler.
;;
;; Usage: racket tools/profile-reduction-share.rkt OUT.txt BENCH.prologos
;;   (one benchmark per invocation — driver main is a module instantiated once per
;;    process; per-benchmark processes match bench-ab's subprocess isolation)
;;
;; Protocol (PReduce autonomy ledger, 2026-06-10): run the benchmark IN-PROCESS via
;; driver's main submodule under the sampling profiler (5ms samples; ZERO production
;; code changes); aggregate SELF time by source file; report (a) the per-file share
;; table, (b) the reduction.rkt + substitution.rkt self-shares (the "reduction share"
;; lower bound — self-time attribution avoids recursive total double-counting), and
;; (c) the full render-text profile for the record. Repeatable by construction.
(require profile/sampler profile/analyzer profile/render-text
         racket/list racket/string)

(define args (vector->list (current-command-line-arguments)))
(unless (= 2 (length args))
  (eprintf "usage: profile-reduction-share.rkt OUT.txt BENCH.prologos\n")
  (exit 1))
(define out-path (car args))
(define bench (cadr args))

(define (src-file n)
  (define s (node-src n))
  (and s (srcloc-source s)
       (let ([p (srcloc-source s)])
         (if (path? p) (path->string p) (format "~a" p)))))

(define prof #f)
(define sampler (create-sampler (current-thread) 0.005))
(parameterize ([current-command-line-arguments (vector bench)])
  (dynamic-require `(submod (file ,(path->string (build-path (current-directory) "driver.rkt"))) main) #f))
(sampler 'stop)
(set! prof (analyze-samples (sampler 'get-snapshots)))

(with-output-to-file out-path #:exists 'replace
  (lambda ()
    (printf "===== ~a =====\n" bench)
    (define total (profile-total-time prof))
    (printf "total sampled time: ~a ms\n\n" total)
    ;; per-file self-time aggregation
    (define by-file (make-hash))
    (for ([n (in-list (profile-nodes prof))])
      (define f (or (src-file n) "<unknown>"))
      (hash-update! by-file f (lambda (v) (+ v (node-self n))) 0))
    (printf "-- self-time share by source file (top 25) --\n")
    (for ([pr (in-list (take (sort (hash->list by-file) > #:key cdr)
                             (min 25 (hash-count by-file))))])
      (printf "~a ms\t~a%\t~a\n" (cdr pr)
              (if (zero? total) 0 (real->decimal-string (* 100.0 (/ (cdr pr) total)) 2))
              (car pr)))
    (define (share-of needle)
      (for/sum ([(f v) (in-hash by-file)]
                #:when (string-contains? f needle))
        v))
    (define red (share-of "reduction.rkt"))
    (define sub (share-of "substitution.rkt"))
    (printf "\nREDUCTION-SHARE (self): reduction.rkt = ~a ms (~a%); substitution.rkt = ~a ms (~a%); combined = ~a%\n"
            red (if (zero? total) 0 (real->decimal-string (* 100.0 (/ red total)) 2))
            sub (if (zero? total) 0 (real->decimal-string (* 100.0 (/ sub total)) 2))
            (if (zero? total) 0 (real->decimal-string (* 100.0 (/ (+ red sub) total)) 2)))
    (printf "\n-- full profile (render-text) --\n")
    (render prof)))

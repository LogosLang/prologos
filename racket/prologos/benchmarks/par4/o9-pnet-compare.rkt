#lang racket/base
;; PAR 4 O-9 evidence — compare two .pnet cache trees module by module (prelude elaboration under two
;; scheduler settings). Cold prelude elaboration is where today's wide BSP rounds are (DEFERRED 150:
;; rounds of 216–368 fires), so the caches it writes are the program-level result of those rounds.
;;
;;   racket benchmarks/par4/o9-pnet-compare.rkt DIR-A DIR-B
;;
;; DIR-A / DIR-B are copies of data/cache/pnet made after `tools/pnet-compile.rkt` ran under each
;; setting. For every A/…/*.pnet: read both with tools/pnet-dump.rkt's reader, compare the bodies in
;; pnet-canonical form (hashes as sorted entry lists), and on a difference name the differing slots.
;; Run it on two generations under the SAME setting first (the control): a difference there is
;; nondeterminism in generation (gensym numbering, …), not the setting.
(require racket/list racket/path "../../tools/pnet-dump.rkt" (only-in "../../pnet-serialize.rkt" PNET-BODY-SLOTS))

(define args (current-command-line-arguments))
(define dir-a (simplify-path (path->complete-path (vector-ref args 0))))
(define dir-b (simplify-path (path->complete-path (vector-ref args 1))))

(define files
  (sort (for/list ([f (in-directory dir-a)] #:when (regexp-match? #rx"[.]pnet$" (path->string f)))
          (find-relative-path dir-a f))
        string<? #:key path->string))

(define n-same 0)
(define n-diff 0)
(for ([rel (in-list files)])
  (define fb (build-path dir-b rel))
  (cond
    [(not (file-exists? fb)) (set! n-diff (add1 n-diff)) (printf "MISSING in B  ~a\n" rel)]
    [else
     (define a (pnet-file-body (read-pnet-file (build-path dir-a rel))))
     (define b (pnet-file-body (read-pnet-file fb)))
     (cond
       [(equal? (pnet-canonical a) (pnet-canonical b)) (set! n-same (add1 n-same))]
       [else
        (set! n-diff (add1 n-diff))
        (define slots
          (for/list ([x (in-list a)] [y (in-list b)] [i (in-naturals)]
                     #:unless (equal? (pnet-canonical x) (pnet-canonical y)))
            (if (< i (length PNET-BODY-SLOTS)) (list-ref PNET-BODY-SLOTS i) i)))
        (printf "DIFF  ~a  slots: ~a\n" rel slots)])]))
(printf "modules: ~a   identical: ~a   different: ~a\n" (length files) n-same n-diff)

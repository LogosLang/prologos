#!/usr/bin/env python3
"""W2-2: apply the env-gated variant switches to the SCRATCH copy only (never the repo).
Exact-once replacements; aborts on any count != 1."""
import sys, pathlib
T = pathlib.Path("/Users/avanti/.hermes/profiles/logos-language-designer/cache/scratch/d3w2/W2-2/tree/racket/prologos")
assert "scratch/d3w2/W2-2/tree" in str(T)

def rep(path, old, new):
    p = T / path
    s = p.read_text()
    n = s.count(old)
    if n != 1:
        sys.exit(f"{path}: expected 1 occurrence, found {n}: {old[:80]!r}")
    p.write_text(s.replace(old, new))
    print(f"ok {path}: {old[:60]!r}")

# ---------------------------------------------------------------- driver.rkt: W22_EXEC_OFF
rep("driver.rkt",
    "(current-parallel-executor (make-parallel-thread-fire-all))",
    ";; W2-2 scratch variant: W22_EXEC_OFF=1 -> do not install the thread executor (BSP falls back\n"
    ";; to sequential-fire-all, propagator.rkt run-to-quiescence-bsp's #:executor default).\n"
    "(unless (getenv \"W22_EXEC_OFF\") (current-parallel-executor (make-parallel-thread-fire-all)))")

# ---------------------------------------------------------------- propagator.rkt: provide
rep("propagator.rkt",
    " pu-value-diff\n filter-dependents-by-paths\n",
    " pu-value-diff\n filter-dependents-by-paths\n w22-register-keyed-merge!\n w22-keyed-diff\n w22-monitor-snapshot\n")

# ---------------------------------------------------------------- propagator.rkt: keyed diff + monitor
KEYED = r''';; ======================================================================
;; W2-2 (PAR 4 D.3 wave 2) scratch variant — NOT production code.
;; W22_KEYED_DIFF=1   : for a merge registered as KEY-PRESERVING (its result keeps every key of
;;                      `old` outside `new`'s keys eq? to before, and drops no key of `old`), the
;;                      slow-path diff examines only the written value's keys.
;; W22_KEYED_MONITOR=full|<n> : equivalence monitor; on every (or every n-th) eligible write
;;                      compute BOTH diffs, compare as multisets, count mismatches; the FULL diff
;;                      is returned to the scheduler (the run stays on the reference path).
;; W22_KEYED_POWER=1  : the keyed diff deliberately drops the first key of the written value
;;                      (power row: the monitor must catch it; with the monitor off it is returned).
;; W22_MONITOR_OUT=<file> : one JSON line per process, appended at exit.
(define w22-keyed-diff? (and (getenv "W22_KEYED_DIFF") #t))
(define w22-power? (and (getenv "W22_KEYED_POWER") #t))
(define w22-monitor-every
  (let ([m (getenv "W22_KEYED_MONITOR")])
    (cond [(not m) #f] [(equal? m "full") 1] [else (string->number m)])))
(define w22-keyed-merges (box '()))
(define (w22-register-keyed-merge! f) (set-box! w22-keyed-merges (cons f (unbox w22-keyed-merges))))
;; monitor counters (fxvector-free; boxes updated with box-cas! so the thread executor cannot lose counts)
(define (w22-inc! b [d 1]) (let loop () (define o (unbox b)) (unless (box-cas! b o (+ o d)) (loop))))
(define w22-n-slow (box 0))         ; slow-path diffs requested (component-path dependents)
(define w22-n-eligible (box 0))     ; ... of which on a registered key-preserving merge with hash values
(define w22-n-compared (box 0))     ; monitor comparisons made
(define w22-n-mismatch (box 0))     ; keyed != full (as multisets)
(define w22-n-delta-small (box 0))  ; eligible writes whose written value has fewer keys than the merged map
(define w22-n-delta-full (box 0))   ; eligible writes whose written value has as many keys (full-map writes, e.g. bulk)
(define w22-keys-full (box 0))      ; sum over eligible writes of keys the full diff walks (|merged| + |old|)
(define w22-keys-keyed (box 0))     ; sum over eligible writes of keys the keyed diff walks (|new|)
(define w22-keys-full-small (box 0)); same two sums restricted to small-delta writes
(define w22-keys-keyed-small (box 0))
(define w22-first-mismatch (box #f))
(define (w22-monitor-snapshot)
  (list (cons 'keyed_diff w22-keyed-diff?) (cons 'power w22-power?) (cons 'monitor_every w22-monitor-every)
        (cons 'slow_diffs (unbox w22-n-slow)) (cons 'eligible (unbox w22-n-eligible))
        (cons 'compared (unbox w22-n-compared)) (cons 'mismatches (unbox w22-n-mismatch))
        (cons 'delta_small (unbox w22-n-delta-small)) (cons 'delta_full (unbox w22-n-delta-full))
        (cons 'keys_full_diff (unbox w22-keys-full)) (cons 'keys_keyed_diff (unbox w22-keys-keyed))
        (cons 'keys_full_diff_small (unbox w22-keys-full-small)) (cons 'keys_keyed_diff_small (unbox w22-keys-keyed-small))
        (cons 'first_mismatch (let ([m (unbox w22-first-mismatch)]) (if m (format "~s" m) "none")))))
(define (w22-json-str v)
  (cond [(boolean? v) (if v "true" "false")] [(number? v) (number->string v)]
        [else (let ([o (open-output-string)]) (write (format "~a" v) o) (get-output-string o))]))
(when (and w22-monitor-every (getenv "W22_MONITOR_OUT"))
  (plumber-add-flush! (current-plumber)
    (lambda (_h)
      (with-output-to-file (getenv "W22_MONITOR_OUT") #:exists 'append
        (lambda ()
          (printf "{\"file\":~a,~a}\n" (w22-json-str (or (getenv "W22_FILE") "?"))
                  (apply string-append
                         (for/list ([p (in-list (w22-monitor-snapshot))] [i (in-naturals)])
                           (format "~a\"~a\":~a" (if (zero? i) "" ",") (car p) (w22-json-str (cdr p)))))))))))
;; keyed diff: pu-value-diff's per-key logic, restricted to `delta`'s keys. Exactly pu-value-diff
;; when merged keeps every key of old outside delta's keys eq? (so the full diff skips them by eq?)
;; and drops no key of old outside delta's keys (so the removed-key loop finds nothing there).
(define (w22-keyed-diff old-val new-val delta)
  (define changed '())
  (define skip-first? w22-power?)
  (for ([(k _d) (in-hash delta)])
    (if skip-first?
        (set! skip-first? #f)              ; POWER ROW: drop one key
        (let ([v (hash-ref new-val k 'pu-diff-absent)]
              [old-v (hash-ref old-val k 'pu-diff-absent)])
          (cond
            [(eq? v 'pu-diff-absent)       ; key removed by the merge
             (unless (eq? old-v 'pu-diff-absent) (set! changed (cons k changed)))]
            [(or (eq? v old-v) (equal? v old-v)) (void)]
            [(and (hash? v) (immutable? v) (hash? old-v) (immutable? old-v))
             (for ([(fk fv) (in-hash v)])
               (define old-fv (hash-ref old-v fk 'pu-diff-absent))
               (unless (or (eq? fv old-fv) (equal? fv old-fv))
                 (set! changed (cons (cons k fk) changed))))
             (for ([(fk _fv) (in-hash old-v)])
               (unless (hash-has-key? v fk)
                 (set! changed (cons (cons k fk) changed))))]
            [(and (hash? v) (immutable? v) (eq? old-v 'pu-diff-absent))
             (for ([(fk _fv) (in-hash v)])
               (set! changed (cons (cons k fk) changed)))]
            [else (set! changed (cons k changed))]))))
  changed)
(define (w22-multiset l)
  (define h (make-hash))
  (for ([x (in-list (or l '()))]) (hash-set! h x (add1 (hash-ref h x 0))))
  h)
(define w22-tick (box 0))
;; The slow-path diff entry point (replaces the direct pu-value-diff call in net-cell-write).
(define (w22-diff merge-fn old-val merged written)
  (cond
    [(not (or w22-keyed-diff? w22-monitor-every)) (pu-value-diff old-val merged)]
    [else
     (when w22-monitor-every (w22-inc! w22-n-slow))
     (cond
       [(and (memq merge-fn (unbox w22-keyed-merges))
             (hash? old-val) (immutable? old-val)
             (hash? merged) (immutable? merged)
             (hash? written))
        (cond
          [w22-monitor-every
           (w22-inc! w22-n-eligible)
           (define nw (hash-count written)) (define nm (hash-count merged))
           (define full-keys (+ nm (hash-count old-val)))
           (w22-inc! w22-keys-full full-keys) (w22-inc! w22-keys-keyed nw)
           (if (< nw nm)
               (begin (w22-inc! w22-n-delta-small) (w22-inc! w22-keys-full-small full-keys)
                      (w22-inc! w22-keys-keyed-small nw))
               (w22-inc! w22-n-delta-full))
           (define full (pu-value-diff old-val merged))
           (define t (let loop () (define o (unbox w22-tick)) (if (box-cas! w22-tick o (add1 o)) o (loop))))
           (when (zero? (modulo t w22-monitor-every))
             (w22-inc! w22-n-compared)
             (define keyed (w22-keyed-diff old-val merged written))
             (unless (equal? (w22-multiset full) (w22-multiset keyed))
               (w22-inc! w22-n-mismatch)
               (unless (unbox w22-first-mismatch)
                 (set-box! w22-first-mismatch
                           (list 'full full 'keyed keyed 'written-keys (hash-keys written)
                                 'old-count (hash-count old-val) 'merged-count nm)))))
           full]
          [else (w22-keyed-diff old-val merged written)])]
       [else (pu-value-diff old-val merged)])]))

;; PPN Track 4 Phase 1a: filter dependent prop-ids by component paths.
'''
rep("propagator.rkt",
    ";; PPN Track 4 Phase 1a: filter dependent prop-ids by component paths.\n",
    KEYED)

rep("propagator.rkt",
    "                         (let ([changed (if has-component-paths?\n"
    "                                            (pu-value-diff old-val merged)\n"
    "                                            #f)])",
    "                         (let ([changed (if has-component-paths?\n"
    "                                            (w22-diff merge-fn old-val merged actual-new-val)  ; W2-2 variant hook\n"
    "                                            #f)])")

# ---------------------------------------------------------------- typing-propagators.rkt: register
rep("typing-propagators.rkt",
    ";; --- that-read / that-write: the attribute record API ---\n",
    ";; W2-2 scratch variant: attribute-map-merge-fn folds over `new`'s keys starting from `old`, so every\n"
    ";; key of `old` outside `new`'s keys is kept eq? and none is dropped (the keyed-diff precondition).\n"
    "(w22-register-keyed-merge! attribute-map-merge-fn)\n\n"
    ";; --- that-read / that-write: the attribute record API ---\n")
print("done")

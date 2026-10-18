#!/usr/bin/env python3
"""W2-2: add the W22_DELTA_WRITES switch (delta-carried writes) to the SCRATCH copy. Exact-once replacements."""
import sys, pathlib
T = pathlib.Path("/Users/avanti/.hermes/profiles/logos-language-designer/cache/scratch/d3w2/W2-2/tree/racket/prologos")
assert "scratch/d3w2/W2-2/tree" in str(T)
def rep(path, old, new):
    p = T / path; s = p.read_text(); n = s.count(old)
    if n != 1: sys.exit(f"{path}: expected 1 occurrence, found {n}: {old[:80]!r}")
    p.write_text(s.replace(old, new)); print(f"ok {path}: {old[:60]!r}")

DW = r''';; ---------------------------------------------------------------- W2-2: delta-carried writes
;; W22_DELTA_WRITES=1 : during a BSP fire, every slow-path write to a cell whose merge is registered
;;   key-preserving records (initial-old, last-merged, joined delta). fire-and-collect-writes then
;;   carries the joined delta as the cell's value write instead of the fire's whole post-fire map,
;;   provided the chain is closed: initial-old eq? the snapshot's value and last-merged eq? the
;;   result's value (no unrecorded write touched the cell). Otherwise it falls back to the whole map.
;; With W22_KEYED_MONITOR set, bulk-merge-writes computes merge(canon, whole) AND merge(canon, delta),
;;   counts inequalities, and writes the WHOLE map (reference path). W22_DW_POWER=1 drops the first
;;   key of each carried delta (power row: the monitor must catch it).
(define w22-delta-writes? (and (getenv "W22_DELTA_WRITES") #t))
(define w22-dw-power? (and (getenv "W22_DW_POWER") #t))
(define w22-fire-deltas (make-parameter #f))
(struct w22-dual (full delta))
(define w22-dw-used (box 0)) (define w22-dw-fallback (box 0)) (define w22-dw-noentry (box 0))
(define w22-dw-compared (box 0)) (define w22-dw-mismatch (box 0)) (define w22-dw-first (box #f))
(define w22-dw-delta-keys (box 0)) (define w22-dw-full-keys (box 0))
(define (w22-record-delta! cid merge-fn old-val written merged)
  (define tbl (w22-fire-deltas))
  (when (and tbl (memq merge-fn (unbox w22-keyed-merges)) (hash? written) (hash? old-val))
    (define k (cell-id-n cid))
    (define e (hash-ref tbl k #f))
    (define last (if (eq? merged old-val) old-val merged))
    (cond
      [(not e) (hash-set! tbl k (vector old-val last written))]
      [(eq? (vector-ref e 1) old-val)
       (vector-set! e 1 last)
       (vector-set! e 2 (merge-fn (vector-ref e 2) written))]
      [else (vector-set! e 0 'w22-broken)])))      ; a write we did not see came in between
(define (w22-drop-first h) (let ([ks (hash-keys h)]) (if (null? ks) h (hash-remove h (car ks)))))
(define (w22-delta-or-full tbl cid old new)
  (define e (hash-ref tbl (cell-id-n cid) #f))
  (cond
    [(not e) (when w22-monitor-every (w22-inc! w22-dw-noentry)) new]
    [(and (eq? (vector-ref e 0) old) (eq? (vector-ref e 1) new))
     (define d (if w22-dw-power? (w22-drop-first (vector-ref e 2)) (vector-ref e 2)))
     (cond [w22-monitor-every
            (w22-inc! w22-dw-used) (w22-inc! w22-dw-delta-keys (hash-count d))
            (when (hash? new) (w22-inc! w22-dw-full-keys (hash-count new)))
            (w22-dual new d)]
           [else d])]
    [else (when w22-monitor-every (w22-inc! w22-dw-fallback)) new]))
(define (w22-bulk-monitor n cid dual)
  (define h (cell-id-hash cid))
  (define merge-fn (champ-lookup (prop-network-merge-fns n) h cid))
  (define canon (prop-cell-value (champ-lookup (prop-network-cells n) h cid)))
  (define m-full (merge-fn canon (w22-dual-full dual)))
  (define m-delta (merge-fn canon (w22-dual-delta dual)))
  (w22-inc! w22-dw-compared)
  (unless (equal? m-full m-delta)
    (w22-inc! w22-dw-mismatch)
    (unless (unbox w22-dw-first)
      (define paths (pu-value-diff m-delta m-full))
      (set-box! w22-dw-first
                (list 'paths (if (list? paths) (let loop ([p paths] [i 0]) (if (or (null? p) (= i 4)) '() (cons (car p) (loop (cdr p) (add1 i))))) paths)
                      'n-paths (if (list? paths) (length paths) paths)
                      'facet-values
                      (for/list ([p (in-list (if (list? paths) paths '()))] [i (in-range 2)] #:when (pair? p))
                        (list p 'full (format "~.a" (hash-ref (hash-ref m-full (car p) (hasheq)) (cdr p) 'absent))
                              'delta (format "~.a" (hash-ref (hash-ref m-delta (car p) (hasheq)) (cdr p) 'absent))))))))
  (net-cell-write n cid (w22-dual-full dual)))
(when (and w22-monitor-every (getenv "W22_MONITOR_OUT"))
  (void
   (plumber-add-flush! (current-plumber)
    (lambda (_h)
      (with-output-to-file (getenv "W22_MONITOR_OUT") #:exists 'append
        (lambda ()
          (printf "{\"kind\":\"dw\",\"file\":~a,\"delta_writes\":~a,\"dw_power\":~a,\"used\":~a,\"fallback_chain\":~a,\"no_entry\":~a,\"compared\":~a,\"mismatches\":~a,\"delta_keys\":~a,\"full_keys\":~a,\"first_mismatch\":~a}\n"
                  (w22-json-str (or (getenv "W22_FILE") "?")) (w22-json-str w22-delta-writes?) (w22-json-str w22-dw-power?)
                  (unbox w22-dw-used) (unbox w22-dw-fallback) (unbox w22-dw-noentry)
                  (unbox w22-dw-compared) (unbox w22-dw-mismatch) (unbox w22-dw-delta-keys) (unbox w22-dw-full-keys)
                  (w22-json-str (let ([m (unbox w22-dw-first)]) (if m (format "~s" m) "none"))))))))))

;; PPN Track 4 Phase 1a: filter dependent prop-ids by component paths.
'''
rep("propagator.rkt", ";; PPN Track 4 Phase 1a: filter dependent prop-ids by component paths.\n", DW)

rep("propagator.rkt",
    "  (define merged (merge-fn old-val actual-new-val))\n"
    "  (if (or (eq? merged old-val) (equal? merged old-val))\n"
    "      net  ;; No change — return same network (critical for termination)\n",
    "  (define merged (merge-fn old-val actual-new-val))\n"
    "  (when w22-delta-writes? (w22-record-delta! cid merge-fn old-val actual-new-val merged))  ; W2-2\n"
    "  (if (or (eq? merged old-val) (equal? merged old-val))\n"
    "      net  ;; No change — return same network (critical for termination)\n")

rep("propagator.rkt",
    "  (define result-net\n"
    "    (parameterize ([current-bsp-fire-round? #t]\n"
    "                   [current-cell-id-namespace namespace-idx])\n"
    "      (fire-propagator prop snapshot-net)))  ;; PPN 4C Phase 1.5\n",
    "  (define w22-tbl (and w22-delta-writes? (make-hasheqv)))   ; W2-2 delta-carried writes\n"
    "  (define result-net\n"
    "    (if w22-tbl\n"
    "        (parameterize ([current-bsp-fire-round? #t]\n"
    "                       [current-cell-id-namespace namespace-idx]\n"
    "                       [w22-fire-deltas w22-tbl])\n"
    "          (fire-propagator prop snapshot-net))\n"
    "        (parameterize ([current-bsp-fire-round? #t]\n"
    "                       [current-cell-id-namespace namespace-idx])\n"
    "          (fire-propagator prop snapshot-net))))  ;; PPN 4C Phase 1.5\n")

rep("propagator.rkt",
    "      (if (equal? old new)\n"
    "          writes\n"
    "          (cons (cons cid new) writes))))\n",
    "      (if (equal? old new)\n"
    "          writes\n"
    "          (cons (cons cid (if w22-tbl (w22-delta-or-full w22-tbl cid old new) new)) writes))))\n")

rep("propagator.rkt",
    "        (net-cell-write n (car w) (cdr w))))\n",
    "        (let ([v (cdr w)])                                   ; W2-2: monitor dual writes\n"
    "          (if (w22-dual? v) (w22-bulk-monitor n (car w) v) (net-cell-write n (car w) v)))))\n")
print("done")

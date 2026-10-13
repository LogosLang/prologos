#lang racket/base
;; update-deps.rkt — inspect and verify the DERIVED dependency graph (tools/dep-graph.rkt)
;;
;; Usage:
;;   racket tools/update-deps.rkt           # print the graph, derived from the files on disk
;;   racket tools/update-deps.rkt --check   # verify the cached derivation equals a full rescan
;;   racket tools/update-deps.rkt --write   # retired: there is nothing to write (see below)
;;
;; Since SW-24 (DEFERRED 169, 2026-10-13) dep-graph.rkt stores no dependency data:
;; every layer is computed from the files on disk when a tool first asks, through a
;; per-file content-keyed cache (data/cache/dep-graph.rktd). The graph cannot drift
;; from the code, so the old `--check` question ("does the stored data match the
;; requires?") no longer exists. What can still be wrong is the cache, so `--check`
;; now derives the graph twice — through the cache, and by scanning every file — and
;; exits 1 if any layer differs.

(require racket/cmdline
         racket/list
         "dep-graph.rkt")

(define layers
  (list (cons "source-deps" dep-graph-source-deps)
        (cons "test-deps" dep-graph-test-deps)
        (cons "prologos-lib-deps" dep-graph-prologos-lib-deps)
        (cons "test-prologos-deps" dep-graph-test-prologos-deps)))

(define (show v)
  (if (test-dep? v)
      (format "src:~a driver?:~a" (test-dep-source-modules v) (test-dep-uses-driver? v))
      (format "~a" v)))

;; compare-layer : string hash hash -> natural (number of differing keys, each printed)
(define (compare-layer label cached scanned)
  (define keys (remove-duplicates (append (hash-keys cached) (hash-keys scanned))))
  (for/sum ([k (in-list (sort keys symbol<?))])
    (define a (hash-ref cached k 'absent))
    (define b (hash-ref scanned k 'absent))
    (cond
      [(equal? a b) 0]
      [else
       (printf "  ~a ~a:\n    cached:  ~a\n    scanned: ~a\n"
               label k (if (eq? a 'absent) "absent" (show a)) (if (eq? b 'absent) "absent" (show b)))
       1])))

(define (run-check)
  (define rescanned 0)
  (define cached (derive-dep-graph #:on-scan (λ (_) (set! rescanned (add1 rescanned)))))
  (define scanned (derive-dep-graph #:cache-path #f))
  (printf "Derived graph (~a file(s) re-scanned through the cache at ~a):\n"
          rescanned (dep-graph-cache-path))
  (define total
    (for/sum ([l (in-list layers)])
      (define n (compare-layer (car l) ((cdr l) cached) ((cdr l) scanned)))
      (printf "  ~a ~a: ~a entries\n" (if (zero? n) "✓" "✗") (car l) (hash-count ((cdr l) scanned)))
      n))
  (cond
    [(zero? total) (printf "The cached derivation equals a full rescan. ✓\n")]
    [else (printf "~a entries differ between the cached derivation and a full rescan.\n" total)
          (exit 1)]))

(define (run-print)
  (define g (current-dep-graph))
  (for ([l (in-list layers)])
    (define h ((cdr l) g))
    (printf "=== ~a (~a) ===\n" (car l) (hash-count h))
    (for ([k (in-list (sort (hash-keys h) symbol<?))])
      (printf "  ~a → ~a\n" k (show (hash-ref h k))))
    (newline)))

(define mode (make-parameter 'print))

(command-line
 #:program "update-deps"
 #:once-any
 ["--check" "Verify the cached derivation equals a full rescan" (mode 'check)]
 ["--write" "Retired: the graph is derived, there is nothing to write" (mode 'write)])

(case (mode)
  [(check) (run-check)]
  [(write)
   (printf "Nothing to write: since SW-24 (DEFERRED 169) dep-graph.rkt stores no data; the graph is\n")
   (printf "derived from the files on disk on every run. `--check` verifies its cache.\n")]
  [else (run-print)])

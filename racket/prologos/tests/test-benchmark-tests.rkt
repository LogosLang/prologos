#lang racket/base

;;; test-benchmark-tests.rkt — the per-file tables of tools/benchmark-tests.rkt.
;;;
;;; DEFERRED 162 open (2), the eq?-keyed-table class: `detect-regressions-v2`
;;; and `flag-high-variance` kept per-file samples in `make-hasheq` tables keyed
;;; by file-name STRINGS. Every run record's "file" is a fresh string from
;;; read-json (and the current run's is built from a path), and no two of them
;;; are `eq?` — so each lookup missed: no file ever had a baseline, no file ever
;;; accumulated more than one sample, and both reports were silently empty.
;;; Each test looks a file up through a COPIED key, the shape that caught 162.

(require rackunit
         json
         "../tools/benchmark-tests.rkt")

;; A run record as read-all-runs returns it: through JSON, so every string is fresh.
(define (json-run results)
  (string->jsexpr
   (jsexpr->string
    (hasheq 'file_count (length results)
            'results (for/list ([r (in-list results)])
                       (hasheq 'file (car r) 'wall_ms (cdr r)))))))

(test-case "benchmark-tests/detect-regressions-v2: a file is compared with its OWN baseline (copied key)"
  (define prev (for/list ([ms (in-list '(1000 1100 900))]) (json-run `(("test-slow.rkt" . ,ms)))))
  ;; the current run, as run-benchmark builds it: the name comes from a path
  (define current
    (hasheq 'results (list (hasheq 'file (string-append "test-" "slow.rkt") 'wall_ms 5000))))
  (define regs (detect-regressions-v2 current (append prev (list (json-run '(("test-slow.rkt" . 5000))))) 10))
  (check-equal? (length regs) 1 "the 5x slowdown must be reported")
  (define r (car regs))
  (check-equal? (hash-ref r 'file) "test-slow.rkt")
  (check-equal? (hash-ref r 'baseline_n) 3 "all three previous runs must land in ONE key")
  (check-equal? (hash-ref r 'baseline_ms) 1000))

(test-case "benchmark-tests/flag-high-variance: one file's samples accumulate across runs (copied key)"
  (define runs (for/list ([ms (in-list '(100 1000 100 1000))]) (json-run `(("test-noisy.rkt" . ,ms)))))
  (define hv (flag-high-variance runs))
  (check-equal? (length hv) 1 "a file swinging 10x between runs must be flagged")
  (check-equal? (hash-ref (car hv) 'file) "test-noisy.rkt")
  (check-equal? (hash-ref (car hv) 'sample_count) 4))

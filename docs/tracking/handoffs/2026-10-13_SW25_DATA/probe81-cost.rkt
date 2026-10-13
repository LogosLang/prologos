#lang racket/base
;; DEFERRED 81: cost of prior-test-counts on the real timings.jsonl.
;; Run: racket probe81-cost.rkt <racket/prologos>
(require racket/file racket/list)
(define root (vector-ref (current-command-line-arguments) 0))
(define prior-test-counts (dynamic-require (build-path root "tools" "suite-plan.rkt") 'prior-test-counts))
(define lines (file->lines (let ([args (current-command-line-arguments)])
                              (if (> (vector-length args) 1) (vector-ref args 1)
                                  (build-path root "data" "benchmarks" "timings.jsonl")))))
(define all-tests (for/list ([p (directory-list (build-path root "tests"))]
                             #:when (regexp-match? #rx"^test-.*[.]rkt$" (path->string p)))
                    (path->string p)))
(define (time-it label wanted)
  (collect-garbage)
  (define t0 (current-process-milliseconds))
  (define r (for/last ([i 3]) (prior-test-counts lines wanted)))
  (printf "~a: ~a ms CPU per call, ~a of ~a found\n" label
          (quotient (- (current-process-milliseconds) t0) 3) (hash-count r) (length wanted)))
(printf "timings.jsonl: ~a lines, ~a MB\n" (length lines)
        (/ (round (* 10 (/ (for/sum ([l lines]) (string-length l)) 1e6))) 10))
(time-it "full suite (every test file)    " all-tests)
(time-it "targeted, one recorded file     " '("test-properties.rkt"))
(time-it "targeted, a never-recorded file " '("test-never-recorded-xyz.rkt"))

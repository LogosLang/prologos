#lang racket/base

;;; suite-plan.rkt — the test runner's SCHEDULING decisions, as pure functions.
;;;
;;; run-affected-tests.rkt owns processes, ports and progress output; this
;;; module owns the decisions those mechanics carry out, so each decision can
;;; be pinned by a unit test (tests/test-suite-plan.rkt) instead of being
;;; observable only as suite wall time.
;;;
;;; ⚠ WHY THIS MODULE EXISTS (2026-10-13). The runner's LPT ("longest first")
;;; ordering was inert for its whole life: the per-file medians were stored in
;;; a `for/hasheq` keyed by file-name STRINGS and looked up with a freshly built
;;; string, so `eq?` never matched — 0 of 489 lookups hit — every file sorted as
;;; +inf.0 and dispatch was alphabetical. The slowest file (test-path-selection,
;;; ~100 s) therefore started only after the a–o files had cycled through the
;;; workers. The comment that recorded "measured impact was NIL" was measuring a
;;; sort that never sorted. A decision that cannot be unit-tested can be
;;; silently inert; here it is tested.

(require json
         racket/list
         racket/port)

(provide historical-medians)

;; historical-medians : (listof string) #:runs N #:min-file-count M
;;                      -> (hash/c string? exact-nonnegative-integer?)  ; equal?-keyed
;;
;; `lines` are timings.jsonl records in FILE order (oldest first). Uses the N
;; most recent FULL-suite records (file_count >= M — targeted runs time a file
;; without contention and read low) and returns each file's median wall_ms.
;; Keys are the `file` strings exactly as recorded (base names).
;; The hash is `equal?`-keyed: callers look up with strings they build
;; themselves, which are never `eq?` to the ones read from JSON.
(define (historical-medians lines #:runs [n-runs 5] #:min-file-count [min-files 100])
  (define full-runs
    (let loop ([ls (reverse lines)] [got '()])
      (cond
        [(or (null? ls) (>= (length got) n-runs)) got]
        [else
         (define rec
           (with-handlers ([exn:fail? (lambda (e) #f)])
             (with-input-from-string (car ls) read-json)))
         (loop (cdr ls)
               (if (and (hash? rec) (>= (hash-ref rec 'file_count 0) min-files))
                   (cons rec got)
                   got))])))
  (define observed
    (for*/fold ([h (hash)])
               ([run (in-list full-runs)]
                [r (in-list (hash-ref run 'results '()))])
      (hash-update h (hash-ref r 'file "") (lambda (v) (cons (hash-ref r 'wall_ms 0) v)) '())))
  (for/hash ([(f ms-list) (in-hash observed)])
    (define sorted (sort ms-list <))
    (values f (list-ref sorted (quotient (length sorted) 2)))))

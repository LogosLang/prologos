#lang racket/base

;;; Run a .prologos file and print numbered results.
;;; Usage: racket tools/run-file.rkt FILE.prologos
;;;        racket tools/run-file.rkt --check FILE.prologos
;;;
;;; --check mode (CIU T6 F1 Pre-0, 2026-07-06): WS-level regression testing in
;;; .prologos files themselves. The file carries expectation markers keyed by
;;; the SAME result index this tool prints in run mode:
;;;   ;;N=> expected        exact match against result N (after trim)
;;;   ;;N=>~ fragment       substring match against result N
;;; Authoring loop: run without --check, copy the numbered outputs into
;;; markers, then --check verifies. Exit code 1 on any mismatch — suitable
;;; as a test-suite gate (see tests/ wrappers).

(require racket/cmdline
         racket/string
         racket/file
         (only-in "../driver.rkt" process-file)
         (only-in "../errors.rkt" prologos-error? prologos-error-message))

(define check-mode? (make-parameter #f))

(define files
  (command-line
   #:program "run-file"
   #:once-each
   [("--check") "Verify ;;N=> / ;;N=>~ expectation markers instead of printing"
                (check-mode? #t)]
   #:args files files))

;; result → display string (shared by both modes)
(define (result->string r)
  (cond
    [(prologos-error? r) (format "ERROR: ~a" (prologos-error-message r))]
    [(string? r) r]
    [else (format "~a" r)]))

;; Parse expectation markers from the source file.
;; Returns (listof (list index contains? expected-string)).
(define (parse-expectations f)
  (define rx #px"^\\s*;;(\\d+)=>(~?)\\s?(.*)$")
  (for/fold ([acc '()] #:result (reverse acc))
            ([line (in-list (file->lines f))])
    (define m (regexp-match rx line))
    (if m
        (cons (list (string->number (cadr m))
                    (string=? (caddr m) "~")
                    (string-trim (cadddr m)))
              acc)
        acc)))

(define (run-check f)
  (define expectations (parse-expectations f))
  (define results (map result->string (process-file f)))
  (define n-results (length results))
  (define failures
    (for/fold ([fails '()] #:result (reverse fails))
              ([e (in-list expectations)])
      (define idx (car e))
      (define contains? (cadr e))
      (define expected (caddr e))
      (cond
        [(>= idx n-results)
         (cons (format "  [~a] NO RESULT (file produced ~a results); expected~a: ~a"
                       idx n-results (if contains? " to contain" "") expected)
               fails)]
        [else
         (define actual (string-trim (list-ref results idx)))
         (define ok?
           (if contains?
               (string-contains? actual expected)
               (string=? actual expected)))
         (if ok?
             fails
             (cons (format "  [~a] MISMATCH\n      expected~a: ~a\n      actual:    ~a"
                           idx (if contains? " to contain" "") expected actual)
                   fails))])))
  (printf "~a: ~a expectations, ~a passed, ~a failed\n"
          f (length expectations)
          (- (length expectations) (length failures)) (length failures))
  (for ([msg (in-list failures)]) (displayln msg))
  (null? failures))

(define (run-print f)
  (define results (process-file f))
  (define error-count 0)
  (for ([r (in-list results)]
        [i (in-naturals)])
    (when (prologos-error? r) (set! error-count (+ error-count 1)))
    (printf "~a: ~a\n" i (result->string r)))
  (printf "\n--- ~a errors ---\n" error-count))

(if (check-mode?)
    (let ([all-ok? (for/and ([f (in-list files)]) (run-check f))])
      (exit (if all-ok? 0 1)))
    (for ([f (in-list files)]) (run-print f)))

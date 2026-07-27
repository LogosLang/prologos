#lang racket/base

;;;
;;; CIU Track 6 F1b.5 — WS-level acceptance gate (the validate face, D27-D29).
;;;
;;; Runs the F1b.5 validate acceptance file through process-file and verifies its
;;; markers (the test-f1-records-acceptance mechanism). SEPARATE clean-state
;;; file per the hang discipline (DEFERRED.md § union-type hang) — the F1b.3
;;; width-file precedent.
;;;

(require rackunit
         racket/file
         racket/string
         racket/runtime-path
         (only-in "../driver.rkt" process-file)
         (only-in "../errors.rkt" prologos-error? prologos-error-message))

(define-runtime-path acceptance-file
  "../examples/2026-07-17-ciu-t6-f1b5-validate.prologos")

(define (result->string r)
  (cond
    [(prologos-error? r) (format "ERROR: ~a" (prologos-error-message r))]
    [(string? r) r]
    [else (format "~a" r)]))

;; Parse (index contains? expected) from the ;;N=> / ;;N=>~ markers.
(define (parse-expectations f)
  (define rx #px"^\\s*;;(\\d+)=>(~?)\\s?(.*)$")
  (for/list ([line (in-list (file->lines f))]
             #:do [(define m (regexp-match rx line))]
             #:when m)
    (list (string->number (cadr m)) (string=? (caddr m) "~") (string-trim (cadddr m)))))

(define results (map result->string (process-file acceptance-file)))
(define n (length results))

(for ([e (in-list (parse-expectations acceptance-file))])
  (define idx (car e))
  (define contains? (cadr e))
  (define expected (caddr e))
  (test-case (format "acceptance [~a] ~a ~s" idx (if contains? "~" "=") expected)
    (check-true (< idx n) (format "no result at index ~a (produced ~a)" idx n))
    (when (< idx n)
      (define actual (string-trim (list-ref results idx)))
      (if contains?
          (check-true (string-contains? actual expected)
                      (format "[~a] expected to contain ~s, got ~s" idx expected actual))
          (check-equal? actual expected (format "[~a]" idx))))))

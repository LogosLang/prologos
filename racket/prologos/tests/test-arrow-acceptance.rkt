#lang racket/base

;;;
;;; ARROW T1 — WS-level acceptance gate (`->` inside identifiers).
;;;
;;; Runs the ARROW acceptance file through process-file and verifies its
;;; markers, using the same mechanism as test-f1-records-acceptance.
;;;
;;; WHY A WRAPPER AT ALL: an acceptance file with markers is only a gate if
;;; something runs it. `tools/run-file.rkt --check` is the authoring loop (a
;;; human types it); this wrapper is what makes the file fail the SUITE when it
;;; regresses. Without it the file is documentation, not a test — which is
;;; exactly the state the 2026-03-18 track7 acceptance file is in (no markers,
;;; no wrapper, >15 min to run, and it carried a stale BUG annotation for four
;;; months because nothing re-ran it).
;;;
;;; The companion tests/test-arrow-identifiers.rkt pins the TOKEN STREAM at
;;; Level 1. This file pins Level 3 — that it works for someone writing an
;;; actual .prologos file, signatures included.
;;;

(require rackunit
         racket/file
         racket/string
         racket/runtime-path
         (only-in "../driver.rkt" process-file)
         (only-in "../errors.rkt" prologos-error? prologos-error-message))

(define-runtime-path acceptance-file
  "../examples/2026-08-05-arrow-identifiers.prologos")

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
(define expectations (parse-expectations acceptance-file))

;; Guard against a vacuous pass: if the markers ever stop being found (a regex
;; drift, a renamed file), the loop below would assert nothing and go green.
(test-case "the acceptance file actually carries expectations"
  (check-true (>= (length expectations) 14)
              (format "expected >=14 markers, parsed ~a" (length expectations))))

(for ([e (in-list expectations)])
  (define idx (car e))
  (define contains? (cadr e))
  (define expected (caddr e))
  (test-case (format "arrow acceptance [~a] ~a ~s" idx (if contains? "~" "=") expected)
    (check-true (< idx n) (format "no result at index ~a (produced ~a)" idx n))
    (when (< idx n)
      (define actual (string-trim (list-ref results idx)))
      (if contains?
          (check-true (string-contains? actual expected)
                      (format "[~a] expected to contain ~s, got ~s" idx expected actual))
          (check-equal? actual expected (format "[~a]" idx))))))

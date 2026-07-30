#lang racket/base

;;;
;;; CIU Track 6 — Path Selection: WS-level acceptance gate (Level 3).
;;;
;;; Runs the Path Selection acceptance file through `process-file` and verifies
;;; BOTH that it produces zero errors AND that every `;;N=>` marker matches.
;;; Mirrors `test-rel-t1-acceptance.rkt` and the four instances before it
;;; (f1-records, f1b3-width, f1b4-seal, f1b5-validate).
;;;
;;; WHY THIS EXISTS (D4.P2, 2026-07-29 — found by the pre-commit adversarial
;;; verify). This file's SIBLINGS were all gated; this one was not. No test and
;;; no tool referenced `2026-07-26-ciu-t6-path-selection.prologos`, so its
;;; "N/N markers, 0 errors" was re-verified BY HAND at every phase from P0
;;; through P1b-iii — a discipline, not a gate.
;;;
;;; That was tolerable while phases only APPENDED. D4.P2 does not: it
;;; uncomments a command in the middle of §D, and because `run-file.rkt` keys
;;; `;;N=>` to RESULT INDEX, that shifts ~20 later markers. Hand-renumbering 20
;;; markers with no gate is exactly the situation that produced the Rel T1
;;; defect this file's sibling was written for — there, `;;29` claimed the
;;; disjunction rows and actually pointed at `fruit-color : _ defined.`, because
;;; appending a `defr` had shifted every later index.
;;;
;;; The renumbering WAS verified correct by hand and by `--check` when it
;;; landed. This file is what keeps it correct.
;;;

(require rackunit
         racket/file
         racket/list
         racket/string
         racket/runtime-path
         (only-in "../driver.rkt" process-file)
         (only-in "../errors.rkt" prologos-error? prologos-error-message))

(define-runtime-path acceptance-file
  "../examples/2026-07-26-ciu-t6-path-selection.prologos")

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

(define raw-results (process-file acceptance-file))
(define results (map result->string raw-results))
(define n (length results))

;; ── Gate 1: zero errors ─────────────────────────────────────────────────────
(test-case "Path Selection acceptance file: 0 errors"
  (define errs
    (for/list ([r (in-list raw-results)]
               [i (in-naturals)]
               #:when (prologos-error? r))
      (format "[~a] ~a" i (prologos-error-message r))))
  (check-equal? errs '()
                (format "acceptance file must run clean; got ~a error(s)" (length errs))))

;; ── Gate 2: markers exist and are in range ──────────────────────────────────
(define expectations (parse-expectations acceptance-file))

(test-case "Path Selection acceptance file: markers exist and are in range"
  ;; Guards the misnumbering class head-on. A marker pointing past the end is
  ;; the loudest symptom of an index shift; a collapsed marker count is the
  ;; quietest.
  (check-true (>= (length expectations) 35)
              (format "expected >=35 markers, found ~a — did a section lose its markers?"
                      (length expectations)))
  (for ([e (in-list expectations)])
    (check-true (< (car e) n)
                (format "marker ;;~a=> points past the last result (~a produced)"
                        (car e) n)))
  ;; No two markers may claim the same result index — the shape a partial
  ;; renumber produces (P2's own first attempt did exactly this: shifting §J's
  ;; markers collided with the renumbered tail until the ranges were separated).
  (define idxs (map car expectations))
  (check-equal? (length idxs) (length (remove-duplicates idxs))
                "two markers claim the same result index — a partial renumber"))

;; ── Gate 3: every marker matches ────────────────────────────────────────────
(for ([e (in-list expectations)])
  (define idx (car e))
  (define contains? (cadr e))
  (define expected (caddr e))
  (test-case (format "path-selection acceptance [~a] ~a ~s" idx (if contains? "~" "=") expected)
    (check-true (< idx n) (format "no result at index ~a (produced ~a)" idx n))
    (when (< idx n)
      (define actual (string-trim (list-ref results idx)))
      (if contains?
          (check-true (string-contains? actual expected)
                      (format "[~a] expected to contain ~s, got ~s" idx expected actual))
          (check-equal? actual expected (format "[~a]" idx))))))

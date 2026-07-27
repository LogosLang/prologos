#lang racket/base

;;;
;;; Rel Track 1 — WS-level acceptance gate (Level 3).
;;;
;;; Runs the Rel T1 acceptance file through `process-file` and verifies BOTH
;;; that it produces zero errors AND that every `;;N=>` marker matches. Uses
;;; the established test-f1-records-acceptance mechanism (4 prior instances:
;;; f1-records, f1b3-width, f1b4-seal, f1b5-validate).
;;;
;;; WHY THIS EXISTS (Rel T1 X.close, 2026-07-25). The track's PIR gap audit
;;; found the acceptance file was gated by NOTHING — no test referenced it, no
;;; golden existed, and `compare-golden-for-file` had zero callers in tests/.
;;; Its "0 errors" was verified by hand each phase: a discipline, not a gate.
;;; Two consequences were then found, both of which this file would have
;;; caught the day they landed:
;;;   1. ~13 of the markers were PROSE, so even a manual `--check` could not
;;;      pass them (the checker does exact match, or substring with `=>~`).
;;;   2. The POL.8/POL.9 markers were MISNUMBERED — off by one and by two
;;;      respectively — because appending a `defr` shifts every later result
;;;      index. `;;29` claimed the disjunction rows and actually pointed at
;;;      `fruit-color : _ defined.`
;;; Both are fixed; this test is what keeps them fixed.
;;;
;;; It also carries the POL cluster's ONLY Level-3 coverage. `test-rel-t1-pol.rkt`
;;; is Level-2 throughout (0 `process-file` calls vs 84 `run-ns-ws-last`), and
;;; testing.md mandates three-level WS validation for syntax features — which
;;; POL.7/.8/.9 are. Until those gain L3 cases of their own, a regression in
;;; the parenless-clause grammar or the paren-goal dispatch surfaces HERE.
;;;

(require rackunit
         racket/file
         racket/string
         racket/runtime-path
         (only-in "../driver.rkt" process-file)
         (only-in "../errors.rkt" prologos-error? prologos-error-message))

(define-runtime-path acceptance-file
  "../examples/2026-07-19-rel-t1-acceptance.prologos")

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
;; The property every phase of the track verified by hand. Named per-result so
;; a failure says WHICH command broke, not merely that the count moved.
(test-case "Rel T1 acceptance file: 0 errors"
  (define errs
    (for/list ([r (in-list raw-results)]
               [i (in-naturals)]
               #:when (prologos-error? r))
      (format "[~a] ~a" i (prologos-error-message r))))
  (check-equal? errs '()
                (format "acceptance file must run clean; got ~a error(s)" (length errs))))

;; ── Gate 2: every marker matches ────────────────────────────────────────────
(define expectations (parse-expectations acceptance-file))

(test-case "Rel T1 acceptance file: markers exist and are in range"
  ;; Guards the misnumbering class directly: appending a command shifts every
  ;; later index, and a marker pointing past the end is the loudest symptom.
  (check-true (>= (length expectations) 30)
              (format "expected >=30 markers, found ~a — did a section lose its markers?"
                      (length expectations)))
  (for ([e (in-list expectations)])
    (check-true (< (car e) n)
                (format "marker ;;~a=> points past the last result (~a produced)"
                        (car e) n))))

(for ([e (in-list expectations)])
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

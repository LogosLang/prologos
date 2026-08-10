#lang racket/base

;;; test-empty-group-toplevel.rkt — an empty group is located AT ITS BRACKET,
;;; and "located nowhere" must never be a merge key.
;;;
;;; A bare top-level `[]` used to return the WRONG command's result:
;;;
;;;     ns p
;;;     def a := 1
;;;     []
;;;     def b := 2
;;;     def c := 3
;;;   → "a : Int defined."  "c : Int defined."  "b : Int defined."  "c : Int defined."
;;;
;;; Four results for four commands, out of order, and `c` twice. Zero errors
;;; reported — silence, not noise.
;;;
;;; Three faults compounded, and each hid the others:
;;;
;;;   1. The reader located an empty group nowhere. `wrap-stx-list` had no
;;;      elements to take a range from and passed 0 for line and column;
;;;      `make-stx` maps 0 to #f; `stx-range` then propagated #f up to the
;;;      enclosing form. The opening bracket's token was right there in the
;;;      caller and unused.
;;;
;;;   2. `merge-preparse-and-tree-parser` keys the two parse spines against each
;;;      other BY SOURCE LINE, and treated line 0 as a line. 0 is the project's
;;;      unknown-location sentinel (`srcloc-unknown` is `(srcloc … 0 0 0)`), so
;;;      every located-nowhere surf on one spine matched every located-nowhere
;;;      surf on the other. The tree spine routinely carries one such surf.
;;;
;;;   3. The two parse spines DISAGREED about what an empty group means. The
;;;      tree spine has always said nil (`parse-bracket-group-tree`: "empty
;;;      brackets = nil") and `def x := []` is tested as the empty list; the
;;;      preparse spine said "Unexpected datum: ()". Fault 2 was papering over
;;;      fault 3 — the error surf got swapped for the tree surf by the very
;;;      collision that was corrupting everything else, so `def x := []` worked
;;;      BY ACCIDENT. Tightening the merge key exposed it immediately, which is
;;;      the useful thing about removing an accident.
;;;
;;; Each fault masks the others, so all three are pinned: the reader tests
;;; assert a real line, the merge tests assert one result per command in order,
;;; and the semantics tests assert both spines now agree that an empty group is
;;; nil wherever it appears.

(require rackunit
         racket/list
         racket/file
         "test-support.rkt"
         "../errors.rkt"
         "../driver.rkt"
         "../parse-reader.rkt")

;; ---------------------------------------------------------------------------
;; Reader level: the empty group carries the bracket's own position.
;; ---------------------------------------------------------------------------

(define (read-forms str)
  (register-default-token-patterns!)
  (read-all-forms-from-tree (read-to-tree str) str "test"))

(test-case "empty-group/a bare [] is located at its own line"
  (define forms (read-forms "ns p\ndef a := 1\n[]\ndef b := 2\n"))
  (check-equal? (length forms) 4)
  (define empty-form (third forms))
  (check-equal? (syntax->datum empty-form) '(()))
  (check-equal? (syntax-line empty-form) 3
                "the empty group must carry the line its bracket is on")
  (check-equal? (syntax-column empty-form) 0))

(test-case "empty-group/a bare () is located too"
  (define forms (read-forms "ns p\n()\n"))
  (check-equal? (syntax-line (second forms)) 2))

(test-case "empty-group/non-empty groups are unchanged"
  ;; The `#:at` fallback fires only when there is nothing to take a range from;
  ;; a populated group must still be located at its FIRST ELEMENT, not at the
  ;; bracket.
  (define forms (read-forms "ns p\n[foo bar]\n"))
  (define e (second forms))
  (check-equal? (syntax->datum e) '(foo bar))
  (check-equal? (syntax-line e) 2)
  (check-equal? (syntax-column e) 1 "first element's column, not the bracket's"))

;; ---------------------------------------------------------------------------
;; End to end: one result per command, in order, with the error where it belongs.
;; ---------------------------------------------------------------------------

(define (run-file str)
  (define tmp (make-temporary-file "prologos-empty-~a.prologos"))
  (call-with-output-file tmp #:exists 'truncate
    (lambda (out) (display str out)))
  (begin0 (process-file tmp) (delete-file tmp)))

(define (describe r)
  (if (prologos-error? r) 'error (format "~a" r)))

(define (nil-result? r)
  (and (not (prologos-error? r))
       (regexp-match? #rx"list::nil" (format "~a" r))))

(test-case "empty-group/[] alone evaluates to nil"
  ;; Not an error. `def x := []` was already the empty list, so a bare `[]`
  ;; being a hard error was the inconsistency, not the value.
  (define rs (run-file "ns eg1\n[]\n"))
  (check-equal? (length rs) 1)
  (check-true (nil-result? (first rs)) (format "got: ~v" (first rs))))

(test-case "empty-group/[] among other commands does not steal a result"
  ;; The whole defect in one assertion set: count, order, no duplicate, and the
  ;; error present. Asserting only that `a`, `b` and `c` appear would have
  ;; PASSED throughout the bug — they all did, one of them twice.
  (define rs (run-file "ns eg2\ndef a := 1\n[]\ndef b := 2\ndef c := 3\n"))
  (check-equal? (length rs) 4 (format "one result per command, got: ~v" (map describe rs)))
  (check-true (regexp-match? #rx"^a : " (format "~a" (first rs))))
  (check-true (nil-result? (second rs))
              (format "the [] must report its OWN result, got: ~v" (describe (second rs))))
  (check-true (regexp-match? #rx"^b : " (format "~a" (third rs))))
  (check-true (regexp-match? #rx"^c : " (format "~a" (fourth rs))))
  ;; and no result appears twice
  (define oks (map (lambda (r) (format "~a" r)) (filter (lambda (r) (not (prologos-error? r))) rs)))
  (check-equal? (length (remove-duplicates oks)) (length oks)
                (format "a result was reported twice: ~v" oks)))

(test-case "empty-group/a bare () behaves the same"
  (define rs (run-file "ns eg3\ndef a := 1\n()\ndef b := 2\n"))
  (check-equal? (length rs) 3)
  (check-true (nil-result? (second rs)) (format "got: ~v" (describe (second rs)))))

(test-case "empty-group/both spines agree an empty group is nil in a VALUE position"
  ;; `def x := []` passed before this work — by accident, via the collision the
  ;; other tests here are about. It is pinned as a real requirement now, in both
  ;; bracket and paren spellings, so the accident cannot come back as the reason
  ;; it works.
  (define rs (run-file "ns eg6\ndef x := []\ndef y := ()\nx\n"))
  (check-equal? (length rs) 3 (format "got: ~v" (map describe rs)))
  (check-false (ormap prologos-error? rs) (format "got: ~v" (map describe rs)))
  (check-true (regexp-match? #rx"List" (format "~a" (first rs))) (format "got: ~v" (first rs)))
  (check-true (regexp-match? #rx"List" (format "~a" (second rs))) (format "got: ~v" (second rs)))
  (check-true (nil-result? (third rs)) (format "got: ~v" (third rs))))

(test-case "empty-group/the control file is untouched"
  ;; The merge change tightened a key. This is the file the tightening must not
  ;; move.
  (define rs (run-file "ns eg4\ndef a := 1\ndef b := 2\ndef c := 3\n"))
  (check-equal? (length rs) 3)
  (check-false (ormap prologos-error? rs) (format "got: ~v" (map describe rs))))

(test-case "empty-group/an empty MAP is a value, not this error"
  ;; `{}` reaches a different path and is legal. Pinned so the fix cannot be
  ;; over-applied to every empty delimiter pair.
  (define rs (run-file "ns eg5\ndef a := 1\ndef e := {}\ndef b := 2\n"))
  (check-equal? (length rs) 3)
  (check-false (ormap prologos-error? rs) (format "got: ~v" (map describe rs))))

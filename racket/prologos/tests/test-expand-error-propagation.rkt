#lang racket/base

;;; test-expand-error-propagation.rkt — an error produced during expansion must
;;; arrive as an ERROR, not as a printed struct.
;;;
;;; `expand-expression` is a structural rebuild with ~30 arms. An error VALUE
;;; produced inside it was WRAPPED into the surrounding node and carried to the
;;; elaborator, which reported it as
;;;
;;;     Cannot elaborate: #(struct:prologos-error #(struct:srcloc …) …)
;;;
;;; — the struct, printed, with the real message buried inside it and the
;;; source location replaced by `<unknown>:0:0`. Two arms had been armed by hand
;;; (a `def` body, and `surf-lam`), which covers the common case; anything
;;; nested deeper leaked.
;;;
;;; Arming the other twenty-eight is the exhaustive-walker hazard: the next arm
;;; added inherits the bug silently. So propagation is by construction now —
;;; every recursive descent goes through `expand-child`, which escapes on an
;;; error child.
;;;
;;; The tests are graded by DEPTH on purpose. Depth 0 passed before the fix and
;;; still passes; depths 1 and 2 are what regressed, and a fix that only armed
;;; one more arm would pass depth 1 and fail depth 2.

(require rackunit
         racket/string
         "test-support.rkt"
         "../errors.rkt"
         "../source-location.rkt")

;; The error producer: an unreachable match arm. Any expansion-time error would
;; do; this one is reachable from ordinary source.
(define (unreachable-at-depth n)
  (define inner "(match v (n -> 1N) (zero -> 2N))")
  (define wrapped
    (for/fold ([e inner]) ([_ (in-range n)])
      (string-append "(suc " e ")")))
  (format "(ns t)\n(spec dd Nat -> Nat)\n(defn dd [v] ~a)" wrapped))

(define (check-clean-error r depth)
  (check-true (prologos-error? r) (format "depth ~a: expected an error, got ~v" depth r))
  (define msg (format "~a" (prologos-error-message r)))
  (check-true (string-contains? msg "unreachable match arm")
              (format "depth ~a: the real message did not survive: ~v" depth msg))
  (check-false (string-contains? msg "Cannot elaborate")
               (format "depth ~a: the error was wrapped and carried to the elaborator" depth))
  (check-false (string-contains? msg "struct:prologos-error")
               (format "depth ~a: a struct was printed at the user" depth)))

(test-case "expand/an expansion error at the top of a def body is reported"
  ;; The case that already worked — the hand-armed arm. Kept so a regression
  ;; here is distinguishable from a regression in the general mechanism.
  (check-clean-error (run-ns-last (unreachable-at-depth 0)) 0))

(test-case "expand/an expansion error ONE node deeper is reported"
  ;; The match is an application ARGUMENT, so the `surf-app` arm rebuilt around
  ;; the error. Before the fix this printed the struct.
  (check-clean-error (run-ns-last (unreachable-at-depth 1)) 1))

(test-case "expand/an expansion error TWO nodes deeper is reported"
  ;; The grading is the point: arming one more arm passes the case above and
  ;; fails this one.
  (check-clean-error (run-ns-last (unreachable-at-depth 2)) 2))

(test-case "expand/the source location survives the propagation"
  ;; Wrapping did not just print a struct — it replaced the srcloc with
  ;; <unknown>:0:0, so the user lost the line as well as the message.
  (define r (run-ns-last (unreachable-at-depth 2)))
  (check-true (prologos-error? r))
  (define loc (prologos-error-srcloc r))
  (check-true (srcloc? loc) (format "no srcloc: ~v" r))
  (check-equal? (srcloc-line loc) 3 (format "wrong line: ~v" loc)))

(test-case "expand/a well-formed program still expands"
  ;; The escape must not fire on success, and must not swallow ordinary results.
  ;; Same shape as the failing cases, at the same depth, with the arms in an
  ;; order that IS reachable -- so what differs between this and depth 2 is the
  ;; error alone.
  (define r (run-ns-last "(ns t)\n(spec ok Nat -> Nat)\n(defn ok [v] (suc (suc (match v (zero -> 1N) (n -> 2N)))))"))
  (check-false (prologos-error? r) (format "expected success, got ~v" r))
  (check-true (string-contains? (format "~a" r) "ok") (format "the def did not register: ~v" r))

  ;; And a plain expression through the same walk, to pin that ordinary values
  ;; still come back rather than being escaped past.
  (define r2 (run-ns-last "(ns t)\n(eval (suc (suc zero)))"))
  (check-false (prologos-error? r2) (format "expected success, got ~v" r2))
  (check-true (string-contains? (format "~a" r2) "2") (format "got ~v" r2)))

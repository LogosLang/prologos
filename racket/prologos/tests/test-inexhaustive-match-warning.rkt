#lang racket/base

;;; test-inexhaustive-match-warning.rkt — W3002.
;;;
;;; A match with no covering row compiles to a typed hole named `__match-fail`
;;; (macros.rkt, two sites), and a typed hole types at anything. So a partial
;;; function SILENTLY returned a hole at its declared return type:
;;;
;;;   spec p1 Nat -> Nat
;;;   defn p1
;;;     | zero -> 1N
;;;   [p1 5N]   =>  ??__match-fail : Nat      (0 errors, before W3002)
;;;
;;; A WARNING and not an error, deliberately: Prologos has typed holes as a
;;; first-class feature — a user-written `??foo` is accepted at 0 errors on
;;; purpose — so a partial function is not obviously illegal here the way it is
;;; in Agda or Idris. What is not defensible is silence about a hole the
;;; COMPILER inserted because a case was missed.
;;;
;;; DEFAULT-ON was decided by measurement, the same way W3001's was:
;;;   full prelude load .............. ZERO holes planted
;;;   F1-records acceptance file ..... zero
;;;   F1b5-validate acceptance file .. zero
;;;   OCapN acceptance file .......... ONE — a real bug, see below
;;; So the ordinary path is silent and the signal is precise. It does NOT fire
;;; on every constructor split, only where coverage genuinely fails.
;;;
;;; ⚠ It paid for itself immediately: the one hit was `step-cell` in
;;; `lib/prologos/ocapn/behavior.prologos`, which lost coverage when
;;; `syrup-bytes` was added to `SyrupValue` at Phase 19 and the match was never
;;; extended. `step-cell` on a bytes argument had been returning
;;; `??__match-fail` at zero errors ever since. Fixed in the same commit.

(require rackunit
         racket/list
         racket/string
         racket/file
         "test-support.rkt"
         "../driver.rkt"
         "../namespace.rkt")

(define (run-file-results src)
  (define tmp (make-temporary-file "prologos-w3002-~a.prologos"))
  (call-with-output-file tmp #:exists 'replace (lambda (o) (display src o)))
  (define rs (parameterize ([current-lib-paths (list prelude-lib-dir)]
                            [current-module-registry prelude-module-registry])
               (install-module-loader!)
               (process-file (path->string tmp))))
  (delete-file tmp)
  (map (lambda (r) (format "~a" r)) rs))

(define (warns? src)
  (ormap (lambda (r) (regexp-match? #rx"W3002" r)) (run-file-results src)))

(test-case "W3002/an incomplete match is reported"
  (define rs (run-file-results
              "ns w3002-a\n\nspec p1 Nat -> Nat\ndefn p1\n  | zero -> 1N\n"))
  (check-true (ormap (lambda (r) (regexp-match? #rx"W3002" r)) rs)
              (format "~v" rs))
  ;; the message must name the file:line, not just complain
  (check-true (ormap (lambda (r) (regexp-match? #rx"prologos-w3002.*:[0-9]+:[0-9]+" r)) rs)
              (format "the warning must locate the match: ~v" rs)))

(test-case "W3002/a COMPLETE match is silent"
  ;; The half that decides whether the warning is usable. If this ever starts
  ;; warning, W3002 has become noise and should be reverted rather than tuned.
  (check-false (warns? (string-append "ns w3002-b\n\n"
                                      "spec p2 Bool -> Nat\n"
                                      "defn p2\n  | true -> 1N\n  | false -> 0N\n"))
               "an exhaustive Bool match must not warn"))

(test-case "W3002/a `_` catch-all silences it"
  ;; The remedy the message recommends must actually work — a hint naming a fix
  ;; nobody has executed is worse than no hint.
  (check-false (warns? (string-append "ns w3002-c\n\n"
                                      "spec p3 Nat -> Nat\n"
                                      "defn p3\n  | zero -> 1N\n  | _ -> 2N\n"))
               "the suggested catch-all must silence the warning"))

(test-case "W3002/an ordinary prelude program is silent"
  ;; The measurement that justified default-on, as a regression lock: a full
  ;; prelude load plants zero `__match-fail` holes.
  (check-false (warns? "ns w3002-d\n\ndef q := 1\nq\n")))

(test-case "W3002/the OCapN behavior module is clean"
  ;; The bug W3002 found on its first run. `step-cell` was missing a
  ;; `syrup-bytes` arm and returned a typed hole for that input. If this
  ;; regresses — say another SyrupValue constructor is added without extending
  ;; the match — the warning fires here again.
  (check-false (warns? (string-append "ns w3002-e\n\n"
                                      "imports [prologos::ocapn::behavior :refer-all]\n\n"
                                      "def q := 1\nq\n"))
               "prologos::ocapn::behavior must have no incomplete matches"))

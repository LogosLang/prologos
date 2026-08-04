#lang racket/base

;;; test-proc-recursion-refusal.rkt — process recursion refuses out loud (2026-08-04)
;;;
;;; `(proc-rec Loop)` parsed correctly and then elaboration threw the label away
;;; and emitted `(proc-stop)`, under a comment calling that "a sentinel that
;;; typing-sessions can handle". It is not a sentinel. `proc-stop`'s typing arm
;;; (typing-sessions.rkt) REQUIRES every channel to be ended, and actively
;;; SOLVES any remaining session metas to `sess-end` — so a recursive process
;;; was typed as TERMINATING and the recursion vanished at zero errors.
;;;
;;; Session TYPES can recurse (`sess-mu` / `sess-svar`, sessions.rkt); the
;;; process side is the missing half and building it is S4 work.
;;;
;;; The existing coverage stopped exactly where the defect began: the one
;;; `proc-rec` test in test-process-parse-01.rkt asserts the PARSE — that the
;;; label survives into `surf-proc-rec` — and says nothing about what
;;; elaboration then does with it. That file is deliberately parse-only (no
;;; driver), which is why these live here instead.

(require rackunit
         "test-support.rkt"
         "../prelude.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../macros.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt")

(define (run-ns s)
  (with-fresh-meta-env
    (parameterize ([current-ns-context #f]
                   [current-module-registry prelude-module-registry]
                   [current-lib-paths (list prelude-lib-dir)]
                   [current-preparse-registry prelude-preparse-registry])
      (install-module-loader!)
      (process-string s))))

(define (run-ns-last s)
  (let ([rs (run-ns s)]) (and (pair? rs) (car (reverse rs)))))

(test-case "proc-rec REFUSES rather than silently becoming stop"
  (define r (run-ns-last
             (string-append "(ns procrecel)\n"
                            "(session S (! Int) end)\n"
                            "(defproc looper : S (proc-send self 1 (proc-rec Loop)))")))
  (check-true (prologos-error? r) (format "expected a refusal, got: ~v" r))
  (define m (prologos-error-message r))
  (check-true (regexp-match? #rx"process recursion is not implemented" m) m)
  ;; The message must say WHY `stop` is not an acceptable stand-in, or the next
  ;; person re-applies the same "harmless sentinel" reasoning that caused this.
  (check-true (regexp-match? #rx"TERMINATING" m) m)
  ;; …and must name the label, so the error points at the user's own text.
  (check-true (regexp-match? #rx"Loop" m) (format "the label is missing: ~a" m)))

(test-case "a genuinely terminating process still elaborates (the control)"
  ;; Without this, a refusal that fired on `proc-stop` too would pass above.
  (define r (run-ns-last
             (string-append "(ns procrecel2)\n"
                            "(session S (! Int) end)\n"
                            "(defproc stopper : S (proc-send self 1 (proc-stop)))")))
  (check-false (prologos-error? r)
               (format "a terminating process must still elaborate: ~v" r)))

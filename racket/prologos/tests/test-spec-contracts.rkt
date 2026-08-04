#lang racket/base

;;; test-spec-contracts.rkt — Spec System Phase 2: `:pre` / `:post` runtime
;;; contracts.
;;;
;;; The surface parsed and stored since the metadata work; nothing consumed it,
;;; so a spec could declare `:pre` and `[sd 6 0]` would sail through at zero
;;; errors. Declaring a contract and having it not run is worse than not
;;; offering the syntax.
;;;
;;; Surface per 2026-02-22_EXTENDED_SPEC_DESIGN.org §Phase 2, unchanged: `:pre`
;;; is a function of the ARGS, `:post` a function of the args plus the RETURN.
;;; They are APPLIED, not interpreted — nothing in the lowering knows what a
;;; predicate looks like.

(require rackunit
         racket/list
         racket/string
         racket/file
         "test-support.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         (only-in "../macros.rkt"
                  current-preparse-registry current-trait-registry
                  current-impl-registry current-param-impl-registry))

(define (run-src src)
  (define tmp (make-temporary-file "prologos-contracts-~a.prologos"))
  (call-with-output-file tmp #:exists 'replace
    (lambda (o) (display (string-append "ns contracttest\n\n" src) o)))
  (define rs (parameterize ([current-lib-paths (list prelude-lib-dir)]
                            [current-module-registry prelude-module-registry]
                            [current-preparse-registry prelude-preparse-registry]
                            [current-trait-registry prelude-trait-registry]
                            [current-impl-registry prelude-impl-registry]
                            [current-param-impl-registry prelude-param-impl-registry])
               (install-module-loader!)
               (process-file (path->string tmp))))
  (delete-file tmp)
  (map (lambda (r) (format "~a" r)) rs))

(test-case "contracts/:pre passes the good call and REJECTS the bad one"
  (define rs (run-src (string-append
                       "spec sd Int Int -> Int\n"
                       "  :pre [fn [x : Int] [fn [y : Int] [not [eq? y 0]]]]\n"
                       "defn sd [x y] [int* x y]\n"
                       "[sd 6 3]\n"
                       "[sd 6 0]\n")))
  (check-regexp-match #rx"^18 : Int" (second rs) (format "~v" rs))
  (check-regexp-match #rx":pre violated" (third rs)
                      (format "the violating call must be rejected: ~v" rs))
  ;; …and the message names WHICH spec and WHICH contract, since a bare "panic"
  ;; would leave the reader to find both.
  (check-regexp-match #rx"sd" (third rs)))

(test-case "contracts/:post rejects a bad RESULT"
  (define rs (run-src (string-append
                       "spec bp Int -> Int\n"
                       "  :post [fn [x : Int] [fn [r : Int] [int-lt r 0]]]\n"
                       "defn bp [x] [int* x 2]\n"
                       "[bp 3]\n")))
  (check-regexp-match #rx":post violated" (second rs) (format "~v" rs)))

(test-case "contracts/:post sees BOTH the args and the return"
  ;; The distinguishing case: a postcondition that relates them. `[int-lt x r]`
  ;; holds for a doubling of a positive x and fails for a negative one, so a
  ;; lowering that passed only the result could not tell these apart.
  (define rs (run-src (string-append
                       "spec pd Int -> Int\n"
                       "  :pre  [fn [x : Int] [int-lt 0 x]]\n"
                       "  :post [fn [x : Int] [fn [r : Int] [int-lt x r]]]\n"
                       "defn pd [x] [int* x 2]\n"
                       "[pd 3]\n"
                       "[pd -3]\n")))
  (check-regexp-match #rx"^6 : Int" (second rs) (format "~v" rs))
  (check-regexp-match #rx":pre violated" (third rs) (format "~v" rs)))

(test-case "contracts/a spec with NO contract is untouched"
  ;; The guard that matters most: this lowering sits on the path of every
  ;; spec'd defn in every program.
  (define rs (run-src (string-append
                       "spec plain Int -> Int\n"
                       "defn plain [x] [int* x 2]\n"
                       "[plain 3]\n")))
  (check-false (ormap (lambda (r) (regexp-match? #rx"violated" r)) rs))
  (check-regexp-match #rx"^6 : Int" (second rs) (format "~v" rs)))

(test-case "contracts/a MULTI-FORM body is left unwrapped, not mis-wrapped"
  ;; Stated non-goal. A multi-form body is a sequence, and folding one into
  ;; `boolrec`'s single `then` slot needs it re-associated — `expand-let`'s job,
  ;; not the wrapper's. So the contract does not fire here, and the function
  ;; still WORKS, which is the important half: declining to wrap must not
  ;; break the definition.
  (define rs (run-src (string-append
                       "spec ml Int -> Int\n"
                       "  :pre [fn [x : Int] [int-lt 0 x]]\n"
                       "defn ml [x]\n"
                       "  let d := [int* x 2]\n"
                       "    [int+ d 1]\n"
                       "[ml 3]\n")))
  (check-regexp-match #rx"^7 : Int" (second rs)
                      (format "the definition must still work: ~v" rs)))

#lang racket/base

;;; test-gen-trait.rkt — the `Gen` trait (Spec System Phase 2's gate).
;;;
;;; Property checking for `:properties` and trait `:laws` needs a way to
;;; produce values. The laws themselves are already stored fully structured —
;;; `(- :name "reflexive" (:forall ($brace-params x : A)) (:holds (eq? x x)))` —
;;; so generation was the only missing piece.
;;;
;;; ⚠ AND IT IS BLOCKED ON SOMETHING ALREADY FILED. `gen : Int -> A` puts the
;;; trait parameter in the RESULT position only, so `derivable-method?` cannot
;;; derive a bare wrapper (there is nothing to unify the type var against) and
;;; `[gen 5]` is Unbound — inside the defining module as well as outside. That
;;; is exactly DEFERRED § "Numerics N6d-i follow-ups" item 3, "output-position-
;;; only methods". Spec Phase 2's property checking therefore inherits item 3's
;;; blocker, which nothing had connected before.
;;;
;;; The instances are real and work through the dictionary method; only the
;;; bare-name ergonomics wait.

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

(define (run-gen src)
  (define tmp (make-temporary-file "prologos-gen-~a.prologos"))
  (call-with-output-file tmp #:exists 'replace
    (lambda (o) (display (string-append
                          "ns gentrait\n\n"
                          "imports [prologos::core::gen :refer-all]\n\n" src) o)))
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

(test-case "gen/the module loads and its instances dispatch"
  (define rs (run-gen "[Int--Gen--gen 5]\n[Bool--Gen--gen 4]\n"))
  (check-false (ormap (lambda (r) (regexp-match? #rx"rror" r)) rs) (format "~v" rs))
  (check-regexp-match #rx": Int"  (first rs)  (format "~a" (first rs)))
  (check-regexp-match #rx": Bool" (second rs) (format "~a" (second rs))))

(test-case "gen/is SEEDED, not random — the same seed gives the same value"
  ;; The property that makes a law failure reproducible from the seed alone.
  ;; Asserting equality of two calls is what rules out a hidden state.
  (define rs (run-gen "[Int--Gen--gen 7]\n[Int--Gen--gen 7]\n"))
  (check-equal? (first rs) (second rs)))

(test-case "gen/different seeds give different values"
  ;; The other half — a constant generator would satisfy the test above.
  (define rs (run-gen "[Int--Gen--gen 5]\n[Int--Gen--gen 250]\n"))
  (check-not-equal? (first rs) (second rs) (format "~v" rs)))

(test-case "gen/Int straddles zero, so sign-sensitive laws see both"
  ;; A generator that only ever produced non-negatives would silently never
  ;; falsify a law that fails on negatives.
  (define rs (run-gen (string-append
                       "[int-lt [Int--Gen--gen 5] 0]\n"
                       "[int-lt 0 [Int--Gen--gen 350]]\n")))
  (check-regexp-match #rx"^true" (first rs)  (format "no negatives: ~a" (first rs)))
  (check-regexp-match #rx"^true" (second rs) (format "no positives: ~a" (second rs))))

(test-case "gen/Bool alternates on CONSECUTIVE seeds"
  ;; A caller stepping the seed by one must get both values rather than a run
  ;; of one — otherwise a Bool law is only ever checked against `true`.
  (define rs (run-gen "[Bool--Gen--gen 4]\n[Bool--Gen--gen 5]\n"))
  (check-regexp-match #rx"^true"  (first rs)  (format "~a" (first rs)))
  (check-regexp-match #rx"^false" (second rs) (format "~a" (second rs))))

(test-case "gen/the BARE wrapper RESOLVES from the expected type"
  ;; This assertion is the one that flipped. It was written the same day as
  ;; `#rx"Unbound variable"` — "when N6d-i item 3 lands, THIS is what changes" —
  ;; and item 3's practical half landed within the hour, because building `Gen`
  ;; is what showed the blocker was `derivable-method?`'s domain-position rule
  ;; and not the resolution machinery the entry blamed.
  ;;
  ;; The expected type picks the instance: `Int` gives the Int generator,
  ;; `Bool` the Bool one, from the identical call shape.
  (define rs (run-gen "def a : Int := [gen 5]\ndef b : Bool := [gen 4]\na\nb\n"))
  (check-false (ormap (lambda (r) (regexp-match? #rx"Unbound variable" r)) rs)
               (format "~v" rs))
  (check-regexp-match #rx": Int"  (third rs)  (format "~a" (third rs)))
  (check-regexp-match #rx"^true"  (fourth rs) (format "~a" (fourth rs))))

(test-case "gen/a CONSTANT method still derives no wrapper"
  ;; The boundary the relaxed rule keeps. `zero : A` takes no arguments at all,
  ;; so there is no application for the checker to hang an expected type on —
  ;; that half of N6d-i item 3 is still open, and `def o : Int := one` is still
  ;; Unbound. Pinned so the two halves are not confused for each other.
  (define rs (run-gen "def o : Int := one\n"))
  (check-true (ormap (lambda (r) (regexp-match? #rx"Unbound variable" r)) rs)
              (format "~v" rs)))

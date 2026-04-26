#lang racket/base

;;;
;;; Tests for Foreign Escape Blocks
;;; Tests the `racket{ code } [captures] -> [exports]` expression syntax.
;;;

(require rackunit
         racket/list
         racket/path
         racket/string
         racket/match
         "test-support.rkt"
         "../macros.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../source-location.rkt"
         "../surface-syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../pretty-print.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../multi-dispatch.rkt"
         "../foreign.rkt")

;; ========================================
;; Helpers
;; ========================================

(define (run-ns s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-multi-defn-registry (current-multi-defn-registry)]
                 [current-spec-store (hasheq)])
    (install-module-loader!)
    (process-string s)))

(define (run-ns-last s)
  (last (run-ns s)))

(define (check-contains actual substr [msg #f])
  (check-true (string-contains? actual substr)
              (or msg (format "Expected ~s to contain ~s" actual substr))))

;; ========================================
;; Unit tests: combining pass
;; ========================================

(test-case "foreign-block/combine-basic"
  ;; racket ($brace-params (+ 1 2)) → ($foreign-block racket ((+ 1 2)) () ())
  (define input '(def x : Nat racket ($brace-params (+ 1 2))))
  (define result (combine-foreign-blocks input))
  ;; Should contain $foreign-block
  (check-true (ormap (lambda (e) (and (pair? e) (eq? (car e) '$foreign-block)))
                     result)
              "Should contain $foreign-block"))

(test-case "foreign-block/combine-with-captures"
  ;; racket ($brace-params (add1 x)) (x : Nat) → ($foreign-block racket ((add1 x)) ((x : Nat)) ())
  (define input '(def len : Nat racket ($brace-params (add1 x)) (x : Nat)))
  (define result (combine-foreign-blocks input))
  (define fb (findf (lambda (e) (and (pair? e) (eq? (car e) '$foreign-block))) result))
  (check-true (pair? fb) "Should contain $foreign-block")
  ;; Check captures are present
  (define captures (cadddr fb))
  (check-true (pair? captures) "Should have captures"))

(test-case "foreign-block/combine-with-captures-and-exports"
  ;; racket ($brace-params (add1 x)) (x : Nat) -> (y : Nat)
  (define input '(def y : Nat racket ($brace-params (add1 x)) (x : Nat) -> (y : Nat)))
  (define result (combine-foreign-blocks input))
  (define fb (findf (lambda (e) (and (pair? e) (eq? (car e) '$foreign-block))) result))
  (check-true (pair? fb) "Should contain $foreign-block")
  ;; Check exports are present
  (define exports (car (cddddr fb)))
  (check-true (pair? exports) "Should have exports"))

(test-case "foreign-block/combine-no-foreign"
  ;; Regular form without racket{} should be unchanged
  (define input '(def x : Nat (suc zero)))
  (define result (combine-foreign-blocks input))
  (check-equal? result input))

;; ========================================
;; Integration tests: full pipeline
;; ========================================
;; Canonical form: racket{...} (no space between identifier and brace)

(test-case "foreign-block/constant-no-captures"
  ;; racket{(+ 1 2)} with no captures — constant expression
  (check-contains
   (run-ns-last
    "(def x : Nat racket{(+ 1 2)})\n(eval x)")
   "3N : Nat"))

(test-case "foreign-block/single-capture"
  ;; racket{(add1 n)} [n : Nat] -> [result : Nat]
  (check-contains
   (run-ns-last
    "(def n : Nat (suc (suc (suc zero))))\n(def result : Nat racket{(add1 n)} (n : Nat) -> (result : Nat))\n(eval result)")
   "4N : Nat"))

(test-case "foreign-block/multiple-captures"
  ;; racket{(+ x y)} [x : Nat y : Nat] -> [result : Nat]
  (check-contains
   (run-ns-last
    "(def x : Nat (suc (suc zero)))\n(def y : Nat (suc (suc (suc zero))))\n(def result : Nat racket{(+ x y)} (x : Nat y : Nat) -> (result : Nat))\n(eval result)")
   "5N : Nat"))

(test-case "foreign-block/bool-return"
  ;; racket{(zero? n)} [n : Nat] -> [result : Bool]
  (check-contains
   (run-ns-last
    "(def n : Nat zero)\n(def result : Bool racket{(zero? n)} (n : Nat) -> (result : Bool))\n(eval result)")
   "true : Bool"))

(test-case "foreign-block/type-check"
  ;; Foreign block result type-checks
  (check-contains
   (run-ns-last
    "(def x : Nat racket{42})\n(check x : Nat)")
   "OK"))

(test-case "foreign-block/in-def-body"
  ;; Foreign block as the body of a def
  (check-contains
   (run-ns-last
    "(def five : Nat racket{(+ 2 3)})\n(eval five)")
   "5N : Nat"))

(test-case "foreign-block/compose-with-native"
  ;; Use foreign block result in further Prologos computation
  (check-contains
   (run-ns-last
    "(def three : Nat racket{3})\n(eval (suc three))")
   "4N : Nat"))

(test-case "foreign-block/string-ops"
  ;; Use Racket string operations via foreign block
  (check-contains
   (run-ns-last
    "(def len : Nat racket{(string-length \"hello\")})\n(eval len)")
   "5N : Nat"))

(test-case "foreign-block/space-backward-compat"
  ;; racket { ... } with space also works (backward compatibility)
  (check-contains
   (run-ns-last
    "(def x : Nat racket {99})\n(eval x)")
   "99N : Nat"))

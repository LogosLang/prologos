#lang racket/base

;;;
;;; Tests for higher-rank Pi types in spec/defn.
;;; Tests the {A B : Type} implicit binder syntax and <(S :0 Type) -> ...> higher-rank params.
;;;

(require rackunit
         racket/list
         racket/path
         racket/string
         racket/port
         racket/file
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
         "../reduction.rkt"
         (prefix-in tc: "../typing-core.rkt")
         "../namespace.rkt"
         "../trait-resolution.rkt"
         "../reader.rkt")

;; ========================================
;; Helpers
;; ========================================

;; Run sexp-mode Prologos code
(define (run s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-bundle-registry (current-bundle-registry)]
                 [current-spec-store (hasheq)])
    (install-module-loader!)
    (process-string s)))

(define (run-last s) (last (run s)))

;; Run WS-mode code via temp .prologos file
(define (run-ws s)
  (define tmp (make-temporary-file "prologos-test-~a.prologos"))
  (call-with-output-file tmp #:exists 'replace
    (lambda (out) (display s out)))
  (define result
    (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                   [current-ns-context #f]
                   [current-module-registry prelude-module-registry]
                   [current-lib-paths (list prelude-lib-dir)]
                   [current-mult-meta-store (make-hasheq)]
                   [current-preparse-registry prelude-preparse-registry]
                   [current-trait-registry prelude-trait-registry]
                   [current-impl-registry prelude-impl-registry]
                   [current-param-impl-registry prelude-param-impl-registry]
                   [current-bundle-registry (current-bundle-registry)]
                   [current-spec-store (hasheq)])
      (install-module-loader!)
      (process-file tmp)))
  (delete-file tmp)
  result)

(define (run-ws-last s) (last (run-ws s)))

(define (check-contains actual substr [msg #f])
  (check-true (string-contains? actual substr)
              (or msg (format "Expected ~s to contain ~s" actual substr))))

;; ========================================
;; A. Spec with {A} implicit binders — basic (sexp mode)
;; ========================================

(test-case "higher-rank: spec {A : Type} with simple identity"
  ;; spec id {A : Type} A -> A
  ;; defn id [x] x
  (define result
    (run (string-append
          "(spec id ($brace-params A : Type) A -> A)\n"
          "(defn id [x] x)\n"
          "(eval (id Nat zero))")))
  (check-equal? (last result) "0N : Nat"))

(test-case "higher-rank: spec {A} bare implicit (default kind)"
  ;; spec id {A} A -> A  — bare {A} means {A : Type}
  (define result
    (run (string-append
          "(spec id ($brace-params A) A -> A)\n"
          "(defn id [x] x)\n"
          "(eval (id Nat (suc zero)))")))
  (check-equal? (last result) "1N : Nat"))

(test-case "higher-rank: spec {A B : Type} multi-name group"
  ;; spec const {A B : Type} A -> B -> A
  (define result
    (run (string-append
          "(spec const ($brace-params A B : Type) A -> B -> A)\n"
          "(defn const [x y] x)\n"
          "(eval (const Nat Bool (suc zero) true))")))
  (check-equal? (last result) "1N : Nat"))

(test-case "higher-rank: spec {A} {B} multiple brace groups"
  ;; spec const {A} {B} A -> B -> A
  (define result
    (run (string-append
          "(spec const ($brace-params A) ($brace-params B) A -> B -> A)\n"
          "(defn const [x y] x)\n"
          "(eval (const Nat Bool (suc zero) true))")))
  (check-equal? (last result) "1N : Nat"))

;; ========================================
;; B. Implicit binders with body usage
;; ========================================

(test-case "higher-rank: implicit binder accessible in defn body"
  ;; The implicit A should be in scope — test with Sigma pair
  (define result
    (run (string-append
          "(spec wrap ($brace-params A : Type) A -> (Sigma (_ : A) A))\n"
          "(defn wrap [x] (pair x x))\n"
          "(eval (wrap Nat (suc zero)))")))
  (check-contains (last result) "1"))

;; ========================================
;; C. Higher-rank Pi parameter via <...> (angle-type)
;; ========================================

(test-case "higher-rank: angle-Pi as parameter type"
  ;; A function that takes a polymorphic function and applies it
  ;; The Pi-typed parameter is passed as ($angle-type ...) already in the spec
  (define result
    (run (string-append
          "(spec apply-poly ($angle-type (A :0 Type) -> A -> A) -> Nat -> Nat)\n"
          "(defn apply-poly [f n] (f Nat n))\n"
          "(eval (apply-poly (fn (A :0 (Type 0)) (fn (x : A) x)) (suc zero)))")))
  (check-equal? (last result) "1N : Nat"))

;; ========================================
;; D. WS mode integration
;; ========================================

(test-case "higher-rank: WS mode — spec with {A : Type} and defn"
  (define result
    (run-ws (string-join
             (list "ns test.hr1"
                   ""
                   "spec id {A : Type} A -> A"
                   "defn id [x] x"
                   ""
                   "eval [id Nat zero]")
             "\n")))
  (check-equal? (last result) "0N : Nat"))

(test-case "higher-rank: WS mode — spec with {A B : Type} bare implicits"
  (define result
    (run-ws (string-join
             (list "ns test.hr2"
                   ""
                   "spec const {A B : Type} A -> B -> A"
                   "defn const [x y] x"
                   ""
                   "eval [const Nat Bool [suc zero] true]")
             "\n")))
  (check-equal? (last result) "1N : Nat"))

(test-case "higher-rank: WS mode — spec with angle-Pi param type-checks"
  ;; Validate that spec with <(A :0 Type) -> ...> compiles and defines correctly
  (define result
    (run-ws (string-join
             (list "ns test.hr3"
                   ""
                   "spec apply-poly <(A :0 Type) -> A -> A> -> Nat -> Nat"
                   "defn apply-poly [f n] [f Nat n]")
             "\n")))
  ;; Should define successfully (produces "apply-poly : ... defined.")
  (check-contains (last result) "defined"))

(test-case "higher-rank: WS mode — implicit binder used in body"
  (define result
    (run-ws (string-join
             (list "ns test.hr4"
                   ""
                   "require [prologos::data::list :refer [List nil cons]]"
                   ""
                   "spec list-conj {A : Type} [List A] -> A -> [List A]"
                   "defn list-conj [acc x]"
                   "  cons A x acc"
                   ""
                   "eval [list-conj Nat [nil Nat] [suc zero]]")
             "\n")))
  (check-contains (last result) "1"))

;; ========================================
;; E. process-spec implicit binder extraction (unit tests)
;; ========================================

(test-case "higher-rank: process-spec extracts {A} implicit binders"
  (parameterize ([current-spec-store (hasheq)])
    (process-spec '(spec foo ($brace-params A) Nat -> Nat))
    (define entry (lookup-spec 'foo))
    (check-true (spec-entry? entry))
    ;; implicit-binders should be ((A . (Type 0)))
    (check-equal? (spec-entry-implicit-binders entry) '((A . (Type 0))))
    ;; type-datums should NOT contain the brace group
    (check-equal? (spec-entry-type-datums entry) '((Nat -> Nat)))))

(test-case "higher-rank: process-spec extracts {A B : Type}"
  (parameterize ([current-spec-store (hasheq)])
    (process-spec '(spec bar ($brace-params A B : Type) Nat -> Nat))
    (define entry (lookup-spec 'bar))
    (check-equal? (spec-entry-implicit-binders entry) '((A . (Type 0)) (B . (Type 0))))))

(test-case "higher-rank: process-spec with no implicits has empty list"
  (parameterize ([current-spec-store (hasheq)])
    (process-spec '(spec baz Nat -> Nat))
    (define entry (lookup-spec 'baz))
    (check-equal? (spec-entry-implicit-binders entry) '())))

(test-case "higher-rank: process-spec with multiple brace groups"
  (parameterize ([current-spec-store (hasheq)])
    (process-spec '(spec qux ($brace-params A) ($brace-params B) Nat -> Nat))
    (define entry (lookup-spec 'qux))
    (check-equal? (spec-entry-implicit-binders entry) '((A . (Type 0)) (B . (Type 0))))))

;; ========================================
;; F. param-type->angle-type passthrough (unit tests)
;; ========================================

(test-case "higher-rank: param-type->angle-type passes through $angle-type"
  ;; An ($angle-type ...) form should pass through unchanged
  (define result (param-type->angle-type '($angle-type (S :0 Type) -> S -> Nat -> S)))
  (check-equal? result '($angle-type (S :0 Type) -> S -> Nat -> S)))

(test-case "higher-rank: param-type->angle-type wraps plain atom"
  (check-equal? (param-type->angle-type 'Nat) '($angle-type Nat)))

(test-case "higher-rank: param-type->angle-type wraps grouped type"
  (check-equal? (param-type->angle-type '(List A)) '($angle-type (List A))))

;; ========================================
;; G. Backward compatibility
;; ========================================

(test-case "higher-rank: existing spec/defn without implicits still works"
  (define result
    (run (string-append
          "(spec add Nat Nat -> Nat)\n"
          "(defn add [x y] (match x (zero -> y) (suc k -> (suc (add k y)))))\n"
          "(eval (add (suc zero) (suc zero)))")))
  (check-equal? (last result) "2N : Nat"))

(test-case "higher-rank: existing WS spec/defn without implicits"
  (define result
    (run-ws (string-join
             (list "ns test.compat"
                   ""
                   "spec double Nat -> Nat"
                   "defn double [x]"
                   "  match x"
                   "    zero -> zero"
                   "    suc k -> suc [suc [double k]]"
                   ""
                   "eval [double [suc [suc zero]]]")
             "\n")))
  (check-equal? (last result) "4N : Nat"))

#lang racket/base

;;;
;;; Tests for MapEntry data type.
;;; Verifies construction, accessors, type inference, and eval reduction.
;;;

(require rackunit
         racket/list
         racket/string
         "test-support.rkt"
         "../macros.rkt"
         "../syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../multi-dispatch.rkt")

;; ========================================
;; Helpers
;; ========================================

(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-multi-defn-registry (current-multi-defn-registry)]
                 [current-spec-store (hasheq)])
    (install-module-loader!)
    (process-string s)))

(define (run-last s)
  (last (run-ns s)))

(define (check-contains actual substr [msg #f])
  (check-true (and (string? actual) (string-contains? actual substr))
              (or msg (format "Expected ~s to contain ~s" actual substr))))

(define preamble
  (string-append
    "(ns map-entry-test)\n"
    "(imports (prologos::data::map-entry :refer (MapEntry mk-entry entry-key entry-val)))\n"))


;; ========================================
;; Type formation
;; ========================================

(test-case "map-entry/type-formation"
  ;; (MapEntry Nat Bool) should be a Type
  (check-contains
    (run-last (string-append preamble "(infer (MapEntry Nat Bool))"))
    "Type"))


;; ========================================
;; Constructor type-check
;; ========================================

(test-case "map-entry/mk-entry-check-nat-bool"
  (check-equal?
    (run-last (string-append preamble
      "(check (mk-entry Nat Bool zero true) : (MapEntry Nat Bool))"))
    "OK"))

(test-case "map-entry/mk-entry-check-nat-nat"
  (check-equal?
    (run-last (string-append preamble
      "(check (mk-entry Nat Nat zero (suc zero)) : (MapEntry Nat Nat))"))
    "OK"))


;; ========================================
;; Constructor type inference
;; ========================================

(test-case "map-entry/mk-entry-infer"
  (define result
    (run-last (string-append preamble
      "(infer (mk-entry Nat Bool zero true))")))
  (check-contains result "MapEntry")
  (check-contains result "Nat")
  (check-contains result "Bool"))


;; ========================================
;; Accessor type-check
;; ========================================

(test-case "map-entry/entry-key-check"
  (check-equal?
    (run-last (string-append preamble
      "(check (entry-key (mk-entry Nat Bool zero true)) : Nat)"))
    "OK"))

(test-case "map-entry/entry-val-check"
  (check-equal?
    (run-last (string-append preamble
      "(check (entry-val (mk-entry Nat Bool zero true)) : Bool)"))
    "OK"))


;; ========================================
;; Accessor eval (pattern matching on constructor should reduce)
;; ========================================

(test-case "map-entry/entry-key-eval"
  (check-equal?
    (run-last (string-append preamble
      "(eval (entry-key (mk-entry Nat Bool zero true)))"))
    "0N : Nat"))

(test-case "map-entry/entry-val-eval"
  (check-equal?
    (run-last (string-append preamble
      "(eval (entry-val (mk-entry Nat Bool zero false)))"))
    "false : Bool"))

(test-case "map-entry/entry-key-eval-suc"
  (check-equal?
    (run-last (string-append preamble
      "(eval (entry-key (mk-entry Nat Nat (suc zero) zero)))"))
    "1N : Nat"))

(test-case "map-entry/entry-val-eval-suc"
  (check-equal?
    (run-last (string-append preamble
      "(eval (entry-val (mk-entry Nat Nat zero (suc (suc zero)))))"))
    "2N : Nat"))

#lang racket/base

;;;
;;; Tests for Phase 2: Hashable Trait and Hash Utilities
;;; Tests hashable-trait.prologos (trait + hash-combine) and
;;; hashable-instances.prologos (Nat/Bool/Ordering impls + hash-option/hash-list)
;;;

(require rackunit
         racket/list
         racket/path
         racket/string
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
                 [current-multi-defn-registry (current-multi-defn-registry)]
                 [current-spec-store (hasheq)])
    (install-module-loader!)
    (process-string s)))

(define (run-ns-last s)
  (last (run-ns s)))

(define preamble
  "(ns test)
(require (prologos::core::hashable-trait :refer (Hashable Hashable-hash hash-combine nat31)))
(require (prologos::core::hashable-instances :refer (hash-option hash-list)))
(require (prologos::data::option :refer (Option some none)))
(require (prologos::data::list :refer (List nil cons)))
(require (prologos::data::ordering :refer (Ordering lt-ord eq-ord gt-ord)))
")

(define (check-contains actual substr [msg #f])
  (check-true (string-contains? actual substr)
              (or msg (format "Expected ~s to contain ~s" actual substr))))

;; ========================================
;; Nat hash
;; ========================================

(test-case "hashable/nat-hash-zero"
  (check-contains
   (run-ns-last (string-append preamble "(eval (Nat--Hashable--hash zero))"))
   "0N : Nat"))

(test-case "hashable/nat-hash-3"
  (check-contains
   (run-ns-last (string-append preamble "(eval (Nat--Hashable--hash (suc (suc (suc zero)))))"))
   "3N : Nat"))

(test-case "hashable/nat-dict-type"
  ;; Nat--Hashable--dict should have type (Hashable Nat) = Nat -> Nat
  (define result (run-ns-last (string-append preamble "(infer Nat--Hashable--dict)")))
  (check-contains result "Nat")
  (check-contains result "->"))

;; ========================================
;; Bool hash
;; ========================================

(test-case "hashable/bool-hash-true"
  (check-contains
   (run-ns-last (string-append preamble "(eval (Bool--Hashable--hash true))"))
   "1N : Nat"))

(test-case "hashable/bool-hash-false"
  (check-contains
   (run-ns-last (string-append preamble "(eval (Bool--Hashable--hash false))"))
   "0N : Nat"))

;; ========================================
;; Ordering hash
;; ========================================

(test-case "hashable/ordering-hash-lt"
  (check-contains
   (run-ns-last (string-append preamble "(eval (Ordering--Hashable--hash lt-ord))"))
   "0N : Nat"))

(test-case "hashable/ordering-hash-eq"
  (check-contains
   (run-ns-last (string-append preamble "(eval (Ordering--Hashable--hash eq-ord))"))
   "1N : Nat"))

(test-case "hashable/ordering-hash-gt"
  (check-contains
   (run-ns-last (string-append preamble "(eval (Ordering--Hashable--hash gt-ord))"))
   "2N : Nat"))

;; ========================================
;; hash-combine
;; ========================================

(test-case "hashable/combine-0-0"
  ;; hash-combine 0 0 = 0*31 + 0 = 0
  (check-contains
   (run-ns-last (string-append preamble "(eval (hash-combine zero zero))"))
   "0N : Nat"))

(test-case "hashable/combine-1-2"
  ;; hash-combine 1 2 = 1*31 + 2 = 33
  (check-contains
   (run-ns-last (string-append preamble "(eval (hash-combine (suc zero) (suc (suc zero))))"))
   "33N : Nat"))

(test-case "hashable/nat31-value"
  ;; nat31 should equal 31
  (check-contains
   (run-ns-last (string-append preamble "(eval nat31)"))
   "31N : Nat"))

;; ========================================
;; hash-option
;; ========================================


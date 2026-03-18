#lang racket/base

;;;
;;; Tests for Phase 3e: Identity Traits + Generic Numeric Functions
;;; Tests: additive-identity-trait, multiplicative-identity-trait,
;;;        identity-instances, generic-numeric-ops (sum, product, int-range)
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
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
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

(define (check-contains actual substr [msg #f])
  (check-true (string-contains? actual substr)
              (or msg (format "Expected ~s to contain ~s" actual substr))))

;; ========================================
;; Preamble — loads identity traits + generic numeric ops
;; ========================================

(define preamble
  "(ns test)
(imports (prologos::core::algebra :refer (AdditiveIdentity AdditiveIdentity-zero
                                          MultiplicativeIdentity MultiplicativeIdentity-one
                                          sum product int-range)))
(imports (prologos::core::arithmetic                     :refer (Add Add-add Mul Mul-mul)))
(imports (prologos::data::list                           :refer (List nil cons)))
")

;; ========================================
;; Module Loading Tests
;; ========================================

(test-case "identity/additive-identity-trait-loads"
  (check-not-exn
    (lambda ()
      (run-ns
        "(ns test)
         (imports (prologos::core::algebra :refer (AdditiveIdentity)))"))))

(test-case "identity/multiplicative-identity-trait-loads"
  (check-not-exn
    (lambda ()
      (run-ns
        "(ns test)
         (imports (prologos::core::algebra :refer (MultiplicativeIdentity)))"))))

(test-case "identity/identity-instances-load"
  (check-not-exn
    (lambda ()
      (run-ns
        "(ns test)
         (imports (prologos::core::algebra :refer (AdditiveIdentity MultiplicativeIdentity)))"))))

(test-case "identity/generic-numeric-ops-loads"
  (check-not-exn
    (lambda ()
      (run-ns
        (string-append preamble "(def x : Int 0)")))))

;; ========================================
;; AdditiveIdentity — type inference
;; ========================================

(test-case "identity/additive-identity-int-type"
  (define result (run-ns-last (string-append preamble
    "(infer Int--AdditiveIdentity--dict)")))
  (check-contains result "Int"))

(test-case "identity/additive-identity-rat-type"
  (define result (run-ns-last (string-append preamble
    "(infer Rat--AdditiveIdentity--dict)")))
  (check-contains result "Rat"))

(test-case "identity/additive-identity-nat-type"
  (define result (run-ns-last (string-append preamble
    "(infer Nat--AdditiveIdentity--dict)")))
  (check-contains result "Nat"))

;; ========================================
;; MultiplicativeIdentity — type inference
;; ========================================

(test-case "identity/multiplicative-identity-int-type"
  (define result (run-ns-last (string-append preamble
    "(infer Int--MultiplicativeIdentity--dict)")))
  (check-contains result "Int"))

(test-case "identity/multiplicative-identity-rat-type"
  (define result (run-ns-last (string-append preamble
    "(infer Rat--MultiplicativeIdentity--dict)")))
  (check-contains result "Rat"))

(test-case "identity/multiplicative-identity-nat-type"
  (define result (run-ns-last (string-append preamble
    "(infer Nat--MultiplicativeIdentity--dict)")))
  (check-contains result "Nat"))

;; ========================================
;; AdditiveIdentity — evaluation
;; ========================================

(test-case "identity/additive-identity-int-eval"
  (define result (run-ns-last (string-append preamble
    "(eval (AdditiveIdentity-zero Int--AdditiveIdentity--dict))")))
  (check-contains result "0"))

(test-case "identity/additive-identity-nat-eval"
  (define result (run-ns-last (string-append preamble
    "(eval (AdditiveIdentity-zero Nat--AdditiveIdentity--dict))")))
  (check-contains result "0N"))

;; ========================================
;; MultiplicativeIdentity — evaluation
;; ========================================

(test-case "identity/multiplicative-identity-int-eval"
  (define result (run-ns-last (string-append preamble
    "(eval (MultiplicativeIdentity-one Int--MultiplicativeIdentity--dict))")))
  (check-contains result "1"))

;; ========================================
;; sum — type inference
;; ========================================

(test-case "identity/sum-type"
  ;; sum : Pi(A:0 Type) (A -> A -> A) -> A -> List A -> A
  ;; (Add A = A->A->A inlined, AdditiveIdentity A = A inlined)
  (define result (run-ns-last (string-append preamble
    "(infer sum)")))
  (check-contains result "Pi")
  (check-contains result "List"))

;; ========================================
;; sum — evaluation with Int
;; ========================================

(test-case "identity/sum-int-eval"
  (define result (run-ns-last (string-append preamble
    "(eval (sum Int--Add--dict Int--AdditiveIdentity--dict
      (cons Int 1 (cons Int 2 (cons Int 3 (nil Int))))))")))
  (check-contains result "6"))

(test-case "identity/sum-int-empty"
  (define result (run-ns-last (string-append preamble
    "(eval (sum Int--Add--dict Int--AdditiveIdentity--dict (nil Int)))")))
  (check-contains result "0"))

;; ========================================
;; product — type inference
;; ========================================

(test-case "identity/product-type"
  ;; product : Pi(A:0 Type) (A -> A -> A) -> A -> List A -> A
  ;; (Mul A = A->A->A inlined, MultiplicativeIdentity A = A inlined)
  (define result (run-ns-last (string-append preamble
    "(infer product)")))
  (check-contains result "Pi")
  (check-contains result "List"))

;; ========================================
;; product — evaluation with Int
;; ========================================

(test-case "identity/product-int-eval"
  (define result (run-ns-last (string-append preamble
    "(eval (product Int--Mul--dict Int--MultiplicativeIdentity--dict
      (cons Int 2 (cons Int 3 (cons Int 4 (nil Int))))))")))
  (check-contains result "24"))

(test-case "identity/product-int-empty"
  (define result (run-ns-last (string-append preamble
    "(eval (product Int--Mul--dict Int--MultiplicativeIdentity--dict (nil Int)))")))
  (check-contains result "1"))

;; ========================================
;; int-range — type inference
;; ========================================

(test-case "identity/int-range-type"
  (define result (run-ns-last (string-append preamble
    "(infer int-range)")))
  (check-contains result "Int")
  (check-contains result "List"))

;; ========================================
;; int-range — evaluation
;; ========================================

(test-case "identity/int-range-eval"
  (define result (run-ns-last (string-append preamble
    "(eval (int-range 0 3))")))
  ;; Pretty-printed as '[0 1 2] : List Int
  (check-contains result "0")
  (check-contains result "1")
  (check-contains result "2")
  (check-contains result "List")
  (check-contains result "Int"))

(test-case "identity/int-range-empty"
  (define result (run-ns-last (string-append preamble
    "(eval (int-range 5 3))")))
  ;; start > end → nil
  (check-contains result "nil"))

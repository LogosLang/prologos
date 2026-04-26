#lang racket/base

;;;
;;; Tests for Phase 3: Eq/Ord Instance Expansion + PartialOrd
;;; Tests eq-instances, ord-instances, eq-derived, partialord-trait.
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
(imports (prologos::core::eq :refer (Eq Eq-eq? eq-neq)))
(imports (prologos::core::ord :refer (Ord Ord-compare ord-lt ord-le ord-gt ord-ge ord-eq ord-min ord-max)))
(imports (prologos::core::eq :refer ()))
(imports (prologos::core::ord :refer ()))
(imports (prologos::core::eq :refer (option-eq)))
(imports (prologos::core::eq-derived :refer (list-eq)))
(imports (prologos::core::ord :refer (PartialOrd PartialOrd-partial-compare)))
(imports (prologos::data::option :refer (Option some none)))
(imports (prologos::data::list :refer (List nil cons)))
(imports (prologos::data::ordering :refer (Ordering lt-ord eq-ord gt-ord)))
")

(define (check-contains actual substr [msg #f])
  (check-true (string-contains? actual substr)
              (or msg (format "Expected ~s to contain ~s" actual substr))))


;; ========================================
;; Eq Bool
;; ========================================

(test-case "eq-ext/bool-true-true"
  (check-contains
   (run-ns-last (string-append preamble "(eval (Bool--Eq--eq? true true))"))
   "true : Bool"))


(test-case "eq-ext/bool-true-false"
  (check-contains
   (run-ns-last (string-append preamble "(eval (Bool--Eq--eq? true false))"))
   "false : Bool"))


(test-case "eq-ext/bool-false-false"
  (check-contains
   (run-ns-last (string-append preamble "(eval (Bool--Eq--eq? false false))"))
   "true : Bool"))


(test-case "eq-ext/bool-false-true"
  (check-contains
   (run-ns-last (string-append preamble "(eval (Bool--Eq--eq? false true))"))
   "false : Bool"))


;; ========================================
;; Eq Ordering
;; ========================================

(test-case "eq-ext/ordering-lt-lt"
  (check-contains
   (run-ns-last (string-append preamble "(eval (Ordering--Eq--eq? lt-ord lt-ord))"))
   "true : Bool"))


(test-case "eq-ext/ordering-lt-gt"
  (check-contains
   (run-ns-last (string-append preamble "(eval (Ordering--Eq--eq? lt-ord gt-ord))"))
   "false : Bool"))


(test-case "eq-ext/ordering-eq-eq"
  (check-contains
   (run-ns-last (string-append preamble "(eval (Ordering--Eq--eq? eq-ord eq-ord))"))
   "true : Bool"))


(test-case "eq-ext/ordering-gt-gt"
  (check-contains
   (run-ns-last (string-append preamble "(eval (Ordering--Eq--eq? gt-ord gt-ord))"))
   "true : Bool"))


;; ========================================
;; Ord Bool — false < true
;; ========================================

(test-case "ord-ext/bool-false-true"
  (check-contains
   (run-ns-last (string-append preamble "(eval (Bool--Ord--compare false true))"))
   "lt-ord"))


(test-case "ord-ext/bool-true-true"
  (check-contains
   (run-ns-last (string-append preamble "(eval (Bool--Ord--compare true true))"))
   "eq-ord"))


(test-case "ord-ext/bool-true-false"
  (check-contains
   (run-ns-last (string-append preamble "(eval (Bool--Ord--compare true false))"))
   "gt-ord"))


(test-case "ord-ext/bool-false-false"
  (check-contains
   (run-ns-last (string-append preamble "(eval (Bool--Ord--compare false false))"))
   "eq-ord"))

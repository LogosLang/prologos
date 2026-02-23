#lang racket/base

;;;
;;; Tests for Posit Identity Instances
;;; Verifies: AdditiveIdentity + MultiplicativeIdentity for Posit8/16/32/64
;;;           Generic sum/product work on Posit lists
;;;

(require rackunit
         racket/list
         racket/path
         racket/string
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

(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)]
                 [current-trait-registry (current-trait-registry)]
                 [current-impl-registry (current-impl-registry)]
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
;; Preamble
;; ========================================

(define preamble
  "(ns test)
(require (prologos::core::additive-identity-trait       :refer (AdditiveIdentity AdditiveIdentity-zero)))
(require (prologos::core::multiplicative-identity-trait  :refer (MultiplicativeIdentity MultiplicativeIdentity-one)))
(require (prologos::core::identity-instances             :refer ()))
(require (prologos::core::add-trait                      :refer (Add Add-add)))
(require (prologos::core::mul-trait                      :refer (Mul Mul-mul)))
(require (prologos::core::add-instances                  :refer ()))
(require (prologos::core::mul-instances                  :refer ()))
(require (prologos::core::generic-numeric-ops            :refer (sum product)))
(require (prologos::data::list                           :refer (List nil cons)))
")

;; ========================================
;; AdditiveIdentity — Posit type inference
;; ========================================

(test-case "posit-id/additive-identity-posit32-type"
  (define result (run-ns-last (string-append preamble
    "(infer Posit32--AdditiveIdentity--dict)")))
  (check-contains result "Posit32"))

(test-case "posit-id/additive-identity-posit8-type"
  (define result (run-ns-last (string-append preamble
    "(infer Posit8--AdditiveIdentity--dict)")))
  (check-contains result "Posit8"))

;; ========================================
;; MultiplicativeIdentity — Posit type inference
;; ========================================

(test-case "posit-id/multiplicative-identity-posit32-type"
  (define result (run-ns-last (string-append preamble
    "(infer Posit32--MultiplicativeIdentity--dict)")))
  (check-contains result "Posit32"))

(test-case "posit-id/multiplicative-identity-posit16-type"
  (define result (run-ns-last (string-append preamble
    "(infer Posit16--MultiplicativeIdentity--dict)")))
  (check-contains result "Posit16"))

;; ========================================
;; AdditiveIdentity — Posit evaluation
;; ========================================

(test-case "posit-id/additive-identity-posit32-eval"
  ;; Zero for Posit32: posit32 encoding 0 = posit zero
  (define result (run-ns-last (string-append preamble
    "(eval (AdditiveIdentity-zero Posit32--AdditiveIdentity--dict))")))
  (check-contains result "posit32 0"))

(test-case "posit-id/additive-identity-posit8-eval"
  (define result (run-ns-last (string-append preamble
    "(eval (AdditiveIdentity-zero Posit8--AdditiveIdentity--dict))")))
  (check-contains result "posit8 0"))

;; ========================================
;; MultiplicativeIdentity — Posit evaluation
;; ========================================

(test-case "posit-id/multiplicative-identity-posit32-eval"
  ;; One for Posit32: posit32 encoding 1073741824 = 1.0
  (define result (run-ns-last (string-append preamble
    "(eval (MultiplicativeIdentity-one Posit32--MultiplicativeIdentity--dict))")))
  (check-contains result "posit32 1073741824"))

;; ========================================
;; sum — Posit32 list
;; ========================================

(test-case "posit-id/sum-posit32"
  ;; sum [1.0, 2.0, 3.0] = 6.0 as Posit32
  ;; Posit32 encodings: ~1 = 1073741824, ~2 = 1207959552, ~3 = 1258291200
  (define result (run-ns-last (string-append preamble
    "(eval (sum Posit32--Add--dict Posit32--AdditiveIdentity--dict
      (cons Posit32 ~1 (cons Posit32 ~2 (cons Posit32 ~3 (nil Posit32))))))")))
  (check-contains result "Posit32")
  ;; 6.0 in Posit32 = encoding 1342177280
  (check-contains result "posit32"))

(test-case "posit-id/sum-posit32-empty"
  ;; sum of empty Posit32 list = zero = posit32(0)
  (define result (run-ns-last (string-append preamble
    "(eval (sum Posit32--Add--dict Posit32--AdditiveIdentity--dict (nil Posit32)))")))
  (check-contains result "posit32 0"))

;; ========================================
;; product — Posit32 list
;; ========================================

(test-case "posit-id/product-posit32"
  ;; product [~2, ~3] = 6.0 as Posit32
  (define result (run-ns-last (string-append preamble
    "(eval (product Posit32--Mul--dict Posit32--MultiplicativeIdentity--dict
      (cons Posit32 ~2 (cons Posit32 ~3 (nil Posit32)))))")))
  (check-contains result "Posit32")
  (check-contains result "posit32"))

(test-case "posit-id/product-posit32-empty"
  ;; product of empty = one = posit32(1073741824) = 1.0
  (define result (run-ns-last (string-append preamble
    "(eval (product Posit32--Mul--dict Posit32--MultiplicativeIdentity--dict (nil Posit32)))")))
  (check-contains result "posit32 1073741824"))

;; ========================================
;; Posit64 — verify larger width works too
;; ========================================

(test-case "posit-id/additive-identity-posit64-type"
  (define result (run-ns-last (string-append preamble
    "(infer Posit64--AdditiveIdentity--dict)")))
  (check-contains result "Posit64"))

(test-case "posit-id/multiplicative-identity-posit64-type"
  (define result (run-ns-last (string-append preamble
    "(infer Posit64--MultiplicativeIdentity--dict)")))
  (check-contains result "Posit64"))

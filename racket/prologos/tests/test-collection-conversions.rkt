#lang racket/base

;;;
;;; Tests for Phase 3f: Collection Conversion Functions
;;; Tests: vec, list-to-seq, pvec-to-seq, set-to-seq, into-list, into-vec, into-set
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
;; Preamble — loads conversion functions
;; ========================================

(define preamble
  "(ns test)
(require (prologos.core.collection-conversions :refer (vec list-to-seq pvec-to-seq set-to-seq into-list into-vec into-set)))
(require (prologos.data.list    :refer (List nil cons)))
(require (prologos.data.lseq    :refer (LSeq lseq-nil lseq-cell)))
(require (prologos.data.lseq-ops :refer (list-to-lseq lseq-to-list)))
")

;; ========================================
;; Module Loading Test
;; ========================================

(test-case "conversions/module-loads"
  (check-not-exn
    (lambda ()
      (run-ns
        "(ns test)
         (require (prologos.core.collection-conversions :refer (vec list-to-seq pvec-to-seq set-to-seq into-list into-vec into-set)))"))))

;; ========================================
;; vec — List → PVec
;; ========================================

(test-case "conversions/vec-type"
  (define result (run-ns-last (string-append preamble "(infer vec)")))
  (check-contains result "List")
  (check-contains result "PVec"))

(test-case "conversions/vec-eval"
  (define result (run-ns-last (string-append preamble
    "(eval (vec (cons Nat zero (cons Nat (suc zero) (nil Nat)))))")))
  (check-contains result "PVec")
  (check-contains result "Nat"))

;; ========================================
;; list-to-seq — List → LSeq
;; ========================================

(test-case "conversions/list-to-seq-type"
  (define result (run-ns-last (string-append preamble "(infer list-to-seq)")))
  (check-contains result "List")
  (check-contains result "LSeq"))

(test-case "conversions/list-to-seq-eval"
  (define result (run-ns-last (string-append preamble
    "(eval (list-to-seq (cons Nat zero (nil Nat))))")))
  (check-contains result "LSeq")
  (check-contains result "Nat"))

;; ========================================
;; pvec-to-seq — PVec → LSeq
;; ========================================

(test-case "conversions/pvec-to-seq-type"
  (define result (run-ns-last (string-append preamble "(infer pvec-to-seq)")))
  (check-contains result "PVec")
  (check-contains result "LSeq"))

;; ========================================
;; set-to-seq — Set → LSeq
;; ========================================

(test-case "conversions/set-to-seq-type"
  (define result (run-ns-last (string-append preamble "(infer set-to-seq)")))
  (check-contains result "Set")
  (check-contains result "LSeq"))

;; ========================================
;; into-list — LSeq → List
;; ========================================

(test-case "conversions/into-list-type"
  (define result (run-ns-last (string-append preamble "(infer into-list)")))
  (check-contains result "LSeq")
  (check-contains result "List"))

(test-case "conversions/into-list-eval"
  (define result (run-ns-last (string-append preamble
    "(eval (into-list (list-to-lseq Nat (cons Nat zero (cons Nat (suc zero) (nil Nat))))))")))
  (check-contains result "List")
  (check-contains result "Nat"))

;; ========================================
;; into-vec — LSeq → PVec
;; ========================================

(test-case "conversions/into-vec-type"
  (define result (run-ns-last (string-append preamble "(infer into-vec)")))
  (check-contains result "LSeq")
  (check-contains result "PVec"))

;; ========================================
;; into-set — LSeq → Set
;; ========================================

(test-case "conversions/into-set-type"
  (define result (run-ns-last (string-append preamble "(infer into-set)")))
  (check-contains result "LSeq")
  (check-contains result "Set"))

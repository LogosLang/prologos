#lang racket/base

;;;
;;; Tests for Phase 3d: LSeq Trait Instances
;;; Tests: seq-lseq, foldable-lseq, seqable-lseq, buildable-lseq
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
;; Preamble — loads LSeq traits
;; ========================================

(define preamble
  "(ns test)
(require (prologos.core.seq-trait      :refer (Seq seq-first seq-rest seq-empty?)))
(require (prologos.core.seqable-trait  :refer (Seqable)))
(require (prologos.core.buildable-trait :refer (Buildable)))
(require (prologos.core.foldable-trait  :refer (Foldable)))
(require (prologos.core.seq-lseq       :refer (LSeq--Seq--dict)))
(require (prologos.core.foldable-lseq  :refer (lseq-foldable)))
(require (prologos.core.seqable-lseq   :refer (LSeq--Seqable--dict)))
(require (prologos.core.buildable-lseq :refer (LSeq--Buildable--dict)))
(require (prologos.data.lseq           :refer (LSeq lseq-nil lseq-cell)))
(require (prologos.data.lseq-ops       :refer (lseq-to-list list-to-lseq)))
(require (prologos.data.option         :refer (Option some none)))
(require (prologos.data.list           :refer (List nil cons)))
")

;; ========================================
;; Module Loading Tests
;; ========================================

(test-case "lseq-traits/seq-lseq-loads"
  (check-not-exn
    (lambda ()
      (run-ns
        "(ns test)
         (require (prologos.core.seq-trait :refer (Seq)))
         (require (prologos.core.seq-lseq  :refer (LSeq--Seq--dict)))"))))

(test-case "lseq-traits/foldable-lseq-loads"
  (check-not-exn
    (lambda ()
      (run-ns
        "(ns test)
         (require (prologos.core.foldable-trait :refer (Foldable)))
         (require (prologos.core.foldable-lseq  :refer (lseq-foldable)))"))))

(test-case "lseq-traits/seqable-lseq-loads"
  (check-not-exn
    (lambda ()
      (run-ns
        "(ns test)
         (require (prologos.core.seqable-trait :refer (Seqable)))
         (require (prologos.core.seqable-lseq  :refer (LSeq--Seqable--dict)))"))))

(test-case "lseq-traits/buildable-lseq-loads"
  (check-not-exn
    (lambda ()
      (run-ns
        "(ns test)
         (require (prologos.core.buildable-trait :refer (Buildable)))
         (require (prologos.core.buildable-lseq  :refer (LSeq--Buildable--dict)))"))))

;; ========================================
;; Seq LSeq — type inference
;; ========================================

(test-case "lseq-traits/seq-dict-type"
  (define result (run-ns-last (string-append preamble "(infer LSeq--Seq--dict)")))
  (check-contains result "Sigma")
  (check-contains result "LSeq")
  (check-contains result "Option"))

(test-case "lseq-traits/seq-first-type"
  (define result (run-ns-last (string-append preamble
    "(def xs <(LSeq Nat)> (lseq-cell Nat zero (fn (_ : Unit) (lseq-nil Nat))))
     (infer (seq-first LSeq--Seq--dict xs))")))
  (check-contains result "Option")
  (check-contains result "Nat"))

(test-case "lseq-traits/seq-empty-type"
  (define result (run-ns-last (string-append preamble
    "(def xs <(LSeq Nat)> (lseq-nil Nat))
     (infer (seq-empty? LSeq--Seq--dict xs))")))
  (check-contains result "Bool"))

;; ========================================
;; Foldable LSeq — type inference
;; ========================================

(test-case "lseq-traits/foldable-dict-type"
  (define result (run-ns-last (string-append preamble "(infer lseq-foldable)")))
  (check-contains result "Pi")
  (check-contains result "LSeq"))

;; ========================================
;; Seqable LSeq — type inference (identity)
;; ========================================

(test-case "lseq-traits/seqable-dict-type"
  (define result (run-ns-last (string-append preamble "(infer LSeq--Seqable--dict)")))
  (check-contains result "Pi")
  (check-contains result "LSeq"))

(test-case "lseq-traits/seqable-identity"
  (define result (run-ns-last (string-append preamble
    "(def xs <(LSeq Nat)> (lseq-nil Nat))
     (infer (LSeq--Seqable--dict Nat xs))")))
  (check-contains result "LSeq")
  (check-contains result "Nat"))

;; ========================================
;; Buildable LSeq — type inference (identity)
;; ========================================

(test-case "lseq-traits/buildable-dict-type"
  (define result (run-ns-last (string-append preamble "(infer LSeq--Buildable--dict)")))
  (check-contains result "Sigma")
  (check-contains result "LSeq"))

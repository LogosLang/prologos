#lang racket/base

;;;
;;; Tests for Phase 3d: LSeq Trait Instances
;;; Tests: seq-lseq, foldable-lseq, seqable-lseq, buildable-lseq
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
;; Preamble — loads LSeq traits
;; ========================================

(define preamble
  "(ns test)
(imports (prologos::core::collection-traits      :refer (Seq seq-first seq-rest seq-empty?)))
(imports (prologos::core::collection-traits  :refer (Seqable)))
(imports (prologos::core::collection-traits :refer (Buildable)))
(imports (prologos::core::collection-traits  :refer (Foldable)))
(imports (prologos::core::lseq :refer (LSeq--Seq--dict lseq-foldable
                                       LSeq--Seqable--dict LSeq--Buildable--dict)))
(imports (prologos::data::lseq           :refer (LSeq lseq-nil lseq-cell)))
(imports (prologos::data::lseq-ops       :refer (lseq-to-list list-to-lseq)))
(imports (prologos::data::option         :refer (Option some none)))
(imports (prologos::data::list           :refer (List nil cons)))
")

;; ========================================
;; Module Loading Tests
;; ========================================

(test-case "lseq-traits/seq-lseq-loads"
  (check-not-exn
    (lambda ()
      (run-ns
        "(ns test)
         (imports (prologos::core::collection-traits :refer (Seq)))
         (imports (prologos::core::lseq  :refer (LSeq--Seq--dict)))"))))

(test-case "lseq-traits/foldable-lseq-loads"
  (check-not-exn
    (lambda ()
      (run-ns
        "(ns test)
         (imports (prologos::core::collection-traits :refer (Foldable)))
         (imports (prologos::core::lseq  :refer (lseq-foldable)))"))))

(test-case "lseq-traits/seqable-lseq-loads"
  (check-not-exn
    (lambda ()
      (run-ns
        "(ns test)
         (imports (prologos::core::collection-traits :refer (Seqable)))
         (imports (prologos::core::lseq  :refer (LSeq--Seqable--dict)))"))))

(test-case "lseq-traits/buildable-lseq-loads"
  (check-not-exn
    (lambda ()
      (run-ns
        "(ns test)
         (imports (prologos::core::collection-traits :refer (Buildable)))
         (imports (prologos::core::lseq  :refer (LSeq--Buildable--dict)))"))))

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

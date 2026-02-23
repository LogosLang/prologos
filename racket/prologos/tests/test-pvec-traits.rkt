#lang racket/base

;;;
;;; Tests for Phase 3b: PVec Trait Instances + PVec Ops
;;; Tests: seqable-pvec, buildable-pvec, foldable-pvec, functor-pvec,
;;;        indexed-pvec, pvec-ops
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

(define (check-contains actual substr [msg #f])
  (check-true (string-contains? actual substr)
              (or msg (format "Expected ~s to contain ~s" actual substr))))

;; ========================================
;; Preamble — loads PVec traits + ops
;; ========================================

(define preamble
  "(ns test)
(require (prologos::core::seqable-pvec    :refer (PVec--Seqable--dict)))
(require (prologos::core::buildable-pvec  :refer (PVec--Buildable--dict)))
(require (prologos::core::foldable-pvec   :refer (pvec-foldable)))
(require (prologos::core::functor-pvec    :refer (pvec-functor)))
(require (prologos::core::indexed-pvec    :refer (PVec--Indexed--dict pvec-idx-nth pvec-idx-length pvec-idx-update)))
(require (prologos::core::pvec-ops        :refer (pvec-map pvec-filter pvec-fold pvec-any? pvec-all? pvec-from-list-fn pvec-to-list-fn)))
(require (prologos::data::lseq            :refer (LSeq lseq-nil lseq-cell)))
(require (prologos::data::lseq-ops        :refer (lseq-to-list list-to-lseq)))
(require (prologos::data::option          :refer (Option some none)))
(require (prologos::data::list            :refer (List nil cons)))
")

;; ========================================
;; Seqable PVec — type and evaluation
;; ========================================

(test-case "pvec-traits/seqable-dict-type"
  (define result (run-ns-last (string-append preamble "(infer PVec--Seqable--dict)")))
  (check-contains result "Pi")
  (check-contains result "PVec")
  (check-contains result "LSeq"))

(test-case "pvec-traits/seqable-type-infer"
  (define result (run-ns-last (string-append preamble
    "(def v <(PVec Nat)> (pvec-push (pvec-push (pvec-empty Nat) zero) (suc zero)))
     (infer (PVec--Seqable--dict Nat v))")))
  (check-contains result "LSeq")
  (check-contains result "Nat"))

;; ========================================
;; Buildable PVec — type and evaluation
;; ========================================

(test-case "pvec-traits/buildable-dict-type"
  (define result (run-ns-last (string-append preamble "(infer PVec--Buildable--dict)")))
  (check-contains result "Sigma")
  (check-contains result "LSeq")
  (check-contains result "PVec"))

;; ========================================
;; Foldable PVec — type and evaluation
;; ========================================

(test-case "pvec-traits/foldable-dict-type"
  (define result (run-ns-last (string-append preamble "(infer pvec-foldable)")))
  (check-contains result "Pi")
  (check-contains result "PVec"))

(test-case "pvec-traits/foldable-eval"
  ;; foldr on PVec returns correct type
  (define result (run-ns-last (string-append preamble
    "(require (prologos::data::nat :refer (add)))
     (def v <(PVec Nat)> (pvec-push (pvec-push (pvec-push (pvec-empty Nat) (suc zero)) (suc (suc zero))) (suc (suc (suc zero)))))
     (infer (pvec-foldable Nat Nat (fn (a : Nat) (fn (b : Nat) (add b a))) zero v))")))
  (check-contains result "Nat"))

;; ========================================
;; Functor PVec — type and evaluation
;; ========================================

(test-case "pvec-traits/functor-dict-type"
  (define result (run-ns-last (string-append preamble "(infer pvec-functor)")))
  (check-contains result "Pi")
  (check-contains result "PVec"))

;; ========================================
;; Indexed PVec — type and evaluation
;; ========================================

(test-case "pvec-traits/indexed-dict-type"
  (define result (run-ns-last (string-append preamble "(infer PVec--Indexed--dict)")))
  (check-contains result "Sigma")
  (check-contains result "PVec")
  (check-contains result "Nat"))

(test-case "pvec-traits/indexed-length"
  (define result (run-ns-last (string-append preamble
    "(def v <(PVec Nat)> (pvec-push (pvec-push (pvec-empty Nat) zero) (suc zero)))
     (eval (pvec-idx-length Nat v))")))
  (check-contains result "2N"))

(test-case "pvec-traits/indexed-nth-in-bounds"
  (define result (run-ns-last (string-append preamble
    "(def v <(PVec Nat)> (pvec-push (pvec-push (pvec-empty Nat) zero) (suc zero)))
     (eval (pvec-idx-nth Nat v zero))")))
  (check-contains result "some")
  (check-contains result "0N"))

(test-case "pvec-traits/indexed-nth-out-of-bounds"
  (define result (run-ns-last (string-append preamble
    "(def v <(PVec Nat)> (pvec-push (pvec-empty Nat) zero))
     (eval (pvec-idx-nth Nat v (suc (suc zero))))")))
  (check-contains result "none"))

;; ========================================
;; PVec Ops — convenience functions
;; ========================================

(test-case "pvec-traits/pvec-map-type"
  (define result (run-ns-last (string-append preamble "(infer pvec-map)")))
  (check-contains result "Pi")
  (check-contains result "PVec"))

(test-case "pvec-traits/pvec-filter-type"
  (define result (run-ns-last (string-append preamble "(infer pvec-filter)")))
  (check-contains result "Pi")
  (check-contains result "PVec")
  (check-contains result "Bool"))

(test-case "pvec-traits/pvec-fold-type"
  (define result (run-ns-last (string-append preamble "(infer pvec-fold)")))
  (check-contains result "Pi")
  (check-contains result "PVec"))

(test-case "pvec-traits/pvec-any-type"
  (define result (run-ns-last (string-append preamble "(infer pvec-any?)")))
  (check-contains result "Pi")
  (check-contains result "PVec")
  (check-contains result "Bool"))

(test-case "pvec-traits/pvec-all-type"
  (define result (run-ns-last (string-append preamble "(infer pvec-all?)")))
  (check-contains result "Pi")
  (check-contains result "PVec")
  (check-contains result "Bool"))

(test-case "pvec-traits/pvec-from-list-fn-type"
  (define result (run-ns-last (string-append preamble "(infer pvec-from-list-fn)")))
  (check-contains result "List")
  (check-contains result "PVec"))

(test-case "pvec-traits/pvec-to-list-fn-type"
  (define result (run-ns-last (string-append preamble "(infer pvec-to-list-fn)")))
  (check-contains result "PVec")
  (check-contains result "List"))

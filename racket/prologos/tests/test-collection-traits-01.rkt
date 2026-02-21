#lang racket/base

;;;
;;; Tests for Phase 5: Collection Traits + List Instances
;;; Tests: seqable-trait, buildable-trait, indexed-trait, keyed-trait, setlike-trait
;;;        seqable-list, buildable-list, indexed-list
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
;; Preamble — loads all collection traits + list instances
;; ========================================

(define preamble
  "(ns test)
(require (prologos.core.seqable-trait   :refer (Seqable Seqable-to-seq)))
(require (prologos.core.buildable-trait :refer (Buildable Buildable-from-seq Buildable-empty-coll)))
(require (prologos.core.indexed-trait   :refer (Indexed Indexed-idx-nth Indexed-idx-length Indexed-idx-update)))
(require (prologos.core.keyed-trait     :refer (Keyed Keyed-kv-get Keyed-kv-assoc Keyed-kv-dissoc)))
(require (prologos.core.setlike-trait   :refer (Setlike Setlike-set-member? Setlike-set-insert Setlike-set-remove)))
(require (prologos.core.seqable-list    :refer (List--Seqable--dict)))
(require (prologos.core.buildable-list  :refer (List--Buildable--dict List--Buildable--from-seq List--Buildable--empty-coll)))
(require (prologos.core.indexed-list    :refer (List--Indexed--dict list-idx-nth list-idx-length list-idx-update)))
(require (prologos.data.lseq            :refer (LSeq lseq-nil lseq-cell)))
(require (prologos.data.lseq-ops        :refer (lseq-to-list list-to-lseq)))
(require (prologos.data.option          :refer (Option some none)))
(require (prologos.data.list            :refer (List nil cons)))
")


;; ========================================
;; Trait type tests — Seqable
;; ========================================

(test-case "collection/seqable-accessor-type"
  ;; Seqable-to-seq should have type involving (Type -> Type) param
  (define result (run-ns-last (string-append preamble "(infer Seqable-to-seq)")))
  (check-contains result "Type 0")
  (check-contains result "->"))


(test-case "collection/seqable-dict-type"
  ;; List--Seqable--dict : (Seqable List)
  ;; Seqable is single-method, so dict = the to-seq function itself
  (define result (run-ns-last (string-append preamble "(infer List--Seqable--dict)")))
  (check-contains result "Pi")
  (check-contains result "LSeq"))


;; ========================================
;; Trait type tests — Buildable
;; ========================================

(test-case "collection/buildable-from-seq-accessor-type"
  (define result (run-ns-last (string-append preamble "(infer Buildable-from-seq)")))
  (check-contains result "Type 0")
  (check-contains result "Sigma"))


(test-case "collection/buildable-dict-type"
  ;; List--Buildable--dict : (Buildable List) = Sigma(from-seq, empty-coll)
  (define result (run-ns-last (string-append preamble "(infer List--Buildable--dict)")))
  (check-contains result "Sigma")
  (check-contains result "LSeq")
  (check-contains result "List"))


;; ========================================
;; Trait type tests — Indexed
;; ========================================

(test-case "collection/indexed-accessor-types"
  (define results (run-ns (string-append preamble
    "(infer Indexed-idx-nth)
     (infer Indexed-idx-length)
     (infer Indexed-idx-update)")))
  (define type-results (filter string? results))
  (check-true (>= (length type-results) 3)
              "Expected at least 3 type-string results"))


(test-case "collection/indexed-dict-type"
  ;; List--Indexed--dict : (Indexed List) = nested Sigma of 3 methods
  (define result (run-ns-last (string-append preamble "(infer List--Indexed--dict)")))
  (check-contains result "Sigma")
  (check-contains result "Nat")
  (check-contains result "Option"))


;; ========================================
;; Trait type tests — Keyed
;; ========================================

(test-case "collection/keyed-accessor-types"
  (define results (run-ns (string-append preamble
    "(infer Keyed-kv-get)
     (infer Keyed-kv-assoc)
     (infer Keyed-kv-dissoc)")))
  (define type-results (filter string? results))
  (check-true (>= (length type-results) 3)
              "Expected at least 3 type-string results for Keyed"))


;; ========================================
;; Trait type tests — Setlike
;; ========================================

(test-case "collection/setlike-accessor-types"
  (define results (run-ns (string-append preamble
    "(infer Setlike-set-member?)
     (infer Setlike-set-insert)
     (infer Setlike-set-remove)")))
  (define type-results (filter string? results))
  (check-true (>= (length type-results) 3)
              "Expected at least 3 type-string results for Setlike"))


;; ========================================
;; Seqable List — functional tests
;; ========================================

(test-case "collection/seqable-list-to-seq"
  ;; List--Seqable--dict IS list-to-lseq, convert list to lseq then back
  (check-contains
   (run-ns-last (string-append preamble
     "(eval (lseq-to-list Nat (List--Seqable--dict Nat (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))))))"))
   "'[1N 2N]"))


(test-case "collection/seqable-list-empty"
  ;; to-seq on empty list → lseq-nil → nil
  (check-contains
   (run-ns-last (string-append preamble
     "(eval (lseq-to-list Nat (List--Seqable--dict Nat (nil Nat))))"))
   "nil"))

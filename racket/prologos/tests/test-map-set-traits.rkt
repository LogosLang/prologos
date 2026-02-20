#lang racket/base

;;;
;;; Tests for Phase 3c: Map/Set Trait Instances + Ops Modules
;;; Tests: keyed-map, setlike-set, seqable-set, buildable-set,
;;;        foldable-set, set-ops, map-ops
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
;; Preamble — loads Map/Set traits + ops
;; ========================================

(define preamble
  "(ns test)
(require (prologos.core.keyed-trait    :refer (Keyed)))
(require (prologos.core.setlike-trait  :refer (Setlike)))
(require (prologos.core.seqable-trait  :refer (Seqable)))
(require (prologos.core.buildable-trait :refer (Buildable Buildable-from-seq Buildable-empty-coll)))
(require (prologos.core.foldable-trait  :refer (Foldable)))
(require (prologos.core.keyed-map      :refer (Map--Keyed--dict)))
(require (prologos.core.setlike-set    :refer (Set--Setlike--dict)))
(require (prologos.core.seqable-set    :refer (Set--Seqable--dict)))
(require (prologos.core.buildable-set  :refer (Set--Buildable--dict)))
(require (prologos.core.foldable-set   :refer (set-foldable)))
(require (prologos.core.set-ops        :refer (set-map set-filter set-fold set-any? set-all? set-to-list-fn set-from-list-fn)))
(require (prologos.core.map-ops        :refer (map-map-vals map-filter-vals map-fold-entries map-keys-list map-vals-list map-merge)))
(require (prologos.data.lseq           :refer (LSeq lseq-nil lseq-cell)))
(require (prologos.data.lseq-ops       :refer (lseq-to-list list-to-lseq)))
(require (prologos.data.option         :refer (Option some none)))
(require (prologos.data.list           :refer (List nil cons)))
(require (prologos.data.set            :refer (set-singleton set-from-list)))
")

;; ========================================
;; Module Loading Tests
;; ========================================

(test-case "map-set-traits/keyed-map-loads"
  (check-not-exn
    (lambda ()
      (run-ns
        "(ns test)
         (require (prologos.core.keyed-trait :refer (Keyed)))
         (require (prologos.core.keyed-map   :refer (Map--Keyed--dict)))"))))

(test-case "map-set-traits/setlike-set-loads"
  (check-not-exn
    (lambda ()
      (run-ns
        "(ns test)
         (require (prologos.core.setlike-trait :refer (Setlike)))
         (require (prologos.core.setlike-set   :refer (Set--Setlike--dict)))"))))

(test-case "map-set-traits/seqable-set-loads"
  (check-not-exn
    (lambda ()
      (run-ns
        "(ns test)
         (require (prologos.core.seqable-trait :refer (Seqable)))
         (require (prologos.core.seqable-set   :refer (Set--Seqable--dict)))"))))

(test-case "map-set-traits/buildable-set-loads"
  (check-not-exn
    (lambda ()
      (run-ns
        "(ns test)
         (require (prologos.core.buildable-trait :refer (Buildable)))
         (require (prologos.core.buildable-set   :refer (Set--Buildable--dict)))"))))

(test-case "map-set-traits/foldable-set-loads"
  (check-not-exn
    (lambda ()
      (run-ns
        "(ns test)
         (require (prologos.core.foldable-trait :refer (Foldable)))
         (require (prologos.core.foldable-set   :refer (set-foldable)))"))))

(test-case "map-set-traits/set-ops-loads"
  (check-not-exn
    (lambda ()
      (run-ns
        "(ns test)
         (require (prologos.core.set-ops :refer (set-map set-filter set-fold set-any? set-all? set-to-list-fn set-from-list-fn)))"))))

(test-case "map-set-traits/map-ops-loads"
  (check-not-exn
    (lambda ()
      (run-ns
        "(ns test)
         (require (prologos.core.map-ops :refer (map-map-vals map-filter-vals map-fold-entries map-keys-list map-vals-list map-merge)))"))))

;; ========================================
;; Keyed Map — type inference
;; ========================================

(test-case "map-set-traits/keyed-dict-type"
  (define result (run-ns-last (string-append preamble "(infer Map--Keyed--dict)")))
  (check-contains result "Sigma")
  (check-contains result "Map")
  (check-contains result "Option"))

(test-case "map-set-traits/keyed-first-type"
  ;; first of keyed dict = kv-get function
  (define result (run-ns-last (string-append preamble
    "(infer (first Map--Keyed--dict))")))
  (check-contains result "Pi")
  (check-contains result "Map")
  (check-contains result "Option"))

(test-case "map-set-traits/keyed-second-type"
  ;; second of keyed dict = (pair kv-assoc kv-dissoc)
  (define result (run-ns-last (string-append preamble
    "(infer (second Map--Keyed--dict))")))
  (check-contains result "Sigma")
  (check-contains result "Map"))

;; ========================================
;; Setlike Set — type inference
;; ========================================

(test-case "map-set-traits/setlike-dict-type"
  (define result (run-ns-last (string-append preamble "(infer Set--Setlike--dict)")))
  (check-contains result "Sigma")
  (check-contains result "Set")
  (check-contains result "Bool"))

(test-case "map-set-traits/setlike-first-type"
  ;; first of setlike dict = set-member? function
  (define result (run-ns-last (string-append preamble
    "(infer (first Set--Setlike--dict))")))
  (check-contains result "Pi")
  (check-contains result "Set")
  (check-contains result "Bool"))

;; ========================================
;; Seqable Set — type inference
;; ========================================

(test-case "map-set-traits/seqable-set-dict-type"
  (define result (run-ns-last (string-append preamble "(infer Set--Seqable--dict)")))
  (check-contains result "Pi")
  (check-contains result "Set")
  (check-contains result "LSeq"))

(test-case "map-set-traits/seqable-set-to-seq"
  (define result (run-ns-last (string-append preamble
    "(def s <(Set Nat)> (set-insert (set-empty Nat) zero))
     (infer (Set--Seqable--dict Nat s))")))
  (check-contains result "LSeq")
  (check-contains result "Nat"))

;; ========================================
;; Buildable Set — type inference
;; ========================================

(test-case "map-set-traits/buildable-set-dict-type"
  (define result (run-ns-last (string-append preamble "(infer Set--Buildable--dict)")))
  (check-contains result "Sigma")
  (check-contains result "LSeq")
  (check-contains result "Set"))

(test-case "map-set-traits/buildable-set-second"
  ;; second of buildable dict = empty-coll function
  (define result (run-ns-last (string-append preamble
    "(infer (second Set--Buildable--dict))")))
  (check-contains result "Pi")
  (check-contains result "Set"))

;; ========================================
;; Foldable Set — type inference
;; ========================================

(test-case "map-set-traits/foldable-set-dict-type"
  (define result (run-ns-last (string-append preamble "(infer set-foldable)")))
  (check-contains result "Pi")
  (check-contains result "Set"))

;; ========================================
;; Set Ops — type inference
;; ========================================

(test-case "map-set-traits/set-map-type"
  (define result (run-ns-last (string-append preamble "(infer set-map)")))
  (check-contains result "Pi")
  (check-contains result "Set"))

(test-case "map-set-traits/set-filter-type"
  (define result (run-ns-last (string-append preamble "(infer set-filter)")))
  (check-contains result "Pi")
  (check-contains result "Set")
  (check-contains result "Bool"))

(test-case "map-set-traits/set-fold-type"
  (define result (run-ns-last (string-append preamble "(infer set-fold)")))
  (check-contains result "Pi")
  (check-contains result "Set"))

(test-case "map-set-traits/set-any-type"
  (define result (run-ns-last (string-append preamble "(infer set-any?)")))
  (check-contains result "Pi")
  (check-contains result "Set")
  (check-contains result "Bool"))

(test-case "map-set-traits/set-all-type"
  (define result (run-ns-last (string-append preamble "(infer set-all?)")))
  (check-contains result "Pi")
  (check-contains result "Set")
  (check-contains result "Bool"))

;; ========================================
;; Map Ops — type inference
;; ========================================

(test-case "map-set-traits/map-map-vals-type"
  (define result (run-ns-last (string-append preamble "(infer map-map-vals)")))
  (check-contains result "Pi")
  (check-contains result "Map"))

(test-case "map-set-traits/map-fold-entries-type"
  (define result (run-ns-last (string-append preamble "(infer map-fold-entries)")))
  (check-contains result "Pi")
  (check-contains result "Map"))

(test-case "map-set-traits/map-keys-list-type"
  (define result (run-ns-last (string-append preamble "(infer map-keys-list)")))
  (check-contains result "Map")
  (check-contains result "List"))

(test-case "map-set-traits/map-vals-list-type"
  (define result (run-ns-last (string-append preamble "(infer map-vals-list)")))
  (check-contains result "Map")
  (check-contains result "List"))

(test-case "map-set-traits/map-merge-type"
  (define result (run-ns-last (string-append preamble "(infer map-merge)")))
  (check-contains result "Pi")
  (check-contains result "Map"))

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
;; Preamble — loads Map/Set traits + ops
;; ========================================

(define preamble
  "(ns test)
(imports (prologos::core::collection-traits    :refer (Keyed)))
(imports (prologos::core::collection-traits  :refer (Setlike)))
(imports (prologos::core::collection-traits  :refer (Seqable)))
(imports (prologos::core::collection-traits :refer (Buildable Buildable-from-seq Buildable-empty-coll)))
(imports (prologos::core::collection-traits  :refer (Foldable)))
(imports (prologos::core::map :refer (Map--Keyed--dict map-filter-vals map-keys-list map-vals-list map-merge)))
(imports (prologos::core::set :refer (Set--Setlike--dict Set--Seqable--dict Set--Buildable--dict
                                      set-foldable set-map set-any? set-all? set-to-list-fn set-from-list-fn)))
(imports (prologos::data::lseq           :refer (LSeq lseq-nil lseq-cell)))
(imports (prologos::data::lseq-ops       :refer (lseq-to-list list-to-lseq)))
(imports (prologos::data::option         :refer (Option some none)))
(imports (prologos::data::list           :refer (List nil cons)))
(imports (prologos::data::set            :refer (set-singleton set-from-list)))
")


;; ========================================
;; Module Loading Tests
;; ========================================

(test-case "map-set-traits/keyed-map-loads"
  (check-not-exn
    (lambda ()
      (run-ns
        "(ns test)
         (imports (prologos::core::collection-traits :refer (Keyed)))
         (imports (prologos::core::map   :refer (Map--Keyed--dict)))"))))


(test-case "map-set-traits/setlike-set-loads"
  (check-not-exn
    (lambda ()
      (run-ns
        "(ns test)
         (imports (prologos::core::collection-traits :refer (Setlike)))
         (imports (prologos::core::set   :refer (Set--Setlike--dict)))"))))


(test-case "map-set-traits/seqable-set-loads"
  (check-not-exn
    (lambda ()
      (run-ns
        "(ns test)
         (imports (prologos::core::collection-traits :refer (Seqable)))
         (imports (prologos::core::set   :refer (Set--Seqable--dict)))"))))


(test-case "map-set-traits/buildable-set-loads"
  (check-not-exn
    (lambda ()
      (run-ns
        "(ns test)
         (imports (prologos::core::collection-traits :refer (Buildable)))
         (imports (prologos::core::set   :refer (Set--Buildable--dict)))"))))


(test-case "map-set-traits/foldable-set-loads"
  (check-not-exn
    (lambda ()
      (run-ns
        "(ns test)
         (imports (prologos::core::collection-traits :refer (Foldable)))
         (imports (prologos::core::set   :refer (set-foldable)))"))))


(test-case "map-set-traits/set-ops-loads"
  (check-not-exn
    (lambda ()
      (run-ns
        "(ns test)
         (imports (prologos::core::set :refer (set-map set-any? set-all? set-to-list-fn set-from-list-fn)))"))))


(test-case "map-set-traits/map-ops-loads"
  (check-not-exn
    (lambda ()
      (run-ns
        "(ns test)
         (imports (prologos::core::map :refer (map-filter-vals map-keys-list map-vals-list map-merge)))"))))


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
    "(infer (fst Map--Keyed--dict))")))
  (check-contains result "Pi")
  (check-contains result "Map")
  (check-contains result "Option"))


(test-case "map-set-traits/keyed-second-type"
  ;; second of keyed dict = (pair kv-assoc kv-dissoc)
  (define result (run-ns-last (string-append preamble
    "(infer (snd Map--Keyed--dict))")))
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
    "(infer (fst Set--Setlike--dict))")))
  (check-contains result "Pi")
  (check-contains result "Set")
  (check-contains result "Bool"))

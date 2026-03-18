#lang racket/base

;;;
;;; Tests for Phase 3g: Prelude expansion — collection types and operations
;;; Verifies all new collection types, operations, and conversions
;;; are accessible from a standard (ns foo) context.
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

;; Standard prelude preamble — just (ns foo) should give access to everything
(define preamble "(ns foo)\n")

;; ========================================
;; LSeq type + operations accessible
;; ========================================

(test-case "prelude/lseq-type-accessible"
  (define result (run-ns-last (string-append preamble "(infer LSeq)")))
  (check-contains result "Type"))

(test-case "prelude/lseq-nil-accessible"
  (check-not-exn
    (lambda ()
      (run-ns (string-append preamble "(def xs : (LSeq Nat) (lseq-nil Nat))")))))

(test-case "prelude/list-to-lseq-accessible"
  (define result (run-ns-last (string-append preamble "(infer list-to-lseq)")))
  (check-contains result "List")
  (check-contains result "LSeq"))

;; ========================================
;; PVec operations accessible
;; ========================================

;; pvec-map, pvec-filter are now native parser keywords — test in applied form.

(test-case "prelude/pvec-map-accessible"
  (define result (run-ns-last (string-append preamble
    "(def v : (PVec Nat) (pvec-push (pvec-empty Nat) zero))
     (infer (pvec-map (fn (x : Nat) (suc x)) v))")))
  (check-contains result "PVec"))

(test-case "prelude/pvec-filter-accessible"
  (define result (run-ns-last (string-append preamble
    "(def v : (PVec Nat) (pvec-push (pvec-empty Nat) zero))
     (infer (pvec-filter (fn (x : Nat) true) v))")))
  (check-contains result "PVec"))

;; ========================================
;; Map operations accessible
;; ========================================

;; map-fold-entries is now a native parser keyword — test in applied form.
(test-case "prelude/map-fold-entries-accessible"
  (define result (run-ns-last (string-append preamble
    "(def m : (Map Nat Nat) (map-assoc (map-empty Nat Nat) zero (suc zero)))
     (infer (map-fold-entries (fn (acc : Nat) (fn (k : Nat) (fn (v : Nat) acc))) zero m))")))
  (check-contains result "Nat"))

(test-case "prelude/map-merge-accessible"
  (define result (run-ns-last (string-append preamble "(infer map-merge)")))
  (check-contains result "Map"))

;; ========================================
;; Set operations accessible
;; ========================================

(test-case "prelude/set-map-accessible"
  (define result (run-ns-last (string-append preamble "(infer set-map)")))
  (check-contains result "Set"))

;; set-filter is now a native parser keyword — test in applied form.
(test-case "prelude/set-filter-accessible"
  (define result (run-ns-last (string-append preamble
    "(def s : (Set Nat) (set-insert (set-empty Nat) zero))
     (infer (set-filter (fn (x : Nat) true) s))")))
  (check-contains result "Set"))

;; ========================================
;; Collection conversions accessible
;; ========================================

(test-case "prelude/vec-accessible"
  (define result (run-ns-last (string-append preamble "(infer vec)")))
  (check-contains result "List")
  (check-contains result "PVec"))

(test-case "prelude/into-vec-accessible"
  (define result (run-ns-last (string-append preamble "(infer into-vec)")))
  (check-contains result "LSeq")
  (check-contains result "PVec"))

(test-case "prelude/into-set-accessible"
  (define result (run-ns-last (string-append preamble "(infer into-set)")))
  (check-contains result "LSeq")
  (check-contains result "Set"))

;; ========================================
;; Generic numeric ops accessible
;; ========================================

(test-case "prelude/sum-accessible"
  (define result (run-ns-last (string-append preamble "(infer sum)")))
  (check-contains result "Pi")
  (check-contains result "List"))

(test-case "prelude/product-accessible"
  (define result (run-ns-last (string-append preamble "(infer product)")))
  (check-contains result "Pi")
  (check-contains result "List"))

(test-case "prelude/int-range-accessible"
  (define result (run-ns-last (string-append preamble "(infer int-range)")))
  (check-contains result "Int")
  (check-contains result "List"))

;; ========================================
;; Identity traits accessible
;; ========================================

(test-case "prelude/additive-identity-accessible"
  ;; AdditiveIdentity is a deftype (type constructor), so test it in a type annotation.
  ;; Single-method trait: AdditiveIdentity Nat = Nat, so dict IS the zero element.
  (check-not-exn
    (lambda ()
      (run-ns (string-append preamble "(def z : (AdditiveIdentity Nat) 0N)")))))

(test-case "prelude/multiplicative-identity-accessible"
  ;; MultiplicativeIdentity is also a deftype.
  (check-not-exn
    (lambda ()
      (run-ns (string-append preamble "(def o : (MultiplicativeIdentity Nat) 1N)")))))

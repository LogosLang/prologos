#lang racket/base

;;;
;;; Tests for Phase 2: Hashable Trait and Hash Utilities
;;; Tests hashable.prologos (trait + hash-combine + Nat/Bool/Ordering impls + hash-option/hash-list)
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
;; Shared Fixture (modules loaded once)
;; ========================================

(define shared-preamble
  "(ns test)
(imports (prologos::core::hashable :refer (Hashable Hashable-hash hash-combine nat31 hash-option hash-list)))
(imports (prologos::data::option :refer (Option some none)))
(imports (prologos::data::list :refer (List nil cons)))
(imports (prologos::data::ordering :refer (Ordering lt-ord eq-ord gt-ord)))
")

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg)
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
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-multi-defn-registry (current-multi-defn-registry)]
                 [current-spec-store (hasheq)])
    (install-module-loader!)
    (process-string shared-preamble)
    (values (current-prelude-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry))))

(define (run s)
  (parameterize ([current-prelude-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg])
    (process-string s)))

(define (run-last s) (last (run s)))

;; Also provide run-all for tests that check multiple results
(define (run-all s) (run s))

(define (check-contains actual substr [msg #f])
  (check-true (string-contains? actual substr)
              (or msg (format "Expected ~s to contain ~s" actual substr))))

(test-case "hashable/option-none"
  ;; hash-option none = 0
  (check-contains
   (run-last "(eval (hash-option Nat--Hashable--dict (none Nat)))")
   "0N : Nat"))

(test-case "hashable/option-some-5"
  ;; hash-option (some 5) = hash-combine 1 5 = 1*31 + 5 = 36
  (check-contains
   (run-last "(eval (hash-option Nat--Hashable--dict (some Nat (suc (suc (suc (suc (suc zero))))))))")
   "36N : Nat"))

;; ========================================
;; hash-list
;; ========================================

(test-case "hashable/list-empty"
  ;; hash-list nil = 0
  (check-contains
   (run-last "(eval (hash-list Nat--Hashable--dict (nil Nat)))")
   "0N : Nat"))

(test-case "hashable/list-singleton"
  ;; hash-list [1] = hash-combine 1 0 = 1*31 + 0 = 31
  (check-contains
   (run-last "(eval (hash-list Nat--Hashable--dict (cons Nat (suc zero) (nil Nat))))")
   "31N : Nat"))

(test-case "hashable/list-two-elements"
  ;; hash-list [1, 2] = hash-combine 1 (hash-combine 2 0)
  ;;                   = hash-combine 1 (2*31 + 0)
  ;;                   = hash-combine 1 62
  ;;                   = 1*31 + 62
  ;;                   = 93
  (check-contains
   (run-last "(eval (hash-list Nat--Hashable--dict (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat)))))")
   "93N : Nat"))

;; ========================================
;; Module loading tests
;; ========================================

(test-case "hashable/trait-module-load"
  ;; Verify hashable module loads (trait definitions)
  (define results (run-all
    "(infer Hashable-hash)
     (infer hash-combine)
     (infer nat31)"))
  (define type-results (filter string? results))
  (check-true (>= (length type-results) 3)
              "Expected at least 3 type-string results"))

(test-case "hashable/instances-module-load"
  ;; Verify hashable module loads with all expected impls
  (define results (run-all
    "(infer Nat--Hashable--dict)
     (infer Bool--Hashable--dict)
     (infer Ordering--Hashable--dict)
     (infer hash-option)
     (infer hash-list)"))
  (define type-results (filter string? results))
  (check-true (>= (length type-results) 5)
              "Expected at least 5 type-string results"))

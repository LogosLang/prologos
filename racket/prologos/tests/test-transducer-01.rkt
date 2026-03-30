#lang racket/base

;;;
;;; Tests for Phase 2c.3: Transducer Infrastructure
;;; Tests transducer.prologos — map-xf, filter-xf, remove-xf,
;;; transduce, xf-compose, list-conj, xf-into-list-rev.
;;;
;;; Key design notes:
;;; - All transducers are R-polymorphic: Pi [R :0 Type] (R -> B -> R) -> (R -> A -> R)
;;; - transduce and xf-into-list-rev accept polymorphic xf and specialize R internally
;;; - xf-compose composes two transducers, threading R through both
;;; - Individual xf functions (map-xf, filter-xf) take their config args but NOT R
;;;   when passed to transduce/xf-into-list-rev (R is still erased/polymorphic)

(require rackunit
         racket/list
         racket/path
         racket/string
         racket/port
         racket/file
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
         "../reduction.rkt"
         (prefix-in tc: "../typing-core.rkt")
         "../namespace.rkt"
         "../trait-resolution.rkt"
         "../parse-reader.rkt")

;; ========================================
;; Shared Fixture (modules loaded once)
;; ========================================

;; Standard preamble: load transducer + list + lseq modules,
;; plus commonly-used data definitions and helper functions.
(define shared-preamble
  "(ns test)
(imports (prologos::data::list :refer (List nil cons))
         (prologos::data::lseq :refer (LSeq lseq-nil lseq-cell lseq-head lseq-rest lseq-empty?))
         (prologos::data::lseq-ops :refer (list-to-lseq lseq-to-list lseq-map lseq-filter lseq-fold lseq-length))
         (prologos::data::transducer :refer (transduce map-xf filter-xf remove-xf xf-compose list-conj xf-into-list-rev)))

;; Helper: make a list of Nat: '(1 2 3)
(def list123 : (List Nat)
   (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))

;; suc-fn : Nat -> Nat
(def suc-fn : (-> Nat Nat) (fn (x : Nat) (suc x)))

;; is-positive : Nat -> Bool — returns false for zero, true otherwise
(def is-positive : (-> Nat Bool)
  (fn (x : Nat) (match x (zero -> false) (suc _ -> true))))

;; is-zero : Nat -> Bool
(def is-zero : (-> Nat Bool)
  (fn (x : Nat) (match x (zero -> true) (suc _ -> false))))
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
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-bundle-registry (current-bundle-registry)])
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
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-bundle-registry (current-bundle-registry)])
    (process-string s)))

(define (run-last s) (last (run s)))

;; Run WS-mode code via temp .prologos file using shared environment
(define (run-ws s)
  (define tmp (make-temporary-file "prologos-test-~a.prologos"))
  (call-with-output-file tmp #:exists 'replace
    (lambda (out) (display s out)))
  (define result
    (parameterize ([current-prelude-env shared-global-env]
                   [current-ns-context shared-ns-context]
                   [current-module-registry shared-module-reg]
                   [current-lib-paths (list prelude-lib-dir)]
                   [current-mult-meta-store (make-hasheq)]
                   [current-preparse-registry (current-preparse-registry)]
                   [current-trait-registry shared-trait-reg]
                   [current-impl-registry shared-impl-reg]
                   [current-param-impl-registry shared-param-impl-reg]
                   [current-bundle-registry (current-bundle-registry)])
      (process-file tmp)))
  (delete-file tmp)
  result)

(define (run-ws-last s) (last (run-ws s)))

;; Helper: check that a result string contains a substring
(define (check-contains actual substr [msg #f])
  (check-true (string-contains? actual substr)
              (or msg (format "Expected ~s to contain ~s" actual substr))))

;; ========================================
;; A. map-xf — Map Transducer (4 tests)
;; ========================================

(test-case "xf/map-xf-type: map-xf type-checks"
  ;; map-xf should produce a well-typed transducer
  (check-contains
   (run-last "(infer (map-xf Nat Nat))")
   "->"))

(test-case "xf/map-xf-suc: map suc over [1,2,3] via transduce"
  ;; transduce (map-xf suc-fn) list-conj nil list123
  ;; = fold (map-xf suc-fn list-conj) nil [1,2,3]
  ;; = [4, 3, 2] (reversed since fold-left with cons)
  (define result (run-last
    "(eval (transduce Nat Nat (List Nat) (map-xf Nat Nat suc-fn) (list-conj Nat) (nil Nat) list123))"))
  (check-contains result "'[4N 3N 2N]")
  (check-contains result "List Nat"))

(test-case "xf/map-xf-empty: map over empty list"
  (define result (run-last
    "(eval (transduce Nat Nat (List Nat) (map-xf Nat Nat suc-fn) (list-conj Nat) (nil Nat) (nil Nat)))"))
  (check-contains result "nil")
  (check-contains result "List Nat"))

(test-case "xf/map-xf-into: map using xf-into-list-rev"
  ;; xf-into-list-rev wraps the xf + list-conj + nil pattern
  (define result (run-last
    "(eval (xf-into-list-rev Nat Nat (map-xf Nat Nat suc-fn) list123))"))
  (check-contains result "'[4N 3N 2N]")
  (check-contains result "List Nat"))

;; ========================================
;; B. filter-xf — Filter Transducer (4 tests)
;; ========================================

(test-case "xf/filter-xf-type: filter-xf type-checks"
  (check-contains
   (run-last "(infer (filter-xf Nat))")
   "->"))

(test-case "xf/filter-xf-positive: filter positives from [0,1,2,3]"
  ;; Build [0, 1, 2, 3] and filter for is-positive → [3, 2, 1] (reversed)
  (define result (run-last
    "(def list0123 : (List Nat)
       (cons Nat zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))
     (eval (transduce Nat Nat (List Nat) (filter-xf Nat is-positive) (list-conj Nat) (nil Nat) list0123))"))
  (check-contains result "'[3N 2N 1N]")
  (check-contains result "List Nat"))

(test-case "xf/filter-xf-none-match: filter yields empty when nothing matches"
  ;; Filter is-zero on [1,2,3] → nothing matches → nil
  (define result (run-last
    "(eval (transduce Nat Nat (List Nat) (filter-xf Nat is-zero) (list-conj Nat) (nil Nat) list123))"))
  (check-contains result "nil")
  (check-contains result "List Nat"))

(test-case "xf/filter-xf-all-match: filter keeps all when all match"
  ;; Filter is-positive on [1,2,3] → all pass → [3, 2, 1] (reversed)
  (define result (run-last
    "(eval (transduce Nat Nat (List Nat) (filter-xf Nat is-positive) (list-conj Nat) (nil Nat) list123))"))
  (check-contains result "'[3N 2N 1N]")
  (check-contains result "List Nat"))

;; ========================================
;; C. remove-xf — Remove Transducer (3 tests)
;; ========================================

(test-case "xf/remove-xf-type: remove-xf type-checks"
  (check-contains
   (run-last "(infer (remove-xf Nat))")
   "->"))

(test-case "xf/remove-xf-zeros: remove zeros from [0,1,0,2,3]"
  (define result (run-last
    "(def list01023 : (List Nat)
       (cons Nat zero (cons Nat (suc zero) (cons Nat zero (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))))
     (eval (transduce Nat Nat (List Nat) (remove-xf Nat is-zero) (list-conj Nat) (nil Nat) list01023))"))
  (check-contains result "'[3N 2N 1N]")
  (check-contains result "List Nat"))

(test-case "xf/remove-xf-positive: remove positives from [0,1,2] → [0]"
  (define result (run-last
    "(def list012 : (List Nat)
       (cons Nat zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat)))))
     (eval (transduce Nat Nat (List Nat) (remove-xf Nat is-positive) (list-conj Nat) (nil Nat) list012))"))
  (check-contains result "'[0N]")
  (check-contains result "List Nat"))

;; ========================================
;; D. xf-compose — Transducer Composition (6 tests)
;; ========================================

(test-case "xf/compose-filter-map: filter positive then map suc"
  ;; (xf-compose (filter-xf is-positive) (map-xf suc)) on [0,1,2]
  ;; Step 1 (filter positive): 0→skip, 1→pass, 2→pass
  ;; Step 2 (map suc): 1→2, 2→3 → [3, 2] (reversed)
  (define result (run-last
    "(def list012 : (List Nat)
       (cons Nat zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat)))))
     (eval (transduce Nat Nat (List Nat) (xf-compose Nat Nat Nat (filter-xf Nat is-positive) (map-xf Nat Nat suc-fn)) (list-conj Nat) (nil Nat) list012))"))
  (check-contains result "'[3N 2N]")
  (check-contains result "List Nat"))

(test-case "xf/compose-map-filter: map suc then filter positive"
  ;; (xf-compose (map-xf suc) (filter-xf is-positive)) on [0,1,2]
  ;; Step 1 (map suc): 0→1, 1→2, 2→3
  ;; Step 2 (filter positive): 1→pass, 2→pass, 3→pass → [3, 2, 1] (reversed)
  (define result (run-last
    "(def list012 : (List Nat)
       (cons Nat zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat)))))
     (eval (transduce Nat Nat (List Nat) (xf-compose Nat Nat Nat (map-xf Nat Nat suc-fn) (filter-xf Nat is-positive)) (list-conj Nat) (nil Nat) list012))"))
  (check-contains result "'[3N 2N 1N]")
  (check-contains result "List Nat"))

(test-case "xf/compose-filter-filter: two filters"
  ;; (xf-compose (filter-xf is-positive) (remove-xf is-zero)) on [0,1,2]
  ;; Step 1 (filter positive): 0→skip, 1→pass, 2→pass
  ;; Step 2 (remove zero): 1→pass, 2→pass → [2, 1] (reversed)
  (define result (run-last
    "(def list012 : (List Nat)
       (cons Nat zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat)))))
     (eval (transduce Nat Nat (List Nat) (xf-compose Nat Nat Nat (filter-xf Nat is-positive) (remove-xf Nat is-zero)) (list-conj Nat) (nil Nat) list012))"))
  (check-contains result "'[2N 1N]")
  (check-contains result "List Nat"))

(test-case "xf/compose-identity: map id is identity"
  ;; map-xf with identity function should produce same list (reversed)
  (define result (run-last
    "(def id-fn : (-> Nat Nat) (fn (x : Nat) x))
     (eval (transduce Nat Nat (List Nat) (map-xf Nat Nat id-fn) (list-conj Nat) (nil Nat) list123))"))
  (check-contains result "'[3N 2N 1N]")
  (check-contains result "List Nat"))

(test-case "xf/compose-on-empty: composed transducer on empty list"
  (define result (run-last
    "(eval (transduce Nat Nat (List Nat) (xf-compose Nat Nat Nat (map-xf Nat Nat suc-fn) (filter-xf Nat is-positive)) (list-conj Nat) (nil Nat) (nil Nat)))"))
  (check-contains result "nil")
  (check-contains result "List Nat"))

(test-case "xf/compose-xf-into-list-rev: composed xf with xf-into-list-rev"
  ;; xf-into-list-rev with composed xf
  (define result (run-last
    "(def list012 : (List Nat)
       (cons Nat zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat)))))
     (eval (xf-into-list-rev Nat Nat (xf-compose Nat Nat Nat (filter-xf Nat is-positive) (map-xf Nat Nat suc-fn)) list012))"))
  (check-contains result "'[3N 2N]")
  (check-contains result "List Nat"))

;; ========================================
;; E. transduce with custom reducers (4 tests)
;; ========================================

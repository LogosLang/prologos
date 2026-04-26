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

(test-case "xf/transduce-count: count elements via fold"
  ;; Use transduce with a counting reducer (acc + 1) to count positives
  (define result (run-last
    "(def list0123 : (List Nat)
       (cons Nat zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))
     (def count-rf : (-> Nat (-> Nat Nat))
       (fn (acc : Nat) (fn (_ : Nat) (suc acc))))
     (eval (transduce Nat Nat Nat (filter-xf Nat is-positive) count-rf zero list0123))"))
  (check-contains result "3N : Nat"))

(test-case "xf/transduce-sum: sum with map"
  ;; Sum of suc-mapped [1,2,3] = sum of [2,3,4] = 9
  (define result (run-last
    "(imports (prologos::data::nat :refer (add)))
     (def sum-rf : (-> Nat (-> Nat Nat))
       (fn (acc : Nat) (fn (x : Nat) (add acc x))))
     (eval (transduce Nat Nat Nat (map-xf Nat Nat suc-fn) sum-rf zero list123))"))
  (check-contains result "9N : Nat"))

(test-case "xf/transduce-sum-filtered: sum positives only"
  ;; Sum of positives in [0,1,2,3] = 1+2+3 = 6
  (define result (run-last
    "(imports (prologos::data::nat :refer (add)))
     (def list0123 : (List Nat)
       (cons Nat zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))
     (def sum-rf : (-> Nat (-> Nat Nat))
       (fn (acc : Nat) (fn (x : Nat) (add acc x))))
     (eval (transduce Nat Nat Nat (filter-xf Nat is-positive) sum-rf zero list0123))"))
  (check-contains result "6N : Nat"))

(test-case "xf/transduce-composed-sum: sum of suc-mapped positives"
  ;; On [0,1,2,3]: filter positive → [1,2,3], map suc → [2,3,4], sum → 9
  (define result (run-last
    "(imports (prologos::data::nat :refer (add)))
     (def list0123 : (List Nat)
       (cons Nat zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))
     (def sum-rf : (-> Nat (-> Nat Nat))
       (fn (acc : Nat) (fn (x : Nat) (add acc x))))
     (eval (transduce Nat Nat Nat (xf-compose Nat Nat Nat (filter-xf Nat is-positive) (map-xf Nat Nat suc-fn)) sum-rf zero list0123))"))
  (check-contains result "9N : Nat"))

;; ========================================
;; F. list-conj and xf-into-list-rev (3 tests)
;; ========================================

(test-case "xf/list-conj-type: list-conj type-checks"
  (check-contains
   (run-last "(infer (list-conj Nat))")
   "->"))

(test-case "xf/xf-into-list-rev-map: xf-into-list-rev with map"
  (define result (run-last
    "(eval (xf-into-list-rev Nat Nat (map-xf Nat Nat suc-fn) list123))"))
  (check-contains result "'[4N 3N 2N]")
  (check-contains result "List Nat"))

(test-case "xf/xf-into-list-rev-filter: xf-into-list-rev with filter"
  (define result (run-last
    "(def list012 : (List Nat)
       (cons Nat zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat)))))
     (eval (xf-into-list-rev Nat Nat (filter-xf Nat is-positive) list012))"))
  (check-contains result "'[2N 1N]")
  (check-contains result "List Nat"))

;; ========================================
;; G. WS Mode Integration (4 tests)
;; ========================================

(test-case "ws/transducer-module-loads: transducer module loads via WS"
  ;; Just verify the module can be loaded and a def type-checks
  (define results (run-ws
    "ns test\nimports [prologos::data::transducer :refer [map-xf filter-xf transduce list-conj]]\ninfer [map-xf Nat Nat]"))
  (check-contains (last results) "->"))

(test-case "ws/transducer-map: transduce with map-xf in WS mode"
  (define result (run-ws-last
    "ns test
require [prologos::data::list :refer [List nil cons]]
require [prologos::data::transducer :refer [transduce map-xf list-conj]]

(def list12 : [List Nat] (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))))
(def suc-fn : [-> Nat Nat] (fn (x : Nat) (suc x)))
eval [transduce Nat Nat [List Nat] [map-xf Nat Nat suc-fn] [list-conj Nat] [nil Nat] list12]"))
  (check-contains result "'[3N 2N]")
  (check-contains result "List Nat"))

(test-case "ws/xf-compose: xf-compose in WS mode"
  (define result (run-ws-last
    "ns test
require [prologos::data::list :refer [List nil cons]]
require [prologos::data::transducer :refer [transduce map-xf filter-xf xf-compose list-conj]]

(def list012 : [List Nat] (cons Nat zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat)))))
(def suc-fn : [-> Nat Nat] (fn (x : Nat) (suc x)))
(def is-positive : [-> Nat Bool] (fn (x : Nat) (match x (zero -> false) (suc _ -> true))))
eval [transduce Nat Nat [List Nat] [xf-compose Nat Nat Nat [filter-xf Nat is-positive] [map-xf Nat Nat suc-fn]] [list-conj Nat] [nil Nat] list012]"))
  (check-contains result "'[3N 2N]")
  (check-contains result "List Nat"))

(test-case "ws/xf-into-list-rev-ws: xf-into-list-rev in WS mode"
  (define result (run-ws-last
    "ns test
require [prologos::data::list :refer [List nil cons]]
require [prologos::data::transducer :refer [xf-into-list-rev map-xf]]

(def list12 : [List Nat] (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))))
(def suc-fn : [-> Nat Nat] (fn (x : Nat) (suc x)))
eval [xf-into-list-rev Nat Nat [map-xf Nat Nat suc-fn] list12]"))
  (check-contains result "'[3N 2N]")
  (check-contains result "List Nat"))

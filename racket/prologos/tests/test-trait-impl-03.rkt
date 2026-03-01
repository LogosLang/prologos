#lang racket/base

;;;
;;; Tests for trait/impl system (macros.rkt layer 1)
;;; Phase A.1: trait declarations
;;; Phase A.2: impl declarations
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
         "../namespace.rkt")

;; ========================================
;; Helpers
;; ========================================

(define (run s)
  (parameterize ([current-global-env (hasheq)])
    (process-string s)))

(define (run-first s) (car (run s)))

(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry])
    (install-module-loader!)
    (process-string s)))

(define (run-ns-last s) (last (run-ns s)))


;; ========================================
;; WS Pipeline Integration: trait + impl end-to-end
;; ========================================

(test-case "ws/trait-impl-single-method-end-to-end"
  ;; Define trait + impl + use dict through WS pipeline
  (define result
    (run-ns-last
     (string-append
      "(ns ws-t1)\n"
      ;; Define trait with single method
      "(trait (Stringify (A : (Type 0))) (show : A -> Nat))\n"
      ;; Implement for Nat (identity)
      "(impl Stringify Nat (defn show (x : Nat) : Nat x))\n"
      ;; Use the dictionary
      "(eval (Nat--Stringify--show (suc (suc zero))))")))
  (check-equal? result "2N : Nat"))


(test-case "ws/trait-accessor-projects-correctly"
  ;; Single-method: accessor is identity, so accessor applied to dict = dict
  (define result
    (run-ns-last
     (string-append
      "(ns ws-t3)\n"
      "(trait (Stringify (A : (Type 0))) (show : A -> Nat))\n"
      "(impl Stringify Nat (defn show (x : Nat) : Nat x))\n"
      ;; Accessor should work on the dict
      "(eval (Stringify-show Nat Nat--Stringify--dict (suc (suc (suc zero)))))")))
  (check-equal? result "3N : Nat"))


;; ========================================
;; Phase A.2: Impl Declarations — Macro Level
;; ========================================

(test-case "impl/single-method-generates-dict"
  ;; impl for a single-method trait produces a dict def
  (parameterize ([current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry (hasheq)]
                 [current-impl-registry (hasheq)])
    ;; First register the trait
    (process-trait '(trait (Showable (A : (Type 0))) (show : A -> Nat)))
    ;; Then process impl
    (define defs
      (process-impl '(impl Showable Nat
                       (defn show (x : Nat) : Nat x))))
    ;; Should produce: 1 helper defn + 1 dict def = 2 defs
    (check-equal? (length defs) 2)
    ;; Helper defn
    (define helper (first defs))
    (check-equal? (car helper) 'defn)
    (check-equal? (cadr helper) 'Nat--Showable--show)
    ;; Dict def
    (define dict-d (second defs))
    (check-equal? (car dict-d) 'def)
    (check-equal? (cadr dict-d) 'Nat--Showable--dict)
    ;; For single-method, dict value is the helper name
    (define dict-body (last dict-d))
    (check-equal? dict-body 'Nat--Showable--show)))


(test-case "impl/multi-method-generates-pair"
  ;; impl for a multi-method trait produces paired dict
  (parameterize ([current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry (hasheq)]
                 [current-impl-registry (hasheq)])
    ;; Register 2-method trait
    (process-trait '(trait (Eq (A : (Type 0)))
                     (== : A -> A -> Bool)
                     (/= : A -> A -> Bool)))
    ;; Process impl
    (define defs
      (process-impl '(impl Eq Nat
                       (defn == (x : Nat) (y : Nat) : Bool true)
                       (defn /= (x : Nat) (y : Nat) : Bool false))))
    ;; 2 helper defns + 1 dict def = 3
    (check-equal? (length defs) 3)
    ;; Dict value should be pair
    (define dict-d (third defs))
    (define dict-body (last dict-d))
    (check-equal? (car dict-body) 'pair)
    (check-equal? (cadr dict-body) 'Nat--Eq--==)
    (check-equal? (caddr dict-body) 'Nat--Eq--/=)))


(test-case "impl/registers-in-impl-registry"
  ;; impl registers in the impl registry
  (parameterize ([current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry (hasheq)]
                 [current-impl-registry (hasheq)])
    (process-trait '(trait (Showable (A : (Type 0))) (show : A -> Nat)))
    (process-impl '(impl Showable Nat
                     (defn show (x : Nat) : Nat x)))
    (define entry (lookup-impl 'Nat--Showable))
    (check-true (impl-entry? entry))
    (check-equal? (impl-entry-trait-name entry) 'Showable)
    (check-equal? (impl-entry-type-args entry) '(Nat))
    (check-equal? (impl-entry-dict-name entry) 'Nat--Showable--dict)))


(test-case "impl/error-unknown-trait"
  ;; impl for unregistered trait should error
  (parameterize ([current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry (hasheq)]
                 [current-impl-registry (hasheq)])
    (check-exn
     exn:fail?
     (lambda ()
       (process-impl '(impl Unknown Nat (defn foo (x : Nat) : Nat x)))))))


(test-case "impl/error-wrong-method-count"
  ;; impl with wrong number of methods
  (parameterize ([current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry (hasheq)]
                 [current-impl-registry (hasheq)])
    (process-trait '(trait (Eq (A : (Type 0)))
                     (== : A -> A -> Bool)
                     (/= : A -> A -> Bool)))
    (check-exn
     exn:fail?
     (lambda ()
       (process-impl '(impl Eq Nat
                        (defn == (x : Nat) (y : Nat) : Bool true)))))))


(test-case "impl/error-wrong-method-name"
  ;; impl with wrong method name
  (parameterize ([current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry (hasheq)]
                 [current-impl-registry (hasheq)])
    (process-trait '(trait (Showable (A : (Type 0))) (show : A -> Nat)))
    (check-exn
     exn:fail?
     (lambda ()
       (process-impl '(impl Showable Nat
                        (defn wrong-name (x : Nat) : Nat x)))))))


(test-case "impl/three-methods-nested-pair"
  ;; Three methods should produce nested pair
  (parameterize ([current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry (hasheq)]
                 [current-impl-registry (hasheq)])
    (process-trait '(trait (Arith (A : (Type 0)))
                     (add-a : A -> A -> A)
                     (sub-a : A -> A -> A)
                     (neg-a : A -> A)))
    (define defs
      (process-impl '(impl Arith Nat
                       (defn add-a (x : Nat) (y : Nat) : Nat x)
                       (defn sub-a (x : Nat) (y : Nat) : Nat x)
                       (defn neg-a (x : Nat) : Nat x))))
    ;; 3 helpers + 1 dict = 4
    (check-equal? (length defs) 4)
    ;; Dict body: (pair helper1 (pair helper2 helper3))
    (define dict-body (last (last defs)))
    (check-equal? dict-body
                  '(pair Nat--Arith--add-a (pair Nat--Arith--sub-a Nat--Arith--neg-a)))))


(test-case "impl/preparse-expand-all-integration"
  ;; Verify impl is handled by preparse-expand-all
  (parameterize ([current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry (hasheq)]
                 [current-impl-registry (hasheq)]
                 [current-ns-context #f])
    ;; Register trait first
    (define trait-stxs
      (list (datum->syntax #f '(trait (Showable (A : (Type 0))) (show : A -> Nat)))))
    (preparse-expand-all trait-stxs)
    ;; Now process impl
    (define impl-stxs
      (list (datum->syntax #f '(impl Showable Nat
                                 (defn show (x : Nat) : Nat x)))))
    (define result (preparse-expand-all impl-stxs))
    ;; Should produce 2 defs: helper + dict
    (check-equal? (length result) 2)))


;; ========================================
;; Phase D.2: Eq/Ord Migration Tests
;; ========================================

(test-case "d2/eq-trait-loads-via-trait-syntax"
  ;; eq-trait.prologos now uses trait/impl syntax
  (define result
    (run-ns-last
     (string-append
      "(ns d2t1)\n"
      "(require [prologos::core::eq :refer [nat-eq]])\n"
      "(eval (nat-eq zero zero))")))
  (check-equal? result "true : Bool"))


(test-case "d2/eq-trait-neq-works"
  (define result
    (run-ns-last
     (string-append
      "(ns d2t2)\n"
      "(require [prologos::core::eq :refer [nat-eq eq-neq]])\n"
      "(eval (eq-neq Nat nat-eq (suc zero) (suc (suc zero))))")))
  (check-equal? result "true : Bool"))


(test-case "d2/ord-trait-loads-via-trait-syntax"
  ;; ord-trait.prologos now uses trait/impl syntax
  (define result
    (run-ns-last
     (string-append
      "(ns d2t3)\n"
      "(require [prologos::core::ord :refer [nat-ord ord-lt]])\n"
      "(eval (ord-lt Nat nat-ord (suc zero) (suc (suc (suc zero)))))")))
  (check-equal? result "true : Bool"))


(test-case "d2/ord-min-works"
  (define result
    (run-ns-last
     (string-append
      "(ns d2t4)\n"
      "(require [prologos::core::ord :refer [nat-ord ord-min]])\n"
      "(eval (ord-min Nat nat-ord (suc (suc (suc zero))) (suc zero)))")))
  (check-equal? result "1N : Nat"))


(test-case "d2/eq-dict-is-callable"
  ;; The dict itself should be the eq? function (single-method trait)
  (define result
    (run-ns-last
     (string-append
      "(ns d2t5)\n"
      "(require [prologos::core::eq :refer [Nat--Eq--dict]])\n"
      "(eval (Nat--Eq--dict (suc (suc zero)) (suc (suc zero))))")))
  (check-equal? result "true : Bool"))


(test-case "d2/ord-dict-is-callable"
  ;; The dict itself should be the compare function (single-method trait)
  (define result
    (run-ns-last
     (string-append
      "(ns d2t6)\n"
      "(require [prologos::core::ord :refer [Nat--Ord--dict]])\n"
      "(require [prologos::data::ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n"
      "(eval (the Nat (match (Nat--Ord--dict (suc zero) (suc (suc zero))) (lt-ord -> zero) (eq-ord -> (suc zero)) (gt-ord -> (suc (suc zero))))))")))
  (check-equal? result "0N : Nat"))

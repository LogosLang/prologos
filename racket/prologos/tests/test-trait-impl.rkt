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

(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (current-trait-registry)]
                 [current-impl-registry (current-impl-registry)])
    (install-module-loader!)
    (process-string s)))

(define (run-ns-last s) (last (run-ns s)))

;; ========================================
;; Phase A.1: Trait Declarations — Macro Level
;; ========================================

(test-case "trait/parse-single-method"
  ;; (trait (Showable (A : (Type 0))) (show : A -> Nat))
  ;; Should register trait and produce accessor defs
  (parameterize ([current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)])
    (define defs
      (process-trait '(trait (Showable (A : (Type 0))) (show : A -> Nat))))
    ;; Should produce 1 accessor def
    (check-equal? (length defs) 1)
    ;; Accessor should be named Showable-show
    (define acc (car defs))
    (check-equal? (cadr acc) 'Showable-show)
    ;; Trait should be registered
    (define tm (lookup-trait 'Showable))
    (check-true (trait-meta? tm))
    (check-equal? (trait-meta-name tm) 'Showable)
    (check-equal? (length (trait-meta-methods tm)) 1)
    (check-equal? (trait-method-name (car (trait-meta-methods tm))) 'show)))

(test-case "trait/parse-multi-method"
  ;; (trait (Eq (A : (Type 0))) (== : A -> A -> Bool) (/= : A -> A -> Bool))
  (parameterize ([current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)])
    (define defs
      (process-trait '(trait (Eq (A : (Type 0))) (== : A -> A -> Bool) (/= : A -> A -> Bool))))
    ;; Should produce 2 accessor defs
    (check-equal? (length defs) 2)
    (check-equal? (cadr (first defs)) 'Eq-==)
    (check-equal? (cadr (second defs)) 'Eq-/=)
    ;; Trait should have 2 methods
    (define tm (lookup-trait 'Eq))
    (check-equal? (length (trait-meta-methods tm)) 2)))

(test-case "trait/single-method-deftype-is-bare"
  ;; Single-method trait: dictionary type is the bare method type (no Sigma)
  (parameterize ([current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)])
    (process-trait '(trait (Showable (A : (Type 0))) (show : A -> Nat)))
    ;; The deftype should have been registered. Verify by expanding it.
    (define expanded (preparse-expand-form '(Showable Nat)))
    ;; Should expand to (-> Nat Nat) — the method type with A=Nat
    (check-equal? expanded '(-> Nat Nat))))

(test-case "trait/multi-method-deftype-is-sigma"
  ;; Multi-method: dictionary type is nested Sigma
  (parameterize ([current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)])
    (process-trait '(trait (Eq (A : (Type 0))) (== : A -> A -> Bool) (/= : A -> A -> Bool)))
    (define expanded (preparse-expand-form '(Eq Nat)))
    ;; Should expand to (Sigma (_ : (-> Nat (-> Nat Bool))) (-> Nat (-> Nat Bool)))
    (check-equal? expanded '(Sigma (_ : (-> Nat (-> Nat Bool))) (-> Nat (-> Nat Bool))))))

(test-case "trait/brace-params-syntax"
  ;; WS-style: (trait Eq ($brace-params A) (== : A -> A -> Bool))
  (parameterize ([current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)])
    (define defs
      (process-trait '(trait Eq ($brace-params A) (== : A -> A -> Bool))))
    (check-equal? (length defs) 1)
    (define tm (lookup-trait 'Eq))
    (check-true (trait-meta? tm))
    (check-equal? (trait-meta-name tm) 'Eq)
    (check-equal? (length (trait-meta-params tm)) 1)))

(test-case "trait/multi-param"
  ;; Trait with multiple type params
  (parameterize ([current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)])
    (define defs
      (process-trait '(trait Convertible ($brace-params A B)
                        (convert : A -> B))))
    (check-equal? (length defs) 1)
    (define tm (lookup-trait 'Convertible))
    (check-equal? (length (trait-meta-params tm)) 2)))

(test-case "trait/accessor-body-single-method"
  ;; Single-method accessor body: outer lambda for type param, inner for dict
  (parameterize ([current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)])
    (define defs
      (process-trait '(trait (Showable (A : (Type 0))) (show : A -> Nat))))
    (define acc-def (car defs))
    ;; body is (fn (A :0 (Type 0)) (fn (dict : (Showable A)) dict))
    (define body (last acc-def))
    (check-equal? (car body) 'fn)
    ;; Inner fn should have identity projection
    (define inner-fn (caddr body))
    (check-equal? (car inner-fn) 'fn)
    (check-equal? (caddr inner-fn) 'dict)))

(test-case "trait/accessor-body-multi-method-first"
  ;; Multi-method: first accessor should project via (first dict)
  (parameterize ([current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)])
    (define defs
      (process-trait '(trait (Eq (A : (Type 0))) (== : A -> A -> Bool) (/= : A -> A -> Bool))))
    (define acc1 (car defs))
    (define body1 (last acc1))
    ;; body is (fn (A :0 (Type 0)) (fn (dict ...) (first dict)))
    (define inner1 (caddr body1))
    (check-equal? (caddr inner1) '(first dict))))

(test-case "trait/accessor-body-multi-method-second"
  ;; Multi-method: second accessor should project via (second dict)
  (parameterize ([current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)])
    (define defs
      (process-trait '(trait (Eq (A : (Type 0))) (== : A -> A -> Bool) (/= : A -> A -> Bool))))
    (define acc2 (second defs))
    (define body2 (last acc2))
    ;; body is (fn (A :0 (Type 0)) (fn (dict ...) (second dict)))
    (define inner2 (caddr body2))
    (check-equal? (caddr inner2) '(second dict))))

(test-case "trait/three-methods-sigma-nesting"
  ;; Three methods: (Sigma (_ T1) (Sigma (_ T2) T3))
  (parameterize ([current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)])
    (define defs
      (process-trait '(trait (Arith (A : (Type 0)))
                        (add-a : A -> A -> A)
                        (sub-a : A -> A -> A)
                        (neg-a : A -> A))))
    (check-equal? (length defs) 3)
    ;; Verify trait metadata
    (define tm (lookup-trait 'Arith))
    (check-equal? (length (trait-meta-methods tm)) 3)
    ;; Verify accessor names
    (check-equal? (cadr (first defs)) 'Arith-add-a)
    (check-equal? (cadr (second defs)) 'Arith-sub-a)
    (check-equal? (cadr (third defs)) 'Arith-neg-a)))

(test-case "trait/three-methods-accessor-projections"
  ;; Three methods: verify projection bodies
  (parameterize ([current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)])
    (define defs
      (process-trait '(trait (Arith (A : (Type 0)))
                        (add-a : A -> A -> A)
                        (sub-a : A -> A -> A)
                        (neg-a : A -> A -> A))))
    ;; Each body is (fn (A :0 (Type 0)) (fn (dict ...) projection))
    ;; 1st: (first dict)
    (check-equal? (caddr (caddr (last (first defs)))) '(first dict))
    ;; 2nd: (first (second dict))
    (check-equal? (caddr (caddr (last (second defs)))) '(first (second dict)))
    ;; 3rd: (second (second dict))
    (check-equal? (caddr (caddr (last (third defs)))) '(second (second dict)))))

(test-case "trait/error-no-methods"
  ;; Trait with no methods should error
  (parameterize ([current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)])
    (check-exn
     exn:fail?
     (lambda ()
       (process-trait '(trait (Empty (A : (Type 0)))))))))

(test-case "trait/error-bad-method"
  ;; Method without type annotation should error
  (parameterize ([current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)])
    (check-exn
     exn:fail?
     (lambda ()
       (process-trait '(trait (Bad (A : (Type 0))) (foo)))))))

(test-case "trait/preparse-expand-all-integration"
  ;; Verify trait is handled by preparse-expand-all
  (parameterize ([current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)]
                 [current-ns-context #f])
    (define stxs
      (list (datum->syntax #f '(trait (Showable (A : (Type 0))) (show : A -> Nat)))))
    (define result (preparse-expand-all stxs))
    ;; Should produce accessor def(s)
    (check-true (> (length result) 0))
    ;; First result should be the accessor def
    (define first-datum (syntax->datum (car result)))
    (check-equal? (car first-datum) 'def)
    (check-equal? (cadr first-datum) 'Showable-show)))

;; ========================================
;; Phase A.1: Integration — Trait Through Pipeline
;; ========================================

(test-case "trait/single-method-through-pipeline"
  ;; Single-method trait: define trait then use dict as bare function
  (define result
    (run-ns-last
     (string-append
      "(ns trait-t1)\n"
      ;; Define a simple single-method trait (sexp needs $A for pattern var)
      "(deftype (Showable $A) (-> $A Nat))\n"
      ;; Use it as a function: the dictionary IS the function
      "(def nat-show : (Showable Nat) (fn [x <Nat>] x))\n"
      "(eval (nat-show (inc (inc zero))))")))
  (check-equal? result "2 : Nat"))

(test-case "trait/multi-method-dict-through-pipeline"
  ;; Multi-method trait: dictionary is a Sigma pair, using projections
  ;; Use explicit Sigma type without deftype alias to isolate the test
  (define result
    (run-ns-last
     (string-append
      "(ns trait-t2)\n"
      "(def nat-eq2 : (Sigma (_ : (-> Nat (-> Nat Bool))) (-> Nat (-> Nat Bool)))"
      "  (pair (fn [x <Nat>] (fn [y <Nat>] true)) (fn [x <Nat>] (fn [y <Nat>] false))))\n"
      ;; Project first method then apply
      "(eval ((first nat-eq2) zero zero))")))
  (check-equal? result "true : Bool"))

;; ========================================
;; Phase A.1: Trait Registration Smoke Tests
;; ========================================

(test-case "trait/method-type-parsing-arrow"
  ;; Verify that A -> A -> Bool becomes (-> A (-> A Bool))
  (parameterize ([current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)])
    (define m (parse-trait-method '(== : A -> A -> Bool) 'Eq))
    (check-equal? (trait-method-name m) '==)
    (check-equal? (trait-method-type-datum m) '(-> A (-> A Bool)))))

(test-case "trait/method-type-parsing-no-arrow"
  ;; Bare type: (count : Nat)
  (parameterize ([current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)])
    (define m (parse-trait-method '(count : Nat) 'Counter))
    (check-equal? (trait-method-type-datum m) 'Nat)))

(test-case "trait/method-type-parsing-applied"
  ;; Applied type in return: (first : S A -> A)
  (parameterize ([current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)])
    (define m (parse-trait-method '(toList : A -> (List A)) 'ToList))
    (check-equal? (trait-method-type-datum m) '(-> A (List A)))))

;; ========================================
;; Phase B.1: New Data Types — Either, Never
;; ========================================

(test-case "b1/either-left-right"
  ;; Either with left and right constructors
  (define result
    (run-ns-last
     (string-append
      "(ns either-t1)\n"
      "(require [prologos.data.either :refer [Either left right is-left is-right]])\n"
      "(eval (is-left (left Nat Bool (inc zero))))")))
  (check-equal? result "true : Bool"))

(test-case "b1/either-map"
  ;; map over Either right value — implicit type params inferred
  (define result
    (run-ns-last
     (string-append
      "(ns either-t2)\n"
      "(require [prologos.data.either :refer [Either left right map]])\n"
      "(eval (map (fn [x <Nat>] (inc x)) (right Bool Nat zero)))")))
  ;; Output has qualified names: [prologos.data.either::right Bool Nat 1]
  (check-true (string-contains? result "right"))
  (check-true (string-contains? result "Either")))

(test-case "b1/either-to-option"
  ;; Convert Either to Option
  (define result
    (run-ns-last
     (string-append
      "(ns either-t3)\n"
      "(require [prologos.data.either :refer [Either left right to-option]])\n"
      "(require [prologos.data.option :refer [Option none some]])\n"
      "(eval (to-option Nat Nat (right Nat Nat (inc zero))))")))
  (check-true (string-contains? result "some"))
  (check-true (string-contains? result "1")))

(test-case "b1/never-type-exists"
  ;; Never type can be defined (zero constructors)
  (define result
    (run-ns-last
     (string-append
      "(ns never-t1)\n"
      "(require [prologos.data.never :refer [Never]])\n"
      "(check Never : (Type 0))")))
  (check-equal? result "OK"))

(test-case "b1/zero-ctor-data"
  ;; Zero-constructor data produces just the type def
  (parameterize ([current-preparse-registry (current-preparse-registry)]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)])
    (define defs (process-data '(data Void)))
    (check-equal? (length defs) 1)
    (check-equal? (cadr (car defs)) 'Void)))

;; ========================================
;; Phase D.1: Extended Option/Result/Pair Combinators
;; ========================================

(test-case "d1/option-is-some"
  (define result
    (run-ns-last
     (string-append
      "(ns opt-t1)\n"
      "(require [prologos.data.option :refer [some none is-some]])\n"
      "(eval (is-some (some Nat zero)))")))
  (check-equal? result "true : Bool"))

(test-case "d1/option-is-none"
  (define result
    (run-ns-last
     (string-append
      "(ns opt-t2)\n"
      "(require [prologos.data.option :refer [some none is-none]])\n"
      "(eval (is-none (none Nat)))")))
  (check-equal? result "true : Bool"))

(test-case "d1/option-flatten"
  (define result
    (run-ns-last
     (string-append
      "(ns opt-t3)\n"
      "(require [prologos.data.option :refer [Option some none flatten]])\n"
      "(eval (flatten (some (Option Nat) (some Nat zero))))")))
  (check-true (string-contains? result "some"))
  (check-true (string-contains? result "zero")))

(test-case "d1/result-is-ok"
  (define result
    (run-ns-last
     (string-append
      "(ns res-t1)\n"
      "(require [prologos.data.result :refer [ok err is-ok]])\n"
      "(eval (is-ok (ok Nat Bool zero)))")))
  (check-equal? result "true : Bool"))

(test-case "d1/result-is-err"
  (define result
    (run-ns-last
     (string-append
      "(ns res-t2)\n"
      "(require [prologos.data.result :refer [ok err is-err]])\n"
      "(eval (is-err (err Nat Bool true)))")))
  (check-equal? result "true : Bool"))

(test-case "d1/result-to-option"
  (define result
    (run-ns-last
     (string-append
      "(ns res-t3)\n"
      "(require [prologos.data.result :refer [ok err to-option]])\n"
      "(eval (to-option (ok Nat Bool (inc zero))))")))
  (check-true (string-contains? result "some")))

(test-case "d1/pair-dup"
  (define result
    (run-ns-last
     (string-append
      "(ns pair-t1)\n"
      "(require [prologos.data.pair :refer [dup]])\n"
      "(eval (first (dup Nat zero)))")))
  (check-equal? result "zero : Nat"))

(test-case "d1/pair-uncurry"
  (define result
    (run-ns-last
     (string-append
      "(ns pair-t2)\n"
      "(require [prologos.data.nat :refer [add]])\n"
      "(require [prologos.data.pair :refer [uncurry]])\n"
      "(eval (uncurry add (pair (inc zero) (inc (inc zero)))))")))
  (check-equal? result "3 : Nat"))

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
      "(eval (Nat--Stringify--show (inc (inc zero))))")))
  (check-equal? result "2 : Nat"))

(test-case "ws/trait-accessor-projects-correctly"
  ;; Single-method: accessor is identity, so accessor applied to dict = dict
  (define result
    (run-ns-last
     (string-append
      "(ns ws-t3)\n"
      "(trait (Stringify (A : (Type 0))) (show : A -> Nat))\n"
      "(impl Stringify Nat (defn show (x : Nat) : Nat x))\n"
      ;; Accessor should work on the dict
      "(eval (Stringify-show Nat Nat--Stringify--dict (inc (inc (inc zero)))))")))
  (check-equal? result "3 : Nat"))

;; ========================================
;; Phase A.2: Impl Declarations — Macro Level
;; ========================================

(test-case "impl/single-method-generates-dict"
  ;; impl for a single-method trait produces a dict def
  (parameterize ([current-preparse-registry (current-preparse-registry)]
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
  (parameterize ([current-preparse-registry (current-preparse-registry)]
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
  (parameterize ([current-preparse-registry (current-preparse-registry)]
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
  (parameterize ([current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)]
                 [current-impl-registry (hasheq)])
    (check-exn
     exn:fail?
     (lambda ()
       (process-impl '(impl Unknown Nat (defn foo (x : Nat) : Nat x)))))))

(test-case "impl/error-wrong-method-count"
  ;; impl with wrong number of methods
  (parameterize ([current-preparse-registry (current-preparse-registry)]
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
  (parameterize ([current-preparse-registry (current-preparse-registry)]
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
  (parameterize ([current-preparse-registry (current-preparse-registry)]
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
  (parameterize ([current-preparse-registry (current-preparse-registry)]
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
      "(require [prologos.core.eq-trait :refer [nat-eq]])\n"
      "(eval (nat-eq zero zero))")))
  (check-equal? result "true : Bool"))

(test-case "d2/eq-trait-neq-works"
  (define result
    (run-ns-last
     (string-append
      "(ns d2t2)\n"
      "(require [prologos.core.eq-trait :refer [nat-eq eq-neq]])\n"
      "(eval (eq-neq Nat nat-eq (inc zero) (inc (inc zero))))")))
  (check-equal? result "true : Bool"))

(test-case "d2/ord-trait-loads-via-trait-syntax"
  ;; ord-trait.prologos now uses trait/impl syntax
  (define result
    (run-ns-last
     (string-append
      "(ns d2t3)\n"
      "(require [prologos.core.ord-trait :refer [nat-ord ord-lt]])\n"
      "(eval (ord-lt Nat nat-ord (inc zero) (inc (inc (inc zero)))))")))
  (check-equal? result "true : Bool"))

(test-case "d2/ord-min-works"
  (define result
    (run-ns-last
     (string-append
      "(ns d2t4)\n"
      "(require [prologos.core.ord-trait :refer [nat-ord ord-min]])\n"
      "(eval (ord-min Nat nat-ord (inc (inc (inc zero))) (inc zero)))")))
  (check-equal? result "1 : Nat"))

(test-case "d2/eq-dict-is-callable"
  ;; The dict itself should be the eq? function (single-method trait)
  (define result
    (run-ns-last
     (string-append
      "(ns d2t5)\n"
      "(require [prologos.core.eq-trait :refer [Nat--Eq--dict]])\n"
      "(eval (Nat--Eq--dict (inc (inc zero)) (inc (inc zero))))")))
  (check-equal? result "true : Bool"))

(test-case "d2/ord-dict-is-callable"
  ;; The dict itself should be the compare function (single-method trait)
  (define result
    (run-ns-last
     (string-append
      "(ns d2t6)\n"
      "(require [prologos.core.ord-trait :refer [Nat--Ord--dict]])\n"
      "(require [prologos.data.ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n"
      "(eval (the Nat (match (Nat--Ord--dict (inc zero) (inc (inc zero))) (lt-ord -> zero) (eq-ord -> (inc zero)) (gt-ord -> (inc (inc zero))))))")))
  (check-equal? result "zero : Nat"))

;; ========================================
;; Phase C.1: Functor and Foldable Traits
;; ========================================

(test-case "c1/functor-list-double"
  ;; list-functor double [1, 2, 3] = [2, 4, 6]
  (define result
    (run-ns-last
     (string-append
      "(ns c1t1)\n"
      "(require [prologos.core.functor-list :refer [list-functor]])\n"
      "(require [prologos.data.list :refer [List nil cons]])\n"
      "(require [prologos.data.nat :refer [double]])\n"
      "(eval (list-functor Nat Nat double (cons Nat (inc zero) (cons Nat (inc (inc zero)) (cons Nat (inc (inc (inc zero))) (nil Nat))))))")))
  (check-equal? result "'[2 4 6] : [prologos.data.list::List Nat]"))

(test-case "c1/functor-list-empty"
  ;; list-functor double [] = []
  (define result
    (run-ns-last
     (string-append
      "(ns c1t2)\n"
      "(require [prologos.core.functor-list :refer [list-functor]])\n"
      "(require [prologos.data.list :refer [List nil]])\n"
      "(require [prologos.data.nat :refer [double]])\n"
      "(eval (list-functor Nat Nat double (nil Nat)))")))
  (check-equal? result "[prologos.data.list::nil Nat] : [prologos.data.list::List Nat]"))

(test-case "c1/functor-list-type-change"
  ;; list-functor zero? [0, 1, 2] = [true, false, false]
  (define result
    (run-ns-last
     (string-append
      "(ns c1t3)\n"
      "(require [prologos.core.functor-list :refer [list-functor]])\n"
      "(require [prologos.data.list :refer [List nil cons]])\n"
      "(require [prologos.data.nat :refer [zero?]])\n"
      "(eval (list-functor Nat Bool zero? (cons Nat zero (cons Nat (inc zero) (cons Nat (inc (inc zero)) (nil Nat))))))")))
  (check-equal? result "'[true false false] : [prologos.data.list::List Bool]"))

(test-case "c1/foldable-list-sum"
  ;; list-foldable add 0 [1, 2, 3] = 6
  (define result
    (run-ns-last
     (string-append
      "(ns c1t4)\n"
      "(require [prologos.core.foldable-list :refer [list-foldable]])\n"
      "(require [prologos.data.list :refer [List nil cons]])\n"
      "(require [prologos.data.nat :refer [add]])\n"
      "(eval (list-foldable Nat Nat add zero (cons Nat (inc zero) (cons Nat (inc (inc zero)) (cons Nat (inc (inc (inc zero))) (nil Nat))))))")))
  (check-equal? result "6 : Nat"))

(test-case "c1/foldable-list-empty"
  ;; list-foldable add 0 [] = 0
  (define result
    (run-ns-last
     (string-append
      "(ns c1t5)\n"
      "(require [prologos.core.foldable-list :refer [list-foldable]])\n"
      "(require [prologos.data.list :refer [List nil]])\n"
      "(require [prologos.data.nat :refer [add]])\n"
      "(eval (list-foldable Nat Nat add zero (nil Nat)))")))
  (check-equal? result "zero : Nat"))

(test-case "c1/foldable-list-count"
  ;; Count elements: foldr (\_ n -> inc n) 0 [a, b, c] = 3
  (define result
    (run-ns-last
     (string-append
      "(ns c1t6)\n"
      "(require [prologos.core.foldable-list :refer [list-foldable]])\n"
      "(require [prologos.data.list :refer [List nil cons]])\n"
      "(eval (list-foldable Nat Nat (fn (_ : Nat) (fn (n : Nat) (inc n))) zero (cons Nat (inc zero) (cons Nat (inc (inc zero)) (cons Nat (inc (inc (inc zero))) (nil Nat))))))")))
  (check-equal? result "3 : Nat"))

(test-case "c1/functor-type-check"
  ;; list-functor : Functor List
  (define result
    (run-ns-last
     (string-append
      "(ns c1t7)\n"
      "(require [prologos.core.functor-list :refer [list-functor]])\n"
      "(require [prologos.core.functor-trait :refer [Functor]])\n"
      "(require [prologos.data.list :refer [List]])\n"
      "(check list-functor : (Functor List))")))
  (check-equal? result "OK"))

;; ========================================
;; Phase C.2: Seq Trait and List Instance
;; ========================================

(test-case "c2/seq-trait-loads"
  ;; Just loading seq-trait should succeed
  (define result
    (run-ns-last
     (string-append
      "(ns c2t1)\n"
      "(require [prologos.core.seq-trait :refer [Seq seq-first seq-rest seq-empty?]])\n"
      "(infer seq-first)")))
  ;; Should be a Pi type
  (check-true (string-contains? result "Pi")))

(test-case "c2/seq-list-loads"
  ;; Loading seq-list should succeed and list-seq has a Sigma type
  (define result
    (run-ns-last
     (string-append
      "(ns c2t2)\n"
      "(require [prologos.core.seq-list :refer [list-seq]])\n"
      "(infer list-seq)")))
  ;; list-seq should have a Sigma type (the Seq dictionary)
  (check-true (string-contains? result "Sigma")))

(test-case "c2/seq-first-list"
  ;; seq-first on a non-empty list gives some
  (define result
    (run-ns-last
     (string-append
      "(ns c2t3)\n"
      "(require [prologos.core.seq-trait :refer [seq-first]])\n"
      "(require [prologos.core.seq-list :refer [list-seq]])\n"
      "(require [prologos.data.list :refer [cons nil]])\n"
      "(eval (seq-first list-seq (cons Nat (inc zero) (cons Nat zero (nil Nat)))))")))
  (check-equal? result "[prologos.data.option::some Nat 1] : [prologos.data.option::Option Nat]"))

(test-case "c2/seq-first-empty"
  ;; seq-first on empty list gives none
  (define result
    (run-ns-last
     (string-append
      "(ns c2t4)\n"
      "(require [prologos.core.seq-trait :refer [seq-first]])\n"
      "(require [prologos.core.seq-list :refer [list-seq]])\n"
      "(require [prologos.data.list :refer [nil]])\n"
      "(eval (seq-first list-seq (nil Nat)))")))
  (check-equal? result "[prologos.data.option::none Nat] : [prologos.data.option::Option Nat]"))

(test-case "c2/seq-rest-list"
  ;; seq-rest on [1, 0] gives [0]
  (define result
    (run-ns-last
     (string-append
      "(ns c2t5)\n"
      "(require [prologos.core.seq-trait :refer [seq-rest]])\n"
      "(require [prologos.core.seq-list :refer [list-seq]])\n"
      "(require [prologos.data.list :refer [cons nil]])\n"
      "(eval (seq-rest list-seq (cons Nat (inc zero) (cons Nat zero (nil Nat)))))")))
  (check-equal? result "'[zero] : [prologos.data.list::List Nat]"))

(test-case "c2/seq-empty-false"
  ;; seq-empty? on non-empty list gives false
  (define result
    (run-ns-last
     (string-append
      "(ns c2t6)\n"
      "(require [prologos.core.seq-trait :refer [seq-empty?]])\n"
      "(require [prologos.core.seq-list :refer [list-seq]])\n"
      "(require [prologos.data.list :refer [cons nil]])\n"
      "(eval (seq-empty? list-seq (cons Nat zero (nil Nat))))")))
  (check-equal? result "false : Bool"))

(test-case "c2/seq-empty-true"
  ;; seq-empty? on empty list gives true
  (define result
    (run-ns-last
     (string-append
      "(ns c2t7)\n"
      "(require [prologos.core.seq-trait :refer [seq-empty?]])\n"
      "(require [prologos.core.seq-list :refer [list-seq]])\n"
      "(require [prologos.data.list :refer [nil]])\n"
      "(eval (seq-empty? list-seq (nil Nat)))")))
  (check-equal? result "true : Bool"))

;; --- Generic seq-functions ---

(test-case "c2/seq-length"
  (define result
    (run-ns-last
     (string-append
      "(ns c2t8)\n"
      "(require [prologos.core.seq-functions :refer [seq-length]])\n"
      "(require [prologos.core.seq-list :refer [list-seq]])\n"
      "(require [prologos.data.list :refer [cons nil]])\n"
      "(eval (seq-length list-seq (cons Nat (inc zero) (cons Nat (inc (inc zero)) (cons Nat (inc (inc (inc zero))) (nil Nat))))))")))
  (check-equal? result "3 : Nat"))

(test-case "c2/seq-length-empty"
  (define result
    (run-ns-last
     (string-append
      "(ns c2t9)\n"
      "(require [prologos.core.seq-functions :refer [seq-length]])\n"
      "(require [prologos.core.seq-list :refer [list-seq]])\n"
      "(require [prologos.data.list :refer [nil]])\n"
      "(eval (seq-length list-seq (nil Nat)))")))
  (check-equal? result "zero : Nat"))

(test-case "c2/seq-drop"
  (define result
    (run-ns-last
     (string-append
      "(ns c2t10)\n"
      "(require [prologos.core.seq-functions :refer [seq-drop]])\n"
      "(require [prologos.core.seq-list :refer [list-seq]])\n"
      "(require [prologos.data.list :refer [cons nil]])\n"
      "(eval (seq-drop list-seq (inc zero) (cons Nat (inc zero) (cons Nat (inc (inc zero)) (cons Nat (inc (inc (inc zero))) (nil Nat))))))")))
  (check-equal? result "'[2 3] : [prologos.data.list::List Nat]"))

(test-case "c2/seq-any-true"
  (define result
    (run-ns-last
     (string-append
      "(ns c2t11)\n"
      "(require [prologos.core.seq-functions :refer [seq-any?]])\n"
      "(require [prologos.core.seq-list :refer [list-seq]])\n"
      "(require [prologos.data.list :refer [cons nil]])\n"
      "(require [prologos.data.nat :refer [zero?]])\n"
      "(eval (seq-any? list-seq zero? (cons Nat (inc zero) (cons Nat zero (nil Nat)))))")))
  (check-equal? result "true : Bool"))

(test-case "c2/seq-any-false"
  (define result
    (run-ns-last
     (string-append
      "(ns c2t12)\n"
      "(require [prologos.core.seq-functions :refer [seq-any?]])\n"
      "(require [prologos.core.seq-list :refer [list-seq]])\n"
      "(require [prologos.data.list :refer [cons nil]])\n"
      "(require [prologos.data.nat :refer [zero?]])\n"
      "(eval (seq-any? list-seq zero? (cons Nat (inc zero) (cons Nat (inc (inc zero)) (nil Nat)))))")))
  (check-equal? result "false : Bool"))

(test-case "c2/seq-all-true"
  (define result
    (run-ns-last
     (string-append
      "(ns c2t13)\n"
      "(require [prologos.core.seq-functions :refer [seq-all?]])\n"
      "(require [prologos.core.seq-list :refer [list-seq]])\n"
      "(require [prologos.data.list :refer [cons nil]])\n"
      "(require [prologos.data.nat :refer [zero?]])\n"
      "(eval (seq-all? list-seq zero? (cons Nat zero (cons Nat zero (nil Nat)))))")))
  (check-equal? result "true : Bool"))

(test-case "c2/seq-all-false"
  (define result
    (run-ns-last
     (string-append
      "(ns c2t14)\n"
      "(require [prologos.core.seq-functions :refer [seq-all?]])\n"
      "(require [prologos.core.seq-list :refer [list-seq]])\n"
      "(require [prologos.data.list :refer [cons nil]])\n"
      "(require [prologos.data.nat :refer [zero?]])\n"
      "(eval (seq-all? list-seq zero? (cons Nat zero (cons Nat (inc zero) (nil Nat)))))")))
  (check-equal? result "false : Bool"))

(test-case "c2/seq-find-found"
  (define result
    (run-ns-last
     (string-append
      "(ns c2t15)\n"
      "(require [prologos.core.seq-functions :refer [seq-find]])\n"
      "(require [prologos.core.seq-list :refer [list-seq]])\n"
      "(require [prologos.data.list :refer [cons nil]])\n"
      "(require [prologos.data.nat :refer [zero?]])\n"
      "(eval (seq-find list-seq zero? (cons Nat (inc zero) (cons Nat zero (nil Nat)))))")))
  (check-equal? result "[prologos.data.option::some Nat zero] : [prologos.data.option::Option Nat]"))

(test-case "c2/seq-find-not-found"
  (define result
    (run-ns-last
     (string-append
      "(ns c2t16)\n"
      "(require [prologos.core.seq-functions :refer [seq-find]])\n"
      "(require [prologos.core.seq-list :refer [list-seq]])\n"
      "(require [prologos.data.list :refer [cons nil]])\n"
      "(require [prologos.data.nat :refer [zero?]])\n"
      "(eval (seq-find list-seq zero? (cons Nat (inc zero) (cons Nat (inc (inc zero)) (nil Nat)))))")))
  (check-equal? result "[prologos.data.option::none Nat] : [prologos.data.option::Option Nat]"))

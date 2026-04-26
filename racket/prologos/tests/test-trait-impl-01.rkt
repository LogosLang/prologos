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
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
    (process-string s)))

(define (run-first s) (car (run s)))

(define (run-ns s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry])
    (install-module-loader!)
    (process-string s)))

(define (run-ns-last s) (last (run-ns s)))


;; ========================================
;; Phase A.1: Trait Declarations — Macro Level
;; ========================================

(test-case "trait/parse-single-method"
  ;; (trait (Showable (A : (Type 0))) (show : A -> Nat))
  ;; Should register trait and produce accessor defs
  (parameterize ([current-preparse-registry prelude-preparse-registry]
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
  (parameterize ([current-preparse-registry prelude-preparse-registry]
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
  (parameterize ([current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry (hasheq)])
    (process-trait '(trait (Showable (A : (Type 0))) (show : A -> Nat)))
    ;; The deftype should have been registered. Verify by expanding it.
    (define expanded (preparse-expand-form '(Showable Nat)))
    ;; Should expand to (-> Nat Nat) — the method type with A=Nat
    (check-equal? expanded '(-> Nat Nat))))


(test-case "trait/multi-method-deftype-is-sigma"
  ;; Multi-method: dictionary type is nested Sigma
  (parameterize ([current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry (hasheq)])
    (process-trait '(trait (Eq (A : (Type 0))) (== : A -> A -> Bool) (/= : A -> A -> Bool)))
    (define expanded (preparse-expand-form '(Eq Nat)))
    ;; Should expand to (Sigma (_ : (-> Nat (-> Nat Bool))) (-> Nat (-> Nat Bool)))
    (check-equal? expanded '(Sigma (_ : (-> Nat (-> Nat Bool))) (-> Nat (-> Nat Bool))))))


(test-case "trait/brace-params-syntax"
  ;; WS-style: (trait Eq ($brace-params A) (== : A -> A -> Bool))
  (parameterize ([current-preparse-registry prelude-preparse-registry]
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
  (parameterize ([current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry (hasheq)])
    (define defs
      (process-trait '(trait Convertible ($brace-params A B)
                        (convert : A -> B))))
    (check-equal? (length defs) 1)
    (define tm (lookup-trait 'Convertible))
    (check-equal? (length (trait-meta-params tm)) 2)))


(test-case "trait/accessor-body-single-method"
  ;; Single-method accessor body: outer lambda for type param, inner for dict
  (parameterize ([current-preparse-registry prelude-preparse-registry]
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
  ;; Multi-method: first accessor should project via (fst dict)
  (parameterize ([current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry (hasheq)])
    (define defs
      (process-trait '(trait (Eq (A : (Type 0))) (== : A -> A -> Bool) (/= : A -> A -> Bool))))
    (define acc1 (car defs))
    (define body1 (last acc1))
    ;; body is (fn (A :0 (Type 0)) (fn (dict ...) (fst dict)))
    (define inner1 (caddr body1))
    (check-equal? (caddr inner1) '(fst dict))))


(test-case "trait/accessor-body-multi-method-second"
  ;; Multi-method: second accessor should project via (snd dict)
  (parameterize ([current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry (hasheq)])
    (define defs
      (process-trait '(trait (Eq (A : (Type 0))) (== : A -> A -> Bool) (/= : A -> A -> Bool))))
    (define acc2 (second defs))
    (define body2 (last acc2))
    ;; body is (fn (A :0 (Type 0)) (fn (dict ...) (snd dict)))
    (define inner2 (caddr body2))
    (check-equal? (caddr inner2) '(snd dict))))


(test-case "trait/three-methods-sigma-nesting"
  ;; Three methods: (Sigma (_ T1) (Sigma (_ T2) T3))
  (parameterize ([current-preparse-registry prelude-preparse-registry]
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
  (parameterize ([current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry (hasheq)])
    (define defs
      (process-trait '(trait (Arith (A : (Type 0)))
                        (add-a : A -> A -> A)
                        (sub-a : A -> A -> A)
                        (neg-a : A -> A -> A))))
    ;; Each body is (fn (A :0 (Type 0)) (fn (dict ...) projection))
    ;; 1st: (fst dict)
    (check-equal? (caddr (caddr (last (first defs)))) '(fst dict))
    ;; 2nd: (fst (snd dict))
    (check-equal? (caddr (caddr (last (second defs)))) '(fst (snd dict)))
    ;; 3rd: (snd (snd dict))
    (check-equal? (caddr (caddr (last (third defs)))) '(snd (snd dict)))))


(test-case "trait/error-no-methods"
  ;; Trait with no methods should error
  (parameterize ([current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry (hasheq)])
    (check-exn
     exn:fail?
     (lambda ()
       (process-trait '(trait (Empty (A : (Type 0)))))))))


(test-case "trait/error-bad-method"
  ;; Method without type annotation should error
  (parameterize ([current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry (hasheq)])
    (check-exn
     exn:fail?
     (lambda ()
       (process-trait '(trait (Bad (A : (Type 0))) (foo)))))))


(test-case "trait/preparse-expand-all-integration"
  ;; Verify trait is handled by preparse-expand-all
  (parameterize ([current-preparse-registry prelude-preparse-registry]
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
      "(eval (nat-show (suc (suc zero))))")))
  (check-equal? result "2N : Nat"))


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
      "(eval ((fst nat-eq2) zero zero))")))
  (check-equal? result "true : Bool"))

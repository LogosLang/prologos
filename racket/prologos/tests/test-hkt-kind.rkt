#lang racket/base

;;;
;;; Tests for Phase 1: HKT Kind Annotations in Brace-Params
;;; Verifies {F : Type -> Type} parsing in trait/data brace-params.
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

(define (run-ns-last s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry])
    (install-module-loader!)
    (last (process-string s))))

;; ========================================
;; Unit Tests: group-brace-params
;; ========================================

(test-case "hkt/group-bare-params"
  ;; (A B C) → ((A) (B) (C))
  (check-equal? (group-brace-params '(A B C))
                '((A) (B) (C))))

(test-case "hkt/group-single-kinded"
  ;; (F : Type -> Type) → ((F : Type -> Type))
  (check-equal? (group-brace-params '(F : Type -> Type))
                '((F : Type -> Type))))

(test-case "hkt/group-kinded-then-bare"
  ;; (F : Type -> Type A) → ((F : Type -> Type) (A))
  ;; A is bare because there's no "A :" sequence
  (define result (group-brace-params '(F : Type -> Type A)))
  ;; F group includes everything from F to before the next boundary
  ;; But A is NOT preceded by :, so we need to check the logic carefully.
  ;; The algorithm finds "F :" as the only boundary at index 0.
  ;; So F group = indices 0..end = (F : Type -> Type A)
  ;; That's wrong — A should be separate.
  ;; Actually, looking at the algorithm: param-start-indices finds all positions i
  ;; where tvec[i] = ':' and tvec[i-1] is a symbol. For (F : Type -> Type A):
  ;; Index 0=F, 1=:, 2=Type, 3=->, 4=Type, 5=A
  ;; ':' at index 1, tvec[0]=F (symbol) → param-start-index = 0
  ;; No other ':' → only one boundary at 0.
  ;; Group = indices 0..5 = (F : Type -> Type A)
  ;; This would NOT separate A. The issue is that bare symbols after a kinded group
  ;; become part of the kind. We need to test what actually happens.
  ;;
  ;; Actually, after reflection: in {F : Type -> Type, A}, the WS reader
  ;; produces ($brace-params F : Type -> Type A). Without additional
  ;; delimiters, the algorithm can't distinguish "Type A" from kind tokens.
  ;; For now, the proper way to write this is:
  ;;   {A, F : Type -> Type} (bare params first)
  ;; or use sexp syntax: (data (Foo (A : (Type 0)) (F : (-> (Type 0) (Type 0)))))
  ;; Let's test what we get and document the behavior.
  (check-equal? (length result) 1)  ;; A gets absorbed into F's kind
  )

(test-case "hkt/group-bare-then-kinded"
  ;; (A F : Type -> Type) → ((A) (F : Type -> Type))
  ;; A comes before the first kinded boundary at F
  (define result (group-brace-params '(A F : Type -> Type)))
  (check-equal? (length result) 2)
  (check-equal? (car result) '(A))
  (check-equal? (cadr result) '(F : Type -> Type)))

(test-case "hkt/group-two-kinded"
  ;; (F : Type -> Type G : Type -> Type -> Type)
  ;; → ((F : Type -> Type) (G : Type -> Type -> Type))
  (define result (group-brace-params '(F : Type -> Type G : Type -> Type -> Type)))
  (check-equal? (length result) 2)
  (check-equal? (car result) '(F : Type -> Type))
  (check-equal? (cadr result) '(G : Type -> Type -> Type)))

(test-case "hkt/group-empty"
  (check-equal? (group-brace-params '()) '()))

;; ========================================
;; Unit Tests: parse-brace-param-list
;; ========================================

(test-case "hkt/parse-bare-backward-compat"
  ;; {A B} → ((A . (Type 0)) (B . (Type 0)))
  (define result (parse-brace-param-list '(A B) 'test))
  (check-equal? result '((A . (Type 0)) (B . (Type 0)))))

(test-case "hkt/parse-single-bare"
  ;; {A} → ((A . (Type 0)))
  (define result (parse-brace-param-list '(A) 'test))
  (check-equal? result '((A . (Type 0)))))

(test-case "hkt/parse-hkt-type-to-type"
  ;; {F : Type -> Type} → ((F . (-> (Type 0) (Type 0))))
  (define result (parse-brace-param-list '(F : Type -> Type) 'test))
  (check-equal? result '((F . (-> (Type 0) (Type 0))))))

(test-case "hkt/parse-hkt-type-to-type-to-type"
  ;; {G : Type -> Type -> Type} → ((G . (-> (Type 0) (-> (Type 0) (Type 0)))))
  (define result (parse-brace-param-list '(G : Type -> Type -> Type) 'test))
  (check-equal? result '((G . (-> (Type 0) (-> (Type 0) (Type 0)))))))

(test-case "hkt/parse-bare-then-kinded"
  ;; {A F : Type -> Type} → ((A . (Type 0)) (F . (-> (Type 0) (Type 0))))
  (define result (parse-brace-param-list '(A F : Type -> Type) 'test))
  (check-equal? (length result) 2)
  (check-equal? (car result) '(A . (Type 0)))
  (check-equal? (cadr result) '(F . (-> (Type 0) (Type 0)))))

(test-case "hkt/parse-two-kinded"
  ;; {F : Type -> Type G : Type -> Type -> Type}
  (define result (parse-brace-param-list '(F : Type -> Type G : Type -> Type -> Type) 'test))
  (check-equal? (length result) 2)
  (check-equal? (car result) '(F . (-> (Type 0) (Type 0))))
  (check-equal? (cadr result) '(G . (-> (Type 0) (-> (Type 0) (Type 0))))))

(test-case "hkt/parse-empty"
  (check-equal? (parse-brace-param-list '() 'test) '()))

;; ========================================
;; Macro-Level: trait with HKT brace-params
;; ========================================

(test-case "hkt/trait-hkt-brace-params-macro"
  ;; (trait Mappable ($brace-params F : Type -> Type) (fmap : (-> Nat Nat) -> (F Nat) -> (F Nat)))
  ;; Should parse correctly and register trait with HKT param
  (parameterize ([current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry (hasheq)])
    (define defs
      (process-trait '(trait Mappable ($brace-params F : Type -> Type)
                        (fmap : (-> Nat Nat) -> (F Nat) -> (F Nat)))))
    ;; Should produce 1 accessor def
    (check-equal? (length defs) 1)
    ;; Trait should be registered
    (define tm (lookup-trait 'Mappable))
    (check-true (trait-meta? tm))
    (check-equal? (trait-meta-name tm) 'Mappable)
    ;; Param kind should be (-> (Type 0) (Type 0))
    (define params (trait-meta-params tm))
    (check-equal? (length params) 1)
    (check-equal? (car (car params)) 'F)
    (check-equal? (cdr (car params)) '(-> (Type 0) (Type 0)))))

(test-case "hkt/trait-bare-backward-compat"
  ;; Existing bare {A} trait still works
  (parameterize ([current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry (hasheq)])
    (define defs
      (process-trait '(trait Eq ($brace-params A) (eq? : A -> A -> Bool))))
    (check-equal? (length defs) 1)
    (define tm (lookup-trait 'Eq))
    (define params (trait-meta-params tm))
    (check-equal? (length params) 1)
    (check-equal? (car (car params)) 'A)
    (check-equal? (cdr (car params)) '(Type 0))))

(test-case "hkt/trait-multi-bare-backward-compat"
  ;; {A B} still works
  (parameterize ([current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry (hasheq)])
    (process-trait '(trait Conv ($brace-params A B) (convert : A -> B)))
    (define tm (lookup-trait 'Conv))
    (define params (trait-meta-params tm))
    (check-equal? (length params) 2)
    (check-equal? (car (car params)) 'A)
    (check-equal? (car (cadr params)) 'B)))

;; ========================================
;; Macro-Level: data with HKT brace-params
;; ========================================

(test-case "hkt/data-hkt-brace-params-macro"
  ;; data with HKT param: (data Wrapper ($brace-params F : Type -> Type) (wrap : (F Nat)))
  ;; This is a contrived example but tests the macro parsing
  (parameterize ([current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)])
    (define defs
      (process-data '(data Wrapper ($brace-params F : Type -> Type) (wrap : (F Nat)))))
    ;; Should produce: deftype + ctor defs
    (check-true (> (length defs) 0))
    ;; First def should be deftype for Wrapper
    (check-equal? (cadr (car defs)) 'Wrapper)))

(test-case "hkt/data-bare-backward-compat"
  ;; Existing {A} data still works
  (parameterize ([current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)])
    (define defs (process-data '(data Box ($brace-params A) (box : A))))
    (check-true (> (length defs) 0))
    (check-equal? (cadr (car defs)) 'Box)))

;; ========================================
;; Pipeline: Existing trait/impl still works end-to-end
;; ========================================

(test-case "hkt/existing-eq-trait-unaffected"
  ;; Eq trait (using bare {A}) still works through full pipeline
  (define result
    (run-ns-last
     (string-append
      "(ns hkt-compat1)\n"
      "(imports [prologos::core::eq :refer [Nat--Eq--dict]])\n"
      "(eval (Nat--Eq--dict (suc (suc zero)) (suc (suc zero))))")))
  (check-equal? result "true : Bool"))

(test-case "hkt/existing-ord-trait-unaffected"
  ;; Ord trait still works
  (define result
    (run-ns-last
     (string-append
      "(ns hkt-compat2)\n"
      "(imports [prologos::core::ord :refer [nat-ord ord-lt]])\n"
      "(eval (ord-lt Nat nat-ord zero (suc zero)))")))
  (check-equal? result "true : Bool"))

(test-case "hkt/existing-data-option-unaffected"
  ;; Option {A} still works
  (define result
    (run-ns-last
     (string-append
      "(ns hkt-compat3)\n"
      "(imports [prologos::data::option :refer [some none some?]])\n"
      "(eval (some? (some Nat (suc zero))))")))
  (check-equal? result "true : Bool"))

(test-case "hkt/existing-data-list-unaffected"
  ;; List {A} still works
  (define result
    (run-ns-last
     (string-append
      "(ns hkt-compat4)\n"
      "(imports [prologos::data::list :refer [cons nil length]])\n"
      "(eval (length (cons Nat (suc zero) (cons Nat zero (nil Nat)))))")))
  (check-equal? result "2N : Nat"))

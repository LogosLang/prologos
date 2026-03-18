#lang racket/base

;;;
;;; Tests for prologos trait and pattern matching features:
;;;   match, Eq trait, Ord trait, elem, recursive-defn,
;;;   native constructors, implicit arguments, structural PM.
;;;
;;; Split from test-stdlib.rkt (part 2 of 3)
;;;

(require rackunit
         racket/path
         racket/string
         racket/list
         "test-support.rkt"
         "../driver.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../macros.rkt")

;; Helper: run prologos code with namespace system active
(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)])
    (install-module-loader!)
    (process-string s)))

;; Helper: run two prologos module strings sequentially,
;; sharing the module registry so the second can require the first.
;; Returns the results from the second module.
(define (run-ns-pair s1 s2)
  (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)])
    (install-module-loader!)
    ;; Process the first module (sets up ns-context, registers module)
    (process-string s1)
    ;; Capture the module info from the first module's namespace
    (let ([ctx (current-ns-context)])
      (when ctx
        (let* ([ns-sym (ns-context-current-ns ctx)]
               [exports (cond
                          [(not (null? (ns-context-exports ctx)))
                           (ns-context-exports ctx)]
                          [(not (null? (ns-context-auto-exports ctx)))
                           (reverse (ns-context-auto-exports ctx))]
                          [else '()])]
               [mi (module-info ns-sym exports (current-global-env) #f (hasheq) (hasheq) (hasheq) (hasheq) #f)])
          (register-module! ns-sym mi))))
    ;; Reset for second module
    (current-global-env (hasheq))
    (current-ns-context #f)
    (process-string s2)))


(test-case "list/head-nonempty"
  (check-equal?
   (last (run-ns "(ns lst15)\n(imports [prologos::data::list :refer [List nil cons head]])\n(eval (head Nat (suc (suc (suc zero))) (cons Nat (suc zero) (nil Nat))))"))
   "1N : Nat"))


(test-case "list/head-empty"
  ;; head returns default for empty list
  (check-equal?
   (last (run-ns "(ns lst16)\n(imports [prologos::data::list :refer [List nil head]])\n(eval (head Nat (suc (suc (suc zero))) (nil Nat)))"))
   "3N : Nat"))


(test-case "list/singleton"
  (check-equal?
   (last (run-ns "(ns lst17)\n(imports [prologos::data::list :refer [List singleton length]])\n(eval (length Nat (singleton Nat zero)))"))
   "1N : Nat"))


(test-case "list/singleton-head"
  (check-equal?
   (last (run-ns "(ns lst18)\n(imports [prologos::data::list :refer [List singleton head]])\n(eval (head Nat (suc (suc (suc zero))) (singleton Nat (suc (suc zero)))))"))
   "2N : Nat"))


;; ========================================
;; prologos::core::eq — Eq dictionary-passing
;; ========================================

(test-case "eq/nat-eq-same"
  ;; nat-eq 0 0 = true
  (check-equal?
   (last (run-ns "(ns eq1)\n(imports [prologos::core::eq :refer [nat-eq]])\n(eval (nat-eq zero zero))"))
   "true : Bool"))


(test-case "eq/nat-eq-same-nonzero"
  ;; nat-eq 3 3 = true
  (check-equal?
   (last (run-ns "(ns eq2)\n(imports [prologos::core::eq :refer [nat-eq]])\n(eval (nat-eq (suc (suc (suc zero))) (suc (suc (suc zero)))))"))
   "true : Bool"))


(test-case "eq/nat-eq-different"
  ;; nat-eq 2 3 = false
  (check-equal?
   (last (run-ns "(ns eq3)\n(imports [prologos::core::eq :refer [nat-eq]])\n(eval (nat-eq (suc (suc zero)) (suc (suc (suc zero)))))"))
   "false : Bool"))


(test-case "eq/nat-eq-zero-nonzero"
  ;; nat-eq 0 1 = false
  (check-equal?
   (last (run-ns "(ns eq4)\n(imports [prologos::core::eq :refer [nat-eq]])\n(eval (nat-eq zero (suc zero)))"))
   "false : Bool"))


(test-case "eq/nat-eq-type-check"
  ;; nat-eq : Nat -> Nat -> Bool (which is Eq Nat after deftype expansion)
  (check-equal?
   (last (run-ns "(ns eq5)\n(imports [prologos::core::eq :refer [nat-eq]])\n(check nat-eq : (-> Nat (-> Nat Bool)))"))
   "OK"))


(test-case "eq/eq-neq-same"
  ;; eq-neq nat-eq 3 3 = false (not equal → false)
  (check-equal?
   (last (run-ns "(ns eq6)\n(imports [prologos::core::eq :refer [nat-eq eq-neq]])\n(eval (eq-neq Nat nat-eq (suc (suc (suc zero))) (suc (suc (suc zero)))))"))
   "false : Bool"))


(test-case "eq/eq-neq-different"
  ;; eq-neq nat-eq 2 5 = true (not equal → true)
  (check-equal?
   (last (run-ns "(ns eq7)\n(imports [prologos::core::eq :refer [nat-eq eq-neq]])\n(eval (eq-neq Nat nat-eq (suc (suc zero)) (suc (suc (suc (suc (suc zero)))))))"))
   "true : Bool"))


(test-case "eq/eq-neq-type-check"
  ;; eq-neq : Pi(A :0 Type 0). (Eq A) -> A -> A -> Bool
  ;; After deftype expansion: (-> A (-> A Bool)) is Eq A
  (check-equal?
   (last (run-ns "(ns eq8)\n(imports [prologos::core::eq :refer [eq-neq]])\n(check eq-neq : (Pi (A :0 (Type 0)) (-> (-> A (-> A Bool)) (-> A (-> A Bool)))))"))
   "OK"))


;; ========================================
;; prologos::core::ord — Ord dictionary-passing
;; ========================================

(test-case "ord/nat-ord-lt"
  ;; nat-ord 2 5 → lt-ord → match to extract
  (check-equal?
   (last (run-ns "(ns ord1)\n(imports [prologos::core::ord :refer [nat-ord]])\n(imports [prologos::data::ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (the Nat (match (nat-ord (suc (suc zero)) (suc (suc (suc (suc (suc zero)))))) (lt-ord -> zero) (eq-ord -> (suc zero)) (gt-ord -> (suc (suc zero))))))"))
   "0N : Nat"))


(test-case "ord/nat-ord-eq"
  ;; nat-ord 3 3 → eq-ord → match to extract
  (check-equal?
   (last (run-ns "(ns ord2)\n(imports [prologos::core::ord :refer [nat-ord]])\n(imports [prologos::data::ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (the Nat (match (nat-ord (suc (suc (suc zero))) (suc (suc (suc zero)))) (lt-ord -> zero) (eq-ord -> (suc zero)) (gt-ord -> (suc (suc zero))))))"))
   "1N : Nat"))


(test-case "ord/nat-ord-gt"
  ;; nat-ord 5 2 → gt-ord → match to extract
  (check-equal?
   (last (run-ns "(ns ord3)\n(imports [prologos::core::ord :refer [nat-ord]])\n(imports [prologos::data::ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (the Nat (match (nat-ord (suc (suc (suc (suc (suc zero))))) (suc (suc zero))) (lt-ord -> zero) (eq-ord -> (suc zero)) (gt-ord -> (suc (suc zero))))))"))
   "2N : Nat"))


(test-case "ord/nat-ord-type-check"
  ;; nat-ord : Nat -> Nat -> Ordering (which is Ord Nat after deftype expansion)
  (check-equal?
   (last (run-ns "(ns ord4)\n(imports [prologos::core::ord :refer [nat-ord]])\n(imports [prologos::data::ordering :refer [Ordering]])\n(check nat-ord : (-> Nat (-> Nat Ordering)))"))
   "OK"))


;; --- Ord derived operations ---

(test-case "ord/ord-lt-true"
  ;; ord-lt nat-ord 2 5 = true
  (check-equal?
   (last (run-ns "(ns ol1)\n(imports [prologos::core::ord :refer [nat-ord ord-lt]])\n(eval (ord-lt Nat nat-ord (suc (suc zero)) (suc (suc (suc (suc (suc zero)))))))"))
   "true : Bool"))


(test-case "ord/ord-lt-false"
  ;; ord-lt nat-ord 5 2 = false
  (check-equal?
   (last (run-ns "(ns ol2)\n(imports [prologos::core::ord :refer [nat-ord ord-lt]])\n(eval (ord-lt Nat nat-ord (suc (suc (suc (suc (suc zero))))) (suc (suc zero))))"))
   "false : Bool"))


(test-case "ord/ord-le-eq"
  ;; ord-le nat-ord 3 3 = true
  (check-equal?
   (last (run-ns "(ns ol3)\n(imports [prologos::core::ord :refer [nat-ord ord-le]])\n(eval (ord-le Nat nat-ord (suc (suc (suc zero))) (suc (suc (suc zero)))))"))
   "true : Bool"))

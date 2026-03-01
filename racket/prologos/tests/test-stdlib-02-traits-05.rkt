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
               [mi (module-info ns-sym exports (current-global-env) #f (hasheq) (hasheq) (hasheq))])
          (register-module! ns-sym mi))))
    ;; Reset for second module
    (current-global-env (hasheq))
    (current-ns-context #f)
    (process-string s2)))


(test-case "ord/ord-le-lt"
  ;; ord-le nat-ord 2 5 = true
  (check-equal?
   (last (run-ns "(ns ol4)\n(require [prologos::core::ord :refer [nat-ord ord-le]])\n(eval (ord-le Nat nat-ord (suc (suc zero)) (suc (suc (suc (suc (suc zero)))))))"))
   "true : Bool"))


(test-case "ord/ord-le-gt"
  ;; ord-le nat-ord 5 2 = false
  (check-equal?
   (last (run-ns "(ns ol5)\n(require [prologos::core::ord :refer [nat-ord ord-le]])\n(eval (ord-le Nat nat-ord (suc (suc (suc (suc (suc zero))))) (suc (suc zero))))"))
   "false : Bool"))


(test-case "ord/ord-gt-true"
  ;; ord-gt nat-ord 5 2 = true
  (check-equal?
   (last (run-ns "(ns og1)\n(require [prologos::core::ord :refer [nat-ord ord-gt]])\n(eval (ord-gt Nat nat-ord (suc (suc (suc (suc (suc zero))))) (suc (suc zero))))"))
   "true : Bool"))


(test-case "ord/ord-gt-false"
  ;; ord-gt nat-ord 2 5 = false
  (check-equal?
   (last (run-ns "(ns og2)\n(require [prologos::core::ord :refer [nat-ord ord-gt]])\n(eval (ord-gt Nat nat-ord (suc (suc zero)) (suc (suc (suc (suc (suc zero)))))))"))
   "false : Bool"))


(test-case "ord/ord-ge-eq"
  ;; ord-ge nat-ord 3 3 = true
  (check-equal?
   (last (run-ns "(ns oge1)\n(require [prologos::core::ord :refer [nat-ord ord-ge]])\n(eval (ord-ge Nat nat-ord (suc (suc (suc zero))) (suc (suc (suc zero)))))"))
   "true : Bool"))


(test-case "ord/ord-ge-gt"
  ;; ord-ge nat-ord 5 2 = true
  (check-equal?
   (last (run-ns "(ns oge2)\n(require [prologos::core::ord :refer [nat-ord ord-ge]])\n(eval (ord-ge Nat nat-ord (suc (suc (suc (suc (suc zero))))) (suc (suc zero))))"))
   "true : Bool"))


(test-case "ord/ord-ge-lt"
  ;; ord-ge nat-ord 2 5 = false
  (check-equal?
   (last (run-ns "(ns oge3)\n(require [prologos::core::ord :refer [nat-ord ord-ge]])\n(eval (ord-ge Nat nat-ord (suc (suc zero)) (suc (suc (suc (suc (suc zero)))))))"))
   "false : Bool"))


(test-case "ord/ord-eq-same"
  ;; ord-eq nat-ord 3 3 = true
  (check-equal?
   (last (run-ns "(ns oeq1)\n(require [prologos::core::ord :refer [nat-ord ord-eq]])\n(eval (ord-eq Nat nat-ord (suc (suc (suc zero))) (suc (suc (suc zero)))))"))
   "true : Bool"))


(test-case "ord/ord-eq-different"
  ;; ord-eq nat-ord 2 5 = false
  (check-equal?
   (last (run-ns "(ns oeq2)\n(require [prologos::core::ord :refer [nat-ord ord-eq]])\n(eval (ord-eq Nat nat-ord (suc (suc zero)) (suc (suc (suc (suc (suc zero)))))))"))
   "false : Bool"))


(test-case "ord/ord-min"
  ;; ord-min nat-ord 2 5 = 2
  (check-equal?
   (last (run-ns "(ns om1)\n(require [prologos::core::ord :refer [nat-ord ord-min]])\n(eval (ord-min Nat nat-ord (suc (suc zero)) (suc (suc (suc (suc (suc zero)))))))"))
   "2N : Nat")
  ;; ord-min nat-ord 5 2 = 2
  (check-equal?
   (last (run-ns "(ns om2)\n(require [prologos::core::ord :refer [nat-ord ord-min]])\n(eval (ord-min Nat nat-ord (suc (suc (suc (suc (suc zero))))) (suc (suc zero))))"))
   "2N : Nat")
  ;; ord-min nat-ord 3 3 = 3
  (check-equal?
   (last (run-ns "(ns om3)\n(require [prologos::core::ord :refer [nat-ord ord-min]])\n(eval (ord-min Nat nat-ord (suc (suc (suc zero))) (suc (suc (suc zero)))))"))
   "3N : Nat"))


(test-case "ord/ord-max"
  ;; ord-max nat-ord 2 5 = 5
  (check-equal?
   (last (run-ns "(ns omx1)\n(require [prologos::core::ord :refer [nat-ord ord-max]])\n(eval (ord-max Nat nat-ord (suc (suc zero)) (suc (suc (suc (suc (suc zero)))))))"))
   "5N : Nat")
  ;; ord-max nat-ord 5 2 = 5
  (check-equal?
   (last (run-ns "(ns omx2)\n(require [prologos::core::ord :refer [nat-ord ord-max]])\n(eval (ord-max Nat nat-ord (suc (suc (suc (suc (suc zero))))) (suc (suc zero))))"))
   "5N : Nat")
  ;; ord-max nat-ord 3 3 = 3
  (check-equal?
   (last (run-ns "(ns omx3)\n(require [prologos::core::ord :refer [nat-ord ord-max]])\n(eval (ord-max Nat nat-ord (suc (suc (suc zero))) (suc (suc (suc zero)))))"))
   "3N : Nat"))


;; ========================================
;; Integration: List + Eq (elem)
;; ========================================

(test-case "elem/found"
  ;; 2 is in [1, 2, 3]
  (check-equal?
   (last (run-ns "(ns le1)\n(require [prologos::data::list :refer [List nil cons elem]])\n(require [prologos::core::eq :refer [nat-eq]])\n(eval (elem Nat nat-eq (suc (suc zero)) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))"))
   "true : Bool"))


(test-case "elem/not-found"
  ;; 5 is not in [1, 2, 3]
  (check-equal?
   (last (run-ns "(ns le2)\n(require [prologos::data::list :refer [List nil cons elem]])\n(require [prologos::core::eq :refer [nat-eq]])\n(eval (elem Nat nat-eq (suc (suc (suc (suc (suc zero))))) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))"))
   "false : Bool"))


(test-case "elem/empty-list"
  ;; Any element not in []
  (check-equal?
   (last (run-ns "(ns le3)\n(require [prologos::data::list :refer [List nil elem]])\n(require [prologos::core::eq :refer [nat-eq]])\n(eval (elem Nat nat-eq zero (nil Nat)))"))
   "false : Bool"))


(test-case "elem/first-element"
  ;; 0 is first in [0, 1, 2]
  (check-equal?
   (last (run-ns "(ns le4)\n(require [prologos::data::list :refer [List nil cons elem]])\n(require [prologos::core::eq :refer [nat-eq]])\n(eval (elem Nat nat-eq zero (cons Nat zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))))))"))
   "true : Bool"))


(test-case "elem/last-element"
  ;; 3 is last in [1, 2, 3]
  (check-equal?
   (last (run-ns "(ns le5)\n(require [prologos::data::list :refer [List nil cons elem]])\n(require [prologos::core::eq :refer [nat-eq]])\n(eval (elem Nat nat-eq (suc (suc (suc zero))) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))"))
   "true : Bool"))

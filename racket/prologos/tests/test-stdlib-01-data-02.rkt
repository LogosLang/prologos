#lang racket/base

;;;
;;; Tests for prologos standard library data modules:
;;;   prologos::data::nat, prologos::data::bool, prologos::data::pair,
;;;   prologos::data::eq, prologos::data::option, prologos::data::result,
;;;   prologos::data::ordering, and inline data definitions.
;;;
;;; Split from test-stdlib.rkt (part 1 of 3)
;;;

(require rackunit
         racket/path
         racket/string
         racket/list
         "../driver.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../macros.rkt")

;; Compute the lib directory path
(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

;; Helper: run prologos code with namespace system active
(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
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
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
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


;; ========================================
;; prologos::data::bool — Type checking
;; ========================================

(test-case "bool operations type correctly"
  (check-equal?
   (run-ns "(ns t34)\n(require [prologos::data::bool :refer [not]])\n(check not <(-> Bool Bool)>)")
   '("OK"))
  (check-equal?
   (run-ns "(ns t35)\n(require [prologos::data::bool :refer [and]])\n(check (and true) <(-> Bool Bool)>)")
   '("OK")))


;; ========================================
;; Cross-module: using nat + bool together
;; ========================================

(test-case "cross-module: nat + bool"
  (check-equal?
   (run-ns "(ns t36)\n(require [prologos::data::nat :refer [add zero?]])\n(require [prologos::data::bool :refer [not]])\n(eval (not (zero? (add (suc zero) (suc zero)))))")
   '("true : Bool")))


;; ========================================
;; prologos::data::bool — Alias access
;; ========================================

(test-case "bool module with :as alias"
  (check-equal?
   (run-ns "(ns t37)\n(require [prologos::data::bool :as bool])\n(eval (bool::not true))")
   '("false : Bool")))


;; ========================================
;; End-to-end: full multi-module example
;; ========================================

(test-case "end-to-end multi-module demo"
  (define result
    (run-ns "(ns demo.test)
             (require [prologos::data::nat :as nat])
             (require [prologos::data::bool :refer [not and]])
             (def four <Nat> (nat::add (suc (suc zero)) (suc (suc zero))))
             (eval four)
             (eval (not true))
             (eval (and true false))"))
  (check-equal? (length result) 4)
  (check-equal? (list-ref result 0) "four : Nat defined.")
  (check-equal? (list-ref result 1) "4N : Nat")
  (check-equal? (list-ref result 2) "false : Bool")
  (check-equal? (list-ref result 3) "false : Bool"))


;; ========================================
;; Multi-spec require + :as alias + qualified access
;; ========================================

(test-case "multi-spec require (WS: single require, multiple specs)"
  ;; Single require keyword with two indented specs
  (define result
    (run-ns "(ns msr1)
             (require [prologos::data::nat :as nat :refer [add]]
                      [prologos::data::bool :as bool :refer [not]])
             (eval (add (suc zero) (suc (suc zero))))
             (eval (not true))"))
  (check-equal? (length result) 2)
  (check-equal? (first result) "3N : Nat")
  (check-equal? (second result) "false : Bool"))


(test-case "multi-spec require with qualified access to non-referred name"
  ;; 'double' is not in :refer, but nat::double works via alias
  (check-equal?
   (run-ns "(ns msr2)\n(require [prologos::data::nat :as nat])\n(eval (nat::double (suc (suc (suc zero)))))")
   '("6N : Nat")))


(test-case "multi-spec require mixed: referred bare + qualified alias"
  ;; 'add' is referred (bare access), 'double' is not (qualified access)
  (define result
    (run-ns "(ns msr3)
             (require [prologos::data::nat :as nat :refer [add mult]]
                      [prologos::data::list :as list :refer [List nil cons map]])
             (def three <Nat> (add (suc zero) (suc (suc zero))))
             (eval three)
             (eval (nat::double three))
             (eval (map (nat::double _) (cons (suc zero) (cons (suc (suc zero)) nil))))"))
  (check-equal? (length result) 4)
  (check-equal? (list-ref result 0) "three : Nat defined.")
  (check-equal? (list-ref result 1) "3N : Nat")
  (check-equal? (list-ref result 2) "6N : Nat")
  ;; map (nat::double _) [1, 2] => [2, 4]
  (check-true (string-contains? (list-ref result 3) "2"))
  (check-true (string-contains? (list-ref result 3) "4")))


(test-case "multi-spec require with three modules"
  (define result
    (run-ns "(ns msr4)
             (require [prologos::data::nat  :as nat  :refer [add]]
                      [prologos::data::bool :as bool :refer [not]]
                      [prologos::data::list :as list :refer [List nil cons length]])
             (eval (add (suc zero) (suc (suc zero))))
             (eval (bool::and true false))
             (eval (length Nat (cons (suc zero) (cons (suc (suc zero)) nil))))"))
  (check-equal? (length result) 3)
  (check-equal? (first result) "3N : Nat")
  (check-equal? (second result) "false : Bool")
  (check-equal? (third result) "2N : Nat"))


;; ========================================
;; prologos::data::nat — Subtraction
;; ========================================

(test-case "nat/sub"
  ;; sub(0, 0) = 0
  (check-equal?
   (run-ns "(ns ts1)\n(require [prologos::data::nat :refer [sub]])\n(eval (sub zero zero))")
   '("0N : Nat"))
  ;; sub(3, 0) = 3
  (check-equal?
   (run-ns "(ns ts2)\n(require [prologos::data::nat :refer [sub]])\n(eval (sub (suc (suc (suc zero))) zero))")
   '("3N : Nat"))
  ;; sub(0, 3) = 0 (saturating)
  (check-equal?
   (run-ns "(ns ts3)\n(require [prologos::data::nat :refer [sub]])\n(eval (sub zero (suc (suc (suc zero)))))")
   '("0N : Nat"))
  ;; sub(5, 3) = 2
  (check-equal?
   (run-ns "(ns ts4)\n(require [prologos::data::nat :refer [sub]])\n(eval (sub (suc (suc (suc (suc (suc zero))))) (suc (suc (suc zero)))))")
   '("2N : Nat"))
  ;; sub(3, 5) = 0 (saturating)
  (check-equal?
   (run-ns "(ns ts5)\n(require [prologos::data::nat :refer [sub]])\n(eval (sub (suc (suc (suc zero))) (suc (suc (suc (suc (suc zero)))))))")
   '("0N : Nat"))
  ;; sub(3, 3) = 0
  (check-equal?
   (run-ns "(ns ts6)\n(require [prologos::data::nat :refer [sub]])\n(eval (sub (suc (suc (suc zero))) (suc (suc (suc zero)))))")
   '("0N : Nat")))


;; ========================================
;; prologos::data::nat — Comparisons
;; ========================================

(test-case "nat/le?"
  (check-equal?
   (run-ns "(ns tc1)\n(require [prologos::data::nat :refer [le?]])\n(eval (le? zero zero))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns tc2)\n(require [prologos::data::nat :refer [le?]])\n(eval (le? zero (suc (suc (suc zero)))))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns tc3)\n(require [prologos::data::nat :refer [le?]])\n(eval (le? (suc (suc (suc zero))) (suc (suc (suc (suc (suc zero)))))))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns tc4)\n(require [prologos::data::nat :refer [le?]])\n(eval (le? (suc (suc (suc (suc (suc zero))))) (suc (suc (suc zero)))))")
   '("false : Bool"))
  (check-equal?
   (run-ns "(ns tc5)\n(require [prologos::data::nat :refer [le?]])\n(eval (le? (suc (suc (suc zero))) (suc (suc (suc zero)))))")
   '("true : Bool")))


(test-case "nat/lt?"
  (check-equal?
   (run-ns "(ns tc6)\n(require [prologos::data::nat :refer [lt?]])\n(eval (lt? zero zero))")
   '("false : Bool"))
  (check-equal?
   (run-ns "(ns tc7)\n(require [prologos::data::nat :refer [lt?]])\n(eval (lt? zero (suc (suc (suc zero)))))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns tc8)\n(require [prologos::data::nat :refer [lt?]])\n(eval (lt? (suc (suc (suc (suc (suc zero))))) (suc (suc (suc zero)))))")
   '("false : Bool"))
  (check-equal?
   (run-ns "(ns tc9)\n(require [prologos::data::nat :refer [lt?]])\n(eval (lt? (suc (suc (suc zero))) (suc (suc (suc zero)))))")
   '("false : Bool")))


(test-case "nat/gt?"
  (check-equal?
   (run-ns "(ns tc10)\n(require [prologos::data::nat :refer [gt?]])\n(eval (gt? (suc (suc (suc (suc (suc zero))))) (suc (suc (suc zero)))))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns tc11)\n(require [prologos::data::nat :refer [gt?]])\n(eval (gt? zero (suc zero)))")
   '("false : Bool")))


(test-case "nat/ge?"
  (check-equal?
   (run-ns "(ns tc12)\n(require [prologos::data::nat :refer [ge?]])\n(eval (ge? (suc (suc (suc zero))) (suc (suc (suc zero)))))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns tc13)\n(require [prologos::data::nat :refer [ge?]])\n(eval (ge? (suc zero) (suc (suc zero))))")
   '("false : Bool")))


(test-case "nat/nat-eq?"
  (check-equal?
   (run-ns "(ns tc14)\n(require [prologos::data::nat :refer [nat-eq?]])\n(eval (nat-eq? zero zero))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns tc15)\n(require [prologos::data::nat :refer [nat-eq?]])\n(eval (nat-eq? (suc (suc (suc zero))) (suc (suc (suc zero)))))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns tc16)\n(require [prologos::data::nat :refer [nat-eq?]])\n(eval (nat-eq? (suc (suc (suc zero))) (suc (suc (suc (suc (suc zero)))))))")
   '("false : Bool"))
  (check-equal?
   (run-ns "(ns tc17)\n(require [prologos::data::nat :refer [nat-eq?]])\n(eval (nat-eq? (suc (suc (suc (suc (suc zero))))) (suc (suc (suc zero)))))")
   '("false : Bool")))

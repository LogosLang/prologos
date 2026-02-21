#lang racket/base

;;;
;;; Tests for prologos standard library data modules:
;;;   prologos.data.nat, prologos.data.bool, prologos.data.pair,
;;;   prologos.data.eq, prologos.data.option, prologos.data.result,
;;;   prologos.data.ordering, and inline data definitions.
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
;; prologos.data.nat — Module Loading
;; ========================================

(test-case "load prologos.data.nat"
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)])
    (install-module-loader!)
    (define mod (load-module 'prologos.data.nat #f))
    (check-not-false (module-info? mod))
    (define exports (module-info-exports mod))
    (check-not-false (member 'add exports) "exports add")
    (check-not-false (member 'mult exports) "exports mult")
    (check-not-false (member 'double exports) "exports double")
    (check-not-false (member 'pred exports) "exports pred")
    (check-not-false (member 'zero? exports) "exports zero?")))

;; ========================================
;; prologos.data.nat — Addition
;; ========================================

(test-case "nat::add basic"
  ;; 0 + 0 = 0
  (check-equal?
   (run-ns "(ns t1)\n(require [prologos.data.nat :refer [add]])\n(eval (add zero zero))")
   '("0N : Nat"))
  ;; 0 + 3 = 3
  (check-equal?
   (run-ns "(ns t2)\n(require [prologos.data.nat :refer [add]])\n(eval (add zero (suc (suc (suc zero)))))")
   '("3N : Nat"))
  ;; 2 + 3 = 5
  (check-equal?
   (run-ns "(ns t3)\n(require [prologos.data.nat :refer [add]])\n(eval (add (suc (suc zero)) (suc (suc (suc zero)))))")
   '("5N : Nat")))

;; ========================================
;; prologos.data.nat — Multiplication
;; ========================================

(test-case "nat/mult basic"
  ;; 0 * 3 = 0
  (check-equal?
   (run-ns "(ns t4)\n(require [prologos.data.nat :refer [mult]])\n(eval (mult zero (suc (suc (suc zero)))))")
   '("0N : Nat"))
  ;; 2 * 3 = 6
  (check-equal?
   (run-ns "(ns t5)\n(require [prologos.data.nat :refer [mult]])\n(eval (mult (suc (suc zero)) (suc (suc (suc zero)))))")
   '("6N : Nat"))
  ;; 3 * 1 = 3
  (check-equal?
   (run-ns "(ns t6)\n(require [prologos.data.nat :refer [mult]])\n(eval (mult (suc (suc (suc zero))) (suc zero)))")
   '("3N : Nat")))

;; ========================================
;; prologos.data.nat — Double
;; ========================================

(test-case "nat::double"
  ;; double 0 = 0
  (check-equal?
   (run-ns "(ns t7)\n(require [prologos.data.nat :refer [double]])\n(eval (double zero))")
   '("0N : Nat"))
  ;; double 3 = 6
  (check-equal?
   (run-ns "(ns t8)\n(require [prologos.data.nat :refer [double]])\n(eval (double (suc (suc (suc zero)))))")
   '("6N : Nat")))

;; ========================================
;; prologos.data.nat — Predecessor
;; ========================================

(test-case "nat/pred"
  ;; pred 0 = 0
  (check-equal?
   (run-ns "(ns t9)\n(require [prologos.data.nat :refer [pred]])\n(eval (pred zero))")
   '("0N : Nat"))
  ;; pred 3 = 2
  (check-equal?
   (run-ns "(ns t10)\n(require [prologos.data.nat :refer [pred]])\n(eval (pred (suc (suc (suc zero)))))")
   '("2N : Nat"))
  ;; pred 1 = 0
  (check-equal?
   (run-ns "(ns t11)\n(require [prologos.data.nat :refer [pred]])\n(eval (pred (suc zero)))")
   '("0N : Nat")))

;; ========================================
;; prologos.data.nat — Is-zero
;; ========================================

(test-case "nat/zero?"
  ;; zero? 0 = true
  (check-equal?
   (run-ns "(ns t12)\n(require [prologos.data.nat :refer [zero?]])\n(eval (zero? zero))")
   '("true : Bool"))
  ;; zero? 1 = false
  (check-equal?
   (run-ns "(ns t13)\n(require [prologos.data.nat :refer [zero?]])\n(eval (zero? (suc zero)))")
   '("false : Bool")))

;; ========================================
;; prologos.data.nat — Alias access
;; ========================================

(test-case "nat module with :as alias"
  (check-equal?
   (run-ns "(ns t14)\n(require [prologos.data.nat :as nat])\n(eval (nat::add (suc zero) (suc (suc zero))))")
   '("3N : Nat")))

;; ========================================
;; prologos.data.nat — Type checking
;; ========================================

(test-case "nat operations type correctly"
  (check-equal?
   (run-ns "(ns t15)\n(require [prologos.data.nat :refer [add]])\n(check (add zero) <(-> Nat Nat)>)")
   '("OK"))
  (check-equal?
   (run-ns "(ns t16)\n(require [prologos.data.nat :refer [zero?]])\n(check zero? <(-> Nat Bool)>)")
   '("OK")))

;; ========================================
;; prologos.data.bool — Module Loading
;; ========================================

(test-case "load prologos.data.bool"
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)])
    (install-module-loader!)
    (define mod (load-module 'prologos.data.bool #f))
    (check-not-false (module-info? mod))
    (define exports (module-info-exports mod))
    (check-not-false (member 'not exports) "exports not")
    (check-not-false (member 'and exports) "exports and")
    (check-not-false (member 'or exports) "exports or")
    (check-not-false (member 'xor exports) "exports xor")
    (check-not-false (member 'bool-eq exports) "exports bool-eq")))

;; ========================================
;; prologos.data.bool — NOT
;; ========================================

(test-case "bool::not"
  (check-equal?
   (run-ns "(ns t17)\n(require [prologos.data.bool :refer [not]])\n(eval (not true))")
   '("false : Bool"))
  (check-equal?
   (run-ns "(ns t18)\n(require [prologos.data.bool :refer [not]])\n(eval (not false))")
   '("true : Bool")))

;; ========================================
;; prologos.data.bool — AND
;; ========================================

(test-case "bool::and"
  (check-equal?
   (run-ns "(ns t19)\n(require [prologos.data.bool :refer [and]])\n(eval (and true true))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns t20)\n(require [prologos.data.bool :refer [and]])\n(eval (and true false))")
   '("false : Bool"))
  (check-equal?
   (run-ns "(ns t21)\n(require [prologos.data.bool :refer [and]])\n(eval (and false true))")
   '("false : Bool"))
  (check-equal?
   (run-ns "(ns t22)\n(require [prologos.data.bool :refer [and]])\n(eval (and false false))")
   '("false : Bool")))

;; ========================================
;; prologos.data.bool — OR
;; ========================================

(test-case "bool/or"
  (check-equal?
   (run-ns "(ns t23)\n(require [prologos.data.bool :refer [or]])\n(eval (or true true))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns t24)\n(require [prologos.data.bool :refer [or]])\n(eval (or true false))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns t25)\n(require [prologos.data.bool :refer [or]])\n(eval (or false true))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns t26)\n(require [prologos.data.bool :refer [or]])\n(eval (or false false))")
   '("false : Bool")))

;; ========================================
;; prologos.data.bool — XOR
;; ========================================

(test-case "bool/xor"
  (check-equal?
   (run-ns "(ns t27)\n(require [prologos.data.bool :refer [xor]])\n(eval (xor true true))")
   '("false : Bool"))
  (check-equal?
   (run-ns "(ns t28)\n(require [prologos.data.bool :refer [xor]])\n(eval (xor true false))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns t29)\n(require [prologos.data.bool :refer [xor]])\n(eval (xor false true))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns t30)\n(require [prologos.data.bool :refer [xor]])\n(eval (xor false false))")
   '("false : Bool")))

;; ========================================
;; prologos.data.bool — Equality
;; ========================================

(test-case "bool/bool-eq"
  (check-equal?
   (run-ns "(ns t31)\n(require [prologos.data.bool :refer [bool-eq]])\n(eval (bool-eq true true))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns t32)\n(require [prologos.data.bool :refer [bool-eq]])\n(eval (bool-eq true false))")
   '("false : Bool"))
  (check-equal?
   (run-ns "(ns t33)\n(require [prologos.data.bool :refer [bool-eq]])\n(eval (bool-eq false false))")
   '("true : Bool")))

;; ========================================
;; prologos.data.bool — Type checking
;; ========================================

(test-case "bool operations type correctly"
  (check-equal?
   (run-ns "(ns t34)\n(require [prologos.data.bool :refer [not]])\n(check not <(-> Bool Bool)>)")
   '("OK"))
  (check-equal?
   (run-ns "(ns t35)\n(require [prologos.data.bool :refer [and]])\n(check (and true) <(-> Bool Bool)>)")
   '("OK")))

;; ========================================
;; Cross-module: using nat + bool together
;; ========================================

(test-case "cross-module: nat + bool"
  (check-equal?
   (run-ns "(ns t36)\n(require [prologos.data.nat :refer [add zero?]])\n(require [prologos.data.bool :refer [not]])\n(eval (not (zero? (add (suc zero) (suc zero)))))")
   '("true : Bool")))

;; ========================================
;; prologos.data.bool — Alias access
;; ========================================

(test-case "bool module with :as alias"
  (check-equal?
   (run-ns "(ns t37)\n(require [prologos.data.bool :as bool])\n(eval (bool::not true))")
   '("false : Bool")))

;; ========================================
;; End-to-end: full multi-module example
;; ========================================

(test-case "end-to-end multi-module demo"
  (define result
    (run-ns "(ns demo.test)
             (require [prologos.data.nat :as nat])
             (require [prologos.data.bool :refer [not and]])
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
             (require [prologos.data.nat :as nat :refer [add]]
                      [prologos.data.bool :as bool :refer [not]])
             (eval (add (suc zero) (suc (suc zero))))
             (eval (not true))"))
  (check-equal? (length result) 2)
  (check-equal? (first result) "3N : Nat")
  (check-equal? (second result) "false : Bool"))

(test-case "multi-spec require with qualified access to non-referred name"
  ;; 'double' is not in :refer, but nat::double works via alias
  (check-equal?
   (run-ns "(ns msr2)\n(require [prologos.data.nat :as nat])\n(eval (nat::double (suc (suc (suc zero)))))")
   '("6N : Nat")))

(test-case "multi-spec require mixed: referred bare + qualified alias"
  ;; 'add' is referred (bare access), 'double' is not (qualified access)
  (define result
    (run-ns "(ns msr3)
             (require [prologos.data.nat :as nat :refer [add mult]]
                      [prologos.data.list :as list :refer [List nil cons map]])
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
             (require [prologos.data.nat  :as nat  :refer [add]]
                      [prologos.data.bool :as bool :refer [not]]
                      [prologos.data.list :as list :refer [List nil cons length]])
             (eval (add (suc zero) (suc (suc zero))))
             (eval (bool::and true false))
             (eval (length Nat (cons (suc zero) (cons (suc (suc zero)) nil))))"))
  (check-equal? (length result) 3)
  (check-equal? (first result) "3N : Nat")
  (check-equal? (second result) "false : Bool")
  (check-equal? (third result) "2N : Nat"))

;; ========================================
;; prologos.data.nat — Subtraction
;; ========================================

(test-case "nat/sub"
  ;; sub(0, 0) = 0
  (check-equal?
   (run-ns "(ns ts1)\n(require [prologos.data.nat :refer [sub]])\n(eval (sub zero zero))")
   '("0N : Nat"))
  ;; sub(3, 0) = 3
  (check-equal?
   (run-ns "(ns ts2)\n(require [prologos.data.nat :refer [sub]])\n(eval (sub (suc (suc (suc zero))) zero))")
   '("3N : Nat"))
  ;; sub(0, 3) = 0 (saturating)
  (check-equal?
   (run-ns "(ns ts3)\n(require [prologos.data.nat :refer [sub]])\n(eval (sub zero (suc (suc (suc zero)))))")
   '("0N : Nat"))
  ;; sub(5, 3) = 2
  (check-equal?
   (run-ns "(ns ts4)\n(require [prologos.data.nat :refer [sub]])\n(eval (sub (suc (suc (suc (suc (suc zero))))) (suc (suc (suc zero)))))")
   '("2N : Nat"))
  ;; sub(3, 5) = 0 (saturating)
  (check-equal?
   (run-ns "(ns ts5)\n(require [prologos.data.nat :refer [sub]])\n(eval (sub (suc (suc (suc zero))) (suc (suc (suc (suc (suc zero)))))))")
   '("0N : Nat"))
  ;; sub(3, 3) = 0
  (check-equal?
   (run-ns "(ns ts6)\n(require [prologos.data.nat :refer [sub]])\n(eval (sub (suc (suc (suc zero))) (suc (suc (suc zero)))))")
   '("0N : Nat")))

;; ========================================
;; prologos.data.nat — Comparisons
;; ========================================

(test-case "nat/le?"
  (check-equal?
   (run-ns "(ns tc1)\n(require [prologos.data.nat :refer [le?]])\n(eval (le? zero zero))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns tc2)\n(require [prologos.data.nat :refer [le?]])\n(eval (le? zero (suc (suc (suc zero)))))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns tc3)\n(require [prologos.data.nat :refer [le?]])\n(eval (le? (suc (suc (suc zero))) (suc (suc (suc (suc (suc zero)))))))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns tc4)\n(require [prologos.data.nat :refer [le?]])\n(eval (le? (suc (suc (suc (suc (suc zero))))) (suc (suc (suc zero)))))")
   '("false : Bool"))
  (check-equal?
   (run-ns "(ns tc5)\n(require [prologos.data.nat :refer [le?]])\n(eval (le? (suc (suc (suc zero))) (suc (suc (suc zero)))))")
   '("true : Bool")))

(test-case "nat/lt?"
  (check-equal?
   (run-ns "(ns tc6)\n(require [prologos.data.nat :refer [lt?]])\n(eval (lt? zero zero))")
   '("false : Bool"))
  (check-equal?
   (run-ns "(ns tc7)\n(require [prologos.data.nat :refer [lt?]])\n(eval (lt? zero (suc (suc (suc zero)))))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns tc8)\n(require [prologos.data.nat :refer [lt?]])\n(eval (lt? (suc (suc (suc (suc (suc zero))))) (suc (suc (suc zero)))))")
   '("false : Bool"))
  (check-equal?
   (run-ns "(ns tc9)\n(require [prologos.data.nat :refer [lt?]])\n(eval (lt? (suc (suc (suc zero))) (suc (suc (suc zero)))))")
   '("false : Bool")))

(test-case "nat/gt?"
  (check-equal?
   (run-ns "(ns tc10)\n(require [prologos.data.nat :refer [gt?]])\n(eval (gt? (suc (suc (suc (suc (suc zero))))) (suc (suc (suc zero)))))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns tc11)\n(require [prologos.data.nat :refer [gt?]])\n(eval (gt? zero (suc zero)))")
   '("false : Bool")))

(test-case "nat/ge?"
  (check-equal?
   (run-ns "(ns tc12)\n(require [prologos.data.nat :refer [ge?]])\n(eval (ge? (suc (suc (suc zero))) (suc (suc (suc zero)))))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns tc13)\n(require [prologos.data.nat :refer [ge?]])\n(eval (ge? (suc zero) (suc (suc zero))))")
   '("false : Bool")))

(test-case "nat/nat-eq?"
  (check-equal?
   (run-ns "(ns tc14)\n(require [prologos.data.nat :refer [nat-eq?]])\n(eval (nat-eq? zero zero))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns tc15)\n(require [prologos.data.nat :refer [nat-eq?]])\n(eval (nat-eq? (suc (suc (suc zero))) (suc (suc (suc zero)))))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns tc16)\n(require [prologos.data.nat :refer [nat-eq?]])\n(eval (nat-eq? (suc (suc (suc zero))) (suc (suc (suc (suc (suc zero)))))))")
   '("false : Bool"))
  (check-equal?
   (run-ns "(ns tc17)\n(require [prologos.data.nat :refer [nat-eq?]])\n(eval (nat-eq? (suc (suc (suc (suc (suc zero))))) (suc (suc (suc zero)))))")
   '("false : Bool")))

;; ========================================
;; prologos.data.nat — Min/Max
;; ========================================

(test-case "nat/min"
  (check-equal?
   (run-ns "(ns tm1)\n(require [prologos.data.nat :refer [min]])\n(eval (min (suc (suc (suc (suc (suc zero))))) (suc (suc (suc zero)))))")
   '("3N : Nat"))
  (check-equal?
   (run-ns "(ns tm2)\n(require [prologos.data.nat :refer [min]])\n(eval (min (suc (suc zero)) (suc (suc (suc (suc (suc zero)))))))")
   '("2N : Nat"))
  (check-equal?
   (run-ns "(ns tm3)\n(require [prologos.data.nat :refer [min]])\n(eval (min (suc (suc (suc zero))) (suc (suc (suc zero)))))")
   '("3N : Nat")))

(test-case "nat/max"
  (check-equal?
   (run-ns "(ns tm4)\n(require [prologos.data.nat :refer [max]])\n(eval (max (suc (suc (suc (suc (suc zero))))) (suc (suc (suc zero)))))")
   '("5N : Nat"))
  (check-equal?
   (run-ns "(ns tm5)\n(require [prologos.data.nat :refer [max]])\n(eval (max (suc (suc zero)) (suc (suc (suc (suc (suc zero)))))))")
   '("5N : Nat"))
  (check-equal?
   (run-ns "(ns tm6)\n(require [prologos.data.nat :refer [max]])\n(eval (max (suc (suc (suc zero))) (suc (suc (suc zero)))))")
   '("3N : Nat")))

;; ========================================
;; prologos.data.nat — Power
;; ========================================

(test-case "nat/pow"
  (check-equal?
   (run-ns "(ns tp1)\n(require [prologos.data.nat :refer [pow]])\n(eval (pow (suc (suc zero)) zero))")
   '("1N : Nat"))
  (check-equal?
   (run-ns "(ns tp2)\n(require [prologos.data.nat :refer [pow]])\n(eval (pow (suc (suc zero)) (suc (suc (suc zero)))))")
   '("8N : Nat"))
  (check-equal?
   (run-ns "(ns tp3)\n(require [prologos.data.nat :refer [pow]])\n(eval (pow (suc (suc (suc zero))) (suc (suc zero))))")
   '("9N : Nat"))
  (check-equal?
   (run-ns "(ns tp4)\n(require [prologos.data.nat :refer [pow]])\n(eval (pow zero (suc (suc (suc (suc (suc zero)))))))")
   '("0N : Nat")))

;; ========================================
;; prologos.data.nat — bool-to-nat
;; ========================================

(test-case "nat/bool-to-nat"
  (check-equal?
   (run-ns "(ns tb1)\n(require [prologos.data.nat :refer [bool-to-nat]])\n(eval (bool-to-nat true))")
   '("1N : Nat"))
  (check-equal?
   (run-ns "(ns tb2)\n(require [prologos.data.nat :refer [bool-to-nat]])\n(eval (bool-to-nat false))")
   '("0N : Nat")))

;; ========================================
;; prologos.data.nat — Type checking new functions
;; ========================================

(test-case "nat new functions type correctly"
  (check-equal?
   (run-ns "(ns tt1)\n(require [prologos.data.nat :refer [sub]])\n(check sub <(-> Nat (-> Nat Nat))>)")
   '("OK"))
  (check-equal?
   (run-ns "(ns tt2)\n(require [prologos.data.nat :refer [le?]])\n(check le? <(-> Nat (-> Nat Bool))>)")
   '("OK"))
  (check-equal?
   (run-ns "(ns tt3)\n(require [prologos.data.nat :refer [nat-eq?]])\n(check nat-eq? <(-> Nat (-> Nat Bool))>)")
   '("OK"))
  (check-equal?
   (run-ns "(ns tt4)\n(require [prologos.data.nat :refer [min]])\n(check min <(-> Nat (-> Nat Nat))>)")
   '("OK"))
  (check-equal?
   (run-ns "(ns tt5)\n(require [prologos.data.nat :refer [pow]])\n(check pow <(-> Nat (-> Nat Nat))>)")
   '("OK"))
  (check-equal?
   (run-ns "(ns tt6)\n(require [prologos.data.nat :refer [bool-to-nat]])\n(check bool-to-nat <(-> Bool Nat)>)")
   '("OK")))

;; ========================================
;; prologos.data.nat — Module loading with new exports
;; ========================================

(test-case "load prologos.data.nat with new exports"
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)])
    (install-module-loader!)
    (define mod (load-module 'prologos.data.nat #f))
    (define exports (module-info-exports mod))
    (check-not-false (member 'sub exports) "exports sub")
    (check-not-false (member 'le? exports) "exports le?")
    (check-not-false (member 'lt? exports) "exports lt?")
    (check-not-false (member 'gt? exports) "exports gt?")
    (check-not-false (member 'ge? exports) "exports ge?")
    (check-not-false (member 'nat-eq? exports) "exports nat-eq?")
    (check-not-false (member 'min exports) "exports min")
    (check-not-false (member 'max exports) "exports max")
    (check-not-false (member 'pow exports) "exports pow")
    (check-not-false (member 'bool-to-nat exports) "exports bool-to-nat")))

;; ========================================
;; prologos.data.bool — NAND
;; ========================================

(test-case "bool/nand"
  (check-equal?
   (run-ns "(ns bn1)\n(require [prologos.data.bool :refer [nand]])\n(eval (nand true true))")
   '("false : Bool"))
  (check-equal?
   (run-ns "(ns bn2)\n(require [prologos.data.bool :refer [nand]])\n(eval (nand true false))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns bn3)\n(require [prologos.data.bool :refer [nand]])\n(eval (nand false true))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns bn4)\n(require [prologos.data.bool :refer [nand]])\n(eval (nand false false))")
   '("true : Bool")))

;; ========================================
;; prologos.data.bool — NOR
;; ========================================

(test-case "bool/nor"
  (check-equal?
   (run-ns "(ns br1)\n(require [prologos.data.bool :refer [nor]])\n(eval (nor true true))")
   '("false : Bool"))
  (check-equal?
   (run-ns "(ns br2)\n(require [prologos.data.bool :refer [nor]])\n(eval (nor true false))")
   '("false : Bool"))
  (check-equal?
   (run-ns "(ns br3)\n(require [prologos.data.bool :refer [nor]])\n(eval (nor false true))")
   '("false : Bool"))
  (check-equal?
   (run-ns "(ns br4)\n(require [prologos.data.bool :refer [nor]])\n(eval (nor false false))")
   '("true : Bool")))

;; ========================================
;; prologos.data.bool — Implies
;; ========================================

(test-case "bool/implies"
  (check-equal?
   (run-ns "(ns bi1)\n(require [prologos.data.bool :refer [implies]])\n(eval (implies true true))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns bi2)\n(require [prologos.data.bool :refer [implies]])\n(eval (implies true false))")
   '("false : Bool"))
  (check-equal?
   (run-ns "(ns bi3)\n(require [prologos.data.bool :refer [implies]])\n(eval (implies false true))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns bi4)\n(require [prologos.data.bool :refer [implies]])\n(eval (implies false false))")
   '("true : Bool")))

;; ========================================
;; prologos.data.bool — New exports
;; ========================================

(test-case "load prologos.data.bool with new exports"
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)])
    (install-module-loader!)
    (define mod (load-module 'prologos.data.bool #f))
    (define exports (module-info-exports mod))
    (check-not-false (member 'nand exports) "exports nand")
    (check-not-false (member 'nor exports) "exports nor")
    (check-not-false (member 'implies exports) "exports implies")))

;; ========================================
;; prologos.data.pair — Module Loading
;; ========================================

(test-case "load prologos.data.pair"
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)])
    (install-module-loader!)
    (define mod (load-module 'prologos.data.pair #f))
    (check-not-false (module-info? mod))
    (define exports (module-info-exports mod))
    (check-not-false (member 'swap exports) "exports swap")
    (check-not-false (member 'map-fst exports) "exports map-fst")
    (check-not-false (member 'map-snd exports) "exports map-snd")
    (check-not-false (member 'bimap exports) "exports bimap")))

;; ========================================
;; prologos.data.pair — swap
;; ========================================

(test-case "pair/swap"
  (check-equal?
   (run-ns "(ns ps1)\n(require [prologos.data.pair :refer [swap]])\n(eval (first (swap Nat Bool (pair zero true))))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns ps2)\n(require [prologos.data.pair :refer [swap]])\n(eval (second (swap Nat Bool (pair zero true))))")
   '("0N : Nat")))

;; ========================================
;; prologos.data.pair — map-fst
;; ========================================

(test-case "pair/map-fst"
  ;; Auto-implicit order: A C B (first-occurrence in spec [A -> C] [Sigma [_ <A>] B] -> ...)
  (check-equal?
   (run-ns "(ns pm1)\n(require [prologos.data.pair :refer [map-fst]])\n(eval (first (map-fst Nat Nat Bool (fn (x : Nat) (suc x)) (pair zero true))))")
   '("1N : Nat"))
  (check-equal?
   (run-ns "(ns pm2)\n(require [prologos.data.pair :refer [map-fst]])\n(eval (second (map-fst Nat Nat Bool (fn (x : Nat) (suc x)) (pair zero true))))")
   '("true : Bool")))

;; ========================================
;; prologos.data.pair — map-snd
;; ========================================

(test-case "pair/map-snd"
  ;; Auto-implicit order: B C A (first-occurrence in spec [B -> C] [Sigma [_ <A>] B] -> ...)
  (check-equal?
   (run-ns "(ns pm3)\n(require [prologos.data.pair :refer [map-snd]])\n(eval (first (map-snd Bool Nat Nat (fn (b : Bool) zero) (pair (suc zero) true))))")
   '("1N : Nat"))
  (check-equal?
   (run-ns "(ns pm4)\n(require [prologos.data.pair :refer [map-snd]])\n(eval (second (map-snd Bool Nat Nat (fn (b : Bool) zero) (pair (suc zero) true))))")
   '("0N : Nat")))

;; ========================================
;; prologos.data.pair — bimap
;; ========================================

(test-case "pair/bimap"
  ;; Auto-implicit order: A C B D (first-occurrence in spec [A -> C] [B -> D] [Sigma [_ <A>] B] -> ...)
  (check-equal?
   (run-ns "(ns pb1)\n(require [prologos.data.pair :refer [bimap]])\n(eval (first (bimap Nat Nat Bool Bool (fn (x : Nat) (suc x)) (fn (b : Bool) (boolrec Bool false true b)) (pair (suc zero) true))))")
   '("2N : Nat"))
  (check-equal?
   (run-ns "(ns pb2)\n(require [prologos.data.pair :refer [bimap]])\n(eval (second (bimap Nat Nat Bool Bool (fn (x : Nat) (suc x)) (fn (b : Bool) (boolrec Bool false true b)) (pair (suc zero) true))))")
   '("false : Bool")))

;; ========================================
;; prologos.core — on combinator
;; ========================================

(test-case "core/on"
  ;; Auto-implicit order: B C A (first-occurrence in spec [B -> B -> C] [A -> B] A A -> C)
  ;; (on nat-eq? id) should compare two nats for equality: on(nat-eq?, id, 3, 3) = true
  (check-equal?
   (run-ns "(ns co1)\n(require [prologos.data.nat :refer [nat-eq?]])\n(eval (on Nat Bool Nat nat-eq? (fn (x : Nat) x) (suc (suc (suc zero))) (suc (suc (suc zero)))))")
   '("true : Bool"))
  ;; on(nat-eq?, id, 2, 3) = false
  (check-equal?
   (run-ns "(ns co2)\n(require [prologos.data.nat :refer [nat-eq?]])\n(eval (on Nat Bool Nat nat-eq? (fn (x : Nat) x) (suc (suc zero)) (suc (suc (suc zero)))))")
   '("false : Bool")))

;; ========================================
;; Cross-module tests with new functions
;; ========================================

(test-case "cross-module: sub + le? + not"
  (check-equal?
   (run-ns "(ns cx1)\n(require [prologos.data.nat :refer [sub le?]])\n(require [prologos.data.bool :refer [not]])\n(eval (not (le? (suc (suc (suc (suc (suc zero))))) (suc (suc (suc zero))))))")
   '("true : Bool")))

;; ========================================
;; prologos.data.eq — Module Loading
;; ========================================

(test-case "load prologos.data.eq"
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)])
    (install-module-loader!)
    (define mod (load-module 'prologos.data.eq #f))
    (check-not-false (module-info? mod))
    (define exports (module-info-exports mod))
    (check-not-false (member 'sym exports) "exports sym")
    (check-not-false (member 'cong exports) "exports cong")
    (check-not-false (member 'trans exports) "exports trans")))

;; ========================================
;; prologos.data.eq — sym (symmetry)
;; ========================================

(test-case "eq/sym"
  ;; sym : Eq(Nat, 0, 0) -> Eq(Nat, 0, 0)
  (check-equal?
   (run-ns "(ns es1)\n(require [prologos.data.eq :refer [sym]])\n(check (sym Nat zero zero (the (Eq Nat zero zero) refl)) : (Eq Nat zero zero))")
   '("OK"))
  ;; sym : Eq(Nat, 1, 1) -> Eq(Nat, 1, 1)
  (check-equal?
   (run-ns "(ns es2)\n(require [prologos.data.eq :refer [sym]])\n(check (sym Nat (suc zero) (suc zero) (the (Eq Nat (suc zero) (suc zero)) refl)) : (Eq Nat (suc zero) (suc zero)))")
   '("OK"))
  ;; sym evaluates to refl
  (check-equal?
   (run-ns "(ns es3)\n(require [prologos.data.eq :refer [sym]])\n(eval (sym Nat zero zero (the (Eq Nat zero zero) refl)))")
   '("refl : [Eq Nat 0N 0N]")))

;; ========================================
;; prologos.data.eq — cong (congruence)
;; ========================================

(test-case "eq/cong"
  ;; cong suc : Eq(Nat, 0, 0) -> Eq(Nat, 1, 1)
  (check-equal?
   (run-ns "(ns ec1)\n(require [prologos.data.eq :refer [cong]])\n(check (cong Nat Nat zero zero (fn (x : Nat) (suc x)) (the (Eq Nat zero zero) refl)) : (Eq Nat (suc zero) (suc zero)))")
   '("OK"))
  ;; cong evaluates to refl
  (check-equal?
   (run-ns "(ns ec2)\n(require [prologos.data.eq :refer [cong]])\n(eval (cong Nat Nat zero zero (fn (x : Nat) (suc x)) (the (Eq Nat zero zero) refl)))")
   '("refl : [Eq Nat 1N 1N]")))

;; ========================================
;; prologos.data.eq — trans (transitivity)
;; ========================================

(test-case "eq/trans"
  ;; trans : Eq(Nat, 0, 0) -> Eq(Nat, 0, 0) -> Eq(Nat, 0, 0)
  (check-equal?
   (run-ns "(ns et1)\n(require [prologos.data.eq :refer [trans]])\n(check (trans Nat zero zero zero (the (Eq Nat zero zero) refl) (the (Eq Nat zero zero) refl)) : (Eq Nat zero zero))")
   '("OK"))
  ;; trans evaluates to refl
  (check-equal?
   (run-ns "(ns et2)\n(require [prologos.data.eq :refer [trans]])\n(eval (trans Nat zero zero zero (the (Eq Nat zero zero) refl) (the (Eq Nat zero zero) refl)))")
   '("refl : [Eq Nat 0N 0N]")))

;; ========================================
;; prologos.data.option — Module Loading
;; ========================================

(test-case "load prologos.data.option"
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)])
    (install-module-loader!)
    (define mod (load-module 'prologos.data.option #f))
    (check-not-false (module-info? mod))
    (define exports (module-info-exports mod))
    (check-not-false (member 'Option exports) "exports Option")
    (check-not-false (member 'none exports) "exports none")
    (check-not-false (member 'some exports) "exports some")
    (check-not-false (member 'map exports) "exports map")
    (check-not-false (member 'flat-map exports) "exports flat-map")
    (check-not-false (member 'unwrap-or exports) "exports unwrap-or")))

;; ========================================
;; prologos.data.option — Constructors
;; ========================================

(test-case "option/constructors"
  (check-equal?
   (run-ns "(ns oc1)\n(require [prologos.data.option :refer [Option none some]])\n(check (none Nat) : (Option Nat))")
   '("OK"))
  (check-equal?
   (run-ns "(ns oc2)\n(require [prologos.data.option :refer [Option none some]])\n(check (some Nat zero) : (Option Nat))")
   '("OK"))
  (check-equal?
   (run-ns "(ns oc3)\n(require [prologos.data.option :refer [Option none some]])\n(check (some Bool true) : (Option Bool))")
   '("OK")))

;; ========================================
;; prologos.data.option — Elimination
;; ========================================

(test-case "option/elimination"
  ;; Eliminate some: extract value via match
  (check-equal?
   (run-ns "(ns oe1)\n(require [prologos.data.option :refer [Option none some]])\n(eval (the Nat (match (some Nat (suc zero)) (none -> zero) (some x -> (suc x)))))")
   '("2N : Nat"))
  ;; Eliminate none: get default via match
  (check-equal?
   (run-ns "(ns oe2)\n(require [prologos.data.option :refer [Option none some]])\n(eval (the Nat (match (none Nat) (none -> (suc (suc zero))) (some x -> (suc x)))))")
   '("2N : Nat")))

;; ========================================
;; prologos.data.option — Combinators
;; ========================================

(test-case "option/map"
  ;; Map over some
  (check-equal?
   (run-ns "(ns om1)\n(require [prologos.data.option :refer [Option none some map unwrap-or]])\n(eval (unwrap-or Nat zero (map Nat Nat (fn (x : Nat) (suc x)) (some Nat (suc zero)))))")
   '("2N : Nat"))
  ;; Map over none
  (check-equal?
   (run-ns "(ns om2)\n(require [prologos.data.option :refer [Option none some map unwrap-or]])\n(eval (unwrap-or Nat zero (map Nat Nat (fn (x : Nat) (suc x)) (none Nat))))")
   '("0N : Nat")))

(test-case "option/flat-map"
  ;; Flat-map some -> some
  (check-equal?
   (run-ns "(ns ofm1)\n(require [prologos.data.option :refer [Option none some flat-map unwrap-or]])\n(eval (unwrap-or Nat zero (flat-map Nat Nat (fn (x : Nat) (some Nat (suc x))) (some Nat (suc zero)))))")
   '("2N : Nat"))
  ;; Flat-map none
  (check-equal?
   (run-ns "(ns ofm2)\n(require [prologos.data.option :refer [Option none some flat-map unwrap-or]])\n(eval (unwrap-or Nat zero (flat-map Nat Nat (fn (x : Nat) (some Nat (suc x))) (none Nat))))")
   '("0N : Nat")))

(test-case "option/unwrap-or"
  (check-equal?
   (run-ns "(ns ou1)\n(require [prologos.data.option :refer [Option none some unwrap-or]])\n(eval (unwrap-or Nat (suc (suc zero)) (some Nat zero)))")
   '("0N : Nat"))
  (check-equal?
   (run-ns "(ns ou2)\n(require [prologos.data.option :refer [Option none some unwrap-or]])\n(eval (unwrap-or Nat (suc (suc zero)) (none Nat)))")
   '("2N : Nat")))

;; ========================================
;; prologos.data.result — Module Loading
;; ========================================

(test-case "load prologos.data.result"
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)])
    (install-module-loader!)
    (define mod (load-module 'prologos.data.result #f))
    (check-not-false (module-info? mod))
    (define exports (module-info-exports mod))
    (check-not-false (member 'Result exports) "exports Result")
    (check-not-false (member 'ok exports) "exports ok")
    (check-not-false (member 'err exports) "exports err")
    (check-not-false (member 'map exports) "exports map")
    (check-not-false (member 'map-err exports) "exports map-err")
    (check-not-false (member 'unwrap-or exports) "exports unwrap-or")))

;; ========================================
;; prologos.data.result — Constructors + Combinators
;; ========================================

(test-case "result/constructors"
  (check-equal?
   (run-ns "(ns rc1)\n(require [prologos.data.result :refer [Result ok err]])\n(check (ok Nat Bool zero) : (Result Nat Bool))")
   '("OK"))
  (check-equal?
   (run-ns "(ns rc2)\n(require [prologos.data.result :refer [Result ok err]])\n(check (err Nat Bool true) : (Result Nat Bool))")
   '("OK")))

(test-case "result/elimination"
  ;; Eliminate ok: extract value via match
  (check-equal?
   (run-ns "(ns re1)\n(require [prologos.data.result :refer [Result ok err]])\n(eval (the Nat (match (ok Nat Bool (suc zero)) (ok x -> (suc x)) (err e -> zero))))")
   '("2N : Nat"))
  ;; Eliminate err: handle error via match
  (check-equal?
   (run-ns "(ns re2)\n(require [prologos.data.result :refer [Result ok err]])\n(eval (the Nat (match (err Nat Bool true) (ok x -> (suc x)) (err e -> zero))))")
   '("0N : Nat")))

(test-case "result/map"
  ;; Auto-implicit order: A B E (first-occurrence in spec [A -> B] [Result A E] -> Result B E)
  (check-equal?
   (run-ns "(ns rm1)\n(require [prologos.data.result :refer [Result ok err map unwrap-or]])\n(eval (unwrap-or Nat Bool zero (map Nat Nat Bool (fn (x : Nat) (suc x)) (ok Nat Bool (suc zero)))))")
   '("2N : Nat"))
  (check-equal?
   (run-ns "(ns rm2)\n(require [prologos.data.result :refer [Result ok err map unwrap-or]])\n(eval (unwrap-or Nat Bool zero (map Nat Nat Bool (fn (x : Nat) (suc x)) (err Nat Bool false))))")
   '("0N : Nat")))

(test-case "result/unwrap-or"
  (check-equal?
   (run-ns "(ns ruo1)\n(require [prologos.data.result :refer [Result ok err unwrap-or]])\n(eval (unwrap-or Nat Bool (suc (suc zero)) (ok Nat Bool zero)))")
   '("0N : Nat"))
  (check-equal?
   (run-ns "(ns ruo2)\n(require [prologos.data.result :refer [Result ok err unwrap-or]])\n(eval (unwrap-or Nat Bool (suc (suc zero)) (err Nat Bool true)))")
   '("2N : Nat")))

;; ========================================
;; prologos.data.ordering — Module Loading + Tests
;; ========================================

(test-case "load prologos.data.ordering"
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)])
    (install-module-loader!)
    (define mod (load-module 'prologos.data.ordering #f))
    (check-not-false (module-info? mod))
    (define exports (module-info-exports mod))
    (check-not-false (member 'Ordering exports) "exports Ordering")
    (check-not-false (member 'lt-ord exports) "exports lt-ord")
    (check-not-false (member 'eq-ord exports) "exports eq-ord")
    (check-not-false (member 'gt-ord exports) "exports gt-ord")))

(test-case "ordering/constructors"
  (check-equal?
   (run-ns "(ns ord1)\n(require [prologos.data.ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(check lt-ord : Ordering)")
   '("OK"))
  (check-equal?
   (run-ns "(ns ord2)\n(require [prologos.data.ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(check eq-ord : Ordering)")
   '("OK"))
  (check-equal?
   (run-ns "(ns ord3)\n(require [prologos.data.ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(check gt-ord : Ordering)")
   '("OK")))

(test-case "ordering/elimination"
  ;; Each constructor selects the corresponding branch via match
  (check-equal?
   (run-ns "(ns oe1)\n(require [prologos.data.ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (the Nat (match lt-ord (lt-ord -> zero) (eq-ord -> (suc zero)) (gt-ord -> (suc (suc zero))))))")
   '("0N : Nat"))
  (check-equal?
   (run-ns "(ns oe2)\n(require [prologos.data.ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (the Nat (match eq-ord (lt-ord -> zero) (eq-ord -> (suc zero)) (gt-ord -> (suc (suc zero))))))")
   '("1N : Nat"))
  (check-equal?
   (run-ns "(ns oe3)\n(require [prologos.data.ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (the Nat (match gt-ord (lt-ord -> zero) (eq-ord -> (suc zero)) (gt-ord -> (suc (suc zero))))))")
   '("2N : Nat")))

;; ========================================
;; data keyword — Inline ADT definition
;; ========================================

(test-case "data/inline-enum"
  ;; Define and use an ADT inline (not from library)
  ;; data generates def forms, so we get "defined." messages
  (define result1
    (run-ns "(ns di1)\n(data (MyBool) (my-true) (my-false))\n(check my-true : MyBool)"))
  (check-equal? (last result1) "OK")
  ;; Eliminate via structural match
  (define result2
    (run-ns "(ns di2)\n(data (MyBool) (my-true) (my-false))\n(eval (the Nat (match my-true (my-true -> zero) (my-false -> (suc zero)))))"))
  (check-equal? (last result2) "0N : Nat")
  (define result3
    (run-ns "(ns di3)\n(data (MyBool) (my-true) (my-false))\n(eval (the Nat (match my-false (my-true -> zero) (my-false -> (suc zero)))))"))
  (check-equal? (last result3) "1N : Nat"))

(test-case "data/inline-parameterized"
  ;; Parameterized ADT
  (define result1
    (run-ns "(ns dp1)\n(data (Maybe (A : (Type 0))) (nothing) (just A))\n(check (nothing Nat) : (Maybe Nat))"))
  (check-equal? (last result1) "OK")
  (define result2
    (run-ns "(ns dp2)\n(data (Maybe (A : (Type 0))) (nothing) (just A))\n(check (just Nat zero) : (Maybe Nat))"))
  (check-equal? (last result2) "OK")
  ;; Eliminate via structural match
  (define result3
    (run-ns "(ns dp3)\n(data (Maybe (A : (Type 0))) (nothing) (just A))\n(eval (the Nat (match (just Nat (suc zero)) (nothing -> zero) (just x -> (suc x)))))"))
  (check-equal? (last result3) "2N : Nat"))

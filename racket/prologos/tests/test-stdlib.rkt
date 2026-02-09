#lang racket/base

;;;
;;; Tests for prologos standard library modules:
;;;   prologos.data.nat — natural number operations
;;;   prologos.data.bool — boolean operations
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
                 [current-preparse-registry (current-preparse-registry)])
    (install-module-loader!)
    (process-string s)))

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

(test-case "nat/add basic"
  ;; 0 + 0 = 0
  (check-equal?
   (run-ns "(ns t1)\n(require [prologos.data.nat :refer [add]])\n(eval (add zero zero))")
   '("zero : Nat"))
  ;; 0 + 3 = 3
  (check-equal?
   (run-ns "(ns t2)\n(require [prologos.data.nat :refer [add]])\n(eval (add zero (inc (inc (inc zero)))))")
   '("3 : Nat"))
  ;; 2 + 3 = 5
  (check-equal?
   (run-ns "(ns t3)\n(require [prologos.data.nat :refer [add]])\n(eval (add (inc (inc zero)) (inc (inc (inc zero)))))")
   '("5 : Nat")))

;; ========================================
;; prologos.data.nat — Multiplication
;; ========================================

(test-case "nat/mult basic"
  ;; 0 * 3 = 0
  (check-equal?
   (run-ns "(ns t4)\n(require [prologos.data.nat :refer [mult]])\n(eval (mult zero (inc (inc (inc zero)))))")
   '("zero : Nat"))
  ;; 2 * 3 = 6
  (check-equal?
   (run-ns "(ns t5)\n(require [prologos.data.nat :refer [mult]])\n(eval (mult (inc (inc zero)) (inc (inc (inc zero)))))")
   '("6 : Nat"))
  ;; 3 * 1 = 3
  (check-equal?
   (run-ns "(ns t6)\n(require [prologos.data.nat :refer [mult]])\n(eval (mult (inc (inc (inc zero))) (inc zero)))")
   '("3 : Nat")))

;; ========================================
;; prologos.data.nat — Double
;; ========================================

(test-case "nat/double"
  ;; double 0 = 0
  (check-equal?
   (run-ns "(ns t7)\n(require [prologos.data.nat :refer [double]])\n(eval (double zero))")
   '("zero : Nat"))
  ;; double 3 = 6
  (check-equal?
   (run-ns "(ns t8)\n(require [prologos.data.nat :refer [double]])\n(eval (double (inc (inc (inc zero)))))")
   '("6 : Nat")))

;; ========================================
;; prologos.data.nat — Predecessor
;; ========================================

(test-case "nat/pred"
  ;; pred 0 = 0
  (check-equal?
   (run-ns "(ns t9)\n(require [prologos.data.nat :refer [pred]])\n(eval (pred zero))")
   '("zero : Nat"))
  ;; pred 3 = 2
  (check-equal?
   (run-ns "(ns t10)\n(require [prologos.data.nat :refer [pred]])\n(eval (pred (inc (inc (inc zero)))))")
   '("2 : Nat"))
  ;; pred 1 = 0
  (check-equal?
   (run-ns "(ns t11)\n(require [prologos.data.nat :refer [pred]])\n(eval (pred (inc zero)))")
   '("zero : Nat")))

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
   (run-ns "(ns t13)\n(require [prologos.data.nat :refer [zero?]])\n(eval (zero? (inc zero)))")
   '("false : Bool")))

;; ========================================
;; prologos.data.nat — Alias access
;; ========================================

(test-case "nat module with :as alias"
  (check-equal?
   (run-ns "(ns t14)\n(require [prologos.data.nat :as nat])\n(eval (nat/add (inc zero) (inc (inc zero))))")
   '("3 : Nat")))

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

(test-case "bool/not"
  (check-equal?
   (run-ns "(ns t17)\n(require [prologos.data.bool :refer [not]])\n(eval (not true))")
   '("false : Bool"))
  (check-equal?
   (run-ns "(ns t18)\n(require [prologos.data.bool :refer [not]])\n(eval (not false))")
   '("true : Bool")))

;; ========================================
;; prologos.data.bool — AND
;; ========================================

(test-case "bool/and"
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
   (run-ns "(ns t36)\n(require [prologos.data.nat :refer [add zero?]])\n(require [prologos.data.bool :refer [not]])\n(eval (not (zero? (add (inc zero) (inc zero)))))")
   '("true : Bool")))

;; ========================================
;; prologos.data.bool — Alias access
;; ========================================

(test-case "bool module with :as alias"
  (check-equal?
   (run-ns "(ns t37)\n(require [prologos.data.bool :as bool])\n(eval (bool/not true))")
   '("false : Bool")))

;; ========================================
;; End-to-end: full multi-module example
;; ========================================

(test-case "end-to-end multi-module demo"
  (define result
    (run-ns "(ns demo.test)
             (require [prologos.data.nat :as nat])
             (require [prologos.data.bool :refer [not and]])
             (def four <Nat> (nat/add (inc (inc zero)) (inc (inc zero))))
             (eval four)
             (eval (not true))
             (eval (and true false))"))
  (check-equal? (length result) 4)
  (check-equal? (list-ref result 0) "four : Nat defined.")
  (check-equal? (list-ref result 1) "4 : Nat")
  (check-equal? (list-ref result 2) "false : Bool")
  (check-equal? (list-ref result 3) "false : Bool"))

;; ========================================
;; prologos.data.nat — Subtraction
;; ========================================

(test-case "nat/sub"
  ;; sub(0, 0) = 0
  (check-equal?
   (run-ns "(ns ts1)\n(require [prologos.data.nat :refer [sub]])\n(eval (sub zero zero))")
   '("zero : Nat"))
  ;; sub(3, 0) = 3
  (check-equal?
   (run-ns "(ns ts2)\n(require [prologos.data.nat :refer [sub]])\n(eval (sub (inc (inc (inc zero))) zero))")
   '("3 : Nat"))
  ;; sub(0, 3) = 0 (saturating)
  (check-equal?
   (run-ns "(ns ts3)\n(require [prologos.data.nat :refer [sub]])\n(eval (sub zero (inc (inc (inc zero)))))")
   '("zero : Nat"))
  ;; sub(5, 3) = 2
  (check-equal?
   (run-ns "(ns ts4)\n(require [prologos.data.nat :refer [sub]])\n(eval (sub (inc (inc (inc (inc (inc zero))))) (inc (inc (inc zero)))))")
   '("2 : Nat"))
  ;; sub(3, 5) = 0 (saturating)
  (check-equal?
   (run-ns "(ns ts5)\n(require [prologos.data.nat :refer [sub]])\n(eval (sub (inc (inc (inc zero))) (inc (inc (inc (inc (inc zero)))))))")
   '("zero : Nat"))
  ;; sub(3, 3) = 0
  (check-equal?
   (run-ns "(ns ts6)\n(require [prologos.data.nat :refer [sub]])\n(eval (sub (inc (inc (inc zero))) (inc (inc (inc zero)))))")
   '("zero : Nat")))

;; ========================================
;; prologos.data.nat — Comparisons
;; ========================================

(test-case "nat/le?"
  (check-equal?
   (run-ns "(ns tc1)\n(require [prologos.data.nat :refer [le?]])\n(eval (le? zero zero))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns tc2)\n(require [prologos.data.nat :refer [le?]])\n(eval (le? zero (inc (inc (inc zero)))))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns tc3)\n(require [prologos.data.nat :refer [le?]])\n(eval (le? (inc (inc (inc zero))) (inc (inc (inc (inc (inc zero)))))))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns tc4)\n(require [prologos.data.nat :refer [le?]])\n(eval (le? (inc (inc (inc (inc (inc zero))))) (inc (inc (inc zero)))))")
   '("false : Bool"))
  (check-equal?
   (run-ns "(ns tc5)\n(require [prologos.data.nat :refer [le?]])\n(eval (le? (inc (inc (inc zero))) (inc (inc (inc zero)))))")
   '("true : Bool")))

(test-case "nat/lt?"
  (check-equal?
   (run-ns "(ns tc6)\n(require [prologos.data.nat :refer [lt?]])\n(eval (lt? zero zero))")
   '("false : Bool"))
  (check-equal?
   (run-ns "(ns tc7)\n(require [prologos.data.nat :refer [lt?]])\n(eval (lt? zero (inc (inc (inc zero)))))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns tc8)\n(require [prologos.data.nat :refer [lt?]])\n(eval (lt? (inc (inc (inc (inc (inc zero))))) (inc (inc (inc zero)))))")
   '("false : Bool"))
  (check-equal?
   (run-ns "(ns tc9)\n(require [prologos.data.nat :refer [lt?]])\n(eval (lt? (inc (inc (inc zero))) (inc (inc (inc zero)))))")
   '("false : Bool")))

(test-case "nat/gt?"
  (check-equal?
   (run-ns "(ns tc10)\n(require [prologos.data.nat :refer [gt?]])\n(eval (gt? (inc (inc (inc (inc (inc zero))))) (inc (inc (inc zero)))))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns tc11)\n(require [prologos.data.nat :refer [gt?]])\n(eval (gt? zero (inc zero)))")
   '("false : Bool")))

(test-case "nat/ge?"
  (check-equal?
   (run-ns "(ns tc12)\n(require [prologos.data.nat :refer [ge?]])\n(eval (ge? (inc (inc (inc zero))) (inc (inc (inc zero)))))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns tc13)\n(require [prologos.data.nat :refer [ge?]])\n(eval (ge? (inc zero) (inc (inc zero))))")
   '("false : Bool")))

(test-case "nat/nat-eq?"
  (check-equal?
   (run-ns "(ns tc14)\n(require [prologos.data.nat :refer [nat-eq?]])\n(eval (nat-eq? zero zero))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns tc15)\n(require [prologos.data.nat :refer [nat-eq?]])\n(eval (nat-eq? (inc (inc (inc zero))) (inc (inc (inc zero)))))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns tc16)\n(require [prologos.data.nat :refer [nat-eq?]])\n(eval (nat-eq? (inc (inc (inc zero))) (inc (inc (inc (inc (inc zero)))))))")
   '("false : Bool"))
  (check-equal?
   (run-ns "(ns tc17)\n(require [prologos.data.nat :refer [nat-eq?]])\n(eval (nat-eq? (inc (inc (inc (inc (inc zero))))) (inc (inc (inc zero)))))")
   '("false : Bool")))

;; ========================================
;; prologos.data.nat — Min/Max
;; ========================================

(test-case "nat/min"
  (check-equal?
   (run-ns "(ns tm1)\n(require [prologos.data.nat :refer [min]])\n(eval (min (inc (inc (inc (inc (inc zero))))) (inc (inc (inc zero)))))")
   '("3 : Nat"))
  (check-equal?
   (run-ns "(ns tm2)\n(require [prologos.data.nat :refer [min]])\n(eval (min (inc (inc zero)) (inc (inc (inc (inc (inc zero)))))))")
   '("2 : Nat"))
  (check-equal?
   (run-ns "(ns tm3)\n(require [prologos.data.nat :refer [min]])\n(eval (min (inc (inc (inc zero))) (inc (inc (inc zero)))))")
   '("3 : Nat")))

(test-case "nat/max"
  (check-equal?
   (run-ns "(ns tm4)\n(require [prologos.data.nat :refer [max]])\n(eval (max (inc (inc (inc (inc (inc zero))))) (inc (inc (inc zero)))))")
   '("5 : Nat"))
  (check-equal?
   (run-ns "(ns tm5)\n(require [prologos.data.nat :refer [max]])\n(eval (max (inc (inc zero)) (inc (inc (inc (inc (inc zero)))))))")
   '("5 : Nat"))
  (check-equal?
   (run-ns "(ns tm6)\n(require [prologos.data.nat :refer [max]])\n(eval (max (inc (inc (inc zero))) (inc (inc (inc zero)))))")
   '("3 : Nat")))

;; ========================================
;; prologos.data.nat — Power
;; ========================================

(test-case "nat/power"
  (check-equal?
   (run-ns "(ns tp1)\n(require [prologos.data.nat :refer [power]])\n(eval (power (inc (inc zero)) zero))")
   '("1 : Nat"))
  (check-equal?
   (run-ns "(ns tp2)\n(require [prologos.data.nat :refer [power]])\n(eval (power (inc (inc zero)) (inc (inc (inc zero)))))")
   '("8 : Nat"))
  (check-equal?
   (run-ns "(ns tp3)\n(require [prologos.data.nat :refer [power]])\n(eval (power (inc (inc (inc zero))) (inc (inc zero))))")
   '("9 : Nat"))
  (check-equal?
   (run-ns "(ns tp4)\n(require [prologos.data.nat :refer [power]])\n(eval (power zero (inc (inc (inc (inc (inc zero)))))))")
   '("zero : Nat")))

;; ========================================
;; prologos.data.nat — bool-to-nat
;; ========================================

(test-case "nat/bool-to-nat"
  (check-equal?
   (run-ns "(ns tb1)\n(require [prologos.data.nat :refer [bool-to-nat]])\n(eval (bool-to-nat true))")
   '("1 : Nat"))
  (check-equal?
   (run-ns "(ns tb2)\n(require [prologos.data.nat :refer [bool-to-nat]])\n(eval (bool-to-nat false))")
   '("zero : Nat")))

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
   (run-ns "(ns tt5)\n(require [prologos.data.nat :refer [power]])\n(check power <(-> Nat (-> Nat Nat))>)")
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
    (check-not-false (member 'power exports) "exports power")
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
   '("zero : Nat")))

;; ========================================
;; prologos.data.pair — map-fst
;; ========================================

(test-case "pair/map-fst"
  (check-equal?
   (run-ns "(ns pm1)\n(require [prologos.data.pair :refer [map-fst]])\n(eval (first (map-fst Nat Bool Nat (fn (x : Nat) (inc x)) (pair zero true))))")
   '("1 : Nat"))
  (check-equal?
   (run-ns "(ns pm2)\n(require [prologos.data.pair :refer [map-fst]])\n(eval (second (map-fst Nat Bool Nat (fn (x : Nat) (inc x)) (pair zero true))))")
   '("true : Bool")))

;; ========================================
;; prologos.data.pair — map-snd
;; ========================================

(test-case "pair/map-snd"
  (check-equal?
   (run-ns "(ns pm3)\n(require [prologos.data.pair :refer [map-snd]])\n(eval (first (map-snd Nat Bool Nat (fn (b : Bool) zero) (pair (inc zero) true))))")
   '("1 : Nat"))
  (check-equal?
   (run-ns "(ns pm4)\n(require [prologos.data.pair :refer [map-snd]])\n(eval (second (map-snd Nat Bool Nat (fn (b : Bool) zero) (pair (inc zero) true))))")
   '("zero : Nat")))

;; ========================================
;; prologos.data.pair — bimap
;; ========================================

(test-case "pair/bimap"
  (check-equal?
   (run-ns "(ns pb1)\n(require [prologos.data.pair :refer [bimap]])\n(eval (first (bimap Nat Bool Nat Bool (fn (x : Nat) (inc x)) (fn (b : Bool) (boolrec Bool false true b)) (pair (inc zero) true))))")
   '("2 : Nat"))
  (check-equal?
   (run-ns "(ns pb2)\n(require [prologos.data.pair :refer [bimap]])\n(eval (second (bimap Nat Bool Nat Bool (fn (x : Nat) (inc x)) (fn (b : Bool) (boolrec Bool false true b)) (pair (inc zero) true))))")
   '("false : Bool")))

;; ========================================
;; prologos.core — on combinator
;; ========================================

(test-case "core/on"
  ;; (on nat-eq? id) should compare two nats for equality: on(nat-eq?, id, 3, 3) = true
  (check-equal?
   (run-ns "(ns co1)\n(require [prologos.data.nat :refer [nat-eq?]])\n(eval (on Nat Nat Bool nat-eq? (fn (x : Nat) x) (inc (inc (inc zero))) (inc (inc (inc zero)))))")
   '("true : Bool"))
  ;; on(nat-eq?, id, 2, 3) = false
  (check-equal?
   (run-ns "(ns co2)\n(require [prologos.data.nat :refer [nat-eq?]])\n(eval (on Nat Nat Bool nat-eq? (fn (x : Nat) x) (inc (inc zero)) (inc (inc (inc zero)))))")
   '("false : Bool")))

;; ========================================
;; Cross-module tests with new functions
;; ========================================

(test-case "cross-module: sub + le? + not"
  (check-equal?
   (run-ns "(ns cx1)\n(require [prologos.data.nat :refer [sub le?]])\n(require [prologos.data.bool :refer [not]])\n(eval (not (le? (inc (inc (inc (inc (inc zero))))) (inc (inc (inc zero))))))")
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
   (run-ns "(ns es2)\n(require [prologos.data.eq :refer [sym]])\n(check (sym Nat (inc zero) (inc zero) (the (Eq Nat (inc zero) (inc zero)) refl)) : (Eq Nat (inc zero) (inc zero)))")
   '("OK"))
  ;; sym evaluates to refl
  (check-equal?
   (run-ns "(ns es3)\n(require [prologos.data.eq :refer [sym]])\n(eval (sym Nat zero zero (the (Eq Nat zero zero) refl)))")
   '("refl : (Eq Nat zero zero)")))

;; ========================================
;; prologos.data.eq — cong (congruence)
;; ========================================

(test-case "eq/cong"
  ;; cong inc : Eq(Nat, 0, 0) -> Eq(Nat, 1, 1)
  (check-equal?
   (run-ns "(ns ec1)\n(require [prologos.data.eq :refer [cong]])\n(check (cong Nat Nat zero zero (fn (x : Nat) (inc x)) (the (Eq Nat zero zero) refl)) : (Eq Nat (inc zero) (inc zero)))")
   '("OK"))
  ;; cong evaluates to refl
  (check-equal?
   (run-ns "(ns ec2)\n(require [prologos.data.eq :refer [cong]])\n(eval (cong Nat Nat zero zero (fn (x : Nat) (inc x)) (the (Eq Nat zero zero) refl)))")
   '("refl : (Eq Nat 1 1)")))

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
   '("refl : (Eq Nat zero zero)")))

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
    (check-not-false (member 'option-map exports) "exports option-map")
    (check-not-false (member 'option-flat-map exports) "exports option-flat-map")
    (check-not-false (member 'option-unwrap-or exports) "exports option-unwrap-or")))

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
  ;; Eliminate some: extract value
  (check-equal?
   (run-ns "(ns oe1)\n(require [prologos.data.option :refer [Option none some]])\n(eval ((some Nat (inc zero)) Nat zero (fn (x : Nat) (inc x))))")
   '("2 : Nat"))
  ;; Eliminate none: get default
  (check-equal?
   (run-ns "(ns oe2)\n(require [prologos.data.option :refer [Option none some]])\n(eval ((none Nat) Nat (inc (inc zero)) (fn (x : Nat) (inc x))))")
   '("2 : Nat")))

;; ========================================
;; prologos.data.option — Combinators
;; ========================================

(test-case "option/option-map"
  ;; Map over some
  (check-equal?
   (run-ns "(ns om1)\n(require [prologos.data.option :refer [Option none some option-map option-unwrap-or]])\n(eval (option-unwrap-or Nat zero (option-map Nat Nat (fn (x : Nat) (inc x)) (some Nat (inc zero)))))")
   '("2 : Nat"))
  ;; Map over none
  (check-equal?
   (run-ns "(ns om2)\n(require [prologos.data.option :refer [Option none some option-map option-unwrap-or]])\n(eval (option-unwrap-or Nat zero (option-map Nat Nat (fn (x : Nat) (inc x)) (none Nat))))")
   '("zero : Nat")))

(test-case "option/option-flat-map"
  ;; Flat-map some -> some
  (check-equal?
   (run-ns "(ns ofm1)\n(require [prologos.data.option :refer [Option none some option-flat-map option-unwrap-or]])\n(eval (option-unwrap-or Nat zero (option-flat-map Nat Nat (fn (x : Nat) (some Nat (inc x))) (some Nat (inc zero)))))")
   '("2 : Nat"))
  ;; Flat-map none
  (check-equal?
   (run-ns "(ns ofm2)\n(require [prologos.data.option :refer [Option none some option-flat-map option-unwrap-or]])\n(eval (option-unwrap-or Nat zero (option-flat-map Nat Nat (fn (x : Nat) (some Nat (inc x))) (none Nat))))")
   '("zero : Nat")))

(test-case "option/option-unwrap-or"
  (check-equal?
   (run-ns "(ns ou1)\n(require [prologos.data.option :refer [Option none some option-unwrap-or]])\n(eval (option-unwrap-or Nat (inc (inc zero)) (some Nat zero)))")
   '("zero : Nat"))
  (check-equal?
   (run-ns "(ns ou2)\n(require [prologos.data.option :refer [Option none some option-unwrap-or]])\n(eval (option-unwrap-or Nat (inc (inc zero)) (none Nat)))")
   '("2 : Nat")))

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
    (check-not-false (member 'result-map exports) "exports result-map")
    (check-not-false (member 'result-map-err exports) "exports result-map-err")
    (check-not-false (member 'result-unwrap-or exports) "exports result-unwrap-or")))

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
  ;; Eliminate ok: extract value
  (check-equal?
   (run-ns "(ns re1)\n(require [prologos.data.result :refer [Result ok err]])\n(eval ((ok Nat Bool (inc zero)) Nat (fn (x : Nat) (inc x)) (fn (e : Bool) zero)))")
   '("2 : Nat"))
  ;; Eliminate err: handle error
  (check-equal?
   (run-ns "(ns re2)\n(require [prologos.data.result :refer [Result ok err]])\n(eval ((err Nat Bool true) Nat (fn (x : Nat) (inc x)) (fn (e : Bool) zero)))")
   '("zero : Nat")))

(test-case "result/result-map"
  (check-equal?
   (run-ns "(ns rm1)\n(require [prologos.data.result :refer [Result ok err result-map result-unwrap-or]])\n(eval (result-unwrap-or Nat Bool zero (result-map Nat Bool Nat (fn (x : Nat) (inc x)) (ok Nat Bool (inc zero)))))")
   '("2 : Nat"))
  (check-equal?
   (run-ns "(ns rm2)\n(require [prologos.data.result :refer [Result ok err result-map result-unwrap-or]])\n(eval (result-unwrap-or Nat Bool zero (result-map Nat Bool Nat (fn (x : Nat) (inc x)) (err Nat Bool false))))")
   '("zero : Nat")))

(test-case "result/result-unwrap-or"
  (check-equal?
   (run-ns "(ns ruo1)\n(require [prologos.data.result :refer [Result ok err result-unwrap-or]])\n(eval (result-unwrap-or Nat Bool (inc (inc zero)) (ok Nat Bool zero)))")
   '("zero : Nat"))
  (check-equal?
   (run-ns "(ns ruo2)\n(require [prologos.data.result :refer [Result ok err result-unwrap-or]])\n(eval (result-unwrap-or Nat Bool (inc (inc zero)) (err Nat Bool true)))")
   '("2 : Nat")))

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
  ;; Each constructor selects the corresponding branch
  (check-equal?
   (run-ns "(ns oe1)\n(require [prologos.data.ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (lt-ord Nat zero (inc zero) (inc (inc zero))))")
   '("zero : Nat"))
  (check-equal?
   (run-ns "(ns oe2)\n(require [prologos.data.ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (eq-ord Nat zero (inc zero) (inc (inc zero))))")
   '("1 : Nat"))
  (check-equal?
   (run-ns "(ns oe3)\n(require [prologos.data.ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (gt-ord Nat zero (inc zero) (inc (inc zero))))")
   '("2 : Nat")))

;; ========================================
;; data keyword — Inline ADT definition
;; ========================================

(test-case "data/inline-enum"
  ;; Define and use an ADT inline (not from library)
  ;; data generates def forms, so we get "defined." messages
  (define result1
    (run-ns "(ns di1)\n(data (MyBool) (my-true) (my-false))\n(check my-true : MyBool)"))
  (check-equal? (last result1) "OK")
  (define result2
    (run-ns "(ns di2)\n(data (MyBool) (my-true) (my-false))\n(eval (my-true Nat zero (inc zero)))"))
  (check-equal? (last result2) "zero : Nat")
  (define result3
    (run-ns "(ns di3)\n(data (MyBool) (my-true) (my-false))\n(eval (my-false Nat zero (inc zero)))"))
  (check-equal? (last result3) "1 : Nat"))

(test-case "data/inline-parameterized"
  ;; Parameterized ADT
  (define result1
    (run-ns "(ns dp1)\n(data (Maybe (A : (Type 0))) (nothing) (just A))\n(check (nothing Nat) : (Maybe Nat))"))
  (check-equal? (last result1) "OK")
  (define result2
    (run-ns "(ns dp2)\n(data (Maybe (A : (Type 0))) (nothing) (just A))\n(check (just Nat zero) : (Maybe Nat))"))
  (check-equal? (last result2) "OK")
  (define result3
    (run-ns "(ns dp3)\n(data (Maybe (A : (Type 0))) (nothing) (just A))\n(eval ((just Nat (inc zero)) Nat zero (fn (x : Nat) (inc x))))"))
  (check-equal? (last result3) "2 : Nat"))

;; ========================================
;; match keyword — Pattern matching on Church-encoded ADTs
;; ========================================

;; --- match on Option ---

(test-case "match/option-some"
  ;; Match on some: extract the value
  (check-equal?
   (run-ns "(ns mo1)\n(require [prologos.data.option :refer [Option none some]])\n(eval (match (some Nat zero) Nat (none (inc zero)) (some (x : Nat) x)))")
   '("zero : Nat")))

(test-case "match/option-none"
  ;; Match on none: use default
  (check-equal?
   (run-ns "(ns mo2)\n(require [prologos.data.option :refer [Option none some]])\n(eval (match (none Nat) Nat (none (inc zero)) (some (x : Nat) x)))")
   '("1 : Nat")))

(test-case "match/option-some-transform"
  ;; Match on some: transform the value
  (check-equal?
   (run-ns "(ns mo3)\n(require [prologos.data.option :refer [Option none some]])\n(eval (match (some Nat (inc (inc zero))) Nat (none zero) (some (x : Nat) (inc x))))")
   '("3 : Nat")))

;; --- match on Result ---

(test-case "match/result-ok"
  ;; Match on ok: extract value
  (check-equal?
   (run-ns "(ns mr1)\n(require [prologos.data.result :refer [Result ok err]])\n(eval (match (ok Nat Bool zero) Nat (ok (x : Nat) x) (err (e : Bool) (inc zero))))")
   '("zero : Nat")))

(test-case "match/result-err"
  ;; Match on err: use error branch
  (check-equal?
   (run-ns "(ns mr2)\n(require [prologos.data.result :refer [Result ok err]])\n(eval (match (err Nat Bool true) Nat (ok (x : Nat) x) (err (e : Bool) (inc zero))))")
   '("1 : Nat")))

(test-case "match/result-err-use-value"
  ;; Match on err: use the error value
  ;; Convert Bool to Nat using boolrec
  (check-equal?
   (run-ns "(ns mr3)\n(require [prologos.data.result :refer [Result ok err]])\n(eval (match (err Nat Bool true) Nat (ok (x : Nat) x) (err (e : Bool) (boolrec Nat (inc (inc zero)) zero e))))")
   '("2 : Nat")))

;; --- match on Ordering ---

(test-case "match/ordering-lt"
  (check-equal?
   (run-ns "(ns mord1)\n(require [prologos.data.ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (match lt-ord Nat (lt-ord zero) (eq-ord (inc zero)) (gt-ord (inc (inc zero)))))")
   '("zero : Nat")))

(test-case "match/ordering-eq"
  (check-equal?
   (run-ns "(ns mord2)\n(require [prologos.data.ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (match eq-ord Nat (lt-ord zero) (eq-ord (inc zero)) (gt-ord (inc (inc zero)))))")
   '("1 : Nat")))

(test-case "match/ordering-gt"
  (check-equal?
   (run-ns "(ns mord3)\n(require [prologos.data.ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (match gt-ord Nat (lt-ord zero) (eq-ord (inc zero)) (gt-ord (inc (inc zero)))))")
   '("2 : Nat")))

;; --- match on inline ADTs ---

(test-case "match/inline-enum"
  ;; Define and match on an inline enum
  (check-equal?
   (last (run-ns "(ns mi1)\n(data (Color) (red) (green) (blue))\n(eval (match red Nat (red zero) (green (inc zero)) (blue (inc (inc zero)))))"))
   "zero : Nat")
  (check-equal?
   (last (run-ns "(ns mi2)\n(data (Color) (red) (green) (blue))\n(eval (match blue Nat (red zero) (green (inc zero)) (blue (inc (inc zero)))))"))
   "2 : Nat"))

(test-case "match/inline-parameterized"
  ;; Define and match on a parameterized ADT
  (check-equal?
   (last (run-ns "(ns mi3)\n(data (Maybe (A : (Type 0))) (nothing) (just A))\n(eval (match (just Nat (inc (inc zero))) Nat (nothing zero) (just (x : Nat) x)))"))
   "2 : Nat")
  (check-equal?
   (last (run-ns "(ns mi4)\n(data (Maybe (A : (Type 0))) (nothing) (just A))\n(eval (match (nothing Nat) Nat (nothing zero) (just (x : Nat) x)))"))
   "zero : Nat"))

;; --- match inside def ---

(test-case "match/inside-def"
  ;; Use match inside a function definition
  (check-equal?
   (last (run-ns "(ns md1)\n(require [prologos.data.option :refer [Option none some]])\n(def unwrap : (Pi (A :0 (Type 0)) (-> A (-> (Option A) A)))\n  (fn (A :0 (Type 0)) (fn (default : A) (fn (opt : (Option A))\n    (match opt A (none default) (some (x : A) x))))))\n(eval (unwrap Nat (inc (inc zero)) (some Nat zero)))"))
   "zero : Nat")
  (check-equal?
   (last (run-ns "(ns md2)\n(require [prologos.data.option :refer [Option none some]])\n(def unwrap : (Pi (A :0 (Type 0)) (-> A (-> (Option A) A)))\n  (fn (A :0 (Type 0)) (fn (default : A) (fn (opt : (Option A))\n    (match opt A (none default) (some (x : A) x))))))\n(eval (unwrap Nat (inc (inc zero)) (none Nat)))"))
   "2 : Nat"))

;; --- match with library's match-based functions ---

(test-case "match/library-option-unwrap-or"
  ;; option-unwrap-or is now implemented with match
  (check-equal?
   (run-ns "(ns mlu1)\n(require [prologos.data.option :refer [Option none some option-unwrap-or]])\n(eval (option-unwrap-or Nat (inc (inc zero)) (some Nat zero)))")
   '("zero : Nat"))
  (check-equal?
   (run-ns "(ns mlu2)\n(require [prologos.data.option :refer [Option none some option-unwrap-or]])\n(eval (option-unwrap-or Nat (inc (inc zero)) (none Nat)))")
   '("2 : Nat")))

(test-case "match/library-result-unwrap-or"
  ;; result-unwrap-or is now implemented with match
  (check-equal?
   (run-ns "(ns mlu3)\n(require [prologos.data.result :refer [Result ok err result-unwrap-or]])\n(eval (result-unwrap-or Nat Bool (inc (inc zero)) (ok Nat Bool zero)))")
   '("zero : Nat"))
  (check-equal?
   (run-ns "(ns mlu4)\n(require [prologos.data.result :refer [Result ok err result-unwrap-or]])\n(eval (result-unwrap-or Nat Bool (inc (inc zero)) (err Nat Bool true)))")
   '("2 : Nat")))

;; --- match on Bool (boolrec replacement) ---

(test-case "match/bool-as-adt"
  ;; Define Bool-like ADT and match on it
  (check-equal?
   (last (run-ns "(ns mb1)\n(data (MyBool) (my-true) (my-false))\n(eval (match my-true Nat (my-true (inc zero)) (my-false zero)))"))
   "1 : Nat")
  (check-equal?
   (last (run-ns "(ns mb2)\n(data (MyBool) (my-true) (my-false))\n(eval (match my-false Nat (my-true (inc zero)) (my-false zero)))"))
   "zero : Nat"))

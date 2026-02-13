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
                 [current-preparse-registry (current-preparse-registry)]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)])
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
    (check-not-false (member 'dec exports) "exports dec")
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

(test-case "nat/dec"
  ;; dec 0 = 0
  (check-equal?
   (run-ns "(ns t9)\n(require [prologos.data.nat :refer [dec]])\n(eval (dec zero))")
   '("zero : Nat"))
  ;; dec 3 = 2
  (check-equal?
   (run-ns "(ns t10)\n(require [prologos.data.nat :refer [dec]])\n(eval (dec (inc (inc (inc zero)))))")
   '("2 : Nat"))
  ;; dec 1 = 0
  (check-equal?
   (run-ns "(ns t11)\n(require [prologos.data.nat :refer [dec]])\n(eval (dec (inc zero)))")
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

(test-case "nat/pow"
  (check-equal?
   (run-ns "(ns tp1)\n(require [prologos.data.nat :refer [pow]])\n(eval (pow (inc (inc zero)) zero))")
   '("1 : Nat"))
  (check-equal?
   (run-ns "(ns tp2)\n(require [prologos.data.nat :refer [pow]])\n(eval (pow (inc (inc zero)) (inc (inc (inc zero)))))")
   '("8 : Nat"))
  (check-equal?
   (run-ns "(ns tp3)\n(require [prologos.data.nat :refer [pow]])\n(eval (pow (inc (inc (inc zero))) (inc (inc zero))))")
   '("9 : Nat"))
  (check-equal?
   (run-ns "(ns tp4)\n(require [prologos.data.nat :refer [pow]])\n(eval (pow zero (inc (inc (inc (inc (inc zero)))))))")
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
   (run-ns "(ns oe1)\n(require [prologos.data.option :refer [Option none some]])\n(eval (the Nat (match (some Nat (inc zero)) (none -> zero) (some x -> (inc x)))))")
   '("2 : Nat"))
  ;; Eliminate none: get default via match
  (check-equal?
   (run-ns "(ns oe2)\n(require [prologos.data.option :refer [Option none some]])\n(eval (the Nat (match (none Nat) (none -> (inc (inc zero))) (some x -> (inc x)))))")
   '("2 : Nat")))

;; ========================================
;; prologos.data.option — Combinators
;; ========================================

(test-case "option/map"
  ;; Map over some
  (check-equal?
   (run-ns "(ns om1)\n(require [prologos.data.option :refer [Option none some map unwrap-or]])\n(eval (unwrap-or Nat zero (map Nat Nat (fn (x : Nat) (inc x)) (some Nat (inc zero)))))")
   '("2 : Nat"))
  ;; Map over none
  (check-equal?
   (run-ns "(ns om2)\n(require [prologos.data.option :refer [Option none some map unwrap-or]])\n(eval (unwrap-or Nat zero (map Nat Nat (fn (x : Nat) (inc x)) (none Nat))))")
   '("zero : Nat")))

(test-case "option/flat-map"
  ;; Flat-map some -> some
  (check-equal?
   (run-ns "(ns ofm1)\n(require [prologos.data.option :refer [Option none some flat-map unwrap-or]])\n(eval (unwrap-or Nat zero (flat-map Nat Nat (fn (x : Nat) (some Nat (inc x))) (some Nat (inc zero)))))")
   '("2 : Nat"))
  ;; Flat-map none
  (check-equal?
   (run-ns "(ns ofm2)\n(require [prologos.data.option :refer [Option none some flat-map unwrap-or]])\n(eval (unwrap-or Nat zero (flat-map Nat Nat (fn (x : Nat) (some Nat (inc x))) (none Nat))))")
   '("zero : Nat")))

(test-case "option/unwrap-or"
  (check-equal?
   (run-ns "(ns ou1)\n(require [prologos.data.option :refer [Option none some unwrap-or]])\n(eval (unwrap-or Nat (inc (inc zero)) (some Nat zero)))")
   '("zero : Nat"))
  (check-equal?
   (run-ns "(ns ou2)\n(require [prologos.data.option :refer [Option none some unwrap-or]])\n(eval (unwrap-or Nat (inc (inc zero)) (none Nat)))")
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
   (run-ns "(ns re1)\n(require [prologos.data.result :refer [Result ok err]])\n(eval (the Nat (match (ok Nat Bool (inc zero)) (ok x -> (inc x)) (err e -> zero))))")
   '("2 : Nat"))
  ;; Eliminate err: handle error via match
  (check-equal?
   (run-ns "(ns re2)\n(require [prologos.data.result :refer [Result ok err]])\n(eval (the Nat (match (err Nat Bool true) (ok x -> (inc x)) (err e -> zero))))")
   '("zero : Nat")))

(test-case "result/map"
  (check-equal?
   (run-ns "(ns rm1)\n(require [prologos.data.result :refer [Result ok err map unwrap-or]])\n(eval (unwrap-or Nat Bool zero (map Nat Bool Nat (fn (x : Nat) (inc x)) (ok Nat Bool (inc zero)))))")
   '("2 : Nat"))
  (check-equal?
   (run-ns "(ns rm2)\n(require [prologos.data.result :refer [Result ok err map unwrap-or]])\n(eval (unwrap-or Nat Bool zero (map Nat Bool Nat (fn (x : Nat) (inc x)) (err Nat Bool false))))")
   '("zero : Nat")))

(test-case "result/unwrap-or"
  (check-equal?
   (run-ns "(ns ruo1)\n(require [prologos.data.result :refer [Result ok err unwrap-or]])\n(eval (unwrap-or Nat Bool (inc (inc zero)) (ok Nat Bool zero)))")
   '("zero : Nat"))
  (check-equal?
   (run-ns "(ns ruo2)\n(require [prologos.data.result :refer [Result ok err unwrap-or]])\n(eval (unwrap-or Nat Bool (inc (inc zero)) (err Nat Bool true)))")
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
  ;; Each constructor selects the corresponding branch via match
  (check-equal?
   (run-ns "(ns oe1)\n(require [prologos.data.ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (the Nat (match lt-ord (lt-ord -> zero) (eq-ord -> (inc zero)) (gt-ord -> (inc (inc zero))))))")
   '("zero : Nat"))
  (check-equal?
   (run-ns "(ns oe2)\n(require [prologos.data.ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (the Nat (match eq-ord (lt-ord -> zero) (eq-ord -> (inc zero)) (gt-ord -> (inc (inc zero))))))")
   '("1 : Nat"))
  (check-equal?
   (run-ns "(ns oe3)\n(require [prologos.data.ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (the Nat (match gt-ord (lt-ord -> zero) (eq-ord -> (inc zero)) (gt-ord -> (inc (inc zero))))))")
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
  ;; Eliminate via structural match
  (define result2
    (run-ns "(ns di2)\n(data (MyBool) (my-true) (my-false))\n(eval (the Nat (match my-true (my-true -> zero) (my-false -> (inc zero)))))"))
  (check-equal? (last result2) "zero : Nat")
  (define result3
    (run-ns "(ns di3)\n(data (MyBool) (my-true) (my-false))\n(eval (the Nat (match my-false (my-true -> zero) (my-false -> (inc zero)))))"))
  (check-equal? (last result3) "1 : Nat"))

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
    (run-ns "(ns dp3)\n(data (Maybe (A : (Type 0))) (nothing) (just A))\n(eval (the Nat (match (just Nat (inc zero)) (nothing -> zero) (just x -> (inc x)))))"))
  (check-equal? (last result3) "2 : Nat"))

;; ========================================
;; match keyword — Structural pattern matching on ADTs
;; (using the | ctor args -> body syntax)
;; ========================================

;; --- match on Option ---

(test-case "match/option-some"
  ;; Match on some: extract the value
  (check-equal?
   (run-ns "(ns mo1)\n(require [prologos.data.option :refer [Option none some]])\n(eval (the Nat (match (some Nat zero) (none -> (inc zero)) (some x -> x))))")
   '("zero : Nat")))

(test-case "match/option-none"
  ;; Match on none: use default
  (check-equal?
   (run-ns "(ns mo2)\n(require [prologos.data.option :refer [Option none some]])\n(eval (the Nat (match (none Nat) (none -> (inc zero)) (some x -> x))))")
   '("1 : Nat")))

(test-case "match/option-some-transform"
  ;; Match on some: transform the value
  (check-equal?
   (run-ns "(ns mo3)\n(require [prologos.data.option :refer [Option none some]])\n(eval (the Nat (match (some Nat (inc (inc zero))) (none -> zero) (some x -> (inc x)))))")
   '("3 : Nat")))

;; --- match on Result ---

(test-case "match/result-ok"
  ;; Match on ok: extract value
  (check-equal?
   (run-ns "(ns mr1)\n(require [prologos.data.result :refer [Result ok err]])\n(eval (the Nat (match (ok Nat Bool zero) (ok x -> x) (err _ -> (inc zero)))))")
   '("zero : Nat")))

(test-case "match/result-err"
  ;; Match on err: use error branch
  (check-equal?
   (run-ns "(ns mr2)\n(require [prologos.data.result :refer [Result ok err]])\n(eval (the Nat (match (err Nat Bool true) (ok x -> (inc zero)) (err _ -> (inc zero)))))")
   '("1 : Nat")))

(test-case "match/result-err-use-value"
  ;; Match on err: use the error value
  ;; Convert Bool to Nat using boolrec
  (check-equal?
   (run-ns "(ns mr3)\n(require [prologos.data.result :refer [Result ok err]])\n(eval (the Nat (match (err Nat Bool true) (ok x -> x) (err e -> (boolrec Nat (inc (inc zero)) zero e)))))")
   '("2 : Nat")))

;; --- match on Ordering ---

(test-case "match/ordering-lt"
  (check-equal?
   (run-ns "(ns mord1)\n(require [prologos.data.ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (the Nat (match (lt-ord) (lt-ord -> zero) (eq-ord -> (inc zero)) (gt-ord -> (inc (inc zero))))))")
   '("zero : Nat")))

(test-case "match/ordering-eq"
  (check-equal?
   (run-ns "(ns mord2)\n(require [prologos.data.ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (the Nat (match (eq-ord) (lt-ord -> zero) (eq-ord -> (inc zero)) (gt-ord -> (inc (inc zero))))))")
   '("1 : Nat")))

(test-case "match/ordering-gt"
  (check-equal?
   (run-ns "(ns mord3)\n(require [prologos.data.ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (the Nat (match (gt-ord) (lt-ord -> zero) (eq-ord -> (inc zero)) (gt-ord -> (inc (inc zero))))))")
   '("2 : Nat")))

;; --- match on inline ADTs ---

(test-case "match/inline-enum"
  ;; Define and match on an inline enum
  (check-equal?
   (last (run-ns "(ns mi1)\n(data (Color) (red) (green) (blue))\n(eval (the Nat (match (red) (red -> zero) (green -> (inc zero)) (blue -> (inc (inc zero))))))"))
   "zero : Nat")
  (check-equal?
   (last (run-ns "(ns mi2)\n(data (Color) (red) (green) (blue))\n(eval (the Nat (match (blue) (red -> zero) (green -> (inc zero)) (blue -> (inc (inc zero))))))"))
   "2 : Nat"))

(test-case "match/inline-parameterized"
  ;; Define and match on a parameterized ADT
  (check-equal?
   (last (run-ns "(ns mi3)\n(data (Maybe (A : (Type 0))) (nothing) (just A))\n(eval (the Nat (match (just Nat (inc (inc zero))) (nothing -> zero) (just x -> x))))"))
   "2 : Nat")
  (check-equal?
   (last (run-ns "(ns mi4)\n(data (Maybe (A : (Type 0))) (nothing) (just A))\n(eval (the Nat (match (nothing Nat) (nothing -> zero) (just x -> x))))"))
   "zero : Nat"))

;; --- match inside def ---

(test-case "match/inside-def"
  ;; Use match inside a function definition
  (check-equal?
   (last (run-ns "(ns md1)\n(require [prologos.data.option :refer [Option none some]])\n(def unwrap : (Pi (A :0 (Type 0)) (-> A (-> (Option A) A)))\n  (fn (A :0 (Type 0)) (fn (default : A) (fn (opt : (Option A))\n    (the A (match opt (none -> default) (some x -> x)))))))\n(eval (unwrap Nat (inc (inc zero)) (some Nat zero)))"))
   "zero : Nat")
  (check-equal?
   (last (run-ns "(ns md2)\n(require [prologos.data.option :refer [Option none some]])\n(def unwrap : (Pi (A :0 (Type 0)) (-> A (-> (Option A) A)))\n  (fn (A :0 (Type 0)) (fn (default : A) (fn (opt : (Option A))\n    (the A (match opt (none -> default) (some x -> x)))))))\n(eval (unwrap Nat (inc (inc zero)) (none Nat)))"))
   "2 : Nat"))

;; --- match with library's match-based functions ---

(test-case "match/library-unwrap-or"
  ;; unwrap-or is now implemented with match
  (check-equal?
   (run-ns "(ns mlu1)\n(require [prologos.data.option :refer [Option none some unwrap-or]])\n(eval (unwrap-or Nat (inc (inc zero)) (some Nat zero)))")
   '("zero : Nat"))
  (check-equal?
   (run-ns "(ns mlu2)\n(require [prologos.data.option :refer [Option none some unwrap-or]])\n(eval (unwrap-or Nat (inc (inc zero)) (none Nat)))")
   '("2 : Nat")))

(test-case "match/library-unwrap-or"
  ;; unwrap-or is now implemented with match
  (check-equal?
   (run-ns "(ns mlu3)\n(require [prologos.data.result :refer [Result ok err unwrap-or]])\n(eval (unwrap-or Nat Bool (inc (inc zero)) (ok Nat Bool zero)))")
   '("zero : Nat"))
  (check-equal?
   (run-ns "(ns mlu4)\n(require [prologos.data.result :refer [Result ok err unwrap-or]])\n(eval (unwrap-or Nat Bool (inc (inc zero)) (err Nat Bool true)))")
   '("2 : Nat")))

;; --- match on Bool (boolrec replacement) ---

(test-case "match/bool-as-adt"
  ;; Define Bool-like ADT and match on it
  (check-equal?
   (last (run-ns "(ns mb1)\n(data (MyBool) (my-true) (my-false))\n(eval (the Nat (match (my-true) (my-true -> (inc zero)) (my-false -> zero))))"))
   "1 : Nat")
  (check-equal?
   (last (run-ns "(ns mb2)\n(data (MyBool) (my-true) (my-false))\n(eval (the Nat (match (my-false) (my-true -> (inc zero)) (my-false -> zero))))"))
   "zero : Nat"))

;; ========================================
;; Sprint 0.3 Combinators — Option
;; ========================================

;; --- or-else ---

(test-case "or-else/some-some"
  ;; some takes priority over alt — use unwrap-or to extract value
  (check-equal?
   (last (run-ns "(ns ooe1)\n(require [prologos.data.option :refer [Option none some or-else unwrap-or]])\n(eval (unwrap-or Nat (inc (inc zero)) (or-else Nat (some Nat zero) (some Nat (inc zero)))))"))
   "zero : Nat"))

(test-case "or-else/some-none"
  ;; some takes priority, alt is none
  (check-equal?
   (last (run-ns "(ns ooe2)\n(require [prologos.data.option :refer [Option none some or-else unwrap-or]])\n(eval (unwrap-or Nat (inc (inc zero)) (or-else Nat (some Nat (inc zero)) (none Nat))))"))
   "1 : Nat"))

(test-case "or-else/none-some"
  ;; opt is none, falls back to alt
  (check-equal?
   (last (run-ns "(ns ooe3)\n(require [prologos.data.option :refer [Option none some or-else unwrap-or]])\n(eval (unwrap-or Nat zero (or-else Nat (none Nat) (some Nat (inc (inc zero))))))"))
   "2 : Nat"))

(test-case "or-else/none-none"
  ;; both none — returns default from unwrap-or
  (check-equal?
   (last (run-ns "(ns ooe4)\n(require [prologos.data.option :refer [Option none some or-else unwrap-or]])\n(eval (unwrap-or Nat (inc (inc (inc zero))) (or-else Nat (none Nat) (none Nat))))"))
   "3 : Nat"))

;; --- filter ---

(test-case "filter/pred-true"
  ;; some with pred returning true → keeps value — use unwrap-or
  (check-equal?
   (last (run-ns "(ns of1)\n(require [prologos.data.option :refer [Option none some filter unwrap-or]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (unwrap-or Nat (inc zero) (filter Nat zero? (some Nat zero))))"))
   "zero : Nat"))

(test-case "filter/pred-false"
  ;; some with pred returning false → none → gets default
  (check-equal?
   (last (run-ns "(ns of2)\n(require [prologos.data.option :refer [Option none some filter unwrap-or]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (unwrap-or Nat (inc (inc zero)) (filter Nat zero? (some Nat (inc zero)))))"))
   "2 : Nat"))

(test-case "filter/none"
  ;; none stays none → gets default
  (check-equal?
   (last (run-ns "(ns of3)\n(require [prologos.data.option :refer [Option none some filter unwrap-or]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (unwrap-or Nat (inc (inc (inc zero))) (filter Nat zero? (none Nat))))"))
   "3 : Nat"))

;; --- zip-with ---

(test-case "zip-with/both-some"
  ;; zip two somes with add — use unwrap-or to extract result
  (check-equal?
   (last (run-ns "(ns ozw1)\n(require [prologos.data.option :refer [Option none some zip-with unwrap-or]])\n(require [prologos.data.nat :refer [add]])\n(eval (unwrap-or Nat zero (zip-with Nat Nat Nat add (some Nat (inc (inc zero))) (some Nat (inc (inc (inc zero)))))))"))
   "5 : Nat"))

(test-case "zip-with/first-none"
  (check-equal?
   (last (run-ns "(ns ozw2)\n(require [prologos.data.option :refer [Option none some zip-with unwrap-or]])\n(require [prologos.data.nat :refer [add]])\n(eval (unwrap-or Nat (inc (inc (inc zero))) (zip-with Nat Nat Nat add (none Nat) (some Nat (inc zero)))))"))
   "3 : Nat"))

(test-case "zip-with/second-none"
  (check-equal?
   (last (run-ns "(ns ozw3)\n(require [prologos.data.option :refer [Option none some zip-with unwrap-or]])\n(require [prologos.data.nat :refer [add]])\n(eval (unwrap-or Nat (inc (inc (inc zero))) (zip-with Nat Nat Nat add (some Nat (inc zero)) (none Nat))))"))
   "3 : Nat"))

(test-case "zip-with/both-none"
  (check-equal?
   (last (run-ns "(ns ozw4)\n(require [prologos.data.option :refer [Option none some zip-with unwrap-or]])\n(require [prologos.data.nat :refer [add]])\n(eval (unwrap-or Nat (inc (inc (inc zero))) (zip-with Nat Nat Nat add (none Nat) (none Nat))))"))
   "3 : Nat"))

;; --- zip ---

(test-case "zip/both-some"
  ;; zip into a pair, then extract via match
  (check-equal?
   (last (run-ns "(ns oz1)\n(require [prologos.data.option :refer [Option none some zip]])\n(eval (the Nat (match (zip Nat Nat (some Nat (inc zero)) (some Nat (inc (inc zero)))) (none -> zero) (some p -> (first p)))))"))
   "1 : Nat"))

(test-case "zip/one-none"
  (check-equal?
   (last (run-ns "(ns oz2)\n(require [prologos.data.option :refer [Option none some zip]])\n(eval (the Nat (match (zip Nat Nat (none Nat) (some Nat (inc (inc zero)))) (none -> (inc (inc (inc zero)))) (some p -> (first p)))))"))
   "3 : Nat"))

;; --- Type checking for Option combinators ---

(test-case "or-else/type-check"
  (check-equal?
   (last (run-ns "(ns ooetc)\n(require [prologos.data.option :refer [Option or-else]])\n(check or-else : (Pi (A :0 (Type 0)) (-> (Option A) (-> (Option A) (Option A)))))"))
   "OK"))

(test-case "filter/type-check"
  (check-equal?
   (last (run-ns "(ns oftc)\n(require [prologos.data.option :refer [Option filter]])\n(check filter : (Pi (A :0 (Type 0)) (-> (-> A Bool) (-> (Option A) (Option A)))))"))
   "OK"))

;; ========================================
;; Sprint 0.3 Combinators — Result
;; ========================================

;; --- and-then ---

(test-case "and-then/ok-to-ok"
  ;; ok value → apply f → ok result — use unwrap-or to extract
  (check-equal?
   (last (run-ns "(ns rat1)\n(require [prologos.data.result :refer [Result ok err and-then unwrap-or]])\n(require [prologos.data.nat :refer [add]])\n(eval (unwrap-or Nat Bool zero (and-then Nat Bool Nat (fn (x : Nat) (ok Nat Bool (add x (inc zero)))) (ok Nat Bool (inc (inc zero))))))"))
   "3 : Nat"))

(test-case "and-then/ok-to-err"
  ;; ok value → apply f → err result — match to extract
  (check-equal?
   (last (run-ns "(ns rat2)\n(require [prologos.data.result :refer [Result ok err and-then]])\n(eval (the Nat (match (and-then Nat Bool Nat (fn (x : Nat) (err Nat Bool true)) (ok Nat Bool (inc zero))) (ok x -> x) (err e -> (match e (true -> (inc (inc (inc (inc (inc zero)))))) (false -> zero))))))"))
   "5 : Nat"))

(test-case "and-then/err-passthrough"
  ;; err → f not called, err passes through
  (check-equal?
   (last (run-ns "(ns rat3)\n(require [prologos.data.result :refer [Result ok err and-then]])\n(eval (the Nat (match (and-then Nat Bool Nat (fn (x : Nat) (ok Nat Bool (inc x))) (err Nat Bool true)) (ok x -> x) (err e -> (match e (true -> (inc (inc (inc (inc (inc (inc (inc zero)))))))) (false -> zero))))))"))
   "7 : Nat"))

;; --- or-else ---

(test-case "or-else/ok-passthrough"
  ;; ok → f not called, ok passes through — use unwrap-or
  (check-equal?
   (last (run-ns "(ns roe1)\n(require [prologos.data.result :refer [Result ok err or-else unwrap-or]])\n(eval (unwrap-or Nat Nat zero (or-else Nat Bool Nat (fn (e : Bool) (ok Nat Nat zero)) (ok Nat Bool (inc (inc zero))))))"))
   "2 : Nat"))

(test-case "or-else/err-to-ok"
  ;; err → apply f → recovers to ok — use unwrap-or
  (check-equal?
   (last (run-ns "(ns roe2)\n(require [prologos.data.result :refer [Result ok err or-else unwrap-or]])\n(eval (unwrap-or Nat Nat zero (or-else Nat Bool Nat (fn (e : Bool) (ok Nat Nat (match e (true -> (inc zero)) (false -> zero)))) (err Nat Bool true))))"))
   "1 : Nat"))

(test-case "or-else/err-to-err"
  ;; err → apply f → still err (with new error type) — match to extract
  (check-equal?
   (last (run-ns "(ns roe3)\n(require [prologos.data.result :refer [Result ok err or-else]])\n(eval (the Nat (match (or-else Nat Bool Nat (fn (e : Bool) (err Nat Nat (the Nat (match e (true -> (inc (inc (inc zero)))) (false -> zero))))) (err Nat Bool true)) (ok x -> x) (err e -> e))))"))
   "3 : Nat"))

;; --- Type checking for Result combinators ---

(test-case "and-then/type-check"
  (check-equal?
   (last (run-ns "(ns rattc)\n(require [prologos.data.result :refer [Result and-then]])\n(check and-then : (Pi (A :0 (Type 0)) (Pi (E :0 (Type 0)) (Pi (B :0 (Type 0)) (-> (-> A (Result B E)) (-> (Result A E) (Result B E)))))))"))
   "OK"))

(test-case "or-else/type-check"
  (check-equal?
   (last (run-ns "(ns roetc)\n(require [prologos.data.result :refer [Result or-else]])\n(check or-else : (Pi (A :0 (Type 0)) (Pi (E :0 (Type 0)) (Pi (F :0 (Type 0)) (-> (-> E (Result A F)) (-> (Result A E) (Result A F)))))))"))
   "OK"))

;; ========================================
;; Recursive Types — Inline data definition
;; ========================================

(test-case "data/recursive-natlist"
  ;; Monomorphic recursive type
  (check-equal?
   (last (run-ns "(ns rd1)\n(data (NatList) (nil) (cons Nat NatList))\n(check nil : NatList)"))
   "OK")
  (check-equal?
   (last (run-ns "(ns rd2)\n(data (NatList) (nil) (cons Nat NatList))\n(check (cons zero nil) : NatList)"))
   "OK"))

(test-case "data/recursive-parameterized"
  ;; Parameterized recursive type
  (check-equal?
   (last (run-ns "(ns rd3)\n(data (List (A : (Type 0))) (nil) (cons A (List A)))\n(check (nil Nat) : (List Nat))"))
   "OK")
  (check-equal?
   (last (run-ns "(ns rd4)\n(data (List (A : (Type 0))) (nil) (cons A (List A)))\n(check (cons Nat zero (nil Nat)) : (List Nat))"))
   "OK"))

(test-case "data/recursive-nested-cons"
  ;; Build a 3-element list
  (check-equal?
   (last (run-ns "(ns rd5)\n(data (List (A : (Type 0))) (nil) (cons A (List A)))\n(check (cons Nat zero (cons Nat (inc zero) (cons Nat (inc (inc zero)) (nil Nat)))) : (List Nat))"))
   "OK"))

(test-case "data/recursive-fold-sum"
  ;; Sum [1, 2, 3] → 6 via recursive match
  (check-equal?
   (last (run-ns "(ns rd6)\n(require [prologos.data.nat :refer [add]])\n(data (List (A : (Type 0))) (nil) (cons A (List A)))\n(def my-sum : (-> (List Nat) Nat) (fn (xs : (List Nat)) (match xs (nil -> zero) (cons a rest -> (add a (my-sum rest))))))\n(eval (my-sum (cons Nat (inc zero) (cons Nat (inc (inc zero)) (cons Nat (inc (inc (inc zero))) (nil Nat))))))"))
   "6 : Nat"))

(test-case "data/recursive-match-sum"
  ;; Match on recursive type — structural (not fold): need explicit recursion
  (check-equal?
   (last (run-ns "(ns rd7)\n(require [prologos.data.nat :refer [add]])\n(data (List (A : (Type 0))) (nil) (cons A (List A)))\n(def my-sum : (-> (List Nat) Nat) (fn (xs : (List Nat)) (match xs (nil -> zero) (cons x rest -> (add x (my-sum rest))))))\n(def my-list : (List Nat) (cons Nat (inc zero) (cons Nat (inc (inc zero)) (cons Nat (inc (inc (inc zero))) (nil Nat)))))\n(eval (my-sum my-list))"))
   "6 : Nat"))

(test-case "data/recursive-match-empty"
  ;; Match on empty list — structural match, nil branch returns 3
  (check-equal?
   (last (run-ns "(ns rd8)\n(data (List (A : (Type 0))) (nil) (cons A (List A)))\n(eval (the Nat (match (nil Nat) (nil -> (inc (inc (inc zero)))) (cons x rest -> zero))))"))
   "3 : Nat"))

;; ========================================
;; List module — prologos.data.list
;; ========================================

(test-case "list/type-check"
  ;; List type and constructor types
  (check-equal?
   (last (run-ns "(ns lst1)\n(require [prologos.data.list :refer [List nil cons]])\n(check (nil Nat) : (List Nat))"))
   "OK")
  (check-equal?
   (last (run-ns "(ns lst2)\n(require [prologos.data.list :refer [List nil cons]])\n(check (cons Nat zero (nil Nat)) : (List Nat))"))
   "OK"))

(test-case "list/foldr-sum"
  ;; foldr add zero [1,2,3] = 6
  (check-equal?
   (last (run-ns "(ns lst3)\n(require [prologos.data.list :refer [List nil cons foldr]])\n(require [prologos.data.nat :refer [add]])\n(eval (foldr Nat Nat add zero (cons Nat (inc zero) (cons Nat (inc (inc zero)) (cons Nat (inc (inc (inc zero))) (nil Nat))))))"))
   "6 : Nat"))

(test-case "list/foldr-product"
  ;; foldr mult 1 [2,3] = 6
  (check-equal?
   (last (run-ns "(ns lst4)\n(require [prologos.data.list :refer [List nil cons foldr]])\n(require [prologos.data.nat :refer [mult]])\n(eval (foldr Nat Nat mult (inc zero) (cons Nat (inc (inc zero)) (cons Nat (inc (inc (inc zero))) (nil Nat)))))"))
   "6 : Nat"))

(test-case "list/foldr-empty"
  ;; foldr f z [] = z
  (check-equal?
   (last (run-ns "(ns lst5)\n(require [prologos.data.list :refer [List nil cons foldr]])\n(require [prologos.data.nat :refer [add]])\n(eval (foldr Nat Nat add (inc (inc (inc (inc (inc zero))))) (nil Nat)))"))
   "5 : Nat"))

(test-case "list/length-empty"
  (check-equal?
   (last (run-ns "(ns lst6)\n(require [prologos.data.list :refer [List nil length]])\n(eval (length Nat (nil Nat)))"))
   "zero : Nat"))

(test-case "list/length-three"
  (check-equal?
   (last (run-ns "(ns lst7)\n(require [prologos.data.list :refer [List nil cons length]])\n(eval (length Nat (cons Nat zero (cons Nat (inc zero) (cons Nat (inc (inc zero)) (nil Nat))))))"))
   "3 : Nat"))

(test-case "list/map-inc"
  ;; map (fn x . suc x) [0, 1] then sum = 1 + 2 = 3
  (check-equal?
   (last (run-ns "(ns lst8)\n(require [prologos.data.list :refer [List nil cons map foldr]])\n(require [prologos.data.nat :refer [add]])\n(eval (foldr Nat Nat add zero (map Nat Nat (fn (x : Nat) (inc x)) (cons Nat zero (cons Nat (inc zero) (nil Nat))))))"))
   "3 : Nat"))

(test-case "list/map-empty"
  ;; map f [] = [], length = 0
  (check-equal?
   (last (run-ns "(ns lst9)\n(require [prologos.data.list :refer [List nil map length]])\n(eval (length Nat (map Nat Nat (fn (x : Nat) (inc x)) (nil Nat))))"))
   "zero : Nat"))

(test-case "list/filter-keep-zeros"
  ;; filter zero? [0, 1, 0] → length 2
  (check-equal?
   (last (run-ns "(ns lst10)\n(require [prologos.data.list :refer [List nil cons filter length]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (length Nat (filter Nat zero? (cons Nat zero (cons Nat (inc zero) (cons Nat zero (nil Nat)))))))"))
   "2 : Nat"))

(test-case "list/filter-drop-all"
  ;; filter zero? [1, 2] → length 0
  (check-equal?
   (last (run-ns "(ns lst11)\n(require [prologos.data.list :refer [List nil cons filter length]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (length Nat (filter Nat zero? (cons Nat (inc zero) (cons Nat (inc (inc zero)) (nil Nat))))))"))
   "zero : Nat"))

(test-case "list/append"
  ;; [1,2] ++ [3] → sum = 6
  (check-equal?
   (last (run-ns "(ns lst12)\n(require [prologos.data.list :refer [List nil cons append foldr]])\n(require [prologos.data.nat :refer [add]])\n(eval (foldr Nat Nat add zero (append Nat (cons Nat (inc zero) (cons Nat (inc (inc zero)) (nil Nat))) (cons Nat (inc (inc (inc zero))) (nil Nat)))))"))
   "6 : Nat"))

(test-case "list/append-empty-left"
  ;; [] ++ [1] → sum = 1
  (check-equal?
   (last (run-ns "(ns lst13)\n(require [prologos.data.list :refer [List nil cons append foldr]])\n(require [prologos.data.nat :refer [add]])\n(eval (foldr Nat Nat add zero (append Nat (nil Nat) (cons Nat (inc zero) (nil Nat)))))"))
   "1 : Nat"))

(test-case "list/append-empty-right"
  ;; [1] ++ [] → sum = 1
  (check-equal?
   (last (run-ns "(ns lst14)\n(require [prologos.data.list :refer [List nil cons append foldr]])\n(require [prologos.data.nat :refer [add]])\n(eval (foldr Nat Nat add zero (append Nat (cons Nat (inc zero) (nil Nat)) (nil Nat))))"))
   "1 : Nat"))

(test-case "list/head-nonempty"
  (check-equal?
   (last (run-ns "(ns lst15)\n(require [prologos.data.list :refer [List nil cons head]])\n(eval (head Nat (inc (inc (inc zero))) (cons Nat (inc zero) (nil Nat))))"))
   "1 : Nat"))

(test-case "list/head-empty"
  ;; head returns default for empty list
  (check-equal?
   (last (run-ns "(ns lst16)\n(require [prologos.data.list :refer [List nil head]])\n(eval (head Nat (inc (inc (inc zero))) (nil Nat)))"))
   "3 : Nat"))

(test-case "list/singleton"
  (check-equal?
   (last (run-ns "(ns lst17)\n(require [prologos.data.list :refer [List singleton length]])\n(eval (length Nat (singleton Nat zero)))"))
   "1 : Nat"))

(test-case "list/singleton-head"
  (check-equal?
   (last (run-ns "(ns lst18)\n(require [prologos.data.list :refer [List singleton head]])\n(eval (head Nat (inc (inc (inc zero))) (singleton Nat (inc (inc zero)))))"))
   "2 : Nat"))

;; ========================================
;; prologos.core.eq-trait — Eq dictionary-passing
;; ========================================

(test-case "eq/nat-eq-same"
  ;; nat-eq 0 0 = true
  (check-equal?
   (last (run-ns "(ns eq1)\n(require [prologos.core.eq-trait :refer [nat-eq]])\n(eval (nat-eq zero zero))"))
   "true : Bool"))

(test-case "eq/nat-eq-same-nonzero"
  ;; nat-eq 3 3 = true
  (check-equal?
   (last (run-ns "(ns eq2)\n(require [prologos.core.eq-trait :refer [nat-eq]])\n(eval (nat-eq (inc (inc (inc zero))) (inc (inc (inc zero)))))"))
   "true : Bool"))

(test-case "eq/nat-eq-different"
  ;; nat-eq 2 3 = false
  (check-equal?
   (last (run-ns "(ns eq3)\n(require [prologos.core.eq-trait :refer [nat-eq]])\n(eval (nat-eq (inc (inc zero)) (inc (inc (inc zero)))))"))
   "false : Bool"))

(test-case "eq/nat-eq-zero-nonzero"
  ;; nat-eq 0 1 = false
  (check-equal?
   (last (run-ns "(ns eq4)\n(require [prologos.core.eq-trait :refer [nat-eq]])\n(eval (nat-eq zero (inc zero)))"))
   "false : Bool"))

(test-case "eq/nat-eq-type-check"
  ;; nat-eq : Nat -> Nat -> Bool (which is Eq Nat after deftype expansion)
  (check-equal?
   (last (run-ns "(ns eq5)\n(require [prologos.core.eq-trait :refer [nat-eq]])\n(check nat-eq : (-> Nat (-> Nat Bool)))"))
   "OK"))

(test-case "eq/eq-neq-same"
  ;; eq-neq nat-eq 3 3 = false (not equal → false)
  (check-equal?
   (last (run-ns "(ns eq6)\n(require [prologos.core.eq-trait :refer [nat-eq eq-neq]])\n(eval (eq-neq Nat nat-eq (inc (inc (inc zero))) (inc (inc (inc zero)))))"))
   "false : Bool"))

(test-case "eq/eq-neq-different"
  ;; eq-neq nat-eq 2 5 = true (not equal → true)
  (check-equal?
   (last (run-ns "(ns eq7)\n(require [prologos.core.eq-trait :refer [nat-eq eq-neq]])\n(eval (eq-neq Nat nat-eq (inc (inc zero)) (inc (inc (inc (inc (inc zero)))))))"))
   "true : Bool"))

(test-case "eq/eq-neq-type-check"
  ;; eq-neq : Pi(A :0 Type 0). (Eq A) -> A -> A -> Bool
  ;; After deftype expansion: (-> A (-> A Bool)) is Eq A
  (check-equal?
   (last (run-ns "(ns eq8)\n(require [prologos.core.eq-trait :refer [eq-neq]])\n(check eq-neq : (Pi (A :0 (Type 0)) (-> (-> A (-> A Bool)) (-> A (-> A Bool)))))"))
   "OK"))

;; ========================================
;; prologos.core.ord-trait — Ord dictionary-passing
;; ========================================

(test-case "ord/nat-ord-lt"
  ;; nat-ord 2 5 → lt-ord → match to extract
  (check-equal?
   (last (run-ns "(ns ord1)\n(require [prologos.core.ord-trait :refer [nat-ord]])\n(require [prologos.data.ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (the Nat (match (nat-ord (inc (inc zero)) (inc (inc (inc (inc (inc zero)))))) (lt-ord -> zero) (eq-ord -> (inc zero)) (gt-ord -> (inc (inc zero))))))"))
   "zero : Nat"))

(test-case "ord/nat-ord-eq"
  ;; nat-ord 3 3 → eq-ord → match to extract
  (check-equal?
   (last (run-ns "(ns ord2)\n(require [prologos.core.ord-trait :refer [nat-ord]])\n(require [prologos.data.ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (the Nat (match (nat-ord (inc (inc (inc zero))) (inc (inc (inc zero)))) (lt-ord -> zero) (eq-ord -> (inc zero)) (gt-ord -> (inc (inc zero))))))"))
   "1 : Nat"))

(test-case "ord/nat-ord-gt"
  ;; nat-ord 5 2 → gt-ord → match to extract
  (check-equal?
   (last (run-ns "(ns ord3)\n(require [prologos.core.ord-trait :refer [nat-ord]])\n(require [prologos.data.ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (the Nat (match (nat-ord (inc (inc (inc (inc (inc zero))))) (inc (inc zero))) (lt-ord -> zero) (eq-ord -> (inc zero)) (gt-ord -> (inc (inc zero))))))"))
   "2 : Nat"))

(test-case "ord/nat-ord-type-check"
  ;; nat-ord : Nat -> Nat -> Ordering (which is Ord Nat after deftype expansion)
  (check-equal?
   (last (run-ns "(ns ord4)\n(require [prologos.core.ord-trait :refer [nat-ord]])\n(require [prologos.data.ordering :refer [Ordering]])\n(check nat-ord : (-> Nat (-> Nat Ordering)))"))
   "OK"))

;; --- Ord derived operations ---

(test-case "ord/ord-lt-true"
  ;; ord-lt nat-ord 2 5 = true
  (check-equal?
   (last (run-ns "(ns ol1)\n(require [prologos.core.ord-trait :refer [nat-ord ord-lt]])\n(eval (ord-lt Nat nat-ord (inc (inc zero)) (inc (inc (inc (inc (inc zero)))))))"))
   "true : Bool"))

(test-case "ord/ord-lt-false"
  ;; ord-lt nat-ord 5 2 = false
  (check-equal?
   (last (run-ns "(ns ol2)\n(require [prologos.core.ord-trait :refer [nat-ord ord-lt]])\n(eval (ord-lt Nat nat-ord (inc (inc (inc (inc (inc zero))))) (inc (inc zero))))"))
   "false : Bool"))

(test-case "ord/ord-le-eq"
  ;; ord-le nat-ord 3 3 = true
  (check-equal?
   (last (run-ns "(ns ol3)\n(require [prologos.core.ord-trait :refer [nat-ord ord-le]])\n(eval (ord-le Nat nat-ord (inc (inc (inc zero))) (inc (inc (inc zero)))))"))
   "true : Bool"))

(test-case "ord/ord-le-lt"
  ;; ord-le nat-ord 2 5 = true
  (check-equal?
   (last (run-ns "(ns ol4)\n(require [prologos.core.ord-trait :refer [nat-ord ord-le]])\n(eval (ord-le Nat nat-ord (inc (inc zero)) (inc (inc (inc (inc (inc zero)))))))"))
   "true : Bool"))

(test-case "ord/ord-le-gt"
  ;; ord-le nat-ord 5 2 = false
  (check-equal?
   (last (run-ns "(ns ol5)\n(require [prologos.core.ord-trait :refer [nat-ord ord-le]])\n(eval (ord-le Nat nat-ord (inc (inc (inc (inc (inc zero))))) (inc (inc zero))))"))
   "false : Bool"))

(test-case "ord/ord-gt-true"
  ;; ord-gt nat-ord 5 2 = true
  (check-equal?
   (last (run-ns "(ns og1)\n(require [prologos.core.ord-trait :refer [nat-ord ord-gt]])\n(eval (ord-gt Nat nat-ord (inc (inc (inc (inc (inc zero))))) (inc (inc zero))))"))
   "true : Bool"))

(test-case "ord/ord-gt-false"
  ;; ord-gt nat-ord 2 5 = false
  (check-equal?
   (last (run-ns "(ns og2)\n(require [prologos.core.ord-trait :refer [nat-ord ord-gt]])\n(eval (ord-gt Nat nat-ord (inc (inc zero)) (inc (inc (inc (inc (inc zero)))))))"))
   "false : Bool"))

(test-case "ord/ord-ge-eq"
  ;; ord-ge nat-ord 3 3 = true
  (check-equal?
   (last (run-ns "(ns oge1)\n(require [prologos.core.ord-trait :refer [nat-ord ord-ge]])\n(eval (ord-ge Nat nat-ord (inc (inc (inc zero))) (inc (inc (inc zero)))))"))
   "true : Bool"))

(test-case "ord/ord-ge-gt"
  ;; ord-ge nat-ord 5 2 = true
  (check-equal?
   (last (run-ns "(ns oge2)\n(require [prologos.core.ord-trait :refer [nat-ord ord-ge]])\n(eval (ord-ge Nat nat-ord (inc (inc (inc (inc (inc zero))))) (inc (inc zero))))"))
   "true : Bool"))

(test-case "ord/ord-ge-lt"
  ;; ord-ge nat-ord 2 5 = false
  (check-equal?
   (last (run-ns "(ns oge3)\n(require [prologos.core.ord-trait :refer [nat-ord ord-ge]])\n(eval (ord-ge Nat nat-ord (inc (inc zero)) (inc (inc (inc (inc (inc zero)))))))"))
   "false : Bool"))

(test-case "ord/ord-eq-same"
  ;; ord-eq nat-ord 3 3 = true
  (check-equal?
   (last (run-ns "(ns oeq1)\n(require [prologos.core.ord-trait :refer [nat-ord ord-eq]])\n(eval (ord-eq Nat nat-ord (inc (inc (inc zero))) (inc (inc (inc zero)))))"))
   "true : Bool"))

(test-case "ord/ord-eq-different"
  ;; ord-eq nat-ord 2 5 = false
  (check-equal?
   (last (run-ns "(ns oeq2)\n(require [prologos.core.ord-trait :refer [nat-ord ord-eq]])\n(eval (ord-eq Nat nat-ord (inc (inc zero)) (inc (inc (inc (inc (inc zero)))))))"))
   "false : Bool"))

(test-case "ord/ord-min"
  ;; ord-min nat-ord 2 5 = 2
  (check-equal?
   (last (run-ns "(ns om1)\n(require [prologos.core.ord-trait :refer [nat-ord ord-min]])\n(eval (ord-min Nat nat-ord (inc (inc zero)) (inc (inc (inc (inc (inc zero)))))))"))
   "2 : Nat")
  ;; ord-min nat-ord 5 2 = 2
  (check-equal?
   (last (run-ns "(ns om2)\n(require [prologos.core.ord-trait :refer [nat-ord ord-min]])\n(eval (ord-min Nat nat-ord (inc (inc (inc (inc (inc zero))))) (inc (inc zero))))"))
   "2 : Nat")
  ;; ord-min nat-ord 3 3 = 3
  (check-equal?
   (last (run-ns "(ns om3)\n(require [prologos.core.ord-trait :refer [nat-ord ord-min]])\n(eval (ord-min Nat nat-ord (inc (inc (inc zero))) (inc (inc (inc zero)))))"))
   "3 : Nat"))

(test-case "ord/ord-max"
  ;; ord-max nat-ord 2 5 = 5
  (check-equal?
   (last (run-ns "(ns omx1)\n(require [prologos.core.ord-trait :refer [nat-ord ord-max]])\n(eval (ord-max Nat nat-ord (inc (inc zero)) (inc (inc (inc (inc (inc zero)))))))"))
   "5 : Nat")
  ;; ord-max nat-ord 5 2 = 5
  (check-equal?
   (last (run-ns "(ns omx2)\n(require [prologos.core.ord-trait :refer [nat-ord ord-max]])\n(eval (ord-max Nat nat-ord (inc (inc (inc (inc (inc zero))))) (inc (inc zero))))"))
   "5 : Nat")
  ;; ord-max nat-ord 3 3 = 3
  (check-equal?
   (last (run-ns "(ns omx3)\n(require [prologos.core.ord-trait :refer [nat-ord ord-max]])\n(eval (ord-max Nat nat-ord (inc (inc (inc zero))) (inc (inc (inc zero)))))"))
   "3 : Nat"))

;; ========================================
;; Integration: List + Eq (elem)
;; ========================================

(test-case "elem/found"
  ;; 2 is in [1, 2, 3]
  (check-equal?
   (last (run-ns "(ns le1)\n(require [prologos.data.list :refer [List nil cons elem]])\n(require [prologos.core.eq-trait :refer [nat-eq]])\n(eval (elem Nat nat-eq (inc (inc zero)) (cons Nat (inc zero) (cons Nat (inc (inc zero)) (cons Nat (inc (inc (inc zero))) (nil Nat))))))"))
   "true : Bool"))

(test-case "elem/not-found"
  ;; 5 is not in [1, 2, 3]
  (check-equal?
   (last (run-ns "(ns le2)\n(require [prologos.data.list :refer [List nil cons elem]])\n(require [prologos.core.eq-trait :refer [nat-eq]])\n(eval (elem Nat nat-eq (inc (inc (inc (inc (inc zero))))) (cons Nat (inc zero) (cons Nat (inc (inc zero)) (cons Nat (inc (inc (inc zero))) (nil Nat))))))"))
   "false : Bool"))

(test-case "elem/empty-list"
  ;; Any element not in []
  (check-equal?
   (last (run-ns "(ns le3)\n(require [prologos.data.list :refer [List nil elem]])\n(require [prologos.core.eq-trait :refer [nat-eq]])\n(eval (elem Nat nat-eq zero (nil Nat)))"))
   "false : Bool"))

(test-case "elem/first-element"
  ;; 0 is first in [0, 1, 2]
  (check-equal?
   (last (run-ns "(ns le4)\n(require [prologos.data.list :refer [List nil cons elem]])\n(require [prologos.core.eq-trait :refer [nat-eq]])\n(eval (elem Nat nat-eq zero (cons Nat zero (cons Nat (inc zero) (cons Nat (inc (inc zero)) (nil Nat))))))"))
   "true : Bool"))

(test-case "elem/last-element"
  ;; 3 is last in [1, 2, 3]
  (check-equal?
   (last (run-ns "(ns le5)\n(require [prologos.data.list :refer [List nil cons elem]])\n(require [prologos.core.eq-trait :refer [nat-eq]])\n(eval (elem Nat nat-eq (inc (inc (inc zero))) (cons Nat (inc zero) (cons Nat (inc (inc zero)) (cons Nat (inc (inc (inc zero))) (nil Nat))))))"))
   "true : Bool"))

;; ========================================
;; match — Structural pattern matching (sexp mode)
;; ========================================

;; match on Option — some case (sexp mode)
(test-case "match/option-some"
  (check-equal?
   (last (run-ns "(ns ro1)\n(require [prologos.data.option :refer [Option none some]])\n(eval (the Nat (match (some Nat zero) (none -> (inc zero)) (some x -> x))))"))
   "zero : Nat"))

;; match on Option — none case
(test-case "match/option-none"
  (check-equal?
   (last (run-ns "(ns ro2)\n(require [prologos.data.option :refer [Option none some]])\n(eval (the Nat (match (none Nat) (none -> (inc zero)) (some x -> x))))"))
   "1 : Nat"))

;; match on Ordering — nullary constructors
(test-case "match/ordering-lt"
  (check-equal?
   (last (run-ns "(ns ro3)\n(require [prologos.data.ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (the Nat (match (lt-ord) (lt-ord -> zero) (eq-ord -> (inc zero)) (gt-ord -> (inc (inc zero))))))"))
   "zero : Nat"))

(test-case "match/ordering-gt"
  (check-equal?
   (last (run-ns "(ns ro4)\n(require [prologos.data.ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (the Nat (match (gt-ord) (lt-ord -> zero) (eq-ord -> (inc zero)) (gt-ord -> (inc (inc zero))))))"))
   "2 : Nat"))

;; match on Result — ok case
(test-case "match/result-ok"
  (check-equal?
   (last (run-ns "(ns ro5)\n(require [prologos.data.result :refer [Result ok err]])\n(eval (the Nat (match (ok Nat Bool zero) (ok x -> x) (err _ -> (inc zero)))))"))
   "zero : Nat"))

;; match on Result — err case
(test-case "match/result-err"
  (check-equal?
   (last (run-ns "(ns ro6)\n(require [prologos.data.result :refer [Result ok err]])\n(eval (the Nat (match (err Nat Bool true) (ok x -> (inc zero)) (err _ -> zero))))"))
   "zero : Nat"))

;; match on List — nil case (structural PM)
(test-case "match/list-nil"
  ;; Match on nil list returns nil-branch value
  (check-equal?
   (last (run-ns "(ns ro7)\n(require [prologos.data.list :refer [List nil cons]])\n(eval (the Nat (match (nil Nat) (nil -> zero) (cons _ rest -> zero))))"))
   "zero : Nat"))

;; match on List — structural PM: cons gives raw tail, need explicit recursion for length
(test-case "match/length-via-match"
  (check-equal?
   (last (run-ns "(ns ro8)\n(require [prologos.data.list :refer [List nil cons length]])\n(eval (length Nat (cons Nat zero (cons Nat (inc zero) (nil Nat)))))"))
   "2 : Nat"))

;; ========================================
;; Recursive defn — self-referential function definitions
;; ========================================

;; Simple recursion: count-down n = natrec on n, calling self on predecessor
(test-case "recursive-defn/count-down"
  ;; count-down just recurses to zero (using natrec, calling itself on k)
  (check-equal?
   (last (run-ns "(ns rec1)\n(def count-down : (-> Nat Nat)\n  (fn (n : Nat) (natrec Nat zero (fn (k : Nat) (fn (_ : Nat) (count-down k))) n)))\n(eval (count-down (inc (inc (inc zero)))))"))
   "zero : Nat"))

;; Recursive defn: factorial using natrec + self-reference
;; fact 0 = 1, fact (suc k) = (suc k) * fact(k)
(test-case "recursive-defn/factorial"
  (check-equal?
   (last (run-ns "(ns rec2)\n(require [prologos.data.nat :refer [mult]])\n(def fact : (-> Nat Nat)\n  (fn (n : Nat) (natrec Nat (inc zero) (fn (k : Nat) (fn (_ : Nat) (mult (inc k) (fact k)))) n)))\n(eval (fact (inc (inc (inc zero)))))"))
   "6 : Nat")
  ;; fact(4) = 24
  (check-equal?
   (last (run-ns "(ns rec2b)\n(require [prologos.data.nat :refer [mult]])\n(def fact : (-> Nat Nat)\n  (fn (n : Nat) (natrec Nat (inc zero) (fn (k : Nat) (fn (_ : Nat) (mult (inc k) (fact k)))) n)))\n(eval (fact (inc (inc (inc (inc zero))))))"))
   "24 : Nat"))

;; Recursive defn with defn syntax
(test-case "recursive-defn/defn-syntax"
  ;; defn double-it [n : Nat] : Nat uses natrec and calls itself
  (check-equal?
   (last (run-ns "(ns rec3)\n(defn my-double [n : Nat] : Nat\n  (natrec Nat zero (fn (k : Nat) (fn (_ : Nat) (inc (inc (my-double k)))) ) n))\n(eval (my-double (inc (inc (inc zero)))))"))
   "6 : Nat"))

;; Recursive defn with match (the key use case!)
;; Sum a list of Nats using match + recursion
(test-case "recursive-defn/list-sum-with-match"
  ;; Structural match: cons gives raw tail, need explicit recursion
  (check-equal?
   (last (run-ns "(ns rec4)\n(require [prologos.data.list :refer [List nil cons]])\n(require [prologos.data.nat :refer [add]])\n(defn my-sum [xs : List Nat] : Nat\n  (match xs (nil -> zero) (cons a rest -> (add a (my-sum rest)))))\n(eval (my-sum (cons Nat (inc zero) (cons Nat (inc (inc zero)) (cons Nat (inc (inc (inc zero))) (nil Nat))))))"))
   "6 : Nat"))

;; Non-recursive def still works (regression check)
(test-case "recursive-defn/non-recursive-still-works"
  (check-equal?
   (last (run-ns "(ns rec5)\n(def id-nat : (-> Nat Nat) (fn (n : Nat) n))\n(eval (id-nat (inc (inc zero))))"))
   "2 : Nat"))

;; ========================================
;; Native Constructor Verification Tests
;; Tests that validate the unfold-guarded constructor architecture:
;; - User-defined types at Type 0 (not Type 1)
;; - Nested types like Option (List Nat) well-typed
;; - Composed functions work correctly
;; ========================================

(test-case "native-ctor/list-type-0"
  ;; List Nat : Type 0 (not Type 1 from Church encoding)
  (check-equal?
   (last (run-ns "(ns nc1)\n(require [prologos.data.list :refer [List]])\n(check (List Nat) : (Type 0))"))
   "OK"))

(test-case "native-ctor/option-type-0"
  ;; Option Nat : Type 0
  (check-equal?
   (last (run-ns "(ns nc2)\n(require [prologos.data.option :refer [Option]])\n(check (Option Nat) : (Type 0))"))
   "OK"))

(test-case "native-ctor/option-list-nat"
  ;; Option (List Nat) is well-typed — was ill-typed before due to universe inflation
  (check-equal?
   (last (run-ns "(ns nc3)\n(require [prologos.data.list :refer [List nil cons]])\n(require [prologos.data.option :refer [Option some none]])\n(check (some (List Nat) (cons Nat zero (nil Nat))) : (Option (List Nat)))"))
   "OK"))

(test-case "native-ctor/list-list-nat"
  ;; List (List Nat) is well-typed — was ill-typed before due to universe inflation
  (check-equal?
   (last (run-ns "(ns nc4)\n(require [prologos.data.list :refer [List nil cons]])\n(check (cons (List Nat) (cons Nat zero (nil Nat)) (nil (List Nat))) : (List (List Nat)))"))
   "OK"))

(test-case "native-ctor/compose-sum-reverse"
  ;; sum (reverse [1,2,3]) = 6 — composition works without reification
  (check-equal?
   (last (run-ns "(ns nc5)\n(require [prologos.data.list :refer [List nil cons sum reverse]])\n(eval (sum (reverse Nat (cons Nat (inc zero) (cons Nat (inc (inc zero)) (cons Nat (inc (inc (inc zero))) (nil Nat)))))))"))
   "6 : Nat"))

(test-case "native-ctor/compose-sum-map"
  ;; sum (map inc [1,2,3]) = 9 — composition works without reification
  (check-equal?
   (last (run-ns "(ns nc6)\n(require [prologos.data.list :refer [List nil cons sum map]])\n(require [prologos.data.nat :refer [add]])\n(def my-inc : (-> Nat Nat) (fn (n : Nat) (inc n)))\n(eval (sum (map Nat Nat my-inc (cons Nat (inc zero) (cons Nat (inc (inc zero)) (cons Nat (inc (inc (inc zero))) (nil Nat)))))))"))
   "9 : Nat"))

(test-case "native-ctor/compose-length-filter"
  ;; length (filter zero? [0,1,2,0,3]) = 2
  (check-equal?
   (last (run-ns "(ns nc7)\n(require [prologos.data.list :refer [List nil cons length filter]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (length Nat (filter Nat zero? (cons Nat zero (cons Nat (inc zero) (cons Nat (inc (inc zero)) (cons Nat zero (cons Nat (inc (inc (inc zero))) (nil Nat)))))))))"))
   "2 : Nat"))

(test-case "native-ctor/compose-sort-sum"
  ;; sum (sort le [3,1,2]) = 6 — sort + sum compose correctly
  (check-equal?
   (last (run-ns "(ns nc8)\n(require [prologos.data.list :refer [List nil cons sum sort]])\n(require [prologos.data.nat :refer [le?]])\n(eval (sum (sort Nat le? (cons Nat (inc (inc (inc zero))) (cons Nat (inc zero) (cons Nat (inc (inc zero)) (nil Nat)))))))"))
   "6 : Nat"))

(test-case "native-ctor/nested-match"
  ;; Match on Option returning List, then match on the List
  (check-equal?
   (last (run-ns "(ns nc9)\n(require [prologos.data.list :refer [List nil cons sum]])\n(require [prologos.data.option :refer [Option some none]])\n(def my-opt : (Option (List Nat)) (some (List Nat) (cons Nat (inc zero) (cons Nat (inc (inc zero)) (nil Nat)))))\n(eval (the Nat (match my-opt (none -> zero) (some xs -> (sum xs)))))"))
   "3 : Nat"))

;; ========================================
;; Implicit Argument Inference Tests
;; ========================================

;; cons with implicit type arg (1 implicit, 2 explicit → unambiguous)
(test-case "implicit/cons-zero-nil"
  (check-equal?
   (last (run-ns "(ns imp1)\n(require [prologos.data.list :refer [List nil cons length]])\n(eval (length Nat (cons zero (nil Nat))))"))
   "1 : Nat"))

;; bare nil auto-applies (all-implicit type)
(test-case "implicit/bare-nil"
  (check-equal?
   (last (run-ns "(ns imp2)\n(require [prologos.data.list :refer [List nil length]])\n(eval (length Nat nil))"))
   "zero : Nat"))

;; cons zero nil — both cons and nil with implicit insertion
(test-case "implicit/cons-zero-bare-nil"
  (check-equal?
   (last (run-ns "(ns imp3)\n(require [prologos.data.list :refer [List nil cons length]])\n(eval (length Nat (cons zero nil)))"))
   "1 : Nat"))

;; singleton with implicit insertion (1 implicit, 1 explicit)
(test-case "implicit/singleton-zero"
  (check-equal?
   (last (run-ns "(ns imp4)\n(require [prologos.data.list :refer [List singleton length]])\n(eval (length Nat (singleton zero)))"))
   "1 : Nat"))

;; backward compat: explicit type args still work
(test-case "implicit/backward-compat-cons"
  (check-equal?
   (last (run-ns "(ns imp5)\n(require [prologos.data.list :refer [List nil cons length]])\n(eval (length Nat (cons Nat zero (nil Nat))))"))
   "1 : Nat"))

;; backward compat: explicit type args to nil still work
(test-case "implicit/backward-compat-nil"
  (check-equal?
   (last (run-ns "(ns imp6)\n(require [prologos.data.list :refer [List nil length]])\n(eval (length Nat (nil Nat)))"))
   "zero : Nat"))

;; some with implicit insertion
(test-case "implicit/some-zero"
  (check-equal?
   (last (run-ns "(ns imp7)\n(require [prologos.data.option :refer [Option some unwrap-or]])\n(eval (unwrap-or Nat (inc zero) (some Nat zero)))"))
   "zero : Nat"))

;; bare none auto-applies
(test-case "implicit/bare-none"
  (check-equal?
   (last (run-ns "(ns imp8)\n(require [prologos.data.option :refer [Option none unwrap-or]])\n(eval (unwrap-or Nat (inc zero) none))"))
   "1 : Nat"))

;; underscore _ in app args now desugars to placeholder (partial application).
;; Use explicit type argument Nat instead of _ hole.
(test-case "implicit/explicit-type-arg"
  (check-equal?
   (last (run-ns "(ns imp9)\n(require [prologos.data.list :refer [List nil cons length]])\n(eval (length Nat (cons Nat zero nil)))"))
   "1 : Nat"))

;; ========================================
;; Structural Pattern Matching (match returning ADTs)
;; ========================================
;; These tests verify that match can return higher-kinded types
;; (List, Option, Result) which live at Type 0 with native constructors.

;; map with match returns List B (Type 1)
(test-case "structural-pm/map-returns-list"
  (check-equal?
   (last (run-ns "(ns spm1)\n(require [prologos.data.list :refer [List nil cons map foldr]])\n(require [prologos.data.nat :refer [add]])\n(eval (foldr Nat Nat add zero (map Nat Nat (fn (x : Nat) (inc x)) (cons Nat zero (cons Nat (inc zero) (cons Nat (inc (inc zero)) (nil Nat)))))))"))
   "6 : Nat"))

;; map empty list
(test-case "structural-pm/map-empty"
  (check-equal?
   (last (run-ns "(ns spm2)\n(require [prologos.data.list :refer [List nil map length]])\n(eval (length Nat (map Nat Nat (fn (x : Nat) (inc x)) (nil Nat))))"))
   "zero : Nat"))

;; append with match returns List A (Type 1)
(test-case "structural-pm/append-returns-list"
  (check-equal?
   (last (run-ns "(ns spm3)\n(require [prologos.data.list :refer [List nil cons append foldr]])\n(require [prologos.data.nat :refer [add]])\n(eval (foldr Nat Nat add zero (append Nat (cons Nat (inc zero) (nil Nat)) (cons Nat (inc (inc zero)) (nil Nat)))))"))
   "3 : Nat"))

;; option/map with match returns Option B (Type 1)
(test-case "structural-pm/option-map"
  (check-equal?
   (last (run-ns "(ns spm4)\n(require [prologos.data.option :refer [Option none some map unwrap-or]])\n(eval (unwrap-or Nat zero (map Nat Nat (fn (x : Nat) (inc x)) (some Nat (inc (inc zero))))))"))
   "3 : Nat"))

;; option/flat-map with match returns Option B (Type 1)
(test-case "structural-pm/option-flat-map"
  (check-equal?
   (last (run-ns "(ns spm5)\n(require [prologos.data.option :refer [Option none some flat-map unwrap-or]])\n(eval (unwrap-or Nat zero (flat-map Nat Nat (fn (x : Nat) (some Nat (inc x))) (some Nat (inc zero)))))"))
   "2 : Nat"))

;; option/or-else with match returns Option A (Type 1)
(test-case "structural-pm/option-or-else"
  (check-equal?
   (last (run-ns "(ns spm6)\n(require [prologos.data.option :refer [Option none some or-else unwrap-or]])\n(eval (unwrap-or Nat zero (or-else Nat (none Nat) (some Nat (inc (inc (inc zero)))))))"))
   "3 : Nat"))

;; option/zip-with with nested match returns Option C (Type 1)
(test-case "structural-pm/option-zip-with"
  (check-equal?
   (last (run-ns "(ns spm7)\n(require [prologos.data.option :refer [Option none some zip-with unwrap-or]])\n(require [prologos.data.nat :refer [add]])\n(eval (unwrap-or Nat zero (zip-with Nat Nat Nat add (some Nat (inc zero)) (some Nat (inc (inc zero))))))"))
   "3 : Nat"))

;; result/map with match returns Result B E (Type 1)
(test-case "structural-pm/result-map"
  (check-equal?
   (last (run-ns "(ns spm8)\n(require [prologos.data.result :refer [Result ok err map unwrap-or]])\n(eval (unwrap-or Nat Nat zero (map Nat Nat Nat (fn (x : Nat) (inc x)) (ok Nat Nat (inc (inc zero))))))"))
   "3 : Nat"))

;; result/and-then with match returns Result B E (Type 1)
(test-case "structural-pm/result-and-then"
  (check-equal?
   (last (run-ns "(ns spm9)\n(require [prologos.data.result :refer [Result ok err and-then unwrap-or]])\n(eval (unwrap-or Nat Nat zero (and-then Nat Nat Nat (fn (x : Nat) (ok Nat Nat (inc x))) (ok Nat Nat (inc zero)))))"))
   "2 : Nat"))

;; result/or-else with match returns Result A F (Type 1)
(test-case "structural-pm/result-or-else"
  (check-equal?
   (last (run-ns "(ns spm10)\n(require [prologos.data.result :refer [Result ok err or-else unwrap-or]])\n(eval (unwrap-or Nat Nat zero (or-else Nat Nat Nat (fn (e : Nat) (ok Nat Nat (inc e))) (err Nat Nat (inc (inc zero))))))"))
   "3 : Nat"))

;; ========================================
;; prologos.data.list — Sprint 1.1 New Functions
;; ========================================

;; --- reduce (left fold) ---

(test-case "list/reduce-empty"
  ;; reduce add 0 [] = 0
  (check-equal?
   (last (run-ns "(ns lst100)\n(require [prologos.data.list :refer [List nil reduce]])\n(require [prologos.data.nat :refer [add]])\n(eval (reduce Nat Nat add zero (nil Nat)))"))
   "zero : Nat"))

(test-case "list/reduce-single"
  ;; reduce add 0 [5] = 5
  (check-equal?
   (last (run-ns "(ns lst101)\n(require [prologos.data.list :refer [List nil cons reduce]])\n(require [prologos.data.nat :refer [add]])\n(eval (reduce Nat Nat add zero (cons Nat (inc (inc (inc (inc (inc zero))))) (nil Nat))))"))
   "5 : Nat"))

(test-case "list/reduce-multi"
  ;; reduce add 0 [1,2,3] = 6
  (check-equal?
   (last (run-ns "(ns lst102)\n(require [prologos.data.list :refer [List nil cons reduce]])\n(require [prologos.data.nat :refer [add]])\n(eval (reduce Nat Nat add zero (cons Nat (inc zero) (cons Nat (inc (inc zero)) (cons Nat (inc (inc (inc zero))) (nil Nat))))))"))
   "6 : Nat"))

;; --- tail ---

;; NOTE: tail tests re-enabled — Option (List A) is well-typed now (List A : Type 0)

(test-case "list/tail-empty"
  (check-equal?
   (last (run-ns "(ns lst103)\n(require [prologos.data.list :refer [List nil tail length]])\n(require [prologos.data.option :refer [unwrap-or]])\n(eval (length Nat (unwrap-or (List Nat) (nil Nat) (tail Nat (nil Nat)))))"))
   "zero : Nat"))

(test-case "list/tail-nonempty"
  (check-equal?
   (last (run-ns "(ns lst104)\n(require [prologos.data.list :refer [List nil cons tail length]])\n(require [prologos.data.option :refer [unwrap-or]])\n(eval (length Nat (unwrap-or (List Nat) (nil Nat) (tail Nat (cons Nat (inc zero) (cons Nat (inc (inc zero)) (cons Nat (inc (inc (inc zero))) (nil Nat))))))))"))
   "2 : Nat"))

;; --- reverse ---

(test-case "list/reverse-empty"
  ;; reverse [] = [], length 0
  (check-equal?
   (last (run-ns "(ns lst105)\n(require [prologos.data.list :refer [List nil reverse length]])\n(eval (length Nat (reverse Nat (nil Nat))))"))
   "zero : Nat"))

(test-case "list/reverse-single"
  ;; reverse [5] = [5], head = 5
  (check-equal?
   (last (run-ns "(ns lst106)\n(require [prologos.data.list :refer [List nil cons reverse head]])\n(eval (head Nat zero (reverse Nat (cons Nat (inc (inc (inc (inc (inc zero))))) (nil Nat)))))"))
   "5 : Nat"))

(test-case "list/reverse-multi"
  ;; reverse [1,2,3], head = 3
  (check-equal?
   (last (run-ns "(ns lst107)\n(require [prologos.data.list :refer [List nil cons reverse head]])\n(eval (head Nat zero (reverse Nat (cons Nat (inc zero) (cons Nat (inc (inc zero)) (cons Nat (inc (inc (inc zero))) (nil Nat)))))))"))
   "3 : Nat"))

;; --- sum ---

(test-case "list/sum-empty"
  ;; sum [] = 0
  (check-equal?
   (last (run-ns "(ns lst108)\n(require [prologos.data.list :refer [List nil sum]])\n(eval (sum (nil Nat)))"))
   "zero : Nat"))

(test-case "list/sum-multi"
  ;; sum [1,2,3] = 6
  (check-equal?
   (last (run-ns "(ns lst109)\n(require [prologos.data.list :refer [List nil cons sum]])\n(eval (sum (cons Nat (inc zero) (cons Nat (inc (inc zero)) (cons Nat (inc (inc (inc zero))) (nil Nat))))))"))
   "6 : Nat"))

;; --- product ---

(test-case "list/product-empty"
  ;; product [] = 1
  (check-equal?
   (last (run-ns "(ns lst110)\n(require [prologos.data.list :refer [List nil product]])\n(eval (product (nil Nat)))"))
   "1 : Nat"))

(test-case "list/product-multi"
  ;; product [2,3] = 6
  (check-equal?
   (last (run-ns "(ns lst111)\n(require [prologos.data.list :refer [List nil cons product]])\n(eval (product (cons Nat (inc (inc zero)) (cons Nat (inc (inc (inc zero))) (nil Nat)))))"))
   "6 : Nat"))

;; --- any? ---

(test-case "list/any?-empty"
  ;; any? zero? [] = false
  (check-equal?
   (last (run-ns "(ns lst112)\n(require [prologos.data.list :refer [List nil any?]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (any? Nat zero? (nil Nat)))"))
   "false : Bool"))

(test-case "list/any?-found"
  ;; any? zero? [1, 0, 2] = true
  (check-equal?
   (last (run-ns "(ns lst113)\n(require [prologos.data.list :refer [List nil cons any?]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (any? Nat zero? (cons Nat (inc zero) (cons Nat zero (cons Nat (inc (inc zero)) (nil Nat))))))"))
   "true : Bool"))

(test-case "list/any?-not-found"
  ;; any? zero? [1, 2] = false
  (check-equal?
   (last (run-ns "(ns lst114)\n(require [prologos.data.list :refer [List nil cons any?]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (any? Nat zero? (cons Nat (inc zero) (cons Nat (inc (inc zero)) (nil Nat)))))"))
   "false : Bool"))

;; --- all? ---

(test-case "list/all?-empty"
  ;; all? zero? [] = true (vacuously)
  (check-equal?
   (last (run-ns "(ns lst115)\n(require [prologos.data.list :refer [List nil all?]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (all? Nat zero? (nil Nat)))"))
   "true : Bool"))

(test-case "list/all?-all-pass"
  ;; all? zero? [0, 0] = true
  (check-equal?
   (last (run-ns "(ns lst116)\n(require [prologos.data.list :refer [List nil cons all?]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (all? Nat zero? (cons Nat zero (cons Nat zero (nil Nat)))))"))
   "true : Bool"))

(test-case "list/all?-some-fail"
  ;; all? zero? [0, 1] = false
  (check-equal?
   (last (run-ns "(ns lst117)\n(require [prologos.data.list :refer [List nil cons all?]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (all? Nat zero? (cons Nat zero (cons Nat (inc zero) (nil Nat)))))"))
   "false : Bool"))

;; --- find ---

(test-case "list/find-empty"
  ;; find zero? [] = none, unwrap-or to 5
  (check-equal?
   (last (run-ns "(ns lst118)\n(require [prologos.data.list :refer [List nil find]])\n(require [prologos.data.nat :refer [zero?]])\n(require [prologos.data.option :refer [unwrap-or]])\n(eval (unwrap-or Nat (inc (inc (inc (inc (inc zero))))) (find Nat zero? (nil Nat))))"))
   "5 : Nat"))

(test-case "list/find-found"
  ;; find zero? [1, 0, 2] = some 0
  (check-equal?
   (last (run-ns "(ns lst119)\n(require [prologos.data.list :refer [List nil cons find]])\n(require [prologos.data.nat :refer [zero?]])\n(require [prologos.data.option :refer [unwrap-or]])\n(eval (unwrap-or Nat (inc (inc (inc (inc (inc zero))))) (find Nat zero? (cons Nat (inc zero) (cons Nat zero (cons Nat (inc (inc zero)) (nil Nat)))))))"))
   "zero : Nat"))

(test-case "list/find-not-found"
  ;; find zero? [1, 2] = none, unwrap-or to 5
  (check-equal?
   (last (run-ns "(ns lst120)\n(require [prologos.data.list :refer [List nil cons find]])\n(require [prologos.data.nat :refer [zero?]])\n(require [prologos.data.option :refer [unwrap-or]])\n(eval (unwrap-or Nat (inc (inc (inc (inc (inc zero))))) (find Nat zero? (cons Nat (inc zero) (cons Nat (inc (inc zero)) (nil Nat))))))"))
   "5 : Nat"))

;; --- nth ---

(test-case "list/nth-valid"
  ;; nth 1 [3, 5, 7] = some 5
  (check-equal?
   (last (run-ns "(ns lst121)\n(require [prologos.data.list :refer [List nil cons nth]])\n(require [prologos.data.option :refer [unwrap-or]])\n(eval (unwrap-or Nat zero (nth Nat (inc zero) (cons Nat (inc (inc (inc zero))) (cons Nat (inc (inc (inc (inc (inc zero))))) (cons Nat (inc (inc (inc (inc (inc (inc (inc zero))))))) (nil Nat)))))))"))
   "5 : Nat"))

(test-case "list/nth-out-of-bounds"
  ;; nth 5 [1,2] = none, unwrap-or to 0
  (check-equal?
   (last (run-ns "(ns lst122)\n(require [prologos.data.list :refer [List nil cons nth]])\n(require [prologos.data.option :refer [unwrap-or]])\n(eval (unwrap-or Nat zero (nth Nat (inc (inc (inc (inc (inc zero))))) (cons Nat (inc zero) (cons Nat (inc (inc zero)) (nil Nat))))))"))
   "zero : Nat"))

(test-case "list/nth-empty"
  ;; nth 0 [] = none, unwrap-or to 0
  (check-equal?
   (last (run-ns "(ns lst123)\n(require [prologos.data.list :refer [List nil nth]])\n(require [prologos.data.option :refer [unwrap-or]])\n(eval (unwrap-or Nat zero (nth Nat zero (nil Nat))))"))
   "zero : Nat"))

;; --- last (Prologos function) ---

(test-case "list/last-empty"
  ;; last [] = none, unwrap-or to 0
  (check-equal?
   (last (run-ns "(ns lst124)\n(require [prologos.data.list :refer [List nil last]])\n(require [prologos.data.option :refer [unwrap-or]])\n(eval (unwrap-or Nat zero (last Nat (nil Nat))))"))
   "zero : Nat"))

(test-case "list/last-nonempty"
  ;; last [1,2,3] = some 3
  (check-equal?
   (last (run-ns "(ns lst125)\n(require [prologos.data.list :refer [List nil cons last]])\n(require [prologos.data.option :refer [unwrap-or]])\n(eval (unwrap-or Nat zero (last Nat (cons Nat (inc zero) (cons Nat (inc (inc zero)) (cons Nat (inc (inc (inc zero))) (nil Nat)))))))"))
   "3 : Nat"))

;; --- replicate ---

(test-case "list/replicate-zero"
  ;; replicate 0 x = [], length 0
  (check-equal?
   (last (run-ns "(ns lst126)\n(require [prologos.data.list :refer [List replicate length]])\n(eval (length Nat (replicate Nat zero (inc (inc (inc zero))))))"))
   "zero : Nat"))

(test-case "list/replicate-positive"
  ;; replicate 3 5 = [5,5,5], sum = 15
  (check-equal?
   (last (run-ns "(ns lst127)\n(require [prologos.data.list :refer [List replicate sum]])\n(eval (sum (replicate Nat (inc (inc (inc zero))) (inc (inc (inc (inc (inc zero))))))))"))
   "15 : Nat"))

;; --- range ---

(test-case "list/range-zero"
  ;; range 0 = [], length 0
  (check-equal?
   (last (run-ns "(ns lst128)\n(require [prologos.data.list :refer [List range length]])\n(eval (length Nat (range zero)))"))
   "zero : Nat"))

(test-case "list/range-one"
  ;; range 1 = [0], length = 1
  (check-equal?
   (last (run-ns "(ns lst129)\n(require [prologos.data.list :refer [List range length]])\n(eval (length Nat (range (inc zero))))"))
   "1 : Nat"))

(test-case "list/range-multi"
  ;; range 4 = [0,1,2,3], sum = 6
  (check-equal?
   (last (run-ns "(ns lst130)\n(require [prologos.data.list :refer [List range sum]])\n(eval (sum (range (inc (inc (inc (inc zero)))))))"))
   "6 : Nat"))

;; --- concat ---

;; concat tests: re-enabled — List A : Type 0 now (native constructors, no Church encoding)

(test-case "list/concat-empty"
  ;; concat [] = []
  (check-equal?
   (last (run-ns "(ns lst131)\n(require [prologos.data.list :refer [List nil cons concat length]])\n(eval (length Nat (concat Nat (nil (List Nat)))))"))
   "zero : Nat"))

(test-case "list/concat-multi"
  ;; concat [[1,2],[3]] = [1,2,3], sum = 6
  (check-equal?
   (last (run-ns "(ns lst132)\n(require [prologos.data.list :refer [List nil cons concat sum]])\n(eval (sum (concat Nat (cons (List Nat) (cons Nat (inc zero) (cons Nat (inc (inc zero)) (nil Nat))) (cons (List Nat) (cons Nat (inc (inc (inc zero))) (nil Nat)) (nil (List Nat)))))))"))
   "6 : Nat"))

;; --- concat-map ---

(test-case "list/concat-map-empty"
  ;; concat-map f [] = [], length 0
  (check-equal?
   (last (run-ns "(ns lst133)\n(require [prologos.data.list :refer [List nil cons singleton concat-map length]])\n(eval (length Nat (concat-map Nat Nat (fn (x : Nat) (singleton Nat x)) (nil Nat))))"))
   "zero : Nat"))

(test-case "list/concat-map-duplicate"
  ;; concat-map (\x -> [x, x]) [1, 2] = [1,1,2,2], sum = 6
  (check-equal?
   (last (run-ns "(ns lst134)\n(require [prologos.data.list :refer [List nil cons concat-map sum]])\n(eval (sum (concat-map Nat Nat (fn (x : Nat) (cons Nat x (cons Nat x (nil Nat)))) (cons Nat (inc zero) (cons Nat (inc (inc zero)) (nil Nat))))))"))
   "6 : Nat"))

;; --- take ---

(test-case "list/take-zero"
  ;; take 0 [1,2,3] = [], length 0
  (check-equal?
   (last (run-ns "(ns lst135)\n(require [prologos.data.list :refer [List nil cons take length]])\n(eval (length Nat (take Nat zero (cons Nat (inc zero) (cons Nat (inc (inc zero)) (cons Nat (inc (inc (inc zero))) (nil Nat)))))))"))
   "zero : Nat"))

(test-case "list/take-within"
  ;; take 2 [1,2,3] = [1,2], sum = 3
  (check-equal?
   (last (run-ns "(ns lst136)\n(require [prologos.data.list :refer [List nil cons take sum]])\n(eval (sum (take Nat (inc (inc zero)) (cons Nat (inc zero) (cons Nat (inc (inc zero)) (cons Nat (inc (inc (inc zero))) (nil Nat)))))))"))
   "3 : Nat"))

(test-case "list/take-exceeds"
  ;; take 5 [1,2] = [1,2], sum = 3
  (check-equal?
   (last (run-ns "(ns lst137)\n(require [prologos.data.list :refer [List nil cons take sum]])\n(eval (sum (take Nat (inc (inc (inc (inc (inc zero))))) (cons Nat (inc zero) (cons Nat (inc (inc zero)) (nil Nat))))))"))
   "3 : Nat"))

;; --- drop ---

(test-case "list/drop-zero"
  ;; drop 0 [1,2,3] = [1,2,3], sum = 6
  (check-equal?
   (last (run-ns "(ns lst138)\n(require [prologos.data.list :refer [List nil cons drop sum]])\n(eval (sum (drop Nat zero (cons Nat (inc zero) (cons Nat (inc (inc zero)) (cons Nat (inc (inc (inc zero))) (nil Nat)))))))"))
   "6 : Nat"))

(test-case "list/drop-within"
  ;; drop 1 [1,2,3] = [2,3], sum = 5
  (check-equal?
   (last (run-ns "(ns lst139)\n(require [prologos.data.list :refer [List nil cons drop sum]])\n(eval (sum (drop Nat (inc zero) (cons Nat (inc zero) (cons Nat (inc (inc zero)) (cons Nat (inc (inc (inc zero))) (nil Nat)))))))"))
   "5 : Nat"))

(test-case "list/drop-exceeds"
  ;; drop 5 [1,2] = [], length 0
  (check-equal?
   (last (run-ns "(ns lst140)\n(require [prologos.data.list :refer [List nil cons drop length]])\n(eval (length Nat (drop Nat (inc (inc (inc (inc (inc zero))))) (cons Nat (inc zero) (cons Nat (inc (inc zero)) (nil Nat))))))"))
   "zero : Nat"))

;; --- split-at ---

(test-case "list/split-at-first"
  ;; split-at 2 [1,2,3], first part sum = 3
  (check-equal?
   (last (run-ns "(ns lst141)\n(require [prologos.data.list :refer [List nil cons split-at sum]])\n(eval (sum (first (split-at Nat (inc (inc zero)) (cons Nat (inc zero) (cons Nat (inc (inc zero)) (cons Nat (inc (inc (inc zero))) (nil Nat))))))))"))
   "3 : Nat"))

(test-case "list/split-at-second"
  ;; split-at 2 [1,2,3], second part sum = 3
  (check-equal?
   (last (run-ns "(ns lst142)\n(require [prologos.data.list :refer [List nil cons split-at sum]])\n(eval (sum (second (split-at Nat (inc (inc zero)) (cons Nat (inc zero) (cons Nat (inc (inc zero)) (cons Nat (inc (inc (inc zero))) (nil Nat))))))))"))
   "3 : Nat"))

;; --- take-while ---

(test-case "list/take-while-all-pass"
  ;; take-while zero? [0,0,0] = [0,0,0], length 3
  (check-equal?
   (last (run-ns "(ns lst143)\n(require [prologos.data.list :refer [List nil cons take-while length]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (length Nat (take-while Nat zero? (cons Nat zero (cons Nat zero (cons Nat zero (nil Nat)))))))"))
   "3 : Nat"))

(test-case "list/take-while-some-pass"
  ;; take-while zero? [0, 0, 1, 0] = [0, 0], length 2
  (check-equal?
   (last (run-ns "(ns lst144)\n(require [prologos.data.list :refer [List nil cons take-while length]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (length Nat (take-while Nat zero? (cons Nat zero (cons Nat zero (cons Nat (inc zero) (cons Nat zero (nil Nat))))))))"))
   "2 : Nat"))

(test-case "list/take-while-none-pass"
  ;; take-while zero? [1, 2] = [], length 0
  (check-equal?
   (last (run-ns "(ns lst145)\n(require [prologos.data.list :refer [List nil cons take-while length]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (length Nat (take-while Nat zero? (cons Nat (inc zero) (cons Nat (inc (inc zero)) (nil Nat))))))"))
   "zero : Nat"))

;; --- drop-while ---

(test-case "list/drop-while-all-pass"
  ;; drop-while zero? [0,0,0] = [], length 0
  (check-equal?
   (last (run-ns "(ns lst146)\n(require [prologos.data.list :refer [List nil cons drop-while length]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (length Nat (drop-while Nat zero? (cons Nat zero (cons Nat zero (cons Nat zero (nil Nat)))))))"))
   "zero : Nat"))

(test-case "list/drop-while-some-pass"
  ;; drop-while zero? [0, 0, 1, 2] = [1, 2], sum = 3
  (check-equal?
   (last (run-ns "(ns lst147)\n(require [prologos.data.list :refer [List nil cons drop-while sum]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (sum (drop-while Nat zero? (cons Nat zero (cons Nat zero (cons Nat (inc zero) (cons Nat (inc (inc zero)) (nil Nat))))))))"))
   "3 : Nat"))

(test-case "list/drop-while-none-pass"
  ;; drop-while zero? [1, 2, 3] = [1, 2, 3], sum = 6
  (check-equal?
   (last (run-ns "(ns lst148)\n(require [prologos.data.list :refer [List nil cons drop-while sum]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (sum (drop-while Nat zero? (cons Nat (inc zero) (cons Nat (inc (inc zero)) (cons Nat (inc (inc (inc zero))) (nil Nat)))))))"))
   "6 : Nat"))

;; --- partition ---

(test-case "list/partition-first"
  ;; partition zero? [0, 1, 0, 2], first = zeros, length 2
  (check-equal?
   (last (run-ns "(ns lst149)\n(require [prologos.data.list :refer [List nil cons partition length]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (length Nat (first (partition Nat zero? (cons Nat zero (cons Nat (inc zero) (cons Nat zero (cons Nat (inc (inc zero)) (nil Nat)))))))))"))
   "2 : Nat"))

(test-case "list/partition-second"
  ;; partition zero? [0, 1, 0, 2], second = non-zeros, sum = 3
  (check-equal?
   (last (run-ns "(ns lst150)\n(require [prologos.data.list :refer [List nil cons partition sum]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (sum (second (partition Nat zero? (cons Nat zero (cons Nat (inc zero) (cons Nat zero (cons Nat (inc (inc zero)) (nil Nat)))))))))"))
   "3 : Nat"))

;; --- zip-with ---

(test-case "list/zip-with-empty"
  ;; zip-with add [] [] = [], length 0
  (check-equal?
   (last (run-ns "(ns lst151)\n(require [prologos.data.list :refer [List nil zip-with length]])\n(require [prologos.data.nat :refer [add]])\n(eval (length Nat (zip-with Nat Nat Nat add (nil Nat) (nil Nat))))"))
   "zero : Nat"))

(test-case "list/zip-with-same-length"
  ;; zip-with add [1,2] [3,4] = [4,6], sum = 10
  (check-equal?
   (last (run-ns "(ns lst152)\n(require [prologos.data.list :refer [List nil cons zip-with sum]])\n(require [prologos.data.nat :refer [add]])\n(eval (sum (zip-with Nat Nat Nat add (cons Nat (inc zero) (cons Nat (inc (inc zero)) (nil Nat))) (cons Nat (inc (inc (inc zero))) (cons Nat (inc (inc (inc (inc zero)))) (nil Nat))))))"))
   "10 : Nat"))

(test-case "list/zip-with-diff-length"
  ;; zip-with add [1,2,3] [10] = [11], sum = 11
  (check-equal?
   (last (run-ns "(ns lst153)\n(require [prologos.data.list :refer [List nil cons zip-with sum]])\n(require [prologos.data.nat :refer [add]])\n(eval (sum (zip-with Nat Nat Nat add (cons Nat (inc zero) (cons Nat (inc (inc zero)) (cons Nat (inc (inc (inc zero))) (nil Nat)))) (cons Nat (inc (inc (inc (inc (inc (inc (inc (inc (inc (inc zero)))))))))) (nil Nat)))))"))
   "11 : Nat"))

;; --- zip ---

(test-case "list/zip-length"
  ;; zip [1,2] [3,4], length = 2
  (check-equal?
   (last (run-ns "(ns lst154)\n(require [prologos.data.list :refer [List nil cons zip length]])\n(eval (length (Sigma [_ <Nat>] Nat) (zip Nat Nat (cons Nat (inc zero) (cons Nat (inc (inc zero)) (nil Nat))) (cons Nat (inc (inc (inc zero))) (cons Nat (inc (inc (inc (inc zero)))) (nil Nat))))))"))
   "2 : Nat"))

(test-case "list/zip-head-first"
  ;; zip [1,2] [3,4], first element of head pair = 1
  (check-equal?
   (last (run-ns "(ns lst155)\n(require [prologos.data.list :refer [List nil cons zip head]])\n(eval (first (head (Sigma [_ <Nat>] Nat) (pair zero zero) (zip Nat Nat (cons Nat (inc zero) (cons Nat (inc (inc zero)) (nil Nat))) (cons Nat (inc (inc (inc zero))) (cons Nat (inc (inc (inc (inc zero)))) (nil Nat)))))))"))
   "1 : Nat"))

;; --- unzip ---

(test-case "list/unzip-firsts"
  ;; unzip [(1,2), (3,4)], first list sum = 4
  (check-equal?
   (last (run-ns "(ns lst156)\n(require [prologos.data.list :refer [List nil cons unzip sum]])\n(eval (sum (first (unzip Nat Nat (cons (Sigma [_ <Nat>] Nat) (pair (inc zero) (inc (inc zero))) (cons (Sigma [_ <Nat>] Nat) (pair (inc (inc (inc zero))) (inc (inc (inc (inc zero))))) (nil (Sigma [_ <Nat>] Nat))))))))"))
   "4 : Nat"))

(test-case "list/unzip-seconds"
  ;; unzip [(1,2), (3,4)], second list sum = 6
  (check-equal?
   (last (run-ns "(ns lst157)\n(require [prologos.data.list :refer [List nil cons unzip sum]])\n(eval (sum (second (unzip Nat Nat (cons (Sigma [_ <Nat>] Nat) (pair (inc zero) (inc (inc zero))) (cons (Sigma [_ <Nat>] Nat) (pair (inc (inc (inc zero))) (inc (inc (inc (inc zero))))) (nil (Sigma [_ <Nat>] Nat))))))))"))
   "6 : Nat"))

;; --- intersperse ---

(test-case "list/intersperse-empty"
  ;; intersperse 0 [] = [], length 0
  (check-equal?
   (last (run-ns "(ns lst158)\n(require [prologos.data.list :refer [List nil intersperse length]])\n(eval (length Nat (intersperse Nat zero (nil Nat))))"))
   "zero : Nat"))

(test-case "list/intersperse-single"
  ;; intersperse 0 [1] = [1], length 1
  (check-equal?
   (last (run-ns "(ns lst159)\n(require [prologos.data.list :refer [List nil cons intersperse length]])\n(eval (length Nat (intersperse Nat zero (cons Nat (inc zero) (nil Nat)))))"))
   "1 : Nat"))

(test-case "list/intersperse-multi"
  ;; intersperse 0 [1,2,3] = [1,0,2,0,3], length = 5
  (check-equal?
   (last (run-ns "(ns lst160)\n(require [prologos.data.list :refer [List nil cons intersperse length]])\n(eval (length Nat (intersperse Nat zero (cons Nat (inc zero) (cons Nat (inc (inc zero)) (cons Nat (inc (inc (inc zero))) (nil Nat)))))))"))
   "5 : Nat"))

;; --- halve ---

(test-case "list/halve-empty"
  ;; halve [] = ([], []), first length 0
  (check-equal?
   (last (run-ns "(ns lst161)\n(require [prologos.data.list :refer [List nil halve length]])\n(eval (length Nat (first (halve Nat (nil Nat)))))"))
   "zero : Nat"))

(test-case "list/halve-odd"
  ;; halve [1,2,3] — alternating: first = [1,3] (length 2)
  (check-equal?
   (last (run-ns "(ns lst162)\n(require [prologos.data.list :refer [List nil cons halve length]])\n(eval (length Nat (first (halve Nat (cons Nat (inc zero) (cons Nat (inc (inc zero)) (cons Nat (inc (inc (inc zero))) (nil Nat))))))))"))
   "2 : Nat"))

(test-case "list/halve-even"
  ;; halve [1,2,3,4] — second = [2,4] (length 2)
  (check-equal?
   (last (run-ns "(ns lst163)\n(require [prologos.data.list :refer [List nil cons halve length]])\n(eval (length Nat (second (halve Nat (cons Nat (inc zero) (cons Nat (inc (inc zero)) (cons Nat (inc (inc (inc zero))) (cons Nat (inc (inc (inc (inc zero)))) (nil Nat)))))))))"))
   "2 : Nat"))

;; --- merge ---

(test-case "list/merge-both-empty"
  ;; merge le? [] [] = [], length 0
  (check-equal?
   (last (run-ns "(ns lst164)\n(require [prologos.data.list :refer [List nil merge length]])\n(require [prologos.data.nat :refer [le?]])\n(eval (length Nat (merge Nat le? (nil Nat) (nil Nat))))"))
   "zero : Nat"))

(test-case "list/merge-sorted"
  ;; merge le? [1,3] [2,4] = [1,2,3,4], sum = 10
  (check-equal?
   (last (run-ns "(ns lst165)\n(require [prologos.data.list :refer [List nil cons merge sum]])\n(require [prologos.data.nat :refer [le?]])\n(eval (sum (merge Nat le? (cons Nat (inc zero) (cons Nat (inc (inc (inc zero))) (nil Nat))) (cons Nat (inc (inc zero)) (cons Nat (inc (inc (inc (inc zero)))) (nil Nat))))))"))
   "10 : Nat"))

;; --- sort ---

(test-case "list/sort-empty"
  ;; sort le? [] = [], length 0
  (check-equal?
   (last (run-ns "(ns lst166)\n(require [prologos.data.list :refer [List nil sort length]])\n(require [prologos.data.nat :refer [le?]])\n(eval (length Nat (sort Nat le? (nil Nat))))"))
   "zero : Nat"))

(test-case "list/sort-single"
  ;; sort le? [3] = [3], sum = 3
  (check-equal?
   (last (run-ns "(ns lst167)\n(require [prologos.data.list :refer [List nil cons sort sum]])\n(require [prologos.data.nat :refer [le?]])\n(eval (sum (sort Nat le? (cons Nat (inc (inc (inc zero))) (nil Nat)))))"))
   "3 : Nat"))

(test-case "list/sort-already-sorted"
  ;; sort le? [1,2,3] = [1,2,3], head = 1
  (check-equal?
   (last (run-ns "(ns lst168)\n(require [prologos.data.list :refer [List nil cons sort head]])\n(require [prologos.data.nat :refer [le?]])\n(eval (head Nat zero (sort Nat le? (cons Nat (inc zero) (cons Nat (inc (inc zero)) (cons Nat (inc (inc (inc zero))) (nil Nat)))))))"))
   "1 : Nat"))

(test-case "list/sort-unsorted"
  ;; sort le? [3,1,2] = [1,2,3], head = 1
  (check-equal?
   (last (run-ns "(ns lst169)\n(require [prologos.data.list :refer [List nil cons sort head]])\n(require [prologos.data.nat :refer [le?]])\n(eval (head Nat zero (sort Nat le? (cons Nat (inc (inc (inc zero))) (cons Nat (inc zero) (cons Nat (inc (inc zero)) (nil Nat)))))))"))
   "1 : Nat"))

;; --- Additional verification tests ---

(test-case "list/reverse-sum-preserved"
  ;; reverse preserves sum: sum (reverse [1,2,3]) = 6
  (check-equal?
   (last (run-ns "(ns lst170)\n(require [prologos.data.list :refer [List nil cons reverse sum]])\n(eval (sum (reverse Nat (cons Nat (inc zero) (cons Nat (inc (inc zero)) (cons Nat (inc (inc (inc zero))) (nil Nat)))))))"))
   "6 : Nat"))

(test-case "list/sort-unsorted-sum"
  ;; sort preserves sum: sum (sort [3,1,2]) = 6
  (check-equal?
   (last (run-ns "(ns lst171)\n(require [prologos.data.list :refer [List nil cons sort sum]])\n(require [prologos.data.nat :refer [le?]])\n(eval (sum (sort Nat le? (cons Nat (inc (inc (inc zero))) (cons Nat (inc zero) (cons Nat (inc (inc zero)) (nil Nat)))))))"))
   "6 : Nat"))

(test-case "list/intersperse-sum"
  ;; intersperse 10 [1,2,3] = [1,10,2,10,3], sum = 26
  (check-equal?
   (last (run-ns "(ns lst172)\n(require [prologos.data.list :refer [List nil cons intersperse sum]])\n(eval (sum (intersperse Nat (inc (inc (inc (inc (inc (inc (inc (inc (inc (inc zero)))))))))) (cons Nat (inc zero) (cons Nat (inc (inc zero)) (cons Nat (inc (inc (inc zero))) (nil Nat)))))))"))
   "26 : Nat"))

(test-case "list/replicate-length"
  ;; replicate 4 0 = [0,0,0,0], length = 4
  (check-equal?
   (last (run-ns "(ns lst173)\n(require [prologos.data.list :refer [List replicate length]])\n(eval (length Nat (replicate Nat (inc (inc (inc (inc zero)))) zero)))"))
   "4 : Nat"))

(test-case "list/range-length"
  ;; range 5 has length 5
  (check-equal?
   (last (run-ns "(ns lst174)\n(require [prologos.data.list :refer [List range length]])\n(eval (length Nat (range (inc (inc (inc (inc (inc zero))))))))"))
   "5 : Nat"))

(test-case "list/range-head"
  ;; range 3 = [0,1,2], head = 0
  (check-equal?
   (last (run-ns "(ns lst175)\n(require [prologos.data.list :refer [List range head]])\n(eval (head Nat (inc (inc (inc zero))) (range (inc (inc (inc zero))))))"))
   "zero : Nat"))

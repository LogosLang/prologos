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
               [mi (module-info ns-sym exports (current-global-env) #f (hasheq) (hasheq) (hasheq) (hasheq) #f)])
          (register-module! ns-sym mi))))
    ;; Reset for second module
    (current-global-env (hasheq))
    (current-ns-context #f)
    (process-string s2)))


;; ========================================
;; prologos::data::nat — Module Loading
;; ========================================

(test-case "load prologos::data::nat"
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)])
    (install-module-loader!)
    (define mod (load-module 'prologos::data::nat #f))
    (check-not-false (module-info? mod))
    (define exports (module-info-exports mod))
    (check-not-false (member 'add exports) "exports add")
    (check-not-false (member 'mult exports) "exports mult")
    (check-not-false (member 'double exports) "exports double")
    (check-not-false (member 'pred exports) "exports pred")
    (check-not-false (member 'zero? exports) "exports zero?")))


;; ========================================
;; prologos::data::nat — Addition
;; ========================================

(test-case "nat::add basic"
  ;; 0 + 0 = 0
  (check-equal?
   (run-ns "(ns t1)\n(imports [prologos::data::nat :refer [add]])\n(eval (add zero zero))")
   '("0N : Nat"))
  ;; 0 + 3 = 3
  (check-equal?
   (run-ns "(ns t2)\n(imports [prologos::data::nat :refer [add]])\n(eval (add zero (suc (suc (suc zero)))))")
   '("3N : Nat"))
  ;; 2 + 3 = 5
  (check-equal?
   (run-ns "(ns t3)\n(imports [prologos::data::nat :refer [add]])\n(eval (add (suc (suc zero)) (suc (suc (suc zero)))))")
   '("5N : Nat")))


;; ========================================
;; prologos::data::nat — Multiplication
;; ========================================

(test-case "nat/mult basic"
  ;; 0 * 3 = 0
  (check-equal?
   (run-ns "(ns t4)\n(imports [prologos::data::nat :refer [mult]])\n(eval (mult zero (suc (suc (suc zero)))))")
   '("0N : Nat"))
  ;; 2 * 3 = 6
  (check-equal?
   (run-ns "(ns t5)\n(imports [prologos::data::nat :refer [mult]])\n(eval (mult (suc (suc zero)) (suc (suc (suc zero)))))")
   '("6N : Nat"))
  ;; 3 * 1 = 3
  (check-equal?
   (run-ns "(ns t6)\n(imports [prologos::data::nat :refer [mult]])\n(eval (mult (suc (suc (suc zero))) (suc zero)))")
   '("3N : Nat")))


;; ========================================
;; prologos::data::nat — Double
;; ========================================

(test-case "nat::double"
  ;; double 0 = 0
  (check-equal?
   (run-ns "(ns t7)\n(imports [prologos::data::nat :refer [double]])\n(eval (double zero))")
   '("0N : Nat"))
  ;; double 3 = 6
  (check-equal?
   (run-ns "(ns t8)\n(imports [prologos::data::nat :refer [double]])\n(eval (double (suc (suc (suc zero)))))")
   '("6N : Nat")))


;; ========================================
;; prologos::data::nat — Predecessor
;; ========================================

(test-case "nat/pred"
  ;; pred 0 = 0
  (check-equal?
   (run-ns "(ns t9)\n(imports [prologos::data::nat :refer [pred]])\n(eval (pred zero))")
   '("0N : Nat"))
  ;; pred 3 = 2
  (check-equal?
   (run-ns "(ns t10)\n(imports [prologos::data::nat :refer [pred]])\n(eval (pred (suc (suc (suc zero)))))")
   '("2N : Nat"))
  ;; pred 1 = 0
  (check-equal?
   (run-ns "(ns t11)\n(imports [prologos::data::nat :refer [pred]])\n(eval (pred (suc zero)))")
   '("0N : Nat")))


;; ========================================
;; prologos::data::nat — Is-zero
;; ========================================

(test-case "nat/zero?"
  ;; zero? 0 = true
  (check-equal?
   (run-ns "(ns t12)\n(imports [prologos::data::nat :refer [zero?]])\n(eval (zero? zero))")
   '("true : Bool"))
  ;; zero? 1 = false
  (check-equal?
   (run-ns "(ns t13)\n(imports [prologos::data::nat :refer [zero?]])\n(eval (zero? (suc zero)))")
   '("false : Bool")))


;; ========================================
;; prologos::data::nat — Alias access
;; ========================================

(test-case "nat module with :as alias"
  (check-equal?
   (run-ns "(ns t14)\n(imports [prologos::data::nat :as nat])\n(eval (nat::add (suc zero) (suc (suc zero))))")
   '("3N : Nat")))


;; ========================================
;; prologos::data::nat — Type checking
;; ========================================

(test-case "nat operations type correctly"
  (check-equal?
   (run-ns "(ns t15)\n(imports [prologos::data::nat :refer [add]])\n(check (add zero) <(-> Nat Nat)>)")
   '("OK"))
  (check-equal?
   (run-ns "(ns t16)\n(imports [prologos::data::nat :refer [zero?]])\n(check zero? <(-> Nat Bool)>)")
   '("OK")))


;; ========================================
;; prologos::data::bool — Module Loading
;; ========================================

(test-case "load prologos::data::bool"
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)])
    (install-module-loader!)
    (define mod (load-module 'prologos::data::bool #f))
    (check-not-false (module-info? mod))
    (define exports (module-info-exports mod))
    (check-not-false (member 'not exports) "exports not")
    (check-not-false (member 'and exports) "exports and")
    (check-not-false (member 'or exports) "exports or")
    (check-not-false (member 'xor exports) "exports xor")
    (check-not-false (member 'bool-eq exports) "exports bool-eq")))


;; ========================================
;; prologos::data::bool — NOT
;; ========================================

(test-case "bool::not"
  (check-equal?
   (run-ns "(ns t17)\n(imports [prologos::data::bool :refer [not]])\n(eval (not true))")
   '("false : Bool"))
  (check-equal?
   (run-ns "(ns t18)\n(imports [prologos::data::bool :refer [not]])\n(eval (not false))")
   '("true : Bool")))


;; ========================================
;; prologos::data::bool — AND
;; ========================================

(test-case "bool::and"
  (check-equal?
   (run-ns "(ns t19)\n(imports [prologos::data::bool :refer [and]])\n(eval (and true true))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns t20)\n(imports [prologos::data::bool :refer [and]])\n(eval (and true false))")
   '("false : Bool"))
  (check-equal?
   (run-ns "(ns t21)\n(imports [prologos::data::bool :refer [and]])\n(eval (and false true))")
   '("false : Bool"))
  (check-equal?
   (run-ns "(ns t22)\n(imports [prologos::data::bool :refer [and]])\n(eval (and false false))")
   '("false : Bool")))


;; ========================================
;; prologos::data::bool — OR
;; ========================================

(test-case "bool/or"
  (check-equal?
   (run-ns "(ns t23)\n(imports [prologos::data::bool :refer [or]])\n(eval (or true true))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns t24)\n(imports [prologos::data::bool :refer [or]])\n(eval (or true false))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns t25)\n(imports [prologos::data::bool :refer [or]])\n(eval (or false true))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns t26)\n(imports [prologos::data::bool :refer [or]])\n(eval (or false false))")
   '("false : Bool")))


;; ========================================
;; prologos::data::bool — XOR
;; ========================================

(test-case "bool/xor"
  (check-equal?
   (run-ns "(ns t27)\n(imports [prologos::data::bool :refer [xor]])\n(eval (xor true true))")
   '("false : Bool"))
  (check-equal?
   (run-ns "(ns t28)\n(imports [prologos::data::bool :refer [xor]])\n(eval (xor true false))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns t29)\n(imports [prologos::data::bool :refer [xor]])\n(eval (xor false true))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns t30)\n(imports [prologos::data::bool :refer [xor]])\n(eval (xor false false))")
   '("false : Bool")))


;; ========================================
;; prologos::data::bool — Equality
;; ========================================

(test-case "bool/bool-eq"
  (check-equal?
   (run-ns "(ns t31)\n(imports [prologos::data::bool :refer [bool-eq]])\n(eval (bool-eq true true))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns t32)\n(imports [prologos::data::bool :refer [bool-eq]])\n(eval (bool-eq true false))")
   '("false : Bool"))
  (check-equal?
   (run-ns "(ns t33)\n(imports [prologos::data::bool :refer [bool-eq]])\n(eval (bool-eq false false))")
   '("true : Bool")))

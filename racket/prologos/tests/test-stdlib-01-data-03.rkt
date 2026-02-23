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
               [mi (module-info ns-sym exports (current-global-env) #f (hasheq) (hasheq) (hasheq))])
          (register-module! ns-sym mi))))
    ;; Reset for second module
    (current-global-env (hasheq))
    (current-ns-context #f)
    (process-string s2)))


;; ========================================
;; prologos::data::nat — Min/Max
;; ========================================

(test-case "nat/min"
  (check-equal?
   (run-ns "(ns tm1)\n(require [prologos::data::nat :refer [min]])\n(eval (min (suc (suc (suc (suc (suc zero))))) (suc (suc (suc zero)))))")
   '("3N : Nat"))
  (check-equal?
   (run-ns "(ns tm2)\n(require [prologos::data::nat :refer [min]])\n(eval (min (suc (suc zero)) (suc (suc (suc (suc (suc zero)))))))")
   '("2N : Nat"))
  (check-equal?
   (run-ns "(ns tm3)\n(require [prologos::data::nat :refer [min]])\n(eval (min (suc (suc (suc zero))) (suc (suc (suc zero)))))")
   '("3N : Nat")))


(test-case "nat/max"
  (check-equal?
   (run-ns "(ns tm4)\n(require [prologos::data::nat :refer [max]])\n(eval (max (suc (suc (suc (suc (suc zero))))) (suc (suc (suc zero)))))")
   '("5N : Nat"))
  (check-equal?
   (run-ns "(ns tm5)\n(require [prologos::data::nat :refer [max]])\n(eval (max (suc (suc zero)) (suc (suc (suc (suc (suc zero)))))))")
   '("5N : Nat"))
  (check-equal?
   (run-ns "(ns tm6)\n(require [prologos::data::nat :refer [max]])\n(eval (max (suc (suc (suc zero))) (suc (suc (suc zero)))))")
   '("3N : Nat")))


;; ========================================
;; prologos::data::nat — Power
;; ========================================

(test-case "nat/pow"
  (check-equal?
   (run-ns "(ns tp1)\n(require [prologos::data::nat :refer [pow]])\n(eval (pow (suc (suc zero)) zero))")
   '("1N : Nat"))
  (check-equal?
   (run-ns "(ns tp2)\n(require [prologos::data::nat :refer [pow]])\n(eval (pow (suc (suc zero)) (suc (suc (suc zero)))))")
   '("8N : Nat"))
  (check-equal?
   (run-ns "(ns tp3)\n(require [prologos::data::nat :refer [pow]])\n(eval (pow (suc (suc (suc zero))) (suc (suc zero))))")
   '("9N : Nat"))
  (check-equal?
   (run-ns "(ns tp4)\n(require [prologos::data::nat :refer [pow]])\n(eval (pow zero (suc (suc (suc (suc (suc zero)))))))")
   '("0N : Nat")))


;; ========================================
;; prologos::data::nat — bool-to-nat
;; ========================================

(test-case "nat/bool-to-nat"
  (check-equal?
   (run-ns "(ns tb1)\n(require [prologos::data::nat :refer [bool-to-nat]])\n(eval (bool-to-nat true))")
   '("1N : Nat"))
  (check-equal?
   (run-ns "(ns tb2)\n(require [prologos::data::nat :refer [bool-to-nat]])\n(eval (bool-to-nat false))")
   '("0N : Nat")))


;; ========================================
;; prologos::data::nat — Type checking new functions
;; ========================================

(test-case "nat new functions type correctly"
  (check-equal?
   (run-ns "(ns tt1)\n(require [prologos::data::nat :refer [sub]])\n(check sub <(-> Nat (-> Nat Nat))>)")
   '("OK"))
  (check-equal?
   (run-ns "(ns tt2)\n(require [prologos::data::nat :refer [le?]])\n(check le? <(-> Nat (-> Nat Bool))>)")
   '("OK"))
  (check-equal?
   (run-ns "(ns tt3)\n(require [prologos::data::nat :refer [nat-eq?]])\n(check nat-eq? <(-> Nat (-> Nat Bool))>)")
   '("OK"))
  (check-equal?
   (run-ns "(ns tt4)\n(require [prologos::data::nat :refer [min]])\n(check min <(-> Nat (-> Nat Nat))>)")
   '("OK"))
  (check-equal?
   (run-ns "(ns tt5)\n(require [prologos::data::nat :refer [pow]])\n(check pow <(-> Nat (-> Nat Nat))>)")
   '("OK"))
  (check-equal?
   (run-ns "(ns tt6)\n(require [prologos::data::nat :refer [bool-to-nat]])\n(check bool-to-nat <(-> Bool Nat)>)")
   '("OK")))


;; ========================================
;; prologos::data::nat — Module loading with new exports
;; ========================================

(test-case "load prologos::data::nat with new exports"
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)])
    (install-module-loader!)
    (define mod (load-module 'prologos::data::nat #f))
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
;; prologos::data::bool — NAND
;; ========================================

(test-case "bool/nand"
  (check-equal?
   (run-ns "(ns bn1)\n(require [prologos::data::bool :refer [nand]])\n(eval (nand true true))")
   '("false : Bool"))
  (check-equal?
   (run-ns "(ns bn2)\n(require [prologos::data::bool :refer [nand]])\n(eval (nand true false))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns bn3)\n(require [prologos::data::bool :refer [nand]])\n(eval (nand false true))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns bn4)\n(require [prologos::data::bool :refer [nand]])\n(eval (nand false false))")
   '("true : Bool")))


;; ========================================
;; prologos::data::bool — NOR
;; ========================================

(test-case "bool/nor"
  (check-equal?
   (run-ns "(ns br1)\n(require [prologos::data::bool :refer [nor]])\n(eval (nor true true))")
   '("false : Bool"))
  (check-equal?
   (run-ns "(ns br2)\n(require [prologos::data::bool :refer [nor]])\n(eval (nor true false))")
   '("false : Bool"))
  (check-equal?
   (run-ns "(ns br3)\n(require [prologos::data::bool :refer [nor]])\n(eval (nor false true))")
   '("false : Bool"))
  (check-equal?
   (run-ns "(ns br4)\n(require [prologos::data::bool :refer [nor]])\n(eval (nor false false))")
   '("true : Bool")))


;; ========================================
;; prologos::data::bool — Implies
;; ========================================

(test-case "bool/implies"
  (check-equal?
   (run-ns "(ns bi1)\n(require [prologos::data::bool :refer [implies]])\n(eval (implies true true))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns bi2)\n(require [prologos::data::bool :refer [implies]])\n(eval (implies true false))")
   '("false : Bool"))
  (check-equal?
   (run-ns "(ns bi3)\n(require [prologos::data::bool :refer [implies]])\n(eval (implies false true))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns bi4)\n(require [prologos::data::bool :refer [implies]])\n(eval (implies false false))")
   '("true : Bool")))


;; ========================================
;; prologos::data::bool — New exports
;; ========================================

(test-case "load prologos::data::bool with new exports"
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)])
    (install-module-loader!)
    (define mod (load-module 'prologos::data::bool #f))
    (define exports (module-info-exports mod))
    (check-not-false (member 'nand exports) "exports nand")
    (check-not-false (member 'nor exports) "exports nor")
    (check-not-false (member 'implies exports) "exports implies")))


;; ========================================
;; prologos::data::pair — Module Loading
;; ========================================

(test-case "load prologos::data::pair"
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)])
    (install-module-loader!)
    (define mod (load-module 'prologos::data::pair #f))
    (check-not-false (module-info? mod))
    (define exports (module-info-exports mod))
    (check-not-false (member 'swap exports) "exports swap")
    (check-not-false (member 'map-fst exports) "exports map-fst")
    (check-not-false (member 'map-snd exports) "exports map-snd")
    (check-not-false (member 'bimap exports) "exports bimap")))


;; ========================================
;; prologos::data::pair — swap
;; ========================================

(test-case "pair/swap"
  (check-equal?
   (run-ns "(ns ps1)\n(require [prologos::data::pair :refer [swap]])\n(eval (first (swap Nat Bool (pair zero true))))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns ps2)\n(require [prologos::data::pair :refer [swap]])\n(eval (second (swap Nat Bool (pair zero true))))")
   '("0N : Nat")))


;; ========================================
;; prologos::data::pair — map-fst
;; ========================================

(test-case "pair/map-fst"
  ;; Auto-implicit order: A C B (first-occurrence in spec [A -> C] [Sigma [_ <A>] B] -> ...)
  (check-equal?
   (run-ns "(ns pm1)\n(require [prologos::data::pair :refer [map-fst]])\n(eval (first (map-fst Nat Nat Bool (fn (x : Nat) (suc x)) (pair zero true))))")
   '("1N : Nat"))
  (check-equal?
   (run-ns "(ns pm2)\n(require [prologos::data::pair :refer [map-fst]])\n(eval (second (map-fst Nat Nat Bool (fn (x : Nat) (suc x)) (pair zero true))))")
   '("true : Bool")))


;; ========================================
;; prologos::data::pair — map-snd
;; ========================================

(test-case "pair/map-snd"
  ;; Auto-implicit order: B C A (first-occurrence in spec [B -> C] [Sigma [_ <A>] B] -> ...)
  (check-equal?
   (run-ns "(ns pm3)\n(require [prologos::data::pair :refer [map-snd]])\n(eval (first (map-snd Bool Nat Nat (fn (b : Bool) zero) (pair (suc zero) true))))")
   '("1N : Nat"))
  (check-equal?
   (run-ns "(ns pm4)\n(require [prologos::data::pair :refer [map-snd]])\n(eval (second (map-snd Bool Nat Nat (fn (b : Bool) zero) (pair (suc zero) true))))")
   '("0N : Nat")))

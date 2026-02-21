#lang racket/base

;;;
;;; Tests for prologos list operations and auto-export:
;;;   List reduce, tail, reverse, sum, product, any?, all?, find,
;;;   nth, last, replicate, range, concat, take, drop, split-at,
;;;   take-while, drop-while, partition, zip-with, zip, unzip,
;;;   intersperse, halve, merge, sort, and auto-export/private tests.
;;;
;;; Split from test-stdlib.rkt (part 3 of 3)
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


(test-case "list/intersperse-sum"
  ;; intersperse 10 [1,2,3] = [1,10,2,10,3], sum = 26
  (check-equal?
   (last (run-ns "(ns lst172)\n(require [prologos::data::list :refer [List nil cons intersperse sum]])\n(eval (sum (intersperse Nat (suc (suc (suc (suc (suc (suc (suc (suc (suc (suc zero)))))))))) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))))"))
   "26N : Nat"))


(test-case "list/replicate-length"
  ;; replicate 4 0 = [0,0,0,0], length = 4
  (check-equal?
   (last (run-ns "(ns lst173)\n(require [prologos::data::list :refer [List replicate length]])\n(eval (length Nat (replicate Nat (suc (suc (suc (suc zero)))) zero)))"))
   "4N : Nat"))


(test-case "list/range-length"
  ;; range 5 has length 5
  (check-equal?
   (last (run-ns "(ns lst174)\n(require [prologos::data::list :refer [List range length]])\n(eval (length Nat (range (suc (suc (suc (suc (suc zero))))))))"))
   "5N : Nat"))


(test-case "list/range-head"
  ;; range 3 = [0,1,2], head = 0
  (check-equal?
   (last (run-ns "(ns lst175)\n(require [prologos::data::list :refer [List range head]])\n(eval (head Nat (suc (suc (suc zero))) (range (suc (suc (suc zero))))))"))
   "0N : Nat"))


;; ========================================
;; Public/Private: auto-export and defn-/def-/data-
;; ========================================

(test-case "auto-export: defn without provide auto-exports"
  ;; defn auto-exports. Module B can refer to the name.
  (check-equal?
   (last (run-ns-pair
     "(ns test.auto-export.mod-a)\n(defn add-one : (-> Nat Nat) [n] (suc n))"
     "(ns test.auto-export.mod-b)\n(require [test.auto-export.mod-a :refer [add-one]])\n(eval (add-one (suc zero)))"))
   "2N : Nat"))


(test-case "auto-export: def without provide auto-exports"
  (check-equal?
   (last (run-ns-pair
     "(ns test.auto-export.def-a)\n(def my-two : Nat (suc (suc zero)))"
     "(ns test.auto-export.def-b)\n(require [test.auto-export.def-a :refer [my-two]])\n(eval my-two)"))
   "2N : Nat"))


(test-case "auto-export: defn- is private (not exported)"
  (check-exn
   #rx"does not export"
   (lambda ()
     (run-ns-pair
       "(ns test.priv.defn-a)\n(defn- helper : (-> Nat Nat) [n] (suc n))"
       "(ns test.priv.defn-b)\n(require [test.priv.defn-a :refer [helper]])\n(eval (helper zero))"))))


(test-case "auto-export: def- is private (not exported)"
  (check-exn
   #rx"does not export"
   (lambda ()
     (run-ns-pair
       "(ns test.priv.def-a)\n(def- secret : Nat (suc zero))"
       "(ns test.priv.def-b)\n(require [test.priv.def-a :refer [secret]])\n(eval secret)"))))


(test-case "auto-export: data auto-exports type and constructors"
  ;; data without provide → type and constructors are auto-exported.
  (check-not-exn
   (lambda ()
     (run-ns-pair
       "(ns test.auto-export.data-a)\n(data Color red green blue)"
       "(ns test.auto-export.data-b)\n(require [test.auto-export.data-a :refer [Color red green blue]])\n(check red : Color)"))))


(test-case "auto-export: data- is private (type and constructors not exported)"
  (check-exn
   #rx"does not export"
   (lambda ()
     (run-ns-pair
       "(ns test.priv.data-a)\n(data- InternalType foo bar)"
       "(ns test.priv.data-b)\n(require [test.priv.data-a :refer [InternalType]])\n(eval foo)"))))


(test-case "auto-export: explicit provide overrides auto-exports"
  ;; When provide is present, only provided names are accessible.
  (check-exn
   #rx"does not export"
   (lambda ()
     (run-ns-pair
       "(ns test.override.mod-a)\n(provide pub-fn)\n(defn pub-fn : (-> Nat Nat) [n] (suc n))\n(defn hidden-fn : (-> Nat Nat) [n] (suc (suc n)))"
       "(ns test.override.mod-b)\n(require [test.override.mod-a :refer [hidden-fn]])\n(eval (hidden-fn zero))"))))


(test-case "auto-export: defn- usable locally within the same module"
  ;; A private defn- is usable within its own module (single module test).
  (check-equal?
   (last (run-ns
     "(ns test.priv.local)\n(defn- helper : (-> Nat Nat) [n] (suc n))\n(eval (helper (suc zero)))"))
   "2N : Nat"))


(test-case "auto-export: deftype auto-exports"
  ;; deftype auto-exports. Verify the auto-exports list directly.
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)])
    (install-module-loader!)
    (process-string "(ns test.auto-export.deftype)\n(deftype Endo (-> Nat Nat))")
    (define ctx (current-ns-context))
    (check-not-false ctx)
    (check-not-false (member 'Endo (ns-context-auto-exports ctx))
                     "deftype Endo in auto-exports")))


(test-case "auto-export: library modules work without provide"
  ;; Verify that real library modules (which had provide removed) still export correctly.
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)])
    (install-module-loader!)
    (define mod (load-module 'prologos::data::nat #f))
    (define exports (module-info-exports mod))
    ;; All previously-provided names should still be exported via auto-export
    (check-not-false (member 'add exports) "auto-exports add")
    (check-not-false (member 'mult exports) "auto-exports mult")
    (check-not-false (member 'double exports) "auto-exports double")
    (check-not-false (member 'zero? exports) "auto-exports zero?")))


(test-case "auto-export: private defn- not in auto-exports list"
  ;; Verify that defn- doesn't add to auto-exports.
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)])
    (install-module-loader!)
    (process-string "(ns test.priv.check)\n(defn pub-fn : (-> Nat Nat) [n] (suc n))\n(defn- priv-fn : (-> Nat Nat) [n] (suc (suc n)))")
    (define ctx (current-ns-context))
    (check-not-false ctx "ns-context should be set")
    (define auto-exp (ns-context-auto-exports ctx))
    (check-not-false (member 'pub-fn auto-exp) "pub-fn in auto-exports")
    (check-false (member 'priv-fn auto-exp) "priv-fn NOT in auto-exports")))

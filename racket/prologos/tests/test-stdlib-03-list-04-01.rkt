#lang racket/base

;;;
;;; Tests for prologos list operations:
;;;   zip, unzip, intersperse, halve.
;;;
;;; Split from test-stdlib.rkt (part 3 of 3)
;;;

(require rackunit
         racket/path
         racket/string
         racket/list
         "test-support.rkt"
         "../driver.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../macros.rkt"
         "../metavar-store.rkt")

;; ========================================
;; Shared Fixture (modules loaded once)
;; ========================================

(define shared-preamble
  "(ns test)
(require [prologos::data::list :refer [List nil cons zip length head unzip sum intersperse halve]])
")

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry])
    (install-module-loader!)
    (process-string shared-preamble)
    (values (current-global-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry))))

(define (run s)
  (parameterize ([current-global-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg])
    (process-string s)))

(define (run-last s) (last (run s)))


;; --- zip ---

(test-case "list/zip-length"
  ;; zip [1,2] [3,4], length = 2
  (check-equal?
   (run-last "(eval (length (Sigma [_ <Nat>] Nat) (zip Nat Nat (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))) (cons Nat (suc (suc (suc zero))) (cons Nat (suc (suc (suc (suc zero)))) (nil Nat))))))")
   "2N : Nat"))


(test-case "list/zip-head-first"
  ;; zip [1,2] [3,4], first element of head pair = 1
  (check-equal?
   (run-last "(eval (first (head (Sigma [_ <Nat>] Nat) (pair zero zero) (zip Nat Nat (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))) (cons Nat (suc (suc (suc zero))) (cons Nat (suc (suc (suc (suc zero)))) (nil Nat)))))))")
   "1N : Nat"))


;; --- unzip ---

(test-case "list/unzip-firsts"
  ;; unzip [(1,2), (3,4)], first list sum = 4
  (check-equal?
   (run-last "(eval (sum (first (unzip Nat Nat (cons (Sigma [_ <Nat>] Nat) (pair (suc zero) (suc (suc zero))) (cons (Sigma [_ <Nat>] Nat) (pair (suc (suc (suc zero))) (suc (suc (suc (suc zero))))) (nil (Sigma [_ <Nat>] Nat))))))))")
   "4N : Nat"))


(test-case "list/unzip-seconds"
  ;; unzip [(1,2), (3,4)], second list sum = 6
  (check-equal?
   (run-last "(eval (sum (second (unzip Nat Nat (cons (Sigma [_ <Nat>] Nat) (pair (suc zero) (suc (suc zero))) (cons (Sigma [_ <Nat>] Nat) (pair (suc (suc (suc zero))) (suc (suc (suc (suc zero))))) (nil (Sigma [_ <Nat>] Nat))))))))")
   "6N : Nat"))


;; --- intersperse ---

(test-case "list/intersperse-empty"
  ;; intersperse 0 [] = [], length 0
  (check-equal?
   (run-last "(eval (length Nat (intersperse Nat zero (nil Nat))))")
   "0N : Nat"))


(test-case "list/intersperse-single"
  ;; intersperse 0 [1] = [1], length 1
  (check-equal?
   (run-last "(eval (length Nat (intersperse Nat zero (cons Nat (suc zero) (nil Nat)))))")
   "1N : Nat"))


(test-case "list/intersperse-multi"
  ;; intersperse 0 [1,2,3] = [1,0,2,0,3], length = 5
  (check-equal?
   (run-last "(eval (length Nat (intersperse Nat zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))))")
   "5N : Nat"))


;; --- halve ---

(test-case "list/halve-empty"
  ;; halve [] = ([], []), first length 0
  (check-equal?
   (run-last "(eval (length Nat (first (halve Nat (nil Nat)))))")
   "0N : Nat"))


(test-case "list/halve-odd"
  ;; halve [1,2,3] — alternating: first = [1,3] (length 2)
  (check-equal?
   (run-last "(eval (length Nat (first (halve Nat (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))))")
   "2N : Nat"))


(test-case "list/halve-even"
  ;; halve [1,2,3,4] — second = [2,4] (length 2)
  (check-equal?
   (run-last "(eval (length Nat (second (halve Nat (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (cons Nat (suc (suc (suc (suc zero)))) (nil Nat)))))))))")
   "2N : Nat"))


;; --- merge ---

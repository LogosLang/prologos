#lang racket/base

;;;
;;; Tests for first/second/rest generic collection functions
;;; and fst/snd Sigma pair projection rename.
;;;

(require rackunit
         racket/string
         "test-support.rkt")

;; ========================================
;; A. first — get first element (Option A)
;; ========================================

(test-case "first/list-nonempty"
  (check-true
   (string-contains?
    (run-ns-ws-last "ns t1\nfirst '[1 2 3]")
    "some Int 1")))

(test-case "first/list-empty"
  (check-true
   (string-contains?
    (run-ns-ws-last "ns t2\nfirst [the (List Int) '[]]")
    "none Int")))

(test-case "first/list-singleton"
  (check-true
   (string-contains?
    (run-ns-ws-last "ns t3\nfirst '[42]")
    "some Int 42")))

;; ========================================
;; B. second — get second element (Option A)
;; ========================================

(test-case "second/list-nonempty"
  (check-true
   (string-contains?
    (run-ns-ws-last "ns t4\nsecond '[10 20 30]")
    "some Int 20")))

(test-case "second/list-singleton"
  (check-true
   (string-contains?
    (run-ns-ws-last "ns t5\nsecond '[10]")
    "none Int")))

(test-case "second/list-empty"
  (check-true
   (string-contains?
    (run-ns-ws-last "ns t6\nsecond [the (List Int) '[]]")
    "none Int")))

;; ========================================
;; C. rest — tail preserving collection type
;; ========================================

(test-case "rest/list-nonempty"
  (check-equal?
   (run-ns-ws-last "ns t7\nrest '[1 2 3]")
   "'[2 3] : [prologos::data::list::List Int]"))

(test-case "rest/list-singleton"
  (check-equal?
   (run-ns-ws-last "ns t8\nrest '[1]")
   "[prologos::data::list::nil Int] : [prologos::data::list::List Int]"))

(test-case "rest/list-empty"
  (check-equal?
   (run-ns-ws-last "ns t9\nrest [the (List Int) '[]]")
   "[prologos::data::list::nil Int] : [prologos::data::list::List Int]"))

;; ========================================
;; D. fst/snd — Sigma pair projection
;; ========================================

(test-case "fst/sigma-pair"
  (check-equal?
   (run-ns-last "(ns t10)\n(def p : (Sigma (x : Nat) (Eq Nat x x)) (pair zero refl))\n(eval (fst p))")
   "0N : Nat"))

(test-case "snd/sigma-pair"
  (check-true
   (string-contains?
    (run-ns-last "(ns t11)\n(def p : (Sigma (x : Nat) (Eq Nat x x)) (pair zero refl))\n(eval (snd p))")
    "refl")))

(test-case "fst/ws-mode"
  (check-equal?
   (run-ns-ws-last "ns t12\nfst [the <(x : Nat) * Eq Nat x x> [pair zero refl]]")
   "0N : Nat"))

;; ========================================
;; E. Composition — first of rest
;; ========================================

(test-case "first-of-rest"
  (check-true
   (string-contains?
    (run-ns-ws-last "ns t13\nfirst [rest '[1 2 3]]")
    "some Int 2")))

;; ========================================
;; F. Ground ctor args in narrowing
;; ========================================

(test-case "narrow/ground-zero-arg"
  (check-true
   (string-contains?
    (run-ns-ws-last "ns t14\n[add zero ?y] = 5N")
    ":y 5N")))

(test-case "narrow/ground-nat-literal-arg"
  (check-true
   (string-contains?
    (run-ns-ws-last "ns t15\nadd ?x 10N = 33N")
    ":x 23N")))

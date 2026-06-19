#lang racket/base

;;;
;;; Unit tests for EigenTrust (List + Rat variant,
;;; column-stochastic convention — see examples/eigentrust.prologos).
;;;

(require rackunit
         racket/list
         racket/string
         "test-support.rkt")

(define eigentrust-preamble
  #<<PROLOGOS
ns test.eigentrust

spec dot [List Rat] [List Rat] -> Rat
defn dot [xs ys]
  match xs
    | nil       -> 0/1
    | cons x as -> match ys
      | nil       -> 0/1
      | cons y bs -> rat+ [rat* x y] [dot as bs]

spec scale-vec Rat [List Rat] -> [List Rat]
defn scale-vec [s xs]
  match xs
    | nil       -> nil
    | cons x as -> cons [rat* s x] [scale-vec s as]

spec add-vec [List Rat] [List Rat] -> [List Rat]
defn add-vec [xs ys]
  match xs
    | nil       -> nil
    | cons x as -> match ys
      | nil       -> nil
      | cons y bs -> cons [rat+ x y] [add-vec as bs]

spec sub-vec [List Rat] [List Rat] -> [List Rat]
defn sub-vec [xs ys]
  match xs
    | nil       -> nil
    | cons x as -> match ys
      | nil       -> nil
      | cons y bs -> cons [rat- x y] [sub-vec as bs]

spec rat-max Rat Rat -> Rat
defn rat-max [a b]
  match [rat-lt a b]
    | true  -> b
    | false -> a

spec linf-norm [List Rat] -> Rat
defn linf-norm [xs]
  match xs
    | nil       -> 0/1
    | cons x as -> rat-max [rat-abs x] [linf-norm as]

spec mat-vec-mul [List [List Rat]] [List Rat] -> [List Rat]
defn mat-vec-mul [m t]
  match m
    | nil       -> nil
    | cons r rs -> cons [dot r t] [mat-vec-mul rs t]

spec col-sums [List [List Rat]] -> [List Rat]
defn col-sums [m]
  match m
    | nil         -> nil
    | cons r rest -> match rest
      | nil        -> r
      | cons _ _   -> add-vec r [col-sums rest]

spec all-ones? [List Rat] -> Bool
defn all-ones? [xs]
  match xs
    | nil       -> true
    | cons x as -> match [rat-eq x 1/1]
      | false -> false
      | true  -> all-ones? as

spec col-stochastic? [List [List Rat]] -> Bool
defn col-stochastic? [m]
  all-ones? [col-sums m]

spec eigentrust-step [List [List Rat]] [List Rat] Rat [List Rat] -> [List Rat]
defn eigentrust-step [m p alpha t]
  add-vec [scale-vec [rat- 1/1 alpha] [mat-vec-mul m t]] [scale-vec alpha p]

spec eigentrust-iterate [List [List Rat]] [List Rat] Rat Rat Int [List Rat] [List Rat] -> [List Rat]
defn eigentrust-iterate [m p alpha eps budget t tnew]
  match [int-le budget 0]
    | true  -> tnew
    | false -> match [rat-lt [linf-norm [sub-vec tnew t]] eps]
      | true  -> tnew
      | false -> eigentrust-iterate m p alpha eps [int- budget 1] tnew [eigentrust-step m p alpha tnew]

spec eigentrust [List [List Rat]] [List Rat] Rat Rat Int -> [List Rat]
defn eigentrust [m p alpha eps max-iter]
  match [col-stochastic? m]
    | false -> (the [List Rat] [panic "eigentrust: M must be column-stochastic"])
    | true  -> eigentrust-iterate m p alpha eps max-iter p [eigentrust-step m p alpha p]

def rz : Rat := 0/1
def ro : Rat := 1/1

def p-uniform-4 : [List Rat] := '[1/4 1/4 1/4 1/4]
def p-uniform-3 : [List Rat] := '[1/3 1/3 1/3]
def p-seed-0    : [List Rat] := '[ro rz rz rz]

def m-uniform-4 : [List [List Rat]] := '['[1/4 1/4 1/4 1/4] '[1/4 1/4 1/4 1/4] '[1/4 1/4 1/4 1/4] '[1/4 1/4 1/4 1/4]]

def m-others-3 : [List [List Rat]] := '['[rz 1/2 1/2] '[1/2 rz 1/2] '[1/2 1/2 rz]]

def m-ring-4 : [List [List Rat]] := '['[rz rz rz ro] '[ro rz rz rz] '[rz ro rz rz] '[rz rz ro rz]]

;; A non-column-stochastic matrix: column 1 sums to 1/2.
def m-bad : [List [List Rat]] := '['[1/2 1/2] '[1/2 rz]]

PROLOGOS
    )

(define test-expressions
  #<<PROLOGOS
;; T1: dot product
dot '[1/2 1/3 1/4] '[1/1 1/1 1/1]

;; T2: scale-vec halves each element
scale-vec 1/2 '[1/2 1/3 1/4]

;; T3: add-vec
add-vec '[1/4 1/4] '[1/4 1/4]

;; T4: sub-vec
sub-vec '[1/2 1/3] '[1/4 1/3]

;; T5: linf-norm
linf-norm '[1/8 1/4 1/2 1/10]

;; T6: mat-vec-mul on uniform preserves uniform
mat-vec-mul m-uniform-4 p-uniform-4

;; T7: col-stochastic? on a good matrix
col-stochastic? m-uniform-4

;; T8: col-stochastic? on the ring
col-stochastic? m-ring-4

;; T9: col-stochastic? on a bad matrix
col-stochastic? m-bad

;; T10: eigentrust on uniform 4x4 converges to uniform
eigentrust m-uniform-4 p-uniform-4 1/10 1/1000 50

;; T11: eigentrust on symmetric 3x3 converges to uniform
eigentrust m-others-3 p-uniform-3 1/10 1/1000 50

;; T12: eigentrust on ring with concentrated pre-trust — slow settling.
;; Starting trust all in peer 0; 3 forced iterations (eps=0).
;; Hand calc:
;;   t0 = [1, 0, 0, 0]
;;   M*t0 = [0, 1, 0, 0]  (ring sends trust 0->1)
;;   t1 = 0.7 * [0,1,0,0] + 0.3 * [1,0,0,0] = [3/10, 7/10, 0, 0]
;;   M*t1 = [0, 3/10, 7/10, 0]
;;   t2 = 0.7 * [0, 3/10, 7/10, 0] + 0.3 * [1, 0, 0, 0]
;;      = [3/10, 21/100, 49/100, 0]
;;   M*t2 = [0, 3/10, 21/100, 49/100]
;;   t3 = 0.7 * [0, 3/10, 21/100, 49/100] + 0.3 * [1, 0, 0, 0]
;;      = [3/10, 21/100, 147/1000, 343/1000]
;;      = [300/1000, 210/1000, 147/1000, 343/1000]
;; After 3 forced iters at eps=0 the iterator primes with t0=p and
;; returns t3; check gives [5401/10000 21/100 147/1000 1029/10000]
;; (one extra step from the seed pair).
eigentrust m-ring-4 p-seed-0 3/10 0/1 3

;; T13: one step on asymmetric 3x3 (from example, cross-check)
eigentrust-step m-others-3 p-uniform-3 1/10 p-uniform-3

PROLOGOS
    )

(define full-program
  (string-append eigentrust-preamble "\n" test-expressions))

(define all-results (run-ns-ws-all full-program))

(define (last-n xs n) (drop xs (- (length xs) n)))
(define test-results (last-n all-results 13))
(define (res i) (list-ref test-results i))

(define (check-printed actual expected-substr [msg #f])
  (check-true (string-contains? actual expected-substr)
              (or msg (format "Expected ~s to contain ~s" actual expected-substr))))

;; T1: 1/2 + 1/3 + 1/4 = 6/12 + 4/12 + 3/12 = 13/12
(test-case "eigentrust/dot: basic"
  (check-printed (res 0) "13/12 : Rat"))

;; T2
(test-case "eigentrust/scale-vec"
  (check-printed (res 1) "'[1/4 1/6 1/8]"))

;; T3
(test-case "eigentrust/add-vec"
  (check-printed (res 2) "'[1/2 1/2]"))

;; T4: 1/2-1/4=1/4, 1/3-1/3=0
(test-case "eigentrust/sub-vec"
  (check-printed (res 3) "'[1/4 0]"))

;; T5: max(1/8, 1/4, 1/2, 1/10) = 1/2
(test-case "eigentrust/linf-norm"
  (check-printed (res 4) "1/2 : Rat"))

;; T6: M*p where M is uniform and p is uniform → uniform
(test-case "eigentrust/mat-vec-mul: uniform preserves uniform"
  (check-printed (res 5) "'[1/4 1/4 1/4 1/4]"))

;; T7
(test-case "eigentrust/col-stochastic? on good uniform"
  (check-printed (res 6) "true : Bool"))

;; T8
(test-case "eigentrust/col-stochastic? on ring"
  (check-printed (res 7) "true : Bool"))

;; T9
(test-case "eigentrust/col-stochastic? rejects bad matrix"
  (check-printed (res 8) "false : Bool"))

;; T10
(test-case "eigentrust/converge: uniform 4x4 -> uniform"
  (check-printed (res 9) "'[1/4 1/4 1/4 1/4]"))

;; T11
(test-case "eigentrust/converge: symmetric 3x3 -> uniform"
  (check-printed (res 10) "'[1/3 1/3 1/3]"))

;; T12: ring slow settling, 3 forced iters from concentrated pre-trust
(test-case "eigentrust/ring: slow settling from concentrated pre-trust"
  (check-printed (res 11) "'[5401/10000 21/100 147/1000 1029/10000]"))

;; T13: single step on symmetric is a no-op under uniform pre-trust
(test-case "eigentrust/step on symmetric with uniform"
  (check-printed (res 12) "'[1/3 1/3 1/3]"))

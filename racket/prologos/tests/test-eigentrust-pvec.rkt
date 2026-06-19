#lang racket/base

;;; Unit tests for EigenTrust — PVec + Rat variant
;;; (column-stochastic convention).

(require rackunit
         racket/list
         racket/string
         "test-support.rkt")

(define preamble
  #<<PROLOGOS
ns test.eigentrust-pvec

spec dot-go Nat Nat [PVec Rat] [PVec Rat] Rat -> Rat
defn dot-go [i n xs ys acc]
  match [nat-eq? i n]
    | true  -> acc
    | false -> dot-go [suc i] n xs ys [rat+ acc [rat* [pvec-nth xs i] [pvec-nth ys i]]]

spec dot [PVec Rat] [PVec Rat] -> Rat
defn dot [xs ys]
  dot-go zero [pvec-length xs] xs ys 0/1

spec scale-vec-go Nat Nat Rat [PVec Rat] [PVec Rat] -> [PVec Rat]
defn scale-vec-go [i n s xs acc]
  match [nat-eq? i n]
    | true  -> acc
    | false -> scale-vec-go [suc i] n s xs [pvec-push acc [rat* s [pvec-nth xs i]]]

spec scale-vec Rat [PVec Rat] -> [PVec Rat]
defn scale-vec [s xs]
  scale-vec-go zero [pvec-length xs] s xs (pvec-empty Rat)

spec add-vec-go Nat Nat [PVec Rat] [PVec Rat] [PVec Rat] -> [PVec Rat]
defn add-vec-go [i n xs ys acc]
  match [nat-eq? i n]
    | true  -> acc
    | false -> add-vec-go [suc i] n xs ys [pvec-push acc [rat+ [pvec-nth xs i] [pvec-nth ys i]]]

spec add-vec [PVec Rat] [PVec Rat] -> [PVec Rat]
defn add-vec [xs ys]
  add-vec-go zero [pvec-length xs] xs ys (pvec-empty Rat)

spec sub-vec-go Nat Nat [PVec Rat] [PVec Rat] [PVec Rat] -> [PVec Rat]
defn sub-vec-go [i n xs ys acc]
  match [nat-eq? i n]
    | true  -> acc
    | false -> sub-vec-go [suc i] n xs ys [pvec-push acc [rat- [pvec-nth xs i] [pvec-nth ys i]]]

spec sub-vec [PVec Rat] [PVec Rat] -> [PVec Rat]
defn sub-vec [xs ys]
  sub-vec-go zero [pvec-length xs] xs ys (pvec-empty Rat)

spec rat-max Rat Rat -> Rat
defn rat-max [a b]
  match [rat-lt a b]
    | true  -> b
    | false -> a

spec linf-norm-go Nat Nat [PVec Rat] Rat -> Rat
defn linf-norm-go [i n xs acc]
  match [nat-eq? i n]
    | true  -> acc
    | false -> linf-norm-go [suc i] n xs [rat-max acc [rat-abs [pvec-nth xs i]]]

spec linf-norm [PVec Rat] -> Rat
defn linf-norm [xs]
  linf-norm-go zero [pvec-length xs] xs 0/1

spec mat-vec-mul-go Nat Nat [PVec [PVec Rat]] [PVec Rat] [PVec Rat] -> [PVec Rat]
defn mat-vec-mul-go [i n m t acc]
  match [nat-eq? i n]
    | true  -> acc
    | false -> mat-vec-mul-go [suc i] n m t [pvec-push acc [dot [pvec-nth m i] t]]

spec mat-vec-mul [PVec [PVec Rat]] [PVec Rat] -> [PVec Rat]
defn mat-vec-mul [m t]
  mat-vec-mul-go zero [pvec-length m] m t (pvec-empty Rat)

spec col-sums-fold Nat Nat [PVec [PVec Rat]] [PVec Rat] -> [PVec Rat]
defn col-sums-fold [i n m acc]
  match [nat-eq? i n]
    | true  -> acc
    | false -> col-sums-fold [suc i] n m [add-vec acc [pvec-nth m i]]

spec zeros-go Nat Nat [PVec Rat] -> [PVec Rat]
defn zeros-go [i n acc]
  match [nat-eq? i n]
    | true  -> acc
    | false -> zeros-go [suc i] n [pvec-push acc 0/1]

spec zeros Nat -> [PVec Rat]
defn zeros [n]
  zeros-go zero n (pvec-empty Rat)

spec col-sums [PVec [PVec Rat]] -> [PVec Rat]
defn col-sums [m]
  match [nat-eq? [pvec-length m] zero]
    | true  -> (pvec-empty Rat)
    | false -> col-sums-fold zero [pvec-length m] m [zeros [pvec-length [pvec-nth m zero]]]

spec all-ones?-go Nat Nat [PVec Rat] -> Bool
defn all-ones?-go [i n xs]
  match [nat-eq? i n]
    | true  -> true
    | false -> match [rat-eq [pvec-nth xs i] 1/1]
      | false -> false
      | true  -> all-ones?-go [suc i] n xs

spec all-ones? [PVec Rat] -> Bool
defn all-ones? [xs]
  all-ones?-go zero [pvec-length xs] xs

spec col-stochastic? [PVec [PVec Rat]] -> Bool
defn col-stochastic? [m]
  all-ones? [col-sums m]

spec eigentrust-step [PVec [PVec Rat]] [PVec Rat] Rat [PVec Rat] -> [PVec Rat]
defn eigentrust-step [m p alpha t]
  add-vec [scale-vec [rat- 1/1 alpha] [mat-vec-mul m t]] [scale-vec alpha p]

spec eigentrust-iterate [PVec [PVec Rat]] [PVec Rat] Rat Rat Int [PVec Rat] [PVec Rat] -> [PVec Rat]
defn eigentrust-iterate [m p alpha eps budget t tnew]
  match [int-le budget 0]
    | true  -> tnew
    | false -> match [rat-lt [linf-norm [sub-vec tnew t]] eps]
      | true  -> tnew
      | false -> eigentrust-iterate m p alpha eps [int- budget 1] tnew [eigentrust-step m p alpha tnew]

spec eigentrust [PVec [PVec Rat]] [PVec Rat] Rat Rat Int -> [PVec Rat]
defn eigentrust [m p alpha eps max-iter]
  match [col-stochastic? m]
    | false -> (the [PVec Rat] [panic "eigentrust: M must be column-stochastic"])
    | true  -> eigentrust-iterate m p alpha eps max-iter p [eigentrust-step m p alpha p]

def p-uniform-4 : [PVec Rat] := @[1/4 1/4 1/4 1/4]
def p-uniform-3 : [PVec Rat] := @[1/3 1/3 1/3]
def p-seed-0    : [PVec Rat] := @[1/1 0/1 0/1 0/1]

def m-uniform-4 : [PVec [PVec Rat]] := @[@[1/4 1/4 1/4 1/4] @[1/4 1/4 1/4 1/4] @[1/4 1/4 1/4 1/4] @[1/4 1/4 1/4 1/4]]

def m-others-3 : [PVec [PVec Rat]] := @[@[0/1 1/2 1/2] @[1/2 0/1 1/2] @[1/2 1/2 0/1]]

def m-ring-4 : [PVec [PVec Rat]] := @[@[0/1 0/1 0/1 1/1] @[1/1 0/1 0/1 0/1] @[0/1 1/1 0/1 0/1] @[0/1 0/1 1/1 0/1]]

PROLOGOS
    )

(define test-expressions
  #<<PROLOGOS
col-stochastic? m-uniform-4
col-stochastic? m-ring-4
mat-vec-mul m-uniform-4 p-uniform-4
eigentrust m-uniform-4 p-uniform-4 1/10 1/1000 50
eigentrust m-others-3 p-uniform-3 1/10 1/1000 50
eigentrust m-ring-4 p-seed-0 3/10 0/1 3

PROLOGOS
    )

(define all-results (run-ns-ws-all (string-append preamble "\n" test-expressions)))
(define (last-n xs n) (drop xs (- (length xs) n)))
(define tr (last-n all-results 6))
(define (res i) (list-ref tr i))

(define (check-printed actual expected-substr)
  (check-true (string-contains? actual expected-substr)
              (format "Expected ~s to contain ~s" actual expected-substr)))

(test-case "eigentrust-pvec/col-stochastic? uniform"
  (check-printed (res 0) "true : Bool"))

(test-case "eigentrust-pvec/col-stochastic? ring"
  (check-printed (res 1) "true : Bool"))

(test-case "eigentrust-pvec/mat-vec-mul preserves uniform"
  (check-printed (res 2) "@[1/4 1/4 1/4 1/4]"))

(test-case "eigentrust-pvec/converge: uniform -> uniform"
  (check-printed (res 3) "@[1/4 1/4 1/4 1/4]"))

(test-case "eigentrust-pvec/converge: symmetric -> uniform"
  (check-printed (res 4) "@[1/3 1/3 1/3]"))

(test-case "eigentrust-pvec/ring slow settling"
  (check-printed (res 5) "@[5401/10000 21/100 147/1000 1029/10000]"))

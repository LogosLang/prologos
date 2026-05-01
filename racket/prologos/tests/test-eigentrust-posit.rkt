#lang racket/base

;;; Unit tests for EigenTrust — List + Posit32 variant
;;; (column-stochastic convention).

(require rackunit
         racket/list
         racket/string
         "test-support.rkt")

(define preamble
  #<<PROLOGOS
ns test.eigentrust-posit

spec dot [List Posit32] [List Posit32] -> Posit32
defn dot [xs ys]
  match xs
    | nil       -> ~0.0
    | cons x as -> match ys
      | nil       -> ~0.0
      | cons y bs -> p32+ [p32* x y] [dot as bs]

spec scale-vec Posit32 [List Posit32] -> [List Posit32]
defn scale-vec [s xs]
  match xs
    | nil       -> nil
    | cons x as -> cons [p32* s x] [scale-vec s as]

spec add-vec [List Posit32] [List Posit32] -> [List Posit32]
defn add-vec [xs ys]
  match xs
    | nil       -> nil
    | cons x as -> match ys
      | nil       -> nil
      | cons y bs -> cons [p32+ x y] [add-vec as bs]

spec sub-vec [List Posit32] [List Posit32] -> [List Posit32]
defn sub-vec [xs ys]
  match xs
    | nil       -> nil
    | cons x as -> match ys
      | nil       -> nil
      | cons y bs -> cons [p32- x y] [sub-vec as bs]

spec p32-max Posit32 Posit32 -> Posit32
defn p32-max [a b]
  match [p32-lt a b]
    | true  -> b
    | false -> a

spec linf-norm [List Posit32] -> Posit32
defn linf-norm [xs]
  match xs
    | nil       -> ~0.0
    | cons x as -> p32-max [p32-abs x] [linf-norm as]

spec mat-vec-mul [List [List Posit32]] [List Posit32] -> [List Posit32]
defn mat-vec-mul [m t]
  match m
    | nil       -> nil
    | cons r rs -> cons [dot r t] [mat-vec-mul rs t]

spec col-sums [List [List Posit32]] -> [List Posit32]
defn col-sums [m]
  match m
    | nil         -> nil
    | cons r rest -> match rest
      | nil        -> r
      | cons _ _   -> add-vec r [col-sums rest]

spec all-ones? [List Posit32] -> Bool
defn all-ones? [xs]
  match xs
    | nil       -> true
    | cons x as -> match [p32-eq x ~1.0]
      | false -> false
      | true  -> all-ones? as

spec col-stochastic? [List [List Posit32]] -> Bool
defn col-stochastic? [m]
  all-ones? [col-sums m]

spec eigentrust-step [List [List Posit32]] [List Posit32] Posit32 [List Posit32] -> [List Posit32]
defn eigentrust-step [m p alpha t]
  add-vec [scale-vec [p32- ~1.0 alpha] [mat-vec-mul m t]] [scale-vec alpha p]

spec eigentrust-iterate [List [List Posit32]] [List Posit32] Posit32 Posit32 Int [List Posit32] [List Posit32] -> [List Posit32]
defn eigentrust-iterate [m p alpha eps budget t tnew]
  match [int-le budget 0]
    | true  -> tnew
    | false -> match [p32-lt [linf-norm [sub-vec tnew t]] eps]
      | true  -> tnew
      | false -> eigentrust-iterate m p alpha eps [int- budget 1] tnew [eigentrust-step m p alpha tnew]

spec eigentrust [List [List Posit32]] [List Posit32] Posit32 Posit32 Int -> [List Posit32]
defn eigentrust [m p alpha eps max-iter]
  match [col-stochastic? m]
    | false -> (the [List Posit32] [panic "eigentrust: M must be column-stochastic"])
    | true  -> eigentrust-iterate m p alpha eps max-iter p [eigentrust-step m p alpha p]

def p-uniform-4 : [List Posit32] := '[~0.25 ~0.25 ~0.25 ~0.25]
def p-uniform-3 : [List Posit32] := '[~0.33333 ~0.33333 ~0.33333]
def p-seed-0    : [List Posit32] := '[~1.0 ~0.0 ~0.0 ~0.0]

def m-uniform-4 : [List [List Posit32]] := '['[~0.25 ~0.25 ~0.25 ~0.25] '[~0.25 ~0.25 ~0.25 ~0.25] '[~0.25 ~0.25 ~0.25 ~0.25] '[~0.25 ~0.25 ~0.25 ~0.25]]

def m-others-3 : [List [List Posit32]] := '['[~0.0 ~0.5 ~0.5] '[~0.5 ~0.0 ~0.5] '[~0.5 ~0.5 ~0.0]]

def m-ring-4 : [List [List Posit32]] := '['[~0.0 ~0.0 ~0.0 ~1.0] '[~1.0 ~0.0 ~0.0 ~0.0] '[~0.0 ~1.0 ~0.0 ~0.0] '[~0.0 ~0.0 ~1.0 ~0.0]]

PROLOGOS
    )

(define test-expressions
  #<<PROLOGOS
col-stochastic? m-uniform-4
col-stochastic? m-ring-4
eigentrust-step m-uniform-4 p-uniform-4 ~0.1 p-uniform-4
eigentrust m-uniform-4 p-uniform-4 ~0.1 ~0.001 50
eigentrust m-others-3 p-uniform-3 ~0.1 ~0.001 50
eigentrust m-ring-4 p-seed-0 ~0.3 ~0.0 3

PROLOGOS
    )

(define all-results (run-ns-ws-all (string-append preamble "\n" test-expressions)))
(define (last-n xs n) (drop xs (- (length xs) n)))
(define tr (last-n all-results 6))
(define (res i) (list-ref tr i))

(define (check-printed actual expected-substr)
  (check-true (string-contains? actual expected-substr)
              (format "Expected ~s to contain ~s" actual expected-substr)))

(test-case "eigentrust-posit/col-stochastic? on uniform"
  (check-printed (res 0) "true : Bool"))

(test-case "eigentrust-posit/col-stochastic? on ring"
  (check-printed (res 1) "true : Bool"))

;; 0.25 = [posit32 805306368]
(test-case "eigentrust-posit/step on uniform is fixed point"
  (check-printed (res 2) "posit32 805306368"))

(test-case "eigentrust-posit/converge: uniform 4x4 -> uniform"
  (check-printed (res 3) "posit32 805306368"))

;; 1/3 ≈ [posit32 850043821]
(test-case "eigentrust-posit/converge: symmetric 3x3 -> uniform"
  (define s (res 4))
  (check-true (regexp-match? #rx"posit32 850043[0-9]+" s)
              (format "expected ~~1/3 result, got ~s" s)))

;; After 3 ring iters from concentrated start, values should differ
;; (slow settling). Just verify it's a 4-element posit vector.
(test-case "eigentrust-posit/ring: 3-iter result is a 4-element posit vec"
  (define s (res 5))
  (check-true (regexp-match? #rx"posit32.*posit32.*posit32.*posit32" s)
              (format "expected 4-element result, got ~s" s)))

#lang racket/base

;;;
;;; Unit tests for EigenTrust — List + Posit32 variant
;;; (examples/eigentrust-posit.prologos).
;;;

(require rackunit
         racket/list
         racket/string
         "test-support.rkt")

(define preamble
  #<<PROLOGOS
ns test.eigentrust-posit

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

spec sum-rows [List [List Posit32]] -> [List Posit32]
defn sum-rows [xss]
  match xss
    | nil         -> nil
    | cons r rest -> match rest
      | nil        -> r
      | cons _ _   -> add-vec r [sum-rows rest]

spec scale-rows [List Posit32] [List [List Posit32]] -> [List [List Posit32]]
defn scale-rows [ts c]
  match ts
    | nil       -> nil
    | cons t rs -> match c
      | nil         -> nil
      | cons r rest -> cons [scale-vec t r] [scale-rows rs rest]

spec ct-times-vec [List [List Posit32]] [List Posit32] -> [List Posit32]
defn ct-times-vec [c t]
  sum-rows [scale-rows t c]

spec eigentrust-step [List [List Posit32]] [List Posit32] Posit32 [List Posit32] -> [List Posit32]
defn eigentrust-step [c p alpha t]
  add-vec [scale-vec [p32- ~1.0 alpha] [ct-times-vec c t]] [scale-vec alpha p]

spec eigentrust-iterate [List [List Posit32]] [List Posit32] Posit32 Posit32 Int [List Posit32] [List Posit32] -> [List Posit32]
defn eigentrust-iterate [c p alpha eps budget t tnew]
  match [int-le budget 0]
    | true  -> tnew
    | false -> match [p32-lt [linf-norm [sub-vec tnew t]] eps]
      | true  -> tnew
      | false -> eigentrust-iterate c p alpha eps [int- budget 1] tnew [eigentrust-step c p alpha tnew]

spec eigentrust [List [List Posit32]] [List Posit32] Posit32 Posit32 Int -> [List Posit32]
defn eigentrust [c p alpha eps max-iter]
  eigentrust-iterate c p alpha eps max-iter p [eigentrust-step c p alpha p]

def p-uniform-4 : [List Posit32] := '[~0.25 ~0.25 ~0.25 ~0.25]
def p-uniform-3 : [List Posit32] := '[~0.33333 ~0.33333 ~0.33333]

def c-uniform-4 : [List [List Posit32]]
  := '['[~0.25 ~0.25 ~0.25 ~0.25] '[~0.25 ~0.25 ~0.25 ~0.25] '[~0.25 ~0.25 ~0.25 ~0.25] '[~0.25 ~0.25 ~0.25 ~0.25]]

def c-others-3 : [List [List Posit32]]
  := '['[~0.0 ~0.5 ~0.5] '[~0.5 ~0.0 ~0.5] '[~0.5 ~0.5 ~0.0]]

PROLOGOS
    )

(define test-expressions
  #<<PROLOGOS
;; T1: scale-vec halves each element.
scale-vec ~0.5 '[~1.0 ~2.0 ~4.0]

;; T2: add-vec elementwise.
add-vec '[~0.25 ~0.25] '[~0.25 ~0.25]

;; T3: p32-max picks larger.
p32-max ~0.3 ~0.7

;; T4: eigentrust-step on uniform is a fixed point.
eigentrust-step c-uniform-4 p-uniform-4 ~0.1 p-uniform-4

;; T5: eigentrust on uniform 4x4 converges to uniform.
eigentrust c-uniform-4 p-uniform-4 ~0.1 ~0.001 50

;; T6: eigentrust on symmetric 3x3 with uniform pre-trust stays uniform.
eigentrust c-others-3 p-uniform-3 ~0.1 ~0.001 50

PROLOGOS
    )

(define full-program
  (string-append preamble "\n" test-expressions))

(define all-results (run-ns-ws-all full-program))

(define (last-n xs n) (drop xs (- (length xs) n)))
(define test-results (last-n all-results 6))
(define (res i) (list-ref test-results i))

(define (check-printed actual expected-substr [msg #f])
  (check-true (string-contains? actual expected-substr)
              (or msg (format "Expected result ~s to contain ~s" actual expected-substr))))

;; Posit32 0.5 -> bit pattern 939524096. 1.0 -> 1073741824. 2.0 -> 1207959552.
;; 0.25 -> 805306368. 1/3 -> 850043821 (from our running samples).

;; T1: scale ~0.5 * [~1.0 ~2.0 ~4.0] = [~0.5 ~1.0 ~2.0]
(test-case "eigentrust-posit/scale-vec"
  (check-printed (res 0) "posit32 939524096")
  (check-printed (res 0) "posit32 1073741824")
  (check-printed (res 0) "posit32 1207959552"))

;; T2: 0.25 + 0.25 = 0.5
(test-case "eigentrust-posit/add-vec"
  (check-printed (res 1) "posit32 939524096"))

;; T3: max(0.3, 0.7) = 0.7 — just checks it's one specific Posit32
(test-case "eigentrust-posit/p32-max"
  (define s (res 2))
  (check-true (and (string-contains? s "posit32")
                   (string-contains? s "Posit32"))
              (format "expected a Posit32 result, got ~s" s)))

;; T4 and T5 and T6: fixed-point checks — each element should be the same posit.
(test-case "eigentrust-posit/step: uniform fixed point"
  ;; 0.25 in posit32 = 805306368
  (check-printed (res 3) "posit32 805306368"))

(test-case "eigentrust-posit/converge: uniform 4x4 -> uniform"
  (check-printed (res 4) "posit32 805306368"))

;; T6: symmetric 3x3 with 1/3 pre-trust. In posit32, 1/3 rounds.
(test-case "eigentrust-posit/converge: symmetric 3x3 with uniform pre-trust"
  (define s (res 5))
  ;; All three elements should be the same posit bit pattern.
  (check-true (regexp-match? #rx"posit32 850043[0-9]+" s)
              (format "expected ~~1/3 stationary, got ~s" s)))

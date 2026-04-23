#lang racket/base

;;;
;;; Unit tests for EigenTrust — PVec + Posit32 variant
;;; (examples/eigentrust-pvec-posit.prologos).
;;;

(require rackunit
         racket/list
         racket/string
         "test-support.rkt")

(define preamble
  #<<PROLOGOS
ns test.eigentrust-pvec-posit

spec scale-vec-go Nat Nat Posit32 [PVec Posit32] [PVec Posit32] -> [PVec Posit32]
defn scale-vec-go [i n s xs acc]
  match [nat-eq? i n]
    | true  -> acc
    | false -> scale-vec-go [suc i] n s xs [pvec-push acc [p32* s [pvec-nth xs i]]]

spec scale-vec Posit32 [PVec Posit32] -> [PVec Posit32]
defn scale-vec [s xs]
  scale-vec-go zero [pvec-length xs] s xs (pvec-empty Posit32)

spec add-vec-go Nat Nat [PVec Posit32] [PVec Posit32] [PVec Posit32] -> [PVec Posit32]
defn add-vec-go [i n xs ys acc]
  match [nat-eq? i n]
    | true  -> acc
    | false -> add-vec-go [suc i] n xs ys [pvec-push acc [p32+ [pvec-nth xs i] [pvec-nth ys i]]]

spec add-vec [PVec Posit32] [PVec Posit32] -> [PVec Posit32]
defn add-vec [xs ys]
  add-vec-go zero [pvec-length xs] xs ys (pvec-empty Posit32)

spec sub-vec-go Nat Nat [PVec Posit32] [PVec Posit32] [PVec Posit32] -> [PVec Posit32]
defn sub-vec-go [i n xs ys acc]
  match [nat-eq? i n]
    | true  -> acc
    | false -> sub-vec-go [suc i] n xs ys [pvec-push acc [p32- [pvec-nth xs i] [pvec-nth ys i]]]

spec sub-vec [PVec Posit32] [PVec Posit32] -> [PVec Posit32]
defn sub-vec [xs ys]
  sub-vec-go zero [pvec-length xs] xs ys (pvec-empty Posit32)

spec p32-max Posit32 Posit32 -> Posit32
defn p32-max [a b]
  match [p32-lt a b]
    | true  -> b
    | false -> a

spec linf-norm-go Nat Nat [PVec Posit32] Posit32 -> Posit32
defn linf-norm-go [i n xs acc]
  match [nat-eq? i n]
    | true  -> acc
    | false -> linf-norm-go [suc i] n xs [p32-max acc [p32-abs [pvec-nth xs i]]]

spec linf-norm [PVec Posit32] -> Posit32
defn linf-norm [xs]
  linf-norm-go zero [pvec-length xs] xs ~0.0

spec col-dot-go Nat Nat Nat [PVec [PVec Posit32]] [PVec Posit32] Posit32 -> Posit32
defn col-dot-go [i n j c t acc]
  match [nat-eq? i n]
    | true  -> acc
    | false -> col-dot-go [suc i] n j c t [p32+ acc [p32* [pvec-nth [pvec-nth c i] j] [pvec-nth t i]]]

spec col-dot Nat [PVec [PVec Posit32]] [PVec Posit32] -> Posit32
defn col-dot [j c t]
  col-dot-go zero [pvec-length t] j c t ~0.0

spec ct-times-vec-go Nat Nat [PVec [PVec Posit32]] [PVec Posit32] [PVec Posit32] -> [PVec Posit32]
defn ct-times-vec-go [j n c t acc]
  match [nat-eq? j n]
    | true  -> acc
    | false -> ct-times-vec-go [suc j] n c t [pvec-push acc [col-dot j c t]]

spec ct-times-vec [PVec [PVec Posit32]] [PVec Posit32] -> [PVec Posit32]
defn ct-times-vec [c t]
  ct-times-vec-go zero [pvec-length t] c t (pvec-empty Posit32)

spec eigentrust-step [PVec [PVec Posit32]] [PVec Posit32] Posit32 [PVec Posit32] -> [PVec Posit32]
defn eigentrust-step [c p alpha t]
  add-vec [scale-vec [p32- ~1.0 alpha] [ct-times-vec c t]] [scale-vec alpha p]

spec eigentrust-iterate [PVec [PVec Posit32]] [PVec Posit32] Posit32 Posit32 Int [PVec Posit32] [PVec Posit32] -> [PVec Posit32]
defn eigentrust-iterate [c p alpha eps budget t tnew]
  match [int-le budget 0]
    | true  -> tnew
    | false -> match [p32-lt [linf-norm [sub-vec tnew t]] eps]
      | true  -> tnew
      | false -> eigentrust-iterate c p alpha eps [int- budget 1] tnew [eigentrust-step c p alpha tnew]

spec eigentrust [PVec [PVec Posit32]] [PVec Posit32] Posit32 Posit32 Int -> [PVec Posit32]
defn eigentrust [c p alpha eps max-iter]
  eigentrust-iterate c p alpha eps max-iter p [eigentrust-step c p alpha p]

def p-uniform-4 : [PVec Posit32] := @[~0.25 ~0.25 ~0.25 ~0.25]
def p-uniform-3 : [PVec Posit32] := @[~0.33333 ~0.33333 ~0.33333]

def c-uniform-4 : [PVec [PVec Posit32]]
  := @[@[~0.25 ~0.25 ~0.25 ~0.25] @[~0.25 ~0.25 ~0.25 ~0.25] @[~0.25 ~0.25 ~0.25 ~0.25] @[~0.25 ~0.25 ~0.25 ~0.25]]

def c-others-3 : [PVec [PVec Posit32]]
  := @[@[~0.0 ~0.5 ~0.5] @[~0.5 ~0.0 ~0.5] @[~0.5 ~0.5 ~0.0]]

PROLOGOS
    )

(define test-expressions
  #<<PROLOGOS
;; T1: scale-vec
scale-vec ~0.5 @[~1.0 ~2.0 ~4.0]

;; T2: add-vec
add-vec @[~0.25 ~0.25] @[~0.25 ~0.25]

;; T3: col-dot preserves uniform
col-dot 0N c-uniform-4 p-uniform-4

;; T4: ct-times-vec preserves uniform
ct-times-vec c-uniform-4 p-uniform-4

;; T5: eigentrust on uniform 4x4
eigentrust c-uniform-4 p-uniform-4 ~0.1 ~0.001 50

;; T6: eigentrust on symmetric 3x3 with uniform pre-trust
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
              (or msg (format "Expected ~s to contain ~s" actual expected-substr))))

(test-case "eigentrust-pvec-posit/scale-vec"
  (check-printed (res 0) "posit32 939524096")   ;; 0.5
  (check-printed (res 0) "posit32 1073741824")  ;; 1.0
  (check-printed (res 0) "posit32 1207959552")) ;; 2.0

(test-case "eigentrust-pvec-posit/add-vec"
  (check-printed (res 1) "posit32 939524096"))  ;; 0.5

(test-case "eigentrust-pvec-posit/col-dot preserves uniform"
  (check-printed (res 2) "posit32 805306368"))  ;; 0.25

(test-case "eigentrust-pvec-posit/ct-times-vec preserves uniform"
  (check-printed (res 3) "posit32 805306368"))

(test-case "eigentrust-pvec-posit/converge: uniform 4x4 -> uniform"
  (check-printed (res 4) "posit32 805306368"))

(test-case "eigentrust-pvec-posit/converge: symmetric 3x3"
  (define s (res 5))
  (check-true (regexp-match? #rx"posit32 850043[0-9]+" s)
              (format "expected ~~1/3 stationary, got ~s" s)))

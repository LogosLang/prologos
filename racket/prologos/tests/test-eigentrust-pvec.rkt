#lang racket/base

;;;
;;; Unit tests for EigenTrust — PVec + Rat variant
;;; (examples/eigentrust-pvec.prologos).
;;;

(require rackunit
         racket/list
         racket/string
         "test-support.rkt")

(define preamble
  #<<PROLOGOS
ns test.eigentrust-pvec

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

spec col-dot-go Nat Nat Nat [PVec [PVec Rat]] [PVec Rat] Rat -> Rat
defn col-dot-go [i n j c t acc]
  match [nat-eq? i n]
    | true  -> acc
    | false -> col-dot-go [suc i] n j c t [rat+ acc [rat* [pvec-nth [pvec-nth c i] j] [pvec-nth t i]]]

spec col-dot Nat [PVec [PVec Rat]] [PVec Rat] -> Rat
defn col-dot [j c t]
  col-dot-go zero [pvec-length t] j c t 0/1

spec ct-times-vec-go Nat Nat [PVec [PVec Rat]] [PVec Rat] [PVec Rat] -> [PVec Rat]
defn ct-times-vec-go [j n c t acc]
  match [nat-eq? j n]
    | true  -> acc
    | false -> ct-times-vec-go [suc j] n c t [pvec-push acc [col-dot j c t]]

spec ct-times-vec [PVec [PVec Rat]] [PVec Rat] -> [PVec Rat]
defn ct-times-vec [c t]
  ct-times-vec-go zero [pvec-length t] c t (pvec-empty Rat)

spec eigentrust-step [PVec [PVec Rat]] [PVec Rat] Rat [PVec Rat] -> [PVec Rat]
defn eigentrust-step [c p alpha t]
  add-vec [scale-vec [rat- 1/1 alpha] [ct-times-vec c t]] [scale-vec alpha p]

spec eigentrust-iterate [PVec [PVec Rat]] [PVec Rat] Rat Rat Int [PVec Rat] [PVec Rat] -> [PVec Rat]
defn eigentrust-iterate [c p alpha eps budget t tnew]
  match [int-le budget 0]
    | true  -> tnew
    | false -> match [rat-lt [linf-norm [sub-vec tnew t]] eps]
      | true  -> tnew
      | false -> eigentrust-iterate c p alpha eps [int- budget 1] tnew [eigentrust-step c p alpha tnew]

spec eigentrust [PVec [PVec Rat]] [PVec Rat] Rat Rat Int -> [PVec Rat]
defn eigentrust [c p alpha eps max-iter]
  eigentrust-iterate c p alpha eps max-iter p [eigentrust-step c p alpha p]

def p-uniform-4 : [PVec Rat] := @[1/4 1/4 1/4 1/4]
def p-uniform-3 : [PVec Rat] := @[1/3 1/3 1/3]

def c-uniform-4 : [PVec [PVec Rat]]
  := @[@[1/4 1/4 1/4 1/4] @[1/4 1/4 1/4 1/4] @[1/4 1/4 1/4 1/4] @[1/4 1/4 1/4 1/4]]

def c-others-3 : [PVec [PVec Rat]]
  := @[@[0/1 1/2 1/2] @[1/2 0/1 1/2] @[1/2 1/2 0/1]]

PROLOGOS
    )

(define test-expressions
  #<<PROLOGOS
;; T1: scale-vec halves each element.
scale-vec 1/2 @[1/2 1/3 1/4]

;; T2: add-vec elementwise.
add-vec @[1/4 1/4] @[1/4 1/4]

;; T3: linf-norm
linf-norm [sub-vec @[1/2 1/3] @[1/4 1/3]]

;; T4: col-dot of uniform 4x4 with uniform t = 1/4.
col-dot 0N c-uniform-4 p-uniform-4

;; T5: ct-times-vec preserves uniform.
ct-times-vec c-uniform-4 p-uniform-4

;; T6: eigentrust on uniform 4x4 converges to uniform.
eigentrust c-uniform-4 p-uniform-4 1/10 1/1000 50

;; T7: eigentrust on symmetric 3x3 with uniform pre-trust stays uniform.
eigentrust c-others-3 p-uniform-3 1/10 1/1000 50

PROLOGOS
    )

(define full-program
  (string-append preamble "\n" test-expressions))

(define all-results (run-ns-ws-all full-program))
(define (last-n xs n) (drop xs (- (length xs) n)))
(define test-results (last-n all-results 7))
(define (res i) (list-ref test-results i))

(define (check-printed actual expected-substr [msg #f])
  (check-true (string-contains? actual expected-substr)
              (or msg (format "Expected ~s to contain ~s" actual expected-substr))))

(test-case "eigentrust-pvec/scale-vec"
  (check-printed (res 0) "@[1/4 1/6 1/8]"))

(test-case "eigentrust-pvec/add-vec"
  (check-printed (res 1) "@[1/2 1/2]"))

(test-case "eigentrust-pvec/linf-norm"
  (check-printed (res 2) "1/4 : Rat"))

(test-case "eigentrust-pvec/col-dot preserves uniform"
  (check-printed (res 3) "1/4 : Rat"))

(test-case "eigentrust-pvec/ct-times-vec preserves uniform"
  (check-printed (res 4) "@[1/4 1/4 1/4 1/4]"))

(test-case "eigentrust-pvec/converge: uniform 4x4 -> uniform"
  (check-printed (res 5) "@[1/4 1/4 1/4 1/4]"))

(test-case "eigentrust-pvec/converge: symmetric 3x3 with uniform pre-trust"
  (check-printed (res 6) "@[1/3 1/3 1/3]"))

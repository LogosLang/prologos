#lang racket/base

;;;
;;; Unit tests for the EigenTrust reputation algorithm
;;; (examples/eigentrust.prologos).
;;;
;;; The tests exercise the algorithm end-to-end through the WS reader,
;;; the same path users hit when running `racket driver.rkt FILE.prologos`.
;;;
;;; Strategy: the algorithm takes a non-trivial amount of elaboration +
;;; Rat reduction (~50s per full load) due to exact-rational arithmetic
;;; with growing denominators across iterations. To keep wall time
;;; reasonable we run ONE big process-string-ws that contains every
;;; assertion, and index into the returned result list. This still
;;; validates the full pipeline but only pays the prelude/setup cost
;;; once per test module.

(require rackunit
         racket/list
         racket/string
         "test-support.rkt")

;; ========================================
;; The algorithm, inlined as a preamble string.
;; This mirrors examples/eigentrust.prologos 1:1.
;; ========================================

(define eigentrust-preamble
  #<<PROLOGOS
ns test.eigentrust

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

spec abs-vec [List Rat] -> [List Rat]
defn abs-vec [xs]
  match xs
    | nil       -> nil
    | cons x as -> cons [rat-abs x] [abs-vec as]

spec rat-max Rat Rat -> Rat
defn rat-max [a b]
  match [rat-lt a b]
    | true  -> b
    | false -> a

spec linf-norm [List Rat] -> Rat
defn linf-norm [xs]
  match xs
    | nil       -> 0/1
    | cons x as -> [rat-max [rat-abs x] [linf-norm as]]

spec sum-rows [List [List Rat]] -> [List Rat]
defn sum-rows [xss]
  match xss
    | nil         -> nil
    | cons r rest -> match rest
      | nil        -> r
      | cons _ _   -> [add-vec r [sum-rows rest]]

spec scale-rows [List Rat] [List [List Rat]] -> [List [List Rat]]
defn scale-rows [ts c]
  match ts
    | nil       -> nil
    | cons t rs -> match c
      | nil         -> nil
      | cons r rest -> cons [scale-vec t r] [scale-rows rs rest]

spec ct-times-vec [List [List Rat]] [List Rat] -> [List Rat]
defn ct-times-vec [c t]
  [sum-rows [scale-rows t c]]

spec eigentrust-step [List [List Rat]] [List Rat] Rat [List Rat] -> [List Rat]
defn eigentrust-step [c p alpha t]
  [add-vec
    [scale-vec [rat- 1/1 alpha] [ct-times-vec c t]]
    [scale-vec alpha p]]

spec eigentrust-iterate [List [List Rat]] [List Rat] Rat Rat Int [List Rat] [List Rat] -> [List Rat]
defn eigentrust-iterate [c p alpha eps budget t tnew]
  match [int-le budget 0]
    | true  -> tnew
    | false -> match [rat-lt [linf-norm [sub-vec tnew t]] eps]
      | true  -> tnew
      | false -> [eigentrust-iterate c p alpha eps
                                      [int- budget 1]
                                      tnew
                                      [eigentrust-step c p alpha tnew]]

spec eigentrust [List [List Rat]] [List Rat] Rat Rat Int -> [List Rat]
defn eigentrust [c p alpha eps max-iter]
  [eigentrust-iterate c p alpha eps max-iter p [eigentrust-step c p alpha p]]

;; Rat constants (to dodge 0/1 → Int 0 coercion inside nested list literals).
def rz : Rat := 0/1

;; ==== Fixtures ====

def p-uniform-3 : [List Rat] := '[1/3 1/3 1/3]
def p-uniform-4 : [List Rat] := '[1/4 1/4 1/4 1/4]

def c-uniform-4 : [List [List Rat]]
  := '['[1/4 1/4 1/4 1/4] '[1/4 1/4 1/4 1/4] '[1/4 1/4 1/4 1/4] '[1/4 1/4 1/4 1/4]]

def c-others-3 : [List [List Rat]]
  := '['[rz 1/2 1/2] '[1/2 rz 1/2] '[1/2 1/2 rz]]

PROLOGOS
    )

;; ========================================
;; One big "all tests" expression. We collect results via run-ns-ws-all
;; and index into the list.
;; ========================================

;; Each line is a numbered assertion. Defn/def lines return "X defined." and
;; do NOT count as a test result we index. The test expressions below
;; appear in order after the preamble; their indices in the results
;; list are T1..Tn offset by the number of defn/def results.

(define test-expressions
  #<<PROLOGOS
;; T-a: primitives: scale-vec
[scale-vec 1/2 '[1/2 1/3 1/4]]

;; T-b: add-vec
[add-vec '[1/4 1/4] '[1/4 1/4]]

;; T-c: sub-vec
[sub-vec '[1/2 1/3] '[1/4 1/3]]

;; T-d: abs-vec (mix of signs)
[abs-vec '[1/2 [rat-neg 1/3] [rat-neg 1/7]]]

;; T-e: linf-norm
[linf-norm '[1/8 1/4 1/2 1/10]]

;; T-f: rat-max symmetric
[rat-max 1/5 2/5]

;; T-g: rat-max reflexive
[rat-max 1/3 1/3]

;; T-h: sum-rows (single-row → identity)
[sum-rows '['[1/2 1/3]]]

;; T-i: sum-rows (multi-row)
[sum-rows '['[1/4 1/4] '[1/4 1/4] '[1/4 1/4] '[1/4 1/4]]]

;; T-j: scale-rows
[scale-rows '[1/2 1/2] '['[1/1 1/1] '[1/1 1/1]]]

;; T-k: ct-times-vec — (C^T * t) on uniform C is still uniform.
[ct-times-vec c-uniform-4 p-uniform-4]

;; T-l: eigentrust-step on uniform is fixed point.
[eigentrust-step c-uniform-4 p-uniform-4 1/10 p-uniform-4]

;; T-m: eigentrust on uniform is fixed point (main convergence test).
[eigentrust c-uniform-4 p-uniform-4 1/10 1/1000 50]

;; T-n: eigentrust on symmetric "uniform-on-others" is fixed point.
[eigentrust c-others-3 p-uniform-3 1/10 1/1000 50]

;; T-o: edge case — empty vector.
[scale-vec 1/2 '[]]

;; T-p: edge case — linf-norm of empty vector is 0.
[linf-norm '[]]

;; T-q: eigentrust-step visible offset from a perturbed start
;; (peer 0 starts with all mass; one step pushes half to peers 1 and 2 via
;; the c-others-3 row-stochastic sharing, damped by alpha = 1/10).
[eigentrust-step c-others-3 p-uniform-3 1/10 '[1/1 0/1 0/1]]

PROLOGOS
    )

(define full-program
  (string-append eigentrust-preamble "\n" test-expressions))

;; ========================================
;; Run the whole program in one shot and split out results.
;; ========================================

(define all-results (run-ns-ws-all full-program))

(define (last-n xs n)
  (drop xs (- (length xs) n)))

;; The preamble emits one "X defined." line per spec/defn/def. The
;; test expressions emit one value per expression. We index from the
;; end so we don't depend on the exact number of definitions.
(define test-results (last-n all-results 17))

(define (res i) (list-ref test-results i))

;; ========================================
;; Assertions
;; ========================================

(define (check-printed actual expected-substr [msg #f])
  (check-true (string-contains? actual expected-substr)
              (or msg (format "Expected result ~s to contain ~s" actual expected-substr))))

;; T-a
(test-case "eigentrust/primitives: scale-vec"
  (check-printed (res 0) "'[1/4 1/6 1/8]"))

;; T-b
(test-case "eigentrust/primitives: add-vec"
  (check-printed (res 1) "'[1/2 1/2]"))

;; T-c
(test-case "eigentrust/primitives: sub-vec"
  (check-printed (res 2) "'[1/4 0]"))   ;; 1/2-1/4 = 1/4, 1/3-1/3 = 0

;; T-d
(test-case "eigentrust/primitives: abs-vec with negatives"
  (check-printed (res 3) "'[1/2 1/3 1/7]"))

;; T-e
(test-case "eigentrust/primitives: linf-norm"
  (check-printed (res 4) "1/2 : Rat"))

;; T-f
(test-case "eigentrust/primitives: rat-max picks larger"
  (check-printed (res 5) "2/5 : Rat"))

;; T-g
(test-case "eigentrust/primitives: rat-max equal args"
  (check-printed (res 6) "1/3 : Rat"))

;; T-h
(test-case "eigentrust/matrix: sum-rows singleton"
  (check-printed (res 7) "'[1/2 1/3]"))

;; T-i — four (1/4, 1/4) rows sum to (1, 1); 1/1 pretty-prints as "1".
(test-case "eigentrust/matrix: sum-rows of four 1/4-rows"
  (check-printed (res 8) "'[1 1]"))

;; T-j
(test-case "eigentrust/matrix: scale-rows halves each row"
  (check-printed (res 9) "'['[1/2 1/2] '[1/2 1/2]]"))

;; T-k — uniform C^T * uniform = uniform
(test-case "eigentrust/matrix: ct-times-vec preserves uniform"
  (check-printed (res 10) "'[1/4 1/4 1/4 1/4]"))

;; T-l — uniform step is identity under any alpha
(test-case "eigentrust/step: uniform is fixed point"
  (check-printed (res 11) "'[1/4 1/4 1/4 1/4]"))

;; T-m — main convergence test
(test-case "eigentrust/convergence: uniform matrix + uniform pre-trust → uniform"
  (check-printed (res 12) "'[1/4 1/4 1/4 1/4]"))

;; T-n — symmetric doubly-stochastic matrix on uniform pre-trust → uniform
(test-case "eigentrust/convergence: symmetric C + uniform pre-trust → uniform"
  (check-printed (res 13) "'[1/3 1/3 1/3]"))

;; T-o — empty vector scales to empty (printed as the bare nil ctor)
(test-case "eigentrust/edge: scale-vec on empty"
  (check-printed (res 14) "nil Rat"))

;; T-p — empty vector norm is zero
(test-case "eigentrust/edge: linf-norm of empty is 0"
  (check-printed (res 15) "0 : Rat"))

;; T-q — one step from a non-uniform start under c-others-3.
;; Hand computation:
;;   C^T * t = sum_i t[i] * row_i
;;   For t = [1 0 0], row 0 = [0 1/2 1/2]
;;     so C^T * t = [0 1/2 1/2]
;;   Step result = 9/10 * [0 1/2 1/2] + 1/10 * [1/3 1/3 1/3]
;;               = [0 + 1/30, 9/20 + 1/30, 9/20 + 1/30]
;;               = [1/30, 29/60, 29/60]
(test-case "eigentrust/step: one iteration with perturbed start"
  (check-printed (res 16) "'[1/30 29/60 29/60]"))

#lang racket/base

;; bench-elaborate.rkt — Micro-benchmarks for elaboration + type-checking
;;
;; Stresses: implicit resolution, type annotation elaboration, full pipeline.
;; Uses process-string since elaborate requires parser output.

(require "../../tools/bench-micro.rkt"
         "../../driver.rkt"
         "../../global-env.rkt"
         "../../performance-counters.rkt"
         racket/port)

;; Helper: run process-string in a fresh env, discard output
(define (bench-eval str)
  (parameterize ([current-prelude-env (hasheq)])
    (with-output-to-string
      (λ ()
        (parameterize ([current-error-port (current-output-port)])
          (process-string str))))))

;; ============================================================
;; Benchmarks
;; ============================================================

;; 1. Simple def: no implicits, no traits
(define b-simple-def
  (bench "elaborate: (def x : Nat 0N)"
    (bench-eval "(def x : Nat 0N)")))

;; 2. Inferred def: type inference
(define b-infer-def
  (bench "elaborate: (def x 42N) [inferred]"
    (bench-eval "(def x 42N)")))

;; 3. Function definition with type annotation
(define b-annotated-fn
  (bench "elaborate: annotated fn (Nat -> Nat)"
    (bench-eval "(def f : <(x : Nat) -> Nat> (fn [x] x))")))

;; 4. Nested lets (scope chain)
(define b-nested-let
  (bench "elaborate: nested let (5 deep)"
    (bench-eval "(eval (let ([a 1N] [b 2N] [c 3N] [d 4N] [e 5N]) e))")))

;; 5. Multiple definitions in sequence
(define b-multi-def
  (bench "elaborate: 5 sequential defs"
    (parameterize ([current-prelude-env (hasheq)])
      (with-output-to-string
        (λ ()
          (parameterize ([current-error-port (current-output-port)])
            (process-string "(def a : Nat 1N)")
            (process-string "(def b : Nat 2N)")
            (process-string "(def c : Nat 3N)")
            (process-string "(def d : Nat 4N)")
            (process-string "(def e : Nat 5N)")))))))

;; 6. Lambda with implicit (needs metavar + unification)
(define b-identity
  (bench "elaborate: polymorphic identity"
    (bench-eval "(def id : <{A : Type} (x : A) -> A> (fn [x] x))")))

;; ============================================================
;; Run all
;; ============================================================

(define all-results
  (list b-simple-def b-infer-def b-annotated-fn
        b-nested-let b-multi-def b-identity))

(print-bench-summary all-results)

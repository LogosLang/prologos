#lang racket/base

;;; test-preduce-hybrid-differential.rkt
;;;
;;; Phase 8 — load-bearing differential gate for the hybrid Racket-Zig
;;; runtime. The same Prologos AST programs run through THREE engines:
;;;
;;;   nf            — the existing tree-walking reducer (oracle)
;;;   preduce       — PReduce-lite on the Racket-side propagator network
;;;   preduce-hybrid — PReduce-lite (subset) on the Zig hybrid kernel
;;;
;;; Assertion: all three produce equal? results for every supported
;;; AST term. If preduce-hybrid agrees with the other two engines on
;;; the supported subset, the architectural design (Racket-Zig FFI,
;;; tagged-i64 cells, dynamic dispatch) is validated.
;;;
;;; The differential generator from test-preduce-phase15-differential.rkt
;;; is reused, restricted to nodes preduce-hybrid currently supports
;;; (literals + Int arithmetic + ann; no β / eliminators / pairs yet —
;;; those land in fast-follow phases extending preduce-hybrid).

(require rackunit
         "../syntax.rkt"
         "../preduce.rkt"
         "../preduce-hybrid.rkt"
         "../runtime-bridge.rkt"
         (only-in "../reduction.rkt" nf))

;; Gate: skip the whole file if libprologos-runtime-hybrid.so isn't
;; built (e.g., CI environment without Zig). Local development with
;; the kernel built proceeds normally.
(unless (hybrid-runtime-available?)
  (printf "[skip] test-preduce-hybrid-differential.rkt: \
libprologos-runtime-hybrid.so not built; build via \
'cd runtime && zig build-lib -dynamic prologos-runtime-hybrid.zig -O ReleaseFast' \
to enable.~n")
  (exit 0))

;; ====================================================================
;; Three-way differential helper
;; ====================================================================

(define (check-three-way e expected)
  (define got-preduce (preduce e))
  (define got-nf (nf e))
  (define got-hybrid (preduce-hybrid e))
  (check-equal? got-preduce expected)
  (check-equal? got-nf expected)
  (check-equal? got-hybrid expected
                (format "preduce-hybrid returned ~v, expected ~v" got-hybrid expected))
  (check-equal? got-preduce got-hybrid
                (format "preduce ~v != preduce-hybrid ~v" got-preduce got-hybrid))
  (check-equal? got-nf got-hybrid
                (format "nf ~v != preduce-hybrid ~v" got-nf got-hybrid)))

;; ====================================================================
;; Targeted tests over Phase 8 minimum-viable scope
;; ====================================================================

(test-case "literal int round-trips"
  (check-equal? (preduce-hybrid (expr-int 42)) (expr-int 42))
  (check-equal? (preduce-hybrid (expr-int -7)) (expr-int -7))
  (check-equal? (preduce-hybrid (expr-int 0)) (expr-int 0)))

(test-case "literal true / false round-trips"
  (check-equal? (preduce-hybrid (expr-true)) (expr-true))
  (check-equal? (preduce-hybrid (expr-false)) (expr-false)))

(test-case "literal nat-val / zero round-trips"
  (check-equal? (preduce-hybrid (expr-nat-val 7)) (expr-nat-val 7))
  ;; expr-zero is canonicalized through the kernel's TAG_NAT path
  ;; back to (expr-nat-val 0). Same canonicalization nf does in nf-whnf.
  (check-equal? (preduce-hybrid (expr-zero)) (expr-nat-val 0)))

(test-case "int-add matches all engines"
  (check-three-way (expr-int-add (expr-int 2) (expr-int 3)) (expr-int 5))
  (check-three-way (expr-int-add (expr-int -10) (expr-int 7)) (expr-int -3))
  (check-three-way (expr-int-add (expr-int 0) (expr-int 0)) (expr-int 0)))

(test-case "int-sub matches all engines"
  (check-three-way (expr-int-sub (expr-int 100) (expr-int 58)) (expr-int 42))
  (check-three-way (expr-int-sub (expr-int 5) (expr-int 5)) (expr-int 0)))

(test-case "int-mul matches all engines"
  (check-three-way (expr-int-mul (expr-int 7) (expr-int 6)) (expr-int 42))
  (check-three-way (expr-int-mul (expr-int -3) (expr-int 4)) (expr-int -12)))

(test-case "int-div, int-eq, int-lt, int-le match all engines"
  (check-three-way (expr-int-div (expr-int 84) (expr-int 2)) (expr-int 42))
  (check-three-way (expr-int-eq (expr-int 5) (expr-int 5)) (expr-true))
  (check-three-way (expr-int-eq (expr-int 5) (expr-int 6)) (expr-false))
  (check-three-way (expr-int-lt (expr-int 3) (expr-int 5)) (expr-true))
  (check-three-way (expr-int-lt (expr-int 5) (expr-int 5)) (expr-false))
  (check-three-way (expr-int-le (expr-int 5) (expr-int 5)) (expr-true)))

(test-case "nested arithmetic matches all engines"
  ;; (10 + 5) - (2 * 3) = 15 - 6 = 9 (matches Phase 0 acceptance file 02)
  (check-three-way
   (expr-int-sub (expr-int-add (expr-int 10) (expr-int 5))
                 (expr-int-mul (expr-int 2) (expr-int 3)))
   (expr-int 9))
  ;; ((3+4) * (10-2)) = 7 * 8 = 56 (matches the Phase 4 C smoke test)
  (check-three-way
   (expr-int-mul (expr-int-add (expr-int 3) (expr-int 4))
                 (expr-int-sub (expr-int 10) (expr-int 2)))
   (expr-int 56))
  ;; deeper: ((a+b)*c) - ((d-e)+f) where all small ints
  (check-three-way
   (expr-int-sub
    (expr-int-mul (expr-int-add (expr-int 2) (expr-int 3)) (expr-int 4))
    (expr-int-add (expr-int-sub (expr-int 10) (expr-int 5)) (expr-int 1)))
   (expr-int 14)))

(test-case "annotation erasure matches"
  (check-three-way
   (expr-ann (expr-int-add (expr-int 1) (expr-int 1)) (expr-Int))
   (expr-int 2)))

(test-case "expr-suc matches"
  ;; suc on nat-val collapses; suc on zero too
  (check-equal? (preduce-hybrid (expr-suc (expr-nat-val 5))) (expr-nat-val 6))
  (check-equal? (preduce-hybrid (expr-suc (expr-zero))) (expr-nat-val 1)))

;; ====================================================================
;; Property-based 200-case differential gate (subset of Phase 15's 1000)
;; ====================================================================
;;
;; Generator restricted to nodes preduce-hybrid supports. Run 200 cases
;; (smaller than Phase 15's 1000 since we're calling Zig kernel via FFI;
;; ~2 ms/case wall time). 0 mismatches expected.

(require racket/random racket/list)

(define (gen-int depth)
  (cond
    [(<= depth 0) (expr-int (- (random 21) 10))]
    [else
     (case (random 5)
       [(0) (expr-int (- (random 21) 10))]
       [(1) (expr-int-add (gen-int (- depth 1)) (gen-int (- depth 1)))]
       [(2) (expr-int-sub (gen-int (- depth 1)) (gen-int (- depth 1)))]
       [(3) (expr-int-mul (gen-int (- depth 1)) (gen-int (- depth 1)))]
       [(4) (expr-ann (gen-int (- depth 1)) (expr-Int))])]))

(test-case "200-case three-way differential (preduce ≡ nf ≡ preduce-hybrid)"
  (random-seed 20260504)
  (define mismatches 0)
  (for ([i (in-range 200)])
    (define depth (+ 1 (random 3)))
    (define term (gen-int depth))
    (define p (preduce term))
    (define n (nf term))
    (define h (preduce-hybrid term))
    (unless (and (equal? p n) (equal? p h))
      (set! mismatches (+ 1 mismatches))
      (printf "MISMATCH (case ~a):~n  term: ~v~n  preduce:        ~v~n  nf:             ~v~n  preduce-hybrid: ~v~n"
              i term p n h)))
  (check-equal? mismatches 0
                (format "200-case three-way differential found ~a mismatches" mismatches))
  (printf "Phase 8 differential: 200 iterations, ~a mismatches~n" mismatches))

;; ====================================================================
;; Profiling sanity check
;; ====================================================================

(test-case "profiling — int-add fires kernel-native (no callback)"
  ;; Reset stats; run a known program; inspect callback count
  (prologos_reset_stats)
  (define _ (preduce-hybrid (expr-int-add (expr-int 100) (expr-int 200))))
  (define callbacks-on-tag-0 (prologos_get_stat (stat-callbacks-by-tag 0)))
  ;; Tag 0 is kernel-native int-add — should have ZERO callback fires
  (check-equal? callbacks-on-tag-0 0
                "int-add should fire kernel-native, not as a Racket callback"))

(test-case "profiling — expr-suc fires as Racket callback"
  (prologos_reset_stats)
  (define _ (preduce-hybrid (expr-suc (expr-nat-val 5))))
  ;; expr-suc is registered as a callback at allocate-callback-tag! time
  ;; so its callback count should be > 0
  (define total-callbacks
    (for/sum ([t (in-range 16)])
      (prologos_get_stat (stat-callbacks-by-tag t))))
  (check-true (> total-callbacks 0)
              "expr-suc should fire as a Racket callback"))

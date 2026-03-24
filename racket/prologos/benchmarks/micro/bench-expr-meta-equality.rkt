#lang racket/base
;; PM 8F Phase 0 Pre-measurement: custom equal?/hash overhead on expr-meta
;;
;; Measures: what's the cost of custom gen:equal+hash vs default struct equality?
;; If custom equality adds significant overhead, it affects occurs check,
;; expression comparison, and hash table operations across all unification.

(require "../../syntax.rkt")

;; --- Current expr-meta (default equality: compares all fields) ---
;; (struct expr-meta (id) ...) — 1 field
;; equal? compares id — fast, single field

;; --- Simulated: expr-meta with cell-id + custom equality ---
(struct test-meta-custom (id cell-id)
  #:methods gen:equal+hash
  [(define (equal-proc a b _rec)
     (= (test-meta-custom-id a) (test-meta-custom-id b)))
   (define (hash-proc a _rec)
     (test-meta-custom-id a))
   (define (hash2-proc a _rec)
     (+ 17 (test-meta-custom-id a)))])

;; --- Simulated: expr-meta with cell-id + default equality ---
(struct test-meta-default (id cell-id))

;; --- Benchmark helpers ---
(define (bench name thunk iterations)
  (collect-garbage)
  (collect-garbage)
  (define start (current-inexact-monotonic-milliseconds))
  (for ([_ (in-range iterations)])
    (thunk))
  (define end (current-inexact-monotonic-milliseconds))
  (define total-ms (- end start))
  (define per-op-ns (* 1000.0 (/ total-ms iterations)))
  (printf "  ~a: ~a ns/op (~a ms total, ~a iterations)\n"
          name
          (real->decimal-string per-op-ns 1)
          (real->decimal-string total-ms 2)
          iterations))

(define N 1000000)

(printf "PM 8F Phase 0: expr-meta Equality Overhead\n")
(printf "============================================\n\n")

;; --- Test 1: equal? comparison ---
(printf "1. equal? comparison (same id, different cell-id):\n")

(let ([a (expr-meta 42 #f)]
      [b (expr-meta 42 #f)])
  (bench "current expr-meta (1 field)" (lambda () (equal? a b)) N))

(let ([a (test-meta-custom 42 100)]
      [b (test-meta-custom 42 200)])
  (bench "custom equal? (ignores cell-id)" (lambda () (equal? a b)) N))

(let ([a (test-meta-default 42 100)]
      [b (test-meta-default 42 200)])
  (bench "default equal? (compares cell-id)" (lambda () (equal? a b)) N))

(let ([a (test-meta-default 42 100)]
      [b (test-meta-default 42 100)])
  (bench "default equal? (same cell-id)" (lambda () (equal? a b)) N))

(printf "\n2. equal? comparison (different id):\n")

(let ([a (expr-meta 42 #f)]
      [b (expr-meta 43 #f)])
  (bench "current expr-meta" (lambda () (equal? a b)) N))

(let ([a (test-meta-custom 42 100)]
      [b (test-meta-custom 43 200)])
  (bench "custom equal?" (lambda () (equal? a b)) N))

(let ([a (test-meta-default 42 100)]
      [b (test-meta-default 43 200)])
  (bench "default equal?" (lambda () (equal? a b)) N))

;; --- Test 2: hash table operations ---
(printf "\n3. Hash table insert + lookup:\n")

(let ([ht (make-hash)]
      [keys (for/list ([i (in-range 100)]) (expr-meta i #f))])
  (bench "current expr-meta hash ops"
         (lambda ()
           (for ([k (in-list keys)])
             (hash-set! ht k (expr-meta-id k)))
           (for ([k (in-list keys)])
             (hash-ref ht k #f)))
         (quotient N 100)))

(let ([ht (make-hash)]
      [keys (for/list ([i (in-range 100)]) (test-meta-custom i (* i 10)))])
  (bench "custom equal? hash ops"
         (lambda ()
           (for ([k (in-list keys)])
             (hash-set! ht k (test-meta-custom-id k)))
           (for ([k (in-list keys)])
             (hash-ref ht k #f)))
         (quotient N 100)))

(let ([ht (make-hash)]
      [keys (for/list ([i (in-range 100)]) (test-meta-default i (* i 10)))])
  (bench "default equal? hash ops"
         (lambda ()
           (for ([k (in-list keys)])
             (hash-set! ht k (test-meta-default-id k)))
           (for ([k (in-list keys)])
             (hash-ref ht k #f)))
         (quotient N 100)))

;; --- Test 3: eq? comparison (unaffected by gen:equal+hash) ---
(printf "\n4. eq? comparison (identity, not equality):\n")

(let ([a (expr-meta 42 #f)])
  (bench "current expr-meta eq?" (lambda () (eq? a a)) N))

(let ([a (test-meta-custom 42 100)])
  (bench "custom eq?" (lambda () (eq? a a)) N))

(printf "\n5. Struct predicate (unaffected by gen:equal+hash):\n")

(let ([a (expr-meta 42 #f)])
  (bench "expr-meta?" (lambda () (expr-meta? a)) N))

(let ([a (test-meta-custom 42 100)])
  (bench "test-meta-custom?" (lambda () (test-meta-custom? a)) N))

(printf "\nDone.\n")

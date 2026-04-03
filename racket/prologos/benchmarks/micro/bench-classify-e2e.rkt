#lang racket/base

;; ========================================================================
;; SRE Track 2 Pre-0 (E2E): Full Classify Path Comparison
;; ========================================================================
;;
;; Measures the FULL classify → extract → build-result path for both
;; the current classify-whnf-problem and the proposed SRE-based dispatch.
;;
;; This answers the D.3 critique §1: "The design needs to compare full
;; classify+extract cost, not just tag lookup cost."

(require "../../syntax.rkt"
         "../../ctor-registry.rkt"
         "../../sre-core.rkt"
         "../../type-lattice.rkt"
         "../../unify.rkt")

;; ========================================
;; Test expressions
;; ========================================

(define pi-a (expr-Pi 'mw expr-Int (expr-Pi 'mw expr-Int expr-Bool)))
(define pi-b (expr-Pi 'mw expr-Nat (expr-Pi 'mw expr-Nat expr-Bool)))

(define app-a (expr-app (expr-fvar 'f) expr-Int))
(define app-b (expr-app (expr-fvar 'f) expr-Nat))

(define eq-a (expr-Eq expr-Int (expr-int 1) (expr-int 2)))
(define eq-b (expr-Eq expr-Int (expr-int 3) (expr-int 4)))

(define pair-a (expr-pair (expr-int 1) (expr-true)))
(define pair-b (expr-pair (expr-int 2) (expr-false)))

(define vec-a (expr-Vec expr-Int (expr-nat-val 3)))
(define vec-b (expr-Vec expr-Nat (expr-nat-val 5)))

(define suc-a (expr-suc (expr-suc expr-zero)))
(define suc-b (expr-suc (expr-suc (expr-suc expr-zero))))

(define sigma-a (expr-Sigma expr-Int expr-Bool))
(define sigma-b (expr-Sigma expr-Nat expr-Bool))

;; Atoms (no structure)
(define atom-a expr-Int)
(define atom-b expr-Nat)

;; Identical (equal? fast path)
(define same-a (expr-Pi 'mw expr-Int expr-Bool))
(define same-b (expr-Pi 'mw expr-Int expr-Bool))

;; Meta (flex-rigid)
(define meta-a (expr-meta 'test-meta-1 #f))
(define concrete-b expr-Int)

;; flex-app: (app (meta ?F) arg) vs (app (fvar f) arg)
(define flex-app-a (expr-app (expr-meta 'test-meta-flex #f) expr-Int))
(define flex-app-b (expr-app (expr-fvar 'g) expr-Nat))

;; ========================================
;; Simulated SRE classify path
;; ========================================
;;
;; This simulates what sre-classify-problem would do:
;; 1. equal? check
;; 2. hole checks
;; 3. meta checks
;; 4. flex-app check (D.3 §7: BEFORE SRE dispatch)
;; 5. SRE tag lookup via ctor-tag-for-value
;; 6. Same-tag check
;; 7. Component extraction via extract-fn
;; 8. Build result

(define type-domain
  (sre-domain 'type
              type-lattice-merge type-top? type-bot? type-bot type-top
              expr-meta? #f #f (hasheq) (hasheq) (hasheq))) ;; Track 2G: property-cell-ids, declared-properties, operations

;; Check if expr-app is headed by an unsolved meta (flex-app pattern)
(define (flex-app-check? v)
  (and (expr-app? v)
       (let loop ([e v])
         (cond
           [(expr-app? e) (loop (expr-app-func e))]
           [(expr-meta? e) #t]
           [else #f]))))

(define (sre-classify-e2e a b)
  (cond
    ;; Fast path: identical
    [(equal? a b) '(ok)]
    ;; Holes
    [(expr-hole? a) '(ok)]
    [(expr-hole? b) '(ok)]
    ;; Same unsolved meta
    [(and (expr-meta? a) (expr-meta? b)
          (eq? (expr-meta-id a) (expr-meta-id b)))
     '(ok)]
    ;; Bare meta
    [(expr-meta? a) (list 'flex-rigid (expr-meta-id a) b)]
    [(expr-meta? b) (list 'flex-rigid (expr-meta-id b) a)]
    ;; flex-app check BEFORE SRE dispatch (D.3 §7)
    [(flex-app-check? a) (list 'flex-app a b)]
    [(flex-app-check? b) (list 'flex-app b a)]
    ;; SRE structural dispatch
    [else
     (define desc-a (ctor-tag-for-value a))
     (define desc-b (ctor-tag-for-value b))
     (cond
       [(and desc-a desc-b
             (eq? (ctor-desc-tag desc-a) (ctor-desc-tag desc-b))
             (eq? (ctor-desc-domain desc-a) 'type)
             (eq? (ctor-desc-domain desc-b) 'type))
        ;; Same structural tag — extract components
        (define comps-a ((ctor-desc-extract-fn desc-a) a))
        (define comps-b ((ctor-desc-extract-fn desc-b) b))
        (define binder-depth (ctor-desc-binder-depth desc-a))
        (cond
          [(and binder-depth (> binder-depth 0))
           ;; Binder case (Pi, Sigma, lam)
           ;; For Pi: need to extract mult separately
           (if (expr-Pi? a)
               (list 'pi
                     (expr-Pi-mult a) (expr-Pi-mult b)
                     (car comps-a) (car comps-b)
                     (cadr comps-a) (cadr comps-b))
               (list 'binder
                     (car comps-a) (car comps-b)
                     (cadr comps-a) (cadr comps-b)))]
          [else
           ;; Non-binder structural: build sub-goals
           (list 'sub (map cons comps-a comps-b))])]
       ;; Level
       [(and (expr-Type? a) (expr-Type? b))
        (list 'level (expr-Type-level a) (expr-Type-level b))]
       ;; Union
       [(and (expr-union? a) (expr-union? b))
        (list 'union (flatten-union a) (flatten-union b))]
       ;; Fallback
       [else '(conv)])]))

;; Same as above but using sre-constructor-tag (includes bot?/contradicts? checks)
(define (sre-classify-full a b)
  (cond
    [(equal? a b) '(ok)]
    [(expr-hole? a) '(ok)]
    [(expr-hole? b) '(ok)]
    [(and (expr-meta? a) (expr-meta? b)
          (eq? (expr-meta-id a) (expr-meta-id b)))
     '(ok)]
    [(expr-meta? a) (list 'flex-rigid (expr-meta-id a) b)]
    [(expr-meta? b) (list 'flex-rigid (expr-meta-id b) a)]
    [(flex-app-check? a) (list 'flex-app a b)]
    [(flex-app-check? b) (list 'flex-app b a)]
    [else
     (define tag-a (sre-constructor-tag type-domain a))
     (define tag-b (sre-constructor-tag type-domain b))
     (cond
       [(and tag-a tag-b (eq? tag-a tag-b))
        (define desc (lookup-ctor-desc tag-a #:domain 'type))
        (define comps-a ((ctor-desc-extract-fn desc) a))
        (define comps-b ((ctor-desc-extract-fn desc) b))
        (define binder-depth (ctor-desc-binder-depth desc))
        (cond
          [(and binder-depth (> binder-depth 0))
           (if (expr-Pi? a)
               (list 'pi
                     (expr-Pi-mult a) (expr-Pi-mult b)
                     (car comps-a) (car comps-b)
                     (cadr comps-a) (cadr comps-b))
               (list 'binder
                     (car comps-a) (car comps-b)
                     (cadr comps-a) (cadr comps-b)))]
          [else
           (list 'sub (map cons comps-a comps-b))])]
       [(and (expr-Type? a) (expr-Type? b))
        (list 'level (expr-Type-level a) (expr-Type-level b))]
       [(and (expr-union? a) (expr-union? b))
        (list 'union (flatten-union a) (flatten-union b))]
       [else '(conv)])]))

;; ========================================
;; Benchmark runner
;; ========================================

(define (bench label fn a b n)
  (collect-garbage)
  (collect-garbage)
  (define t0 (current-inexact-monotonic-milliseconds))
  (for ([_ (in-range n)])
    (fn a b))
  (define elapsed-us (* (- (current-inexact-monotonic-milliseconds) t0) 1000))
  (define per-call-ns (* (/ elapsed-us n) 1000))
  (printf "  ~a: ~a ns/call\n" label (exact->inexact (round per-call-ns))))

;; ========================================
;; Correctness verification
;; ========================================

(printf "\n=== Correctness Check ===\n")
(define test-pairs
  (list (list "Pi-vs-Pi" pi-a pi-b)
        (list "app-vs-app" app-a app-b)
        (list "Eq-vs-Eq" eq-a eq-b)
        (list "pair-vs-pair" pair-a pair-b)
        (list "Vec-vs-Vec" vec-a vec-b)
        (list "suc-vs-suc" suc-a suc-b)
        (list "Sigma-vs-Sigma" sigma-a sigma-b)
        (list "identical" same-a same-b)
        (list "atom-vs-atom" atom-a atom-b)
        (list "meta-vs-concrete" meta-a concrete-b)
        (list "flex-app" flex-app-a flex-app-b)))

(for ([tp (in-list test-pairs)])
  (define label (car tp))
  (define a (cadr tp))
  (define b (caddr tp))
  (define current-result (classify-whnf-problem a b))
  (define sre-result (sre-classify-e2e a b))
  (define sre-full-result (sre-classify-full a b))
  (define tag-match? (eq? (if (pair? current-result) (car current-result) current-result)
                         (if (pair? sre-result) (car sre-result) sre-result)))
  (printf "  ~a: current=~a sre=~a match?=~a\n"
          label
          (if (pair? current-result) (car current-result) current-result)
          (if (pair? sre-result) (car sre-result) sre-result)
          tag-match?))

;; ========================================
;; Performance comparison
;; ========================================

(define N 100000)

(printf "\n=== E2E Performance: classify-whnf-problem (current) ===\n")
(bench "Pi-vs-Pi" classify-whnf-problem pi-a pi-b N)
(bench "app-vs-app" classify-whnf-problem app-a app-b N)
(bench "Eq-vs-Eq" classify-whnf-problem eq-a eq-b N)
(bench "pair-vs-pair" classify-whnf-problem pair-a pair-b N)
(bench "Vec-vs-Vec" classify-whnf-problem vec-a vec-b N)
(bench "suc-vs-suc" classify-whnf-problem suc-a suc-b N)
(bench "Sigma-vs-Sigma" classify-whnf-problem sigma-a sigma-b N)
(bench "identical" classify-whnf-problem same-a same-b N)
(bench "atom-vs-atom" classify-whnf-problem atom-a atom-b N)
(bench "meta-vs-concrete" classify-whnf-problem meta-a concrete-b N)
(bench "flex-app" classify-whnf-problem flex-app-a flex-app-b N)

(printf "\n=== E2E Performance: sre-classify-e2e (ctor-tag-for-value) ===\n")
(bench "Pi-vs-Pi" sre-classify-e2e pi-a pi-b N)
(bench "app-vs-app" sre-classify-e2e app-a app-b N)
(bench "Eq-vs-Eq" sre-classify-e2e eq-a eq-b N)
(bench "pair-vs-pair" sre-classify-e2e pair-a pair-b N)
(bench "Vec-vs-Vec" sre-classify-e2e vec-a vec-b N)
(bench "suc-vs-suc" sre-classify-e2e suc-a suc-b N)
(bench "Sigma-vs-Sigma" sre-classify-e2e sigma-a sigma-b N)
(bench "identical" sre-classify-e2e same-a same-b N)
(bench "atom-vs-atom" sre-classify-e2e atom-a atom-b N)
(bench "meta-vs-concrete" sre-classify-e2e meta-a concrete-b N)
(bench "flex-app" sre-classify-e2e flex-app-a flex-app-b N)

(printf "\n=== E2E Performance: sre-classify-full (sre-constructor-tag) ===\n")
(bench "Pi-vs-Pi" sre-classify-full pi-a pi-b N)
(bench "app-vs-app" sre-classify-full app-a app-b N)
(bench "Eq-vs-Eq" sre-classify-full eq-a eq-b N)
(bench "pair-vs-pair" sre-classify-full pair-a pair-b N)
(bench "Vec-vs-Vec" sre-classify-full vec-a vec-b N)
(bench "suc-vs-suc" sre-classify-full suc-a suc-b N)
(bench "Sigma-vs-Sigma" sre-classify-full sigma-a sigma-b N)
(bench "identical" sre-classify-full same-a same-b N)
(bench "atom-vs-atom" sre-classify-full atom-a atom-b N)
(bench "meta-vs-concrete" sre-classify-full meta-a concrete-b N)
(bench "flex-app" sre-classify-full flex-app-a flex-app-b N)

;; ========================================
;; Component extraction cost isolation
;; ========================================

(printf "\n=== Extraction Cost: closure vs direct field access ===\n")

;; Direct field access (current pattern)
(define (extract-pi-direct e)
  (list (expr-Pi-domain e) (expr-Pi-codomain e)))

;; Closure call (SRE pattern)
(define pi-desc (lookup-ctor-desc 'Pi #:domain 'type))
(define pi-extract-fn (and pi-desc (ctor-desc-extract-fn pi-desc)))

(define (extract-pi-closure e)
  (pi-extract-fn e))

(define (bench-extract label fn expr n)
  (collect-garbage)
  (collect-garbage)
  (define t0 (current-inexact-monotonic-milliseconds))
  (for ([_ (in-range n)])
    (fn expr))
  (define elapsed-us (* (- (current-inexact-monotonic-milliseconds) t0) 1000))
  (define per-call-ns (* (/ elapsed-us n) 1000))
  (printf "  ~a: ~a ns/call\n" label (exact->inexact (round per-call-ns))))

(bench-extract "Pi direct field" extract-pi-direct pi-a N)
(bench-extract "Pi closure (SRE)" extract-pi-closure pi-a N)

;; Eq: 3 fields
(define eq-desc (lookup-ctor-desc 'Eq #:domain 'type))
(define eq-extract-fn (and eq-desc (ctor-desc-extract-fn eq-desc)))

(define (extract-eq-direct e)
  (list (expr-Eq-type e) (expr-Eq-lhs e) (expr-Eq-rhs e)))

(define (extract-eq-closure e)
  (eq-extract-fn e))

(bench-extract "Eq direct field (3)" extract-eq-direct eq-a N)
(bench-extract "Eq closure (SRE) (3)" extract-eq-closure eq-a N)

;; suc: 1 field
(define suc-desc (lookup-ctor-desc 'suc #:domain 'type))
(define suc-extract-fn (and suc-desc (ctor-desc-extract-fn suc-desc)))

(define (extract-suc-direct e)
  (list (expr-suc-pred e)))

(define (extract-suc-closure e)
  (suc-extract-fn e))

(bench-extract "suc direct field (1)" extract-suc-direct suc-a N)
(bench-extract "suc closure (SRE) (1)" extract-suc-closure suc-a N)

(printf "\n=== Done ===\n")

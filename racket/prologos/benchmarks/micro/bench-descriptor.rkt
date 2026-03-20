#lang racket/base

;; bench-descriptor.rkt — Micro-benchmarks for constructor descriptor registry
;;
;; Stresses: lookup, extract, reconstruct, decompose, tag recognition.
;; Validates that registry dispatch adds minimal overhead vs direct struct access.
;;
;; Design reference: PUnify Part 2 Phase 1, deliverable 11.

(require racket/list
         "../../tools/bench-micro.rkt"
         "../../syntax.rkt"
         "../../ctor-registry.rkt")

;; ============================================================
;; Sample values for benchmarks
;; ============================================================

;; Type constructor samples
(define sample-pi (expr-Pi 'mw (expr-Nat) (expr-Nat)))
(define sample-sigma (expr-Sigma (expr-Nat) (expr-Nat)))
(define sample-app (expr-app (expr-tycon 'List) (expr-Nat)))
(define sample-eq (expr-Eq (expr-Nat) (expr-zero) (expr-zero)))
(define sample-vec (expr-Vec (expr-Nat) (expr-zero)))
(define sample-pair (expr-pair (expr-Nat) (expr-Nat)))
(define sample-lam (expr-lam 'mw (expr-Nat) (expr-zero)))

;; Atom (non-compound)
(define sample-nat (expr-Nat))

;; Data constructor samples
(define sample-cons (list 'cons 1 2))
(define sample-some (list 'some 42))
(define sample-nil '(nil))

;; Deeply nested type for decompose stress
(define (deep-pi depth)
  (if (zero? depth)
      (expr-Nat)
      (expr-Pi 'mw (expr-Nat) (deep-pi (sub1 depth)))))
(define sample-deep-pi (deep-pi 10))


;; ============================================================
;; 1. Lookup benchmarks
;; ============================================================

;; Direct struct predicate (baseline)
(define b-direct-predicate
  (bench "direct: expr-Pi? predicate (1000x)"
    (lambda ()
      (for ([_ (in-range 1000)])
        (expr-Pi? sample-pi)))))

;; Registry lookup by tag (should be ~same as hash-ref)
(define b-lookup-tag
  (bench "registry: lookup-ctor-desc by tag (1000x)"
    (lambda ()
      (for ([_ (in-range 1000)])
        (lookup-ctor-desc 'Pi)))))

;; Registry tag-for-value (recognizer chain traversal)
(define b-tag-for-value-pi
  (bench "registry: ctor-tag-for-value Pi (1000x)"
    (lambda ()
      (for ([_ (in-range 1000)])
        (ctor-tag-for-value sample-pi)))))

;; Tag-for-value on atom (full chain scan, returns #f)
(define b-tag-for-value-atom
  (bench "registry: ctor-tag-for-value atom (1000x)"
    (lambda ()
      (for ([_ (in-range 1000)])
        (ctor-tag-for-value sample-nat)))))

;; Tag-for-value on data constructor (later in chain)
(define b-tag-for-value-cons
  (bench "registry: ctor-tag-for-value cons (1000x)"
    (lambda ()
      (for ([_ (in-range 1000)])
        (ctor-tag-for-value sample-cons)))))


;; ============================================================
;; 2. Extract benchmarks
;; ============================================================

;; Direct field access (baseline)
(define b-direct-extract-pi
  (bench "direct: Pi field access (1000x)"
    (lambda ()
      (for ([_ (in-range 1000)])
        (list (expr-Pi-mult sample-pi)
              (expr-Pi-domain sample-pi)
              (expr-Pi-codomain sample-pi))))))

;; Registry extract via descriptor
(define b-registry-extract-pi
  (let ([desc (lookup-ctor-desc 'Pi)])
    (bench "registry: extract Pi via descriptor (1000x)"
      (lambda ()
        (for ([_ (in-range 1000)])
          ((ctor-desc-extract-fn desc) sample-pi))))))

;; Generic decompose (lookup + extract)
(define b-generic-decompose-pi
  (bench "registry: generic-decompose-components Pi (1000x)"
    (lambda ()
      (for ([_ (in-range 1000)])
        (generic-decompose-components sample-pi)))))


;; ============================================================
;; 3. Reconstruct benchmarks
;; ============================================================

(define pi-components (list 'mw (expr-Nat) (expr-Nat)))

;; Direct constructor (baseline)
(define b-direct-reconstruct-pi
  (bench "direct: expr-Pi constructor (1000x)"
    (lambda ()
      (for ([_ (in-range 1000)])
        (expr-Pi (first pi-components) (second pi-components) (third pi-components))))))

;; Registry reconstruct
(define b-registry-reconstruct-pi
  (bench "registry: generic-reconstruct-value Pi (1000x)"
    (lambda ()
      (for ([_ (in-range 1000)])
        (generic-reconstruct-value 'Pi pi-components)))))


;; ============================================================
;; 4. Roundtrip (extract → reconstruct)
;; ============================================================

(define b-roundtrip-pi
  (let ([desc (lookup-ctor-desc 'Pi)])
    (bench "registry: roundtrip Pi (extract→reconstruct) (1000x)"
      (lambda ()
        (for ([_ (in-range 1000)])
          (define cs ((ctor-desc-extract-fn desc) sample-pi))
          ((ctor-desc-reconstruct-fn desc) cs))))))

(define b-roundtrip-app
  (let ([desc (lookup-ctor-desc 'app)])
    (bench "registry: roundtrip App (extract→reconstruct) (1000x)"
      (lambda ()
        (for ([_ (in-range 1000)])
          (define cs ((ctor-desc-extract-fn desc) sample-app))
          ((ctor-desc-reconstruct-fn desc) cs))))))


;; ============================================================
;; 5. Data constructor operations
;; ============================================================

(define b-extract-cons
  (let ([desc (lookup-ctor-desc 'cons)])
    (bench "registry: extract cons data ctor (1000x)"
      (lambda ()
        (for ([_ (in-range 1000)])
          ((ctor-desc-extract-fn desc) sample-cons))))))

(define b-reconstruct-cons
  (bench "registry: reconstruct cons data ctor (1000x)"
    (lambda ()
      (for ([_ (in-range 1000)])
        (generic-reconstruct-value 'cons (list 1 2))))))


;; ============================================================
;; Summary
;; ============================================================

(print-bench-summary
 (list b-direct-predicate
       b-lookup-tag
       b-tag-for-value-pi
       b-tag-for-value-atom
       b-tag-for-value-cons
       b-direct-extract-pi
       b-registry-extract-pi
       b-generic-decompose-pi
       b-direct-reconstruct-pi
       b-registry-reconstruct-pi
       b-roundtrip-pi
       b-roundtrip-app
       b-extract-cons
       b-reconstruct-cons))

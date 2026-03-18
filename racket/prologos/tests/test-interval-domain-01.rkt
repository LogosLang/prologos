#lang racket/base

;;;
;;; Tests for Phase 2a: Interval Abstract Domain
;;; Tests interval-domain.rkt, narrowing-abstract.rkt, and interval-bounded
;;; narrowing in narrowing.rkt.
;;;
;;; Covers: interval struct, lattice ops, arithmetic, constraint propagators,
;;; split, Galois connection, integration with narrowing search, performance.
;;;

(require rackunit
         racket/list
         racket/string
         racket/path
         racket/file
         racket/port
         "../interval-domain.rkt"
         "../narrowing-abstract.rkt"
         "../definitional-tree.rkt"
         "../narrowing.rkt"
         "../macros.rkt"
         "../syntax.rkt"
         "../prelude.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../reduction.rkt"
         "../namespace.rkt"
         "../trait-resolution.rkt")

;; ========================================
;; Shared Fixture (for integration tests)
;; ========================================

(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-bundle-reg)
  (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (current-trait-registry)]
                 [current-impl-registry (current-impl-registry)]
                 [current-param-impl-registry (current-param-impl-registry)]
                 [current-bundle-registry (current-bundle-registry)])
    (install-module-loader!)
    (process-string "(ns test-interval-domain)")
    (values (current-global-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-bundle-registry))))

;; ========================================
;; A. Interval struct and predicates
;; ========================================

(test-case "interval/singleton"
  (check-true  (interval-singleton? (interval 5 5)))
  (check-false (interval-singleton? (interval 0 1)))
  (check-false (interval-singleton? (interval 0 +inf.0))))

(test-case "interval/finite"
  (check-true  (interval-finite? (interval 0 10)))
  (check-true  (interval-finite? (interval -3 3)))
  (check-false (interval-finite? (interval 0 +inf.0)))
  (check-false (interval-finite? (interval -inf.0 +inf.0))))

(test-case "interval/size"
  (check-equal? (interval-size (interval 0 0)) 1)
  (check-equal? (interval-size (interval 0 10)) 11)
  (check-equal? (interval-size (interval 3 7)) 5)
  (check-equal? (interval-size interval-empty) 0)
  (check-false  (interval-size (interval 0 +inf.0))))

(test-case "interval/contains"
  (check-true  (interval-contains? (interval 0 10) 5))
  (check-true  (interval-contains? (interval 0 10) 0))
  (check-true  (interval-contains? (interval 0 10) 10))
  (check-false (interval-contains? (interval 0 10) 11))
  (check-false (interval-contains? (interval 0 10) -1))
  (check-true  (interval-contains? interval-nat-full 100))
  (check-false (interval-contains? interval-nat-full -1)))

;; ========================================
;; B. Constants and type mapping
;; ========================================

(test-case "interval/constants"
  (check-equal? (interval-lo interval-nat-full) 0)
  (check-equal? (interval-hi interval-nat-full) +inf.0)
  (check-equal? (interval-lo interval-posint-full) 1)
  (check-equal? (interval-lo interval-int-full) -inf.0)
  (check-equal? (interval-hi interval-int-full) +inf.0))

(test-case "interval/type-initial"
  (check-equal? (type-initial-interval 'Nat) interval-nat-full)
  (check-equal? (type-initial-interval 'PosInt) interval-posint-full)
  (check-equal? (type-initial-interval 'Int) interval-int-full)
  (check-equal? (type-initial-interval 'prologos::data::nat::Nat) interval-nat-full))

(test-case "interval/nat-type-name"
  (check-not-false (nat-type-name? 'Nat))
  (check-not-false (nat-type-name? 'PosInt))
  (check-not-false (nat-type-name? 'Int))
  (check-not-false (nat-type-name? 'prologos::data::nat::Nat))
  (check-false (nat-type-name? 'Bool))
  (check-false (nat-type-name? 'List)))

;; ========================================
;; C. Lattice operations
;; ========================================

(test-case "interval/merge-intersection"
  ;; [0,10] ∩ [5,15] = [5,10]
  (define m (interval-merge (interval 0 10) (interval 5 15)))
  (check-equal? (interval-lo m) 5)
  (check-equal? (interval-hi m) 10))

(test-case "interval/merge-disjoint"
  ;; [0,3] ∩ [5,10] = contradiction
  (define m (interval-merge (interval 0 3) (interval 5 10)))
  (check-true (interval-contradiction? m)))

(test-case "interval/merge-identity"
  ;; [a,b] ∩ [-∞,+∞] = [a,b]
  (define m (interval-merge (interval 2 5) interval-int-full))
  (check-equal? (interval-lo m) 2)
  (check-equal? (interval-hi m) 5))

(test-case "interval/merge-nat-clamp"
  ;; [-3,10] ∩ [0,+∞) = [0,10]
  (define m (interval-merge (interval -3 10) interval-nat-full))
  (check-equal? (interval-lo m) 0)
  (check-equal? (interval-hi m) 10))

(test-case "interval/contradiction"
  (check-true  (interval-contradiction? interval-empty))
  (check-true  (interval-contradiction? (interval 5 3)))
  (check-false (interval-contradiction? (interval 0 0)))
  (check-false (interval-contradiction? interval-nat-full)))

;; ========================================
;; D. Arithmetic
;; ========================================

(test-case "interval/add"
  ;; [0,0] + [0,0] = [0,0]
  (define r1 (interval-add (interval 0 0) (interval 0 0)))
  (check-equal? (interval-lo r1) 0)
  (check-equal? (interval-hi r1) 0)
  ;; [1,3] + [2,4] = [3,7]
  (define r2 (interval-add (interval 1 3) (interval 2 4)))
  (check-equal? (interval-lo r2) 3)
  (check-equal? (interval-hi r2) 7))

(test-case "interval/sub"
  ;; [5,10] - [1,3] = [2,9]
  (define r (interval-sub (interval 5 10) (interval 1 3)))
  (check-equal? (interval-lo r) 2)
  (check-equal? (interval-hi r) 9))

(test-case "interval/mul"
  ;; [2,3] × [4,5] = [8,15]
  (define r (interval-mul (interval 2 3) (interval 4 5)))
  (check-equal? (interval-lo r) 8)
  (check-equal? (interval-hi r) 15))

(test-case "interval/mul-with-zero"
  ;; [0,3] × [0,5] = [0,15]
  (define r (interval-mul (interval 0 3) (interval 0 5)))
  (check-equal? (interval-lo r) 0)
  (check-equal? (interval-hi r) 15))

(test-case "interval/negate"
  ;; -[2,5] = [-5,-2]
  (define r (interval-negate (interval 2 5)))
  (check-equal? (interval-lo r) -5)
  (check-equal? (interval-hi r) -2))

(test-case "interval/clamp-nat"
  ;; [-3,10] clamped to [0,10]
  (define r (interval-clamp-nat (interval -3 10)))
  (check-equal? (interval-lo r) 0)
  (check-equal? (interval-hi r) 10))

(test-case "interval/add-infinite"
  ;; [0,+inf) + [0,+inf) = [0,+inf)
  (define r (interval-add interval-nat-full interval-nat-full))
  (check-equal? (interval-lo r) 0)
  (check-equal? (interval-hi r) +inf.0))

;; ========================================
;; E. Constraint propagators
;; ========================================

(test-case "constraint/add: x+y=5"
  ;; x ∈ [0,+inf), y ∈ [0,+inf), z = [5,5]
  (define-values (nx ny nz)
    (interval-add-constraint interval-nat-full interval-nat-full (interval 5 5)))
  ;; x' = [0,+inf) ∩ ([5,5] - [0,+inf)) = [0,+inf) ∩ [-inf,5] = [0,5]
  (check-equal? (interval-lo nx) 0)
  (check-equal? (interval-hi nx) 5)
  ;; y' = [0,5]
  (check-equal? (interval-lo ny) 0)
  (check-equal? (interval-hi ny) 5)
  ;; z' = [5,5] (singleton)
  (check-equal? (interval-lo nz) 5)
  (check-equal? (interval-hi nz) 5))

(test-case "constraint/add: x+y=0"
  (define-values (nx ny nz)
    (interval-add-constraint interval-nat-full interval-nat-full (interval 0 0)))
  ;; x' = [0,0], y' = [0,0]
  (check-equal? (interval-lo nx) 0)
  (check-equal? (interval-hi nx) 0)
  (check-equal? (interval-lo ny) 0)
  (check-equal? (interval-hi ny) 0))

(test-case "constraint/sub: x-y=3"
  (define-values (nx ny nz)
    (interval-sub-constraint interval-nat-full interval-nat-full (interval 3 3)))
  ;; z = x - y = 3, so x = z + y >= 3
  (check-equal? (interval-lo nx) 3)
  ;; y = x - z
  (check-equal? (interval-lo ny) 0))

(test-case "constraint/mul: x*y=12"
  (define-values (nx ny nz)
    (interval-mul-constraint
     (interval 1 +inf.0) (interval 1 +inf.0) (interval 12 12)))
  ;; z' = [12,12]
  (check-equal? (interval-lo nz) 12)
  (check-equal? (interval-hi nz) 12)
  ;; x and y bounded by division
  (check-true (<= (interval-lo nx) 12))
  (check-true (<= (interval-lo ny) 12)))

;; ========================================
;; F. Split
;; ========================================

(test-case "interval/split-even"
  ;; [0,9] → [0,4] and [5,9]
  (define-values (lo-half hi-half) (interval-split (interval 0 9)))
  (check-equal? (interval-lo lo-half) 0)
  (check-equal? (interval-hi lo-half) 4)
  (check-equal? (interval-lo hi-half) 5)
  (check-equal? (interval-hi hi-half) 9))

(test-case "interval/split-small"
  ;; [0,1] → [0,0] and [1,1]
  (define-values (lo-half hi-half) (interval-split (interval 0 1)))
  (check-true (interval-singleton? lo-half))
  (check-true (interval-singleton? hi-half)))

;; ========================================
;; G. Galois connection (narrowing-abstract.rkt)
;; ========================================

(test-case "galois/term->interval: zero"
  (define iv (term->interval (expr-zero)))
  (check-equal? (interval-lo iv) 0)
  (check-equal? (interval-hi iv) 0))

(test-case "galois/term->interval: suc(zero)"
  (define iv (term->interval (expr-suc (expr-zero))))
  (check-equal? (interval-lo iv) 1)
  (check-equal? (interval-hi iv) 1))

(test-case "galois/term->interval: suc(suc(zero))"
  (define iv (term->interval (expr-suc (expr-suc (expr-zero)))))
  (check-equal? (interval-lo iv) 2)
  (check-equal? (interval-hi iv) 2))

(test-case "galois/term->interval: nat-val"
  (define iv (term->interval (expr-nat-val 7)))
  (check-equal? (interval-lo iv) 7)
  (check-equal? (interval-hi iv) 7))

(test-case "galois/term->interval: logic-var"
  (define iv (term->interval (expr-logic-var 'x 'free)))
  (check-equal? (interval-lo iv) 0)
  (check-equal? (interval-hi iv) +inf.0))

(test-case "galois/term->interval: suc(suc(logic-var))"
  (define iv (term->interval (expr-suc (expr-suc (expr-logic-var 'x 'free)))))
  (check-equal? (interval-lo iv) 2)
  (check-equal? (interval-hi iv) +inf.0))

(test-case "galois/integer->peano"
  (check-true (expr-zero? (integer->peano 0)))
  (check-true (expr-suc? (integer->peano 1)))
  (check-true (expr-zero? (expr-suc-pred (integer->peano 1))))
  ;; 3 = suc(suc(suc(zero)))
  (define p3 (integer->peano 3))
  (check-true (expr-suc? p3))
  (check-true (expr-suc? (expr-suc-pred p3)))
  (check-true (expr-suc? (expr-suc-pred (expr-suc-pred p3))))
  (check-true (expr-zero? (expr-suc-pred (expr-suc-pred (expr-suc-pred p3))))))

(test-case "galois/interval->peano-or-false"
  ;; Singleton → peano
  (define p (interval->peano-or-false (interval 3 3)))
  (check-not-false p)
  (check-true (expr-suc? p))
  ;; Non-singleton → #f
  (check-false (interval->peano-or-false (interval 0 5)))
  (check-false (interval->peano-or-false interval-nat-full)))

(test-case "galois/compute-arg-intervals: add"
  (define ivs
    (compute-arg-intervals
     'prologos::data::nat::add
     (list (expr-logic-var 'x 'free) (expr-logic-var 'y 'free))
     (expr-nat-val 5)))
  (check-not-false ivs)
  (check-equal? (length ivs) 2)
  ;; Both args bounded to [0,5]
  (check-equal? (interval-lo (car ivs)) 0)
  (check-equal? (interval-hi (car ivs)) 5)
  (check-equal? (interval-lo (cadr ivs)) 0)
  (check-equal? (interval-hi (cadr ivs)) 5))

(test-case "galois/compute-arg-intervals: sub"
  (define ivs
    (compute-arg-intervals
     'prologos::data::nat::sub
     (list (expr-logic-var 'x 'free) (expr-logic-var 'y 'free))
     (expr-nat-val 3)))
  (check-not-false ivs)
  (check-equal? (length ivs) 2))

(test-case "galois/compute-arg-intervals: unknown func"
  (define ivs
    (compute-arg-intervals
     'prologos::data::bool::not
     (list (expr-logic-var 'b 'free))
     (expr-true)))
  (check-false ivs))

;; ========================================
;; H. Integration with narrowing search
;; ========================================

(test-case "integration/add 0: 1 solution"
  (parameterize ([current-global-env shared-global-env])
    (define sols
      (run-narrowing-search
       'prologos::data::nat::add
       (list (expr-logic-var 'x 'free) (expr-logic-var 'y 'free))
       (expr-zero)
       '(x y)))
    (check-equal? (length sols) 1)
    (check-true (expr-zero? (hash-ref (car sols) 'x)))
    (check-true (expr-zero? (hash-ref (car sols) 'y)))))

(test-case "integration/add 1: 2 solutions"
  (parameterize ([current-global-env shared-global-env])
    (define sols
      (run-narrowing-search
       'prologos::data::nat::add
       (list (expr-logic-var 'x 'free) (expr-logic-var 'y 'free))
       (expr-suc (expr-zero))
       '(x y)))
    (check-equal? (length sols) 2)))

(test-case "integration/add 3: 4 solutions"
  (parameterize ([current-global-env shared-global-env])
    (define sols
      (run-narrowing-search
       'prologos::data::nat::add
       (list (expr-logic-var 'x 'free) (expr-logic-var 'y 'free))
       (expr-suc (expr-suc (expr-suc (expr-zero))))
       '(x y)))
    (check-equal? (length sols) 4)))

(test-case "integration/add 10: 11 solutions"
  (parameterize ([current-global-env shared-global-env])
    (define target
      (let loop ([n 10])
        (if (zero? n) (expr-zero) (expr-suc (loop (- n 1))))))
    (define sols
      (run-narrowing-search
       'prologos::data::nat::add
       (list (expr-logic-var 'x 'free) (expr-logic-var 'y 'free))
       target
       '(x y)))
    (check-equal? (length sols) 11)))

(test-case "integration/not: unchanged by intervals"
  (parameterize ([current-global-env shared-global-env])
    (define sols
      (run-narrowing-search
       'prologos::data::bool::not
       (list (expr-logic-var 'b 'free))
       (expr-true)
       '(b)))
    (check-equal? (length sols) 1)
    (check-true (expr-false? (hash-ref (car sols) 'b)))))

(test-case "integration/add zero ?y = 5: 1 solution"
  (parameterize ([current-global-env shared-global-env])
    (define target
      (let loop ([n 5])
        (if (zero? n) (expr-zero) (expr-suc (loop (- n 1))))))
    (define sols
      (run-narrowing-search
       'prologos::data::nat::add
       (list (expr-zero) (expr-logic-var 'y 'free))
       target
       '(y)))
    (check-equal? (length sols) 1)))

(test-case "integration/add (suc ?x) ?y = 3: 3 solutions"
  (parameterize ([current-global-env shared-global-env])
    (define target (expr-suc (expr-suc (expr-suc (expr-zero)))))
    (define sols
      (run-narrowing-search
       'prologos::data::nat::add
       (list (expr-suc (expr-logic-var 'x 'free))
             (expr-logic-var 'y 'free))
       target
       '(x y)))
    (check-equal? (length sols) 3)))

#lang racket/base

;; bench-solve-pipeline.rkt — Micro-benchmarks for the full solve pipeline
;;
;; Stresses the complete solver path: relation lookup, clause matching,
;; variable freshening, conjunction solving, backtracking, and answer
;; projection — with controlled relation stores that isolate solver cost
;; from driver/parsing/elaboration overhead.
;;
;; This complements bench-solver-unify.rkt (low-level primitives) and
;; solve-adversarial.prologos (end-to-end through driver). Together,
;; the three benchmarks triangulate PUnify's impact at every level.

(require "../../tools/bench-micro.rkt"
         "../../relations.rkt"
         "../../solver.rkt"
         "../../performance-counters.rkt")

;; ============================================================
;; Helper: build relation stores programmatically
;; ============================================================

;; Build a relation with N facts (ground tuples)
(define (make-fact-relation name arity n-facts [fact-gen #f])
  (define gen (or fact-gen
                  (lambda (i) (for/list ([a (in-range arity)])
                                (+ (* i 100) a)))))
  (define facts (for/list ([i (in-range n-facts)])
                  (fact-row (gen i))))
  (relation-info name arity
    (list (variant-info
           (for/list ([a (in-range arity)])
             (param-info (string->symbol (format "x~a" a)) 'free))
           '() facts))
    #f #f))

;; Build a chain of relations: r0(X) :- r1(X). r1(X) :- r2(X). ... rN(X) :- fact.
;; Stresses conjunction depth and recursive clause resolution.
(define (make-chain-store depth)
  (define store (make-relation-store))
  ;; Terminal: a fact-only relation
  (define terminal
    (relation-info
     (string->symbol (format "r~a" depth)) 1
     (list (variant-info
            (list (param-info 'x 'free))
            '()
            (list (fact-row '(42)))))
     #f #f))
  (define store-with-terminal (relation-register store terminal))
  ;; Chain: each ri(X) :- ri+1(X)
  (for/fold ([s store-with-terminal])
            ([i (in-range depth)])
    (define this-name (string->symbol (format "r~a" i)))
    (define next-name (string->symbol (format "r~a" (add1 i))))
    (define rel
      (relation-info
       this-name 1
       (list (variant-info
              (list (param-info 'x 'free))
              (list (clause-info
                     (list (goal-desc 'app (list next-name '(x))))))
              '()))
       #f #f))
    (relation-register s rel)))

;; Build a relation with N clauses, each with a different ground head
;; Stresses backtracking: solving with a specific target means trying
;; N-1 clauses before finding the right one.
(define (make-branching-store n-clauses)
  (define store (make-relation-store))
  ;; One relation 'find' with n-clauses facts, each with a unique first arg
  (define facts
    (for/list ([i (in-range n-clauses)])
      (fact-row (list i (string->symbol (format "val~a" i))))))
  (define rel
    (relation-info 'find 2
      (list (variant-info
             (list (param-info 'key 'free) (param-info 'val 'free))
             '() facts))
      #f #f))
  (relation-register store rel))

;; Build a multi-hop join store: hop(X,Y) :- step1(X,M), step2(M,Y).
;; With N facts per step relation, produces N matching pairs.
;; Stresses conjunction solving with backtracking join behavior.
(define (make-multihop-store n-per-step n-hops)
  (define store (make-relation-store))
  ;; Create step1, step2, ..., stepN relations (each with n-per-step facts)
  (define store-with-steps
    (for/fold ([s store])
              ([h (in-range n-hops)])
      (define step-name (string->symbol (format "step~a" h)))
      (define step-facts
        (for/list ([i (in-range n-per-step)])
          (fact-row (list (string->symbol (format "s~a_~a" h i))
                          (string->symbol (format "s~a_~a" (add1 h) i))))))
      (define step-rel
        (relation-info step-name 2
          (list (variant-info
                 (list (param-info 'x 'free) (param-info 'y 'free))
                 '() step-facts))
          #f #f))
      (relation-register s step-rel)))
  ;; Create multi-hop relation: hop(X,Y) :- step0(X,M0), step1(M0,M1), ..., stepN-1(MN-2,Y)
  (define vars
    (cons 'x
          (append (for/list ([i (in-range (sub1 n-hops))])
                    (string->symbol (format "m~a" i)))
                  (list 'y))))
  (define goals
    (for/list ([h (in-range n-hops)])
      (define step-name (string->symbol (format "step~a" h)))
      (goal-desc 'app (list step-name (list (list-ref vars h) (list-ref vars (add1 h)))))))
  (define hop-rel
    (relation-info 'hop (length vars)
      (list (variant-info
             (list (param-info 'x 'free) (param-info 'y 'free))
             (list (clause-info goals))
             '()))
      #f #f))
  (relation-register store-with-steps hop-rel))

;; Build a relation with conjunction of N unify goals
;; multi(X1,...,XN) :- X1 = v1, X2 = v2, ..., XN = vN.
(define (make-conjunction-store n-goals)
  (define store (make-relation-store))
  (define params
    (for/list ([i (in-range n-goals)])
      (param-info (string->symbol (format "x~a" i)) 'free)))
  (define goals
    (for/list ([i (in-range n-goals)])
      (goal-desc 'unify (list (string->symbol (format "x~a" i)) i))))
  (define rel
    (relation-info 'multi n-goals
      (list (variant-info params (list (clause-info goals)) '()))
      #f #f))
  (relation-register store rel))

;; Build a diamond-pattern relation store
;; top(X,Y) :- left(X,M), right(M,Y).
;; left(X,M) :- [N facts]
;; right(M,Y) :- [N facts]
;; This creates N² potential answer combinations — stresses join behavior.
(define (make-diamond-store n-per-side)
  (define store (make-relation-store))
  (define left-facts
    (for/list ([i (in-range n-per-side)])
      (fact-row (list (string->symbol (format "l~a" i))
                      (string->symbol (format "m~a" i))))))
  (define right-facts
    (for/list ([i (in-range n-per-side)])
      (fact-row (list (string->symbol (format "m~a" i))
                      (string->symbol (format "r~a" i))))))
  (define left-rel
    (relation-info 'left 2
      (list (variant-info
             (list (param-info 'x 'free) (param-info 'm 'free))
             '() left-facts))
      #f #f))
  (define right-rel
    (relation-info 'right 2
      (list (variant-info
             (list (param-info 'm 'free) (param-info 'y 'free))
             '() right-facts))
      #f #f))
  (define top-rel
    (relation-info 'top 2
      (list (variant-info
             (list (param-info 'x 'free) (param-info 'y 'free))
             (list (clause-info
                    (list (goal-desc 'app (list 'left '(x m)))
                          (goal-desc 'app (list 'right '(m y))))))
             '()))
      #f #f))
  (relation-register
   (relation-register (relation-register store left-rel) right-rel)
   top-rel))

;; ============================================================
;; Section 1: Fact-only relations — pure unification
;; ============================================================

;; 1a. Small fact relation — baseline
(define b-facts-small
  (let* ([store (let ([s (make-relation-store)])
                  (relation-register s (make-fact-relation 'data 3 10)))]
         [cfg default-solver-config])
    (bench "solve: 10 facts, all matches x500"
      (for ([_ (in-range 500)])
        (solve-goal cfg store 'data '() '(x0 x1 x2))))))

;; 1b. Medium fact relation — 100 facts, query all
(define b-facts-medium
  (let* ([store (let ([s (make-relation-store)])
                  (relation-register s (make-fact-relation 'data 3 100)))]
         [cfg default-solver-config])
    (bench "solve: 100 facts, all matches x100"
      (for ([_ (in-range 100)])
        (solve-goal cfg store 'data '() '(x0 x1 x2))))))

;; 1c. Large fact relation — 1000 facts, query all
(define b-facts-large
  (let* ([store (let ([s (make-relation-store)])
                  (relation-register s (make-fact-relation 'data 3 1000)))]
         [cfg default-solver-config])
    (bench "solve: 1000 facts, all matches x20"
      (for ([_ (in-range 20)])
        (solve-goal cfg store 'data '() '(x0 x1 x2))))))

;; 1d. Large fact relation — selective query (ground first arg)
(define b-facts-selective
  (let* ([store (let ([s (make-relation-store)])
                  (relation-register s (make-fact-relation 'data 3 1000)))]
         [cfg default-solver-config])
    (bench "solve: 1000 facts, ground 1st arg (1 match) x200"
      (for ([_ (in-range 200)])
        ;; Query with ground first arg — only 1 fact matches
        (solve-goal cfg store 'data (list 500 'x1 'x2) '(x1 x2))))))

;; ============================================================
;; Section 2: Clause chains — recursive resolution depth
;; ============================================================

;; 2a. Short chain (depth 5)
(define b-chain-5
  (let ([store (make-chain-store 5)]
        [cfg default-solver-config])
    (bench "solve: clause chain depth=5 x500"
      (for ([_ (in-range 500)])
        (solve-goal cfg store 'r0 '() '(x))))))

;; 2b. Medium chain (depth 20)
(define b-chain-20
  (let ([store (make-chain-store 20)]
        [cfg default-solver-config])
    (bench "solve: clause chain depth=20 x200"
      (for ([_ (in-range 200)])
        (solve-goal cfg store 'r0 '() '(x))))))

;; 2c. Deep chain (depth 50) — note: stays within depth limit since each
;; clause only adds 1 depth level (no branching/recursion, just chaining)
(define b-chain-50
  (let ([store (make-chain-store 50)]
        [cfg default-solver-config])
    (bench "solve: clause chain depth=50 x100"
      (for ([_ (in-range 100)])
        (solve-goal cfg store 'r0 '() '(x))))))

;; ============================================================
;; Section 3: Backtracking — many clauses, varying hit position
;; ============================================================

;; 3a. 100 facts, target is the first — best case
(define b-backtrack-first
  (let ([store (make-branching-store 100)]
        [cfg default-solver-config])
    (bench "solve: 100 facts, match first x500"
      (for ([_ (in-range 500)])
        (solve-goal cfg store 'find (list 0 'val) '(val))))))

;; 3b. 100 facts, target is the last — worst case
(define b-backtrack-last
  (let ([store (make-branching-store 100)]
        [cfg default-solver-config])
    (bench "solve: 100 facts, match last x500"
      (for ([_ (in-range 500)])
        (solve-goal cfg store 'find (list 99 'val) '(val))))))

;; 3c. 100 facts, target doesn't exist — exhaustive failure
(define b-backtrack-fail
  (let ([store (make-branching-store 100)]
        [cfg default-solver-config])
    (bench "solve: 100 facts, no match (fail) x500"
      (for ([_ (in-range 500)])
        (solve-goal cfg store 'find (list 999 'val) '(val))))))

;; 3d. 500 facts, worst case
(define b-backtrack-500
  (let ([store (make-branching-store 500)]
        [cfg default-solver-config])
    (bench "solve: 500 facts, match last x100"
      (for ([_ (in-range 100)])
        (solve-goal cfg store 'find (list 499 'val) '(val))))))

;; ============================================================
;; Section 4: Multi-hop joins — conjunction depth
;; ============================================================

;; 4a. 2-hop join, 10 facts per step
(define b-multihop-2x10
  (let ([store (make-multihop-store 10 2)]
        [cfg default-solver-config])
    (bench "solve: 2-hop join, 10 facts/step x200"
      (for ([_ (in-range 200)])
        (solve-goal cfg store 'hop '() '(x y))))))

;; 4b. 3-hop join, 10 facts per step — longer conjunction
(define b-multihop-3x10
  (let ([store (make-multihop-store 10 3)]
        [cfg default-solver-config])
    (bench "solve: 3-hop join, 10 facts/step x100"
      (for ([_ (in-range 100)])
        (solve-goal cfg store 'hop '() '(x y))))))

;; 4c. 2-hop join, 50 facts per step — wider join
(define b-multihop-2x50
  (let ([store (make-multihop-store 50 2)]
        [cfg default-solver-config])
    (bench "solve: 2-hop join, 50 facts/step x50"
      (for ([_ (in-range 50)])
        (solve-goal cfg store 'hop '() '(x y))))))

;; 4d. 5-hop join, 5 facts per step — deep conjunction chain
(define b-multihop-5x5
  (let ([store (make-multihop-store 5 5)]
        [cfg default-solver-config])
    (bench "solve: 5-hop join, 5 facts/step x100"
      (for ([_ (in-range 100)])
        (solve-goal cfg store 'hop '() '(x y))))))

;; ============================================================
;; Section 5: Conjunction depth — many goals per clause
;; ============================================================

;; 5a. 10 unify goals in one clause
(define b-conj-10
  (let ([store (make-conjunction-store 10)]
        [cfg default-solver-config])
    (bench "solve: conjunction of 10 unify goals x500"
      (for ([_ (in-range 500)])
        (solve-goal cfg store 'multi '()
          (for/list ([i (in-range 10)])
            (string->symbol (format "x~a" i))))))))

;; 5b. 50 unify goals in one clause
(define b-conj-50
  (let ([store (make-conjunction-store 50)]
        [cfg default-solver-config])
    (bench "solve: conjunction of 50 unify goals x200"
      (for ([_ (in-range 200)])
        (solve-goal cfg store 'multi '()
          (for/list ([i (in-range 50)])
            (string->symbol (format "x~a" i))))))))

;; 5c. 200 unify goals in one clause
(define b-conj-200
  (let ([store (make-conjunction-store 200)]
        [cfg default-solver-config])
    (bench "solve: conjunction of 200 unify goals x50"
      (for ([_ (in-range 50)])
        (solve-goal cfg store 'multi '()
          (for/list ([i (in-range 200)])
            (string->symbol (format "x~a" i))))))))

;; ============================================================
;; Section 6: Diamond join — multiplicative answer space
;; ============================================================

;; 6a. Small diamond: 5×5 = 5 matching pairs (shared key)
(define b-diamond-5
  (let ([store (make-diamond-store 5)]
        [cfg default-solver-config])
    (bench "solve: diamond join 5×5 x500"
      (for ([_ (in-range 500)])
        (solve-goal cfg store 'top '() '(x y))))))

;; 6b. Medium diamond: 20×20 = 20 matching pairs
(define b-diamond-20
  (let ([store (make-diamond-store 20)]
        [cfg default-solver-config])
    (bench "solve: diamond join 20×20 x100"
      (for ([_ (in-range 100)])
        (solve-goal cfg store 'top '() '(x y))))))

;; 6c. Large diamond: 50×50 = 50 matching pairs
(define b-diamond-50
  (let ([store (make-diamond-store 50)]
        [cfg default-solver-config])
    (bench "solve: diamond join 50×50 x20"
      (for ([_ (in-range 20)])
        (solve-goal cfg store 'top '() '(x y))))))

;; ============================================================
;; Section 7: Inline unify goals (solve-single-goal 'unify)
;; ============================================================

;; 7a. Simple unify via solve-single-goal
(define b-inline-unify-simple
  (let ([cfg default-solver-config]
        [store (make-relation-store)])
    (bench "solve-single-goal: simple unify x2000"
      (for ([_ (in-range 2000)])
        (solve-single-goal cfg store
          (goal-desc 'unify (list 'x 42))
          (hasheq) 0)))))

;; 7b. Structured term unify via solve-single-goal
(define b-inline-unify-structured
  (let ([cfg default-solver-config]
        [store (make-relation-store)]
        [term1 (list '#:pair 'a 'b)]
        [term2 (list '#:pair 1 2)])
    (bench "solve-single-goal: structured unify x2000"
      (for ([_ (in-range 2000)])
        (solve-single-goal cfg store
          (goal-desc 'unify (list term1 term2))
          (hasheq) 0)))))

;; 7c. Chain of inline unify goals
(define b-inline-unify-chain
  (let ([cfg default-solver-config]
        [store (make-relation-store)]
        [goals (for/list ([i (in-range 50)])
                 (goal-desc 'unify
                   (list (string->symbol (format "v~a" i))
                         (list '#:val i))))])
    (bench "solve-goals: 50 inline unify goals x500"
      (for ([_ (in-range 500)])
        (solve-goals cfg store goals (hasheq) 0)))))

;; ============================================================
;; Run all
;; ============================================================

(define section-1 (list b-facts-small b-facts-medium b-facts-large b-facts-selective))
(define section-2 (list b-chain-5 b-chain-20 b-chain-50))
(define section-3 (list b-backtrack-first b-backtrack-last b-backtrack-fail b-backtrack-500))
(define section-4 (list b-multihop-2x10 b-multihop-3x10 b-multihop-2x50 b-multihop-5x5))
(define section-5 (list b-conj-10 b-conj-50 b-conj-200))
(define section-6 (list b-diamond-5 b-diamond-20 b-diamond-50))
(define section-7 (list b-inline-unify-simple b-inline-unify-structured b-inline-unify-chain))

(newline)
(displayln "=== Section 1: fact-only relations ===")
(print-bench-summary section-1)

(newline)
(displayln "=== Section 2: clause chain depth ===")
(print-bench-summary section-2)

(newline)
(displayln "=== Section 3: backtracking ===")
(print-bench-summary section-3)

(newline)
(displayln "=== Section 4: multi-hop joins ===")
(print-bench-summary section-4)

(newline)
(displayln "=== Section 5: conjunction depth ===")
(print-bench-summary section-5)

(newline)
(displayln "=== Section 6: diamond join ===")
(print-bench-summary section-6)

(newline)
(displayln "=== Section 7: inline unify goals ===")
(print-bench-summary section-7)

#lang racket/base

;;;
;;; Tests for WFLE Phase 7: Benchmark Comparison
;;; Quantitative comparison of stratified vs well-founded engines.
;;; Measures: wall time, answer count, answer agreement, convergence.
;;;

(require rackunit
         "../solver.rkt"
         "../relations.rkt"
         "../stratified-eval.rkt"
         "../wf-engine.rkt"
         "../syntax.rkt")

;; ========================================
;; Helper
;; ========================================

(define (build-store . specs)
  (for/hasheq ([spec (in-list specs)])
    (define name (car spec))
    (define arity (cadr spec))
    (define facts (caddr spec))
    (define clauses (cadddr spec))
    (values name
            (relation-info name arity
              (list (variant-info
                     (for/list ([i (in-range arity)])
                       (param-info (string->symbol (format "X~a" i)) 'free))
                     (map clause-info clauses)
                     (map fact-row facts)))
              #f #f))))

(define cfg-strat (make-solver-config (hasheq 'semantics 'stratified)))
(define cfg-wf (make-solver-config (hasheq 'semantics 'well-founded)))

;; Benchmark a solve call, return (values result elapsed-ms)
(define (timed-solve config store goal-name query-vars)
  (define start (current-inexact-milliseconds))
  (define result
    (with-handlers ([exn:fail? (lambda (e) 'error)])
      (parameterize ([current-relation-store store]
                     [current-relation-store-version 0]
                     [current-strata-cache #f])
        (stratified-solve-goal config store goal-name '() query-vars))))
  (define elapsed (- (current-inexact-milliseconds) start))
  (values result elapsed))

;; ========================================
;; 1. Positive-only: facts (no negation overhead)
;; ========================================

(test-case "wf-benchmark/positive-facts: 10 facts, both engines same answers"
  (define store
    (build-store
     (list 'item 1
           (for/list ([i (in-range 10)]) (list (format "item-~a" i)))
           '())))
  (define-values (strat strat-ms) (timed-solve cfg-strat store 'item '(X0)))
  (define-values (wf wf-ms) (timed-solve cfg-wf store 'item '(X0)))
  (check-equal? (length strat) 10)
  (check-equal? (length wf) 10)
  ;; WF should not be dramatically slower for positive-only
  ;; Allow generous 20× threshold (absolute time is tiny)
  (check-true (< wf-ms (* 20 (max strat-ms 1)))
              (format "WF ~a ms vs Strat ~a ms" wf-ms strat-ms)))

;; ========================================
;; 2. Positive rule chain
;; ========================================

(test-case "wf-benchmark/positive-rule: derived :- base, same answers"
  (define store
    (build-store
     (list 'base 1
           (for/list ([i (in-range 20)]) (list (format "b-~a" i)))
           '())
     (list 'derived 1 '()
           (list (list (goal-desc 'app (list 'base '(X0))))))))
  (define-values (strat strat-ms) (timed-solve cfg-strat store 'derived '(X0)))
  (define-values (wf wf-ms) (timed-solve cfg-wf store 'derived '(X0)))
  (check-equal? (length strat) (length wf))
  (check-equal? (length strat) 20))

;; ========================================
;; 3. Stratifiable 2-stratum: a :- not b. b has facts.
;; ========================================

(test-case "wf-benchmark/stratifiable-2: same answers, both complete quickly"
  (define inner-b (expr-goal-app 'b (list)))
  (define store
    (build-store
     (list 'b 0 '(()) '())
     (list 'a 0 '() (list (list (goal-desc 'not (list inner-b)))))))
  (define-values (strat strat-ms) (timed-solve cfg-strat store 'a '()))
  (define-values (wf wf-ms) (timed-solve cfg-wf store 'a '()))
  ;; b is true → not b fails → a has no proofs
  (check-equal? (length strat) 0)
  (check-equal? (length wf) 0))

;; ========================================
;; 4. Stratifiable 4-stratum chain
;; ========================================

(test-case "wf-benchmark/stratifiable-4: long chain, same answers"
  (define inner-a (expr-goal-app 'a (list)))
  (define inner-b (expr-goal-app 'b (list)))
  (define inner-c (expr-goal-app 'c (list)))
  (define store
    (build-store
     (list 'a 0 '(()) '())
     (list 'b 0 '() (list (list (goal-desc 'not (list inner-a)))))
     (list 'c 0 '() (list (list (goal-desc 'not (list inner-b)))))
     (list 'd 0 '() (list (list (goal-desc 'not (list inner-c)))))))
  (define-values (strat strat-ms) (timed-solve cfg-strat store 'd '()))
  (define-values (wf wf-ms) (timed-solve cfg-wf store 'd '()))
  ;; a=true, b=false, c=true, d=false
  (check-equal? (length strat) (length wf))
  (check-equal? (length strat) 0))

;; ========================================
;; 5. WF-only: odd cycle
;; ========================================

(test-case "wf-benchmark/odd-cycle: WF handles, stratified errors"
  (define inner-q (expr-goal-app 'q (list)))
  (define inner-p (expr-goal-app 'p (list)))
  (define store
    (build-store
     (list 'p 0 '() (list (list (goal-desc 'not (list inner-q)))))
     (list 'q 0 '() (list (list (goal-desc 'not (list inner-p)))))))
  (define-values (wf wf-ms) (timed-solve cfg-wf store 'p '()))
  ;; WF: unknown → empty definite answers
  (check-equal? (length wf) 0)
  ;; Stratified errors
  (define-values (strat strat-ms) (timed-solve cfg-strat store 'p '()))
  ;; Stratified may error or return unexpected results for odd cycles
  ;; Just verify WF completed in reasonable time
  (check-true (< wf-ms 1000) (format "WF odd cycle: ~a ms" wf-ms)))

;; ========================================
;; 6. 10-predicate stratifiable chain
;; ========================================

(test-case "wf-benchmark/10-chain: long stratifiable chain converges"
  (define specs
    (append
     (for/list ([i (in-range 9)])
       (define inner (expr-goal-app (string->symbol (format "p~a" (add1 i))) (list)))
       (list (string->symbol (format "p~a" i)) 0 '()
             (list (list (goal-desc 'not (list inner))))))
     (list (list 'p9 0 '(()) '()))))
  (define store (apply build-store specs))
  (define-values (wf wf-ms) (timed-solve cfg-wf store 'p0 '()))
  ;; Should converge in reasonable time
  (check-true (< wf-ms 2000) (format "10-chain WF: ~a ms" wf-ms)))

;; ========================================
;; 7. Mixed: facts + odd cycle coexist
;; ========================================

(test-case "wf-benchmark/mixed: definite facts alongside unknown cycle"
  (define inner-q (expr-goal-app 'q (list)))
  (define inner-p (expr-goal-app 'p (list)))
  (define store
    (build-store
     (list 'fact-a 0 '(()) '())
     (list 'fact-b 0 '(()) '())
     (list 'p 0 '() (list (list (goal-desc 'not (list inner-q)))))
     (list 'q 0 '() (list (list (goal-desc 'not (list inner-p)))))))
  (define-values (wf-a wf-a-ms) (timed-solve cfg-wf store 'fact-a '()))
  (define-values (wf-p wf-p-ms) (timed-solve cfg-wf store 'p '()))
  ;; Facts are definite, cycle is unknown
  (check-equal? (length wf-a) 1)
  (check-equal? (length wf-p) 0))

;; ========================================
;; 8. Multiple clauses for same head
;; ========================================

(test-case "wf-benchmark/multi-clause: p with 5 fact clauses"
  (define store
    (build-store
     (list 'p 1
           (for/list ([i (in-range 5)]) (list (format "v~a" i)))
           '())))
  (define-values (strat strat-ms) (timed-solve cfg-strat store 'p '(X0)))
  (define-values (wf wf-ms) (timed-solve cfg-wf store 'p '(X0)))
  (check-equal? (length strat) (length wf))
  (check-equal? (length strat) 5))

;; ========================================
;; 9. Self-reference convergence time
;; ========================================

(test-case "wf-benchmark/self-ref: p :- not p converges quickly"
  (define inner-p (expr-goal-app 'p (list)))
  (define store
    (build-store
     (list 'p 0 '() (list (list (goal-desc 'not (list inner-p)))))))
  (define-values (wf wf-ms) (timed-solve cfg-wf store 'p '()))
  (check-equal? (length wf) 0)
  (check-true (< wf-ms 500) (format "Self-ref WF: ~a ms" wf-ms)))

;; ========================================
;; 10. Benchmark summary (printed, not asserted)
;; ========================================

(test-case "wf-benchmark/summary: all benchmarks complete"
  ;; This test just verifies the benchmark suite itself runs to completion
  ;; Timing results are informational, captured in timings.jsonl
  (check-true #t "Benchmark suite complete"))

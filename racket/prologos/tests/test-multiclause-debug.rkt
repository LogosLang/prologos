#lang racket/base
(require "../relations.rkt" "../propagator.rkt"
         "../decision-cell.rkt" "../syntax.rkt"
         "../solver.rkt" "../atms.rkt" racket/set)

(define color-pair-rel
  (relation-info 'color-pair 2
    (list (variant-info
           (list (param-info 'c1 'free) (param-info 'c2 'free))
           (list (clause-info (list (goal-desc 'unify (list 'c1 "red"))
                                    (goal-desc 'unify (list 'c2 "blue"))))
                 (clause-info (list (goal-desc 'unify (list 'c1 "blue"))
                                    (goal-desc 'unify (list 'c2 "red"))))
                 (clause-info (list (goal-desc 'unify (list 'c1 "green"))
                                    (goal-desc 'unify (list 'c2 "yellow")))))
           '()))
    #f #f))

(define store (relation-register (make-relation-store) color-pair-rel))
(define config (make-solver-config (hasheq 'strategy 'atms)))

;; Test ATMS
;; Manual step-by-step to trace scope cell state
(define fuel 1000000)
(define net0 (make-prop-network fuel))
(define-values (net-ctx ctx) (make-solver-context net0))
(define-values (net1 query-env) (build-var-env net-ctx '(c1 c2)))
(define-values (net2 answer-cid) (net-new-cell net1 '() (lambda (a b) (if (null? a) b (if (null? b) a (append a b))))))

(define top-goal (goal-desc 'app (list 'color-pair '(c1 c2))))
(define net2a (net-cell-write (net-cell-write net2 relation-store-cell-id store)
                               config-cell-id config))
(define net3 (install-goal-propagator net2a top-goal query-env answer-cid ctx))

;; Check scope cell state
(define c1-ref (hash-ref query-env 'c1))
(define scope-cid (car c1-ref))
(printf "Query scope cell raw BEFORE quiescence:\n  ~a\n" (net-cell-read-raw net3 scope-cid))

(define net4 (run-to-quiescence net3))
(printf "\nQuery scope cell raw AFTER quiescence:\n  ~a\n" (net-cell-read-raw net4 scope-cid))

;; Check if tagged
(define raw (net-cell-read-raw net4 scope-cid))
(when (tagged-cell-value? raw)
  (printf "IS tagged. Base: ~a\n" (tagged-cell-value-base raw))
  (printf "Entries (~a):\n" (length (tagged-cell-value-entries raw)))
  (for ([entry (in-list (tagged-cell-value-entries raw))])
    (printf "  bitmask=~a value=~a\n" (car entry) (cdr entry))))

;; Standard solve for comparison
(define results (solve-goal-propagator config store 'color-pair
                                       '(c1 c2) '(c1 c2)))
(printf "\nATMS results (~a):\n" (length results))
(for ([r (in-list results)])
  (printf "  c1=~a c2=~a\n" (hash-ref r 'c1 '?) (hash-ref r 'c2 '?)))

;; Test DFS for comparison
(define dfs-config (make-solver-config (hasheq 'strategy 'depth-first)))
(define dfs-results (solve-goal dfs-config store 'color-pair
                                '(c1 c2) '(c1 c2)))
(printf "\nDFS results (~a):\n" (length dfs-results))
(for ([r (in-list dfs-results)])
  (printf "  c1=~a c2=~a\n" (hash-ref r 'c1 '?) (hash-ref r 'c2 '?)))

;; Also test existing choice relation (which passes in the test suite)
(define choice-rel
  (relation-info 'choice 1
    (list (variant-info
           (list (param-info 'x 'free))
           (list (clause-info (list (goal-desc 'unify (list 'x 'left))))
                 (clause-info (list (goal-desc 'unify (list 'x 'right)))))
           '()))
    #f #f))

(define choice-store (relation-register (make-relation-store) choice-rel))
(define choice-results (solve-goal-propagator config choice-store 'choice
                                              '(x) '(x)))
(printf "\nChoice ATMS results (~a):\n" (length choice-results))
(for ([r (in-list choice-results)])
  (printf "  x=~a\n" (hash-ref r 'x '?)))

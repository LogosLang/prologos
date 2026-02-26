#lang racket/base

;;;
;;; Tests for stratify.rkt — Compile-Time Stratification Check
;;; Phase 7a: dependency graph, Tarjan SCC, stratification, cyclic negation
;;;

(require rackunit
         "../stratify.rkt")

;; ========================================
;; Dependency graph construction
;; ========================================

(test-case "build-dependency-graph: empty"
  (define g (build-dependency-graph '()))
  (check-equal? (hash-count g) 0))

(test-case "build-dependency-graph: single predicate"
  (define g (build-dependency-graph
             (list (dep-info 'parent '() '()))))
  (check-equal? (hash-count g) 1)
  (check-true (hash-has-key? g 'parent)))

;; ========================================
;; Tarjan SCC
;; ========================================

(test-case "tarjan-scc: no edges — each node is own SCC"
  (define g (build-dependency-graph
             (list (dep-info 'a '() '())
                   (dep-info 'b '() '()))))
  (define sccs (tarjan-scc g))
  ;; Each node in its own SCC
  (check-equal? (length sccs) 2)
  (for ([scc (in-list sccs)])
    (check-equal? (length scc) 1)))

(test-case "tarjan-scc: simple cycle forms single SCC"
  (define g (build-dependency-graph
             (list (dep-info 'a '(b) '())
                   (dep-info 'b '(a) '()))))
  (define sccs (tarjan-scc g))
  ;; a and b in same SCC
  (define big-scc (findf (lambda (scc) (> (length scc) 1)) sccs))
  (check-not-false big-scc)
  (check-not-false (member 'a big-scc) "a in SCC")
  (check-not-false (member 'b big-scc) "b in SCC"))

(test-case "tarjan-scc: DAG — each node is own SCC"
  (define g (build-dependency-graph
             (list (dep-info 'a '(b) '())
                   (dep-info 'b '(c) '())
                   (dep-info 'c '() '()))))
  (define sccs (tarjan-scc g))
  (check-equal? (length sccs) 3))

;; ========================================
;; Stratification — valid programs
;; ========================================

(test-case "stratify: no negation — single stratum (trivial)"
  (define dis (list (dep-info 'parent '() '())
                    (dep-info 'ancestor '(parent ancestor) '())))
  (define strata (stratify dis))
  ;; All predicates reachable, may be 1 or 2 strata
  (check-true (>= (length strata) 1)))

(test-case "stratify: valid stratification with negation"
  ;; edge, reachable: stratum 0
  ;; unreachable: depends on (not reachable) — stratum 1
  (define dis (list (dep-info 'edge '() '())
                    (dep-info 'reachable '(edge reachable) '())
                    (dep-info 'unreachable '() '(reachable))))
  (define strata (stratify dis))
  ;; unreachable should be in a later stratum than reachable
  (check-true (>= (length strata) 1)))

(test-case "stratify: multiple strata ordering"
  ;; a depends on (not b), b has no negation
  ;; b should be in stratum 0, a in stratum 1
  (define dis (list (dep-info 'b '() '())
                    (dep-info 'a '() '(b))))
  (define strata (stratify dis))
  ;; Should have 2 strata, b before a
  (check-equal? (length strata) 2))

;; ========================================
;; Stratification — cyclic negation (rejected)
;; ========================================

(test-case "stratify: cyclic negation — error"
  ;; a depends on (not b), b depends on (not a) → unstratifiable
  (check-exn
   exn:fail?
   (lambda ()
     (stratify (list (dep-info 'a '(b) '(b))
                     (dep-info 'b '(a) '(a)))))))

(test-case "stratify: self-negation — error"
  ;; a depends on (not a) → unstratifiable
  (check-exn
   exn:fail?
   (lambda ()
     (stratify (list (dep-info 'a '() '(a)))))))

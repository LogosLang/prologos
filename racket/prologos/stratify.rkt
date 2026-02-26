#lang racket/base

;;;
;;; stratify.rkt — Compile-Time Stratification Check
;;;
;;; For programs using `not` (negation-as-failure), ensures that the predicate
;;; dependency graph is stratifiable. Cyclic negation is rejected at compile time.
;;;
;;; Key concepts:
;;;   - Build predicate dependency graph (positive and negative edges)
;;;   - Compute SCCs via Tarjan's algorithm
;;;   - Check that no negative edge lies within an SCC
;;;   - Return strata in topological order
;;;
;;; Design reference: docs/tracking/2026-02-24_LOGIC_ENGINE_DESIGN.org §7.7
;;;

(require racket/list)

(provide
 ;; Core analysis
 build-dependency-graph
 tarjan-scc
 stratify
 ;; Structs
 (struct-out dep-info))

;; ========================================
;; Dependency graph
;; ========================================

;; Dependency info for a single predicate
;; name: symbol — predicate name
;; pos-deps: (listof symbol) — predicates called positively
;; neg-deps: (listof symbol) — predicates called via `not`
(struct dep-info (name pos-deps neg-deps) #:transparent)

;; Build a dependency graph from a list of dep-info structs.
;; Returns hasheq: symbol → dep-info
(define (build-dependency-graph dep-infos)
  (for/hasheq ([di (in-list dep-infos)])
    (values (dep-info-name di) di)))

;; ========================================
;; Tarjan's SCC algorithm
;; ========================================

;; Returns a list of SCCs (each SCC = list of symbols), in reverse
;; topological order (leaves first).
(define (tarjan-scc graph)
  (define index-counter (box 0))
  (define stack '())
  (define on-stack (make-hasheq))
  (define indices (make-hasheq))
  (define lowlinks (make-hasheq))
  (define result '())

  ;; All known nodes (from graph keys + all deps)
  (define all-nodes
    (remove-duplicates
     (append (hash-keys graph)
             (apply append
                    (for/list ([(k di) (in-hash graph)])
                      (append (dep-info-pos-deps di)
                              (dep-info-neg-deps di)))))))

  (define (strongconnect v)
    (define idx (unbox index-counter))
    (set-box! index-counter (+ idx 1))
    (hash-set! indices v idx)
    (hash-set! lowlinks v idx)
    (set! stack (cons v stack))
    (hash-set! on-stack v #t)

    ;; All successors (positive + negative)
    (define di (hash-ref graph v #f))
    (define successors
      (if di
          (append (dep-info-pos-deps di) (dep-info-neg-deps di))
          '()))

    (for ([w (in-list successors)])
      (cond
        [(not (hash-has-key? indices w))
         ;; w has not been visited
         (strongconnect w)
         (hash-set! lowlinks v
                    (min (hash-ref lowlinks v)
                         (hash-ref lowlinks w)))]
        [(hash-ref on-stack w #f)
         ;; w is on stack — back edge
         (hash-set! lowlinks v
                    (min (hash-ref lowlinks v)
                         (hash-ref indices w)))]))

    ;; If v is a root, pop SCC
    (when (= (hash-ref lowlinks v) (hash-ref indices v))
      (define scc
        (let loop ([acc '()])
          (define w (car stack))
          (set! stack (cdr stack))
          (hash-set! on-stack w #f)
          (if (eq? w v)
              (cons w acc)
              (loop (cons w acc)))))
      (set! result (cons scc result))))

  ;; Visit all nodes
  (for ([v (in-list all-nodes)])
    (unless (hash-has-key? indices v)
      (strongconnect v)))

  ;; result is in reverse topological order (leaves first)
  result)

;; ========================================
;; Stratification
;; ========================================

;; Stratify a list of dep-info structs.
;; Returns a list of strata (each stratum = list of dep-info), in
;; evaluation order (stratum 0 first).
;;
;; Raises an error if the program is unstratifiable (cyclic negation).
(define (stratify dep-infos)
  (define graph (build-dependency-graph dep-infos))
  (define sccs (tarjan-scc graph))

  ;; Build SCC membership: symbol → SCC index
  (define scc-membership (make-hasheq))
  (for ([scc (in-list sccs)]
        [idx (in-naturals)])
    (for ([name (in-list scc)])
      (hash-set! scc-membership name idx)))

  ;; Check: no negative edge within any SCC
  (for ([di (in-list dep-infos)])
    (define my-scc (hash-ref scc-membership (dep-info-name di) #f))
    (when my-scc
      (for ([neg-dep (in-list (dep-info-neg-deps di))])
        (define dep-scc (hash-ref scc-membership neg-dep #f))
        (when (and dep-scc (= my-scc dep-scc))
          (error 'stratify
                 "Cyclic negation detected: ~a and ~a are mutually recursive through negation. Consider restructuring."
                 (dep-info-name di) neg-dep)))))

  ;; Group dep-infos by stratum (SCC index)
  ;; SCCs are already in reverse topological order, so reverse for eval order
  (define reversed-sccs (reverse sccs))
  (for/list ([scc (in-list reversed-sccs)])
    (filter-map (lambda (name) (hash-ref graph name #f))
                scc)))

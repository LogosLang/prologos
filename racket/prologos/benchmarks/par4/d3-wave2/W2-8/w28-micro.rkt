#lang racket/base
;;; W2-8: the three network builders of benchmarks/micro/bench-parallel-demos.rkt (PAR 2), copied VERBATIM
;;; (lines "max-merge" .. before "Run all demos"), so that probes can run them under injected executors
;;; without running that benchmark (it writes result files, DEFERRED 155). Only change: this header.
(require (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt")
         racket/list)
(provide make-graph-coloring-network random-graph make-constraint-grid-network make-wave-network
         build-micro)
;; name -> (values net cells-vector-or-grid)
(define (build-micro name)
  (random-seed 42)
  (case name
    [("gc500") (let ([n 500]) (make-graph-coloring-network n 4 (random-graph n (min (* n 3) (quotient (* n (- n 1)) 2)))))]
    [("gc200") (let ([n 200]) (make-graph-coloring-network n 4 (random-graph n (min (* n 3) (quotient (* n (- n 1)) 2)))))]
    [("grid12") (make-constraint-grid-network 12)]
    [("grid10") (make-constraint-grid-network 10)]
    [("wave1000") (make-wave-network 1000)]
    [("gc500i") (let ([n 500]) (make-graph-coloring-network/isect n 4 (random-graph n (min (* n 3) (quotient (* n (- n 1)) 2)))))]
    [("grid12i") (make-constraint-grid-network/isect 12)]
    [("grid20i") (make-constraint-grid-network/isect 20)]
    [else (cond [(regexp-match #rx"^grid([0-9]+)i$" name) => (lambda (m) (make-constraint-grid-network/isect (string->number (cadr m))))]
                [else (error 'build-micro "unknown ~a" name)])]))
(define (max-merge old new) (max old new))
(define (set-merge old new)
  (sort (remove-duplicates (append old new)) <))

;; Run quiescence with given executor, return (values result wall-ms)
(define (timed-quiescence net executor-param)
  (collect-garbage 'major)
  (define t0 (current-inexact-monotonic-milliseconds))
  (define result
    (parameterize ([current-parallel-executor executor-param])
      (run-to-quiescence net)))
  (define t1 (current-inexact-monotonic-milliseconds))
  (values result (- t1 t0)))

;; Run N times, return median time
(define (median-time net executor-param runs)
  (define times
    (for/list ([_ (in-range runs)])
      (let-values ([(_ t) (timed-quiescence net executor-param)])
        t)))
  (define sorted (sort times <))
  (list-ref sorted (quotient (length sorted) 2)))

;; ============================================================
;; Demo 1: Graph Coloring
;; ============================================================
;; N vertices, each has a domain cell {1..K}.
;; For each edge (u,v), a constraint propagator narrows:
;;   if u is assigned color c, remove c from v's domain.
;; This is arc-consistency propagation — inherently parallel.

(define (make-graph-coloring-network num-vertices num-colors edges)
  (define net0 (make-prop-network))
  ;; Create domain cells: each vertex has domain {1..K}
  (define initial-domain (for/list ([i (in-range 1 (+ num-colors 1))]) i))
  (define-values (net1 vertex-cells)
    (for/fold ([net net0] [cells '()]) ([v (in-range num-vertices)])
      (let-values ([(net* cid) (net-new-cell net initial-domain set-merge)])
        (values net* (cons cid cells)))))
  (define vertex-cells-vec (list->vector (reverse vertex-cells)))
  ;; For each edge, create a constraint propagator
  ;; When one vertex's domain narrows to a single value,
  ;; remove that value from the neighbor's domain
  (define net2
    (for/fold ([net net1]) ([edge (in-list edges)])
      (define u (car edge))
      (define v (cdr edge))
      (define u-cid (vector-ref vertex-cells-vec u))
      (define v-cid (vector-ref vertex-cells-vec v))
      ;; u → v constraint
      (let-values ([(net* _)
                    (net-add-propagator net (list u-cid) (list v-cid)
                      (lambda (n)
                        (define u-dom (net-cell-read n u-cid))
                        (if (= (length u-dom) 1)
                            ;; u is assigned — remove its color from v
                            (let ([v-dom (net-cell-read n v-cid)]
                                  [assigned (car u-dom)])
                              (define new-v-dom (remove assigned v-dom))
                              (if (equal? new-v-dom v-dom)
                                  n
                                  (net-cell-write n v-cid new-v-dom)))
                            n)))])
        ;; v → u constraint
        (let-values ([(net** _)
                      (net-add-propagator net* (list v-cid) (list u-cid)
                        (lambda (n)
                          (define v-dom (net-cell-read n v-cid))
                          (if (= (length v-dom) 1)
                              (let ([u-dom (net-cell-read n u-cid)]
                                    [assigned (car v-dom)])
                                (define new-u-dom (remove assigned u-dom))
                                (if (equal? new-u-dom u-dom)
                                    n
                                    (net-cell-write n u-cid new-u-dom)))
                              n)))])
          net**))))
  ;; Assign first vertex to color 1 (trigger propagation)
  (define net3 (net-cell-write net2 (vector-ref vertex-cells-vec 0) '(1)))
  (values net3 vertex-cells-vec))

;; Generate a random graph with N vertices and ~E edges
(define (random-graph n target-edges)
  (define edges (make-hash))
  (let loop ([count 0])
    (if (>= count target-edges)
        (hash-keys edges)
        (let ([u (random n)]
              [v (random n)])
          (if (or (= u v) (hash-has-key? edges (cons (min u v) (max u v))))
              (loop count)
              (begin
                (hash-set! edges (cons (min u v) (max u v)) #t)
                (loop (+ count 1))))))))

;; ============================================================
;; Demo 2: Constraint Propagation (Sudoku-like)
;; ============================================================
;; N×N grid, each cell has domain {1..N}.
;; Row and column constraints: no duplicates.
;; Assigning a cell narrows domains in its row and column.

(define (make-constraint-grid-network grid-size)
  (define net0 (make-prop-network))
  (define initial-domain (for/list ([i (in-range 1 (+ grid-size 1))]) i))
  ;; Create N×N cells
  (define-values (net1 cell-grid)
    (for/fold ([net net0] [grid '()]) ([r (in-range grid-size)])
      (define-values (net* row)
        (for/fold ([n net] [cells '()]) ([c (in-range grid-size)])
          (let-values ([(n* cid) (net-new-cell n initial-domain set-merge)])
            (values n* (cons cid cells)))))
      (values net* (cons (list->vector (reverse row)) grid))))
  (define grid-vec (list->vector (reverse cell-grid)))
  ;; Row constraints: for each pair in a row
  (define net2
    (for/fold ([net net1]) ([r (in-range grid-size)])
      (for/fold ([n net]) ([c1 (in-range grid-size)])
        (for/fold ([n2 n]) ([c2 (in-range (+ c1 1) grid-size)])
          (define cid1 (vector-ref (vector-ref grid-vec r) c1))
          (define cid2 (vector-ref (vector-ref grid-vec r) c2))
          (let-values ([(n3 _)
                        (net-add-propagator n2 (list cid1) (list cid2)
                          (lambda (net)
                            (define d1 (net-cell-read net cid1))
                            (if (= (length d1) 1)
                                (let ([d2 (net-cell-read net cid2)]
                                      [val (car d1)])
                                  (define new-d2 (remove val d2))
                                  (if (equal? new-d2 d2) net
                                      (net-cell-write net cid2 new-d2)))
                                net)))])
            (let-values ([(n4 _)
                          (net-add-propagator n3 (list cid2) (list cid1)
                            (lambda (net)
                              (define d2 (net-cell-read net cid2))
                              (if (= (length d2) 1)
                                  (let ([d1 (net-cell-read net cid1)]
                                        [val (car d2)])
                                    (define new-d1 (remove val d1))
                                    (if (equal? new-d1 d1) net
                                        (net-cell-write net cid1 new-d1)))
                                  net)))])
              n4))))))
  ;; Column constraints: same pattern
  (define net3
    (for/fold ([net net2]) ([c (in-range grid-size)])
      (for/fold ([n net]) ([r1 (in-range grid-size)])
        (for/fold ([n2 n]) ([r2 (in-range (+ r1 1) grid-size)])
          (define cid1 (vector-ref (vector-ref grid-vec r1) c))
          (define cid2 (vector-ref (vector-ref grid-vec r2) c))
          (let-values ([(n3 _)
                        (net-add-propagator n2 (list cid1) (list cid2)
                          (lambda (net)
                            (define d1 (net-cell-read net cid1))
                            (if (= (length d1) 1)
                                (let ([d2 (net-cell-read net cid2)]
                                      [val (car d1)])
                                  (define new-d2 (remove val d2))
                                  (if (equal? new-d2 d2) net
                                      (net-cell-write net cid2 new-d2)))
                                net)))])
            (let-values ([(n4 _)
                          (net-add-propagator n3 (list cid2) (list cid1)
                            (lambda (net)
                              (define d2 (net-cell-read net cid2))
                              (if (= (length d2) 1)
                                  (let ([d1 (net-cell-read net cid1)]
                                        [val (car d2)])
                                    (define new-d1 (remove val d1))
                                    (if (equal? new-d1 d1) net
                                        (net-cell-write net cid1 new-d1)))
                                  net)))])
              n4))))))
  ;; Assign first row: cell(0,i) = i+1 (trigger propagation cascade)
  (define net4
    (for/fold ([net net3]) ([c (in-range grid-size)])
      (net-cell-write net
                      (vector-ref (vector-ref grid-vec 0) c)
                      (list (+ c 1)))))
  (values net4 grid-vec))

;; ============================================================
;; Demo 3: Wave Propagation
;; ============================================================
;; 1D array of N cells. A "wave" propagates from cell 0.
;; Each cell propagates max(self, neighbor-1) to its right neighbor.
;; All propagators are independent per round — ideal for parallelism.

(define (make-wave-network size)
  (define net0 (make-prop-network))
  (define-values (net1 cell-ids)
    (for/fold ([net net0] [ids '()]) ([i (in-range size)])
      (let-values ([(net* cid) (net-new-cell net 0 max-merge)])
        (values net* (cons cid ids)))))
  (define cells-vec (list->vector (reverse cell-ids)))
  ;; Propagators: cell[i] → cell[i+1] (propagate value-1)
  (define net2
    (for/fold ([net net1]) ([i (in-range (- size 1))])
      (define src (vector-ref cells-vec i))
      (define dst (vector-ref cells-vec (+ i 1)))
      (let-values ([(net* _)
                    (net-add-propagator net (list src) (list dst)
                      (lambda (n)
                        (define v (net-cell-read n src))
                        (if (> v 0)
                            (net-cell-write n dst (- v 1))
                            n)))])
        net*)))
  ;; Seed: cell 0 = size (wave amplitude)
  (define net3 (net-cell-write net2 (vector-ref cells-vec 0) size))
  (values net3 cells-vec))


;; ---- W2-8 VARIANT (NOT in the repo): the same two builders with the merge replaced by INTERSECTION, the
;; narrowing order's join. With the original union merge (set-merge above) a narrowed domain merges back to the
;; full domain, so no write ever changes a cell: the PAR 2 demos run one round of no-op fires.
(define (isect-merge old new) (sort (filter (lambda (x) (memv x new)) old) <))
(define (make-graph-coloring-network/isect num-vertices num-colors edges)
  (define net0 (make-prop-network))
  ;; Create domain cells: each vertex has domain {1..K}
  (define initial-domain (for/list ([i (in-range 1 (+ num-colors 1))]) i))
  (define-values (net1 vertex-cells)
    (for/fold ([net net0] [cells '()]) ([v (in-range num-vertices)])
      (let-values ([(net* cid) (net-new-cell net initial-domain isect-merge)])
        (values net* (cons cid cells)))))
  (define vertex-cells-vec (list->vector (reverse vertex-cells)))
  ;; For each edge, create a constraint propagator
  ;; When one vertex's domain narrows to a single value,
  ;; remove that value from the neighbor's domain
  (define net2
    (for/fold ([net net1]) ([edge (in-list edges)])
      (define u (car edge))
      (define v (cdr edge))
      (define u-cid (vector-ref vertex-cells-vec u))
      (define v-cid (vector-ref vertex-cells-vec v))
      ;; u → v constraint
      (let-values ([(net* _)
                    (net-add-propagator net (list u-cid) (list v-cid)
                      (lambda (n)
                        (define u-dom (net-cell-read n u-cid))
                        (if (= (length u-dom) 1)
                            ;; u is assigned — remove its color from v
                            (let ([v-dom (net-cell-read n v-cid)]
                                  [assigned (car u-dom)])
                              (define new-v-dom (remove assigned v-dom))
                              (if (equal? new-v-dom v-dom)
                                  n
                                  (net-cell-write n v-cid new-v-dom)))
                            n)))])
        ;; v → u constraint
        (let-values ([(net** _)
                      (net-add-propagator net* (list v-cid) (list u-cid)
                        (lambda (n)
                          (define v-dom (net-cell-read n v-cid))
                          (if (= (length v-dom) 1)
                              (let ([u-dom (net-cell-read n u-cid)]
                                    [assigned (car v-dom)])
                                (define new-u-dom (remove assigned u-dom))
                                (if (equal? new-u-dom u-dom)
                                    n
                                    (net-cell-write n u-cid new-u-dom)))
                              n)))])
          net**))))
  ;; Assign first vertex to color 1 (trigger propagation)
  (define net3 (net-cell-write net2 (vector-ref vertex-cells-vec 0) '(1)))
  (values net3 vertex-cells-vec))

;; Generate a random graph with N vertices and ~E edges
(define (make-constraint-grid-network/isect grid-size)
  (define net0 (make-prop-network))
  (define initial-domain (for/list ([i (in-range 1 (+ grid-size 1))]) i))
  ;; Create N×N cells
  (define-values (net1 cell-grid)
    (for/fold ([net net0] [grid '()]) ([r (in-range grid-size)])
      (define-values (net* row)
        (for/fold ([n net] [cells '()]) ([c (in-range grid-size)])
          (let-values ([(n* cid) (net-new-cell n initial-domain isect-merge)])
            (values n* (cons cid cells)))))
      (values net* (cons (list->vector (reverse row)) grid))))
  (define grid-vec (list->vector (reverse cell-grid)))
  ;; Row constraints: for each pair in a row
  (define net2
    (for/fold ([net net1]) ([r (in-range grid-size)])
      (for/fold ([n net]) ([c1 (in-range grid-size)])
        (for/fold ([n2 n]) ([c2 (in-range (+ c1 1) grid-size)])
          (define cid1 (vector-ref (vector-ref grid-vec r) c1))
          (define cid2 (vector-ref (vector-ref grid-vec r) c2))
          (let-values ([(n3 _)
                        (net-add-propagator n2 (list cid1) (list cid2)
                          (lambda (net)
                            (define d1 (net-cell-read net cid1))
                            (if (= (length d1) 1)
                                (let ([d2 (net-cell-read net cid2)]
                                      [val (car d1)])
                                  (define new-d2 (remove val d2))
                                  (if (equal? new-d2 d2) net
                                      (net-cell-write net cid2 new-d2)))
                                net)))])
            (let-values ([(n4 _)
                          (net-add-propagator n3 (list cid2) (list cid1)
                            (lambda (net)
                              (define d2 (net-cell-read net cid2))
                              (if (= (length d2) 1)
                                  (let ([d1 (net-cell-read net cid1)]
                                        [val (car d2)])
                                    (define new-d1 (remove val d1))
                                    (if (equal? new-d1 d1) net
                                        (net-cell-write net cid1 new-d1)))
                                  net)))])
              n4))))))
  ;; Column constraints: same pattern
  (define net3
    (for/fold ([net net2]) ([c (in-range grid-size)])
      (for/fold ([n net]) ([r1 (in-range grid-size)])
        (for/fold ([n2 n]) ([r2 (in-range (+ r1 1) grid-size)])
          (define cid1 (vector-ref (vector-ref grid-vec r1) c))
          (define cid2 (vector-ref (vector-ref grid-vec r2) c))
          (let-values ([(n3 _)
                        (net-add-propagator n2 (list cid1) (list cid2)
                          (lambda (net)
                            (define d1 (net-cell-read net cid1))
                            (if (= (length d1) 1)
                                (let ([d2 (net-cell-read net cid2)]
                                      [val (car d1)])
                                  (define new-d2 (remove val d2))
                                  (if (equal? new-d2 d2) net
                                      (net-cell-write net cid2 new-d2)))
                                net)))])
            (let-values ([(n4 _)
                          (net-add-propagator n3 (list cid2) (list cid1)
                            (lambda (net)
                              (define d2 (net-cell-read net cid2))
                              (if (= (length d2) 1)
                                  (let ([d1 (net-cell-read net cid1)]
                                        [val (car d2)])
                                    (define new-d1 (remove val d1))
                                    (if (equal? new-d1 d1) net
                                        (net-cell-write net cid1 new-d1)))
                                  net)))])
              n4))))))
  ;; Assign first row: cell(0,i) = i+1 (trigger propagation cascade)
  (define net4
    (for/fold ([net net3]) ([c (in-range grid-size)])
      (net-cell-write net
                      (vector-ref (vector-ref grid-vec 0) c)
                      (list (+ c 1)))))
  (values net4 grid-vec))


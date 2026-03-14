#lang racket/base

;;;
;;; Tests for WFLE Phase 3: Well-Founded Propagator Patterns
;;; Verifies: fact/negation/positive-clause/aggregate-upper propagators,
;;;           clause/program compilation, classic WF examples.
;;;

(require rackunit
         racket/list
         racket/set
         "../propagator.rkt"
         "../bilattice.rkt"
         "../wf-propagators.rkt")

;; Helper: create a fresh network and bilattice-var
(define (fresh-bvar [net (make-prop-network)])
  (bilattice-new-var net bool-lattice))

;; Helper: compile program, run to quiescence, return atom-map reader
(define (run-program program)
  (define net (make-prop-network))
  (define-values (net1 atom-map) (wf-compile-program net program))
  (define net2 (run-to-quiescence net1))
  (values net2 atom-map))

(define (read-atom net atom-map name)
  (bilattice-read-bool net (hash-ref atom-map name)))

;; ========================================
;; 1. Positive clause propagator
;; ========================================

(test-case "wf/positive-single-body-true"
  ;; p :- q. With q true → p true
  (define net (make-prop-network))
  (define-values (net1 p) (bilattice-new-var net bool-lattice))
  (define-values (net2 q) (bilattice-new-var net1 bool-lattice))
  (define net3 (wf-wire-positive-clause net2 p (list q)))
  ;; Set q true
  (define net4 (bilattice-lower-write net3 q #t))
  (define net5 (run-to-quiescence net4))
  ;; p's lower should be true (head certainly true)
  (check-equal? (net-cell-read net5 (bilattice-var-lower-cid p)) #t))

(test-case "wf/positive-single-body-unknown"
  ;; p :- q. With q unknown → p's lower stays false
  (define net (make-prop-network))
  (define-values (net1 p) (bilattice-new-var net bool-lattice))
  (define-values (net2 q) (bilattice-new-var net1 bool-lattice))
  (define net3 (wf-wire-positive-clause net2 p (list q)))
  (define net4 (run-to-quiescence net3))
  (check-equal? (net-cell-read net4 (bilattice-var-lower-cid p)) #f))

(test-case "wf/positive-multi-body-all-true"
  ;; p :- q, r. Both true → p true
  (define net (make-prop-network))
  (define-values (net1 p) (bilattice-new-var net bool-lattice))
  (define-values (net2 q) (bilattice-new-var net1 bool-lattice))
  (define-values (net3 r) (bilattice-new-var net2 bool-lattice))
  (define net4 (wf-wire-positive-clause net3 p (list q r)))
  (define net5 (bilattice-lower-write net4 q #t))
  (define net6 (bilattice-lower-write net5 r #t))
  (define net7 (run-to-quiescence net6))
  (check-equal? (net-cell-read net7 (bilattice-var-lower-cid p)) #t))

(test-case "wf/positive-multi-body-one-unknown"
  ;; p :- q, r. Only q true → p's lower stays false
  (define net (make-prop-network))
  (define-values (net1 p) (bilattice-new-var net bool-lattice))
  (define-values (net2 q) (bilattice-new-var net1 bool-lattice))
  (define-values (net3 r) (bilattice-new-var net2 bool-lattice))
  (define net4 (wf-wire-positive-clause net3 p (list q r)))
  (define net5 (bilattice-lower-write net4 q #t))
  (define net6 (run-to-quiescence net5))
  (check-equal? (net-cell-read net6 (bilattice-var-lower-cid p)) #f))

;; ========================================
;; 2. Negative literal propagator
;; ========================================

(test-case "wf/negation-q-true"
  ;; not q with q true → not-q false
  (define net (make-prop-network))
  (define-values (net1 q) (bilattice-new-var net bool-lattice))
  (define net2 (bilattice-lower-write net1 q #t))  ;; q = true
  (define-values (net3 neg-q) (wf-wire-negation net2 q))
  (define net4 (run-to-quiescence net3))
  (check-equal? (bilattice-read-bool net4 neg-q) 'false))

(test-case "wf/negation-q-false"
  ;; not q with q false → not-q true
  (define net (make-prop-network))
  (define-values (net1 q) (bilattice-new-var net bool-lattice))
  (define net2 (bilattice-upper-write net1 q #f))  ;; q = false
  (define-values (net3 neg-q) (wf-wire-negation net2 q))
  (define net4 (run-to-quiescence net3))
  (check-equal? (bilattice-read-bool net4 neg-q) 'true))

(test-case "wf/negation-q-unknown"
  ;; not q with q unknown → not-q unknown
  (define net (make-prop-network))
  (define-values (net1 q) (bilattice-new-var net bool-lattice))
  ;; q stays unknown (fresh)
  (define-values (net2 neg-q) (wf-wire-negation net1 q))
  (define net3 (run-to-quiescence net2))
  (check-equal? (bilattice-read-bool net3 neg-q) 'unknown))

;; ========================================
;; 3. Fact propagator
;; ========================================

(test-case "wf/fact-sets-lower-true"
  (define net (make-prop-network))
  (define-values (net1 p) (bilattice-new-var net bool-lattice))
  (define net2 (wf-wire-fact net1 p))
  (check-equal? (bilattice-read-bool net2 p) 'true))

;; ========================================
;; 4. Aggregate upper bound
;; ========================================

(test-case "wf/aggregate-single-infeasible"
  ;; One clause for p, body infeasible → upper-p false
  (define net (make-prop-network))
  (define-values (net1 p) (bilattice-new-var net bool-lattice))
  (define-values (net2 q) (bilattice-new-var net1 bool-lattice))
  ;; Clause body check: is q's upper true?
  (define body-fn (lambda (n) (net-cell-read n (bilattice-var-upper-cid q))))
  ;; Make q's upper false (q is definitely false)
  (define net3 (bilattice-upper-write net2 q #f))
  (define net4 (wf-wire-aggregate-upper net3 p
                 (list (bilattice-var-upper-cid q))
                 (list body-fn)))
  (define net5 (run-to-quiescence net4))
  (check-equal? (net-cell-read net5 (bilattice-var-upper-cid p)) #f))

(test-case "wf/aggregate-two-clauses-one-feasible"
  ;; Two clauses for p, one feasible → upper-p stays true
  (define net (make-prop-network))
  (define-values (net1 p) (bilattice-new-var net bool-lattice))
  (define-values (net2 q) (bilattice-new-var net1 bool-lattice))
  (define-values (net3 r) (bilattice-new-var net2 bool-lattice))
  ;; Make q false, r stays unknown (feasible)
  (define net4 (bilattice-upper-write net3 q #f))
  (define fn1 (lambda (n) (net-cell-read n (bilattice-var-upper-cid q))))
  (define fn2 (lambda (n) (net-cell-read n (bilattice-var-upper-cid r))))
  (define net5 (wf-wire-aggregate-upper net4 p
                 (list (bilattice-var-upper-cid q) (bilattice-var-upper-cid r))
                 (list fn1 fn2)))
  (define net6 (run-to-quiescence net5))
  ;; r is still feasible → upper-p stays true
  (check-equal? (net-cell-read net6 (bilattice-var-upper-cid p)) #t))

(test-case "wf/aggregate-two-clauses-both-infeasible"
  ;; Two clauses for p, both infeasible → upper-p false
  (define net (make-prop-network))
  (define-values (net1 p) (bilattice-new-var net bool-lattice))
  (define-values (net2 q) (bilattice-new-var net1 bool-lattice))
  (define-values (net3 r) (bilattice-new-var net2 bool-lattice))
  (define net4 (bilattice-upper-write net3 q #f))
  (define net5 (bilattice-upper-write net4 r #f))
  (define fn1 (lambda (n) (net-cell-read n (bilattice-var-upper-cid q))))
  (define fn2 (lambda (n) (net-cell-read n (bilattice-var-upper-cid r))))
  (define net6 (wf-wire-aggregate-upper net5 p
                 (list (bilattice-var-upper-cid q) (bilattice-var-upper-cid r))
                 (list fn1 fn2)))
  (define net7 (run-to-quiescence net6))
  (check-equal? (net-cell-read net7 (bilattice-var-upper-cid p)) #f))

;; ========================================
;; 5. Clause compilation
;; ========================================

(test-case "wf/compile-clause-positive"
  ;; p :- q (positive body)
  (define net (make-prop-network))
  (define-values (net1 p) (bilattice-new-var net bool-lattice))
  (define-values (net2 q) (bilattice-new-var net1 bool-lattice))
  (define-values (net3 body-fn body-bvars)
    (wf-compile-clause net2 p (list (cons 'pos q))))
  ;; body-fn checks q's upper
  (check-true (body-fn (bilattice-lower-write net3 q #t)))
  ;; body-bvars should contain q (or its equivalent)
  (check-equal? (length body-bvars) 1))

(test-case "wf/compile-clause-negative"
  ;; p :- not q
  (define net (make-prop-network))
  (define-values (net1 p) (bilattice-new-var net bool-lattice))
  (define-values (net2 q) (bilattice-new-var net1 bool-lattice))
  (define-values (net3 body-fn body-bvars)
    (wf-compile-clause net2 p (list (cons 'neg q))))
  ;; body-bvars should contain neg-q (not q itself)
  (check-equal? (length body-bvars) 1)
  ;; neg-q is different from q
  (check-false (equal? (car body-bvars) q)))

(test-case "wf/compile-clause-mixed"
  ;; p :- q, not r
  (define net (make-prop-network))
  (define-values (net1 p) (bilattice-new-var net bool-lattice))
  (define-values (net2 q) (bilattice-new-var net1 bool-lattice))
  (define-values (net3 r) (bilattice-new-var net2 bool-lattice))
  (define-values (net4 body-fn body-bvars)
    (wf-compile-clause net3 p (list (cons 'pos q) (cons 'neg r))))
  (check-equal? (length body-bvars) 2))

;; ========================================
;; 6. Program compilation — classic examples
;; ========================================

(test-case "wf/odd-cycle-p-not-q"
  ;; p :- not q. q :- not p. → both unknown
  (define-values (net atom-map)
    (run-program '((p (neg . q)) (q (neg . p)))))
  (check-equal? (read-atom net atom-map 'p) 'unknown)
  (check-equal? (read-atom net atom-map 'q) 'unknown))

(test-case "wf/stratifiable-a-not-b-not-c"
  ;; a :- not b. b :- not c. c. → a=true, b=false, c=true
  (define-values (net atom-map)
    (run-program '((a (neg . b)) (b (neg . c)) (c))))
  (check-equal? (read-atom net atom-map 'c) 'true)
  (check-equal? (read-atom net atom-map 'b) 'false)
  (check-equal? (read-atom net atom-map 'a) 'true))

(test-case "wf/win-lose-game"
  ;; Ground instances of win(X) :- move(X,Y), not win(Y).
  ;; move(a,b). move(b,c). move(c,d).
  ;; win: d has no move → win(d)=false. win(c)=true (move c→d, not win(d)=true).
  ;; win(b)=false (move b→c, not win(c)=false). win(a)=true.
  ;;
  ;; Encoded as ground propositions:
  ;; move-ab. move-bc. move-cd.
  ;; win-a :- move-ab, not win-b.
  ;; win-b :- move-bc, not win-c.
  ;; win-c :- move-cd, not win-d.
  ;; (win-d has no clauses)
  (define-values (net atom-map)
    (run-program
     '((move-ab) (move-bc) (move-cd)
       (win-a (pos . move-ab) (neg . win-b))
       (win-b (pos . move-bc) (neg . win-c))
       (win-c (pos . move-cd) (neg . win-d)))))
  (check-equal? (read-atom net atom-map 'win-d) 'false)
  (check-equal? (read-atom net atom-map 'win-c) 'true)
  (check-equal? (read-atom net atom-map 'win-b) 'false)
  (check-equal? (read-atom net atom-map 'win-a) 'true))

(test-case "wf/even-odd-positive"
  ;; even(0). even(s(N)) :- odd(N). odd(s(N)) :- even(N).
  ;; Ground instances: even0. even1 :- odd0. odd1 :- even0. even2 :- odd1. odd0 :- ???
  ;; Actually: even0 is a fact. odd0 has no clause → false.
  ;; even1 :- odd0 → false. odd1 :- even0 → true. even2 :- odd1 → true.
  (define-values (net atom-map)
    (run-program
     '((even0)
       (even1 (pos . odd0))
       (odd1 (pos . even0))
       (even2 (pos . odd1)))))
  (check-equal? (read-atom net atom-map 'even0) 'true)
  (check-equal? (read-atom net atom-map 'odd0) 'false)
  (check-equal? (read-atom net atom-map 'even1) 'false)
  (check-equal? (read-atom net atom-map 'odd1) 'true)
  (check-equal? (read-atom net atom-map 'even2) 'true))

;; ========================================
;; 7. Edge cases
;; ========================================

(test-case "wf/no-clauses-atom-false"
  ;; Atom with no clauses → false
  ;; p :- q. (q has no clauses)
  (define-values (net atom-map)
    (run-program '((p (pos . q)))))
  (check-equal? (read-atom net atom-map 'q) 'false)
  (check-equal? (read-atom net atom-map 'p) 'false))

(test-case "wf/self-reference-positive"
  ;; p :- p. → p = unknown (lower can't rise without evidence, upper can't
  ;; fall because the clause IS feasible as long as upper-p is true)
  (define-values (net atom-map)
    (run-program '((p (pos . p)))))
  ;; p's lower stays false (no base case), upper stays true (clause is self-feasible)
  ;; Result: unknown
  (check-equal? (read-atom net atom-map 'p) 'unknown))

(test-case "wf/self-reference-negative"
  ;; p :- not p. → p = unknown (the classic paradox)
  (define-values (net atom-map)
    (run-program '((p (neg . p)))))
  (check-equal? (read-atom net atom-map 'p) 'unknown))

(test-case "wf/empty-program"
  (define net (make-prop-network))
  (define-values (net1 atom-map) (wf-compile-program net '()))
  (check-equal? (hash-count atom-map) 0))

(test-case "wf/long-negation-chain"
  ;; a :- not b. b :- not c. c :- not d. d :- not e. e.
  ;; e=true, d=false, c=true, b=false, a=true
  (define-values (net atom-map)
    (run-program
     '((a (neg . b)) (b (neg . c)) (c (neg . d)) (d (neg . e)) (e))))
  (check-equal? (read-atom net atom-map 'e) 'true)
  (check-equal? (read-atom net atom-map 'd) 'false)
  (check-equal? (read-atom net atom-map 'c) 'true)
  (check-equal? (read-atom net atom-map 'b) 'false)
  (check-equal? (read-atom net atom-map 'a) 'true))

(test-case "wf/multiple-clauses-mixed"
  ;; p :- q.  p :- not r.  q.  r.
  ;; q=true → p=true via first clause. r=true → not-r=false, but doesn't matter.
  (define-values (net atom-map)
    (run-program '((p (pos . q)) (p (neg . r)) (q) (r))))
  (check-equal? (read-atom net atom-map 'p) 'true)
  (check-equal? (read-atom net atom-map 'q) 'true)
  (check-equal? (read-atom net atom-map 'r) 'true))

(test-case "wf/nixon-diamond"
  ;; pacifist :- quaker, not hawk.
  ;; hawk :- republican, not pacifist.
  ;; quaker. republican.
  ;; → both pacifist and hawk are unknown (Nixon diamond)
  (define-values (net atom-map)
    (run-program
     '((pacifist (pos . quaker) (neg . hawk))
       (hawk (pos . republican) (neg . pacifist))
       (quaker) (republican))))
  (check-equal? (read-atom net atom-map 'quaker) 'true)
  (check-equal? (read-atom net atom-map 'republican) 'true)
  (check-equal? (read-atom net atom-map 'pacifist) 'unknown)
  (check-equal? (read-atom net atom-map 'hawk) 'unknown))

(test-case "wf/bsp-convergence"
  ;; Same odd-cycle example but with BSP scheduler
  (define net (make-prop-network))
  (define-values (net1 atom-map)
    (wf-compile-program net '((p (neg . q)) (q (neg . p)))))
  (define net2 (run-to-quiescence-bsp net1))
  (check-equal? (read-atom net2 atom-map 'p) 'unknown)
  (check-equal? (read-atom net2 atom-map 'q) 'unknown))

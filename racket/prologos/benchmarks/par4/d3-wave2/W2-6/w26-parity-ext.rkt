#lang racket/base
;; W2-6 (PAR 4 D.3 wave 2) — power check for the regression instrument.
;; A SCRATCH COPY of the harness of tests/test-solver-parity.rkt (DFS<->ATMS parity, 15 cases at HEAD, none with a
;; conflicting binding), extended with DEFERRED 177's three rows, its control, and the three shapes found by W2-6's
;; real-program probe (w26-crosssite.prologos): R5 cross-site var-var unify, R6 base write after the branch, R7.
;; Question: would the existing parity harness catch 177 if the rows were in it? (It must FAIL them at HEAD.)
;; Run: racket w26-parity-ext.rkt
(require racket/set
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/solver.rkt")
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/relations.rkt")
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/stratified-eval.rkt")
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/syntax.rkt"))

;; --- harness copied from tests/test-solver-parity.rkt:28-82 (unchanged logic) ---
(define (build-store . specs)
  (for/hasheq ([spec (in-list specs)])
    (define name (car spec)) (define arity (cadr spec)) (define facts (caddr spec)) (define clauses (cadddr spec))
    (values name (relation-info name arity
                   (list (variant-info (for/list ([i (in-range arity)]) (param-info (string->symbol (format "X~a" i)) 'free))
                                       (map clause-info clauses) (map fact-row facts)))
                   #f #f))))
(define cfg-dfs (make-solver-config (hasheq 'strategy 'depth-first)))
(define cfg-atms (make-solver-config (hasheq 'strategy 'atms)))
(define (parity-query store goal-name query-vars [goal-args '()])
  (parameterize ([current-relation-store store] [current-relation-store-version 0] [current-strata-cache #f])
    (define dfs (parameterize ([current-solver-strategy-override 'depth-first])
                  (stratified-solve-goal cfg-dfs store goal-name goal-args query-vars)))
    (define atms (parameterize ([current-solver-strategy-override 'atms])
                   (stratified-solve-goal cfg-atms store goal-name goal-args query-vars)))
    (values dfs atms)))
(define (normalize-result result query-vars)
  (for/hasheq ([(k v) (in-hash result)]) (values k (if (and (symbol? v) (not (memq v query-vars))) k v))))
(define (parity-row label store goal-name query-vars [goal-args '()])
  (define-values (dfs atms)
    (with-handlers ([exn:fail? (λ (e) (values (list 'ERROR (exn-message e)) (list 'ERROR)))])
      (parity-query store goal-name query-vars goal-args)))
  (define (norm l) (if (and (pair? l) (eq? (car l) 'ERROR)) l (list->set (map (λ (r) (normalize-result r query-vars)) l))))
  (define ok (equal? (norm dfs) (norm atms)))
  (printf "  ~a ~a\n      DFS  ~s\n      ATMS ~s\n" (if ok "PASS  " "FAIL  ") label dfs atms)
  ok)

(define (u a b) (goal-desc 'unify (list a b)))
(define (app r args) (goal-desc 'app (list r args)))
(define pick (list 'pick 1 '() (list (list (u 'X0 "a")) (list (u 'X0 "b")))))

(printf "== CONTROL rows (shapes already in test-solver-parity.rkt; must PASS)\n")
(define c1 (parity-row "fact-multi-arg (copy of :92)" (build-store (list 'edge 2 '(("a" "b") ("b" "c") ("c" "a")) '())) 'edge '(X0 X1)))
(define c2 (parity-row "multi-clause (copy of :118)"
                       (build-store (list 'a 1 '(("x")) '()) (list 'b 1 '(("y")) '())
                                    (list 'either 1 '() (list (list (app 'a '(X0))) (list (app 'b '(X0))))))
                       'either '(X0)))
(define c3 (parity-row "pick alone (two clauses)" (build-store pick) 'pick '(X0)))

(printf "== DEFERRED 177 rows + W2-6 shapes (expected to FAIL at HEAD if the harness has power)\n")
(define rows
  (list
   (parity-row "177 row 1  two: (= x a) (= x b) in one clause"
               (build-store (list 'two 1 '() (list (list (u 'X0 "a") (u 'X0 "b"))))) 'two '(X0))
   (parity-row "177 row 2  q3: (= x a) (pick x)"
               (build-store pick (list 'q3 1 '() (list (list (u 'X0 "a") (app 'pick '(X0)))))) 'q3 '(X0))
   (parity-row "177 row 3  clash: (= x a) (= y b) (= x y)"
               (build-store (list 'clash 2 '() (list (list (u 'X0 "a") (u 'X1 "b") (u 'X0 'X1))))) 'clash '(X0 X1))
   (parity-row "177 control agree: (= x a) (= y a) (= x y)"
               (build-store (list 'agree 2 '() (list (list (u 'X0 "a") (u 'X1 "a") (u 'X0 'X1))))) 'agree '(X0 X1))
   (parity-row "R5 cross: (pick x) (pick y) (= x y)"
               (build-store pick (list 'cross 2 '() (list (list (app 'pick '(X0)) (app 'pick '(X1)) (u 'X0 'X1))))) 'cross '(X0 X1))
   (parity-row "R6 q3rev: (pick x) (= x b)"
               (build-store pick (list 'q3rev 1 '() (list (list (app 'pick '(X0)) (u 'X0 "b"))))) 'q3rev '(X0))
   (parity-row "R7: (pick x) (= y a) (= x y)"
               (build-store pick (list 'r7 2 '() (list (list (app 'pick '(X0)) (u 'X1 "a") (u 'X0 'X1))))) 'r7 '(X0 X1))))
(printf "SUMMARY controls pass ~a/3 ; extended rows pass ~a/~a\n"
        (length (filter values (list c1 c2 c3))) (length (filter values rows)) (length rows))

#lang racket/base

;;;
;;; Tests for PPN Track 0: Parse Domain Lattices
;;;

(require rackunit
         racket/set
         "../parse-lattice.rkt")

;; ============================================================
;; Token Lattice Tests
;; ============================================================

(test-case "token: bot merge with value = value"
  (define t (make-token 'identifier "foo" 0 3 0))
  (check-equal? (token-lattice-merge token-bot t) t)
  (check-equal? (token-lattice-merge t token-bot) t))

(test-case "token: same value merge = identity (idempotent)"
  (define t (make-token 'identifier "foo" 0 3 0))
  (check-eq? (token-lattice-merge t t) t))

(test-case "token: different values = contradiction (top)"
  (define t1 (make-token 'identifier "def" 0 3 0))
  (define t2 (make-token 'keyword "def" 0 3 0))
  (check-equal? (token-lattice-merge t1 t2) token-top))

(test-case "token: top absorbs everything"
  (define t (make-token 'number "42" 5 7 0))
  (check-equal? (token-lattice-merge token-top t) token-top)
  (check-equal? (token-lattice-merge t token-top) token-top)
  (check-equal? (token-lattice-merge token-top token-bot) token-top))

(test-case "token: bot is bot"
  (check-true (token-bot? token-bot))
  (check-false (token-bot? (make-token 'identifier "x" 0 1 0))))

(test-case "token: contradicts detects top"
  (check-true (token-contradicts? token-top))
  (check-false (token-contradicts? token-bot))
  (check-false (token-contradicts? (make-token 'number "42" 0 2 0))))

(test-case "token: indent fields preserved"
  (define t (make-token 'identifier "x" 10 11 4 'indent))
  (check-equal? (token-cell-value-indent-level t) 4)
  (check-equal? (token-cell-value-indent-delta t) 'indent))

;; ============================================================
;; Surface (Parse) Lattice Tests
;; ============================================================

(test-case "parse: bot is empty derivation set"
  (check-true (parse-bot? parse-bot))
  (check-true (set-empty? (parse-cell-value-derivations parse-bot))))

(test-case "parse: merge bot with value = value"
  (define item (make-parse-item 'S 0 0 5))
  (define node (make-derivation-node item '()))
  (define pcv (parse-cell-value (seteq node)))
  (check-equal? (parse-lattice-merge parse-bot pcv) pcv)
  (check-equal? (parse-lattice-merge pcv parse-bot) pcv))

(test-case "parse: merge two derivation sets = union"
  (define item1 (make-parse-item 'S 0 0 5))
  (define item2 (make-parse-item 'S 1 0 5))
  (define n1 (make-derivation-node item1 '()))
  (define n2 (make-derivation-node item2 '()))
  (define pcv1 (parse-cell-value (seteq n1)))
  (define pcv2 (parse-cell-value (seteq n2)))
  (define merged (parse-lattice-merge pcv1 pcv2))
  (check-equal? (set-count (parse-cell-value-derivations merged)) 2))

(test-case "parse: merge with same derivations = identity"
  (define item (make-parse-item 'NP 2 3 7))
  (define node (make-derivation-node item '()))
  (define pcv (parse-cell-value (seteq node)))
  (check-eq? (parse-lattice-merge pcv pcv) pcv))

(test-case "parse: top absorbs"
  (define pcv (parse-cell-value (seteq (make-derivation-node
                                        (make-parse-item 'S 0 0 1) '()))))
  (check-equal? (parse-lattice-merge parse-top pcv) parse-top)
  (check-equal? (parse-lattice-merge pcv parse-top) parse-top))

(test-case "parse: derivation-node carries provenance (children)"
  (define child1 (make-derivation-node (make-parse-item 'NP 2 0 3) '()))
  (define child2 (make-derivation-node (make-parse-item 'VP 2 3 7) '()))
  (define parent (make-derivation-node (make-parse-item 'S 2 0 7)
                                       (list child1 child2)))
  (check-equal? (length (derivation-node-children parent)) 2))

(test-case "parse: derivation-node carries ATMS assumption"
  (define node (make-derivation-node (make-parse-item 'S 0 0 5) '() 'assumption-42))
  (check-equal? (derivation-node-assumption-id node) 'assumption-42))

(test-case "parse: derivation-node carries tropical cost"
  (define node (make-derivation-node (make-parse-item 'S 0 0 5) '() #f 3.5))
  (check-equal? (derivation-node-cost node) 3.5))

(test-case "parse: identity preservation on no-change merge"
  (define n1 (make-derivation-node (make-parse-item 'A 0 0 1) '()))
  (define n2 (make-derivation-node (make-parse-item 'B 0 0 1) '()))
  (define pcv-ab (parse-cell-value (seteq n1 n2)))
  (define pcv-a  (parse-cell-value (seteq n1)))
  ;; Merging subset into superset returns superset (identity)
  (check-eq? (parse-lattice-merge pcv-ab pcv-a) pcv-ab))

;; ============================================================
;; Demand Lattice Tests
;; ============================================================

(test-case "demand: bot is empty set"
  (check-true (demand-bot? demand-bot))
  (check-true (set-empty? (demand-cell-value-demands demand-bot))))

(test-case "demand: merge accumulates demands"
  (define d1 (make-demand 'token 5 'any 'S-elaborate))
  (define d2 (make-demand 'type 'cell-100 'constructor 'S-elaborate))
  (define dcv1 (demand-cell-value (seteq d1)))
  (define dcv2 (demand-cell-value (seteq d2)))
  (define merged (demand-lattice-merge dcv1 dcv2))
  (check-equal? (set-count (demand-cell-value-demands merged)) 2))

(test-case "demand: merge with bot = value"
  (define d (make-demand 'surface '(0 . 5) 'complete-item 'S-elaborate))
  (define dcv (demand-cell-value (seteq d)))
  (check-equal? (demand-lattice-merge demand-bot dcv) dcv)
  (check-equal? (demand-lattice-merge dcv demand-bot) dcv))

(test-case "demand: merge is idempotent"
  (define d (make-demand 'narrowing '(f . (cons head)) 'constructor 'S-elaborate 0))
  (define dcv (demand-cell-value (seteq d)))
  (check-eq? (demand-lattice-merge dcv dcv) dcv))

(test-case "demand: priority field"
  (define d-high (make-demand 'type 'cell-1 'ground 'S-elaborate 0))
  (define d-low  (make-demand 'type 'cell-2 'ground 'S-elaborate 5))
  (check-equal? (demand-priority d-high) 0)
  (check-equal? (demand-priority d-low) 5))

(test-case "demand: domain-specific positions"
  ;; Token: char offset
  (define d1 (make-demand 'token 42 'any 'S-parse))
  (check-equal? (demand-position d1) 42)
  ;; Surface: span
  (define d2 (make-demand 'surface '(0 . 10) 'complete-item 'S-elaborate))
  (check-equal? (demand-position d2) '(0 . 10))
  ;; Narrowing: DT path
  (define d3 (make-demand 'narrowing '(fib . (suc zero)) 'constructor 'S-elaborate))
  (check-equal? (demand-position d3) '(fib . (suc zero))))

;; ============================================================
;; Core Lattice Tests
;; ============================================================

(test-case "core: bot merge with value = value"
  (check-equal? (core-lattice-merge core-bot 42) 42)
  (check-equal? (core-lattice-merge 42 core-bot) 42))

(test-case "core: same value = identity"
  (check-equal? (core-lattice-merge 42 42) 42))

(test-case "core: different values = contradiction"
  (check-equal? (core-lattice-merge 42 43) core-top))

(test-case "core: top absorbs"
  (check-equal? (core-lattice-merge core-top 42) core-top)
  (check-equal? (core-lattice-merge 42 core-top) core-top))

(test-case "core: contradicts detects top"
  (check-true (core-contradicts? core-top))
  (check-false (core-contradicts? core-bot))
  (check-false (core-contradicts? "some ast node")))

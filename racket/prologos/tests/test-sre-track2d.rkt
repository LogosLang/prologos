#lang racket/base

;;; test-sre-track2d.rkt — Regression tests for SRE Track 2D rewrite relation
;;;
;;; Validates: DPO span matching, template instantiation, fold combinator,
;;; tree-structural combinator, critical pair analysis, pipeline integration.

(require rackunit
         rackunit/text-ui
         racket/set
         racket/list
         "../sre-rewrite.rkt"
         "../parse-reader.rkt"
         "../surface-rewrite.rkt"
         "../rrb.rkt"
         "../driver.rkt")

;; ========================================
;; Helpers
;; ========================================

(define (mk-tok lex)
  (token-entry (seteq 'identifier) lex 0 (string-length lex)))

(define (make-node tag children)
  (parse-tree-node tag
                   (for/fold ([r rrb-empty]) ([c (in-list children)])
                     (rrb-push r c))
                   #f 0))

(define (node-children-list node)
  (rrb-to-list (parse-tree-node-children node)))

(define (child-lexemes node)
  (for/list ([c (in-list (node-children-list node))])
    (cond
      [(token-entry? c) (token-entry-lexeme c)]
      [(parse-tree-node? c) (format "<~a>" (parse-tree-node-tag c))]
      [else "?"])))

;; ========================================
;; Suite 1: Pattern-desc matching
;; ========================================

(define suite-pattern
  (test-suite "pattern-desc matching"

    (test-case "match: tag match with bindings"
      (define node (make-node 'if (list (mk-tok "if") (mk-tok "c") (mk-tok "t") (mk-tok "e"))))
      (define pd (pattern-desc 'if
        (list (child-pattern 0 'token "if" #f)
              (child-pattern 1 'any #f 'cond)
              (child-pattern 2 'any #f 'then)
              (child-pattern 3 'any #f 'else))
        #f))
      (define bindings (match-pattern-desc node pd))
      (check-true (hash? bindings))
      (check-equal? (token-entry-lexeme (hash-ref bindings 'cond)) "c")
      (check-equal? (token-entry-lexeme (hash-ref bindings 'then)) "t")
      (check-equal? (token-entry-lexeme (hash-ref bindings 'else)) "e"))

    (test-case "match: tag mismatch → #f"
      (define node (make-node 'when (list (mk-tok "when") (mk-tok "c") (mk-tok "b"))))
      (define pd (pattern-desc 'if (list) #f))
      (check-false (match-pattern-desc node pd)))

    (test-case "match: literal check"
      (define node (make-node 'let-assign
        (list (mk-tok "let") (mk-tok "x") (mk-tok ":=") (mk-tok "42") (mk-tok "body"))))
      (define pd (pattern-desc 'let-assign
        (list (child-pattern 0 'token "let" #f)
              (child-pattern 1 'any #f 'name)
              (child-pattern 2 'token ":=" #f)
              (child-pattern 3 'any #f 'value))
        'body))
      (define bindings (match-pattern-desc node pd))
      (check-true (hash? bindings))
      (check-equal? (token-entry-lexeme (hash-ref bindings 'name)) "x")
      (check-equal? (token-entry-lexeme (hash-ref bindings 'value)) "42")
      ;; Variadic tail
      (define tail (hash-ref bindings 'body))
      (check-true (list? tail))
      (check-equal? (length tail) 1)
      (check-equal? (token-entry-lexeme (car tail)) "body"))

    (test-case "match: literal mismatch → #f"
      (define node (make-node 'let-assign
        (list (mk-tok "let") (mk-tok "x") (mk-tok "=") (mk-tok "42"))))
      (define pd (pattern-desc 'let-assign
        (list (child-pattern 2 'token ":=" #f))
        #f))
      (check-false (match-pattern-desc node pd)))

    (test-case "match: not enough children → #f"
      (define node (make-node 'if (list (mk-tok "if") (mk-tok "c"))))
      (define pd (pattern-desc 'if
        (list (child-pattern 3 'any #f 'else))
        #f))
      (check-false (match-pattern-desc node pd)))))

;; ========================================
;; Suite 2: Template instantiation
;; ========================================

(define suite-template
  (test-suite "template instantiation"

    (test-case "instantiate: hole replacement"
      (define template (make-node 'expr (list (mk-tok "boolrec") (make-hole 'cond))))
      (define bindings (hasheq 'cond (mk-tok "my-cond")))
      (define result (instantiate-template template bindings))
      (check-true (parse-tree-node? result))
      (define kids (node-children-list result))
      (check-equal? (length kids) 2)
      (check-equal? (token-entry-lexeme (first kids)) "boolrec")
      (check-equal? (token-entry-lexeme (second kids)) "my-cond"))

    (test-case "instantiate: splice replacement"
      (define template (make-node 'expr
        (list (mk-tok "fn") (make-splice 'body))))
      (define bindings (hasheq 'body (list (mk-tok "a") (mk-tok "b") (mk-tok "c"))))
      (define result (instantiate-template template bindings))
      (define kids (node-children-list result))
      (check-equal? (length kids) 4)  ;; fn + a + b + c
      (check-equal? (token-entry-lexeme (first kids)) "fn")
      (check-equal? (token-entry-lexeme (fourth kids)) "c"))

    (test-case "instantiate: nested template"
      (define inner (make-node 'inner (list (make-hole 'x))))
      (define template (make-node 'outer (list (mk-tok "wrap") inner)))
      (define bindings (hasheq 'x (mk-tok "val")))
      (define result (instantiate-template template bindings))
      (define kids (node-children-list result))
      (check-equal? (length kids) 2)
      (define inner-result (second kids))
      (check-true (parse-tree-node? inner-result))
      (check-equal? (token-entry-lexeme (car (node-children-list inner-result))) "val"))))

;; ========================================
;; Suite 3: Simple rule application
;; ========================================

(define suite-simple-rules
  (test-suite "simple rule application"

    (test-case "expand-if-3: (if c t e) → (boolrec _ t e c)"
      (define node (make-node 'if
        (list (mk-tok "if") (mk-tok "cond") (mk-tok "then") (mk-tok "else"))))
      (define result (apply-all-sre-rewrites node 'V0-2))
      (check-true (parse-tree-node? result))
      (check-equal? (parse-tree-node-tag result) 'expr)
      (define kids (child-lexemes result))
      (check-equal? (first kids) "boolrec")
      (check-equal? (second kids) "_")
      (check-equal? (third kids) "then")
      (check-equal? (fourth kids) "else")
      (check-equal? (fifth kids) "cond"))

    (test-case "expand-when: (when c b) → (if c b unit)"
      (define node (make-node 'when
        (list (mk-tok "when") (mk-tok "cond") (mk-tok "body"))))
      (define result (apply-all-sre-rewrites node 'V0-2))
      (check-true (parse-tree-node? result))
      (check-equal? (parse-tree-node-tag result) 'if)
      (define kids (child-lexemes result))
      (check-equal? (first kids) "if")
      (check-equal? (second kids) "cond")
      (check-equal? (third kids) "body")
      (check-equal? (fourth kids) "unit"))

    (test-case "no match → #f"
      (define node (make-node 'unknown-tag (list (mk-tok "x"))))
      (check-false (apply-all-sre-rewrites node 'V0-2)))))

;; ========================================
;; Suite 4: Fold combinator
;; ========================================

(define suite-fold
  (test-suite "fold combinator"

    (test-case "list-literal: [e1 e2 e3] → cons chain"
      (define elems (list (mk-tok "e1") (mk-tok "e2") (mk-tok "e3")))
      (define result (run-fold elems (mk-tok "nil") list-literal-step))
      (check-true (parse-tree-node? result))
      ;; Outermost: (expr cons e1 ...)
      (check-equal? (token-entry-lexeme (first (node-children-list result))) "cons")
      (check-equal? (token-entry-lexeme (second (node-children-list result))) "e1"))

    (test-case "do: [a b c] → nested let"
      (define result (run-fold (list (mk-tok "a") (mk-tok "b")) (mk-tok "c") do-step))
      (check-true (parse-tree-node? result))
      (check-equal? (token-entry-lexeme (first (node-children-list result))) "let"))

    (test-case "fold empty → base case"
      (define result (run-fold '() (mk-tok "nil") list-literal-step))
      (check-true (token-entry? result))
      (check-equal? (token-entry-lexeme result) "nil"))))

;; ========================================
;; Suite 5: PUnify holes
;; ========================================

(define suite-holes
  (test-suite "PUnify holes"

    (test-case "make-hole creates $punify-hole node"
      (define h (make-hole 'test))
      (check-true (punify-hole? h))
      (check-equal? (punify-hole-name h) 'test))

    (test-case "make-splice creates $punify-splice node"
      (define s (make-splice 'body))
      (check-true (punify-splice? s))
      (check-equal? (punify-hole-name s) 'body))

    (test-case "regular node is not a hole"
      (define n (make-node 'expr (list (mk-tok "x"))))
      (check-false (punify-hole? n))
      (check-false (punify-splice? n)))))

;; ========================================
;; Suite 6: Verification
;; ========================================

(define suite-verify
  (test-suite "DPO interface verification"

    (test-case "valid rule passes verification"
      (define rule (sre-rewrite-rule
        'test-valid
        (pattern-desc 'test (list) #f)
        '(x y)
        (make-node 'expr (list (make-hole 'x) (make-hole 'y)))
        #f  ;; apply-fn
        'one-way 0 'unknown 'V0-2))
      (check-true (verify-rewrite-rule rule)))

    (test-case "rule with unbound hole fails verification"
      (define rule (sre-rewrite-rule
        'test-invalid
        (pattern-desc 'test (list) #f)
        '(x)  ;; K only has x
        (make-node 'expr (list (make-hole 'x) (make-hole 'z)))  ;; z not in K
        #f  ;; apply-fn
        'one-way 0 'unknown 'V0-2))
      (check-exn exn:fail? (lambda () (verify-rewrite-rule rule))))))

;; ========================================
;; Suite 7: Critical pair analysis
;; ========================================

(define suite-critical
  (test-suite "critical pair analysis"

    (test-case "SRE rules have zero critical pairs"
      (define-values (count pairs pair-list) (analyze-confluence))
      (check-equal? pairs 0)
      (check-true (> count 0)))

    (test-case "arity-disjoint rules are not overlapping"
      (define r1 (sre-rewrite-rule 'r1
        (pattern-desc 'tag (list (child-pattern 0 'any #f 'a)
                                 (child-pattern 1 'any #f 'b)) #f)
        '(a b) #f #f 'one-way 0 'unknown 'test))
      (define r2 (sre-rewrite-rule 'r2
        (pattern-desc 'tag (list (child-pattern 0 'any #f 'a)
                                 (child-pattern 1 'any #f 'b)
                                 (child-pattern 2 'any #f 'c)) #f)
        '(a b c) #f #f 'one-way 0 'unknown 'test))
      (define pairs (find-critical-pairs (list r1 r2)))
      (check-equal? (length pairs) 0))

    (test-case "same-arity same-tag rules overlap"
      (define r1 (sre-rewrite-rule 'r1
        (pattern-desc 'tag (list (child-pattern 0 'any #f 'a)) #f)
        '(a) #f #f 'one-way 0 'unknown 'test))
      (define r2 (sre-rewrite-rule 'r2
        (pattern-desc 'tag (list (child-pattern 0 'any #f 'b)) #f)
        '(b) #f #f 'one-way 0 'unknown 'test))
      (define pairs (find-critical-pairs (list r1 r2)))
      (check-equal? (length pairs) 1))))

;; ========================================
;; Suite 8: Pipeline integration
;; ========================================

(define suite-pipeline
  (test-suite "pipeline integration"

    (test-case "if-node through pipeline completes"
      (define node (make-node 'if
        (list (mk-tok "if") (mk-tok "c") (mk-tok "t") (mk-tok "e"))))
      (define pv (run-form-pipeline node))
      (check-true (set-member? (form-pipeline-value-transforms pv) 'done)))

    (test-case "when-node through pipeline completes"
      (define node (make-node 'when
        (list (mk-tok "when") (mk-tok "c") (mk-tok "b"))))
      (define pv (run-form-pipeline node))
      (check-true (set-member? (form-pipeline-value-transforms pv) 'done)))

    (test-case "let-assign through pipeline completes"
      (define node (make-node 'let-assign
        (list (mk-tok "let") (mk-tok "x") (mk-tok ":=") (mk-tok "42") (mk-tok "body"))))
      (define pv (run-form-pipeline node))
      (check-true (set-member? (form-pipeline-value-transforms pv) 'done)))))

;; ========================================
;; Run all
;; ========================================

(run-tests suite-pattern)
(run-tests suite-template)
(run-tests suite-simple-rules)
(run-tests suite-fold)
(run-tests suite-holes)
(run-tests suite-verify)
(run-tests suite-critical)
(run-tests suite-pipeline)

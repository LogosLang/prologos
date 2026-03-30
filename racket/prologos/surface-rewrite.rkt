#lang racket/base

;;;
;;; surface-rewrite.rkt — Surface Normalization as Propagator Rewriting
;;;
;;; PPN Track 2: Replaces the imperative preparse pipeline in macros.rkt
;;; with registered rewrite rules operating on parse tree nodes.
;;;
;;; Design: docs/tracking/2026-03-28_PPN_TRACK2_DESIGN.md
;;; Research: docs/research/2026-03-26_TREE_REWRITING_AS_STRUCTURAL_UNIFICATION.md
;;;
;;; Architecture:
;;;   - Parse tree nodes (from PPN Track 1) are the canonical representation
;;;   - SRE ctor-desc registrations for surface form tags
;;;   - Rewrite rules as first-class data (lhs-desc, rhs-desc/template-fn, binding-map)
;;;   - CALM-compliant: set-once cells between strata, Layered Recovery for rewrites
;;;   - Tag refinement T(0): 'line → form-specific tags via SRE subtype
;;;
;;; Principle: Propagator Only. No algorithms. Rules are data.
;;; Ordering emerges from data dependencies, not code structure.
;;;

(require racket/list
         racket/set
         "parse-reader.rkt"
         "rrb.rkt"
         "ctor-registry.rkt")

(provide
 ;; Rewrite rule struct
 (struct-out rewrite-rule)
 ;; Tag refinement
 (struct-out tag-rule)
 register-tag-rule!
 refine-tag
 ;; Rewrite rule registration
 register-rewrite-rule!
 lookup-rewrite-rules
 ;; Surface domain helpers
 surface-lattice-spec
 ;; Tag constants
 tag-expr tag-line
 tag-let-assign tag-let-bracket
 tag-if tag-when tag-cond tag-do
 tag-defn tag-def tag-spec
 tag-data tag-trait tag-impl
 tag-list-literal tag-lseq-literal
 tag-quote tag-quasiquote
 tag-pipe-gt tag-compose tag-mixfix
 tag-dot-access tag-dot-key tag-infix-pipe tag-implicit-map
 tag-session tag-defproc tag-proc
 tag-defr tag-solver tag-eval
 tag-ns tag-imports tag-exports tag-foreign
 tag-defmacro tag-deftype tag-bundle
 tag-property tag-functor tag-schema tag-selection
 tag-specialize tag-capability tag-strategy
 tag-spawn tag-spawn-with
 tag-precedence-group)

;; ========================================
;; Tag constants
;; ========================================
;; Form-head tags assigned by T(0) tag refinement.
;; 'line is the initial tag from PPN Track 1 tree-builder.
;; tag-expr is the catch-all for non-keyword-headed lines.

(define tag-line 'line)
(define tag-expr 'expr)

;; Keyword-headed form tags
(define tag-let-assign 'let-assign)
(define tag-let-bracket 'let-bracket)
(define tag-if 'if)
(define tag-when 'when)
(define tag-cond 'cond)
(define tag-do 'do)
(define tag-defn 'defn)
(define tag-def 'def)
(define tag-spec 'spec)
(define tag-data 'data)
(define tag-trait 'trait)
(define tag-impl 'impl)
(define tag-list-literal 'list-literal)
(define tag-lseq-literal 'lseq-literal)
(define tag-quote 'quote)
(define tag-quasiquote 'quasiquote)
(define tag-pipe-gt 'pipe-gt)
(define tag-compose 'compose)
(define tag-mixfix 'mixfix)
(define tag-dot-access 'dot-access)
(define tag-dot-key 'dot-key)
(define tag-infix-pipe 'infix-pipe)
(define tag-implicit-map 'implicit-map)
(define tag-session 'session)
(define tag-defproc 'defproc)
(define tag-proc 'proc)
(define tag-defr 'defr)
(define tag-solver 'solver)
(define tag-eval 'eval)
(define tag-ns 'ns)
(define tag-imports 'imports)
(define tag-exports 'exports)
(define tag-foreign 'foreign)
(define tag-defmacro 'defmacro)
(define tag-deftype 'deftype)
(define tag-bundle 'bundle)
(define tag-property 'property)
(define tag-functor 'functor)
(define tag-schema 'schema)
(define tag-selection 'selection)
(define tag-specialize 'specialize)
(define tag-capability 'capability)
(define tag-strategy 'strategy)
(define tag-spawn 'spawn)
(define tag-spawn-with 'spawn-with)
(define tag-precedence-group 'precedence-group)

;; ========================================
;; Surface lattice spec
;; ========================================
;; Sentinel for surface domain — resolved at decomposition time.
;; Parallels type-lattice-spec and session-lattice-spec in ctor-registry.rkt.

(define surface-lattice-spec 'surface)

;; ========================================
;; Tag refinement rules
;; ========================================
;; A tag-rule inspects a 'line node's first child token and structure
;; to assign a form-specific tag. This is SRE subtype refinement:
;; 'line → 'let-assign is monotone (more specific, more structure known).

(struct tag-rule
  (keyword       ;; string: first-token lexeme that triggers this rule
   guard         ;; (rrb-of-children → boolean) | #f: additional structure check
   target-tag)   ;; symbol: the refined tag to assign
  #:transparent)

;; Registry: keyword → (list tag-rule)
;; Multiple rules per keyword (e.g., 'let' → let-assign OR let-bracket)
(define tag-rule-registry (make-hasheq))

(define (register-tag-rule! rule)
  (define kw (string->symbol (tag-rule-keyword rule)))
  (define existing (hash-ref tag-rule-registry kw '()))
  (hash-set! tag-rule-registry kw (cons rule existing)))

;; Get the first child token's lexeme from a parse-tree-node
(define (first-token-lexeme node)
  (define children (parse-tree-node-children node))
  (and (> (rrb-size children) 0)
       (let ([first (rrb-get children 0)])
         (and (token-entry? first)
              (token-entry-lexeme first)))))

;; Refine a single node's tag based on registered tag-rules.
;; Returns a new node with refined tag, or the original if no rule matches.
(define (refine-node-tag node)
  (cond
    [(not (eq? (parse-tree-node-tag node) 'line)) node]  ;; only refine 'line nodes
    [else
     (define lexeme (first-token-lexeme node))
     (cond
       [(not lexeme)
        ;; No first token (empty line) → keep as 'line
        node]
       [else
        (define kw (string->symbol lexeme))
        (define rules (hash-ref tag-rule-registry kw '()))
        (define children (parse-tree-node-children node))
        (define matching-rule
          (for/first ([r (in-list rules)]
                      #:when (or (not (tag-rule-guard r))
                                 ((tag-rule-guard r) children)))
            r))
        (if matching-rule
            ;; Refine: create new node with specific tag, same children
            (parse-tree-node (tag-rule-target-tag matching-rule)
                             children
                             (parse-tree-node-srcloc node)
                             (parse-tree-node-indent node))
            ;; No rule matched → tag as expression (catch-all)
            (parse-tree-node tag-expr
                             children
                             (parse-tree-node-srcloc node)
                             (parse-tree-node-indent node)))])]))

;; Refine tags for an entire tree (recursive into all children).
;; D.3 finding E1: T(0) MUST recurse into all parse-tree-node children.
(define (refine-tag tree)
  (cond
    [(not (parse-tree-node? tree)) tree]
    [else
     ;; First, recursively refine children
     (define old-children (parse-tree-node-children tree))
     (define new-children
       (let loop ([i 0] [acc rrb-empty])
         (if (>= i (rrb-size old-children))
             acc
             (let ([child (rrb-get old-children i)])
               (loop (+ i 1)
                     (rrb-push acc
                               (if (parse-tree-node? child)
                                   (refine-tag child)
                                   child)))))))
     ;; Then refine this node's own tag
     (define with-refined-children
       (if (equal? old-children new-children)
           tree
           (parse-tree-node (parse-tree-node-tag tree)
                            new-children
                            (parse-tree-node-srcloc tree)
                            (parse-tree-node-indent tree))))
     (refine-node-tag with-refined-children)]))

;; ========================================
;; Rewrite rule struct
;; ========================================
;; A rewrite rule is first-class data describing a DPO transformation.
;; Simple rules use rhs-desc + binding-map (inspectable data).
;; Recursive rules use template-fn (pure function).

(struct rewrite-rule
  (name          ;; symbol — for debugging/tracing
   lhs-tag       ;; symbol — which form tag this rule matches
   ;; EITHER static template (simple rules) OR template function (recursive rules):
   rhs-builder   ;; (list-of-children srcloc indent → parse-tree-node) — builds output
   ;; Metadata:
   guard         ;; (parse-tree-node → boolean) or #f — additional match condition
   priority      ;; natural — higher fires first for independent overlapping patterns
   stratum)      ;; symbol — which rewrite stratum: 'V0-0, 'V0-1, 'V0-2, 'V1, 'V2
  #:transparent)

;; ========================================
;; Rewrite rule registry
;; ========================================
;; stratum → (list rewrite-rule), sorted by priority (highest first)

(define rewrite-rule-registry (make-hasheq))

(define (register-rewrite-rule! rule)
  (define stratum (rewrite-rule-stratum rule))
  (define existing (hash-ref rewrite-rule-registry stratum '()))
  ;; Insert maintaining priority order (highest first)
  (define updated
    (let loop ([rules existing] [acc '()] [inserted? #f])
      (cond
        [(and (null? rules) (not inserted?))
         (reverse (cons rule acc))]
        [(null? rules)
         (reverse acc)]
        [(and (not inserted?)
              (>= (rewrite-rule-priority rule)
                  (rewrite-rule-priority (car rules))))
         (loop rules (cons rule acc) #t)]
        [else
         (loop (cdr rules) (cons (car rules) acc) inserted?)])))
  (hash-set! rewrite-rule-registry stratum updated))

;; Get all rules for a stratum, priority-ordered
(define (lookup-rewrite-rules stratum)
  (hash-ref rewrite-rule-registry stratum '()))

;; ========================================
;; Rule application
;; ========================================
;; Apply the first matching rule to a node.
;; Returns (values new-node matched?) where matched? indicates if any rule fired.

(define (apply-rules node stratum)
  (define rules (lookup-rewrite-rules stratum))
  (let loop ([remaining rules])
    (cond
      [(null? remaining) (values node #f)]
      [else
       (define rule (car remaining))
       (define tag (parse-tree-node-tag node))
       (cond
         [(and (eq? tag (rewrite-rule-lhs-tag rule))
               (or (not (rewrite-rule-guard rule))
                   ((rewrite-rule-guard rule) node)))
          ;; Match! Apply the rule.
          (define children (rrb-to-list (parse-tree-node-children node)))
          (define new-node
            ((rewrite-rule-rhs-builder rule)
             children
             (parse-tree-node-srcloc node)
             (parse-tree-node-indent node)))
          (values new-node #t)]
         [else
          (loop (cdr remaining))])])))

;; ========================================
;; Built-in tag refinement rules
;; ========================================
;; Register tag rules for all known form heads.
;; Guards distinguish variants (e.g., let-assign vs let-bracket).

;; Helper: check if nth child is a token with specific lexeme
(define (nth-child-token-is? children n lexeme)
  (and (> (rrb-size children) n)
       (let ([child (rrb-get children n)])
         (and (token-entry? child)
              (equal? (token-entry-lexeme child) lexeme)))))

;; Helper: check if nth child is a parse-tree-node (bracket group)
(define (nth-child-is-node? children n)
  (and (> (rrb-size children) n)
       (parse-tree-node? (rrb-get children n))))

;; --- Keyword form tags ---
;; Each keyword gets one or more tag-rules. Guards distinguish variants.

;; let: two variants
(register-tag-rule!
 (tag-rule "let"
           (lambda (children) (nth-child-token-is? children 2 ":="))
           tag-let-assign))
(register-tag-rule!
 (tag-rule "let"
           (lambda (children) (nth-child-is-node? children 1))
           tag-let-bracket))

;; Simple keyword forms (no variants — just first-token match)
(define (register-simple-tag! keyword tag)
  (register-tag-rule! (tag-rule keyword #f tag)))

(register-simple-tag! "if" tag-if)
(register-simple-tag! "when" tag-when)
(register-simple-tag! "cond" tag-cond)
(register-simple-tag! "do" tag-do)
(register-simple-tag! "defn" tag-defn)
(register-simple-tag! "def" tag-def)
(register-simple-tag! "spec" tag-spec)
(register-simple-tag! "data" tag-data)
(register-simple-tag! "trait" tag-trait)
(register-simple-tag! "impl" tag-impl)
(register-simple-tag! "defmacro" tag-defmacro)
(register-simple-tag! "deftype" tag-deftype)
(register-simple-tag! "bundle" tag-bundle)
(register-simple-tag! "property" tag-property)
(register-simple-tag! "functor" tag-functor)
(register-simple-tag! "schema" tag-schema)
(register-simple-tag! "selection" tag-selection)
(register-simple-tag! "specialize" tag-specialize)
(register-simple-tag! "session" tag-session)
(register-simple-tag! "defproc" tag-defproc)
(register-simple-tag! "proc" tag-proc)
(register-simple-tag! "defr" tag-defr)
(register-simple-tag! "solver" tag-solver)
(register-simple-tag! "eval" tag-eval)
(register-simple-tag! "ns" tag-ns)
(register-simple-tag! "imports" tag-imports)
(register-simple-tag! "exports" tag-exports)
(register-simple-tag! "foreign" tag-foreign)
(register-simple-tag! "capability" tag-capability)
(register-simple-tag! "strategy" tag-strategy)
(register-simple-tag! "spawn" tag-spawn)
(register-simple-tag! "spawn-with" tag-spawn-with)
(register-simple-tag! "precedence-group" tag-precedence-group)

;; Sentinel-headed forms (from reader sentinels, not keyword tokens)
(register-tag-rule!
 (tag-rule "$list-literal" #f tag-list-literal))
(register-tag-rule!
 (tag-rule "$lseq-literal" #f tag-lseq-literal))
(register-tag-rule!
 (tag-rule "$quote" #f tag-quote))
(register-tag-rule!
 (tag-rule "$quasiquote" #f tag-quasiquote))
(register-tag-rule!
 (tag-rule "$pipe-gt" #f tag-pipe-gt))
(register-tag-rule!
 (tag-rule "$compose" #f tag-compose))
(register-tag-rule!
 (tag-rule "$mixfix" #f tag-mixfix))

;; ========================================
;; Module-level tests
;; ========================================

(module+ test
  (require rackunit
           "rrb.rkt")

  ;; Helper: make a simple line node with token children
  (define (make-line-node . lexemes)
    (parse-tree-node
     'line
     (for/fold ([rrb rrb-empty]) ([lex (in-list lexemes)])
       (rrb-push rrb (token-entry (seteq 'symbol) lex 0 (string-length lex))))
     #f 0))

  ;; Helper: make a line node with a bracket-group child at position 1
  (define (make-line-with-bracket first-lex . bracket-lexemes)
    (parse-tree-node
     'line
     (rrb-push
      (rrb-push rrb-empty
                (token-entry (seteq 'symbol) first-lex 0 (string-length first-lex)))
      (parse-tree-node 'line
                       (for/fold ([rrb rrb-empty]) ([lex (in-list bracket-lexemes)])
                         (rrb-push rrb (token-entry (seteq 'symbol) lex 0 (string-length lex))))
                       #f 0))
     #f 0))

  ;; --- Tag refinement tests ---

  (test-case "tag-refine: let-assign"
    (define node (make-line-node "let" "x" ":=" "42" "body"))
    (define refined (refine-node-tag node))
    (check-eq? (parse-tree-node-tag refined) tag-let-assign))

  (test-case "tag-refine: let-bracket"
    (define node (make-line-with-bracket "let" "x" ":=" "42"))
    (define refined (refine-node-tag node))
    (check-eq? (parse-tree-node-tag refined) tag-let-bracket))

  (test-case "tag-refine: defn"
    (define node (make-line-node "defn" "foo" "[x]" "body"))
    (define refined (refine-node-tag node))
    (check-eq? (parse-tree-node-tag refined) tag-defn))

  (test-case "tag-refine: def"
    (define node (make-line-node "def" "x" ":=" "42"))
    (define refined (refine-node-tag node))
    (check-eq? (parse-tree-node-tag refined) tag-def))

  (test-case "tag-refine: spec"
    (define node (make-line-node "spec" "add" "Int" "Int" "->" "Int"))
    (define refined (refine-node-tag node))
    (check-eq? (parse-tree-node-tag refined) tag-spec))

  (test-case "tag-refine: data"
    (define node (make-line-node "data" "Bool" ":=" "true" "|" "false"))
    (define refined (refine-node-tag node))
    (check-eq? (parse-tree-node-tag refined) tag-data))

  (test-case "tag-refine: unknown keyword → expr"
    (define node (make-line-node "foo" "bar" "baz"))
    (define refined (refine-node-tag node))
    (check-eq? (parse-tree-node-tag refined) tag-expr))

  (test-case "tag-refine: non-line node unchanged"
    (define node (parse-tree-node 'root rrb-empty #f 0))
    (define refined (refine-node-tag node))
    (check-eq? (parse-tree-node-tag refined) 'root))

  (test-case "tag-refine: recursive into children"
    (define inner (make-line-node "let" "x" ":=" "42" "body"))
    (define outer (parse-tree-node
                   'line
                   (rrb-push (rrb-push rrb-empty
                                       (token-entry (seteq 'symbol) "defn" 0 4))
                             inner)
                   #f 0))
    (define refined (refine-tag outer))
    ;; Outer should be refined to defn
    (check-eq? (parse-tree-node-tag refined) tag-defn)
    ;; Inner child should be refined to let-assign
    (define inner-refined (rrb-get (parse-tree-node-children refined) 1))
    (check-true (parse-tree-node? inner-refined))
    (check-eq? (parse-tree-node-tag inner-refined) tag-let-assign))

  (test-case "tag-refine: sentinel-headed forms"
    (define node (make-line-node "$list-literal" "1" "2" "3"))
    (define refined (refine-node-tag node))
    (check-eq? (parse-tree-node-tag refined) tag-list-literal))

  ;; --- Rewrite rule tests ---

  (test-case "rewrite-rule: registration and lookup"
    (define test-rule
      (rewrite-rule 'test-rule
                    tag-if
                    (lambda (children srcloc indent)
                      (parse-tree-node 'rewritten rrb-empty srcloc indent))
                    #f 100 'V0-2))
    (register-rewrite-rule! test-rule)
    (define rules (lookup-rewrite-rules 'V0-2))
    (check-true (pair? rules))
    (check-eq? (rewrite-rule-name (car rules)) 'test-rule))

  (test-case "rewrite-rule: apply-rules matches by tag"
    (define test-rule
      (rewrite-rule 'expand-if-test
                    tag-if
                    (lambda (children srcloc indent)
                      (parse-tree-node 'if-expanded rrb-empty srcloc indent))
                    #f 100 'test-stratum))
    (register-rewrite-rule! test-rule)
    (define node (parse-tree-node tag-if rrb-empty #f 0))
    (define-values (result matched?) (apply-rules node 'test-stratum))
    (check-true matched?)
    (check-eq? (parse-tree-node-tag result) 'if-expanded))

  (test-case "rewrite-rule: no match returns original"
    (define node (parse-tree-node tag-defn rrb-empty #f 0))
    (define-values (result matched?) (apply-rules node 'test-stratum))
    (check-false matched?)
    (check-eq? result node))

  (test-case "rewrite-rule: guard filters matches"
    (define guarded-rule
      (rewrite-rule 'guarded-test
                    tag-def
                    (lambda (children srcloc indent)
                      (parse-tree-node 'def-expanded rrb-empty srcloc indent))
                    (lambda (node)
                      (> (rrb-size (parse-tree-node-children node)) 3))
                    100 'guard-stratum))
    (register-rewrite-rule! guarded-rule)
    ;; Node with 2 children → guard fails
    (define small-node
      (parse-tree-node tag-def
                       (rrb-push (rrb-push rrb-empty 'a) 'b)
                       #f 0))
    (define-values (r1 m1) (apply-rules small-node 'guard-stratum))
    (check-false m1)
    ;; Node with 4 children → guard passes
    (define big-node
      (parse-tree-node tag-def
                       (rrb-push (rrb-push (rrb-push (rrb-push rrb-empty 'a) 'b) 'c) 'd)
                       #f 0))
    (define-values (r2 m2) (apply-rules big-node 'guard-stratum))
    (check-true m2)
    (check-eq? (parse-tree-node-tag r2) 'def-expanded))
)

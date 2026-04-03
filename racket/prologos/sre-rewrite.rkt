#lang racket/base

;;;
;;; sre-rewrite.rkt — SRE Rewrite Relation (Track 2D)
;;;
;;; The 4th SRE relation: DPO spans (L ← K → R) for surface normalization.
;;; Rules are first-class data with pattern-desc LHS, PUnify hole templates,
;;; and sub-cell interfaces.
;;;
;;; Consumers:
;;;   - surface-rewrite.rkt (rewrite pipeline integration)
;;;   - Grammar Form R&D (production compilation target)
;;;   - PPN Track 4 (critical pair analysis for elaboration)
;;;   - SRE Track 6 (reduction-as-rewriting, equivalence mode)
;;;
;;; Design: docs/tracking/2026-04-03_SRE_TRACK2D_DESIGN.md
;;;

(require racket/match
         racket/list
         racket/set
         "syntax.rkt"
         "parse-reader.rkt"        ;; parse-tree-node, token-entry
         "rrb.rkt"                 ;; rrb-empty, rrb-push, rrb-to-list, rrb-get, rrb-size
         "ctor-registry.rkt"
         "sre-core.rkt")

(provide
 ;; DPO span struct
 (struct-out sre-rewrite-rule)
 ;; Pattern-desc struct
 (struct-out pattern-desc)
 (struct-out child-pattern)
 ;; PUnify hole helpers
 make-hole
 make-splice
 punify-hole?
 punify-splice?
 punify-hole-name
 ;; Rule registry (monotone — rules only added, never removed)
 register-sre-rewrite-rule!
 lookup-sre-rewrite-rules
 all-sre-rewrite-rules
 ;; Template instantiation
 instantiate-template
 ;; Propagator factory (Phase 4)
 make-rewrite-propagator-fn
 apply-sre-rewrite-rule
 apply-all-sre-rewrites
 ;; Verification
 verify-rewrite-rule
 ;; Critical pair analysis
 find-critical-pairs
 ;; Pattern matching
 match-pattern-desc
 ;; Fold combinator
 (struct-out fold-pu-state)
 run-fold
 apply-fold-rewrite
 ;; Fold step functions (for lifted fold rules)
 list-literal-step
 lseq-literal-step
 do-step
 ;; Form-tag ctor-desc registration
 register-form-tag-ctor-desc!)

;; ========================================
;; DPO Span: sre-rewrite-rule
;; ========================================

(struct sre-rewrite-rule
  (name              ;; symbol — debugging/tracing
   lhs-pattern       ;; pattern-desc — LHS pattern for matching
   interface-keys    ;; (listof symbol) — named K bindings (= sub-cell names)
   rhs-template      ;; parse-tree-node with $punify-hole markers — the reconstruction template
   directionality    ;; 'one-way (Track 2D) or 'equivalence (Track 6 e-graph)
   cost              ;; number (tropical semiring, default 0)
   confluence-class  ;; 'unknown | 'strongly-confluent | 'priority-resolved
   stratum)          ;; symbol — pipeline stratum
  #:transparent)

;; ========================================
;; Pattern-desc: extends ctor-desc with sub-structure matching
;; ========================================
;; Grammar Form compilation target. Retires guard field from rewrite-rule.

(struct pattern-desc
  (tag              ;; symbol — outermost form tag
   child-patterns   ;; (listof child-pattern) — per-position patterns
   variadic-tail    ;; symbol or #f — K binding for remaining children
   )
  #:transparent)

(struct child-pattern
  (position         ;; natural — which child
   kind             ;; 'token | 'node | 'any — what type of child
   literal          ;; string or #f — for token literal matching (e.g., ":=")
   bind-name        ;; symbol or #f — K binding name (e.g., 'value)
   )
  #:transparent)

;; ========================================
;; PUnify Holes — template markers
;; ========================================
;; A hole is a parse-tree-node with tag '$punify-hole and a single child
;; whose lexeme is the K binding name. PUnify recognizes this tag and
;; unifies the node with the named K sub-cell value.
;;
;; A splice marker uses tag '$punify-splice — same structure, different tag.
;; PUnify splices the K binding's children into the parent RRB.

(define (make-hole binding-name)
  (parse-tree-node '$punify-hole
                   (list->rrb (list (token-entry (seteq 'binding)
                                                 (symbol->string binding-name) 0 0)))
                   #f 0))

(define (make-splice binding-name)
  (parse-tree-node '$punify-splice
                   (list->rrb (list (token-entry (seteq 'binding)
                                                 (symbol->string binding-name) 0 0)))
                   #f 0))

(define (punify-hole? node)
  (and (parse-tree-node? node)
       (eq? (parse-tree-node-tag node) '$punify-hole)))

(define (punify-splice? node)
  (and (parse-tree-node? node)
       (eq? (parse-tree-node-tag node) '$punify-splice)))

(define (punify-hole-name node)
  (define children (parse-tree-node-children node))
  (and (> (rrb-size children) 0)
       (let ([first (rrb-get children 0)])
         (and (token-entry? first)
              (string->symbol (token-entry-lexeme first))))))

(define (list->rrb lst)
  (for/fold ([rrb rrb-empty]) ([item (in-list lst)])
    (rrb-push rrb item)))

;; ========================================
;; Rule Registry (monotone — F5)
;; ========================================
;; INVARIANT: rules are ONLY added, never removed or overwritten.
;; This enforces monotonicity — the rule catalog only grows.
;; Grammar Form migration to cell is straightforward: register = cell write.

(define sre-rewrite-registry (make-hasheq))  ;; stratum → (listof sre-rewrite-rule)

(define (register-sre-rewrite-rule! rule)
  (define stratum (sre-rewrite-rule-stratum rule))
  (define existing (hash-ref sre-rewrite-registry stratum '()))
  (hash-set! sre-rewrite-registry stratum (append existing (list rule))))

(define (lookup-sre-rewrite-rules stratum)
  (hash-ref sre-rewrite-registry stratum '()))

(define (all-sre-rewrite-rules)
  (apply append (hash-values sre-rewrite-registry)))

;; ========================================
;; Verification (DPO interface preservation)
;; ========================================
;; Every hole in the RHS template must correspond to a K binding.

(define (collect-holes node)
  (cond
    [(not (parse-tree-node? node)) '()]
    [(punify-hole? node) (list (punify-hole-name node))]
    [(punify-splice? node) (list (punify-hole-name node))]
    [else
     (define children (parse-tree-node-children node))
     (define n (rrb-size children))
     (apply append
       (for/list ([i (in-range n)])
         (define child (rrb-get children i))
         (if (parse-tree-node? child)
             (collect-holes child)
             '())))]))

(define (verify-rewrite-rule rule)
  (define k-names (sre-rewrite-rule-interface-keys rule))
  (define holes (collect-holes (sre-rewrite-rule-rhs-template rule)))
  (for ([hole-name (in-list holes)])
    (unless (member hole-name k-names)
      (error 'verify-rewrite-rule
             "rule ~a: RHS has hole ~a but K only declares ~a"
             (sre-rewrite-rule-name rule) hole-name k-names)))
  #t)

;; ========================================
;; Critical Pair Analysis
;; ========================================
;; Two rules have a critical pair if their LHS patterns can match
;; the same cell value and produce different results.
;; For pattern-desc: overlap = same tag + compatible child patterns.

(define (patterns-overlap? p1 p2)
  ;; Two pattern-descs overlap if they have the same tag.
  ;; (Richer overlap analysis for child-patterns is future scope.)
  (eq? (pattern-desc-tag p1) (pattern-desc-tag p2)))

(define (find-critical-pairs rules)
  (define pairs '())
  (for* ([i (in-range (length rules))]
         [j (in-range (add1 i) (length rules))])
    (define r1 (list-ref rules i))
    (define r2 (list-ref rules j))
    (when (and (eq? (sre-rewrite-rule-stratum r1) (sre-rewrite-rule-stratum r2))
               (patterns-overlap? (sre-rewrite-rule-lhs-pattern r1)
                                  (sre-rewrite-rule-lhs-pattern r2)))
      (set! pairs (cons (list r1 r2) pairs))))
  (reverse pairs))

;; ========================================
;; Pattern Matching: match-pattern-desc
;; ========================================
;; Match a parse-tree-node against a pattern-desc.
;; Returns a hash of K bindings (symbol → value) on match, or #f on no match.

(define (match-pattern-desc node pattern)
  (cond
    [(not (parse-tree-node? node)) #f]
    [(not (eq? (parse-tree-node-tag node) (pattern-desc-tag pattern))) #f]
    [else
     (define children (rrb-to-list (parse-tree-node-children node)))
     (define child-pats (pattern-desc-child-patterns pattern))
     ;; Check each child pattern
     (define bindings (make-hasheq))
     (define ok?
       (for/and ([cp (in-list child-pats)])
         (define pos (child-pattern-position cp))
         (cond
           [(>= pos (length children)) #f]  ;; not enough children
           [else
            (define child (list-ref children pos))
            (define kind-ok?
              (case (child-pattern-kind cp)
                [(token) (token-entry? child)]
                [(node) (parse-tree-node? child)]
                [(any) #t]
                [else #t]))
            (define literal-ok?
              (if (child-pattern-literal cp)
                  (and (token-entry? child)
                       (equal? (token-entry-lexeme child)
                               (child-pattern-literal cp)))
                  #t))
            (when (and kind-ok? literal-ok? (child-pattern-bind-name cp))
              (hash-set! bindings (child-pattern-bind-name cp) child))
            (and kind-ok? literal-ok?)])))
     ;; Handle variadic tail
     (when (and ok? (pattern-desc-variadic-tail pattern))
       (define last-fixed-pos
         (if (null? child-pats) -1
             (apply max (map child-pattern-position child-pats))))
       (define tail (drop children (add1 last-fixed-pos)))
       (hash-set! bindings (pattern-desc-variadic-tail pattern) tail))
     (and ok? bindings)]))

;; ========================================
;; Template Instantiation
;; ========================================
;; Replace $punify-hole markers in a template tree with K binding values.
;; Replace $punify-splice markers by splicing K binding's list into parent.
;; Returns a new parse-tree-node with all holes filled.

(define (instantiate-template template bindings #:srcloc [srcloc #f] #:indent [indent 0])
  (cond
    [(not (parse-tree-node? template)) template]  ;; token-entry — pass through
    [(punify-hole? template)
     ;; Replace hole with bound value
     (define name (punify-hole-name template))
     (hash-ref bindings name
               (lambda () (error 'instantiate-template
                                  "unbound hole: ~a" name)))]
    [else
     ;; Recursively instantiate children, handling splices
     (define children (rrb-to-list (parse-tree-node-children template)))
     (define new-children
       (apply append
         (for/list ([child (in-list children)])
           (cond
             [(and (parse-tree-node? child) (punify-splice? child))
              ;; Splice: insert all items from the binding
              (define name (punify-hole-name child))
              (define val (hash-ref bindings name
                            (lambda () (error 'instantiate-template
                                              "unbound splice: ~a" name))))
              (if (list? val) val (list val))]
             [else
              (list (instantiate-template child bindings
                      #:srcloc srcloc #:indent indent))]))))
     (parse-tree-node (parse-tree-node-tag template)
                      (list->rrb new-children)
                      (or srcloc (parse-tree-node-srcloc template))
                      (or indent (parse-tree-node-indent template)))]))

;; ========================================
;; Phase 4: Per-Rule Propagator Factory
;; ========================================
;; Each rule becomes a propagator: watches a form cell, fires when LHS
;; matches, writes RHS. No iteration. No priority. All matching propagators
;; fire. With zero critical pairs, exactly one fires.
;;
;; make-rewrite-propagator-fn: given a rule, returns a fire function.
;; apply-sre-rewrite-rule: standalone rule application (match + instantiate).

;; Apply a single SRE rewrite rule to a node.
;; Returns the rewritten node on match, or #f on no match.
(define (apply-sre-rewrite-rule rule node)
  (define bindings (match-pattern-desc node (sre-rewrite-rule-lhs-pattern rule)))
  (cond
    [(not bindings) #f]  ;; no match — propagator doesn't fire
    [(not (sre-rewrite-rule-rhs-template rule))
     ;; No template (fold/tree rules) — fold rules use apply-fold-rewrite
     ;; or tree-structural-rewrite directly. This path is for simple span rules.
     #f]
    [else
     (instantiate-template (sre-rewrite-rule-rhs-template rule) bindings
       #:srcloc (and (parse-tree-node? node) (parse-tree-node-srcloc node))
       #:indent (and (parse-tree-node? node) (parse-tree-node-indent node)))]))

;; Create a propagator fire function for a rewrite rule.
;; The fire function signature matches the propagator protocol:
;;   (fire-fn net cell-id cell-value) → new-value | #f
;; Returns: the rewritten value, or #f (don't write — propagator silent).
;;
;; Phase 7 installs this on the network via net-add-propagator.
(define (make-rewrite-propagator-fn rule)
  (lambda (net cell-id cell-value)
    (apply-sre-rewrite-rule rule cell-value)))

;; Apply ALL matching SRE rewrite rules to a node.
;; Returns the first match's result (since rules have zero critical pairs,
;; at most one matches). For future Grammar Form rules with critical pairs,
;; the cell merge function resolves conflicts (F7: conflicting → top).
(define (apply-all-sre-rewrites node stratum)
  (define rules (lookup-sre-rewrite-rules stratum))
  (for/or ([rule (in-list rules)])
    (apply-sre-rewrite-rule rule node)))

;; ========================================
;; Form-tag ctor-desc registration
;; ========================================
;; Register a form tag as a first-class ctor-desc in the 'form domain.
;; Makes form tags SRE-native: structural decomposition, critical pair
;; analysis, Grammar Form registration target.

(define (register-form-tag-ctor-desc! tag-sym #:arity [arity #f])
  ;; Register in 'form domain. Recognizer: parse-tree-node with matching tag.
  ;; Extract: drop first child (tag token), return rest.
  ;; Reconstruct: build parse-tree-node with tag + children.
  ;; Arity = total children count (including tag token if present).
  ;; For form-tag ctor-descs, extract returns ALL children (tag included).
  ;; Pattern-desc handles the tag/children split at the pattern level.
  (define actual-arity (or arity 0))
  (define sample-children
    (make-list actual-arity (token-entry (seteq 'sample) "x" 0 1)))
  (register-ctor! tag-sym
    #:arity actual-arity
    #:recognizer (lambda (v)
                   (and (parse-tree-node? v)
                        (eq? (parse-tree-node-tag v) tag-sym)))
    #:extract (lambda (v)
                (rrb-to-list (parse-tree-node-children v)))
    #:reconstruct (lambda (vals)
                    (parse-tree-node tag-sym
                                    (list->rrb vals)
                                    #f 0))
    #:component-lattices (make-list actual-arity 'atom)
    #:domain 'form
    #:sample (parse-tree-node tag-sym
                              (list->rrb sample-children)
                              #f 0)))

;; ========================================
;; Phase 2: Lifted Simple Rewrite Rules
;; ========================================
;; SRE spans for the 6 simple rewrites. Templates are parse-tree-nodes
;; with $punify-hole markers. Verified at definition time.
;;
;; NOTE: These are PARALLEL registrations alongside the existing lambda-based
;; rules in surface-rewrite.rkt. Phase 7 wires these as propagators and
;; retires the lambda-based rules.

(require "surface-rewrite.rkt")  ;; for tag constants

;; Helper: build a template node (parse-tree-node with potential holes)
(define (tpl tag . children)
  (parse-tree-node tag (list->rrb children) #f 0))

;; Helper: make a constant token for templates
(define (tpl-const lexeme)
  (token-entry (seteq 'constant) lexeme 0 (string-length lexeme)))

;; --- expand-if-3: (if cond then else) → (boolrec _ then else cond) ---
;; 4 children: [if-token, cond, then, else]
(define expand-if-3-span
  (sre-rewrite-rule
    'expand-if-3
    (pattern-desc 'if
      (list (child-pattern 0 'token "if" #f)
            (child-pattern 1 'any #f 'cond)
            (child-pattern 2 'any #f 'then)
            (child-pattern 3 'any #f 'else))
      #f)
    '(cond then else)
    (tpl tag-expr (tpl-const "boolrec") (tpl-const "_")
         (make-hole 'then) (make-hole 'else) (make-hole 'cond))
    'one-way 0 'strongly-confluent 'V0-2))
(verify-rewrite-rule expand-if-3-span)
(register-sre-rewrite-rule! expand-if-3-span)

;; --- expand-if-4: (if ResultType cond then else) → (boolrec ResultType then else cond) ---
;; 5 children: [if-token, type, cond, then, else]
(define expand-if-4-span
  (sre-rewrite-rule
    'expand-if-4
    (pattern-desc 'if
      (list (child-pattern 0 'token "if" #f)
            (child-pattern 1 'any #f 'result-type)
            (child-pattern 2 'any #f 'cond)
            (child-pattern 3 'any #f 'then)
            (child-pattern 4 'any #f 'else))
      #f)
    '(result-type cond then else)
    (tpl tag-expr (tpl-const "boolrec") (make-hole 'result-type)
         (make-hole 'then) (make-hole 'else) (make-hole 'cond))
    'one-way 0 'strongly-confluent 'V0-2))
(verify-rewrite-rule expand-if-4-span)
(register-sre-rewrite-rule! expand-if-4-span)

;; --- expand-when: (when cond body) → (if cond body unit) ---
;; 3 children: [when-token, cond, body]
(define expand-when-span
  (sre-rewrite-rule
    'expand-when
    (pattern-desc 'when
      (list (child-pattern 0 'token "when" #f)
            (child-pattern 1 'any #f 'cond)
            (child-pattern 2 'any #f 'body))
      #f)
    '(cond body)
    (tpl tag-if (tpl-const "if") (make-hole 'cond) (make-hole 'body) (tpl-const "unit"))
    'one-way 0 'strongly-confluent 'V0-2))
(verify-rewrite-rule expand-when-span)
(register-sre-rewrite-rule! expand-when-span)

;; --- expand-let-assign: (let name := val body...) → ((fn [name] body...) val) ---
;; 5+ children: [let-token, name, :=, val, body...]
(define expand-let-assign-span
  (sre-rewrite-rule
    'expand-let-assign
    (pattern-desc 'let-assign
      (list (child-pattern 0 'token "let" #f)
            (child-pattern 1 'any #f 'name)
            (child-pattern 2 'token ":=" #f)
            (child-pattern 3 'any #f 'value))
      'body)  ;; variadic tail
    '(name value body)
    ;; RHS: ((fn [name] body...) val)
    (tpl tag-expr
      (tpl tag-expr (tpl-const "fn")
           (tpl tag-expr (make-hole 'name))
           (make-splice 'body))
      (make-hole 'value))
    'one-way 0 'strongly-confluent 'V0-2))
(verify-rewrite-rule expand-let-assign-span)
(register-sre-rewrite-rule! expand-let-assign-span)

;; --- expand-let-bracket: (let [bindings] body...) → nested fn ---
;; 3+ children: [let-token, bracket-group, body...]
(define expand-let-bracket-span
  (sre-rewrite-rule
    'expand-let-bracket
    (pattern-desc 'let-bracket
      (list (child-pattern 0 'token "let" #f)
            (child-pattern 1 'node #f 'bindings))  ;; bracket group
      'body)
    '(bindings body)
    ;; RHS: ((fn [bindings] body...) — simplified; full nested let is fold scope)
    (tpl tag-expr (tpl-const "fn")
         (make-hole 'bindings)
         (make-splice 'body))
    'one-way 0 'strongly-confluent 'V0-2))
(verify-rewrite-rule expand-let-bracket-span)
(register-sre-rewrite-rule! expand-let-bracket-span)

;; --- expand-dot-access: (dot-access obj key) → (map-get obj :key) ---
;; Note: dot-access has its own handling in tree-parser; this span
;; represents the rewrite if it reaches the surface-rewrite pipeline.
;; Registered for completeness and critical pair analysis.

;; --- expand-compose (FIXED — only Track 2B left-to-right version): ---
;; (compose f g ...) → (fn [$_comp] (g (f $_comp)))
;; Track 2 version (right-to-left) is REMOVED — it was the duplicate bug.

;; ========================================
;; Phase 3a: Fold Combinator (PU Micro-Stratified)
;; ========================================
;; Sequential accumulation via micro-strata within a single Pocket Universe.
;; Progress is monotone (ascending Nat). Accumulator changes between
;; micro-strata (non-monotone, gated by progress — NAF-LE pattern).
;;
;; The fold combinator takes:
;;   - elements: list of nodes to fold over
;;   - base-case: the initial accumulator value
;;   - step-fn: (element accumulator → new-accumulator)
;; Returns: the final accumulator.
;;
;; Option C: one cell, no per-step allocation. Micro-strata execute
;; within a single pipeline cycle. Track 6 can upgrade to Option B
;; (per-step cells) if reduction interleaving is needed.

(struct fold-pu-state
  (progress      ;; Nat — micro-stratum index (ascending, monotone)
   accumulator   ;; node — built-up result (changes between micro-strata)
   elements      ;; (listof node) — original input (immutable)
   step-fn)      ;; (element accumulator → node) — the step rule
  #:transparent)

;; Run a right-fold to completion: apply step-fn from right to left.
;; foldr step base [e1, e2, e3] = step(e1, step(e2, step(e3, base)))
;; Returns the final accumulator.
(define (run-fold elements base-case step-fn)
  (foldr step-fn base-case elements))

;; Build a fold-based rewrite: decompose the node into elements,
;; fold them with a step template, return the result.
(define (apply-fold-rewrite node element-extractor base-case-fn step-fn)
  (define elements (element-extractor node))
  (define base (base-case-fn node))
  (run-fold elements base step-fn))

;; --- Fold rule: expand-list-literal ---
;; (list-literal e1 e2 ...) → (cons e1 (cons e2 ... nil))
(define (list-literal-step elem acc)
  (tpl tag-expr (tpl-const "cons") elem acc))

(define expand-list-literal-fold
  (sre-rewrite-rule
    'expand-list-literal-fold
    (pattern-desc 'list-literal (list) #f)  ;; tag match only
    '()  ;; K is implicit in fold — elements extracted from node
    #f   ;; no template — fold produces result directly
    'one-way 0 'strongly-confluent 'V0-2))
(register-sre-rewrite-rule! expand-list-literal-fold)

;; --- Fold rule: expand-lseq-literal ---
;; (lseq-literal e1 e2 ...) → (lseq-cell e1 (fn [_ : _] (lseq-cell e2 ... lseq-nil)))
(define (lseq-literal-step elem acc)
  (tpl tag-expr (tpl-const "lseq-cell") elem
       (tpl tag-expr (tpl-const "fn")
            (tpl tag-expr (tpl-const "_") (tpl-const ":") (tpl-const "_"))
            acc)))

(define expand-lseq-literal-fold
  (sre-rewrite-rule
    'expand-lseq-literal-fold
    (pattern-desc 'lseq-literal (list) #f)
    '() #f 'one-way 0 'strongly-confluent 'V0-2))
(register-sre-rewrite-rule! expand-lseq-literal-fold)

;; --- Fold rule: expand-do ---
;; (do e1 e2 ... en) → (let [_ := e1] (let [_ := e2] ... en))
(define (do-step elem acc)
  (tpl tag-expr (tpl-const "let") (tpl-const "_") (tpl-const ":=") elem acc))

(define expand-do-fold
  (sre-rewrite-rule
    'expand-do-fold
    (pattern-desc 'do (list) #f)
    '() #f 'one-way 0 'strongly-confluent 'V0-2))
(register-sre-rewrite-rule! expand-do-fold)

;; Note: expand-cond is more complex (arms need guard/body splitting).
;; It stays as the existing lambda-based rule for now. The fold combinator
;; infrastructure is in place for cond — the step function would need
;; arm-splitting logic that doesn't reduce cleanly to a single template.
;; This is documented as a known limitation for Phase 3a.

;; ========================================
;; Phase 3b: Tree-Structural Combinator
;; ========================================
;; Pocket Universe with per-position processing. Positions are independent
;; and can be processed in parallel within the PU. Results compose when
;; all positions are complete.
;;
;; The tree-structural combinator takes:
;;   - node: a parse-tree-node to transform
;;   - position-fn: (child → result) — processes each position independently
;; Returns: a new node with all positions processed.

(struct tree-pu-state
  (processed    ;; (seteq position-index) — which positions done (monotone)
   results      ;; (hasheq position-index → result) — per-position results
   original)    ;; parse-tree-node — the input tree
  #:transparent)

;; Process all positions of a tree node, producing per-position results.
;; Positions are independent — order doesn't matter.
(define (tree-structural-rewrite node position-fn)
  (cond
    [(not (parse-tree-node? node)) node]  ;; non-node → pass through
    [else
     (define children (rrb-to-list (parse-tree-node-children node)))
     (define results
       (for/list ([child (in-list children)])
         (position-fn child)))
     (parse-tree-node (parse-tree-node-tag node)
                      (list->rrb results)
                      (parse-tree-node-srcloc node)
                      (parse-tree-node-indent node))]))

;; Quasiquote position function: classify each child and produce datum constructor.
;; This is the per-position recognition for the quasiquote tree PU.
(define (quasiquote-position-fn child)
  (cond
    [(token-entry? child)
     (define lex (token-entry-lexeme child))
     (cond
       ;; Keyword → datum-kw
       [(and (> (string-length lex) 1) (char=? (string-ref lex 0) #\:))
        (tpl tag-expr (tpl-const "datum-kw") child)]
       ;; Boolean
       [(equal? lex "true")
        (tpl tag-expr (tpl-const "datum-bool") child)]
       [(equal? lex "false")
        (tpl tag-expr (tpl-const "datum-bool") child)]
       ;; Number (simple heuristic)
       [(and (> (string-length lex) 0)
             (or (char-numeric? (string-ref lex 0))
                 (and (char=? (string-ref lex 0) #\-)
                      (> (string-length lex) 1)
                      (char-numeric? (string-ref lex 1)))))
        (tpl tag-expr (tpl-const "datum-int") child)]
       ;; Default → datum-sym
       [else
        (tpl tag-expr (tpl-const "datum-sym")
             (tpl tag-expr (tpl-const "symbol-lit") child))])]
    ;; Node → recurse (nested PU), wrap in datum-list + cons chain
    [(parse-tree-node? child)
     (define child-results
       (for/list ([i (in-range (rrb-size (parse-tree-node-children child)))])
         (quasiquote-position-fn (rrb-get (parse-tree-node-children child) i))))
     ;; Fold into cons chain
     (define cons-chain (run-fold child-results (tpl-const "nil") list-literal-step))
     (tpl tag-expr (tpl-const "datum-list") cons-chain)]
    [else child]))

;; Register quasiquote as a tree-structural rule
(define expand-quasiquote-tree
  (sre-rewrite-rule
    'expand-quasiquote-tree
    (pattern-desc 'quasiquote (list) #f)
    '() #f 'one-way 0 'strongly-confluent 'V0-2))
(register-sre-rewrite-rule! expand-quasiquote-tree)

;; ========================================
;; Phase 2 summary: 5 simple rules lifted to SRE spans.
;; expand-dot-access and expand-implicit-map have tag-specific handling
;; in tree-parser.rkt — they don't go through surface-rewrite's pipeline.
;; compose duplicate is fixed by NOT re-registering the Track 2 version.
;; The remaining rules (fold: cond, do, list-literal, lseq-literal) are Phase 3a.
;; quasiquote is Phase 3b (tree-structural combinator).

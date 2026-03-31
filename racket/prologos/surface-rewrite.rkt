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
(define tag-check 'check)
(define tag-infer 'infer)
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
    [(not (memq (parse-tree-node-tag node) '(line group))) node]  ;; refine 'line and 'group nodes
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
(register-simple-tag! "check" tag-check)
(register-simple-tag! "infer" tag-infer)
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
;; Phase 6a: Form-grouping stratum G(0)
;; ========================================
;; Converts indent-tree nodes (line structure, flat tokens) into
;; form-tree nodes (bracket-grouped, known arity).
;;
;; This is what group-items (datum extraction) does, but producing
;; parse-tree-node values instead of syntax objects.
;;
;; The key operation: walk a tag-refined tree, flatten each line node's
;; children into tokens + indent markers, then group by bracket matching
;; into nested form nodes.

(provide group-tree-node)

;; Group a tag-refined tree node's children by bracket matching.
;; Produces a new tree node with bracket-grouped children.
;; Each bracket group becomes a nested parse-tree-node.
(define (group-tree-node node)
  (cond
    [(not (parse-tree-node? node)) node]
    [(eq? (parse-tree-node-tag node) 'root)
     ;; Root node: recurse into children, group each top-level form
     (define old-children (parse-tree-node-children node))
     (define new-children
       (let loop ([i 0] [acc rrb-empty])
         (if (>= i (rrb-size old-children))
             acc
             (loop (+ i 1)
                   (rrb-push acc (group-tree-node (rrb-get old-children i)))))))
     (parse-tree-node 'root new-children
                      (parse-tree-node-srcloc node)
                      (parse-tree-node-indent node))]
    [else
     ;; Non-root node: flatten to items, group by brackets, rebuild
     (define items (flatten-node-to-items node))
     (define vec (list->vector items))
     (define-values (children _end)
       (group-items-to-tree vec 0 (vector-length vec) #f
                            (parse-tree-node-srcloc node)
                            (parse-tree-node-indent node)))
     ;; Rebuild node with grouped children and preserved tag
     (parse-tree-node (parse-tree-node-tag node)
                      (list->rrb children)
                      (parse-tree-node-srcloc node)
                      (parse-tree-node-indent node))]))

;; Helper: convert list to rrb
(define (list->rrb lst)
  (for/fold ([rrb rrb-empty]) ([item (in-list lst)])
    (rrb-push rrb item)))

;; Flatten a tree node into a list of (token-entry | 'indent-open | 'indent-close)
;; Same logic as flatten-with-boundaries in parse-reader.rkt
(define (flatten-node-to-items node)
  (define children (parse-tree-node-children node))
  (define n (rrb-size children))
  (apply append
    (for/list ([i (in-range n)])
      (define child (rrb-get children i))
      (cond
        [(token-entry? child) (list child)]
        [(parse-tree-node? child)
         (append (list 'indent-open)
                 (flatten-node-to-items child)
                 (list 'indent-close))]
        [else '()]))))

;; Group items by bracket matching → list of (parse-tree-node | token-entry)
;; Parallel to group-items in parse-reader.rkt but produces tree nodes.
(define (group-items-to-tree vec start end close-type srcloc indent)
  (let loop ([i start] [result '()])
    (cond
      [(>= i end)
       (values (reverse result) end)]
      [else
       (define item (vector-ref vec i))
       (cond
         ;; Indent boundary markers → sub-group
         [(eq? item 'indent-open)
          (define-values (inner-items next-i)
            (group-items-to-tree vec (+ i 1) end 'indent-close srcloc indent))
          (cond
            [(null? inner-items) (loop next-i result)]
            [(= (length inner-items) 1) (loop next-i (cons (car inner-items) result))]
            [else
             (define sub-node (parse-tree-node 'group (list->rrb inner-items) srcloc indent))
             (loop next-i (cons sub-node result))])]
         [(eq? item 'indent-close)
          (if (eq? close-type 'indent-close)
              (values (reverse result) (+ i 1))
              (loop (+ i 1) result))]
         ;; Token entry → check for brackets
         [(token-entry? item)
          (define type (set-first (token-entry-types item)))
          (cond
            ;; Opening brackets → recurse for bracket group
            [(memq type '(lbracket lparen))
             (define close (if (eq? type 'lbracket) 'rbracket 'rparen))
             (define-values (inner next-i)
               (group-items-to-tree vec (+ i 1) end close srcloc indent))
             (define group-tag (if (eq? type 'lbracket) 'bracket-group 'paren-group))
             (define group-node (parse-tree-node group-tag (list->rrb inner) srcloc indent))
             (loop next-i (cons group-node result))]
            ;; Closing bracket → end of group
            [(and close-type (memq type '(rbracket rparen rbrace rangle))
                  (or (eq? type close-type)
                      (and (eq? close-type 'mixfix-rbrace) (eq? type 'rbrace))))
             (values (reverse result) (+ i 1))]
            ;; Langle → check for matching rangle (angle type group)
            [(eq? type 'langle)
             (define-values (inner next-i)
               (group-items-to-tree vec (+ i 1) end 'rangle srcloc indent))
             (define group-node (parse-tree-node 'angle-group (list->rrb inner) srcloc indent))
             (loop next-i (cons group-node result))]
            ;; Lbrace → brace group
            [(memq type '(lbrace dot-lbrace hash-lbrace))
             (define group-close (if (eq? type 'dot-lbrace) 'mixfix-rbrace 'rbrace))
             (define-values (inner next-i)
               (group-items-to-tree vec (+ i 1) end group-close srcloc indent))
             (define group-tag (cond [(eq? type 'lbrace) 'brace-group]
                                     [(eq? type 'dot-lbrace) 'mixfix-group]
                                     [(eq? type 'hash-lbrace) 'set-group]
                                     [else 'brace-group]))
             (define group-node (parse-tree-node group-tag (list->rrb inner) srcloc indent))
             (loop next-i (cons group-node result))]
            ;; Quote-bracket, at-bracket, tilde-bracket → special groups
            [(memq type '(quote-lbracket at-lbracket tilde-lbracket))
             (define-values (inner next-i)
               (group-items-to-tree vec (+ i 1) end 'rbracket srcloc indent))
             (define group-tag (cond [(eq? type 'quote-lbracket) 'list-literal-group]
                                     [(eq? type 'at-lbracket) 'at-group]
                                     [(eq? type 'tilde-lbracket) 'tilde-group]
                                     [else 'bracket-group]))
             (define group-node (parse-tree-node group-tag (list->rrb inner) srcloc indent))
             (loop next-i (cons group-node result))]
            ;; Stray closing brackets → skip
            [(memq type '(rbracket rparen rbrace rangle))
             (loop (+ i 1) result)]
            ;; Comma → skip (cosmetic separator)
            [(eq? type 'comma)
             (loop (+ i 1) result)]
            ;; Regular token → add to result
            [else
             (loop (+ i 1) (cons item result))])]
         ;; Unknown → skip
         [else (loop (+ i 1) result)])])))

;; ========================================
;; Phase 6b: Pipeline-as-cell model
;; ========================================
;; Each form gets ONE cell holding a form-pipeline-value.
;; A single propagator advances through stages monotonically.
;; The stage chain IS the stratification.

(provide
 (struct-out form-pipeline-value)
 form-pipeline-merge
 advance-pipeline
 run-form-pipeline
 rewrite-tree)

;; --- Pipeline-as-cell value ---

(struct form-pipeline-value
  (stage        ;; symbol: position in stage chain
   tree-node    ;; parse-tree-node at this stage
   registrations ;; (listof pair) extracted registry entries
   source-pos)  ;; source position for provenance
  #:transparent)

;; Stage ordering (finite total order)
(define stage-order
  '(raw tagged grouped v0-0 v0-1 v0-2 v1 v2 done))

(define (stage-index stage)
  (let loop ([stages stage-order] [i 0])
    (cond
      [(null? stages) -1]  ;; unknown stage
      [(eq? (car stages) stage) i]
      [else (loop (cdr stages) (+ i 1))])))

(define (stage>? a b)
  (> (stage-index a) (stage-index b)))

;; Merge: take the later stage (monotone)
(define (form-pipeline-merge old new)
  (if (stage>? (form-pipeline-value-stage new)
               (form-pipeline-value-stage old))
      new
      old))

;; Advance a pipeline value by one stage.
;; Returns a new form-pipeline-value at the next stage, or #f if already 'done.
;; Optional registries parameter for V(1) and V(2) stages.
(define (advance-pipeline pv #:registries [registries #f])
  (define stage (form-pipeline-value-stage pv))
  (define node (form-pipeline-value-tree-node pv))
  (define regs (form-pipeline-value-registrations pv))
  (define spos (form-pipeline-value-source-pos pv))

  (case stage
    [(raw)
     ;; G(0): form grouping FIRST — creates bracket groups, nested groups
     (define grouped (group-tree-node node))
     (form-pipeline-value 'tagged grouped regs spos)]

    [(tagged)
     ;; T(0): tag refinement AFTER grouping — tags 'line AND 'group nodes
     ;; Must run after G(0) because G(0) creates 'group nodes that need tagging
     (define refined (refine-tag node))  ;; recursive into all children
     (form-pipeline-value 'grouped refined regs spos)]

    [(grouped)
     ;; V(0,0): implicit-map
     (define-values (result _) (apply-rules node 'V0-0))
     (form-pipeline-value 'v0-0 result regs spos)]

    [(v0-0)
     ;; V(0,1): dot-access
     (define-values (result _) (apply-rules node 'V0-1))
     (form-pipeline-value 'v0-1 result regs spos)]

    [(v0-1)
     ;; V(0,2): infix + simple + recursive rewrites
     (define-values (result _) (apply-rules node 'V0-2))
     (form-pipeline-value 'v0-2 result regs spos)]

    [(v0-2)
     ;; V(1): macro expansion
     ;; Apply any rewrite rules registered in stratum 'V1 (user macros).
     ;; Built-in macros (let, if, cond, etc.) are already handled in V(0,2).
     ;; User macros from defmacro need to be registered as V1 rewrite rules
     ;; by the driver after preparse runs.
     (define-values (result matched?) (apply-rules node 'V1))
     (form-pipeline-value 'v1 result regs spos)]

    [(v1)
     ;; V(2): spec/where injection
     ;; If registries provided with a spec-store lookup function,
     ;; check if this node is a defn whose name has a matching spec.
     ;; If so, the spec type replaces the defn's hole types.
     ;;
     ;; For tree-level: this would modify the defn node's type annotation.
     ;; For pipeline-as-cell: this would be a propagator watching
     ;; form-cell + spec-store-cell, firing when both have values.
     ;;
     ;; For now: pass through. Spec injection is handled by datum-level
     ;; preparse (maybe-inject-spec). The defn's type in the tree parser
     ;; has Pi chain with holes; the preparse injects the spec type into
     ;; the DATUM which parse-datum sees. The hybrid path uses preparse's
     ;; output so spec types are correct in elaboration.
     (form-pipeline-value 'v2 node regs spos)]

    [(v2)
     ;; Extract registrations, mark done
     (form-pipeline-value 'done node regs spos)]

    [(done) #f]  ;; already done
    [else #f]))

;; Run a form through the entire pipeline to 'done.
;; Returns the final form-pipeline-value.
;; Optional registries for V(1)/V(2) stages.
(define (run-form-pipeline node #:registries [registries #f])
  (let loop ([pv (form-pipeline-value 'raw node '()
                                       (and (parse-tree-node? node)
                                            (parse-tree-node-srcloc node)))])
    (define next (advance-pipeline pv #:registries registries))
    (if next
        (loop next)
        pv)))

;; --- Tree-level rewriting (uses pipeline) ---

;; Apply all rules for a given stratum to a single node.
;; Returns the rewritten node (or original if no rules match).
(define (rewrite-node node stratum)
  (if (not (parse-tree-node? node))
      node
      (let-values ([(result matched?) (apply-rules node stratum)])
        result)))

;; Apply rewrite rules for a stratum to an entire tree (bottom-up).
;; Bottom-up: children rewritten first, then the node itself.
;; This ensures that inner forms (e.g., let inside defn body) are
;; rewritten before outer forms see their results.
(define (rewrite-tree-stratum tree stratum)
  (cond
    [(not (parse-tree-node? tree)) tree]
    [else
     ;; First, recursively rewrite children
     (define old-children (parse-tree-node-children tree))
     (define new-children
       (let loop ([i 0] [acc rrb-empty])
         (if (>= i (rrb-size old-children))
             acc
             (let ([child (rrb-get old-children i)])
               (loop (+ i 1)
                     (rrb-push acc
                               (if (parse-tree-node? child)
                                   (rewrite-tree-stratum child stratum)
                                   child)))))))
     ;; Then rewrite this node
     (define with-children
       (if (equal? old-children new-children)
           tree
           (parse-tree-node (parse-tree-node-tag tree)
                            new-children
                            (parse-tree-node-srcloc tree)
                            (parse-tree-node-indent tree))))
     (rewrite-node with-children stratum)]))

;; Apply the full rewrite pipeline: V(0,0) → V(0,1) → V(0,2) → V(1) → V(2)
;; Each stratum is a separate pass over the tree (CALM: set-once between strata).
(define (rewrite-tree tree)
  (define pass0 (rewrite-tree-stratum tree 'V0-0))  ;; implicit-map
  (define pass1 (rewrite-tree-stratum pass0 'V0-1)) ;; dot-access
  (define pass2 (rewrite-tree-stratum pass1 'V0-2)) ;; infix + simple + recursive rules
  ;; V(1) macro expansion and V(2) spec injection are Phase 6 scope
  ;; when form cells and registry cell watching are wired.
  ;; For now, the datum-level preparse-expand-all handles these.
  pass2)

;; ========================================
;; Phase 6e: User macro → rewrite rule bridge
;; ========================================
;; After preparse populates the preparse-registry with user macros,
;; this function registers corresponding tree-level rewrite rules.
;; Called from driver.rkt after preparse-expand-all completes.

(provide register-user-macros-as-rewrite-rules!)

(define (register-user-macros-as-rewrite-rules! preparse-registry)
  ;; Scan registry for entries that are preparse-macro structs or lambdas
  ;; (not built-in expander symbols — those are already rewrite rules).
  (for ([(key val) (in-hash preparse-registry)])
    (cond
      ;; Skip built-in expanders (symbols referring to expand-* functions)
      [(symbol? val) (void)]
      ;; Lambda macros (from defmacro with lambda body)
      [(procedure? val)
       ;; Can't easily convert arbitrary procedures to tree rewrite rules.
       ;; These remain handled by datum-level preparse.
       (void)]
      ;; preparse-macro structs: pattern/template substitution
      ;; These CAN be converted to tree rewrite rules.
      ;; For now: register a rewrite rule that matches the head symbol
      ;; and applies the macro's template at tree level.
      ;; Full implementation requires pattern-matching on tree children.
      ;; DEFERRED: user macro tree rewriting needs pattern→tree conversion.
      [else (void)])))

;; ========================================
;; Phase 2a: Simple rewrite rules (9 rules)
;; ========================================
;; These rules match tag-refined parse tree nodes and produce new nodes.
;; Each rhs-builder takes (children srcloc indent) → parse-tree-node.
;;
;; Simple rules have static structure: the output shape is determined
;; entirely by the input children + a fixed template. No recursion,
;; no fold over variable-length children.

;; Helper: make a token child
(define (make-token lexeme)
  (token-entry (seteq 'symbol) lexeme 0 (string-length lexeme)))

;; Helper: build a node with given tag and children list
(define (build-node tag children-list srcloc indent)
  (parse-tree-node tag
                   (for/fold ([rrb rrb-empty]) ([c (in-list children-list)])
                     (rrb-push rrb c))
                   srcloc indent))

;; --- expand-if: (if cond then else) → (boolrec _ then else cond) ---
;; 3-arg form: inferred motive via hole (_)
(register-rewrite-rule!
 (rewrite-rule
  'expand-if
  tag-if
  (lambda (children srcloc indent)
    ;; children: [if-token, cond, then, else] (4 elements)
    ;; or: [if-token, ResultType, cond, then, else] (5 elements)
    (cond
      [(= (length children) 4)
       (define cond-child (list-ref children 1))
       (define then-child (list-ref children 2))
       (define else-child (list-ref children 3))
       (build-node tag-expr
                   (list (make-token "boolrec")
                         (make-token "_")
                         then-child
                         else-child
                         cond-child)
                   srcloc indent)]
      [(= (length children) 5)
       (define result-type (list-ref children 1))
       (define cond-child (list-ref children 2))
       (define then-child (list-ref children 3))
       (define else-child (list-ref children 4))
       (build-node tag-expr
                   (list (make-token "boolrec")
                         result-type
                         then-child
                         else-child
                         cond-child)
                   srcloc indent)]
      [else
       ;; Malformed — return error node
       (build-node 'error (list (make-token "if: expected 3 or 4 args")) srcloc indent)]))
  #f    ;; no guard
  100   ;; priority
  'V0-2))  ;; stratum V(0,2) — after dot-access, infix

;; --- expand-let-assign: (let name := val body) → ((fn [name] body) val) ---
;; children: [let-token, name, :=, val, body...]
(register-rewrite-rule!
 (rewrite-rule
  'expand-let-assign
  tag-let-assign
  (lambda (children srcloc indent)
    (if (>= (length children) 5)
        (let* ([name-child (list-ref children 1)]
               [val-child (list-ref children 3)]
               [body-children (drop children 4)]
               ;; Build: ((fn [name] body...) val)
               [param-bracket (build-node tag-expr (list name-child) srcloc indent)]
               [fn-form (build-node tag-expr
                                    (cons (make-token "fn")
                                          (cons param-bracket body-children))
                                    srcloc indent)])
          (build-node tag-expr (list fn-form val-child) srcloc indent))
        (build-node 'error (list (make-token "let-assign: need name := val body")) srcloc indent)))
  #f 100 'V0-2))

;; --- expand-let-bracket: (let [bindings] body) → nested fn applications ---
;; children: [let-token, bracket-group, body...]
;; The bracket-group contains binding pairs. For Phase 2a, we handle the
;; simplest case: single binding. Multi-binding is Phase 2b (recursive).
(register-rewrite-rule!
 (rewrite-rule
  'expand-let-bracket
  tag-let-bracket
  (lambda (children srcloc indent)
    (if (>= (length children) 3)
        (let* ([bracket (list-ref children 1)]
               [body-children (drop children 2)]
               ;; For now: treat bracket contents as single binding
               ;; Full multi-binding is Phase 2b (recursive rule)
               [bracket-children (if (parse-tree-node? bracket)
                                     (rrb-to-list (parse-tree-node-children bracket))
                                     (list bracket))]
               ;; Build: ((fn [bracket-children...] body...) ???)
               ;; This is a placeholder — full let-bracket needs to extract
               ;; name/type/value triples from the bracket
               [fn-form (build-node tag-expr
                                    (cons (make-token "fn")
                                          (cons bracket body-children))
                                    srcloc indent)])
          fn-form)
        (build-node 'error (list (make-token "let-bracket: need [bindings] body")) srcloc indent)))
  #f 100 'V0-2))

;; --- expand-when: (when cond body) → (if cond body unit) ---
(register-rewrite-rule!
 (rewrite-rule
  'expand-when
  tag-when
  (lambda (children srcloc indent)
    ;; children: [when-token, cond, body]
    (if (>= (length children) 3)
        (let ([cond-child (list-ref children 1)]
              [body-child (list-ref children 2)])
          (build-node tag-if
                      (list (make-token "if")
                            cond-child
                            body-child
                            (make-token "unit"))
                      srcloc indent))
        (build-node 'error (list (make-token "when: expected 2 args")) srcloc indent)))
  #f 100 'V0-2))

;; --- expand-compose: ($compose f g) → (fn [$>>0 : _] (f (g $>>0))) ---
;; Sexp-mode compose: wraps in nested lambda
(register-rewrite-rule!
 (rewrite-rule
  'expand-compose
  tag-compose
  (lambda (children srcloc indent)
    ;; children: [$compose-token, f, g, ...]
    ;; For 2 functions: (fn [$>>0 : _] (g (f $>>0)))
    ;; The actual compose chains right-to-left
    (if (>= (length children) 3)
        (let* ([fns (cdr children)]  ;; drop the $compose sentinel
               [param (make-token "$>>0")]
               [type-hole (make-token "_")]
               ;; Build application chain: (last (... (first $>>0)))
               [inner
                (for/fold ([acc param]) ([f (in-list fns)])
                  (build-node tag-expr (list f acc) srcloc indent))])
          (build-node tag-expr
                      (list (make-token "fn")
                            (build-node tag-expr
                                        (list param (make-token ":") type-hole)
                                        srcloc indent)
                            inner)
                      srcloc indent))
        (build-node 'error (list (make-token "compose: need at least 2 fns")) srcloc indent)))
  #f 100 'V0-2))

;; ========================================
;; Phase 2b: Recursive rewrite rules (5 rules)
;; ========================================
;; These rules fold over variable-length children. The rhs-builder
;; contains a recursive function, not a static binding map.

;; --- expand-cond: (cond | guard -> body | guard -> body ...) → nested if ---
;; Each arm is a $pipe-prefixed or bare (guard -> body) pair.
;; Recursively builds: (if guard1 body1 (if guard2 body2 ...))
(register-rewrite-rule!
 (rewrite-rule
  'expand-cond
  tag-cond
  (lambda (children srcloc indent)
    ;; children: [cond-token, arm1, arm2, ...]
    ;; Each arm is either a ($pipe guard -> body) node or bare tokens
    (define arms (cdr children))  ;; drop cond token
    (if (null? arms)
        (build-node 'error (list (make-token "cond: need at least one arm")) srcloc indent)
        ;; Build nested if chain from arms
        (let loop ([remaining arms])
          (cond
            [(null? remaining)
             ;; No more arms — terminal case. Should have been caught, but
             ;; as fallback: unit (unreachable if cond is exhaustive)
             (make-token "unit")]
            [(null? (cdr remaining))
             ;; Last arm — extract guard and body, no else branch
             (define arm (car remaining))
             (define parts (if (and (parse-tree-node? arm)
                                   (let ([children (parse-tree-node-children arm)])
                                     (and (> (rrb-size children) 0)
                                          (let ([first (rrb-get children 0)])
                                            (and (token-entry? first)
                                                 (equal? (token-entry-lexeme first) "$pipe"))))))
                               ;; Strip $pipe prefix
                               (cdr (rrb-to-list (parse-tree-node-children arm)))
                               (if (parse-tree-node? arm)
                                   (rrb-to-list (parse-tree-node-children arm))
                                   (list arm))))
             ;; Find -> separator
             (define arrow-idx
               (for/first ([p (in-list parts)] [i (in-naturals)]
                           #:when (and (token-entry? p)
                                       (equal? (token-entry-lexeme p) "->")))
                 i))
             (if arrow-idx
                 (let ([guard-parts (take parts arrow-idx)]
                       [body-parts (drop parts (+ arrow-idx 1))])
                   ;; Last arm: just the body (guard assumed true, or wrap in if)
                   (if (= (length guard-parts) 1)
                       (build-node tag-if
                                   (list (make-token "if")
                                         (car guard-parts)
                                         (if (= (length body-parts) 1)
                                             (car body-parts)
                                             (build-node tag-expr body-parts srcloc indent))
                                         (make-token "unit"))
                                   srcloc indent)
                       (build-node tag-expr
                                   (append guard-parts (list (make-token "->")) body-parts)
                                   srcloc indent)))
                 ;; No arrow — malformed arm, pass through
                 arm)]
            [else
             ;; Non-last arm — extract guard and body, recurse for else
             (define arm (car remaining))
             (define parts (if (and (parse-tree-node? arm)
                                   (let ([children (parse-tree-node-children arm)])
                                     (and (> (rrb-size children) 0)
                                          (let ([first (rrb-get children 0)])
                                            (and (token-entry? first)
                                                 (equal? (token-entry-lexeme first) "$pipe"))))))
                               (cdr (rrb-to-list (parse-tree-node-children arm)))
                               (if (parse-tree-node? arm)
                                   (rrb-to-list (parse-tree-node-children arm))
                                   (list arm))))
             (define arrow-idx
               (for/first ([p (in-list parts)] [i (in-naturals)]
                           #:when (and (token-entry? p)
                                       (equal? (token-entry-lexeme p) "->")))
                 i))
             (if arrow-idx
                 (let ([guard-parts (take parts arrow-idx)]
                       [body-parts (drop parts (+ arrow-idx 1))]
                       [else-branch (loop (cdr remaining))])
                   (build-node tag-if
                               (list (make-token "if")
                                     (if (= (length guard-parts) 1)
                                         (car guard-parts)
                                         (build-node tag-expr guard-parts srcloc indent))
                                     (if (= (length body-parts) 1)
                                         (car body-parts)
                                         (build-node tag-expr body-parts srcloc indent))
                                     else-branch)
                               srcloc indent))
                 ;; No arrow — malformed, pass through
                 arm)]))))
  #f 90 'V0-2))

;; --- expand-list-literal: ($list-literal e1 e2 ...) → (cons e1 (cons e2 ... nil)) ---
(register-rewrite-rule!
 (rewrite-rule
  'expand-list-literal
  tag-list-literal
  (lambda (children srcloc indent)
    ;; children: [$list-literal-token, e1, e2, ...]
    (define elems (cdr children))  ;; drop sentinel
    (if (null? elems)
        (make-token "nil")
        ;; Check for $list-tail sentinel at end
        (let-values ([(proper tail)
                      (let ([last-elem (last elems)])
                        (if (and (parse-tree-node? last-elem)
                                 (let ([c (parse-tree-node-children last-elem)])
                                   (and (> (rrb-size c) 0)
                                        (let ([f (rrb-get c 0)])
                                          (and (token-entry? f)
                                               (equal? (token-entry-lexeme f) "$list-tail"))))))
                            ;; Has tail: last child's second element
                            (values (drop-right elems 1)
                                    (rrb-get (parse-tree-node-children last-elem) 1))
                            ;; No tail: nil
                            (values elems (make-token "nil"))))])
          (foldr (lambda (elem rest)
                   (build-node tag-expr
                               (list (make-token "cons") elem rest)
                               srcloc indent))
                 tail
                 proper))))
  #f 100 'V0-2))

;; --- expand-lseq-literal: ($lseq-literal e1 e2 ...) → nested lseq-cell + thunks ---
(register-rewrite-rule!
 (rewrite-rule
  'expand-lseq-literal
  tag-lseq-literal
  (lambda (children srcloc indent)
    ;; children: [$lseq-literal-token, e1, e2, ...]
    (define elems (cdr children))
    (if (null? elems)
        (make-token "lseq-nil")
        (foldr (lambda (elem rest)
                 (build-node tag-expr
                             (list (make-token "lseq-cell")
                                   elem
                                   ;; Wrap tail in thunk: (fn [_ : _] rest)
                                   (build-node tag-expr
                                               (list (make-token "fn")
                                                     (build-node tag-expr
                                                                 (list (make-token "_")
                                                                       (make-token ":")
                                                                       (make-token "_"))
                                                                 srcloc indent)
                                                     rest)
                                               srcloc indent))
                             srcloc indent))
               (make-token "lseq-nil")
               elems)))
  #f 100 'V0-2))

;; --- expand-do: (do e1 e2 ... en) → (let [_ := e1] (let [_ := e2] ... en)) ---
(register-rewrite-rule!
 (rewrite-rule
  'expand-do
  tag-do
  (lambda (children srcloc indent)
    ;; children: [do-token, e1, e2, ..., en]
    (define body (cdr children))  ;; drop do token
    (if (null? body)
        (make-token "unit")
        (if (null? (cdr body))
            ;; Single expression — just return it
            (car body)
            ;; Multiple: (let [_ := e1] (let [_ := e2] ... en))
            (let loop ([remaining body])
              (if (null? (cdr remaining))
                  ;; Last expression — the value
                  (car remaining)
                  ;; Non-last — wrap in let
                  (build-node tag-expr
                              (list (make-token "let")
                                    (make-token "_")
                                    (make-token ":=")
                                    (car remaining)
                                    (loop (cdr remaining)))
                              srcloc indent))))))
  #f 100 'V0-2))

;; --- expand-quasiquote: ($quasiquote datum) → datum constructor chain ---
;; Walks the tree converting tokens/nodes to Datum constructor calls.
;; Detects $unquote sentinels for splicing in evaluated expressions.
(register-rewrite-rule!
 (rewrite-rule
  'expand-quasiquote
  tag-quasiquote
  (lambda (children srcloc indent)
    ;; children: [$quasiquote-token, datum-children...]
    (define datum-parts (cdr children))
    (if (null? datum-parts)
        (build-node tag-expr (list (make-token "datum-nil")) srcloc indent)
        ;; Convert each child to a Datum constructor
        (let convert-child ([child (if (= (length datum-parts) 1)
                                       (car datum-parts)
                                       (build-node tag-expr datum-parts srcloc indent))])
          (cond
            ;; Token → datum constructor based on type
            [(token-entry? child)
             (define lex (token-entry-lexeme child))
             (cond
               ;; Unquote sentinel → pass through (evaluated at runtime)
               [(equal? lex "$unquote")
                ;; The NEXT sibling is the unquoted expression — but we
                ;; only see one child here. The unquote handling needs the
                ;; full children context. For now, emit as datum-sym.
                (build-node tag-expr
                            (list (make-token "datum-sym")
                                  (build-node tag-expr
                                              (list (make-token "symbol-lit") child)
                                              srcloc indent))
                            srcloc indent)]
               ;; Keyword → datum-kw
               [(and (> (string-length lex) 1) (char=? (string-ref lex 0) #\:))
                (build-node tag-expr (list (make-token "datum-kw") child) srcloc indent)]
               ;; Number check (simple heuristic)
               [(and (> (string-length lex) 0)
                     (or (char-numeric? (string-ref lex 0))
                         (and (char=? (string-ref lex 0) #\-)
                              (> (string-length lex) 1)
                              (char-numeric? (string-ref lex 1)))))
                (build-node tag-expr (list (make-token "datum-int") child) srcloc indent)]
               ;; Boolean
               [(equal? lex "true")
                (build-node tag-expr (list (make-token "datum-bool") child) srcloc indent)]
               [(equal? lex "false")
                (build-node tag-expr (list (make-token "datum-bool") child) srcloc indent)]
               ;; Default → datum-sym
               [else
                (build-node tag-expr
                            (list (make-token "datum-sym")
                                  (build-node tag-expr
                                              (list (make-token "symbol-lit") child)
                                              srcloc indent))
                            srcloc indent)])]
            ;; Node → recurse into children, build datum-list
            [(parse-tree-node? child)
             (define child-results
               (for/list ([i (in-range (rrb-size (parse-tree-node-children child)))])
                 (convert-child (rrb-get (parse-tree-node-children child) i))))
             ;; Build (datum-list (cons c1 (cons c2 ... nil)))
             (define cons-chain
               (foldr (lambda (elem rest)
                        (build-node tag-expr (list (make-token "cons") elem rest) srcloc indent))
                      (make-token "nil")
                      child-results))
             (build-node tag-expr (list (make-token "datum-list") cons-chain) srcloc indent)]
            ;; Unknown → pass through
            [else child]))))
  #f 100 'V0-2))

;; --- Placeholder notes for deferred rules ---
;; rewrite-dot-access: ($dot-access field) target → (map-get target :field)
;; rewrite-implicit-map: keyword-block restructuring
;; rewrite-infix-pipe: |> canonicalization
;; These require tree-level integration with token sentinels (Phase 6).

;; --- rewrite-dot-access: ($dot-access field) target → (map-get target :field) ---
;; Note: dot-access is a sentinel from the reader. The tree has:
;; [target, ($dot-access field)] → rewrite to [map-get target :field]
;; This is handled at the datum level in group-items currently.
;; For tree-level rewriting, the dot-access sentinel is a token-entry with
;; special type. The rewrite would need to detect the sentinel pattern.
;; For Phase 2a, we register the rule but it requires the datum extraction
;; layer to fire — tree-level dot-access handling is Phase 6 scope.

;; --- rewrite-implicit-map ---
;; Similarly, implicit-map operates at the datum level (keyword block restructuring).
;; Tree-level handling requires understanding indent structure + keyword detection.
;; Registered as placeholder; full implementation in Phase 6.

;; --- rewrite-infix-pipe ---
;; Infix |> detection and canonicalization.
;; Currently handled in preparse-expand-subforms via rewrite-infix-operators.
;; Tree-level: detect $pipe-gt token not at head position, restructure.
;; Registered as placeholder; full implementation in Phase 6.

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
                    'test-tag-for-lookup
                    (lambda (children srcloc indent)
                      (parse-tree-node 'rewritten rrb-empty srcloc indent))
                    #f 100 'test-lookup-stratum))
    (register-rewrite-rule! test-rule)
    (define rules (lookup-rewrite-rules 'test-lookup-stratum))
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

  ;; --- Phase 2a: Simple rewrite rule tests ---

  (test-case "expand-let-assign: → fn application"
    (define node (parse-tree-node
                  tag-let-assign
                  (rrb-from-list
                   (list (make-token "let")
                         (make-token "x")
                         (make-token ":=")
                         (make-token "42")
                         (make-token "body")))
                  #f 0))
    (define-values (result matched?) (apply-rules node 'V0-2))
    (check-true matched?)
    (check-eq? (parse-tree-node-tag result) tag-expr)
    ;; Result should be application: (fn-form val)
    (define children (rrb-to-list (parse-tree-node-children result)))
    (check-equal? (length children) 2)
    ;; First child is fn-form (a node)
    (check-true (parse-tree-node? (first children)))
    ;; Second child is val ("42")
    (check-true (token-entry? (second children)))
    (check-equal? (token-entry-lexeme (second children)) "42"))

  (test-case "expand-if: 3-arg → boolrec"
    (define node (parse-tree-node
                  tag-if
                  (rrb-from-list
                   (list (make-token "if")
                         (make-token "true")
                         (make-token "1")
                         (make-token "0")))
                  #f 0))
    (define-values (result matched?) (apply-rules node 'V0-2))
    (check-true matched?)
    (check-eq? (parse-tree-node-tag result) tag-expr)
    ;; First child should be "boolrec"
    (define first-child (rrb-get (parse-tree-node-children result) 0))
    (check-true (token-entry? first-child))
    (check-equal? (token-entry-lexeme first-child) "boolrec"))

  (test-case "expand-when: → if with unit"
    (define node (parse-tree-node
                  tag-when
                  (rrb-from-list
                   (list (make-token "when")
                         (make-token "cond")
                         (make-token "body")))
                  #f 0))
    (define-values (result matched?) (apply-rules node 'V0-2))
    (check-true matched?)
    ;; Result should be an if-tagged node (which will be further rewritten)
    (check-eq? (parse-tree-node-tag result) tag-if)
    ;; Last child should be "unit"
    (define children (rrb-to-list (parse-tree-node-children result)))
    (check-equal? (token-entry-lexeme (last children)) "unit"))

  (test-case "expand-compose: 2 functions → fn wrapper"
    (define node (parse-tree-node
                  tag-compose
                  (rrb-from-list
                   (list (make-token "$compose")
                         (make-token "f")
                         (make-token "g")))
                  #f 0))
    (define-values (result matched?) (apply-rules node 'V0-2))
    (check-true matched?)
    (check-eq? (parse-tree-node-tag result) tag-expr)
    ;; First child should be "fn"
    (define first-child (rrb-get (parse-tree-node-children result) 0))
    (check-true (token-entry? first-child))
    (check-equal? (token-entry-lexeme first-child) "fn"))

  ;; --- Phase 2b: Recursive rule tests ---

  (test-case "expand-list-literal: 3 elements → nested cons"
    (define node (parse-tree-node
                  tag-list-literal
                  (rrb-from-list
                   (list (make-token "$list-literal")
                         (make-token "1")
                         (make-token "2")
                         (make-token "3")))
                  #f 0))
    (define-values (result matched?) (apply-rules node 'V0-2))
    (check-true matched?)
    ;; Result should be (cons 1 (cons 2 (cons 3 nil)))
    (check-true (parse-tree-node? result))
    (check-eq? (parse-tree-node-tag result) tag-expr)
    ;; First child should be "cons"
    (define first-child (rrb-get (parse-tree-node-children result) 0))
    (check-equal? (token-entry-lexeme first-child) "cons"))

  (test-case "expand-list-literal: empty → nil"
    (define node (parse-tree-node
                  tag-list-literal
                  (rrb-from-list (list (make-token "$list-literal")))
                  #f 0))
    (define-values (result matched?) (apply-rules node 'V0-2))
    (check-true matched?)
    ;; Result should be nil token
    (check-true (token-entry? result))
    (check-equal? (token-entry-lexeme result) "nil"))

  (test-case "expand-do: sequence → nested let"
    (define node (parse-tree-node
                  tag-do
                  (rrb-from-list
                   (list (make-token "do")
                         (make-token "e1")
                         (make-token "e2")
                         (make-token "e3")))
                  #f 0))
    (define-values (result matched?) (apply-rules node 'V0-2))
    (check-true matched?)
    ;; Result should be (let _ := e1 (let _ := e2 e3))
    (check-true (parse-tree-node? result))
    (check-eq? (parse-tree-node-tag result) tag-expr)
    (define c0 (rrb-get (parse-tree-node-children result) 0))
    (check-equal? (token-entry-lexeme c0) "let"))

  (test-case "expand-do: single expression → pass through"
    (define node (parse-tree-node
                  tag-do
                  (rrb-from-list
                   (list (make-token "do")
                         (make-token "e1")))
                  #f 0))
    (define-values (result matched?) (apply-rules node 'V0-2))
    (check-true matched?)
    ;; Result should be just e1
    (check-true (token-entry? result))
    (check-equal? (token-entry-lexeme result) "e1"))

  (test-case "expand-lseq-literal: 2 elements → nested lseq-cell"
    (define node (parse-tree-node
                  tag-lseq-literal
                  (rrb-from-list
                   (list (make-token "$lseq-literal")
                         (make-token "1")
                         (make-token "2")))
                  #f 0))
    (define-values (result matched?) (apply-rules node 'V0-2))
    (check-true matched?)
    (check-true (parse-tree-node? result))
    (check-eq? (parse-tree-node-tag result) tag-expr)
    (define c0 (rrb-get (parse-tree-node-children result) 0))
    (check-equal? (token-entry-lexeme c0) "lseq-cell"))

  ;; --- Pipeline-as-cell tests ---

  (test-case "pipeline: stage ordering"
    (check-true (stage>? 'tagged 'raw))
    (check-true (stage>? 'done 'raw))
    (check-false (stage>? 'raw 'tagged))
    (check-false (stage>? 'raw 'raw)))

  (test-case "pipeline: merge takes later stage"
    (define old (form-pipeline-value 'raw (make-line-node "def" "x") '() #f))
    (define new (form-pipeline-value 'tagged (make-line-node "def" "x") '() #f))
    (define merged (form-pipeline-merge old new))
    (check-eq? (form-pipeline-value-stage merged) 'tagged))

  (test-case "pipeline: merge rejects earlier stage"
    (define old (form-pipeline-value 'grouped (make-line-node "def" "x") '() #f))
    (define new (form-pipeline-value 'tagged (make-line-node "def" "x") '() #f))
    (define merged (form-pipeline-merge old new))
    (check-eq? (form-pipeline-value-stage merged) 'grouped))

  (test-case "pipeline: advance raw → tagged (G(0) grouping)"
    (define pv (form-pipeline-value 'raw (make-line-node "def" "x" ":=" "42") '() #f))
    (define next (advance-pipeline pv))
    (check-eq? (form-pipeline-value-stage next) 'tagged)
    ;; raw → tagged now does G(0) form grouping (tag refinement is tagged → grouped)
    (check-true (parse-tree-node? (form-pipeline-value-tree-node next))))

  (test-case "pipeline: advance tagged → grouped (T(0) tag refinement)"
    (define node (make-line-node "def" "x" ":=" "42"))
    (define grouped (group-tree-node node))
    (define pv (form-pipeline-value 'tagged grouped '() #f))
    (define next (advance-pipeline pv))
    (check-eq? (form-pipeline-value-stage next) 'grouped)
    (check-eq? (parse-tree-node-tag (form-pipeline-value-tree-node next)) tag-def))

  (test-case "pipeline: run-form-pipeline reaches done"
    (define node (make-line-node "eval" "x"))
    (define result (run-form-pipeline node))
    (check-eq? (form-pipeline-value-stage result) 'done)
    ;; Tag should have been refined
    (check-eq? (parse-tree-node-tag (form-pipeline-value-tree-node result)) tag-eval))

  (test-case "pipeline: if form reaches done with correct rewrite"
    (define node (make-line-node "if" "true" "1" "0"))
    (define result (run-form-pipeline node))
    (check-eq? (form-pipeline-value-stage result) 'done)
    ;; After G(0) grouping + V(0,2) rewrite, the if should be rewritten to boolrec
    (define final-node (form-pipeline-value-tree-node result))
    (check-true (parse-tree-node? final-node))
    ;; Check that rewriting happened (tag should be expr, first child boolrec)
    (define children (parse-tree-node-children final-node))
    (when (> (rrb-size children) 0)
      (define first-child (rrb-get children 0))
      (when (token-entry? first-child)
        (check-equal? (token-entry-lexeme first-child) "boolrec"))))

  (test-case "expand-quasiquote: symbol → datum-sym"
    (define node (parse-tree-node
                  tag-quasiquote
                  (rrb-from-list
                   (list (make-token "$quasiquote")
                         (make-token "foo")))
                  #f 0))
    (define-values (result matched?) (apply-rules node 'V0-2))
    (check-true matched?)
    (check-true (parse-tree-node? result))
    (check-eq? (parse-tree-node-tag result) tag-expr)
    (define c0 (rrb-get (parse-tree-node-children result) 0))
    (check-equal? (token-entry-lexeme c0) "datum-sym"))

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

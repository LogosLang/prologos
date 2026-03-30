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

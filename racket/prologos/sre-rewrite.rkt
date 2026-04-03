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
 ;; Verification
 verify-rewrite-rule
 ;; Critical pair analysis
 find-critical-pairs
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

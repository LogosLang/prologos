#lang racket/base

;;;
;;; ctor-registry.rkt — Domain-agnostic constructor descriptor registry
;;;
;;; Shared infrastructure for PUnify: both type constructors (System 1,
;;; elaborator-network.rkt) and data constructors (System 2, relations.rkt)
;;; register here. Generic decompose/reconstruct/merge operations dispatch
;;; through descriptors rather than per-tag hardcoded cases.
;;;
;;; Design reference: docs/tracking/2026-03-19_PUNIFY_PART2_CELL_TREE_ARCHITECTURE.md §5.6.2-5.6.3
;;;

(require racket/list
         "syntax.rkt")

(provide
 ;; Core struct
 (struct-out ctor-desc)
 ;; Registration and lookup
 register-ctor!
 lookup-ctor-desc
 all-ctor-descs
 ;; Validation
 validate-ctor-desc!
 ;; Generic operations
 generic-decompose-components
 generic-reconstruct-value
 ctor-tag-for-value
 ;; Debugging
 cell-tree->sexp
 ;; A/B toggle
 current-punify-enabled?)

;; ========================================
;; Constructor descriptor struct
;; ========================================

;; Each registered constructor describes how to decompose a compound value
;; into sub-components and reconstruct it from sub-component values.
;;
;; Fields:
;;   tag             — symbol identifying this constructor ('Pi, 'Sigma, 'cons, etc.)
;;   arity           — number of sub-components
;;   recognizer-fn   — (value → boolean) safe dispatch predicate
;;   extract-fn      — (value → (list component ...)) decompose into sub-values
;;   reconstruct-fn  — ((list value ...) → value) rebuild from sub-values
;;   component-lattices — (list (cons merge-fn contradiction-fn) ...) per-component
;;   binder-depth    — how many trailing components are under a binder (0 for most, 1 for Pi/Sigma)
;;   domain          — 'type or 'data — which unification system owns this
(struct ctor-desc
  (tag
   arity
   recognizer-fn
   extract-fn
   reconstruct-fn
   component-lattices
   binder-depth
   domain)
  #:transparent)


;; ========================================
;; Registry (mutable hash, populated at module load time)
;; ========================================

;; tag (symbol) → ctor-desc
(define ctor-registry (make-hasheq))

;; Ordered list of recognizer pairs for ctor-tag-for-value dispatch.
;; Each entry is (cons recognizer-fn tag). Type constructors first (more common).
(define recognizer-chain '())

;; Register a constructor descriptor.
;; Validates the descriptor and adds it to the registry.
(define (register-ctor! tag
                        #:arity arity
                        #:recognizer recognizer-fn
                        #:extract extract-fn
                        #:reconstruct reconstruct-fn
                        #:component-lattices component-lattices
                        #:binder-depth [binder-depth 0]
                        #:domain [domain 'type])
  (define desc (ctor-desc tag arity recognizer-fn extract-fn reconstruct-fn
                          component-lattices binder-depth domain))
  (hash-set! ctor-registry tag desc)
  ;; Add to recognizer chain (append — preserves registration order)
  (set! recognizer-chain (append recognizer-chain (list (cons recognizer-fn tag))))
  (void))

;; Look up a descriptor by tag. Returns #f if not registered.
(define (lookup-ctor-desc tag)
  (hash-ref ctor-registry tag #f))

;; All registered descriptors as a list.
(define (all-ctor-descs)
  (hash-values ctor-registry))

;; Determine the constructor tag for an AST value by trying recognizers.
;; Returns a symbol tag or #f for atoms/non-compound.
(define (ctor-tag-for-value v)
  (let loop ([chain recognizer-chain])
    (cond
      [(null? chain) #f]
      [((caar chain) v) (cdar chain)]
      [else (loop (cdr chain))])))


;; ========================================
;; Validation
;; ========================================

;; Validate a ctor-desc at registration time (development-mode check).
;; Verifies:
;;   1. extract-fn produces exactly `arity` components for a sample value
;;   2. roundtrip: (reconstruct-fn (extract-fn sample)) equals sample
;;   3. component-lattices length matches arity
;;   4. binder-depth ≤ arity
;; Pass a sample value to validate against.
(define (validate-ctor-desc! desc sample)
  (define tag (ctor-desc-tag desc))
  (define arity (ctor-desc-arity desc))
  ;; Check recognizer
  (unless ((ctor-desc-recognizer-fn desc) sample)
    (error 'validate-ctor-desc!
           "recognizer-fn returned #f for sample value of ~a" tag))
  ;; Check extract arity
  (define components ((ctor-desc-extract-fn desc) sample))
  (unless (= (length components) arity)
    (error 'validate-ctor-desc!
           "~a: extract-fn produced ~a components, expected ~a"
           tag (length components) arity))
  ;; Check roundtrip
  (define reconstructed ((ctor-desc-reconstruct-fn desc) components))
  (unless (equal? reconstructed sample)
    (error 'validate-ctor-desc!
           "~a: roundtrip failed: (reconstruct (extract sample)) ≠ sample\n  sample: ~e\n  got: ~e"
           tag sample reconstructed))
  ;; Check component-lattices length
  (unless (= (length (ctor-desc-component-lattices desc)) arity)
    (error 'validate-ctor-desc!
           "~a: component-lattices length ~a ≠ arity ~a"
           tag (length (ctor-desc-component-lattices desc)) arity))
  ;; Check binder-depth
  (unless (<= (ctor-desc-binder-depth desc) arity)
    (error 'validate-ctor-desc!
           "~a: binder-depth ~a > arity ~a"
           tag (ctor-desc-binder-depth desc) arity))
  #t)


;; ========================================
;; Generic operations
;; ========================================

;; Extract sub-components from a value using its descriptor.
;; Returns (values tag components) or (values #f #f) for atoms.
(define (generic-decompose-components v)
  (define tag (ctor-tag-for-value v))
  (cond
    [(not tag) (values #f #f)]
    [else
     (define desc (lookup-ctor-desc tag))
     (values tag ((ctor-desc-extract-fn desc) v))]))

;; Reconstruct a value from sub-components using its descriptor.
;; tag must be a registered constructor tag.
(define (generic-reconstruct-value tag components)
  (define desc (lookup-ctor-desc tag))
  (unless desc
    (error 'generic-reconstruct-value "unknown constructor tag: ~a" tag))
  ((ctor-desc-reconstruct-fn desc) components))


;; ========================================
;; Debugging
;; ========================================

;; Convert a cell-tree to an S-expression for debugging.
;; Takes a cell-read function (net → cell-id → value) and a net.
;; Recursively reads cells and decomposes compound values.
(define (cell-tree->sexp read-fn net cell-id)
  (define v (read-fn net cell-id))
  (cond
    [(not v) '⊥]
    [else
     (define tag (ctor-tag-for-value v))
     (cond
       [(not tag) v]  ;; atom — return as-is
       [else
        (define desc (lookup-ctor-desc tag))
        (define components ((ctor-desc-extract-fn desc) v))
        (cons tag (map (lambda (c) (if (number? c)
                                       ;; sub-cell id — recurse
                                       (cell-tree->sexp read-fn net c)
                                       ;; ground component — show directly
                                       c))
                       components))])]))


;; ========================================
;; A/B toggle
;; ========================================

;; When #t, unify-core delegates to unify-via-propagator (descriptor-based).
;; When #f (default), existing code runs unchanged.
(define current-punify-enabled? (make-parameter #f))


;; ========================================
;; Type Constructor Registrations (System 1)
;; ========================================
;;
;; Domain 'type — these describe AST struct constructors from syntax.rkt.
;; component-lattices stores symbols ('type or 'mult) resolved at use-time
;; by the propagator infrastructure; this avoids circular dependencies
;; with type-lattice.rkt and mult-lattice.rkt.

(register-ctor! 'Pi
  #:arity 3
  #:recognizer expr-Pi?
  #:extract (lambda (v) (list (expr-Pi-mult v) (expr-Pi-domain v) (expr-Pi-codomain v)))
  #:reconstruct (lambda (cs) (expr-Pi (first cs) (second cs) (third cs)))
  #:component-lattices '(mult type type)
  #:binder-depth 1
  #:domain 'type)

(register-ctor! 'Sigma
  #:arity 2
  #:recognizer expr-Sigma?
  #:extract (lambda (v) (list (expr-Sigma-fst-type v) (expr-Sigma-snd-type v)))
  #:reconstruct (lambda (cs) (expr-Sigma (first cs) (second cs)))
  #:component-lattices '(type type)
  #:binder-depth 1
  #:domain 'type)

(register-ctor! 'app
  #:arity 2
  #:recognizer expr-app?
  #:extract (lambda (v) (list (expr-app-func v) (expr-app-arg v)))
  #:reconstruct (lambda (cs) (expr-app (first cs) (second cs)))
  #:component-lattices '(type type)
  #:binder-depth 0
  #:domain 'type)

(register-ctor! 'Eq
  #:arity 3
  #:recognizer expr-Eq?
  #:extract (lambda (v) (list (expr-Eq-type v) (expr-Eq-lhs v) (expr-Eq-rhs v)))
  #:reconstruct (lambda (cs) (expr-Eq (first cs) (second cs) (third cs)))
  #:component-lattices '(type type type)
  #:binder-depth 0
  #:domain 'type)

(register-ctor! 'Vec
  #:arity 2
  #:recognizer expr-Vec?
  #:extract (lambda (v) (list (expr-Vec-elem-type v) (expr-Vec-length v)))
  #:reconstruct (lambda (cs) (expr-Vec (first cs) (second cs)))
  #:component-lattices '(type type)
  #:binder-depth 0
  #:domain 'type)

(register-ctor! 'Fin
  #:arity 1
  #:recognizer expr-Fin?
  #:extract (lambda (v) (list (expr-Fin-bound v)))
  #:reconstruct (lambda (cs) (expr-Fin (first cs)))
  #:component-lattices '(type)
  #:binder-depth 0
  #:domain 'type)

(register-ctor! 'pair
  #:arity 2
  #:recognizer expr-pair?
  #:extract (lambda (v) (list (expr-pair-fst v) (expr-pair-snd v)))
  #:reconstruct (lambda (cs) (expr-pair (first cs) (second cs)))
  #:component-lattices '(type type)
  #:binder-depth 0
  #:domain 'type)

(register-ctor! 'lam
  #:arity 3
  #:recognizer expr-lam?
  #:extract (lambda (v) (list (expr-lam-mult v) (expr-lam-type v) (expr-lam-body v)))
  #:reconstruct (lambda (cs) (expr-lam (first cs) (second cs) (third cs)))
  #:component-lattices '(mult type type)
  #:binder-depth 1
  #:domain 'type)

(register-ctor! 'suc
  #:arity 1
  #:recognizer expr-suc?
  #:extract (lambda (v) (list (expr-suc-pred v)))
  #:reconstruct (lambda (cs) (expr-suc (first cs)))
  #:component-lattices '(type)
  #:binder-depth 0
  #:domain 'type)

(register-ctor! 'PVec
  #:arity 1
  #:recognizer expr-PVec?
  #:extract (lambda (v) (list (expr-PVec-elem-type v)))
  #:reconstruct (lambda (cs) (expr-PVec (first cs)))
  #:component-lattices '(type)
  #:binder-depth 0
  #:domain 'type)

(register-ctor! 'Set
  #:arity 1
  #:recognizer expr-Set?
  #:extract (lambda (v) (list (expr-Set-elem-type v)))
  #:reconstruct (lambda (cs) (expr-Set (first cs)))
  #:component-lattices '(type)
  #:binder-depth 0
  #:domain 'type)

(register-ctor! 'Map
  #:arity 2
  #:recognizer expr-Map?
  #:extract (lambda (v) (list (expr-Map-k-type v) (expr-Map-v-type v)))
  #:reconstruct (lambda (cs) (expr-Map (first cs) (second cs)))
  #:component-lattices '(type type)
  #:binder-depth 0
  #:domain 'type)


;; ========================================
;; Data Constructor Registrations (System 2)
;; ========================================
;;
;; Domain 'data — these describe list-based solver terms from relations.rkt.
;; The solver represents compound terms as '(tag arg1 arg2 ...).
;; Atoms (symbols, numbers, keywords) have no descriptor — they're ground.

(register-ctor! 'cons
  #:arity 2
  #:recognizer (lambda (v) (and (pair? v) (eq? (car v) 'cons)))
  #:extract (lambda (v) (list (second v) (third v)))
  #:reconstruct (lambda (cs) (list 'cons (first cs) (second cs)))
  #:component-lattices '(term term)
  #:binder-depth 0
  #:domain 'data)

(register-ctor! 'nil
  #:arity 0
  #:recognizer (lambda (v) (and (pair? v) (eq? (car v) 'nil)))
  #:extract (lambda (v) '())
  #:reconstruct (lambda (cs) '(nil))
  #:component-lattices '()
  #:binder-depth 0
  #:domain 'data)

(register-ctor! 'some
  #:arity 1
  #:recognizer (lambda (v) (and (pair? v) (eq? (car v) 'some)))
  #:extract (lambda (v) (list (second v)))
  #:reconstruct (lambda (cs) (list 'some (first cs)))
  #:component-lattices '(term)
  #:binder-depth 0
  #:domain 'data)

(register-ctor! 'none
  #:arity 0
  #:recognizer (lambda (v) (and (pair? v) (eq? (car v) 'none)))
  #:extract (lambda (v) '())
  #:reconstruct (lambda (cs) '(none))
  #:component-lattices '()
  #:binder-depth 0
  #:domain 'data)

(register-ctor! 'data-suc
  #:arity 1
  #:recognizer (lambda (v) (and (pair? v) (eq? (car v) 'suc)))
  #:extract (lambda (v) (list (second v)))
  #:reconstruct (lambda (cs) (list 'suc (first cs)))
  #:component-lattices '(term)
  #:binder-depth 0
  #:domain 'data)

(register-ctor! 'data-zero
  #:arity 0
  #:recognizer (lambda (v) (and (pair? v) (eq? (car v) 'zero)))
  #:extract (lambda (v) '())
  #:reconstruct (lambda (cs) '(zero))
  #:component-lattices '()
  #:binder-depth 0
  #:domain 'data)

(register-ctor! 'data-pair
  #:arity 2
  #:recognizer (lambda (v) (and (pair? v) (eq? (car v) 'pair)))
  #:extract (lambda (v) (list (second v) (third v)))
  #:reconstruct (lambda (cs) (list 'pair (first cs) (second cs)))
  #:component-lattices '(term term)
  #:binder-depth 0
  #:domain 'data)

(register-ctor! 'ok
  #:arity 1
  #:recognizer (lambda (v) (and (pair? v) (eq? (car v) 'ok)))
  #:extract (lambda (v) (list (second v)))
  #:reconstruct (lambda (cs) (list 'ok (first cs)))
  #:component-lattices '(term)
  #:binder-depth 0
  #:domain 'data)

(register-ctor! 'err
  #:arity 1
  #:recognizer (lambda (v) (and (pair? v) (eq? (car v) 'err)))
  #:extract (lambda (v) (list (second v)))
  #:reconstruct (lambda (cs) (list 'err (first cs)))
  #:component-lattices '(term)
  #:binder-depth 0
  #:domain 'data)

#lang racket/base

;;;
;;; cap-type-bridge.rkt — Cross-Domain Bridge: Type Lattice ↔ Capability Lattice
;;;
;;; Implements the Galois connection between the type inference domain
;;; (type expressions with type-lattice-merge) and the capability inference
;;; domain (CapabilitySet with cap-set-join) via α/γ abstraction functions,
;;; plus a combined propagator network that runs both domains simultaneously.
;;;
;;; Phase 8 of the Capabilities as Types implementation.
;;;
;;; α (type-to-cap-set): TypeExpr → cap-set
;;;   Extracts all capability type names from a type expression.
;;;   Walks Pi chains, union branches, and bare fvars.
;;;
;;; γ (cap-set-to-type): cap-set → TypeExpr
;;;   Converts a capability set back to a type expression.
;;;   Empty → type-bot, singleton → fvar, multi → union.
;;;
;;; Galois adjunction: α ∘ γ ∘ α = α, γ ∘ α ∘ γ = γ
;;;
;;; Design reference: docs/tracking/2026-03-01_1500_CAPABILITIES_AS_TYPES_DESIGN.md §Phase 8
;;;

(require racket/match
         racket/set
         racket/list
         "syntax.rkt"               ;; expr structs
         "macros.rkt"               ;; capability-type?, subtype-pair?
         "type-lattice.rkt"         ;; type-bot, type-top, type-lattice-merge, type-lattice-contradicts?
         "capability-inference.rkt" ;; cap-set, cap-set-bot, cap-set-join, build-call-graph, etc.
         "global-env.rkt"           ;; current-global-env
         "propagator.rkt")          ;; prop-network, net-new-cell, net-add-cross-domain-propagator, etc.

(provide ;; α/γ Galois connection functions
         type-to-cap-set
         cap-set-to-type
         ;; Cross-domain network
         build-cross-domain-network
         ;; Result struct
         cap-type-bridge-result
         cap-type-bridge-result?
         cap-type-bridge-result-type-closures
         cap-type-bridge-result-cap-closures
         cap-type-bridge-result-overdeclared
         cap-type-bridge-result-call-graph
         ;; Query API
         cap-audit-overdeclared)

;; ========================================
;; α: type-to-cap-set (TypeExpr → cap-set)
;; ========================================
;;
;; Extracts all capability type names from a type expression.
;; Walks:
;;   - Bare fvar: if capability-type? → singleton cap-set
;;   - Union: join both branches
;;   - Pi with :0 capability domain: include that cap, recurse on codomain
;;   - Pi with non-capability domain: recurse on codomain only
;;   - type-bot / type-top / other: cap-set-bot
;;
;; Monotonicity: more type information → superset of capabilities (or same).

(define (type-to-cap-set type)
  (match type
    ;; Bare capability reference: fvar whose name is in capability registry
    [(expr-fvar name)
     (if (capability-type? name)
         (cap-set (set (bare-cap name)))
         cap-set-bot)]
    ;; Applied capability: (expr-app (expr-fvar cap-name) index-expr)
    [(expr-app (? expr-fvar? f) idx)
     (define name (expr-fvar-name f))
     (if (capability-type? name)
         (cap-set (set (cap-entry name idx)))
         cap-set-bot)]
    ;; Union type: join both branches
    [(expr-union left right)
     (cap-set-join (type-to-cap-set left) (type-to-cap-set right))]
    ;; Pi with :0 bare capability domain: include cap, recurse on codomain
    [(expr-Pi 'm0 (? expr-fvar? dom) cod)
     (define name (expr-fvar-name dom))
     (if (capability-type? name)
         (cap-set-join (cap-set (set (bare-cap name))) (type-to-cap-set cod))
         (type-to-cap-set cod))]
    ;; Pi with :0 applied capability domain: (Pi m0 (FileCap "/data") cod)
    [(expr-Pi 'm0 (expr-app (? expr-fvar? f) idx) cod)
     (define name (expr-fvar-name f))
     (if (capability-type? name)
         (cap-set-join (cap-set (set (cap-entry name idx))) (type-to-cap-set cod))
         (type-to-cap-set cod))]
    ;; Pi with non-:0 or non-fvar domain: recurse on codomain only
    [(expr-Pi _ _ cod) (type-to-cap-set cod)]
    ;; Type-domain sentinels
    [(? type-bot?) cap-set-bot]
    [(? type-top?) cap-set-bot]  ;; contradiction → no capability info
    ;; Anything else (Nat, Bool, String, app, etc.): no capability content
    [_ cap-set-bot]))

;; ========================================
;; γ: cap-set-to-type (cap-set → TypeExpr)
;; ========================================
;;
;; Converts a capability set back to a type expression:
;;   - Empty → type-bot (no type information)
;;   - Singleton {C} → (expr-fvar C)
;;   - Multi {C1, C2, ...} → union of fvars
;;
;; Monotonicity: larger cap-set → type with more union branches.
;;
;; NOTE: set->list order is unspecified for seteq. We sort by symbol name
;; to ensure deterministic output (important for test stability and for
;; type-lattice-merge which compares structurally).

;; Convert a cap-entry to its type expression representation.
;; Bare cap → (expr-fvar name), applied cap → (expr-app (expr-fvar name) idx)
(define (cap-entry->type-expr entry)
  (if (cap-entry-index-expr entry)
      (expr-app (expr-fvar (cap-entry-name entry)) (cap-entry-index-expr entry))
      (expr-fvar (cap-entry-name entry))))

(define (cap-set-to-type caps)
  ;; Sort by name for determinism
  (define members (sort (set->list (cap-set-members caps))
                        (lambda (a b)
                          (string<? (symbol->string (cap-entry-name a))
                                    (symbol->string (cap-entry-name b))))))
  (cond
    [(null? members) type-bot]
    [(= 1 (length members))
     (cap-entry->type-expr (car members))]
    [else
     ;; Build right-associative union: C1 | (C2 | C3)
     (foldr (lambda (entry acc)
              (if (type-bot? acc)
                  (cap-entry->type-expr entry)
                  (expr-union (cap-entry->type-expr entry) acc)))
            type-bot
            members)]))

;; Helper: symbol ordering for deterministic output
(define (symbol<? a b)
  (string<? (symbol->string a) (symbol->string b)))

;; ========================================
;; Cross-Domain Network Construction
;; ========================================
;;
;; Builds a combined propagator network containing both type-valued cells
;; (using type-lattice-merge) and cap-set-valued cells (using cap-set-join)
;; connected by cross-domain propagators via α/γ.
;;
;; Architecture:
;;   For each function in the global env:
;;     - type-cell: seeded with the function's type, merge = type-lattice-merge
;;     - cap-cell:  seeded with declared capabilities, merge = cap-set-join
;;     - Cross-domain propagator: type-cell ↔ cap-cell via α/γ
;;   Plus call-edge propagators on cap-cells (reusing Phase 5 logic).
;;
;; After quiescence, extracts:
;;   - Type closures: per-function type from type cells
;;   - Cap closures: per-function capability set from cap cells
;;   - Overdeclared: per-function set of declared-but-unused capabilities

(struct cap-type-bridge-result
  (type-closures       ;; hasheq: name → type-expr (from type cells)
   cap-closures        ;; hasheq: name → (set of cap-entry) (from cap cells)
   overdeclared        ;; hasheq: name → (set of cap-entry) (unused caps)
   call-graph)         ;; hasheq: name → (seteq callee-names)
  #:transparent)

(define (build-cross-domain-network [env (global-env-snapshot)])
  ;; Step 1: Build call graph (reuse from capability-inference.rkt)
  (define call-graph (build-call-graph env))

  ;; Step 2: Create cells for each function — one type cell + one cap cell
  (define-values (net0 name->type-cid name->cap-cid)
    (for/fold ([net (make-prop-network)]
               [type-mapping (hasheq)]
               [cap-mapping (hasheq)])
              ([(name _) (in-hash call-graph)])
      (define entry (hash-ref env name #f))

      ;; Type cell: seeded with function's type (or type-bot if no entry)
      (define func-type
        (if (and entry (pair? entry))
            (car entry)
            type-bot))
      (define-values (net1 type-cid)
        (net-new-cell net func-type type-lattice-merge type-lattice-contradicts?))

      ;; Cap cell: seeded with declared capabilities (from type spec)
      (define initial-caps
        (if (and entry (pair? entry))
            (cap-set (extract-capability-requirements (car entry)))
            cap-set-bot))
      (define-values (net2 cap-cid)
        (net-new-cell net1 initial-caps cap-set-join))

      (values net2
              (hash-set type-mapping name type-cid)
              (hash-set cap-mapping name cap-cid))))

  ;; Step 3: Add cross-domain propagators (type-cell ↔ cap-cell via α/γ)
  (define net1
    (for/fold ([net net0])
              ([(name _) (in-hash call-graph)])
      (define type-cid (hash-ref name->type-cid name))
      (define cap-cid (hash-ref name->cap-cid name))
      (define-values (net* _pid-alpha _pid-gamma)
        (net-add-cross-domain-propagator net type-cid cap-cid
                                          type-to-cap-set cap-set-to-type))
      net*))

  ;; Step 4: Add call-edge propagators on cap cells (same as Phase 5)
  ;; For each call edge (caller → callee): watch callee's cap-cell,
  ;; write callee's cap-set to caller's cap-cell.
  (define net2
    (for/fold ([net net1])
              ([(caller callees) (in-hash call-graph)])
      (define caller-cap-cid (hash-ref name->cap-cid caller #f))
      (if (not caller-cap-cid)
          net
          (for/fold ([net net])
                    ([callee (in-set callees)]
                     #:when (hash-ref name->cap-cid callee #f))
            (define callee-cap-cid (hash-ref name->cap-cid callee))
            (define-values (net* _pid)
              (net-add-propagator net
                (list callee-cap-cid)    ;; inputs: watch callee's cap cell
                (list caller-cap-cid)    ;; outputs: may write to caller's cap cell
                (lambda (n)
                  (define callee-caps (net-cell-read n callee-cap-cid))
                  (net-cell-write n caller-cap-cid callee-caps))))
            net*))))

  ;; Step 5: Run to quiescence (fixed point across both domains)
  (define net-final (run-to-quiescence net2))

  ;; Step 6: Extract results from both cell types
  (define type-closures
    (for/hasheq ([(name type-cid) (in-hash name->type-cid)])
      (values name (net-cell-read net-final type-cid))))

  (define cap-closures
    (for/hasheq ([(name cap-cid) (in-hash name->cap-cid)])
      (define caps (net-cell-read net-final cap-cid))
      (values name (cap-set-members caps))))

  ;; Step 7: Compute overdeclared capabilities per function
  ;; Overdeclared = declared capabilities - exercised capabilities
  ;; "Exercised" = union of all callees' cap-cell values (what the call graph
  ;; actually requires). We can't compare declared vs the function's OWN cap-cell
  ;; because the cap-cell includes declared caps (from seeding + α propagation).
  ;; By looking at callees only, we see what the function NEEDS from its call graph.
  ;; Note: leaf functions that declare caps are assumed to exercise them directly
  ;; (they are the terminal consumers — e.g., foreign IO bindings).
  (define overdeclared
    (for/hasheq ([(name _) (in-hash call-graph)])
      (define entry (hash-ref env name #f))
      (define declared
        (if (and entry (pair? entry))
            (extract-capability-requirements (car entry))
            (set)))
      (define callees (hash-ref call-graph name (seteq)))
      ;; Exercised = union of all callees' cap-cell values (only callees
      ;; that are actual functions in the env, not type references like Nat)
      (define exercised
        (for/fold ([caps (set)])
                  ([callee (in-set callees)]
                   #:when (hash-ref cap-closures callee #f))
          (set-union caps (hash-ref cap-closures callee (set)))))
      ;; Leaf functions (no function callees — only type refs from
      ;; extract-fvar-names) exercise their own declared caps directly.
      ;; They are terminal consumers (e.g., foreign IO bindings).
      (define has-function-callees?
        (for/or ([callee (in-set callees)])
          (hash-ref cap-closures callee #f)))
      (define effective-exercised
        (if has-function-callees? exercised declared))
      ;; Overdeclared = declared - exercised (cap-entry-aware)
      (define unused
        (for/set ([dcap (in-set declared)]
                  #:unless (for/or ([ecap (in-set effective-exercised)])
                             (cap-entry-covers? ecap dcap)))
          dcap))
      (values name unused)))

  (cap-type-bridge-result type-closures cap-closures overdeclared call-graph))

;; ========================================
;; Query API
;; ========================================

;; Get the set of overdeclared (unused) capabilities for a function.
;; Returns a set of cap-entry structs.
(define (cap-audit-overdeclared result func-name)
  (hash-ref (cap-type-bridge-result-overdeclared result) func-name (set)))

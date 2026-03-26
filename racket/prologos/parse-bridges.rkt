#lang racket/base

;;;
;;; PPN Track 0: Parse Domain Bridge Specifications
;;;
;;; Defines α/γ functions for cross-domain information flow in the
;;; propagator-based parsing architecture. These are SPECIFICATIONS
;;; with test-specific implementations — production implementations
;;; come in Track 3 when a real grammar is wired.
;;;
;;; Architecture (D.2/D.4):
;;; - BRIDGES: inter-domain, within stratum. Galois α/γ.
;;; - EXCHANGES: inter-strata, via Kan extensions. Demand/supply.
;;; - PROJECTIONS: one-way (fibration), α only.
;;;
;;; Bridges are STRATIFICATION-AGNOSTIC (D.4): pure data transformations
;;; that don't assume whether parse and elaborate share a stratum.
;;;
;;; See: docs/tracking/2026-03-26_PPN_TRACK0_LATTICE_DESIGN.md §3
;;;

(require racket/set
         "parse-lattice.rkt")

(provide
 ;; Bridge 1: TokenToSurface
 token-to-surface-alpha    ;; token → parse items (scanning)
 surface-to-token-gamma    ;; parse context → token disambiguation

 ;; Bridge 2: SurfaceToCore
 surface-to-core-alpha     ;; completed parse → AST node
 core-to-surface-gamma     ;; type error → ATMS retraction signal

 ;; Bridge 3: SurfaceToType (α + ATMS-mediated backward)
 surface-to-type-alpha     ;; parse → type constraints

 ;; Exchange: Right Kan (elaborate demands from parse)
 make-demand-from-elaboration  ;; create a demand for parse info

 ;; Exchange: Left Kan (parse forwards partial results)
 (struct-out partial-parse-result)
 make-partial-parse-result     ;; wrap a partial parse for forwarding

 ;; Projection: SurfaceToNarrowing (α only)
 surface-to-narrowing-alpha    ;; parse → narrowing request

 ;; Demand satisfaction
 demand-satisfied?             ;; check if a target cell satisfies a demand
 )


;; ============================================================
;; Bridge 1: TokenToSurface (bidirectional)
;; ============================================================
;;
;; α: Token → parse items that this token can advance (scanning step).
;;    Given a token at position i, return the set of parse items that
;;    expect this token type at this position.
;;
;; γ: Parse context → token disambiguation.
;;    Given the current parse state, determine if a token's classification
;;    should be constrained. E.g., ">" inside angle brackets is delimiter.

;; α: Scanning. Takes a token + a grammar's "expected tokens" function.
;; The grammar function is Track 3's responsibility — here we define
;; the INTERFACE that Track 3 will call.
;;
;; expected-tokens-fn : (position × token-type) → set of parse-item
;;   "Given position i and token type T, which items expect T at i?"
;;
;; For Track 0 testing: a simple hardcoded grammar function.
(define (token-to-surface-alpha token expected-tokens-fn)
  (if (token-bot? token)
      parse-bot
      (let ([items (expected-tokens-fn
                    (token-cell-value-span-start token)
                    (token-cell-value-type token))])
        (if (set-empty? items)
            parse-bot
            (parse-cell-value
             (for/seteq ([item (in-set items)])
               (make-derivation-node item '() #f 0)))))))

;; γ: Context-sensitive disambiguation. Takes parse state + token,
;; returns a possibly-refined token (or the same token if unambiguous).
;;
;; context-fn : parse-cell-value → symbol → symbol | #f
;;   "Given parse state, should token type T be reclassified?"
;;   Returns new type or #f (no change).
;;
;; For Track 0 testing: a function that reclassifies ">" as delimiter
;; when inside angle brackets.
(define (surface-to-token-gamma parse-state token context-fn)
  (cond
    [(token-bot? token) token-bot]
    [(parse-bot? parse-state) token]  ;; no parse context → no change
    [else
     (define new-type (context-fn parse-state (token-cell-value-type token)))
     (if new-type
         (struct-copy token-cell-value token [type new-type])
         token)]))


;; ============================================================
;; Bridge 2: SurfaceToCore (bidirectional)
;; ============================================================
;;
;; α: Completed parse → AST node.
;;    When a parse item is complete (dot at end of production),
;;    construct the corresponding core AST.
;;
;; Backward: Type error → ATMS retraction signal (NOT classical γ).
;;    D.4: SurfaceToType backward flow is ATMS-mediated, not lattice γ.
;;    We provide a retraction signal, not a Galois γ.

;; α: Takes a completed derivation-node + an AST-construction function.
;; The construction function is Track 4's responsibility.
;;
;; ast-fn : derivation-node → any (AST node)
;;   "Given a completed derivation, build the AST."
(define (surface-to-core-alpha derivation ast-fn)
  (if (derivation-node? derivation)
      (ast-fn derivation)
      core-bot))

;; Backward: ATMS retraction signal.
;; Returns the assumption-id to retract when a type error occurs.
;; NOT a γ function — it's a retraction action.
(define (core-to-surface-gamma derivation)
  (and (derivation-node? derivation)
       (derivation-node-assumption-id derivation)))


;; ============================================================
;; Bridge 3: SurfaceToType (α + ATMS-mediated backward)
;; ============================================================
;;
;; α: Parse → type constraints.
;;    A parsed form generates type constraints for elaboration.
;;    The constraint-generation function is Track 4's responsibility.
;;
;; D.4: Backward flow is ATMS-mediated (type errors retract parse
;; assumptions), NOT a classical Galois γ. Handled by the ATMS
;; infrastructure, not by a bridge γ function.

;; α: Takes a completed parse + a constraint-generation function.
;; constraint-fn : derivation-node → list of type constraints
(define (surface-to-type-alpha derivation constraint-fn)
  (if (derivation-node? derivation)
      (constraint-fn derivation)
      '()))


;; ============================================================
;; Exchange: Right Kan (Elaborate → Parse demand)
;; ============================================================
;;
;; The elaborator demands parse information. The demand flows
;; backward (elaborate → parse) via the demand lattice.
;; The parse stratum computes what's demanded.

;; Create a demand: the elaborator needs info at a specific position.
(define (make-demand-from-elaboration target-domain position specificity [priority 0])
  (make-demand target-domain position specificity 'S-elaborate priority))


;; ============================================================
;; Exchange: Left Kan (Parse → Elaborate partial results)
;; ============================================================
;;
;; As parsing progresses, partial results are forwarded to the
;; elaborator BEFORE parse reaches fixpoint. These are lower bounds
;; on the final result.

;; Wrap a parse-cell-value as a partial result for Left Kan forwarding.
;; The wrapper signals "this is speculative — may change."
(struct partial-parse-result
  (parse-value    ;; parse-cell-value
   confidence     ;; real [0,1]: how likely this partial result is final
   )
  #:transparent)

(define (make-partial-parse-result pcv [confidence 0.5])
  (partial-parse-result pcv confidence))


;; ============================================================
;; Projection: SurfaceToNarrowing (α only, fibration)
;; ============================================================
;;
;; One-way: parse events trigger narrowing of variables.
;; Results flow back via TypeToSurface (ATMS retraction), not
;; directly from narrowing to surface.

;; α: A parsed pattern match triggers narrowing request.
;; narrowing-fn : derivation-node → narrowing-request | #f
(define (surface-to-narrowing-alpha derivation narrowing-fn)
  (if (derivation-node? derivation)
      (narrowing-fn derivation)
      #f))


;; ============================================================
;; Demand Satisfaction Protocol (D.4)
;; ============================================================
;;
;; A demand satisfaction propagator watches BOTH the demand cell
;; AND the target cell. When the target transitions bot → value,
;; check if any pending demand is satisfied.
;;
;; This is the operational semantics of Right Kan demand flow.

;; Check: does a cell value satisfy a specific demand?
;; Satisfaction depends on the demand's specificity:
;;   'any       → any non-bot value satisfies
;;   'ground    → a fully-ground (no metas) value satisfies
;;   'constructor → a value with a specific constructor tag satisfies
;;   domain-specific → delegate to domain
(define (demand-satisfied? demand-entry cell-value [ground-check (lambda (v) #t)])
  (cond
    [(eq? cell-value 'token-bot) #f]
    [(eq? cell-value 'core-bot) #f]
    [(and (parse-cell-value? cell-value) (parse-bot? cell-value)) #f]
    [(and (demand-cell-value? cell-value) (demand-bot? cell-value)) #f]
    [else
     (case (demand-specificity demand-entry)
       [(any) #t]  ;; any non-bot satisfies
       [(ground) (ground-check cell-value)]  ;; delegate to ground checker
       [(constructor) #t]  ;; constructor-specific — Track 3 refines
       [(complete-item) (and (parse-cell-value? cell-value)
                             (not (set-empty? (parse-cell-value-derivations cell-value))))]
       [else #t])]))  ;; unknown specificity → permissive default

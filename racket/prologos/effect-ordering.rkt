#lang racket/base

;;;
;;; EFFECT ORDERING — Data-Flow Analysis and Ordering for Effects (AD-D)
;;;
;;; Phase AD-D implements three capabilities:
;;;
;;; D1: Data-flow edge extraction — static analysis of process ASTs to find
;;;     cross-channel data dependencies (recv on channel A flows to send on B).
;;;
;;; D2: Ordering propagator — propagator that computes the transitive closure
;;;     of session edges + data-flow edges (monotone fixed point).
;;;
;;; D3: Integration — combines session ordering, data-flow ordering, and
;;;     effect linearization into a complete pipeline.
;;;
;;; See: docs/tracking/2026-03-07_ARCHITECTURE_AD_IMPLEMENTATION_DESIGN.org §7-8
;;;

(require racket/match
         racket/list
         "effect-position.rkt"
         "processes.rkt"
         "propagator.rkt"
         "sessions.rkt"
         "syntax.rkt")

(provide
 ;; AD-D1: Data-flow edge extraction
 free-variables-in-expr
 extract-data-flow-edges
 session-ordering-edges
 ;; AD-D2: Ordering propagator
 add-ordering-propagator
 ;; AD-D3: Linearize effect descriptors
 linearize-effects)


;; ========================================
;; AD-D1: Free Variable Extraction
;; ========================================

;; Extract free variable symbols from an expression AST.
;; Returns a deduplicated list of symbols.
;;
;; Handles the common expression forms that appear in proc-send.
;; Unknown/unrecognized forms return '() (conservative: may miss
;; some dependencies, won't create false ones).
(define (free-variables-in-expr expr)
  (remove-duplicates (fv-expr expr)))

;; Internal: collect free variables without deduplication.
(define (fv-expr expr)
  (cond
    ;; Raw symbols — used in Phase 0 simple process expressions
    [(symbol? expr) (list expr)]
    [else
     (match expr
       ;; Variable references
       [(expr-fvar name) (list name)]
       [(expr-bvar _) '()]  ;; de Bruijn — not a named free var

       ;; Compound expressions — recurse
       [(expr-app fun arg) (append (fv-expr fun) (fv-expr arg))]
       [(expr-pair fst snd) (append (fv-expr fst) (fv-expr snd))]
       [(expr-fst e) (fv-expr e)]
       [(expr-snd e) (fv-expr e)]
       [(expr-ann term _type) (fv-expr term)]
       [(expr-suc pred) (fv-expr pred)]

       ;; Binding forms — the bound variable is local, not free
       [(expr-lam _mult _type body) (fv-expr body)]

       ;; Literals and type constructors — no free variables
       [(expr-string _) '()]
       [(expr-nat-val _) '()]
       [(expr-int _) '()]
       [(expr-zero) '()]
       [(expr-true) '()]
       [(expr-false) '()]
       [(expr-refl) '()]
       [(expr-keyword _) '()]

       ;; Fallback — unknown form, conservatively no vars
       [_ '()])]))


;; ========================================
;; AD-D1: Data-Flow Edge Extraction
;; ========================================

;; Walk a process AST to extract cross-channel data-flow edges.
;;
;; Algorithm:
;; 1. Track variable bindings: recv binds a variable at a (channel, depth) position
;; 2. Track variable uses: send uses variables; if a used variable was bound by
;;    a recv on a DIFFERENT channel, create an ordering edge
;; 3. Walk recursively through continuations, parallel compositions, and branches
;;
;; proc        : proc-* (process AST)
;; chan-depth   : hasheq symbol → Nat (current depth per channel)
;; var-origins  : hasheq symbol → eff-pos (where each variable was bound)
;; Returns: list of eff-edge
(define (extract-data-flow-edges proc [chan-depth (hasheq)] [var-origins (hasheq)])
  (match proc
    [(proc-stop) '()]

    [(proc-recv chan binding _type cont)
     ;; recv binds a variable at this channel's current depth.
     ;; The binding name comes from proc-recv-binding (AD-A0).
     (define depth (hash-ref chan-depth chan 0))
     (define pos (eff-pos chan depth))
     (define new-origins
       (if binding
           (hash-set var-origins binding pos)
           var-origins))
     (define new-depths (hash-set chan-depth chan (add1 depth)))
     (extract-data-flow-edges cont new-depths new-origins)]

    [(proc-send expr chan cont)
     ;; send uses variables; check if any were bound on a different channel
     (define depth (hash-ref chan-depth chan 0))
     (define send-pos (eff-pos chan depth))
     (define used-vars (free-variables-in-expr expr))
     (define edges
       (for*/list ([v (in-list used-vars)]
                   [origin (in-value (hash-ref var-origins v #f))]
                   #:when origin
                   #:when (not (eq? (eff-pos-channel origin) chan)))
         (eff-edge origin send-pos)))
     (define new-depths (hash-set chan-depth chan (add1 depth)))
     (append edges (extract-data-flow-edges cont new-depths var-origins))]

    [(proc-par left right)
     ;; Both sub-processes may have cross-channel data flow
     (append (extract-data-flow-edges left chan-depth var-origins)
             (extract-data-flow-edges right chan-depth var-origins))]

    [(proc-case chan branches)
     ;; Each branch independently analyzed
     ;; Increment depth for the offer step
     (define new-depths (hash-set chan-depth chan
                          (add1 (hash-ref chan-depth chan 0))))
     (apply append
            (for/list ([b (in-list branches)])
              (extract-data-flow-edges (cdr b) new-depths var-origins)))]

    [(proc-sel chan _label cont)
     ;; Increment depth for the select step
     (define new-depths (hash-set chan-depth chan
                          (add1 (hash-ref chan-depth chan 0))))
     (extract-data-flow-edges cont new-depths var-origins)]

    [(proc-open _path _session-type _cap-type cont)
     ;; open creates IO channel 'ch; depth starts at 0
     (define new-depths (hash-set chan-depth 'ch 0))
     (extract-data-flow-edges cont new-depths var-origins)]

    [(proc-new _session cont)
     ;; new creates a channel pair; the continuation uses 'ch
     (define new-depths (hash-set chan-depth 'ch 0))
     (extract-data-flow-edges cont new-depths var-origins)]

    [(proc-link _c1 _c2) '()]

    [_ '()]))


;; ========================================
;; AD-D1: Session Ordering Edges
;; ========================================

;; Extract session ordering edges from a session type.
;; For a session with N steps on channel C, returns N-1 edges:
;;   (C,0) < (C,1) < ... < (C,N-1)
;;
;; Returns: list of eff-edge (total order within the channel)
(define (session-ordering-edges channel session-type)
  (define steps (session-steps session-type))
  (for/list ([i (in-range (sub1 steps))])
    (eff-edge (eff-pos channel i) (eff-pos channel (add1 i)))))


;; ========================================
;; AD-D2: Ordering Propagator (Transitive Closure)
;; ========================================

;; Install a propagator that computes transitive closure of ordering edges.
;;
;; Watches: session-edges-cell + data-flow-edges-cell
;; Writes to: complete-ordering-cell
;; Monotone: adding edges never removes ordering relationships
;;
;; If a cycle is detected (deadlock), writes eff-top to the contradiction cell.
;;
;; net                    : prop-network
;; session-edges-cell     : cell-id (eff-ordering value)
;; data-flow-edges-cell   : cell-id (eff-ordering value)
;; complete-ordering-cell : cell-id (eff-ordering value — output)
;; contradiction-cell     : cell-id (eff-bot or eff-top)
;; Returns: (values net* prop-id)
(define (add-ordering-propagator net session-edges-cell data-flow-edges-cell
                                 complete-ordering-cell contradiction-cell)
  (define fire-fn
    (lambda (n)
      (define sess-edges (net-cell-read n session-edges-cell))
      (define df-edges (net-cell-read n data-flow-edges-cell))
      (cond
        ;; Wait for both inputs
        [(or (eff-bot? sess-edges) (eff-bot? df-edges)) n]
        ;; Either input is contradiction
        [(or (eff-top? sess-edges) (eff-top? df-edges))
         (net-cell-write n contradiction-cell eff-top)]
        [else
         (define combined (eff-ordering-merge sess-edges df-edges))
         (define closed (eff-ordering-transitive-closure combined))
         (if (eff-ordering-has-cycle? closed)
             (net-cell-write n contradiction-cell eff-top)
             (net-cell-write n complete-ordering-cell closed))])))
  (net-add-propagator net
                      (list session-edges-cell data-flow-edges-cell)
                      (list complete-ordering-cell contradiction-cell)
                      fire-fn))


;; ========================================
;; AD-D3: Effect Descriptor Linearization
;; ========================================

;; Linearize effect descriptors according to an ordering.
;;
;; Takes a complete ordering and a list of effect descriptors, produces
;; a total order consistent with the partial order. Uses Kahn's algorithm
;; with deterministic tiebreak (channel name, then depth).
;;
;; ordering : eff-ordering (should be transitively closed)
;; effects  : list of effect-desc (from effect collection)
;; Returns: list of effect-desc in execution order, or #f if cycle detected.
(define (linearize-effects ordering effects)
  (define positions (map effect-desc-position effects))
  ;; Build position → effect-desc mapping
  (define pos->effect (make-hash))   ;; equal?-based keys (eff-pos structs)
  (for ([eff (in-list effects)])
    (hash-set! pos->effect (effect-desc-position eff) eff))
  ;; Use the existing position linearization
  (define linearized-positions (eff-ordering-linearize positions ordering))
  (cond
    [(not linearized-positions) #f]  ;; cycle detected
    [else
     (for/list ([pos (in-list linearized-positions)])
       (hash-ref pos->effect pos))]))

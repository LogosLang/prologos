#lang racket/base

;;;
;;; resolution.rkt — Constraint Resolution Logic (Track 7 Phase 7a)
;;;
;;; Extracted from driver.rkt (trait/hasmethod callbacks) and unify.rkt
;;; (constraint retry callback). These are the S2 resolution functions
;;; called by execute-resolution-actions! in metavar-store.rkt.
;;;
;;; Breaking circular deps: metavar-store.rkt cannot import unify.rkt
;;; or driver.rkt directly. This module bridges the gap — it imports
;;; both and provides direct resolution functions that metavar-store.rkt
;;; can call without callback parameters.
;;;

(require racket/match
         racket/string
         "syntax.rkt"
         "metavar-store.rkt"
         "elab-network-types.rkt"   ;; Track 8 C1: elab-network-prop-net, elab-network-rewrap
         "propagator.rkt"           ;; Track 8D: net-cell-read for pure bridges
         "unify.rkt"
         "zonk.rkt"
         "trait-resolution.rkt"
         "macros.rkt"
         "infra-cell.rkt"
         "performance-counters.rkt")

(provide retry-unify-constraint!
         resolve-trait-constraint!
         resolve-hasmethod-constraint!
         ;; Track 7 Phase 7a: single dispatcher replacing 3 callbacks
         resolution-execute-action!
         ;; Track 7 Phase 7b: pure variants (enet → enet*)
         retry-unify-constraint-pure
         resolve-trait-constraint-pure
         resolve-hasmethod-constraint-pure
         resolution-execute-action-pure
         ;; Track 8 C1-C3: Bridge propagator fire functions (pnet → pnet) — LEGACY
         make-trait-resolution-bridge-fire-fn
         make-hasmethod-resolution-bridge-fire-fn
         make-constraint-retry-bridge-fire-fn
         ;; Track 8D: Pure bridge factories (return (pnet → pnet) fire functions)
         make-pure-trait-bridge-factory
         make-pure-hasmethod-bridge-factory)

;; ========================================
;; Constraint Retry (extracted from unify.rkt module-level callback)
;; ========================================
;; When a postponed constraint's dependency metas are solved, retry
;; unification. Uses unify-core (not unify) to avoid double propagator
;; checking — the retry is triggered by the stratified resolution loop.

(define (retry-unify-constraint! c)
  (let ([lhs (zonk-at-depth 0 (constraint-lhs c))]
        [rhs (zonk-at-depth 0 (constraint-rhs c))])
    (define result (unify-core (constraint-ctx c) lhs rhs))
    (cond
      [(eq? result #t)
       (write-constraint-to-store! (struct-copy constraint c [status 'solved]))
       (write-constraint-status-cell! (constraint-cid c) 'resolved)]
      [(eq? result #f)
       (write-constraint-to-store! (struct-copy constraint c [status 'failed]))
       (write-constraint-status-cell! (constraint-cid c) 'resolved)]
      ;; 'postponed: leave status as-is (will be set back to 'postponed
      ;; by the caller if still 'retrying)
      )))

;; ========================================
;; Trait Resolution (extracted from driver.rkt callback)
;; ========================================
;; When a trait constraint's type-arg metas are all ground, attempt
;; monomorphic then parametric resolution. On success, solve the dict meta.
;; On failure, record an error descriptor for the post-fixpoint error sweep.

(define (resolve-trait-constraint! dict-meta-id tc-info)
  (define trait-name (trait-constraint-info-trait-name tc-info))
  (define type-args
    (map (lambda (e) (normalize-for-resolution (zonk e)))
         (trait-constraint-info-type-arg-exprs tc-info)))
  (when (andmap ground-expr? type-args)
    (define dict-expr
      (or (try-monomorphic-resolve trait-name type-args)
          (try-parametric-resolve trait-name type-args)))
    (if dict-expr
        (solve-meta! dict-meta-id dict-expr)
        ;; Track 2 Phase 7: Write error descriptor on resolution failure.
        (write-error-descriptor! dict-meta-id
          (build-trait-error dict-meta-id trait-name type-args)))))

;; ========================================
;; HasMethod Resolution (extracted from driver.rkt callback)
;; ========================================
;; When a hasmethod constraint's dependency metas (trait-var + type-args)
;; are all ground, resolve by finding the trait with the method,
;; resolving the dict, and projecting the method.

(define (resolve-hasmethod-constraint! meta-id hm-info)
  (unless (meta-solved? meta-id)
    (define method-name (hasmethod-constraint-info-method-name hm-info))
    (define type-args
      (map (lambda (e) (normalize-for-resolution (zonk e)))
           (hasmethod-constraint-info-type-arg-exprs hm-info)))
    (when (andmap ground-expr? type-args)
      ;; Strategy 1: P (trait var) is already ground
      (define trait-expr (zonk (hasmethod-constraint-info-trait-var-expr hm-info)))
      (define known-trait-name (and (ground-expr? trait-expr) (trait-expr->name trait-expr)))
      ;; Strategy 2: P is not ground — search all traits for the method name
      (define resolved-trait-name
        (or known-trait-name
            (find-trait-with-method method-name type-args)))
      (when resolved-trait-name
        (define tm (lookup-trait resolved-trait-name))
        (when tm
          (define methods (trait-meta-methods tm))
          (define method-idx
            (for/or ([m (in-list methods)] [i (in-naturals)])
              (and (eq? (trait-method-name m) method-name) i)))
          (when method-idx
            ;; Resolve the dict via standard impl resolution
            (define dict-expr
              (or (try-monomorphic-resolve resolved-trait-name type-args)
                  (try-parametric-resolve resolved-trait-name type-args)))
            (when dict-expr
              ;; Solve the trait variable P if it's still a meta
              (define trait-var-expr (hasmethod-constraint-info-trait-var-expr hm-info))
              (when (and (expr-meta? trait-var-expr)
                         (not (meta-solved? (expr-meta-id trait-var-expr))))
                (solve-meta! (expr-meta-id trait-var-expr) (expr-fvar resolved-trait-name)))
              ;; Optionally solve the dict meta if present
              (define dict-meta-id (hasmethod-constraint-info-dict-meta-id hm-info))
              (when (and dict-meta-id (not (meta-solved? dict-meta-id)))
                (solve-meta! dict-meta-id dict-expr))
              ;; Project the method and solve the evidence meta.
              (unless (meta-solved? meta-id)
                (define projected (project-method dict-expr tm method-idx))
                (solve-meta! meta-id projected)))))))))

;; ========================================
;; Track 7 Phase 7a: Unified Resolution Dispatcher
;; ========================================
;; Single function replacing 3 callback parameters.
;; Called from execute-resolution-actions! in metavar-store.rkt.

(define (resolution-execute-action! action)
  (match action
    [(action-retry-constraint c)
     ;; Re-check: constraint may have been resolved by a prior action.
     (define c-cid (constraint-cid c))
     (define current-c (read-constraint-by-cid c-cid))
     (when (and current-c (eq? (constraint-status current-c) 'postponed))
       (perf-inc-constraint-retry!)
       (write-constraint-to-store! (struct-copy constraint current-c [status 'retrying]))
       (retry-unify-constraint! current-c)
       (define post-c (read-constraint-by-cid c-cid))
       (when (and post-c (eq? (constraint-status post-c) 'retrying))
         (write-constraint-to-store! (struct-copy constraint post-c [status 'postponed]))))]
    [(action-resolve-trait dict-id tc-info)
     (unless (meta-solved? dict-id)
       (resolve-trait-constraint! dict-id tc-info))]
    [(action-resolve-hasmethod hm-id hm-info)
     (unless (meta-solved? hm-id)
       (resolve-hasmethod-constraint! hm-id hm-info))]))

;; ========================================
;; Track 7 Phase 7b: Pure Resolution Functions (enet → enet*)
;; ========================================
;;
;; These take an elab-network and return an updated elab-network.
;; Read-path functions (zonk, ground-expr?, normalize-for-resolution) are
;; bridged via parameterize on current-prop-net-box — a tight local scope
;; that maintains data-in → data-out at the contract boundary. This avoids
;; duplicating 500+ lines of zonk/unify pattern-matching code. Track 8
;; (metas as propagator cells) will eliminate this bridge entirely.

;; Bridge: temporarily set the net-box so existing read functions see the enet.
(define-syntax-rule (with-enet-reads enet body ...)
  (parameterize ([current-prop-net-box (box enet)])
    body ...))

;; Pure constraint retry: enet → enet*
(define (retry-unify-constraint-pure enet c)
  (with-enet-reads enet
    (let ([lhs (zonk-at-depth 0 (constraint-lhs c))]
          [rhs (zonk-at-depth 0 (constraint-rhs c))])
      (define result (unify-core (constraint-ctx c) lhs rhs))
      (cond
        [(eq? result #t)
         (define enet1 (write-constraint-to-store-pure enet
                         (struct-copy constraint c [status 'solved])))
         (write-constraint-status-cell-pure enet1 (constraint-cid c) 'resolved)]
        [(eq? result #f)
         (define enet1 (write-constraint-to-store-pure enet
                         (struct-copy constraint c [status 'failed])))
         (write-constraint-status-cell-pure enet1 (constraint-cid c) 'resolved)]
        [else enet]))))

;; Pure trait resolution: enet → enet*
(define (resolve-trait-constraint-pure enet dict-meta-id tc-info)
  (with-enet-reads enet
    (define trait-name (trait-constraint-info-trait-name tc-info))
    (define type-args
      (map (lambda (e) (normalize-for-resolution (zonk e)))
           (trait-constraint-info-type-arg-exprs tc-info)))
    (cond
      [(not (andmap ground-expr? type-args)) enet]
      [(or (try-monomorphic-resolve trait-name type-args)
           (try-parametric-resolve trait-name type-args))
       => (lambda (dict-expr)
            (define-values (enet* _) (solve-meta-core-pure enet dict-meta-id dict-expr))
            enet*)]
      [else
       (write-error-descriptor-pure enet dict-meta-id
         (build-trait-error dict-meta-id trait-name type-args))])))

;; Pure hasmethod resolution: enet → enet*
(define (resolve-hasmethod-constraint-pure enet meta-id hm-info)
  (with-enet-reads enet
    (cond
      [(meta-solved? meta-id) enet]  ;; already solved
      [else
       (define method-name (hasmethod-constraint-info-method-name hm-info))
       (define type-args
         (map (lambda (e) (normalize-for-resolution (zonk e)))
              (hasmethod-constraint-info-type-arg-exprs hm-info)))
       (cond
         [(not (andmap ground-expr? type-args)) enet]
         [else
          (define trait-expr (zonk (hasmethod-constraint-info-trait-var-expr hm-info)))
          (define known-trait-name
            (and (ground-expr? trait-expr) (trait-expr->name trait-expr)))
          (define resolved-trait-name
            (or known-trait-name
                (find-trait-with-method method-name type-args)))
          (cond
            [(not resolved-trait-name) enet]
            [else
             (define tm (lookup-trait resolved-trait-name))
             (cond
               [(not tm) enet]
               [else
                (define methods (trait-meta-methods tm))
                (define method-idx
                  (for/or ([m (in-list methods)] [i (in-naturals)])
                    (and (eq? (trait-method-name m) method-name) i)))
                (cond
                  [(not method-idx) enet]
                  [else
                   (define dict-expr
                     (or (try-monomorphic-resolve resolved-trait-name type-args)
                         (try-parametric-resolve resolved-trait-name type-args)))
                   (cond
                     [(not dict-expr) enet]
                     [else
                      ;; Solve trait variable P if still a meta
                      (define trait-var-expr (hasmethod-constraint-info-trait-var-expr hm-info))
                      (define enet1
                        (if (and (expr-meta? trait-var-expr)
                                 (not (meta-solved? (expr-meta-id trait-var-expr))))
                            (let-values ([(e _) (solve-meta-core-pure enet (expr-meta-id trait-var-expr)
                                                                      (expr-fvar resolved-trait-name))])
                              e)
                            enet))
                      ;; Solve dict meta if present
                      (define dict-meta-id (hasmethod-constraint-info-dict-meta-id hm-info))
                      (define enet2
                        (if (and dict-meta-id (not (meta-solved? dict-meta-id)))
                            (let-values ([(e _) (solve-meta-core-pure enet1 dict-meta-id dict-expr)]) e)
                            enet1))
                      ;; Project method and solve evidence meta
                      (if (meta-solved? meta-id)
                          enet2
                          (let ([projected (project-method dict-expr tm method-idx)])
                            (let-values ([(e _) (solve-meta-core-pure enet2 meta-id projected)]) e)))])])])])])])))

;; Pure unified dispatcher: enet → enet*
(define (resolution-execute-action-pure enet action)
  (match action
    [(action-retry-constraint c)
     (define c-cid (constraint-cid c))
     (define current-c (read-constraint-by-cid-pure enet c-cid))
     (cond
       [(and current-c (eq? (constraint-status current-c) 'postponed))
        (perf-inc-constraint-retry!)
        (define enet1 (write-constraint-to-store-pure enet
                        (struct-copy constraint current-c [status 'retrying])))
        (define enet2 (retry-unify-constraint-pure enet1 current-c))
        (define post-c (read-constraint-by-cid-pure enet2 c-cid))
        (if (and post-c (eq? (constraint-status post-c) 'retrying))
            (write-constraint-to-store-pure enet2
              (struct-copy constraint post-c [status 'postponed]))
            enet2)]
       [else enet])]
    [(action-resolve-trait dict-id tc-info)
     (with-enet-reads enet
       (if (meta-solved? dict-id)
           enet
           (resolve-trait-constraint-pure enet dict-id tc-info)))]
    [(action-resolve-hasmethod hm-id hm-info)
     (with-enet-reads enet
       (if (meta-solved? hm-id)
           enet
           (resolve-hasmethod-constraint-pure enet hm-id hm-info)))]))

;; ========================================
;; Track 8 C1: Resolution Bridge Fire Functions
;; ========================================
;;
;; These functions are used as bridge propagator fire functions, executing
;; during S0 quiescence. They bridge from prop-network (the quiescence
;; domain) to elab-network (the resolution domain):
;;   1. Read the enet from the box
;;   2. Rewrap with the current pnet (quiescence has been modifying pnet)
;;   3. Call the pure resolution function
;;   4. Write updated enet back to box
;;   5. Return the updated pnet (for quiescence loop)
;;
;; This moves trait/hasmethod resolution from S2 (post-quiescence) into
;; S0 (during quiescence). The existing readiness propagators (threshold →
;; fan-in → ready-queue) remain as fallback — if the bridge resolves the
;; dict, the S2 action is a no-op (meta already solved).

;; Returns a function suitable for current-trait-resolution-bridge-fn.
;; The returned function has signature: (pnet dict-meta-id tc-info dep-cids → pnet)
(define (make-trait-resolution-bridge-fire-fn)
  (lambda (pnet dict-meta-id tc-info dep-cids)
    ;; Early exit: already solved
    (define net-box (current-prop-net-box))
    (cond
      [(not net-box) pnet]
      [(meta-solved? dict-meta-id) pnet]
      [else
       ;; Sync box with current pnet from quiescence loop
       (define enet-base (unbox net-box))
       (define enet (elab-network-rewrap enet-base pnet))
       ;; Attempt resolution (pure: enet → enet*)
       (define enet* (resolve-trait-constraint-pure enet dict-meta-id tc-info))
       ;; Write back to box (meta-info updates persist for subsequent reads)
       (set-box! net-box enet*)
       ;; Return updated pnet for quiescence loop
       (elab-network-prop-net enet*)])))

;; Returns a function suitable for current-hasmethod-resolution-bridge-fn.
;; Same pattern as trait bridge.
(define (make-hasmethod-resolution-bridge-fire-fn)
  (lambda (pnet meta-id hm-info dep-cids)
    (define net-box (current-prop-net-box))
    (cond
      [(not net-box) pnet]
      [(meta-solved? meta-id) pnet]
      [else
       (define enet-base (unbox net-box))
       (define enet (elab-network-rewrap enet-base pnet))
       (define enet* (resolve-hasmethod-constraint-pure enet meta-id hm-info))
       (set-box! net-box enet*)
       (elab-network-prop-net enet*)])))

;; Track 8 C3: Constraint retry bridge fire function.
;; Returns a function suitable for current-constraint-retry-bridge-fn.
;; Signature: (pnet constraint dep-cids → pnet)
(define (make-constraint-retry-bridge-fire-fn)
  (lambda (pnet c dep-cids)
    (define net-box (current-prop-net-box))
    (cond
      [(not net-box) pnet]
      [else
       ;; Read the current constraint status — only retry if still postponed
       (define enet-base (unbox net-box))
       (define enet (elab-network-rewrap enet-base pnet))
       (define current-c (read-constraint-by-cid-pure enet (constraint-cid c)))
       (cond
         [(not current-c) pnet]
         [(not (eq? (constraint-status current-c) 'postponed)) pnet]
         [else
          (define enet* (retry-unify-constraint-pure enet current-c))
          (set-box! net-box enet*)
          (elab-network-prop-net enet*)])])))

;; ========================================
;; Track 8D: Pure Bridge Fire Functions (pnet → pnet, NO enet-box)
;; ========================================
;;
;; These fire functions read cell values directly from the prop-network
;; passed by the quiescence loop. No unbox, no set-box!, no enet-rewrap.
;;
;; Meta type-arg values are read from dependency cells (already resolved
;; — cell values ARE the solutions, no zonk needed).
;;
;; Registry lookups read from the persistent registry network via
;; net-cell-read on the persistent-registry-net-box. This is a monotone
;; read from a stable source (registries only grow, never shrink).
;;
;; The fire function writes to the dict-meta cell on the per-command
;; prop-network — a pure net-cell-write.

;; Helper: read a hash from a persistent registry cell.
;; Returns the hash value, or (hasheq) if not available.
(define (read-persistent-registry-cell cid)
  (define prn-box (current-persistent-registry-net-box))
  (if (and cid prn-box)
      (let ([v (net-cell-read (unbox prn-box) cid)])
        (if v v (hasheq)))
      (hasheq)))

;; Inline type-lattice predicates (avoid requiring type-lattice.rkt — cycle).
(define (prop-type-bot? v) (eq? v 'type-bot))
(define (prop-type-top? v) (eq? v 'type-top))

;; Helper: check if a cell value is a resolved type (not bot/top/meta).
(define (resolved-cell-value? v)
  (and v
       (not (prop-type-bot? v))
       (not (prop-type-top? v))))

;; Pure trait resolution bridge FACTORY.
;; Returns a factory function: (trait-name dict-cell-id dep-cell-ids → (pnet → pnet))
;; The factory captures registry cell IDs at creation time (from driver.rkt).
;; Each call produces a per-constraint fire function that reads cells directly.
(define (make-pure-trait-bridge-factory)
  (define impl-reg-cid (current-impl-registry-cell-id))
  (define param-impl-reg-cid (current-param-impl-registry-cell-id))
  (lambda (trait-name dict-cell-id dep-cell-ids)
    (make-pure-trait-bridge-fire-fn trait-name dict-cell-id dep-cell-ids impl-reg-cid param-impl-reg-cid)))

;; Pure trait resolution bridge fire function.
;; Closed over: trait-name, dict-cell-id, dep-cell-ids, impl-registry-cell-id.
;; Fire function: pnet → pnet (pure).
(define (make-pure-trait-bridge-fire-fn trait-name dict-cell-id dep-cell-ids impl-reg-cid param-impl-reg-cid)
  (lambda (pnet)
    ;; Early exit: dict already solved
    (define dict-val (net-cell-read pnet dict-cell-id))
    (cond
      [(resolved-cell-value? dict-val) pnet]  ;; already resolved
      [else
       ;; Read dependency cell values (type-arg solutions)
       (define type-arg-vals
         (for/list ([cid (in-list dep-cell-ids)])
           (net-cell-read pnet cid)))
       ;; All resolved? (no bot/top)
       (cond
         [(not (andmap resolved-cell-value? type-arg-vals)) pnet]  ;; not all ground yet
         [else
          ;; Build impl key from ground type-arg values
          (define type-arg-str
            (string-join (map expr->impl-key-str type-arg-vals) "-"))
          (define impl-key
            (string->symbol (string-append type-arg-str "--" (symbol->string trait-name))))
          ;; Read impl registry from persistent network cell
          (define impl-reg (read-persistent-registry-cell impl-reg-cid))
          (define entry (hash-ref impl-reg impl-key #f))
          (cond
            [entry
             ;; Monomorphic resolution succeeded — write dict to cell
             (net-cell-write pnet dict-cell-id (expr-fvar (impl-entry-dict-name entry)))]
            [else
             ;; Try parametric resolution
             (define param-impl-reg (read-persistent-registry-cell param-impl-reg-cid))
             (define param-entries (hash-ref param-impl-reg trait-name '()))
             (cond
               [(null? param-entries) pnet]  ;; no parametric impls — leave for S2
               [else
                ;; Match type-arg values against parametric patterns
                (define matches
                  (for/fold ([acc '()])
                            ([pe (in-list param-entries)])
                    (define bindings (match-type-args-pure type-arg-vals (param-impl-entry-type-pattern pe)))
                    (if bindings
                        (cons (cons pe bindings) acc)
                        acc)))
                (cond
                  [(null? matches) pnet]  ;; no match
                  [else
                   ;; Pick most specific (fewest pattern vars)
                   (define sorted
                     (sort matches < #:key (lambda (m) (length (param-impl-entry-pattern-vars (car m))))))
                   (define best (car sorted))
                   (define pe (car best))
                   (define bindings (cdr best))
                   ;; Build the dict expression with resolved sub-dicts
                   (define dict-expr
                     (build-parametric-dict-expr-pure
                       trait-name type-arg-vals pe bindings impl-reg param-impl-reg))
                   (if dict-expr
                       (net-cell-write pnet dict-cell-id dict-expr)
                       pnet)])])])])])))

;; Pure hasmethod resolution bridge FACTORY.
;; Returns a factory: (method-name meta-cell-id trait-var-cell-id dict-meta-cell-id dep-cell-ids → (pnet → pnet))
(define (make-pure-hasmethod-bridge-factory)
  (define trait-reg-cid (current-trait-registry-cell-id))
  (define impl-reg-cid (current-impl-registry-cell-id))
  (define param-impl-reg-cid (current-param-impl-registry-cell-id))
  (lambda (method-name meta-cell-id trait-var-cell-id dict-meta-cell-id dep-cell-ids)
    (make-pure-hasmethod-bridge-fire-fn method-name meta-cell-id trait-var-cell-id
                                         dict-meta-cell-id dep-cell-ids
                                         trait-reg-cid impl-reg-cid param-impl-reg-cid)))

;; Pure hasmethod resolution bridge fire function.
(define (make-pure-hasmethod-bridge-fire-fn method-name meta-cell-id trait-var-cell-id
                                            dict-meta-cell-id dep-cell-ids
                                            trait-reg-cid impl-reg-cid param-impl-reg-cid)
  (lambda (pnet)
    ;; Early exit: already resolved
    (define meta-val (net-cell-read pnet meta-cell-id))
    (cond
      [(resolved-cell-value? meta-val) pnet]
      [else
       ;; Read dependency cell values
       (define type-arg-vals
         (for/list ([cid (in-list dep-cell-ids)])
           (net-cell-read pnet cid)))
       (cond
         [(not (andmap resolved-cell-value? type-arg-vals)) pnet]
         [else
          ;; Read trait registry to find which trait has this method
          (define trait-reg (read-persistent-registry-cell trait-reg-cid))
          (define resolved-trait-name
            ;; Check if trait variable is already ground
            (let ([tv (and trait-var-cell-id (net-cell-read pnet trait-var-cell-id))])
              (if (and tv (resolved-cell-value? tv))
                  (trait-expr->name tv)
                  ;; Search all traits for the method
                  (find-trait-with-method-from-hash method-name type-arg-vals trait-reg))))
          (cond
            [(not resolved-trait-name) pnet]
            [else
             ;; Look up the trait to get method index
             (define tm (hash-ref trait-reg resolved-trait-name #f))
             (cond
               [(not tm) pnet]
               [else
                (define methods (trait-meta-methods tm))
                (define method-idx
                  (for/or ([m (in-list methods)] [i (in-naturals)])
                    (and (eq? (trait-method-name m) method-name) i)))
                (cond
                  [(not method-idx) pnet]
                  [else
                   ;; Resolve the dict via impl registry
                   (define impl-reg (read-persistent-registry-cell impl-reg-cid))
                   (define param-impl-reg (read-persistent-registry-cell param-impl-reg-cid))
                   (define type-arg-str
                     (string-join (map expr->impl-key-str type-arg-vals) "-"))
                   (define dict-key
                     (string->symbol (string-append type-arg-str "--" (symbol->string resolved-trait-name))))
                   (define dict-entry (hash-ref impl-reg dict-key #f))
                   (define dict-expr
                     (cond
                       [dict-entry (expr-fvar (impl-entry-dict-name dict-entry))]
                       [else
                        ;; Try parametric
                        (define param-entries (hash-ref param-impl-reg resolved-trait-name '()))
                        (define match-result
                          (for/or ([pe (in-list param-entries)])
                            (define bindings (match-type-args-pure type-arg-vals (param-impl-entry-type-pattern pe)))
                            (and bindings (cons pe bindings))))
                        (and match-result
                             (build-parametric-dict-expr-pure
                               resolved-trait-name type-arg-vals
                               (car match-result) (cdr match-result)
                               impl-reg param-impl-reg))]))
                   (cond
                     [(not dict-expr) pnet]
                     [else
                      ;; Solve trait variable if still unsolved
                      (define pnet1
                        (if (and trait-var-cell-id
                                 (not (resolved-cell-value? (net-cell-read pnet trait-var-cell-id))))
                            (net-cell-write pnet trait-var-cell-id (expr-fvar resolved-trait-name))
                            pnet))
                      ;; Solve dict meta if present
                      (define pnet2
                        (if (and dict-meta-cell-id
                                 (not (resolved-cell-value? (net-cell-read pnet1 dict-meta-cell-id))))
                            (net-cell-write pnet1 dict-meta-cell-id dict-expr)
                            pnet1))
                      ;; Project method and solve evidence meta
                      (define projected (project-method dict-expr tm method-idx))
                      (net-cell-write pnet2 meta-cell-id projected)])])])])])])))

;; ========================================
;; Track 8D: Pure Helper Functions (no box/parameter access)
;; ========================================

;; Match type-arg values against a parametric impl's type pattern.
;; Returns bindings alist or #f.
;; Pure: operates only on the values passed, no parameter reads.
(define (match-type-args-pure type-arg-vals pattern)
  (define (match-one val pat bindings)
    (cond
      [(symbol? pat)
       ;; Pattern variable — check if already bound
       (define existing (assq pat bindings))
       (if existing
           (and (equal? (cdr existing) val) bindings)
           (cons (cons pat val) bindings))]
      [(and (pair? pat) (pair? (cdr pat)))
       ;; Compound pattern — recursive match
       (match-compound val pat bindings)]
      [else
       ;; Literal — must match exactly
       (and (equal? (list pat) (list val)) bindings)]))
  ;; match-compound handles (List A), (Map K V), etc.
  (define (match-compound val pat bindings)
    (match pat
      [`(,tag . ,sub-pats)
       (define val-parts (decompose-type-for-match val tag))
       (and val-parts
            (= (length val-parts) (length sub-pats))
            (for/fold ([b bindings])
                      ([v (in-list val-parts)]
                       [p (in-list sub-pats)]
                       #:break (not b))
              (match-one v p b)))]
      [_ #f]))
  ;; Top-level: match each type-arg against corresponding pattern element
  (and (= (length type-arg-vals) (length pattern))
       (for/fold ([b '()])
                 ([v (in-list type-arg-vals)]
                  [p (in-list pattern)]
                  #:break (not b))
         (match-one v p b))))

;; Decompose a type value for pattern matching.
;; Returns list of components or #f if tag doesn't match.
(define (decompose-type-for-match val tag)
  (match (cons tag val)
    [(cons 'List (expr-fvar name))
     (and (memq name '(List prologos::data::list::List)) '())]
    [(cons 'List (expr-app (expr-fvar name) a))
     (and (memq name '(List prologos::data::list::List)) (list a))]
    [(cons 'PVec (expr-PVec a)) (list a)]
    [(cons 'Set (expr-Set a)) (list a)]
    [(cons 'Map (expr-Map k v)) (list k v)]
    [(cons 'Option (expr-app (expr-fvar name) a))
     (and (memq name '(Option prologos::data::option::Option some none)) (list a))]
    [_ #f]))

;; Build a parametric dict expression from resolved bindings.
;; Pure: uses the passed registry hashes, no parameter reads.
(define (build-parametric-dict-expr-pure trait-name type-arg-vals pe bindings impl-reg param-impl-reg)
  ;; Resolve where-constraints sub-dicts
  (define where-constraints (param-impl-entry-where-constraints pe))
  (define sub-dicts
    (for/list ([wc (in-list where-constraints)])
      (define wc-trait (car wc))
      (define wc-type-args
        (for/list ([pat (in-list (cdr wc))])
          (cond
            [(assq pat bindings) => cdr]
            [else pat])))  ;; literal type arg
      ;; Resolve sub-dict
      (define wc-key-str (string-join (map expr->impl-key-str wc-type-args) "-"))
      (define wc-key (string->symbol (string-append wc-key-str "--" (symbol->string wc-trait))))
      (define wc-entry (hash-ref impl-reg wc-key #f))
      (cond
        [wc-entry (expr-fvar (impl-entry-dict-name wc-entry))]
        [else
         ;; Try parametric for sub-dict
         (define wc-param-entries (hash-ref param-impl-reg wc-trait '()))
         (define wc-match
           (for/or ([wpe (in-list wc-param-entries)])
             (define wb (match-type-args-pure wc-type-args (param-impl-entry-type-pattern wpe)))
             (and wb (cons wpe wb))))
         (and wc-match
              (build-parametric-dict-expr-pure
                wc-trait wc-type-args (car wc-match) (cdr wc-match) impl-reg param-impl-reg))])))
  ;; If any sub-dict failed, overall resolution fails
  (and (andmap values sub-dicts)
       (let* ([dict-name (param-impl-entry-dict-name pe)]
              [base (expr-fvar dict-name)])
         ;; Apply sub-dicts as arguments
         (for/fold ([e base])
                   ([sd (in-list sub-dicts)])
           (expr-app e sd)))))

;; Find which trait contains a given method, from a registry hash.
;; Pure: no parameter reads.
(define (find-trait-with-method-from-hash method-name type-arg-vals trait-reg)
  (for/or ([(name tm) (in-hash trait-reg)])
    (and (for/or ([m (in-list (trait-meta-methods tm))])
           (eq? (trait-method-name m) method-name))
         name)))

#lang racket/base

;;;
;;; EFFECT EXECUTOR — Layer 5 Effect Handler (AD-E)
;;;
;;; The ONLY non-monotone step in the Architecture D pipeline.
;;; Everything before this (position computation, ordering, transitive
;;; closure, linearization) is monotone and lives in the propagator network.
;;; This module is the Layer 5 barrier — where the CALM theorem requires
;;; coordination.
;;;
;;; AD-E1: Linearization is in effect-ordering.rkt (linearize-effects).
;;; AD-E2: execute-effects — performs actual IO in linearized order.
;;; AD-E3: rt-execute-process-d — full Architecture D pipeline entry point.
;;;
;;; See: docs/tracking/2026-03-07_ARCHITECTURE_AD_IMPLEMENTATION_DESIGN.org §9
;;;

(require racket/match
         "effect-ordering.rkt"
         "effect-position.rkt"
         "io-bridge.rkt"
         "pretty-print.rkt"
         "processes.rkt"
         "propagator.rkt"
         "sessions.rkt"
         "session-lattice.rkt"
         "session-runtime.rkt"
         "syntax.rkt")

(provide
 ;; AD-E2: Effect executor
 execute-effects
 execute-effects-and-propagate
 ;; AD-E3: Full D pipeline
 rt-execute-process-d
 ;; AD-F2: Unified architecture dispatch
 rt-execute-process-auto
 ;; AD-F3: Concurrent hooks (placeholders for S8b runtime)
 current-effect-executor
 default-effect-executor
 concurrent-effect-executor)


;; ========================================
;; AD-E2: Effect Executor
;; ========================================

;; Execute a linearized list of effect descriptors.
;; Performs actual IO operations in the given order.
;;
;; Error handling follows the existing io-bridge.rkt pattern: filesystem errors
;; are caught and the execution continues (errors detectable in post-execution
;; verification via Stratum 3).
;;
;; rnet    : runtime-network
;; effects : list of effect-desc (already linearized)
;; Returns : (values rnet* results open-ports)
;;   results:    hash eff-pos → any (IO results keyed by position)
;;   open-ports: hash channel → port
(define (execute-effects rnet effects)
  (for/fold ([rnet* rnet]
             [results (hash)]       ;; equal?-based (eff-pos struct keys)
             [open-ports (hasheq)]) ;; symbol keys for channels
            ([eff (in-list effects)])
    (match eff
      [(eff-open chan pos path mode)
       (with-handlers
         ([exn:fail?
           (lambda (e)
             (values rnet*
                     (hash-set results pos (format "IO error: ~a" (exn-message e)))
                     open-ports))])
         (define port
           (case mode
             [(read)   (open-input-file path #:mode 'text)]
             [(write)  (open-output-file path #:mode 'text #:exists 'truncate)]
             [(append) (open-output-file path #:mode 'text #:exists 'append)]))
         (values rnet*
                 (hash-set results pos port)
                 (hash-set open-ports chan port)))]

      [(eff-write chan pos value)
       (define port (hash-ref open-ports chan #f))
       (cond
         [(not port)
          (values rnet* (hash-set results pos "no open port") open-ports)]
         [else
          (with-handlers
            ([exn:fail? (lambda (e)
                          (values rnet* (hash-set results pos (exn-message e)) open-ports))])
            (define str-val (if (expr-string? value)
                                (expr-string-val value)
                                (format "~a" value)))
            (write-string str-val port)
            (flush-output port)
            (values rnet* (hash-set results pos (void)) open-ports))])]

      [(eff-read chan pos)
       (define port (hash-ref open-ports chan #f))
       (cond
         [(not port)
          (values rnet* (hash-set results pos "no open port") open-ports)]
         [else
          (with-handlers
            ([exn:fail? (lambda (e)
                          (values rnet* (hash-set results pos (exn-message e)) open-ports))])
            (define data (read-string 1048576 port))  ;; 1MB max, matching Architecture A
            (define result-str (if (eof-object? data) "" data))
            (values rnet* (hash-set results pos result-str) open-ports))])]

      [(eff-close chan pos)
       (define port (hash-ref open-ports chan #f))
       (when port
         (with-handlers ([exn:fail? void])
           (cond [(input-port? port) (close-input-port port)]
                 [(output-port? port) (close-output-port port)])))
       (values rnet*
               (hash-set results pos (void))
               (hash-remove open-ports chan))])))


;; Execute effects and feed results back into the propagator network.
;; This is the complete Layer 5 barrier: execute → feed back → verify.
;;
;; rnet        : runtime-network
;; effects     : list of effect-desc (already linearized)
;; channel-eps : hasheq symbol → channel-endpoint
;; Returns: (values rnet* results)
;;   rnet*:   runtime-network after post-execution quiescence
;;   results: hash eff-pos → any
(define (execute-effects-and-propagate rnet effects channel-eps)
  (define-values (rnet* results open-ports) (execute-effects rnet effects))
  ;; Feed read results back into msg-in cells for post-execution verification
  (define rnet**
    (for/fold ([net rnet*])
              ([eff (in-list effects)]
               #:when (eff-read? eff))
      (define pos (eff-read-position eff))
      (define val (hash-ref results pos #f))
      (if (and val (string? val))
          (let* ([chan (eff-read-channel eff)]
                 [ep (hash-ref channel-eps chan #f)])
            (if ep
                (rt-cell-write net (channel-endpoint-msg-in-cell ep) (expr-string val))
                net))
          net)))
  ;; Run to quiescence: session advancement, protocol completion, contradiction detection
  (values (rt-run-to-quiescence rnet**) results))


;; ========================================
;; AD-E3: Full Architecture D Pipeline
;; ========================================

;; Execute a process using Architecture D (session-derived effect ordering).
;;
;; Pipeline:
;; 1. Compile with effect collection (#:collect-effects? #t)
;; 2. Extract data-flow edges from process AST
;; 3. Compute session ordering edges from session types
;; 4. Build complete ordering (transitive closure via propagator)
;; 5. Linearize effects
;; 6. Execute effects (Layer 5 barrier)
;; 7. Feed results back, run to quiescence, check contradictions
;;
;; Returns: rt-exec-result
(define (rt-execute-process-d proc session-type [fuel 1000000])
  ;; 1. Create runtime network
  (define rnet0 (make-runtime-network fuel))
  ;; 2. Create channel pair for 'self with trivial session (sess-end).
  ;; The process communicates via IO channels (proc-open creates 'ch),
  ;; not via 'self. The session-type parameter governs ordering, not 'self.
  (define-values (rnet1 pair) (rt-new-channel-pair rnet0 (sess-end)))
  (define ep-a (channel-pair-ep-a pair))
  (define ep-b (channel-pair-ep-b pair))
  (define rnet2 (rt-cross-wire-choice rnet1 ep-a ep-b))
  (define rnet3 (rt-register-channel rnet2 'self ep-a))
  ;; 3. Compile with effect collection
  (define channel-eps (hasheq 'self ep-a))
  (define init-trace
    (hasheq (channel-endpoint-session-cell ep-a)
      (list (format "IO session type: ~a (Architecture D)" (pp-session session-type)))))
  (define-values (rnet4 bindings trace)
    (compile-live-process rnet3 proc channel-eps (hasheq) init-trace
                          #:collect-effects? #t))
  ;; 4. Extract effects
  (define effects (effect-set-effects (get-effect-acc bindings)))
  ;; If no effects, short-circuit (pure process or non-IO)
  (cond
    [(null? effects)
     ;; No effects — just run to quiescence for session verification
     (define rnet5 (rt-run-to-quiescence rnet4))
     (cond
       [(rt-contradiction? rnet5)
        (rt-exec-result 'contradiction bindings rnet5 trace)]
       [else
        (rt-exec-result 'ok bindings rnet5 trace)])]
    [else
     ;; 5. Extract data-flow edges from process AST
     (define df-edges (extract-data-flow-edges proc))
     ;; 6. Compute session ordering edges
     ;; For proc-open processes, the IO channel is 'ch with the given session type
     (define sess-edges (session-ordering-edges 'ch session-type))
     ;; 7. Build complete ordering
     (define combined-ordering
       (eff-ordering (append sess-edges
                             (map (lambda (e) e) df-edges))))
     (define complete-ordering (eff-ordering-transitive-closure combined-ordering))
     ;; 8. Check for deadlock (cycle)
     (cond
       [(eff-ordering-has-cycle? complete-ordering)
        (rt-exec-result 'contradiction bindings rnet4
          (hash-set trace 'deadlock
            (list "Deadlock detected: cyclic ordering in effect dependencies")))]
       [else
        ;; 9. Linearize effects
        (define linearized (linearize-effects complete-ordering effects))
        (cond
          [(not linearized)
           ;; Linearization failed (cycle in effects)
           (rt-exec-result 'contradiction bindings rnet4
             (hash-set trace 'deadlock
               (list "Linearization failed: cyclic effect ordering")))]
          [else
           ;; 10. Execute effects (Layer 5 barrier)
           (define-values (rnet5 results)
             (execute-effects-and-propagate rnet4 linearized channel-eps))
           ;; 11. Check for contradictions
           (cond
             [(rt-contradiction? rnet5)
              (rt-exec-result 'contradiction
                (hash-set bindings '__effect_results results) rnet5 trace)]
             [else
              (rt-exec-result 'ok
                (hash-set bindings '__effect_results results) rnet5 trace)])])])]))


;; ========================================
;; AD-F2: Unified Architecture Dispatch
;; ========================================

;; Execute a process with automatic architecture selection.
;; Dispatches between Architecture A (walk-order, from session-runtime.rkt)
;; and Architecture D (session-derived ordering) based on process characteristics.
;;
;; Architecture D is selected when:
;;   1. Multiple IO channels exist (> 1 proc-open), AND
;;   2. Cross-channel data flow edges exist (recv on one → send on another)
;; Otherwise Architecture A is used (cheaper, same result for single-channel IO).
;;
;; proc          : proc-* (process AST)
;; session-type  : session type for the process
;; fuel          : propagator network fuel limit
;; #:architecture : 'auto | 'a | 'd — override architecture selection
;;
;; Returns: rt-exec-result
(define (rt-execute-process-auto proc session-type [fuel 1000000]
                                 #:architecture [arch 'auto])
  ;; For proc-open processes, 'self gets sess-end because the process
  ;; communicates via IO channels (proc-open creates 'ch), not 'self.
  ;; The session-type parameter describes the IO channel protocol,
  ;; used by Architecture D for effect ordering.
  (define a-session (if (proc-open? proc) (sess-end) session-type))
  (case arch
    [(a) (rt-execute-process proc a-session fuel)]
    [(d) (rt-execute-process-d proc session-type fuel)]
    [(auto)
     (if (architecture-d-required? proc)
         (rt-execute-process-d proc session-type fuel)
         (rt-execute-process proc a-session fuel))]
    [else (error 'rt-execute-process-auto
                 "unknown architecture: ~a (expected 'a, 'd, or 'auto)" arch)]))


;; ========================================
;; AD-F3: Concurrent Execution Hooks
;; ========================================
;;
;; Placeholders for the S8b concurrent runtime. In Phase 0, all execution
;; is sequential (single-network). The concurrent runtime will:
;;   - Execute partner processes on separate networks
;;   - Deliver messages via buffered channels
;;   - Defer ATMS worldview collapse until runtime label delivery
;;   - Execute effects from consistent worldviews only
;;
;; These hooks allow the execution strategy to be swapped without modifying
;; the core pipeline. The default executor runs effects sequentially (Phase 0).
;; The concurrent executor is a stub that raises an error (S8b not yet implemented).

;; Parameter: the current effect execution strategy.
;; Value is a function: (rnet effects channel-eps) → (values rnet* results)
(define current-effect-executor (make-parameter #f))

;; Default (sequential) effect executor — delegates to execute-effects-and-propagate.
;; This is the Phase 0 behavior: effects are linearized and executed in order.
(define (default-effect-executor rnet effects channel-eps)
  (execute-effects-and-propagate rnet effects channel-eps))

;; Concurrent effect executor — placeholder for S8b runtime.
;; Raises an error because the concurrent runtime is not yet implemented.
;; Future: will partition effects by network, execute concurrently, and
;; merge results via cross-network message delivery.
(define (concurrent-effect-executor rnet effects channel-eps)
  (error 'concurrent-effect-executor
         "S8b concurrent runtime not yet implemented"))
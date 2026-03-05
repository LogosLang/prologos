#lang racket/base

;;;
;;; session-runtime.rkt — Runtime infrastructure for session type execution
;;;
;;; Channel cells for message passing between processes via propagator networks.
;;; This is the RUNTIME layer (S7) — distinct from session-propagators.rkt (S4)
;;; which is the COMPILE-TIME type checking layer.
;;;
;;; S4 cells hold session type fragments; S7 cells hold actual runtime values
;;; (messages, labels). Both share the same propagator.rkt persistent network API.
;;;
;;; Design reference: docs/tracking/2026-03-03_SESSION_TYPE_DESIGN.md
;;;   §10 (Execution Model), §10.6 (Choice as Cell-Write)
;;;

(require racket/match
         "propagator.rkt"
         "sessions.rkt"
         "session-lattice.rkt"
         "processes.rkt"
         "pretty-print.rkt")

(provide
 ;; Structs
 (struct-out channel-endpoint)
 (struct-out channel-pair)
 (struct-out runtime-network)
 ;; Message lattice
 msg-bot msg-top msg-bot? msg-top?
 msg-lattice-merge
 msg-lattice-contradicts?
 ;; Choice lattice
 choice-bot choice-top choice-bot? choice-top?
 choice-lattice-merge
 choice-lattice-contradicts?
 ;; Network lifecycle
 make-runtime-network
 ;; Channel operations
 rt-new-channel-pair
 rt-register-channel
 rt-lookup-channel
 ;; Session advancement
 rt-fresh-session-cell
 rt-add-session-advance
 ;; Network operations
 rt-run-to-quiescence
 rt-contradiction?
 rt-cell-read
 rt-cell-write
 ;; S7b: Process compilation
 (struct-out rt-exec-result)
 compile-live-process
 rt-execute-process
 rt-cross-wire-choice
 endpoint-advance-session
 resolve-expr)

;; ========================================
;; Message Lattice (flat: bot → value → top)
;; ========================================
;;
;; Messages are write-once per protocol step (design doc §10.2).
;; A second distinct write to the same message cell is a contradiction.

(define msg-bot 'msg-bot)
(define msg-top 'msg-top)

(define (msg-bot? v) (eq? v 'msg-bot))
(define (msg-top? v) (eq? v 'msg-top))

(define (msg-lattice-merge old new)
  (cond
    [(msg-bot? old) new]
    [(msg-bot? new) old]
    [(msg-top? old) msg-top]
    [(msg-top? new) msg-top]
    [(equal? old new) old]
    [else msg-top]))

(define (msg-lattice-contradicts? v) (msg-top? v))

;; ========================================
;; Choice Lattice (flat keyword: bot → :label → top)
;; ========================================
;;
;; Choice cells resolve internal/external choice (design doc §10.6).
;; select writes :label; offer watches partner's choice cell.
;; A second distinct label write is a contradiction (non-determinism).

(define choice-bot 'choice-bot)
(define choice-top 'choice-top)

(define (choice-bot? v) (eq? v 'choice-bot))
(define (choice-top? v) (eq? v 'choice-top))

(define (choice-lattice-merge old new)
  (cond
    [(choice-bot? old) new]
    [(choice-bot? new) old]
    [(choice-top? old) choice-top]
    [(choice-top? new) choice-top]
    [(equal? old new) old]
    [else choice-top]))

(define (choice-lattice-contradicts? v) (choice-top? v))

;; ========================================
;; Structs
;; ========================================

;; A channel endpoint: one side of a bidirectional communication channel.
;; Each endpoint has 4 cells in the propagator network:
;;   msg-out:  process writes outgoing messages here
;;   msg-in:   process reads incoming messages here
;;   session:  current session state (tracks protocol progress)
;;   choice:   for internal/external choice resolution
;;
;; A channel PAIR consists of two endpoints, cross-wired:
;;   A.msg-out → propagator → B.msg-in
;;   B.msg-out → propagator → A.msg-in
(struct channel-endpoint
  (msg-out-cell    ;; cell-id
   msg-in-cell     ;; cell-id
   session-cell    ;; cell-id
   choice-cell)    ;; cell-id
  #:transparent)

;; A channel pair: two cross-wired endpoints.
;; ep-a: the "positive" / initiator endpoint
;; ep-b: the "negative" / responder endpoint (dual session)
(struct channel-pair (ep-a ep-b) #:transparent)

;; Runtime session network: prop-network + channel metadata.
;; Pure value — all operations return new runtime-network values.
;; Follows the elab-network pattern (elaborator-network.rkt).
(struct runtime-network
  (prop-net        ;; prop-network
   channel-info    ;; hasheq : symbol → channel-endpoint
   next-chan-id)   ;; Nat — deterministic counter
  #:transparent)

;; ========================================
;; Runtime Network Lifecycle
;; ========================================

(define (make-runtime-network [fuel 1000000])
  (runtime-network (make-prop-network fuel) (hasheq) 0))

;; Register a named channel endpoint in the runtime network.
(define (rt-register-channel rnet name endpoint)
  (runtime-network
   (runtime-network-prop-net rnet)
   (hash-set (runtime-network-channel-info rnet) name endpoint)
   (runtime-network-next-chan-id rnet)))

;; Look up a channel endpoint by name.
(define (rt-lookup-channel rnet name)
  (hash-ref (runtime-network-channel-info rnet) name #f))

;; Run the runtime network to quiescence.
(define (rt-run-to-quiescence rnet)
  (runtime-network
   (run-to-quiescence (runtime-network-prop-net rnet))
   (runtime-network-channel-info rnet)
   (runtime-network-next-chan-id rnet)))

;; Check if the runtime network hit a contradiction.
(define (rt-contradiction? rnet)
  (net-contradiction? (runtime-network-prop-net rnet)))

;; Read a cell value in the runtime network.
(define (rt-cell-read rnet cid)
  (net-cell-read (runtime-network-prop-net rnet) cid))

;; Write a cell value in the runtime network (via lattice merge).
(define (rt-cell-write rnet cid val)
  (runtime-network
   (net-cell-write (runtime-network-prop-net rnet) cid val)
   (runtime-network-channel-info rnet)
   (runtime-network-next-chan-id rnet)))

;; ========================================
;; Channel Pair Creation
;; ========================================

;; Create a channel pair with cross-wired endpoints.
;; session-type: the session type for endpoint A (B gets dual).
;;
;; Allocates 8 cells (4 per endpoint) and creates 2 cross-wiring propagators:
;;   A.msg-out → B.msg-in, B.msg-out → A.msg-in
;;
;; Session cells: A initialized with session-type, B with (dual session-type).
;; Choice cells: NOT cross-wired — the offer propagator (S7b) directly
;;   watches the partner's choice cell-id per design doc §10.6.
;;
;; Returns (values runtime-network* channel-pair)
(define (rt-new-channel-pair rnet session-type)
  (define net (runtime-network-prop-net rnet))

  ;; --- Endpoint A cells ---
  (define-values (net1 a-out)
    (net-new-cell net msg-bot msg-lattice-merge msg-lattice-contradicts?))
  (define-values (net2 a-in)
    (net-new-cell net1 msg-bot msg-lattice-merge msg-lattice-contradicts?))
  (define-values (net3 a-sess)
    (net-new-cell net2 session-type session-lattice-merge session-lattice-contradicts?))
  (define-values (net4 a-choice)
    (net-new-cell net3 choice-bot choice-lattice-merge choice-lattice-contradicts?))

  ;; --- Endpoint B cells ---
  (define-values (net5 b-out)
    (net-new-cell net4 msg-bot msg-lattice-merge msg-lattice-contradicts?))
  (define-values (net6 b-in)
    (net-new-cell net5 msg-bot msg-lattice-merge msg-lattice-contradicts?))
  (define dual-session (dual session-type))
  (define-values (net7 b-sess)
    (net-new-cell net6 dual-session session-lattice-merge session-lattice-contradicts?))
  (define-values (net8 b-choice)
    (net-new-cell net7 choice-bot choice-lattice-merge choice-lattice-contradicts?))

  ;; --- Cross-wiring propagators ---
  ;; A.msg-out → B.msg-in: when A writes, B receives
  (define-values (net9 _p1)
    (net-add-propagator net8 (list a-out) (list b-in)
      (lambda (n)
        (define v (net-cell-read n a-out))
        (if (msg-bot? v) n
            (net-cell-write n b-in v)))))

  ;; B.msg-out → A.msg-in: when B writes, A receives
  (define-values (net10 _p2)
    (net-add-propagator net9 (list b-out) (list a-in)
      (lambda (n)
        (define v (net-cell-read n b-out))
        (if (msg-bot? v) n
            (net-cell-write n a-in v)))))

  ;; --- Build structs ---
  (define ep-a (channel-endpoint a-out a-in a-sess a-choice))
  (define ep-b (channel-endpoint b-out b-in b-sess b-choice))
  (define pair (channel-pair ep-a ep-b))

  (values
   (runtime-network net10
                    (runtime-network-channel-info rnet)
                    (runtime-network-next-chan-id rnet))
   pair))

;; ========================================
;; Session Advancement
;; ========================================

;; Create a fresh session state cell (for use in session advancement chains).
;; Returns (values prop-network cell-id).
(define (rt-fresh-session-cell net initial-session)
  (net-new-cell net initial-session session-lattice-merge session-lattice-contradicts?))

;; Create a propagator that advances session state from current to next cell.
;;
;; Watches current-cell. When it has a concrete session type:
;;   - If sess-mu: unfolds first, then re-checks
;;   - If matches expected-shape?: writes (extract-cont value) to next-cell
;;   - If wrong shape: writes sess-top to current-cell (protocol violation)
;;
;; This mirrors session-propagators.rkt's add-send-prop / add-recv-prop pattern
;; but is parameterized for reuse across Send, Recv, etc.
;;
;; Returns (values prop-network prop-id).
(define (rt-add-session-advance net current-cell next-cell expected-shape? extract-cont)
  (net-add-propagator net
    (list current-cell) (list next-cell)
    (lambda (n)
      (define raw-sess (net-cell-read n current-cell))
      ;; Unfold recursive sessions before checking shape
      (define sess (if (sess-mu? raw-sess) (unfold-session raw-sess) raw-sess))
      (cond
        [(sess-bot? sess) n]   ;; No info yet, wait
        [(sess-top? sess) n]   ;; Already contradicted
        [(expected-shape? sess)
         (net-cell-write n next-cell (extract-cont sess))]
        ;; Wrong shape → protocol violation
        [else (net-cell-write n current-cell sess-top)]))))

;; ========================================
;; S7b: Process-to-Propagator Compilation
;; ========================================

;; Result of compiling and running a process.
(struct rt-exec-result
  (status          ;; 'ok | 'contradiction | 'incomplete
   bindings        ;; hasheq : symbol → value (received values)
   runtime-network ;; final runtime-network state
   trace)          ;; hasheq : cell-id → (listof string) — operation trace
  #:transparent)

;; ----------------------------------------
;; Helpers
;; ----------------------------------------

;; Create a new endpoint with a different session cell.
;; Preserves msg-out, msg-in, and choice cells — only session advances.
(define (endpoint-advance-session ep new-session-cell)
  (channel-endpoint
   (channel-endpoint-msg-out-cell ep)
   (channel-endpoint-msg-in-cell ep)
   new-session-cell
   (channel-endpoint-choice-cell ep)))

;; Resolve an expression against current bindings.
;; Phase 0: simple symbol lookup. Future: full reduction.
(define (resolve-expr expr bindings)
  (cond
    [(symbol? expr) (hash-ref bindings expr expr)]
    [else expr]))

;; Add choice cross-wiring propagators between two endpoints.
;; When one endpoint's choice cell is written, the value propagates to the other.
;; Returns updated runtime-network.
(define (rt-cross-wire-choice rnet ep-a ep-b)
  (define net (runtime-network-prop-net rnet))
  (define a-choice (channel-endpoint-choice-cell ep-a))
  (define b-choice (channel-endpoint-choice-cell ep-b))
  ;; A's choice → B's choice
  (define-values (net1 _p1)
    (net-add-propagator net (list a-choice) (list b-choice)
      (lambda (n)
        (define v (net-cell-read n a-choice))
        (if (choice-bot? v) n
            (net-cell-write n b-choice v)))))
  ;; B's choice → A's choice
  (define-values (net2 _p2)
    (net-add-propagator net1 (list b-choice) (list a-choice)
      (lambda (n)
        (define v (net-cell-read n b-choice))
        (if (choice-bot? v) n
            (net-cell-write n a-choice v)))))
  (runtime-network net2
                   (runtime-network-channel-info rnet)
                   (runtime-network-next-chan-id rnet)))

;; Add a trace entry for a cell.
(define (rt-trace-add trace cell-id msg)
  (hash-set trace cell-id
    (cons msg (hash-ref trace cell-id '()))))

;; Create a fresh session cell in the runtime network's prop-net.
;; Returns (values rnet* cell-id).
(define (rt-fresh-session-cell-in-rnet rnet initial-session)
  (define-values (net* cid)
    (rt-fresh-session-cell (runtime-network-prop-net rnet) initial-session))
  (values (runtime-network net*
                           (runtime-network-channel-info rnet)
                           (runtime-network-next-chan-id rnet))
          cid))

;; Add a session advance propagator in the runtime network context.
;; Returns (values rnet* prop-id).
(define (rt-add-session-advance-in-rnet rnet current-cell next-cell expected? extract)
  (define-values (net* pid)
    (rt-add-session-advance (runtime-network-prop-net rnet)
                            current-cell next-cell expected? extract))
  (values (runtime-network net*
                           (runtime-network-channel-info rnet)
                           (runtime-network-next-chan-id rnet))
          pid))

;; Add a propagator in the runtime network context.
;; Returns (values rnet* prop-id).
(define (rt-add-propagator rnet input-ids output-ids fire-fn)
  (define-values (net* pid)
    (net-add-propagator (runtime-network-prop-net rnet) input-ids output-ids fire-fn))
  (values (runtime-network net*
                           (runtime-network-channel-info rnet)
                           (runtime-network-next-chan-id rnet))
          pid))

;; ----------------------------------------
;; Main Compiler: compile-live-process
;; ----------------------------------------

;; Walk a proc-* tree and install propagators in a runtime-network.
;;
;; rnet:         runtime-network
;; proc:         proc-* tree
;; channel-eps:  hasheq : symbol → channel-endpoint
;; bindings:     hasheq : symbol → value (accumulated recv bindings)
;; trace:        hasheq : cell-id → (listof string)
;;
;; Returns: (values rnet* bindings* trace*)
(define (compile-live-process rnet proc channel-eps
                              [bindings (hasheq)] [trace (hasheq)])
  (match proc
    ;; ---- Stop: all channels must be at End ----
    [(proc-stop)
     (define-values (rnet* trace*)
       (for/fold ([r rnet] [t trace])
                 ([(chan ep) (in-hash channel-eps)])
         (define sess-cell (channel-endpoint-session-cell ep))
         ;; Add propagator that asserts End on the session cell
         (define-values (r* _pid)
           (rt-add-propagator r (list sess-cell) (list sess-cell)
             (lambda (n)
               (define sess-val (net-cell-read n sess-cell))
               (define sess (if (sess-mu? sess-val) (unfold-session sess-val) sess-val))
               (cond
                 [(sess-bot? sess)
                  (net-cell-write n sess-cell (sess-end))]
                 [(sess-end? sess) n]
                 [else (net-cell-write n sess-cell sess-top)]))))
         (values r* (rt-trace-add t sess-cell
                      (format "process stops (expects ~a at End)" chan)))))
     (values rnet* bindings trace*)]

    ;; ---- Send: write value to channel-out, advance session ----
    [(proc-send expr chan cont)
     (define ep (hash-ref channel-eps chan #f))
     (cond
       [(not ep) (values rnet bindings trace)]  ;; unknown channel
       [else
        (define val (resolve-expr expr bindings))
        ;; Write value to msg-out cell
        (define rnet1 (rt-cell-write rnet (channel-endpoint-msg-out-cell ep) val))
        ;; Create fresh session cell for continuation
        (define-values (rnet2 next-sess-cell)
          (rt-fresh-session-cell-in-rnet rnet1 sess-bot))
        ;; Add session advance: Send → continuation
        (define-values (rnet3 _pid)
          (rt-add-session-advance-in-rnet rnet2
            (channel-endpoint-session-cell ep) next-sess-cell
            sess-send? sess-send-cont))
        ;; Update endpoint with new session cell
        (define ep* (endpoint-advance-session ep next-sess-cell))
        (define trace*
          (rt-trace-add trace (channel-endpoint-session-cell ep)
            (format "process sends on ~a" chan)))
        ;; Recurse into continuation
        (compile-live-process rnet3 cont
          (hash-set channel-eps chan ep*) bindings trace*)])]

    ;; ---- Recv: read from channel-in, bind value, advance session ----
    [(proc-recv chan _type cont)
     (define ep (hash-ref channel-eps chan #f))
     (cond
       [(not ep) (values rnet bindings trace)]
       [else
        ;; Create fresh session cell for continuation
        (define-values (rnet1 next-sess-cell)
          (rt-fresh-session-cell-in-rnet rnet sess-bot))
        ;; Add session advance: Recv → continuation
        (define-values (rnet2 _pid)
          (rt-add-session-advance-in-rnet rnet1
            (channel-endpoint-session-cell ep) next-sess-cell
            sess-recv? sess-recv-cont))
        ;; Add propagator to capture received value into bindings
        ;; (For Phase 0, we just read the msg-in cell value)
        (define msg-in-cell (channel-endpoint-msg-in-cell ep))
        ;; Update endpoint with new session cell
        (define ep* (endpoint-advance-session ep next-sess-cell))
        (define trace*
          (rt-trace-add trace (channel-endpoint-session-cell ep)
            (format "process receives from ~a" chan)))
        ;; Record binding: use a generated variable name based on channel
        ;; proc-recv stores the channel name and type, not a variable name
        ;; We use the channel name as the binding key for now
        (define bindings* (hash-set bindings chan 'pending-recv))
        ;; Recurse into continuation
        (compile-live-process rnet2 cont
          (hash-set channel-eps chan ep*) bindings* trace*)])]

    ;; ---- Select: write label to choice cell, advance session ----
    [(proc-sel chan label cont)
     (define ep (hash-ref channel-eps chan #f))
     (cond
       [(not ep) (values rnet bindings trace)]
       [else
        ;; Write label to choice cell
        (define rnet1 (rt-cell-write rnet (channel-endpoint-choice-cell ep) label))
        ;; Create fresh session cell for continuation
        (define-values (rnet2 next-sess-cell)
          (rt-fresh-session-cell-in-rnet rnet1 sess-bot))
        ;; Add session advance: Choice → selected branch
        (define-values (rnet3 _pid)
          (rt-add-propagator rnet2
            (list (channel-endpoint-session-cell ep))
            (list next-sess-cell)
            (lambda (n)
              (define raw-sess (net-cell-read n (channel-endpoint-session-cell ep)))
              (define sess (if (sess-mu? raw-sess) (unfold-session raw-sess) raw-sess))
              (cond
                [(sess-bot? sess) n]
                [(sess-top? sess) n]
                [(sess-choice? sess)
                 (define branch (lookup-branch label (sess-choice-branches sess)))
                 (if (sess-branch-error? branch)
                     (net-cell-write n (channel-endpoint-session-cell ep) sess-top)
                     (net-cell-write n next-sess-cell branch))]
                [else (net-cell-write n (channel-endpoint-session-cell ep) sess-top)]))))
        ;; Update endpoint
        (define ep* (endpoint-advance-session ep next-sess-cell))
        (define trace*
          (rt-trace-add trace (channel-endpoint-session-cell ep)
            (format "process selects '~a on ~a" label chan)))
        ;; Recurse
        (compile-live-process rnet3 cont
          (hash-set channel-eps chan ep*) bindings trace*)])]

    ;; ---- Case/Offer: watch choice cell, compile each branch (guarded) ----
    [(proc-case chan proc-branches)
     (define ep (hash-ref channel-eps chan #f))
     (cond
       [(not ep) (values rnet bindings trace)]
       [else
        (define choice-cell (channel-endpoint-choice-cell ep))
        (define sess-cell (channel-endpoint-session-cell ep))
        (define trace*
          (rt-trace-add trace sess-cell
            (format "process offers branches on ~a" chan)))
        ;; Add session advance: Offer → distribute branches
        ;; First create a cont cell per branch label
        (define labels (map car proc-branches))
        (define-values (rnet1 branch-cells)
          (for/fold ([r rnet] [cells '()])
                    ([lbl (in-list labels)])
            (define-values (r* cid) (rt-fresh-session-cell-in-rnet r sess-bot))
            (values r* (cons (cons lbl cid) cells))))
        (define branch-cells-rev (reverse branch-cells))
        ;; Add propagator that distributes offer branches to cont cells
        (define output-ids (map cdr branch-cells-rev))
        (define-values (rnet2 _pid)
          (rt-add-propagator rnet1
            (list sess-cell) output-ids
            (lambda (n)
              (define raw-sess (net-cell-read n sess-cell))
              (define sess (if (sess-mu? raw-sess) (unfold-session raw-sess) raw-sess))
              (cond
                [(sess-bot? sess) n]
                [(sess-top? sess) n]
                [(sess-offer? sess)
                 (for/fold ([net-acc n])
                           ([bc (in-list branch-cells-rev)])
                   (define lbl (car bc))
                   (define cid (cdr bc))
                   (define branch (lookup-branch lbl (sess-offer-branches sess)))
                   (if (sess-branch-error? branch)
                       (net-cell-write net-acc sess-cell sess-top)
                       (net-cell-write net-acc cid branch)))]
                [else (net-cell-write n sess-cell sess-top)]))))
        ;; Compile each branch guarded on the choice cell value
        ;; All branches are compiled, but only the one matching the choice
        ;; will see non-bot values on its message cells.
        (for/fold ([r rnet2] [b bindings] [t trace*])
                  ([pb (in-list proc-branches)])
          (define lbl (car pb))
          (define p (cdr pb))
          (define cont-cid (cdr (assq lbl branch-cells-rev)))
          (define ep* (endpoint-advance-session ep cont-cid))
          (compile-live-process r p
            (hash-set channel-eps chan ep*) b t))])]

    ;; ---- New: create channel pair, compile parallel sub-processes ----
    [(proc-new session-ty (proc-par p1 p2))
     (define-values (rnet1 pair) (rt-new-channel-pair rnet session-ty))
     (define ep-a (channel-pair-ep-a pair))
     (define ep-b (channel-pair-ep-b pair))
     ;; Cross-wire choice cells
     (define rnet2 (rt-cross-wire-choice rnet1 ep-a ep-b))
     (define trace*
       (rt-trace-add
        (rt-trace-add trace
          (channel-endpoint-session-cell ep-a) "channel endpoint A (proc-new)")
        (channel-endpoint-session-cell ep-b) "channel endpoint B (dual, proc-new)"))
     ;; Compile p1 with ch → ep-a
     (define-values (rnet3 bindings1 trace1)
       (compile-live-process rnet2 p1
         (hash-set channel-eps 'ch ep-a) bindings trace*))
     ;; Compile p2 with ch → ep-b
     (compile-live-process rnet3 p2
       (hash-set channel-eps 'ch ep-b) bindings1 trace1)]

    ;; ---- Par: compile both sides with shared channels ----
    [(proc-par p1 p2)
     (define-values (rnet1 bindings1 trace1)
       (compile-live-process rnet p1 channel-eps bindings trace))
     (compile-live-process rnet1 p2 channel-eps bindings1 trace1)]

    ;; ---- Link: forward between two channels ----
    [(proc-link c1 c2)
     (define ep1 (hash-ref channel-eps c1 #f))
     (define ep2 (hash-ref channel-eps c2 #f))
     (cond
       [(not (and ep1 ep2)) (values rnet bindings trace)]
       [else
        ;; Forward msg: c1.out → c2.in, c2.out → c1.in
        (define-values (rnet1 _p1)
          (rt-add-propagator rnet
            (list (channel-endpoint-msg-out-cell ep1))
            (list (channel-endpoint-msg-in-cell ep2))
            (lambda (n)
              (define v (net-cell-read n (channel-endpoint-msg-out-cell ep1)))
              (if (msg-bot? v) n
                  (net-cell-write n (channel-endpoint-msg-in-cell ep2) v)))))
        (define-values (rnet2 _p2)
          (rt-add-propagator rnet1
            (list (channel-endpoint-msg-out-cell ep2))
            (list (channel-endpoint-msg-in-cell ep1))
            (lambda (n)
              (define v (net-cell-read n (channel-endpoint-msg-out-cell ep2)))
              (if (msg-bot? v) n
                  (net-cell-write n (channel-endpoint-msg-in-cell ep1) v)))))
        ;; Forward choice cells
        (define rnet3 (rt-cross-wire-choice rnet2 ep1 ep2))
        (define trace*
          (rt-trace-add
           (rt-trace-add trace
             (channel-endpoint-session-cell ep1)
             (format "linked ~a ↔ ~a (forwarding)" c1 c2))
           (channel-endpoint-session-cell ep2)
           (format "linked ~a ↔ ~a (forwarding)" c2 c1)))
        (values rnet3 bindings trace*)])]

    ;; ---- Fallback ----
    [_ (values rnet bindings trace)]))

;; ----------------------------------------
;; Entry Point: compile and execute a process
;; ----------------------------------------

;; Compile and run a process against a session type.
;; Creates a fresh runtime network, sets up a channel pair for 'self,
;; compiles the process, and runs to quiescence.
;;
;; Returns: rt-exec-result
(define (rt-execute-process proc session-type [fuel 1000000])
  ;; 1. Create runtime network
  (define rnet0 (make-runtime-network fuel))
  ;; 2. Create channel pair for self
  (define-values (rnet1 pair) (rt-new-channel-pair rnet0 session-type))
  (define ep-a (channel-pair-ep-a pair))
  (define ep-b (channel-pair-ep-b pair))
  ;; Cross-wire choice for the self channel
  (define rnet2 (rt-cross-wire-choice rnet1 ep-a ep-b))
  ;; Register ep-a as 'self
  (define rnet3 (rt-register-channel rnet2 'self ep-a))
  ;; 3. Compile process
  (define channel-eps (hasheq 'self ep-a))
  (define init-trace
    (hasheq (channel-endpoint-session-cell ep-a)
      (list (format "session type declared as ~a" (pp-session session-type)))))
  (define-values (rnet4 bindings trace)
    (compile-live-process rnet3 proc channel-eps (hasheq) init-trace))
  ;; 4. Run to quiescence
  (define rnet5 (rt-run-to-quiescence rnet4))
  ;; 5. Check for contradictions
  (cond
    [(rt-contradiction? rnet5)
     (rt-exec-result 'contradiction bindings rnet5 trace)]
    [else
     (rt-exec-result 'ok bindings rnet5 trace)]))

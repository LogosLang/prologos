#lang racket/base

;;;
;;; session-propagators.rkt — Propagator-based session type checking
;;;
;;; Compiles process trees (proc-*) to propagator networks.
;;; Each process operation creates propagators that constrain session cells
;;; using session-lattice-merge. After quiescence, contradictions indicate
;;; protocol violations.
;;;
;;; Design:
;;; - Each channel has a session cell (holds the "remaining protocol")
;;; - Each process operation decomposes one step of the protocol
;;; - The cell's value refines monotonically: sess-bot → concrete → sess-top
;;; - Contradictions arise from polarity mismatches or type incompatibilities
;;;
;;; S4d: Operation tracing (ATMS-style derivation chains)
;;; - Each process operation records a session-op in a trace map
;;; - On contradiction: the trace explains which operations conflicted
;;; - Errors are structured session-protocol-error values with derivation chains
;;;
;;; Integration:
;;; - Uses propagator.rkt's persistent network (cells, propagators, scheduling)
;;; - Uses session-lattice.rkt for merge and contradiction detection
;;; - Cross-domain bridges (S4e) will connect message types to type-lattice cells
;;;

(require racket/match
         racket/list
         racket/string
         "propagator.rkt"
         "sessions.rkt"
         "processes.rkt"
         "session-lattice.rkt"
         "errors.rkt"
         "source-location.rkt"
         "pretty-print.rkt"
         "prop-observatory.rkt"
         "champ.rkt")

(provide
 ;; Core operations
 make-session-cell
 add-send-prop
 add-recv-prop
 add-async-send-prop
 add-async-recv-prop
 add-select-prop
 add-offer-prop
 add-stop-prop
 ;; Duality (S4c)
 add-duality-prop
 ;; S4d: Operation tracing
 (struct-out session-op)
 trace-add
 ;; Compilation
 compile-proc-to-network
 ;; S4d: Error construction
 build-session-error
 ;; S4f: Deadlock/completeness detection
 check-session-completeness
 ;; Top-level checker
 check-session-via-propagators)

;; ========================================
;; Session cell creation
;; ========================================

;; Create a fresh session cell in the network.
;; Returns (values net cell-id).
(define (make-session-cell net [initial-value sess-bot])
  (net-new-cell net initial-value session-lattice-merge session-lattice-contradicts?))

;; ========================================
;; S4d: Operation tracing
;; ========================================

;; A session-op records what process operation constrains a cell.
;; kind: symbol — 'init, 'send, 'recv, 'stop, 'select, 'offer, 'dual, 'new
;; channel: symbol — the channel name this operation acts on
;; description: string — human-readable explanation
(struct session-op (kind channel description) #:transparent)

;; A session trace is a hasheq from cell-id → (listof session-op).
;; Records all operations that constrained each cell.

;; Add an operation record for a cell in the trace.
(define (trace-add trace cell-id op)
  (hash-set trace cell-id
    (cons op (hash-ref trace cell-id '()))))

;; ========================================
;; Process operation propagators
;; ========================================

;; Each add-*-prop function:
;;   1. Creates a continuation cell (successor session state)
;;   2. Adds a decomposition propagator to the network
;;   3. Returns (values net cont-cell-id)
;;
;; The propagator watches the channel's session cell and decomposes
;; the session into the current operation + continuation.

;; add-send-prop: constrains sess-cell to be sess-send(A, S') or sess-async-send(A, S')
;; Returns (values net cont-cell-id) where cont-cell holds S'.
;; In Phase 0, proc-send matches both sync and async send in the session type.
(define (add-send-prop net sess-cell)
  ;; Create continuation cell
  (define-values (net1 cont-cell) (make-session-cell net))
  ;; Add decomposition propagator
  (define fire-fn
    (lambda (n)
      (define sess-val (net-cell-read n sess-cell))
      (define cont-val (net-cell-read n cont-cell))
      (cond
        [(sess-bot? sess-val) n]  ;; No info yet, wait
        [(sess-send? sess-val)
         (net-cell-write n cont-cell (sess-send-cont sess-val))]
        [(sess-async-send? sess-val)
         (net-cell-write n cont-cell (sess-async-send-cont sess-val))]
        [(sess-meta? sess-val) n]  ;; Unknown, defer
        ;; Incompatible shape → write contradiction
        [else (net-cell-write n sess-cell sess-top)])))
  (define-values (net2 _pid)
    (net-add-propagator net1 (list sess-cell) (list cont-cell) fire-fn))
  (values net2 cont-cell))

;; add-recv-prop: constrains sess-cell to be sess-recv(A, S') or sess-async-recv(A, S')
(define (add-recv-prop net sess-cell)
  (define-values (net1 cont-cell) (make-session-cell net))
  (define fire-fn
    (lambda (n)
      (define sess-val (net-cell-read n sess-cell))
      (cond
        [(sess-bot? sess-val) n]
        [(sess-recv? sess-val)
         (net-cell-write n cont-cell (sess-recv-cont sess-val))]
        [(sess-async-recv? sess-val)
         (net-cell-write n cont-cell (sess-async-recv-cont sess-val))]
        [(sess-meta? sess-val) n]
        [else (net-cell-write n sess-cell sess-top)])))
  (define-values (net2 _pid)
    (net-add-propagator net1 (list sess-cell) (list cont-cell) fire-fn))
  (values net2 cont-cell))

;; add-async-send-prop: constrains sess-cell to be sess-async-send(A, S')
;; Identical to add-send-prop but matches sess-async-send.
(define (add-async-send-prop net sess-cell)
  (define-values (net1 cont-cell) (make-session-cell net))
  (define fire-fn
    (lambda (n)
      (define sess-val (net-cell-read n sess-cell))
      (cond
        [(sess-bot? sess-val) n]
        [(sess-async-send? sess-val)
         (net-cell-write n cont-cell (sess-async-send-cont sess-val))]
        [(sess-meta? sess-val) n]
        [else (net-cell-write n sess-cell sess-top)])))
  (define-values (net2 _pid)
    (net-add-propagator net1 (list sess-cell) (list cont-cell) fire-fn))
  (values net2 cont-cell))

;; add-async-recv-prop: constrains sess-cell to be sess-async-recv(A, S')
(define (add-async-recv-prop net sess-cell)
  (define-values (net1 cont-cell) (make-session-cell net))
  (define fire-fn
    (lambda (n)
      (define sess-val (net-cell-read n sess-cell))
      (cond
        [(sess-bot? sess-val) n]
        [(sess-async-recv? sess-val)
         (net-cell-write n cont-cell (sess-async-recv-cont sess-val))]
        [(sess-meta? sess-val) n]
        [else (net-cell-write n sess-cell sess-top)])))
  (define-values (net2 _pid)
    (net-add-propagator net1 (list sess-cell) (list cont-cell) fire-fn))
  (values net2 cont-cell))

;; add-select-prop: constrains sess-cell to be sess-choice with label present
(define (add-select-prop net sess-cell label)
  (define-values (net1 cont-cell) (make-session-cell net))
  (define fire-fn
    (lambda (n)
      (define sess-val (net-cell-read n sess-cell))
      (cond
        [(sess-bot? sess-val) n]
        [(sess-choice? sess-val)
         (define branch (lookup-branch label (sess-choice-branches sess-val)))
         (if (sess-branch-error? branch)
             (net-cell-write n sess-cell sess-top)  ;; label not found → contradiction
             (net-cell-write n cont-cell branch))]
        [(sess-meta? sess-val) n]
        [else (net-cell-write n sess-cell sess-top)])))
  (define-values (net2 _pid)
    (net-add-propagator net1 (list sess-cell) (list cont-cell) fire-fn))
  (values net2 cont-cell))

;; add-offer-prop: constrains sess-cell to be sess-offer, creates cont cells per branch
;; Returns (values net (list (cons label cont-cell-id) ...))
(define (add-offer-prop net sess-cell labels)
  ;; Create a continuation cell for each expected branch
  (define-values (net1 branch-cells)
    (for/fold ([n net] [cells '()])
              ([lbl (in-list labels)])
      (define-values (n* cid) (make-session-cell n))
      (values n* (cons (cons lbl cid) cells))))
  (define branch-cells-rev (reverse branch-cells))
  ;; Add propagator that distributes offer branches to their cells
  (define fire-fn
    (lambda (n)
      (define sess-val (net-cell-read n sess-cell))
      (cond
        [(sess-bot? sess-val) n]
        [(sess-offer? sess-val)
         ;; Write each branch's continuation to its cell
         (for/fold ([net-acc n])
                   ([bc (in-list branch-cells-rev)])
           (define lbl (car bc))
           (define cid (cdr bc))
           (define branch (lookup-branch lbl (sess-offer-branches sess-val)))
           (if (sess-branch-error? branch)
               (net-cell-write net-acc sess-cell sess-top)
               (net-cell-write net-acc cid branch)))]
        [(sess-meta? sess-val) n]
        [else (net-cell-write n sess-cell sess-top)])))
  (define output-ids (map cdr branch-cells-rev))
  (define-values (net2 _pid)
    (net-add-propagator net1 (list sess-cell) output-ids fire-fn))
  (values net2 branch-cells-rev))

;; add-stop-prop: constrains sess-cell to be sess-end
(define (add-stop-prop net sess-cell)
  (define fire-fn
    (lambda (n)
      (define sess-val (net-cell-read n sess-cell))
      (cond
        [(sess-bot? sess-val)
         ;; Write end as expected value
         (net-cell-write n sess-cell (sess-end))]
        [(sess-end? sess-val) n]  ;; Already end, good
        [(sess-meta? sess-val)
         ;; Solve meta to end
         (net-cell-write n sess-cell (sess-end))]
        ;; Not end → contradiction
        [else (net-cell-write n sess-cell sess-top)])))
  (define-values (net* _pid)
    (net-add-propagator net (list sess-cell) (list sess-cell) fire-fn))
  net*)

;; ========================================
;; Duality propagator (S4c)
;; ========================================

;; add-duality-prop: cell1 and cell2 must be dual sessions.
;; Bidirectional: cell1 refines → dual written to cell2, and vice versa.
(define (add-duality-prop net cell1 cell2)
  ;; Forward: cell1 → dual → cell2
  (define fwd-fire
    (lambda (n)
      (define v1 (net-cell-read n cell1))
      (cond
        [(sess-bot? v1) n]
        [(sess-top? v1) (net-cell-write n cell2 sess-top)]
        [else (net-cell-write n cell2 (dual v1))])))
  ;; Backward: cell2 → dual → cell1
  (define bwd-fire
    (lambda (n)
      (define v2 (net-cell-read n cell2))
      (cond
        [(sess-bot? v2) n]
        [(sess-top? v2) (net-cell-write n cell1 sess-top)]
        [else (net-cell-write n cell1 (dual v2))])))
  (define-values (net1 _p1)
    (net-add-propagator net (list cell1) (list cell2) fwd-fire))
  (define-values (net2 _p2)
    (net-add-propagator net1 (list cell2) (list cell1) bwd-fire))
  net2)

;; ========================================
;; Process tree compilation (with trace)
;; ========================================

;; compile-proc-to-network: walk a proc-* tree and add propagators.
;; channel-cells: hash of (channel-name → cell-id)
;; trace: hasheq cell-id → (listof session-op) — accumulated operation trace
;; Returns (values augmented-network augmented-trace).
(define (compile-proc-to-network net proc channel-cells [trace (hasheq)])
  (match proc
    ;; ---- Stop: all channels must be at End ----
    [(proc-stop)
     (define net*
       (for/fold ([n net]) ([(_chan cid) (in-hash channel-cells)])
         (add-stop-prop n cid)))
     (define trace*
       (for/fold ([t trace]) ([(chan cid) (in-hash channel-cells)])
         (trace-add t cid (session-op 'stop chan
                            (format "process stops (expects ~a at end)" chan)))))
     (values net* trace*)]

    ;; ---- Send: constrain channel to Send, continue ----
    [(proc-send _expr chan cont)
     (define chan-cid (hash-ref channel-cells chan #f))
     (if (not chan-cid)
         (values net trace)  ;; unknown channel, skip
         (let-values ([(net* cont-cid) (add-send-prop net chan-cid)])
           (define trace*
             (trace-add
              (trace-add trace chan-cid
                (session-op 'send chan (format "process sends on ~a" chan)))
              cont-cid
              (session-op 'send chan (format "continuation after send on ~a" chan))))
           (compile-proc-to-network net* cont
             (hash-set channel-cells chan cont-cid) trace*)))]

    ;; ---- Recv: constrain channel to Recv, continue ----
    [(proc-recv chan _binding _type cont)
     (define chan-cid (hash-ref channel-cells chan #f))
     (if (not chan-cid)
         (values net trace)
         (let-values ([(net* cont-cid) (add-recv-prop net chan-cid)])
           (define trace*
             (trace-add
              (trace-add trace chan-cid
                (session-op 'recv chan (format "process receives from ~a" chan)))
              cont-cid
              (session-op 'recv chan (format "continuation after recv on ~a" chan))))
           (compile-proc-to-network net* cont
             (hash-set channel-cells chan cont-cid) trace*)))]

    ;; ---- Select: constrain to Choice, select label, continue ----
    [(proc-sel chan label cont)
     (define chan-cid (hash-ref channel-cells chan #f))
     (if (not chan-cid)
         (values net trace)
         (let-values ([(net* cont-cid) (add-select-prop net chan-cid label)])
           (define trace*
             (trace-add
              (trace-add trace chan-cid
                (session-op 'select chan
                  (format "process selects label '~a on ~a" label chan)))
              cont-cid
              (session-op 'select chan
                (format "continuation after select '~a on ~a" label chan))))
           (compile-proc-to-network net* cont
             (hash-set channel-cells chan cont-cid) trace*)))]

    ;; ---- Case/Offer: constrain to Offer, compile each branch ----
    [(proc-case chan proc-branches)
     (define chan-cid (hash-ref channel-cells chan #f))
     (if (not chan-cid)
         (values net trace)
         (let* ([labels (map car proc-branches)]
                [net* (void)] [branch-cells (void)])
           (define-values (n bc) (add-offer-prop net chan-cid labels))
           (define trace*
             (trace-add trace chan-cid
               (session-op 'offer chan
                 (format "process offers branches ~a on ~a"
                   (string-join (map (lambda (l) (format "'~a" l)) labels) ", ")
                   chan))))
           ;; Record branch context on each continuation cell
           (define trace-with-branches
             (for/fold ([t trace*]) ([b (in-list bc)])
               (trace-add t (cdr b)
                 (session-op 'offer chan
                   (format "branch '~a of offer on ~a" (car b) chan)))))
           ;; Compile each process branch against its continuation cell
           (for/fold ([net-acc n] [trace-acc trace-with-branches])
                     ([pb (in-list proc-branches)])
             (define lbl (car pb))
             (define p (cdr pb))
             (define cont-cid (cdr (assq lbl bc)))
             ;; Each branch sees the same channel set except chan is now the branch cont
             (compile-proc-to-network net-acc p
               (hash-set channel-cells chan cont-cid) trace-acc))))]

    ;; ---- New: create paired channel cells with duality ----
    [(proc-new session-ty (proc-par p1 p2))
     ;; Create two session cells for the two endpoints
     (define-values (net1 cell-a) (make-session-cell net))
     (define-values (net2 cell-b) (make-session-cell net1))
     ;; Add duality constraint: a and b are dual sessions
     (define net3 (add-duality-prop net2 cell-a cell-b))
     ;; Record duality in trace
     (define trace*
       (trace-add
        (trace-add trace cell-a
          (session-op 'new 'ch "channel endpoint A (proc-new)"))
        cell-b
        (session-op 'dual 'ch "channel endpoint B (dual of A)")))
     ;; Compile both sides of the parallel composition
     ;; p1 gets 'ch → cell-a, p2 gets 'ch → cell-b
     (define-values (net4 trace**)
       (compile-proc-to-network net3 p1
         (hash-set channel-cells 'ch cell-a) trace*))
     (compile-proc-to-network net4 p2
       (hash-set channel-cells 'ch cell-b) trace**)]

    ;; ---- Par: split channels (both sides share channel cells) ----
    [(proc-par p1 p2)
     (define-values (net* trace*)
       (compile-proc-to-network net p1 channel-cells trace))
     (compile-proc-to-network net* p2 channel-cells trace*)]

    ;; ---- Link: add duality constraint between two channels ----
    [(proc-link c1 c2)
     (define c1-cid (hash-ref channel-cells c1 #f))
     (define c2-cid (hash-ref channel-cells c2 #f))
     (if (and c1-cid c2-cid)
         (let ([net* (add-duality-prop net c1-cid c2-cid)])
           (define trace*
             (trace-add
              (trace-add trace c1-cid
                (session-op 'dual c1 (format "linked ~a ↔ ~a (duality)" c1 c2)))
              c2-cid
              (session-op 'dual c2 (format "linked ~a ↔ ~a (duality)" c2 c1))))
           (values net* trace*))
         (values net trace))]

    ;; ---- S5b: Boundary operations: create single-endpoint channel ----
    ;; open/connect/listen create a new channel cell with the declared session type
    ;; and add it to channel-cells under a generated name. The continuation runs
    ;; with the new channel available.
    [(proc-open path session-type _cap-type cont)
     (define-values (net1 cell) (make-session-cell net))
     (define trace*
       (trace-add trace cell
         (session-op 'open 'ch (format "opened channel with session type (open)"))))
     (compile-proc-to-network net1 cont
       (hash-set channel-cells 'ch cell) trace*)]

    [(proc-connect addr session-type _cap-type cont)
     (define-values (net1 cell) (make-session-cell net))
     (define trace*
       (trace-add trace cell
         (session-op 'connect 'ch (format "connected channel with session type (connect)"))))
     (compile-proc-to-network net1 cont
       (hash-set channel-cells 'ch cell) trace*)]

    [(proc-listen port session-type _cap-type cont)
     (define-values (net1 cell) (make-session-cell net))
     (define trace*
       (trace-add trace cell
         (session-op 'listen 'ch (format "listening channel with session type (listen)"))))
     (compile-proc-to-network net1 cont
       (hash-set channel-cells 'ch cell) trace*)]

    ;; ---- Fallback ----
    [_ (values net trace)]))

;; ========================================
;; Error construction (S4d)
;; ========================================

;; Build a session-protocol-error from contradiction info and trace.
;; Finds the channel associated with the contradicting cell and builds
;; a derivation chain from all operations that constrained that cell.
(define (build-session-error net trace contradiction-cell session-type)
  ;; Look up all operations on the contradicting cell
  (define ops (hash-ref trace contradiction-cell '()))
  ;; The cell's current value (should be sess-top = contradiction)
  (define cell-val
    (with-handlers ([exn:fail? (lambda (e) 'unknown)])
      (net-cell-read net contradiction-cell)))
  ;; Determine the primary channel from ops
  (define channel
    (if (null? ops) '?
        (session-op-channel (last ops))))
  ;; Build derivation chain (oldest → newest)
  (define derivation
    (for/list ([op (in-list (reverse ops))])
      (session-op-description op)))
  ;; Construct the error
  (session-protocol-error
   srcloc-unknown  ;; srcloc (core proc-* AST lacks locations; surface forms carry them)
   "Protocol violation: process does not match declared session type"
   channel
   (format "Declared session type: ~a" (pp-session session-type))
   derivation))

;; ========================================
;; S4f: Deadlock / completeness detection
;; ========================================

;; After quiescence with no contradiction, check for incomplete protocol.
;;
;; The check looks for cells with 'stop operations that did NOT reach sess-end.
;; In the propagator model:
;;   - Root/intermediate cells retain their full session value (monotonic lattice)
;;   - Only "terminal" cells (constrained by proc-stop) must be at sess-end
;;   - A terminal cell NOT at sess-end with no contradiction means the stop
;;     propagator couldn't resolve — potential deadlock or unused channel
;;
;; Additionally checks for sess-bot cells with 'init or 'new operations,
;; meaning a channel was allocated but never constrained by any process operation.
;;
;; Returns:
;;   'ok — all terminal cells at end, no unused channels
;;   session-protocol-error — incomplete protocol or unused channel
(define (check-session-completeness net trace)
  ;; 1. Find cells with 'stop ops that aren't at sess-end
  ;; 2. Find cells with only 'init/'new ops (never used by process)
  (define problems
    (for/fold ([acc '()])
              ([(cid ops) (in-hash trace)])
      (define val
        (with-handlers ([exn:fail? (lambda (e) sess-bot)])
          (net-cell-read net cid)))
      (define has-stop? (for/or ([op (in-list ops)]) (eq? 'stop (session-op-kind op))))
      (define has-init-only?
        (and (for/and ([op (in-list ops)])
               (memq (session-op-kind op) '(init new dual)))
             (not (null? ops))))
      (cond
        ;; Terminal cell not at end = process stopped but protocol remains
        [(and has-stop?
              (not (sess-end? val))
              (not (sess-bot? val))
              (not (sess-top? val)))
         (cons (list cid val ops 'incomplete) acc)]
        ;; Allocated channel never used by any process operation
        [(and has-init-only? (sess-bot? val))
         (cons (list cid val ops 'unused) acc)]
        [else acc])))
  (cond
    [(null? problems) 'ok]
    [else
     ;; Report the first problem
     (define entry (car problems))
     (define cid (first entry))
     (define val (second entry))
     (define ops (third entry))
     (define kind (fourth entry))
     (define channel
       (if (null? ops) '?
           (session-op-channel (last ops))))
     (define derivation
       (for/list ([op (in-list (reverse ops))])
         (session-op-description op)))
     (define msg
       (case kind
         [(incomplete) "Incomplete protocol: session not fully consumed (potential deadlock)"]
         [(unused) "Unused channel: allocated but never used by any process operation"]
         [else "Session completeness check failed"]))
     (define detail
       (case kind
         [(incomplete) (format "Remaining session: ~a" (pp-session val))]
         [(unused) "Channel cell is at bottom (no information)"]
         [else ""]))
     (session-protocol-error srcloc-unknown msg channel detail derivation)]))

;; ========================================
;; Top-level session checker
;; ========================================

;; Check a process against a session type using propagator inference.
;; Returns:
;;   'ok — process correctly implements the protocol
;;   session-protocol-error — protocol violation or incomplete protocol
(define (check-session-via-propagators proc session-type)
  ;; 1. Create empty network
  (define net0 (make-prop-network))
  ;; 2. Create root session cell for 'self, initialized with declared type
  (define-values (net1 self-cell) (make-session-cell net0 session-type))
  ;; 3. Initialize trace with session declaration
  (define init-trace
    (hasheq self-cell
      (list (session-op 'init 'self
              (format "session type declared as ~a" (pp-session session-type))))))
  ;; 4. Compile process tree against channel cells
  (define channel-cells (hasheq 'self self-cell))
  (define-values (net2 trace) (compile-proc-to-network net1 proc channel-cells init-trace))
  ;; 5. Run to quiescence (with observatory capture if active)
  (define cell-metas
    (build-session-cell-metas net2 channel-cells))
  (define net3
    (capture-network net2 'session
                     (format "session:~a" (pp-session session-type))
                     cell-metas))
  ;; 6. Check for contradictions
  (define contradiction-cell (prop-network-contradiction net3))
  (cond
    [contradiction-cell
     (build-session-error net3 trace contradiction-cell session-type)]
    ;; 7. S4f: Check for incomplete protocol (deadlock detection)
    [else
     (check-session-completeness net3 trace)]))

;; ========================================
;; Observatory: Cell-Meta Builder
;; ========================================

;; Build cell-metas for session networks.
;; channel-cells is a hasheq of symbol → cell-id (e.g., 'self → cell-id(0)).
;; Named channels get their symbol as label; other cells get generic labels.
(define (build-session-cell-metas net channel-cells)
  ;; Build reverse map: cell-id → channel name
  (define named-cells
    (for/hasheq ([(name cid) (in-hash channel-cells)])
      (values cid (symbol->string name))))
  ;; Walk all cells in the network
  (define all-cell-ids (champ-keys (prop-network-cells net)))
  (for/fold ([cm champ-empty])
            ([cid (in-list all-cell-ids)])
    (define label
      (hash-ref named-cells cid
                (lambda () (format "session-cell-~a" (cell-id-n cid)))))
    (champ-insert cm (cell-id-hash cid) cid
                  (cell-meta 'session label #f 'session-protocol (hasheq)))))

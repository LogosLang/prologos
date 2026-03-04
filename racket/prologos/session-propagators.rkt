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
;;; Integration:
;;; - Uses propagator.rkt's persistent network (cells, propagators, scheduling)
;;; - Uses session-lattice.rkt for merge and contradiction detection
;;; - Cross-domain bridges (S4e) will connect message types to type-lattice cells
;;;

(require racket/match
         racket/list
         "propagator.rkt"
         "sessions.rkt"
         "processes.rkt"
         "session-lattice.rkt"
         "pretty-print.rkt")

(provide
 ;; Core operations
 make-session-cell
 add-send-prop
 add-recv-prop
 add-select-prop
 add-offer-prop
 add-stop-prop
 ;; Duality (S4c)
 add-duality-prop
 ;; Compilation
 compile-proc-to-network
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
;; Process operation propagators
;; ========================================

;; Each add-*-prop function:
;;   1. Creates a continuation cell (successor session state)
;;   2. Adds a decomposition propagator to the network
;;   3. Returns (values net cont-cell-id)
;;
;; The propagator watches the channel's session cell and decomposes
;; the session into the current operation + continuation.

;; add-send-prop: constrains sess-cell to be sess-send(A, S')
;; Returns (values net cont-cell-id) where cont-cell holds S'.
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
         ;; Forward: extract continuation → write to cont-cell
         (net-cell-write n cont-cell (sess-send-cont sess-val))]
        [(sess-meta? sess-val) n]  ;; Unknown, defer
        ;; Incompatible shape → write contradiction
        [else (net-cell-write n sess-cell sess-top)])))
  (define-values (net2 _pid)
    (net-add-propagator net1 (list sess-cell) (list cont-cell) fire-fn))
  (values net2 cont-cell))

;; add-recv-prop: constrains sess-cell to be sess-recv(A, S')
(define (add-recv-prop net sess-cell)
  (define-values (net1 cont-cell) (make-session-cell net))
  (define fire-fn
    (lambda (n)
      (define sess-val (net-cell-read n sess-cell))
      (cond
        [(sess-bot? sess-val) n]
        [(sess-recv? sess-val)
         (net-cell-write n cont-cell (sess-recv-cont sess-val))]
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
;; Process tree compilation
;; ========================================

;; compile-proc-to-network: walk a proc-* tree and add propagators.
;; channel-cells: hash of (channel-name → cell-id)
;; Returns the augmented network.
(define (compile-proc-to-network net proc channel-cells)
  (match proc
    ;; ---- Stop: all channels must be at End ----
    [(proc-stop)
     (for/fold ([n net]) ([(_chan cid) (in-hash channel-cells)])
       (add-stop-prop n cid))]

    ;; ---- Send: constrain channel to Send, continue ----
    [(proc-send _expr chan cont)
     (define chan-cid (hash-ref channel-cells chan #f))
     (if (not chan-cid)
         net  ;; unknown channel, skip
         (let-values ([(net* cont-cid) (add-send-prop net chan-cid)])
           (compile-proc-to-network net* cont
             (hash-set channel-cells chan cont-cid))))]

    ;; ---- Recv: constrain channel to Recv, continue ----
    [(proc-recv chan _type cont)
     (define chan-cid (hash-ref channel-cells chan #f))
     (if (not chan-cid)
         net
         (let-values ([(net* cont-cid) (add-recv-prop net chan-cid)])
           (compile-proc-to-network net* cont
             (hash-set channel-cells chan cont-cid))))]

    ;; ---- Select: constrain to Choice, select label, continue ----
    [(proc-sel chan label cont)
     (define chan-cid (hash-ref channel-cells chan #f))
     (if (not chan-cid)
         net
         (let-values ([(net* cont-cid) (add-select-prop net chan-cid label)])
           (compile-proc-to-network net* cont
             (hash-set channel-cells chan cont-cid))))]

    ;; ---- Case/Offer: constrain to Offer, compile each branch ----
    [(proc-case chan proc-branches)
     (define chan-cid (hash-ref channel-cells chan #f))
     (if (not chan-cid)
         net
         (let* ([labels (map car proc-branches)]
                [net* (void)] [branch-cells (void)])
           (define-values (n bc) (add-offer-prop net chan-cid labels))
           ;; Compile each process branch against its continuation cell
           (for/fold ([net-acc n])
                     ([pb (in-list proc-branches)])
             (define lbl (car pb))
             (define p (cdr pb))
             (define cont-cid (cdr (assq lbl bc)))
             ;; Each branch sees the same channel set except chan is now the branch cont
             (compile-proc-to-network net-acc p
               (hash-set channel-cells chan cont-cid)))))]

    ;; ---- New: create paired channel cells with duality ----
    [(proc-new session-ty (proc-par p1 p2))
     ;; Create two session cells for the two endpoints
     (define-values (net1 cell-a) (make-session-cell net))
     (define-values (net2 cell-b) (make-session-cell net1))
     ;; Add duality constraint: a and b are dual sessions
     (define net3 (add-duality-prop net2 cell-a cell-b))
     ;; Compile both sides of the parallel composition
     ;; p1 gets 'ch → cell-a, p2 gets 'ch → cell-b
     (define net4 (compile-proc-to-network net3 p1
                    (hash-set channel-cells 'ch cell-a)))
     (compile-proc-to-network net4 p2
       (hash-set channel-cells 'ch cell-b))]

    ;; ---- Par: split channels (both sides share channel cells) ----
    [(proc-par p1 p2)
     (define net* (compile-proc-to-network net p1 channel-cells))
     (compile-proc-to-network net* p2 channel-cells)]

    ;; ---- Link: add duality constraint between two channels ----
    [(proc-link c1 c2)
     (define c1-cid (hash-ref channel-cells c1 #f))
     (define c2-cid (hash-ref channel-cells c2 #f))
     (if (and c1-cid c2-cid)
         (add-duality-prop net c1-cid c2-cid)
         net)]

    ;; ---- Fallback ----
    [_ net]))

;; ========================================
;; Top-level session checker
;; ========================================

;; Check a process against a session type using propagator inference.
;; Returns:
;;   'ok - process correctly implements the protocol
;;   (list 'contradiction cell-id) - protocol violation detected
;;   (list 'error msg) - compilation error
(define (check-session-via-propagators proc session-type)
  ;; 1. Create empty network
  (define net0 (make-prop-network))
  ;; 2. Create root session cell for 'self, initialized with declared type
  (define-values (net1 self-cell) (make-session-cell net0 session-type))
  ;; 3. Compile process tree against channel cells
  (define channel-cells (hasheq 'self self-cell))
  (define net2 (compile-proc-to-network net1 proc channel-cells))
  ;; 4. Run to quiescence
  (define net3 (run-to-quiescence net2))
  ;; 5. Check for contradictions
  (define contradiction-cell (prop-network-contradiction net3))
  (cond
    [contradiction-cell
     (list 'contradiction contradiction-cell)]
    [else 'ok]))

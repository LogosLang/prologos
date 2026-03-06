#lang racket/base

;;;
;;; test-effect-collection-01.rkt — AD-C: Effect Collection Mode tests
;;;
;;; Tests for compile-live-process with #:collect-effects? #t.
;;; Verifies that effect descriptors are accumulated correctly,
;;; positions have correct depths, and Architecture A behavior
;;; is unchanged when collect-effects? is #f (default).
;;;
;;; Pattern: Direct struct construction, no shared fixtures, no process-string.
;;; Uses temporary files for IO boundary tests.
;;;

(require rackunit
         racket/file
         racket/port
         "../effect-bridge.rkt"
         "../effect-position.rkt"
         "../io-bridge.rkt"
         "../processes.rkt"
         "../propagator.rkt"
         "../sessions.rkt"
         "../session-lattice.rkt"
         "../session-runtime.rkt"
         "../syntax.rkt")

;; ========================================
;; Helpers
;; ========================================

;; Extract effect list from bindings (returns list of effect descriptors).
(define (effects-from-bindings bindings)
  (effect-set-effects (get-effect-acc bindings)))

;; Find effects of a specific kind in the list.
(define (find-effects pred effects)
  (filter pred effects))


;; ========================================
;; Group 1: Effect Collection — Basic Behavior
;; ========================================

(test-case "collect-effects: default #f does not activate collection"
  (define tmp (make-temporary-file))
  (call-with-output-file tmp
    (lambda (out) (write-string "hello" out))
    #:exists 'truncate/replace)
  (define sess (sess-recv (expr-String) (sess-end)))
  (define proc
    (proc-open (expr-string (path->string tmp))
               sess 'FsCap (proc-stop)))
  (define rnet (make-runtime-network))
  (define-values (rnet* bindings trace)
    (compile-live-process rnet proc (hasheq)))
  ;; Effect collection should NOT be active
  (check-false (collecting-effects? bindings))
  ;; Effect accumulator should be empty
  (check-equal? (effect-set-count (get-effect-acc bindings)) 0)
  (delete-file tmp))

(test-case "collect-effects: #t activates collection"
  (define tmp (make-temporary-file))
  (call-with-output-file tmp
    (lambda (out) (write-string "test" out))
    #:exists 'truncate/replace)
  (define sess (sess-recv (expr-String) (sess-end)))
  (define proc
    (proc-open (expr-string (path->string tmp))
               sess 'FsCap (proc-stop)))
  (define rnet (make-runtime-network))
  (define-values (rnet* bindings trace)
    (compile-live-process rnet proc (hasheq) (hasheq)
                          #:collect-effects? #t))
  ;; Effect collection should be active
  (check-true (collecting-effects? bindings))
  ;; Should have effects (at least eff-open and eff-close)
  (check-true (> (effect-set-count (get-effect-acc bindings)) 0))
  (delete-file tmp))


;; ========================================
;; Group 2: Effect Descriptors — Open/Close
;; ========================================

(test-case "collect-effects: proc-open produces eff-open descriptor"
  (define tmp (make-temporary-file))
  (call-with-output-file tmp
    (lambda (out) (write-string "x" out))
    #:exists 'truncate/replace)
  (define path-str (path->string tmp))
  (define sess (sess-recv (expr-String) (sess-end)))
  (define proc
    (proc-open (expr-string path-str)
               sess 'FsCap (proc-stop)))
  (define rnet (make-runtime-network))
  (define-values (rnet* bindings trace)
    (compile-live-process rnet proc (hasheq) (hasheq)
                          #:collect-effects? #t))
  (define effs (effects-from-bindings bindings))
  (define opens (find-effects eff-open? effs))
  (check-equal? (length opens) 1)
  ;; eff-open fields
  (define op (car opens))
  (check-equal? (eff-open-channel op) 'ch)
  (check-equal? (eff-open-position op) (eff-pos 'ch 0))
  (check-equal? (eff-open-path op) path-str)
  (check-equal? (eff-open-mode op) 'read)  ;; recv session → read mode
  (delete-file tmp))

(test-case "collect-effects: proc-stop produces eff-close descriptor"
  (define tmp (make-temporary-file))
  (call-with-output-file tmp
    (lambda (out) (write-string "y" out))
    #:exists 'truncate/replace)
  ;; Session: ?String.end, process: open → recv → stop
  ;; recv increments depth to 1, so close is at depth 1
  (define sess (sess-recv (expr-String) (sess-end)))
  (define proc
    (proc-open (expr-string (path->string tmp))
               sess 'FsCap
               (proc-recv 'ch #f (expr-String) (proc-stop))))
  (define rnet (make-runtime-network))
  (define-values (rnet* bindings trace)
    (compile-live-process rnet proc (hasheq) (hasheq)
                          #:collect-effects? #t))
  (define effs (effects-from-bindings bindings))
  (define closes (find-effects eff-close? effs))
  (check-equal? (length closes) 1)
  ;; eff-close position should be after the recv (depth 1)
  (define cl (car closes))
  (check-equal? (eff-close-channel cl) 'ch)
  (check-equal? (eff-close-position cl) (eff-pos 'ch 1))
  (delete-file tmp))

(test-case "collect-effects: open + stop only → open at 0, close at 0"
  ;; Session is just (sess-end) → no send/recv steps
  (define tmp (make-temporary-file))
  (call-with-output-file tmp
    (lambda (out) (write-string "z" out))
    #:exists 'truncate/replace)
  (define sess (sess-end))
  (define proc
    (proc-open (expr-string (path->string tmp))
               sess 'FsCap (proc-stop)))
  (define rnet (make-runtime-network))
  (define-values (rnet* bindings trace)
    (compile-live-process rnet proc (hasheq) (hasheq)
                          #:collect-effects? #t))
  (define effs (effects-from-bindings bindings))
  (define opens (find-effects eff-open? effs))
  (define closes (find-effects eff-close? effs))
  (check-equal? (length opens) 1)
  (check-equal? (length closes) 1)
  (check-equal? (eff-open-position (car opens)) (eff-pos 'ch 0))
  (check-equal? (eff-close-position (car closes)) (eff-pos 'ch 0))
  (delete-file tmp))


;; ========================================
;; Group 3: Effect Descriptors — Send/Recv
;; ========================================

(test-case "collect-effects: proc-send produces eff-write descriptor"
  (define tmp (make-temporary-file))
  (define sess (sess-send (expr-String) (sess-end)))
  (define proc
    (proc-open (expr-string (path->string tmp))
               sess 'FsCap
               (proc-send (expr-string "hello world") 'ch (proc-stop))))
  (define rnet (make-runtime-network))
  (define-values (rnet* bindings trace)
    (compile-live-process rnet proc (hasheq) (hasheq)
                          #:collect-effects? #t))
  (define effs (effects-from-bindings bindings))
  (define writes (find-effects eff-write? effs))
  (check-equal? (length writes) 1)
  ;; eff-write fields: channel 'ch, position at depth 0 (first step)
  (define wr (car writes))
  (check-equal? (eff-write-channel wr) 'ch)
  (check-equal? (eff-write-position wr) (eff-pos 'ch 0))
  (check-true (expr-string? (eff-write-value wr)))
  (check-equal? (expr-string-val (eff-write-value wr)) "hello world")
  (delete-file tmp))

(test-case "collect-effects: proc-recv produces eff-read descriptor"
  (define tmp (make-temporary-file))
  (call-with-output-file tmp
    (lambda (out) (write-string "data" out))
    #:exists 'truncate/replace)
  (define sess (sess-recv (expr-String) (sess-end)))
  (define proc
    (proc-open (expr-string (path->string tmp))
               sess 'FsCap
               (proc-recv 'ch #f (expr-String) (proc-stop))))
  (define rnet (make-runtime-network))
  (define-values (rnet* bindings trace)
    (compile-live-process rnet proc (hasheq) (hasheq)
                          #:collect-effects? #t))
  (define effs (effects-from-bindings bindings))
  (define reads (find-effects eff-read? effs))
  (check-equal? (length reads) 1)
  ;; eff-read fields: channel 'ch, position at depth 0 (first step)
  (define rd (car reads))
  (check-equal? (eff-read-channel rd) 'ch)
  (check-equal? (eff-read-position rd) (eff-pos 'ch 0))
  (delete-file tmp))


;; ========================================
;; Group 4: Multi-Step Depth Tracking
;; ========================================

(test-case "collect-effects: send then recv has correct depths"
  ;; Session: !String.?Int.end → send at depth 0, recv at depth 1
  (define tmp (make-temporary-file))
  (define sess (sess-send (expr-String) (sess-recv (expr-Int) (sess-end))))
  (define proc
    (proc-open (expr-string (path->string tmp))
               sess 'FsCap
               (proc-send (expr-string "msg") 'ch
                 (proc-recv 'ch #f (expr-Int) (proc-stop)))))
  (define rnet (make-runtime-network))
  (define-values (rnet* bindings trace)
    (compile-live-process rnet proc (hasheq) (hasheq)
                          #:collect-effects? #t))
  (define effs (effects-from-bindings bindings))
  (define writes (find-effects eff-write? effs))
  (define reads (find-effects eff-read? effs))
  (define closes (find-effects eff-close? effs))
  ;; Verify depths
  (check-equal? (length writes) 1)
  (check-equal? (length reads) 1)
  (check-equal? (length closes) 1)
  (check-equal? (eff-write-position (car writes)) (eff-pos 'ch 0))
  (check-equal? (eff-read-position (car reads)) (eff-pos 'ch 1))
  (check-equal? (eff-close-position (car closes)) (eff-pos 'ch 2))
  (delete-file tmp))

(test-case "collect-effects: three sends have increasing depths"
  ;; Session: !S.!S.!S.end → sends at depth 0, 1, 2; close at 3
  (define tmp (make-temporary-file))
  (define sess (sess-send (expr-String)
                 (sess-send (expr-String)
                   (sess-send (expr-String) (sess-end)))))
  (define proc
    (proc-open (expr-string (path->string tmp))
               sess 'FsCap
               (proc-send (expr-string "a") 'ch
                 (proc-send (expr-string "b") 'ch
                   (proc-send (expr-string "c") 'ch
                     (proc-stop))))))
  (define rnet (make-runtime-network))
  (define-values (rnet* bindings trace)
    (compile-live-process rnet proc (hasheq) (hasheq)
                          #:collect-effects? #t))
  (define effs (effects-from-bindings bindings))
  (define writes (find-effects eff-write? effs))
  (define closes (find-effects eff-close? effs))
  ;; 3 writes + 1 close
  (check-equal? (length writes) 3)
  (check-equal? (length closes) 1)
  ;; Check depths — effects accumulate via cons, so most recent is first
  (define write-depths
    (sort (map (lambda (w) (eff-pos-depth (eff-write-position w))) writes) <))
  (check-equal? write-depths '(0 1 2))
  (check-equal? (eff-close-position (car closes)) (eff-pos 'ch 3))
  (delete-file tmp))


;; ========================================
;; Group 5: Architecture A Preserved
;; ========================================

(test-case "collect-effects: Architecture A still opens files"
  ;; With default #:collect-effects? #f, file should be opened normally
  (define tmp (make-temporary-file))
  (call-with-output-file tmp
    (lambda (out) (write-string "arch-a" out))
    #:exists 'truncate/replace)
  (define sess (sess-recv (expr-String) (sess-end)))
  (define proc
    (proc-open (expr-string (path->string tmp))
               sess 'FsCap
               (proc-recv 'ch #f (expr-String) (proc-stop))))
  (define rnet (make-runtime-network))
  (define-values (rnet* bindings trace)
    (compile-live-process rnet proc (hasheq)))
  ;; io-cell should exist in bindings (Architecture A stored it)
  (check-true (hash-has-key? bindings (string->symbol "__io_cell_ch")))
  ;; Effect accumulator should be empty (not collecting)
  (check-equal? (effect-set-count (get-effect-acc bindings)) 0)
  (delete-file tmp))

(test-case "collect-effects: collection mode does NOT open file"
  ;; With #:collect-effects? #t, file should NOT be opened
  (define tmp (make-temporary-file))
  (call-with-output-file tmp
    (lambda (out) (write-string "no-open" out))
    #:exists 'truncate/replace)
  (define sess (sess-recv (expr-String) (sess-end)))
  (define proc
    (proc-open (expr-string (path->string tmp))
               sess 'FsCap
               (proc-recv 'ch #f (expr-String) (proc-stop))))
  (define rnet (make-runtime-network))
  (define-values (rnet* bindings trace)
    (compile-live-process rnet proc (hasheq) (hasheq)
                          #:collect-effects? #t))
  ;; IO cell should be at io-bot (file not opened)
  (define io-cell-id (hash-ref bindings (string->symbol "__io_cell_ch") #f))
  (check-true (and io-cell-id #t) "io-cell should be stored in bindings")
  (define io-state (rt-cell-read rnet* io-cell-id))
  (check-true (io-bot? io-state) "io-cell should be at io-bot in collection mode")
  (delete-file tmp))


;; ========================================
;; Group 6: AD-C2 — Position Cells
;; ========================================

(test-case "collect-effects: position cell created for channel"
  (define tmp (make-temporary-file))
  (call-with-output-file tmp
    (lambda (out) (write-string "pos-cell" out))
    #:exists 'truncate/replace)
  (define sess (sess-recv (expr-String) (sess-end)))
  (define proc
    (proc-open (expr-string (path->string tmp))
               sess 'FsCap (proc-stop)))
  (define rnet (make-runtime-network))
  (define-values (rnet* bindings trace)
    (compile-live-process rnet proc (hasheq) (hasheq)
                          #:collect-effects? #t))
  ;; Position cells hash should have 'ch entry
  (define pos-cells (get-eff-pos-cells bindings))
  (check-true (hash-has-key? pos-cells 'ch)
    "position cells should have 'ch entry")
  ;; The cell ID should be valid
  (define eff-cell-id (hash-ref pos-cells 'ch))
  (check-true (cell-id? eff-cell-id))
  (delete-file tmp))

(test-case "collect-effects: position cell advances after quiescence"
  ;; After quiescence, the session-effect bridge should have written
  ;; the correct eff-pos to the position cell.
  (define tmp (make-temporary-file))
  (call-with-output-file tmp
    (lambda (out) (write-string "bridge" out))
    #:exists 'truncate/replace)
  ;; Session: ?String.end — recv is one step
  (define sess (sess-recv (expr-String) (sess-end)))
  (define proc
    (proc-open (expr-string (path->string tmp))
               sess 'FsCap
               (proc-recv 'ch #f (expr-String) (proc-stop))))
  (define rnet (make-runtime-network))
  (define-values (rnet* bindings trace)
    (compile-live-process rnet proc (hasheq) (hasheq)
                          #:collect-effects? #t))
  ;; Run to quiescence to let bridge propagators fire
  (define rnet-q (rt-run-to-quiescence rnet*))
  ;; Check position cell
  (define pos-cells (get-eff-pos-cells bindings))
  (define eff-cell-id (hash-ref pos-cells 'ch))
  (define eff-val (rt-cell-read rnet-q eff-cell-id))
  ;; After quiescence, the session cell has been initialized with the
  ;; full session type. The bridge should have computed the depth.
  ;; Session cell starts at the full session (sess-recv (expr-String) (sess-end)),
  ;; which is steps-to = 0 from the full session.
  (check-true (eff-pos? eff-val)
    (format "position cell should have eff-pos, got ~v" eff-val))
  (check-equal? (eff-pos-channel eff-val) 'ch)
  ;; Depth is 0 because the session cell starts at the full session
  (check-equal? (eff-pos-depth eff-val) 0)
  (delete-file tmp))


;; ========================================
;; Group 7: Complete Effect Ordering
;; ========================================

(test-case "collect-effects: full pipeline — open, send, recv, close"
  ;; Session: !String.?String.end
  (define tmp (make-temporary-file))
  (define sess (sess-send (expr-String)
                 (sess-recv (expr-String) (sess-end))))
  (define proc
    (proc-open (expr-string (path->string tmp))
               sess 'FsCap
               (proc-send (expr-string "out") 'ch
                 (proc-recv 'ch #f (expr-String) (proc-stop)))))
  (define rnet (make-runtime-network))
  (define-values (rnet* bindings trace)
    (compile-live-process rnet proc (hasheq) (hasheq)
                          #:collect-effects? #t))
  (define effs (effects-from-bindings bindings))
  ;; Should have exactly 4 effects: open, write, read, close
  (check-equal? (effect-set-count (get-effect-acc bindings)) 4)
  (define opens (find-effects eff-open? effs))
  (define writes (find-effects eff-write? effs))
  (define reads (find-effects eff-read? effs))
  (define closes (find-effects eff-close? effs))
  (check-equal? (length opens) 1)
  (check-equal? (length writes) 1)
  (check-equal? (length reads) 1)
  (check-equal? (length closes) 1)
  ;; Depths: open@0, send@0, recv@1, close@2
  (check-equal? (eff-open-position (car opens)) (eff-pos 'ch 0))
  (check-equal? (eff-write-position (car writes)) (eff-pos 'ch 0))
  (check-equal? (eff-read-position (car reads)) (eff-pos 'ch 1))
  (check-equal? (eff-close-position (car closes)) (eff-pos 'ch 2))
  (delete-file tmp))

(test-case "collect-effects: effect count matches protocol steps + open + close"
  ;; Session: ?S.?S.?S.end → 3 recvs + 1 open + 1 close = 5 effects
  (define tmp (make-temporary-file))
  (call-with-output-file tmp
    (lambda (out) (write-string "data data data" out))
    #:exists 'truncate/replace)
  (define sess (sess-recv (expr-String)
                 (sess-recv (expr-String)
                   (sess-recv (expr-String) (sess-end)))))
  (define proc
    (proc-open (expr-string (path->string tmp))
               sess 'FsCap
               (proc-recv 'ch #f (expr-String)
                 (proc-recv 'ch #f (expr-String)
                   (proc-recv 'ch #f (expr-String)
                     (proc-stop))))))
  (define rnet (make-runtime-network))
  (define-values (rnet* bindings trace)
    (compile-live-process rnet proc (hasheq) (hasheq)
                          #:collect-effects? #t))
  (check-equal? (effect-set-count (get-effect-acc bindings)) 5)
  (delete-file tmp))


;; ========================================
;; Group 8: No IO Channel — Non-IO Processes
;; ========================================

(test-case "collect-effects: process without proc-open has no effects"
  ;; A proc-stop with no channel endpoints — no IO effects
  (define rnet (make-runtime-network))
  (define-values (rnet* bindings trace)
    (compile-live-process rnet (proc-stop) (hasheq) (hasheq)
                          #:collect-effects? #t))
  ;; Collecting is active, but no effects accumulated
  (check-true (collecting-effects? bindings))
  (check-equal? (effect-set-count (get-effect-acc bindings)) 0))

(test-case "collect-effects: send on non-IO channel produces no effect"
  ;; proc-new creates a regular channel pair (not IO),
  ;; sends should NOT produce effect descriptors because
  ;; there's no IO cell for the channel
  (define sess (sess-send (expr-String) (sess-end)))
  (define rnet (make-runtime-network))
  (define proc
    (proc-new sess
      (proc-par
        (proc-send (expr-string "hi") 'ch (proc-stop))
        (proc-recv 'ch #f (expr-String) (proc-stop)))))
  (define-values (rnet* bindings trace)
    (compile-live-process rnet proc (hasheq) (hasheq)
                          #:collect-effects? #t))
  ;; No effects — these are non-IO channels
  (check-equal? (effect-set-count (get-effect-acc bindings)) 0))


;; ========================================
;; Group 9: Write Mode Inference
;; ========================================

(test-case "collect-effects: send session → write mode in eff-open"
  (define tmp (make-temporary-file))
  (define sess (sess-send (expr-String) (sess-end)))
  (define proc
    (proc-open (expr-string (path->string tmp))
               sess 'FsCap
               (proc-send (expr-string "output") 'ch (proc-stop))))
  (define rnet (make-runtime-network))
  (define-values (rnet* bindings trace)
    (compile-live-process rnet proc (hasheq) (hasheq)
                          #:collect-effects? #t))
  (define effs (effects-from-bindings bindings))
  (define opens (find-effects eff-open? effs))
  (check-equal? (length opens) 1)
  (check-equal? (eff-open-mode (car opens)) 'write)
  (delete-file tmp))

(test-case "collect-effects: recv session → read mode in eff-open"
  (define tmp (make-temporary-file))
  (call-with-output-file tmp
    (lambda (out) (write-string "input" out))
    #:exists 'truncate/replace)
  (define sess (sess-recv (expr-String) (sess-end)))
  (define proc
    (proc-open (expr-string (path->string tmp))
               sess 'FsCap
               (proc-recv 'ch #f (expr-String) (proc-stop))))
  (define rnet (make-runtime-network))
  (define-values (rnet* bindings trace)
    (compile-live-process rnet proc (hasheq) (hasheq)
                          #:collect-effects? #t))
  (define effs (effects-from-bindings bindings))
  (define opens (find-effects eff-open? effs))
  (check-equal? (length opens) 1)
  (check-equal? (eff-open-mode (car opens)) 'read)
  (delete-file tmp))

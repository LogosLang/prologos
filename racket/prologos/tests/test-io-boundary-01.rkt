#lang racket/base

;;;
;;; test-io-boundary-01.rkt — IO boundary operations tests
;;;
;;; Phase IO-C: Tests for rt-new-io-channel (C1) and compile-live-process
;;; proc-open match arm (C1). Integration tests for the full proc-open pipeline.
;;;
;;; Pattern: Direct struct construction, no shared fixtures, no process-string.
;;; Uses temporary files for IO tests.
;;;

(require rackunit
         racket/file
         racket/port
         racket/string
         "../io-bridge.rkt"
         "../processes.rkt"
         "../propagator.rkt"
         "../sessions.rkt"
         "../session-lattice.rkt"
         "../session-runtime.rkt"
         "../syntax.rkt")

;; ========================================
;; Group 1: rt-new-io-channel
;; ========================================

(test-case "rt-new-io-channel: creates endpoint + io-cell"
  (define sess (sess-recv (expr-String) (sess-end)))
  (define rnet (make-runtime-network))
  (define-values (rnet1 ep io-cell) (rt-new-io-channel rnet sess))
  ;; Returns correct types
  (check-true (runtime-network? rnet1))
  (check-true (channel-endpoint? ep))
  (check-true (cell-id? io-cell))
  ;; IO cell starts at io-bot
  (check-true (io-bot? (rt-cell-read rnet1 io-cell))))

(test-case "rt-new-io-channel: session cell initialized"
  (define sess (sess-recv (expr-String) (sess-end)))
  (define rnet (make-runtime-network))
  (define-values (rnet1 ep io-cell) (rt-new-io-channel rnet sess))
  ;; Session cell should read the provided session type
  (define sess-val (rt-cell-read rnet1 (channel-endpoint-session-cell ep)))
  (check-true (sess-recv? sess-val))
  (check-true (sess-end? (sess-recv-cont sess-val))))

(test-case "rt-new-io-channel: msg cells at bot"
  (define sess (sess-send (expr-String) (sess-end)))
  (define rnet (make-runtime-network))
  (define-values (rnet1 ep io-cell) (rt-new-io-channel rnet sess))
  (check-true (msg-bot? (rt-cell-read rnet1 (channel-endpoint-msg-out-cell ep))))
  (check-true (msg-bot? (rt-cell-read rnet1 (channel-endpoint-msg-in-cell ep)))))

;; ========================================
;; Group 2: Direct IO channel + bridge (prop-net level)
;; ========================================

(test-case "io-channel: read delivers data to msg-in"
  ;; Manually wire up an IO channel and verify end-to-end data flow
  (define tmp (make-temporary-file))
  (call-with-output-file tmp
    (lambda (out) (write-string "direct read test" out))
    #:exists 'truncate/replace)
  (define sess (sess-recv (expr-String) (sess-end)))
  (define rnet0 (make-runtime-network))
  (define-values (rnet1 ep io-cell) (rt-new-io-channel rnet0 sess))
  ;; Set io-opening
  (define rnet2 (rt-cell-write rnet1 io-cell
                  (io-opening (path->string tmp) 'read)))
  ;; Open the file
  (define net-opened (io-bridge-open-file (runtime-network-prop-net rnet2) io-cell))
  (define rnet3 (runtime-network net-opened
                  (runtime-network-channel-info rnet2)
                  (runtime-network-next-chan-id rnet2)))
  ;; Verify io-open
  (check-true (io-open? (rt-cell-read rnet3 io-cell)))
  ;; Install bridge propagator at prop-net level
  (define fire-fn (make-io-bridge-propagator
                    io-cell
                    (channel-endpoint-session-cell ep)
                    (channel-endpoint-msg-in-cell ep)
                    (channel-endpoint-msg-out-cell ep)))
  (define-values (net4 _pid)
    (net-add-propagator (runtime-network-prop-net rnet3)
      (list io-cell (channel-endpoint-session-cell ep) (channel-endpoint-msg-out-cell ep))
      (list (channel-endpoint-msg-in-cell ep) io-cell)
      fire-fn))
  (define rnet4 (runtime-network net4
                  (runtime-network-channel-info rnet3)
                  (runtime-network-next-chan-id rnet3)))
  ;; Run to quiescence
  (define rnet-q (rt-run-to-quiescence rnet4))
  ;; msg-in should have data
  (define msg-in-val (rt-cell-read rnet-q (channel-endpoint-msg-in-cell ep)))
  (check-true (expr-string? msg-in-val))
  (check-equal? (expr-string-val msg-in-val) "direct read test")
  ;; Clean up
  (define io-state (rt-cell-read rnet-q io-cell))
  (when (io-open? io-state)
    (close-input-port (io-open-port io-state)))
  (delete-file tmp))

(test-case "io-channel: write session writes data"
  (define tmp (make-temporary-file))
  (define sess (sess-send (expr-String) (sess-end)))
  (define rnet0 (make-runtime-network))
  (define-values (rnet1 ep io-cell) (rt-new-io-channel rnet0 sess))
  ;; Set io-opening in write mode
  (define rnet2 (rt-cell-write rnet1 io-cell
                  (io-opening (path->string tmp) 'write)))
  ;; Open the file
  (define net-opened (io-bridge-open-file (runtime-network-prop-net rnet2) io-cell))
  (define rnet3 (runtime-network net-opened
                  (runtime-network-channel-info rnet2)
                  (runtime-network-next-chan-id rnet2)))
  (check-true (io-open? (rt-cell-read rnet3 io-cell)))
  ;; Install bridge propagator
  (define fire-fn (make-io-bridge-propagator
                    io-cell
                    (channel-endpoint-session-cell ep)
                    (channel-endpoint-msg-in-cell ep)
                    (channel-endpoint-msg-out-cell ep)))
  (define-values (net4 _pid)
    (net-add-propagator (runtime-network-prop-net rnet3)
      (list io-cell (channel-endpoint-session-cell ep) (channel-endpoint-msg-out-cell ep))
      (list (channel-endpoint-msg-in-cell ep) io-cell)
      fire-fn))
  (define rnet4 (runtime-network net4
                  (runtime-network-channel-info rnet3)
                  (runtime-network-next-chan-id rnet3)))
  ;; Drain initial propagator firing (msg-out is bot → noop)
  (define rnet4q (rt-run-to-quiescence rnet4))
  ;; Write message to msg-out
  (define rnet5 (rt-cell-write rnet4q (channel-endpoint-msg-out-cell ep)
                  (expr-string "written by test")))
  ;; Run to quiescence — bridge should write to file (once)
  (define rnet-q (rt-run-to-quiescence rnet5))
  ;; Close the port
  (define io-state (rt-cell-read rnet-q io-cell))
  (when (io-open? io-state)
    (close-output-port (io-open-port io-state)))
  ;; Verify file contents
  (check-equal? (file->string tmp) "written by test")
  (delete-file tmp))

(test-case "io-channel: nonexistent file → io-top"
  (define sess (sess-recv (expr-String) (sess-end)))
  (define rnet0 (make-runtime-network))
  (define-values (rnet1 ep io-cell) (rt-new-io-channel rnet0 sess))
  (define rnet2 (rt-cell-write rnet1 io-cell
                  (io-opening "/nonexistent/path/does-not-exist.txt" 'read)))
  (define net-opened (io-bridge-open-file (runtime-network-prop-net rnet2) io-cell))
  (define rnet3 (runtime-network net-opened
                  (runtime-network-channel-info rnet2)
                  (runtime-network-next-chan-id rnet2)))
  ;; io-cell should be io-top (error)
  (check-true (io-top? (rt-cell-read rnet3 io-cell))))

(test-case "io-channel: session end closes port"
  (define tmp (make-temporary-file))
  (call-with-output-file tmp
    (lambda (out) (write-string "close-test" out))
    #:exists 'truncate/replace)
  ;; Session is just sess-end — bridge should immediately close
  (define sess (sess-end))
  (define rnet0 (make-runtime-network))
  (define-values (rnet1 ep io-cell) (rt-new-io-channel rnet0 sess))
  ;; Open the file
  (define rnet2 (rt-cell-write rnet1 io-cell
                  (io-opening (path->string tmp) 'read)))
  (define net-opened (io-bridge-open-file (runtime-network-prop-net rnet2) io-cell))
  (define rnet3 (runtime-network net-opened
                  (runtime-network-channel-info rnet2)
                  (runtime-network-next-chan-id rnet2)))
  ;; Get port before quiescence
  (define io-pre (rt-cell-read rnet3 io-cell))
  (check-true (io-open? io-pre))
  (define port (io-open-port io-pre))
  ;; Install bridge propagator
  (define fire-fn (make-io-bridge-propagator
                    io-cell
                    (channel-endpoint-session-cell ep)
                    (channel-endpoint-msg-in-cell ep)
                    (channel-endpoint-msg-out-cell ep)))
  (define-values (net4 _pid)
    (net-add-propagator (runtime-network-prop-net rnet3)
      (list io-cell (channel-endpoint-session-cell ep) (channel-endpoint-msg-out-cell ep))
      (list (channel-endpoint-msg-in-cell ep) io-cell)
      fire-fn))
  (define rnet4 (runtime-network net4
                  (runtime-network-channel-info rnet3)
                  (runtime-network-next-chan-id rnet3)))
  ;; Run to quiescence — session is sess-end, bridge should close port
  (define rnet-q (rt-run-to-quiescence rnet4))
  ;; Verify io-closed
  (check-true (io-closed? (rt-cell-read rnet-q io-cell)))
  ;; Verify port is closed
  (check-true (port-closed? port))
  (delete-file tmp))

;; ========================================
;; Group 3: compile-live-process integration
;; ========================================

(test-case "proc-open: compiles without error"
  (define sess (sess-recv (expr-String) (sess-end)))
  (define tmp (make-temporary-file))
  (call-with-output-file tmp
    (lambda (out) (write-string "hello" out))
    #:exists 'truncate/replace)
  (define proc
    (proc-open (expr-string (path->string tmp))
               sess 'FsCap (proc-stop)))
  (define rnet (make-runtime-network))
  (define-values (rnet* bindings trace)
    (compile-live-process rnet proc (hasheq)))
  (check-true (runtime-network? rnet*))
  (delete-file tmp))

(test-case "proc-open: endpoint bound as 'ch in continuation"
  (define tmp (make-temporary-file))
  (call-with-output-file tmp
    (lambda (out) (write-string "x" out))
    #:exists 'truncate/replace)
  (define sess (sess-recv (expr-String) (sess-end)))
  ;; proc-open → proc-recv 'ch → proc-stop
  ;; If 'ch is not bound, proc-recv would skip (return rnet unchanged)
  ;; proc-recv adds 'ch to bindings as 'pending-recv when it processes
  (define proc
    (proc-open (expr-string (path->string tmp))
               sess 'FsCap
               (proc-recv 'ch #f (expr-String) (proc-stop))))
  (define rnet (make-runtime-network))
  (define-values (rnet* bindings trace)
    (compile-live-process rnet proc (hasheq)))
  ;; proc-recv should have added 'ch → 'pending-recv
  (check-equal? (hash-ref bindings 'ch #f) 'pending-recv)
  (check-false (rt-contradiction? rnet*))
  (delete-file tmp))

(test-case "proc-open: trace records file path"
  (define tmp (make-temporary-file))
  (call-with-output-file tmp
    (lambda (out) (write-string "trace-test" out))
    #:exists 'truncate/replace)
  (define path-str (path->string tmp))
  (define sess (sess-recv (expr-String) (sess-end)))
  (define proc
    (proc-open (expr-string path-str)
               sess 'FsCap (proc-stop)))
  (define rnet (make-runtime-network))
  (define-values (rnet* bindings trace)
    (compile-live-process rnet proc (hasheq)))
  ;; Trace is keyed by cell-id — find any entry containing the path
  (define all-trace-strs
    (for/fold ([acc '()])
              ([(_ entries) (in-hash trace)])
      (append entries acc)))
  (check-true (pair? all-trace-strs) "trace should have entries")
  (check-true
    (for/or ([s (in-list all-trace-strs)])
      (string-contains? s path-str))
    (format "trace should mention path ~a" path-str))
  (delete-file tmp))

(test-case "proc-open: read then recv compiles and binds"
  ;; proc-open → proc-recv 'ch → proc-stop
  ;; Verifies: proc-open creates endpoint, proc-recv uses it,
  ;; bindings record the recv operation
  (define tmp (make-temporary-file))
  (call-with-output-file tmp
    (lambda (out) (write-string "lifecycle data" out))
    #:exists 'truncate/replace)
  (define sess (sess-recv (expr-String) (sess-end)))
  (define proc
    (proc-open (expr-string (path->string tmp))
               sess 'FsCap
               (proc-recv 'ch #f (expr-String) (proc-stop))))
  (define rnet (make-runtime-network))
  (define-values (rnet* bindings trace)
    (compile-live-process rnet proc (hasheq)))
  ;; proc-recv should have added 'ch → 'pending-recv
  (check-equal? (hash-ref bindings 'ch #f) 'pending-recv)
  ;; Compilation should succeed (no errors during compilation)
  (check-true (runtime-network? rnet*))
  (delete-file tmp))

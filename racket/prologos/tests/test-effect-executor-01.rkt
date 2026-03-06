#lang racket/base

;;;
;;; test-effect-executor-01.rkt — AD-E: Effect Executor + Architecture D Pipeline tests
;;;
;;; Tests for execute-effects (AD-E2), execute-effects-and-propagate,
;;; and rt-execute-process-d (AD-E3).
;;;
;;; Pattern: Direct struct construction, no shared fixtures, no process-string.
;;; Uses temporary files for IO boundary tests.
;;;

(require rackunit
         racket/file
         racket/port
         racket/string
         "../effect-executor.rkt"
         "../effect-ordering.rkt"
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

;; Create a temp file with given content.
(define (make-temp-with-content content)
  (define tmp (make-temporary-file))
  (call-with-output-file tmp
    (lambda (out) (write-string content out))
    #:exists 'truncate/replace)
  tmp)


;; ========================================
;; Group 1: execute-effects — Basic Behavior
;; ========================================

(test-case "execute-effects: empty list → no IO, empty results"
  (define rnet (make-runtime-network))
  (define-values (rnet* results open-ports) (execute-effects rnet '()))
  (check-equal? (hash-count results) 0)
  (check-equal? (hash-count open-ports) 0))

(test-case "execute-effects: open + close writes to file"
  ;; Open a file for writing, then close it
  (define tmp (make-temporary-file))
  (define rnet (make-runtime-network))
  (define effs
    (list (eff-open 'ch (eff-pos 'ch 0) (path->string tmp) 'write)
          (eff-close 'ch (eff-pos 'ch 1))))
  (define-values (rnet* results open-ports) (execute-effects rnet effs))
  ;; Open should have a port result
  (define open-result (hash-ref results (eff-pos 'ch 0)))
  (check-true (output-port? open-result))
  ;; Close should have void result
  (check-true (void? (hash-ref results (eff-pos 'ch 1))))
  ;; open-ports should be empty after close
  (check-equal? (hash-count open-ports) 0)
  (delete-file tmp))

(test-case "execute-effects: open + write + close writes content"
  (define tmp (make-temporary-file))
  (define rnet (make-runtime-network))
  (define effs
    (list (eff-open 'ch (eff-pos 'ch 0) (path->string tmp) 'write)
          (eff-write 'ch (eff-pos 'ch 1) (expr-string "hello world"))
          (eff-close 'ch (eff-pos 'ch 2))))
  (define-values (rnet* results open-ports) (execute-effects rnet effs))
  ;; Write result should be void (success)
  (check-true (void? (hash-ref results (eff-pos 'ch 1))))
  ;; File content should match
  (check-equal? (file->string tmp) "hello world")
  (delete-file tmp))

(test-case "execute-effects: open + read + close reads content"
  (define tmp (make-temp-with-content "file data here"))
  (define rnet (make-runtime-network))
  (define effs
    (list (eff-open 'ch (eff-pos 'ch 0) (path->string tmp) 'read)
          (eff-read 'ch (eff-pos 'ch 1))
          (eff-close 'ch (eff-pos 'ch 2))))
  (define-values (rnet* results open-ports) (execute-effects rnet effs))
  ;; Read result should be the file content
  (check-equal? (hash-ref results (eff-pos 'ch 1)) "file data here")
  (delete-file tmp))

(test-case "execute-effects: write without open → error"
  (define rnet (make-runtime-network))
  (define effs
    (list (eff-write 'ch (eff-pos 'ch 0) (expr-string "oops"))))
  (define-values (rnet* results open-ports) (execute-effects rnet effs))
  ;; Result should be error string
  (check-equal? (hash-ref results (eff-pos 'ch 0)) "no open port"))

(test-case "execute-effects: read without open → error"
  (define rnet (make-runtime-network))
  (define effs
    (list (eff-read 'ch (eff-pos 'ch 0))))
  (define-values (rnet* results open-ports) (execute-effects rnet effs))
  (check-equal? (hash-ref results (eff-pos 'ch 0)) "no open port"))

(test-case "execute-effects: open non-existent file for read → IO error"
  (define rnet (make-runtime-network))
  (define effs
    (list (eff-open 'ch (eff-pos 'ch 0) "/tmp/nonexistent-prologos-test-file-12345" 'read)))
  (define-values (rnet* results open-ports) (execute-effects rnet effs))
  ;; Result should be an IO error string
  (define result (hash-ref results (eff-pos 'ch 0)))
  (check-true (string? result))
  (check-true (string-contains? result "IO error")))

(test-case "execute-effects: multiple writes accumulate"
  (define tmp (make-temporary-file))
  (define rnet (make-runtime-network))
  (define effs
    (list (eff-open 'ch (eff-pos 'ch 0) (path->string tmp) 'write)
          (eff-write 'ch (eff-pos 'ch 1) (expr-string "abc"))
          (eff-write 'ch (eff-pos 'ch 2) (expr-string "def"))
          (eff-close 'ch (eff-pos 'ch 3))))
  (define-values (rnet* results open-ports) (execute-effects rnet effs))
  ;; File should have concatenated content
  (check-equal? (file->string tmp) "abcdef")
  (delete-file tmp))

(test-case "execute-effects: read empty file → empty string"
  (define tmp (make-temporary-file))
  ;; Ensure file is empty
  (call-with-output-file tmp (lambda (out) (void)) #:exists 'truncate/replace)
  (define rnet (make-runtime-network))
  (define effs
    (list (eff-open 'ch (eff-pos 'ch 0) (path->string tmp) 'read)
          (eff-read 'ch (eff-pos 'ch 1))
          (eff-close 'ch (eff-pos 'ch 2))))
  (define-values (rnet* results open-ports) (execute-effects rnet effs))
  ;; Empty file → empty string (eof-object becomes "")
  (check-equal? (hash-ref results (eff-pos 'ch 1)) "")
  (delete-file tmp))

(test-case "execute-effects: append mode appends to existing content"
  (define tmp (make-temp-with-content "existing"))
  (define rnet (make-runtime-network))
  (define effs
    (list (eff-open 'ch (eff-pos 'ch 0) (path->string tmp) 'append)
          (eff-write 'ch (eff-pos 'ch 1) (expr-string "+new"))
          (eff-close 'ch (eff-pos 'ch 2))))
  (define-values (rnet* results open-ports) (execute-effects rnet effs))
  (check-equal? (file->string tmp) "existing+new")
  (delete-file tmp))


;; ========================================
;; Group 2: execute-effects — Non-String Values
;; ========================================

(test-case "execute-effects: write non-string value uses format"
  ;; When value is not an expr-string, execute-effects uses (format "~a" value)
  (define tmp (make-temporary-file))
  (define rnet (make-runtime-network))
  (define effs
    (list (eff-open 'ch (eff-pos 'ch 0) (path->string tmp) 'write)
          (eff-write 'ch (eff-pos 'ch 1) 42)
          (eff-close 'ch (eff-pos 'ch 2))))
  (define-values (rnet* results open-ports) (execute-effects rnet effs))
  (check-equal? (file->string tmp) "42")
  (delete-file tmp))


;; ========================================
;; Group 3: rt-execute-process-d — Full Pipeline
;; ========================================

(test-case "rt-execute-process-d: pure process (no IO) → ok"
  ;; A proc-stop process with no effects → ok
  (define sess (sess-end))
  (define proc (proc-stop))
  (define result (rt-execute-process-d proc sess))
  (check-equal? (rt-exec-result-status result) 'ok))

(test-case "rt-execute-process-d: send writes to file"
  ;; Session: !String.end → open file, send "hello", close
  (define tmp (make-temporary-file))
  (define sess (sess-send (expr-String) (sess-end)))
  (define proc
    (proc-open (expr-string (path->string tmp))
               sess 'FsCap
               (proc-send (expr-string "hello from D") 'ch (proc-stop))))
  (define result (rt-execute-process-d proc sess))
  (check-equal? (rt-exec-result-status result) 'ok)
  ;; File should have the content
  (check-equal? (file->string tmp) "hello from D")
  ;; Effect results should be in bindings
  (define bindings (rt-exec-result-bindings result))
  (check-true (hash-has-key? bindings '__effect_results))
  (delete-file tmp))

(test-case "rt-execute-process-d: recv reads from file"
  ;; Session: ?String.end → open file, recv, close
  (define tmp (make-temp-with-content "data for D"))
  (define sess (sess-recv (expr-String) (sess-end)))
  (define proc
    (proc-open (expr-string (path->string tmp))
               sess 'FsCap
               (proc-recv 'ch #f (expr-String) (proc-stop))))
  (define result (rt-execute-process-d proc sess))
  (check-equal? (rt-exec-result-status result) 'ok)
  ;; Effect results should contain the read data
  (define bindings (rt-exec-result-bindings result))
  (check-true (hash-has-key? bindings '__effect_results))
  (define effect-results (hash-ref bindings '__effect_results))
  ;; Find the read result — should be a string
  (define read-values
    (for/list ([(pos val) (in-hash effect-results)]
               #:when (string? val))
      val))
  (check-true (> (length read-values) 0) "should have read data")
  (check-not-false (member "data for D" read-values))
  (delete-file tmp))

(test-case "rt-execute-process-d: send+recv full pipeline"
  ;; Session: !String.?String.end → open file, send, recv, close
  ;; We write first, so the file should have content
  (define tmp (make-temporary-file))
  (define sess (sess-send (expr-String)
                 (sess-recv (expr-String) (sess-end))))
  (define proc
    (proc-open (expr-string (path->string tmp))
               sess 'FsCap
               (proc-send (expr-string "output") 'ch
                 (proc-recv 'ch #f (expr-String) (proc-stop)))))
  (define result (rt-execute-process-d proc sess))
  (check-equal? (rt-exec-result-status result) 'ok)
  ;; File should have been written to
  (check-equal? (file->string tmp) "output")
  (delete-file tmp))

(test-case "rt-execute-process-d: multiple sends"
  ;; Session: !S.!S.!S.end → three writes
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
  (define result (rt-execute-process-d proc sess))
  (check-equal? (rt-exec-result-status result) 'ok)
  ;; File should have concatenated writes
  (check-equal? (file->string tmp) "abc")
  (delete-file tmp))

(test-case "rt-execute-process-d: non-IO process → no effects, ok"
  ;; proc-new creates non-IO channels: effects collected but none are IO effects.
  ;; rt-execute-process-d's self channel has sess-end (no external comms).
  (define sess (sess-send (expr-Nat) (sess-end)))
  (define proc
    (proc-new sess
      (proc-par
        (proc-send (expr-nat-val 42) 'ch (proc-stop))
        (proc-recv 'ch #f (expr-Nat) (proc-stop)))))
  (define result (rt-execute-process-d proc (sess-end)))
  (check-equal? (rt-exec-result-status result) 'ok))


;; ========================================
;; Group 4: execute-effects-and-propagate
;; ========================================

(test-case "execute-effects-and-propagate: read feeds back to propagator"
  ;; Create a runtime network with a channel endpoint
  ;; Execute a read effect, verify that the msg-in cell gets the value
  (define tmp (make-temp-with-content "propagated"))
  (define rnet0 (make-runtime-network))
  (define sess (sess-recv (expr-String) (sess-end)))
  (define-values (rnet1 pair) (rt-new-channel-pair rnet0 sess))
  (define ep-a (channel-pair-ep-a pair))
  (define channel-eps (hasheq 'ch ep-a))
  ;; Create effects: open for read, read, close
  (define effs
    (list (eff-open 'ch (eff-pos 'ch 0) (path->string tmp) 'read)
          (eff-read 'ch (eff-pos 'ch 1))
          (eff-close 'ch (eff-pos 'ch 2))))
  (define-values (rnet* results) (execute-effects-and-propagate rnet1 effs channel-eps))
  ;; The read result should be the file content
  (check-equal? (hash-ref results (eff-pos 'ch 1)) "propagated")
  ;; The msg-in cell should have been written with the value
  (define msg-in-val (rt-cell-read rnet* (channel-endpoint-msg-in-cell ep-a)))
  (check-true (expr-string? msg-in-val))
  (check-equal? (expr-string-val msg-in-val) "propagated")
  (delete-file tmp))

(test-case "execute-effects-and-propagate: write effects don't feed back"
  ;; Only read effects feed back into the propagator network
  (define tmp (make-temporary-file))
  (define rnet0 (make-runtime-network))
  (define sess (sess-send (expr-String) (sess-end)))
  (define-values (rnet1 pair) (rt-new-channel-pair rnet0 sess))
  (define ep-a (channel-pair-ep-a pair))
  (define channel-eps (hasheq 'ch ep-a))
  ;; Write effects only
  (define effs
    (list (eff-open 'ch (eff-pos 'ch 0) (path->string tmp) 'write)
          (eff-write 'ch (eff-pos 'ch 1) (expr-string "no feedback"))
          (eff-close 'ch (eff-pos 'ch 2))))
  (define-values (rnet* results) (execute-effects-and-propagate rnet1 effs channel-eps))
  ;; Write result should be void
  (check-true (void? (hash-ref results (eff-pos 'ch 1))))
  ;; msg-in cell should still be at bot (no read to feed back)
  (define msg-in-val (rt-cell-read rnet* (channel-endpoint-msg-in-cell ep-a)))
  (check-true (msg-bot? msg-in-val))
  (delete-file tmp))

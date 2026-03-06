#lang racket/base

;;;
;;; test-architecture-selection-01.rkt — AD-F2/F3: Architecture Selection + Hooks
;;;
;;; Tests for architecture selection logic (AD-F2): count-io-channels,
;;; architecture-d-required?, rt-execute-process-auto, and concurrent
;;; execution hooks (AD-F3).
;;;
;;; Pattern: Direct struct construction, no shared fixtures, no process-string.
;;;

(require rackunit
         racket/file
         racket/port
         racket/string
         "../effect-executor.rkt"
         "../effect-ordering.rkt"
         "../effect-position.rkt"
         "../processes.rkt"
         "../propagator.rkt"
         "../sessions.rkt"
         "../session-lattice.rkt"
         "../session-runtime.rkt"
         "../syntax.rkt")


;; ========================================
;; Helpers
;; ========================================

(define (make-temp-with-content content)
  (define tmp (make-temporary-file))
  (call-with-output-file tmp
    (lambda (out) (write-string content out))
    #:exists 'truncate/replace)
  tmp)


;; ========================================
;; Group 1: count-io-channels
;; ========================================

(test-case "count-io-channels: proc-stop → 0"
  (check-equal? (count-io-channels (proc-stop)) 0))

(test-case "count-io-channels: single proc-open → 1"
  (define proc
    (proc-open (expr-string "/tmp/test")
               (sess-send (expr-String) (sess-end)) 'FsCap
               (proc-send (expr-string "data") 'ch (proc-stop))))
  (check-equal? (count-io-channels proc) 1))

(test-case "count-io-channels: proc-par with two proc-opens → 2"
  (define p1
    (proc-open (expr-string "/tmp/a")
               (sess-send (expr-String) (sess-end)) 'FsCap
               (proc-stop)))
  (define p2
    (proc-open (expr-string "/tmp/b")
               (sess-recv (expr-String) (sess-end)) 'FsCap
               (proc-stop)))
  (check-equal? (count-io-channels (proc-par p1 p2)) 2))

(test-case "count-io-channels: nested proc-new with no proc-open → 0"
  (define sess (sess-send (expr-Nat) (sess-end)))
  (define proc
    (proc-new sess
      (proc-par
        (proc-send (expr-nat-val 42) 'ch (proc-stop))
        (proc-recv 'ch #f (expr-Nat) (proc-stop)))))
  (check-equal? (count-io-channels proc) 0))

(test-case "count-io-channels: proc-case with proc-opens in branches"
  ;; Only the max branch count matters (branches are alternatives)
  (define proc
    (proc-case 'ch
      (list (cons ':a
              (proc-open (expr-string "/tmp/a")
                         (sess-end) 'FsCap (proc-stop)))
            (cons ':b (proc-stop)))))
  (check-equal? (count-io-channels proc) 1))


;; ========================================
;; Group 2: architecture-d-required?
;; ========================================

(test-case "architecture-d-required?: single IO channel → #f"
  ;; Single proc-open, no cross-channel data flow → A is sufficient
  (define proc
    (proc-open (expr-string "/tmp/test")
               (sess-send (expr-String) (sess-end)) 'FsCap
               (proc-send (expr-string "data") 'ch (proc-stop))))
  (check-false (architecture-d-required? proc)))

(test-case "architecture-d-required?: no IO channels → #f"
  ;; Pure process — no IO at all
  (define proc (proc-stop))
  (check-false (architecture-d-required? proc)))

(test-case "architecture-d-required?: two IO channels with no data flow → #f"
  ;; Two independent IO channels but no cross-channel data flow
  (define p1
    (proc-open (expr-string "/tmp/a")
               (sess-send (expr-String) (sess-end)) 'FsCap
               (proc-send (expr-string "a-data") 'ch (proc-stop))))
  (define p2
    (proc-open (expr-string "/tmp/b")
               (sess-send (expr-String) (sess-end)) 'FsCap
               (proc-send (expr-string "b-data") 'ch (proc-stop))))
  ;; Two opens in parallel, but no data flow between them
  (check-equal? (count-io-channels (proc-par p1 p2)) 2)
  ;; extract-data-flow-edges looks for cross-channel dependencies
  ;; No recv → send cross-channel dependency here
  (check-false (architecture-d-required? (proc-par p1 p2))))

(test-case "architecture-d-required?: two IO channels (Phase 0 limitation)"
  ;; Phase 0 limitation: all IO channels use the same name 'ch (from proc-open).
  ;; extract-data-flow-edges can't distinguish between different IO channels
  ;; with the same name, so cross-channel data flow is not detected.
  ;; Architecture D is not triggered (falls back to Architecture A).
  ;; This is correct for Phase 0 — unique channel naming is a future improvement.
  (define p1
    (proc-open (expr-string "/tmp/a")
               (sess-recv (expr-String) (sess-end)) 'FsCap
               (proc-recv 'ch 'x (expr-String)
                 (proc-open (expr-string "/tmp/b")
                            (sess-send (expr-String) (sess-end)) 'FsCap
                            (proc-send (expr-fvar 'x) 'ch (proc-stop))))))
  (check-equal? (count-io-channels p1) 2)
  ;; Phase 0: same-named channels → no cross-channel edges detected → #f
  (check-false (architecture-d-required? p1)))


;; ========================================
;; Group 3: rt-execute-process-auto
;; ========================================

(test-case "rt-execute-process-auto: auto selects A for single-channel"
  ;; Single IO channel → Architecture A
  (define tmp (make-temporary-file))
  (define sess (sess-send (expr-String) (sess-end)))
  (define proc
    (proc-open (expr-string (path->string tmp))
               sess 'FsCap
               (proc-send (expr-string "auto-a") 'ch (proc-stop))))
  (define result (rt-execute-process-auto proc sess))
  (check-equal? (rt-exec-result-status result) 'ok)
  (check-equal? (file->string tmp) "auto-a")
  (delete-file tmp))

(test-case "rt-execute-process-auto: explicit 'a forces Architecture A"
  (define tmp (make-temporary-file))
  (define sess (sess-send (expr-String) (sess-end)))
  (define proc
    (proc-open (expr-string (path->string tmp))
               sess 'FsCap
               (proc-send (expr-string "forced-a") 'ch (proc-stop))))
  (define result (rt-execute-process-auto proc sess #:architecture 'a))
  (check-equal? (rt-exec-result-status result) 'ok)
  (check-equal? (file->string tmp) "forced-a")
  (delete-file tmp))

(test-case "rt-execute-process-auto: explicit 'd forces Architecture D"
  (define tmp (make-temporary-file))
  (define sess (sess-send (expr-String) (sess-end)))
  (define proc
    (proc-open (expr-string (path->string tmp))
               sess 'FsCap
               (proc-send (expr-string "forced-d") 'ch (proc-stop))))
  (define result (rt-execute-process-auto proc sess #:architecture 'd))
  (check-equal? (rt-exec-result-status result) 'ok)
  (check-equal? (file->string tmp) "forced-d")
  (delete-file tmp))

(test-case "rt-execute-process-auto: auto selects A for pure process"
  (define proc (proc-stop))
  (define result (rt-execute-process-auto proc (sess-end)))
  (check-equal? (rt-exec-result-status result) 'ok))

(test-case "rt-execute-process-auto: A and D produce same result for single channel"
  ;; Shadow validation: both architectures should produce identical file output
  (define tmp-a (make-temporary-file))
  (define tmp-d (make-temporary-file))
  (define sess (sess-send (expr-String) (sess-end)))
  (define (make-proc path)
    (proc-open (expr-string path)
               sess 'FsCap
               (proc-send (expr-string "shadow-test") 'ch (proc-stop))))
  (define result-a (rt-execute-process-auto (make-proc (path->string tmp-a)) sess
                     #:architecture 'a))
  (define result-d (rt-execute-process-auto (make-proc (path->string tmp-d)) sess
                     #:architecture 'd))
  (check-equal? (rt-exec-result-status result-a) 'ok)
  (check-equal? (rt-exec-result-status result-d) 'ok)
  ;; Both should produce the same file content
  (check-equal? (file->string tmp-a) (file->string tmp-d))
  (check-equal? (file->string tmp-a) "shadow-test")
  (delete-file tmp-a)
  (delete-file tmp-d))


;; ========================================
;; Group 4: AD-F3 — Concurrent Hooks
;; ========================================

(test-case "AD-F3: default-effect-executor works as sequential executor"
  ;; default-effect-executor delegates to execute-effects-and-propagate
  (define tmp (make-temp-with-content "hook-test-data"))
  (define rnet0 (make-runtime-network))
  (define sess (sess-recv (expr-String) (sess-end)))
  (define-values (rnet1 pair) (rt-new-channel-pair rnet0 sess))
  (define ep-a (channel-pair-ep-a pair))
  (define channel-eps (hasheq 'ch ep-a))
  (define effs
    (list (eff-open 'ch (eff-pos 'ch 0) (path->string tmp) 'read)
          (eff-read 'ch (eff-pos 'ch 1))
          (eff-close 'ch (eff-pos 'ch 2))))
  (define-values (rnet* results) (default-effect-executor rnet1 effs channel-eps))
  ;; Read result should be the file content
  (check-equal? (hash-ref results (eff-pos 'ch 1)) "hook-test-data")
  (delete-file tmp))

(test-case "AD-F3: concurrent-effect-executor raises error (not yet implemented)"
  (define rnet (make-runtime-network))
  (check-exn
    (lambda (e)
      (and (exn:fail? e)
           (string-contains? (exn-message e) "S8b concurrent runtime not yet implemented")))
    (lambda ()
      (concurrent-effect-executor rnet '() (hasheq)))))

(test-case "AD-F3: current-effect-executor parameter defaults to #f"
  ;; The parameter exists but defaults to #f (not yet wired)
  (check-false (current-effect-executor)))

(test-case "AD-F3: current-effect-executor can be parameterized"
  ;; Verify the parameter can be set to the default executor
  (parameterize ([current-effect-executor default-effect-executor])
    (check-equal? (current-effect-executor) default-effect-executor)))

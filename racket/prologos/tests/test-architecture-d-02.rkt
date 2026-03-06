#lang racket/base

;;;
;;; test-architecture-d-02.rkt — AD-F1: ATMS Branching Tests
;;;
;;; Tests the Phase 0 simplified ATMS branching: when collecting effects
;;; in Architecture D mode, proc-case only collects effects from the
;;; active branch (the one matching the resolved choice cell).
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
;; Group 1: AD-F1 — Branching with Effect Collection (Full Pipeline)
;; ========================================

;; Internal channel session: Choice { :wr → End, :sk → End }
;; The IO operations happen on a separate IO channel (from proc-open),
;; not on the internal channel. The internal channel only carries the
;; branch selection label.

(test-case "AD-F1: proc-case with resolved choice collects only active branch effects"
  ;; p1 (selector) selects :write-branch on internal channel, then stops.
  ;; p2 (offerer) offers two branches on internal channel:
  ;;   :write-branch → open file, send "chosen", close
  ;;   :skip-branch → open file, send "skipped", close
  ;; Only the :write-branch effects should be collected and executed.
  (define tmp (make-temporary-file))
  (define io-sess (sess-send (expr-String) (sess-end)))
  ;; Internal channel: branches go to End (IO is on a separate channel)
  (define branch-sess (sess-choice
                        (list (cons ':write-branch (sess-end))
                              (cons ':skip-branch (sess-end)))))
  ;; Selector: pick :write-branch, then stop
  (define p1 (proc-sel 'ch ':write-branch (proc-stop)))
  ;; Offerer: two branches, each opens a file and writes on IO channel 'ch
  ;; (proc-open rebinds 'ch to the IO channel, shadowing the internal channel)
  (define p2-write
    (proc-open (expr-string (path->string tmp))
               io-sess 'FsCap
               (proc-send (expr-string "chosen") 'ch (proc-stop))))
  (define p2-skip
    (proc-open (expr-string (path->string tmp))
               io-sess 'FsCap
               (proc-send (expr-string "skipped") 'ch (proc-stop))))
  (define p2 (proc-case 'ch
               (list (cons ':write-branch p2-write)
                     (cons ':skip-branch p2-skip))))
  (define proc (proc-new branch-sess (proc-par p1 p2)))
  ;; Execute with Architecture D
  (define result (rt-execute-process-d proc (sess-end)))
  (check-equal? (rt-exec-result-status result) 'ok)
  ;; File should have "chosen", not "skipped"
  (check-equal? (file->string tmp) "chosen")
  (delete-file tmp))

(test-case "AD-F1: proc-case with unresolved choice falls back to all branches"
  ;; When the choice cell is not yet resolved (choice-bot), all branches
  ;; should be compiled. This is a safety fallback that shouldn't happen
  ;; in Phase 0 (left-to-right walk guarantees resolution), but we test it.
  (define sess (sess-offer (list (cons ':a (sess-end))
                                 (cons ':b (sess-end)))))
  (define proc (proc-case 'self
                 (list (cons ':a (proc-stop))
                       (cons ':b (proc-stop)))))
  ;; Manually compile with effect collection but choice-bot (no prior sel)
  (define rnet0 (make-runtime-network))
  (define-values (rnet1 pair) (rt-new-channel-pair rnet0 sess))
  (define ep-a (channel-pair-ep-a pair))
  (define ep-b (channel-pair-ep-b pair))
  (define rnet2 (rt-cross-wire-choice rnet1 ep-a ep-b))
  ;; Don't write anything to choice cell — it stays at choice-bot
  (define channel-eps (hasheq 'self ep-a))
  (define-values (rnet3 bindings trace)
    (compile-live-process rnet2 proc channel-eps (hasheq) (hasheq)
                          #:collect-effects? #t))
  ;; With choice-bot and no IO operations, there are no effects to collect,
  ;; but the compilation should complete without error.
  (define rnet4 (rt-run-to-quiescence rnet3))
  ;; No contradiction — both branches compiled successfully
  (check-false (rt-contradiction? rnet4)))

(test-case "AD-F1: active branch effects execute, inactive branch effects don't"
  ;; Two branches: :alpha writes "alpha-data", :beta writes "beta-data"
  ;; Select :alpha — only "alpha-data" should appear in the file.
  (define tmp (make-temporary-file))
  (define io-sess (sess-send (expr-String) (sess-end)))
  (define branch-sess (sess-choice
                        (list (cons ':alpha (sess-end))
                              (cons ':beta (sess-end)))))
  (define p1 (proc-sel 'ch ':alpha (proc-stop)))
  (define p2-alpha
    (proc-open (expr-string (path->string tmp))
               io-sess 'FsCap
               (proc-send (expr-string "alpha-data") 'ch (proc-stop))))
  (define p2-beta
    (proc-open (expr-string (path->string tmp))
               io-sess 'FsCap
               (proc-send (expr-string "beta-data") 'ch (proc-stop))))
  (define p2 (proc-case 'ch
               (list (cons ':alpha p2-alpha)
                     (cons ':beta p2-beta))))
  (define proc (proc-new branch-sess (proc-par p1 p2)))
  (define result (rt-execute-process-d proc (sess-end)))
  (check-equal? (rt-exec-result-status result) 'ok)
  (check-equal? (file->string tmp) "alpha-data")
  (delete-file tmp))

(test-case "AD-F1: branching with recv in active branch"
  ;; Select :read-branch, which reads from a file.
  ;; The inactive :noop-branch just stops.
  (define tmp (make-temp-with-content "branch-read-data"))
  (define io-sess (sess-recv (expr-String) (sess-end)))
  (define branch-sess (sess-choice
                        (list (cons ':read-branch (sess-end))
                              (cons ':noop-branch (sess-end)))))
  (define p1 (proc-sel 'ch ':read-branch (proc-stop)))
  (define p2-read
    (proc-open (expr-string (path->string tmp))
               io-sess 'FsCap
               (proc-recv 'ch #f (expr-String) (proc-stop))))
  (define p2-noop (proc-stop))
  (define p2 (proc-case 'ch
               (list (cons ':read-branch p2-read)
                     (cons ':noop-branch p2-noop))))
  (define proc (proc-new branch-sess (proc-par p1 p2)))
  (define result (rt-execute-process-d proc (sess-end)))
  (check-equal? (rt-exec-result-status result) 'ok)
  ;; Effect results should contain the read data
  (define bindings (rt-exec-result-bindings result))
  (check-true (hash-has-key? bindings '__effect_results))
  (define effect-results (hash-ref bindings '__effect_results))
  (define read-values
    (for/list ([(pos val) (in-hash effect-results)]
               #:when (string? val))
      val))
  (check-not-false (member "branch-read-data" read-values) "should read from active branch")
  (delete-file tmp))

(test-case "AD-F1: non-collection mode still compiles all branches"
  ;; In non-collection mode (Architecture A), all branches should be compiled.
  ;; This verifies AD-F1 doesn't break Architecture A behavior.
  (define sess (sess-choice (list (cons ':a (sess-end))
                                   (cons ':b (sess-end)))))
  (define p1 (proc-sel 'ch ':a (proc-stop)))
  (define p2 (proc-case 'ch
               (list (cons ':a (proc-stop))
                     (cons ':b (proc-stop)))))
  (define proc (proc-new sess (proc-par p1 p2)))
  ;; Architecture A (default)
  (define result (rt-execute-process proc (sess-end)))
  (check-equal? (rt-exec-result-status result) 'ok))


;; ========================================
;; Group 2: Effect Count Verification
;; ========================================

(test-case "AD-F1: only active branch effects in accumulator"
  ;; Compile with effect collection and verify effect count.
  ;; :write-branch produces 3 effects (open, write, close).
  ;; :noop-branch produces 0 effects.
  ;; With AD-F1, only 3 effects should be collected when :write-branch is active.
  (define tmp (make-temporary-file))
  (define io-sess (sess-send (expr-String) (sess-end)))
  (define branch-sess (sess-choice
                        (list (cons ':write-branch (sess-end))
                              (cons ':noop-branch (sess-end)))))
  ;; Build a runtime network manually for inspection
  (define rnet0 (make-runtime-network))
  ;; Create self channel
  (define-values (rnet1 self-pair) (rt-new-channel-pair rnet0 (sess-end)))
  (define self-ep-a (channel-pair-ep-a self-pair))
  (define self-ep-b (channel-pair-ep-b self-pair))
  (define rnet2 (rt-cross-wire-choice rnet1 self-ep-a self-ep-b))
  (define rnet3 (rt-register-channel rnet2 'self self-ep-a))
  ;; Create the full process
  (define p1 (proc-sel 'ch ':write-branch (proc-stop)))
  (define p2-write
    (proc-open (expr-string (path->string tmp))
               io-sess 'FsCap
               (proc-send (expr-string "data") 'ch (proc-stop))))
  (define p2-noop (proc-stop))
  (define p2 (proc-case 'ch
               (list (cons ':write-branch p2-write)
                     (cons ':noop-branch p2-noop))))
  (define proc (proc-new branch-sess (proc-par p1 p2)))
  ;; Compile with effect collection
  (define channel-eps (hasheq 'self self-ep-a))
  (define-values (rnet4 bindings trace)
    (compile-live-process rnet3 proc channel-eps (hasheq) (hasheq)
                          #:collect-effects? #t))
  ;; Extract collected effects
  (define effects (effect-set-effects (get-effect-acc bindings)))
  ;; Should have exactly 3 effects: open, write, close (from active branch only)
  (check-equal? (length effects) 3
    "should collect 3 effects from active branch only")
  (delete-file tmp))

(test-case "AD-F1: selecting noop branch produces 0 effects"
  ;; With AD-F1, selecting :noop-branch should produce 0 IO effects.
  (define tmp (make-temporary-file))
  (define io-sess (sess-send (expr-String) (sess-end)))
  (define branch-sess (sess-choice
                        (list (cons ':write-branch (sess-end))
                              (cons ':noop-branch (sess-end)))))
  (define rnet0 (make-runtime-network))
  (define-values (rnet1 self-pair) (rt-new-channel-pair rnet0 (sess-end)))
  (define self-ep-a (channel-pair-ep-a self-pair))
  (define self-ep-b (channel-pair-ep-b self-pair))
  (define rnet2 (rt-cross-wire-choice rnet1 self-ep-a self-ep-b))
  (define rnet3 (rt-register-channel rnet2 'self self-ep-a))
  ;; Select :noop-branch — should produce no IO effects
  (define p1 (proc-sel 'ch ':noop-branch (proc-stop)))
  (define p2-write
    (proc-open (expr-string (path->string tmp))
               io-sess 'FsCap
               (proc-send (expr-string "data") 'ch (proc-stop))))
  (define p2-noop (proc-stop))
  (define p2 (proc-case 'ch
               (list (cons ':write-branch p2-write)
                     (cons ':noop-branch p2-noop))))
  (define proc (proc-new branch-sess (proc-par p1 p2)))
  (define channel-eps (hasheq 'self self-ep-a))
  (define-values (rnet4 bindings trace)
    (compile-live-process rnet3 proc channel-eps (hasheq) (hasheq)
                          #:collect-effects? #t))
  (define effects (effect-set-effects (get-effect-acc bindings)))
  ;; :noop-branch has no IO operations → 0 effects
  (check-equal? (length effects) 0
    "noop branch should produce 0 effects")
  (delete-file tmp))

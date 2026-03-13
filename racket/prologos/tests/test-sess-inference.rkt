#lang racket/base

;;;
;;; Tests for Sprint 8: Session Type Continuation Inference
;;;
;;; Tests the sess-meta struct, sess-meta store, unify-session,
;;; zonk-session, and integration with type-proc for inferred continuations.
;;;

(require rackunit
         "../prelude.rkt"
         "../syntax.rkt"
         "../substitution.rkt"
         "../sessions.rkt"
         "../processes.rkt"
         "../metavar-store.rkt"
         (except-in "../typing-core.rkt" check)
         "../typing-sessions.rkt"
         "../driver.rkt")

;; Helper to build channel contexts from pairs
(define (make-chan-ctx . pairs)
  (for/fold ([ctx chan-ctx-empty])
            ([p (in-list pairs)])
    (chan-ctx-add ctx (car p) (cdr p))))

;; ========================================
;; Unit tests: sess-meta infrastructure
;; ========================================

(test-case "sess-meta/fresh-creates-unsolved"
  (with-fresh-meta-env
    (define sm (fresh-sess-meta "test"))
    (check-true (sess-meta? sm))
    (check-false (sess-meta-solved? (sess-meta-id sm)))))

(test-case "sess-meta/solve-and-retrieve"
  (with-fresh-meta-env
    (define sm (fresh-sess-meta "test"))
    (define id (sess-meta-id sm))
    (solve-sess-meta! id (sess-end))
    (check-true (sess-meta-solved? id))
    (check-equal? (sess-meta-solution id) (sess-end))))

(test-case "sess-meta/solve-with-send"
  (with-fresh-meta-env
    (define sm (fresh-sess-meta "test"))
    (define id (sess-meta-id sm))
    (define expected (sess-send (expr-Nat) (sess-end)))
    (solve-sess-meta! id expected)
    (check-equal? (sess-meta-solution id) expected)))

;; ========================================
;; Unit tests: zonk-session
;; ========================================

(test-case "zonk-session/follows-solved"
  (with-fresh-meta-env
    (define sm (fresh-sess-meta "test"))
    (solve-sess-meta! (sess-meta-id sm) (sess-end))
    (check-equal? (zonk-session sm) (sess-end))))

(test-case "zonk-session/preserves-unsolved"
  (with-fresh-meta-env
    (define sm (fresh-sess-meta "test"))
    (check-true (sess-meta? (zonk-session sm)))))

(test-case "zonk-session-default/defaults-unsolved-to-end"
  (with-fresh-meta-env
    (define sm (fresh-sess-meta "test"))
    (check-equal? (zonk-session-default sm) (sess-end))))

(test-case "zonk-session/transitive"
  (with-fresh-meta-env
    (define sm1 (fresh-sess-meta "a"))
    (define sm2 (fresh-sess-meta "b"))
    (solve-sess-meta! (sess-meta-id sm1) sm2)
    (solve-sess-meta! (sess-meta-id sm2) (sess-send (expr-Nat) (sess-end)))
    (check-equal? (zonk-session sm1) (sess-send (expr-Nat) (sess-end)))))

(test-case "zonk-session/concrete-passthrough"
  (check-equal? (zonk-session (sess-end)) (sess-end))
  (check-equal? (zonk-session (sess-send (expr-Nat) (sess-end)))
                (sess-send (expr-Nat) (sess-end))))

(test-case "zonk-session/nested-meta-in-continuation"
  (with-fresh-meta-env
    (define sm (fresh-sess-meta "cont"))
    (solve-sess-meta! (sess-meta-id sm) (sess-recv (expr-Bool) (sess-end)))
    (define session (sess-send (expr-Nat) sm))
    (check-equal? (zonk-session session)
                  (sess-send (expr-Nat) (sess-recv (expr-Bool) (sess-end))))))

;; ========================================
;; Unit tests: unify-session
;; ========================================

(test-case "unify-session/meta-vs-concrete"
  (with-fresh-meta-env
    (define sm (fresh-sess-meta "test"))
    (define concrete (sess-send (expr-Nat) (sess-end)))
    (check-equal? (unify-session sm concrete) #t)
    (check-true (sess-meta-solved? (sess-meta-id sm)))
    (check-equal? (sess-meta-solution (sess-meta-id sm)) concrete)))

(test-case "unify-session/two-metas"
  (with-fresh-meta-env
    (define sm1 (fresh-sess-meta "a"))
    (define sm2 (fresh-sess-meta "b"))
    (check-equal? (unify-session sm1 sm2) #t)
    ;; One should be solved to the other
    (check-true (sess-meta-solved? (sess-meta-id sm1)))))

(test-case "unify-session/ground-match"
  (with-fresh-meta-env
    (check-equal? (unify-session
                   (sess-send (expr-Nat) (sess-end))
                   (sess-send (expr-Nat) (sess-end)))
                  #t)))

(test-case "unify-session/ground-mismatch"
  (with-fresh-meta-env
    (check-equal? (unify-session
                   (sess-send (expr-Nat) (sess-end))
                   (sess-recv (expr-Nat) (sess-end)))
                  #f)))

(test-case "unify-session/structural-with-meta-cont"
  (with-fresh-meta-env
    (define sm (fresh-sess-meta "cont"))
    (check-equal? (unify-session
                   (sess-send (expr-Nat) sm)
                   (sess-send (expr-Nat) (sess-recv (expr-Bool) (sess-end))))
                  #t)
    (check-equal? (sess-meta-solution (sess-meta-id sm))
                  (sess-recv (expr-Bool) (sess-end)))))

;; ========================================
;; Unit tests: session operations with sess-meta
;; ========================================

(test-case "dual/sess-meta-passthrough"
  (with-fresh-meta-env
    (define sm (fresh-sess-meta "test"))
    (check-true (sess-meta? (dual sm)))))

(test-case "substS/sess-meta-passthrough"
  (with-fresh-meta-env
    (define sm (fresh-sess-meta "test"))
    (check-true (sess-meta? (substS sm 0 (expr-zero))))))

;; ========================================
;; Integration tests: continuation inference via type-proc
;; ========================================

(test-case "sess-infer/send-with-meta-continuation"
  ;; ch :: (sess-send Nat ?S'), send zero, stop → ?S' = sess-end
  (with-fresh-meta-env
    (define cont-meta (fresh-sess-meta "cont"))
    (check-true
     (type-proc ctx-empty
                (make-chan-ctx (cons 'c (sess-send (expr-Nat) cont-meta)))
                (proc-send (expr-zero) 'c (proc-stop))))
    (check-equal? (zonk-session cont-meta) (sess-end))))

(test-case "sess-infer/send-then-recv-with-meta-continuation"
  ;; ch :: (sess-send Nat ?S'), send zero, recv Bool, stop → ?S' = (sess-recv Bool sess-end)
  (with-fresh-meta-env
    (define cont-meta (fresh-sess-meta "cont"))
    (check-true
     (type-proc ctx-empty
                (make-chan-ctx (cons 'c (sess-send (expr-Nat) cont-meta)))
                (proc-send (expr-zero) 'c
                  (proc-recv 'c #f (expr-Bool) (proc-stop)))))
    (check-equal? (zonk-session cont-meta)
                  (sess-recv (expr-Bool) (sess-end)))))

(test-case "sess-infer/full-meta-channel-send-stop"
  ;; ch :: ?S, send zero, stop → ?S = (sess-send Nat sess-end)
  (with-fresh-meta-env
    (define ch-meta (fresh-sess-meta "ch"))
    (check-true
     (type-proc ctx-empty
                (make-chan-ctx (cons 'c ch-meta))
                (proc-send (expr-zero) 'c (proc-stop))))
    (check-equal? (zonk-session ch-meta)
                  (sess-send (expr-Nat) (sess-end)))))

(test-case "sess-infer/full-meta-send-then-recv"
  ;; ch :: ?S, send zero, recv Bool, stop → ?S = (sess-send Nat (sess-recv Bool sess-end))
  (with-fresh-meta-env
    (define ch-meta (fresh-sess-meta "ch"))
    (check-true
     (type-proc ctx-empty
                (make-chan-ctx (cons 'c ch-meta))
                (proc-send (expr-zero) 'c
                  (proc-recv 'c #f (expr-Bool) (proc-stop)))))
    (check-equal? (zonk-session ch-meta)
                  (sess-send (expr-Nat) (sess-recv (expr-Bool) (sess-end))))))

(test-case "sess-infer/select-with-meta"
  ;; ch :: ?S, select ping, send zero, stop → ?S solved to choice
  (with-fresh-meta-env
    (define ch-meta (fresh-sess-meta "ch"))
    (check-true
     (type-proc ctx-empty
                (make-chan-ctx (cons 'c ch-meta))
                (proc-sel 'c 'ping
                  (proc-send (expr-zero) 'c (proc-stop)))))
    ;; Verify the sess-meta was solved to a choice
    (define solved (zonk-session ch-meta))
    (check-true (sess-choice? solved))
    ;; The ping branch should be (sess-send Nat sess-end)
    (define branches (sess-choice-branches solved))
    (check-equal? (length branches) 1)
    (check-equal? (caar branches) 'ping)
    (check-equal? (zonk-session (cdar branches))
                  (sess-send (expr-Nat) (sess-end)))))

(test-case "sess-infer/case-offer-with-meta"
  ;; ch :: ?S, case {ping → recv Nat stop, quit → stop} → ?S solved to offer
  (with-fresh-meta-env
    (define ch-meta (fresh-sess-meta "ch"))
    (check-true
     (type-proc ctx-empty
                (make-chan-ctx (cons 'c ch-meta))
                (proc-case 'c
                  (list (cons 'ping (proc-recv 'c #f (expr-Nat) (proc-stop)))
                        (cons 'quit (proc-stop))))))
    ;; Verify the sess-meta was solved to an offer
    (define solved (zonk-session ch-meta))
    (check-true (sess-offer? solved))))

(test-case "sess-infer/link-with-meta"
  ;; c1 :: ?S, c2 :: (sess-recv Nat sess-end) → ?S = (sess-send Nat sess-end)
  (with-fresh-meta-env
    (define ch-meta (fresh-sess-meta "ch"))
    (check-true
     (type-proc ctx-empty
                (make-chan-ctx (cons 'c1 ch-meta)
                              (cons 'c2 (sess-recv (expr-Nat) (sess-end))))
                (proc-link 'c1 'c2)))
    ;; ?S should be dual of (sess-recv Nat sess-end) = (sess-send Nat sess-end)
    (check-equal? (zonk-session ch-meta)
                  (sess-send (expr-Nat) (sess-end)))))

;; ========================================
;; Sprint 8b: Dependent continuation inference
;; ========================================

(test-case "sess-infer/dependent-send-with-meta-continuation"
  ;; ch :: (sess-dsend Nat ?S'), send 2, then send Vec(Nat, 2), stop
  ;; After substS, ?S' should be solved
  (with-fresh-meta-env
    (define cont-meta (fresh-sess-meta "dep-cont"))
    ;; Protocol: !(x:Nat). ?S'
    ;; After sending 2: substS(?S', 0, 2)
    ;; The continuation ?S' should be solved to (sess-send Vec(Nat, bvar(0)) sess-end)
    ;; After substS: (sess-send Vec(Nat, 2) sess-end)
    ;;
    ;; For this test, use a simpler version: dsend Nat then meta continuation
    ;; Process: send 2, send zero (as Nat), stop
    (check-true
     (type-proc ctx-empty
                (make-chan-ctx (cons 'c (sess-dsend (expr-Nat) cont-meta)))
                (proc-send (expr-suc (expr-suc (expr-zero))) 'c
                  (proc-send (expr-zero) 'c (proc-stop)))))
    ;; The sess-meta was passed through substS and then the next send resolved it
    (define solved (zonk-session cont-meta))
    ;; After substS(cont-meta, 0, 2) = cont-meta (passthrough),
    ;; then process sends zero on c, so cont-meta is solved to (sess-send Nat sess-end)
    (check-equal? solved (sess-send (expr-Nat) (sess-end)))))

;; ========================================
;; Negative tests
;; ========================================

(test-case "NEGATIVE: sess-infer/send-wrong-type-with-meta-cont"
  ;; ch :: (sess-send Nat ?S'), send true → type check fails (true is Bool, not Nat)
  (with-fresh-meta-env
    (define cont-meta (fresh-sess-meta "cont"))
    (check-false
     (type-proc ctx-empty
                (make-chan-ctx (cons 'c (sess-send (expr-Nat) cont-meta)))
                (proc-send (expr-true) 'c (proc-stop))))))

(test-case "NEGATIVE: sess-infer/recv-when-session-expects-send"
  ;; ch :: (sess-send Nat sess-end), recv → session shape mismatch
  (with-fresh-meta-env
    (check-false
     (type-proc ctx-empty
                (make-chan-ctx (cons 'c (sess-send (expr-Nat) (sess-end))))
                (proc-recv 'c #f (expr-Nat) (proc-stop))))))

;; ========================================
;; Regression: existing concrete session tests still work
;; ========================================

(test-case "regression/concrete-send-still-works"
  (with-fresh-meta-env
    (check-true
     (type-proc ctx-empty
                (make-chan-ctx (cons 'c (sess-send (expr-Nat) (sess-end))))
                (proc-send (expr-zero) 'c (proc-stop))))))

(test-case "regression/concrete-recv-still-works"
  (with-fresh-meta-env
    (check-true
     (type-proc ctx-empty
                (make-chan-ctx (cons 'c (sess-recv (expr-Nat) (sess-end))))
                (proc-recv 'c #f (expr-Nat) (proc-stop))))))

(test-case "regression/concrete-link-still-works"
  (with-fresh-meta-env
    (check-true
     (type-proc ctx-empty
                (make-chan-ctx (cons 'c1 (sess-send (expr-Nat) (sess-end)))
                              (cons 'c2 (sess-recv (expr-Nat) (sess-end))))
                (proc-link 'c1 'c2)))))

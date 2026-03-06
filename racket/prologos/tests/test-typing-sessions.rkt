#lang racket/base

;;;
;;; Tests for typing-sessions.rkt — Port of test-0g.maude (process typing subset)
;;;

(require rackunit
         "../prelude.rkt"
         "../syntax.rkt"
         "../substitution.rkt"
         "../reduction.rkt"
         "../sessions.rkt"
         "../processes.rkt"
         "../typing-sessions.rkt")

;; Helper to build channel contexts from pairs
(define (make-chan-ctx . pairs)
  (for/fold ([ctx chan-ctx-empty])
            ([p (in-list pairs)])
    (chan-ctx-add ctx (car p) (cdr p))))

;; ========================================
;; Process typing: simple send
;; ========================================

(test-case "type-proc: send zero on c :: send(Nat, endS)"
  (check-true
   (type-proc ctx-empty
              (make-chan-ctx (cons 'c (sess-send (expr-Nat) (sess-end))))
              (proc-send (expr-zero) 'c (proc-stop)))))

(test-case "NEGATIVE: send true on c :: send(Nat, endS)"
  (check-false
   (type-proc ctx-empty
              (make-chan-ctx (cons 'c (sess-send (expr-Nat) (sess-end))))
              (proc-send (expr-true) 'c (proc-stop)))))

;; ========================================
;; Process typing: simple recv
;; ========================================

(test-case "type-proc: recv on c :: recv(Nat, endS)"
  (check-true
   (type-proc ctx-empty
              (make-chan-ctx (cons 'c (sess-recv (expr-Nat) (sess-end))))
              (proc-recv 'c #f (expr-Nat) (proc-stop)))))

;; ========================================
;; Process typing: send then recv
;; ========================================

(test-case "type-proc: send-then-recv"
  (check-true
   (type-proc ctx-empty
              (make-chan-ctx (cons 'c (sess-send (expr-Nat) (sess-recv (expr-Bool) (sess-end)))))
              (proc-send (expr-zero) 'c (proc-recv 'c #f (expr-Bool) (proc-stop))))))

;; ========================================
;; Process typing: dependent send
;; ========================================

(test-case "type-proc: dependent send with Vec"
  ;; c :: dsend(Nat, send(Vec(Nat, bvar(0)), endS))
  ;; Send 2, then send a Vec(Nat, 2), then stop
  (check-true
   (type-proc ctx-empty
              (make-chan-ctx (cons 'c (sess-dsend (expr-Nat)
                                        (sess-send (expr-Vec (expr-Nat) (expr-bvar 0)) (sess-end)))))
              (proc-send (expr-suc (expr-suc (expr-zero))) 'c
                (proc-send (expr-ann (expr-vcons (expr-Nat) (expr-suc (expr-zero)) (expr-zero)
                                       (expr-vcons (expr-Nat) (expr-zero) (expr-suc (expr-zero))
                                                   (expr-vnil (expr-Nat))))
                                     (expr-Vec (expr-Nat) (expr-suc (expr-suc (expr-zero)))))
                           'c (proc-stop))))))

;; ========================================
;; Process typing: select
;; ========================================

(define choice-session
  (sess-choice (list (cons 'ping (sess-send (expr-Nat) (sess-end)))
                     (cons 'quit (sess-end)))))

(test-case "type-proc: select ping, then send"
  (check-true
   (type-proc ctx-empty
              (make-chan-ctx (cons 'c choice-session))
              (proc-sel 'c 'ping (proc-send (expr-zero) 'c (proc-stop))))))

(test-case "type-proc: select quit, then stop"
  (check-true
   (type-proc ctx-empty
              (make-chan-ctx (cons 'c choice-session))
              (proc-sel 'c 'quit (proc-stop)))))

;; ========================================
;; Process typing: case/offer
;; ========================================

(test-case "type-proc: case/offer handling all branches"
  (check-true
   (type-proc ctx-empty
              (make-chan-ctx (cons 'c (sess-offer (list (cons 'ping (sess-recv (expr-Nat) (sess-end)))
                                                       (cons 'quit (sess-end))))))
              (proc-case 'c (list (cons 'ping (proc-recv 'c #f (expr-Nat) (proc-stop)))
                                  (cons 'quit (proc-stop)))))))

;; ========================================
;; Process typing: solve (axiomatic)
;; ========================================

(test-case "type-proc: solve for Nat, then send on c"
  (check-true
   (type-proc ctx-empty
              (make-chan-ctx (cons 'c (sess-send (expr-Nat) (sess-end))))
              (proc-solve (expr-Nat) (proc-send (expr-bvar 0) 'c (proc-stop))))))

;; ========================================
;; Process typing: link
;; ========================================

(test-case "type-proc: link c1 c2 with dual sessions"
  (check-true
   (type-proc ctx-empty
              (make-chan-ctx (cons 'c1 (sess-send (expr-Nat) (sess-end)))
                            (cons 'c2 (sess-recv (expr-Nat) (sess-end))))
              (proc-link 'c1 'c2))))

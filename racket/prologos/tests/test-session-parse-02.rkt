#lang racket/base

;;;
;;; Tests for WS-mode session desugaring (Phase S1d)
;;; Tests desugar-session-ws → then parse-string on the result.
;;;

(require rackunit
         "../surface-syntax.rkt"
         "../parser.rkt"
         "../macros.rkt"
         "../errors.rkt")

;; Helper: desugar WS datum then parse the sexp result
(define (desugar-and-parse datum)
  (define desugared (desugar-session-ws datum))
  ;; Convert desugared datum to string and parse
  (define s (format "~s" desugared))
  (parse-string s))

;; ========================================
;; Basic send/recv/end
;; ========================================

(test-case "ws session: ! String end → Send String End"
  (define r (desugar-and-parse '(session Greeting (! String) end)))
  (check-true (surf-session? r))
  (check-equal? (surf-session-name r) 'Greeting)
  (define body (surf-session-body r))
  (check-true (surf-sess-send? body))
  (check-true (surf-sess-end? (surf-sess-send-cont body))))

(test-case "ws session: ? Nat end → Recv Nat End"
  (define r (desugar-and-parse '(session Listen (? Nat) end)))
  (check-true (surf-session? r))
  (define body (surf-session-body r))
  (check-true (surf-sess-recv? body))
  (check-true (surf-sess-end? (surf-sess-recv-cont body))))

(test-case "ws session: ! String ? String end → Send String (Recv String End)"
  (define r (desugar-and-parse '(session Echo (! String) (? String) end)))
  (check-true (surf-session? r))
  (define body (surf-session-body r))
  (check-true (surf-sess-send? body))
  (define cont (surf-sess-send-cont body))
  (check-true (surf-sess-recv? cont))
  (check-true (surf-sess-end? (surf-sess-recv-cont cont))))

;; ========================================
;; Dependent send/recv
;; ========================================

(test-case "ws session: !: (n : Nat) end → DSend"
  (define r (desugar-and-parse '(session DepSend (!: (n : Nat)) end)))
  (check-true (surf-session? r))
  (define body (surf-session-body r))
  (check-true (surf-sess-dsend? body))
  (check-true (surf-sess-end? (surf-sess-dsend-cont body))))

(test-case "ws session: ?: (x : Bool) end → DRecv"
  (define r (desugar-and-parse '(session DepRecv (?: (x : Bool)) end)))
  (check-true (surf-session? r))
  (define body (surf-session-body r))
  (check-true (surf-sess-drecv? body))
  (check-true (surf-sess-end? (surf-sess-drecv-cont body))))

;; ========================================
;; Choice and Offer branches
;; ========================================

(test-case "ws session: +> with $pipe branches → Choice"
  ;; WS reader would produce: (+> ($pipe :inc (! Nat) end) ($pipe :done end))
  (define r (desugar-and-parse
    '(session Counter (+> ($pipe :inc (! Nat) end) ($pipe :done end)))))
  (check-true (surf-session? r))
  (define body (surf-session-body r))
  (check-true (surf-sess-choice? body))
  (define branches (surf-sess-choice-branches body))
  (check-equal? (length branches) 2)
  ;; First branch: :inc → Send Nat End
  (check-true (surf-sess-branch? (car branches)))
  ;; Label should be 'inc (keyword stripped)
  (define label1 (surf-sess-branch-label (car branches)))
  (check-true (or (eq? label1 ':inc) (eq? label1 'inc)))
  (check-true (surf-sess-send? (surf-sess-branch-cont (car branches))))
  ;; Second branch: :done → End
  (define label2 (surf-sess-branch-label (cadr branches)))
  (check-true (or (eq? label2 ':done) (eq? label2 'done))))

(test-case "ws session: &> with $pipe branches → Offer"
  (define r (desugar-and-parse
    '(session Server (&> ($pipe :get (! String) end) ($pipe :put (? String) end)))))
  (check-true (surf-session? r))
  (define body (surf-session-body r))
  (check-true (surf-sess-offer? body))
  (define branches (surf-sess-offer-branches body))
  (check-equal? (length branches) 2))

;; ========================================
;; Recursion
;; ========================================

(test-case "ws session: rec → anonymous Mu"
  (define r (desugar-and-parse
    '(session Loop rec (! Nat) (SVar Loop))))
  (check-true (surf-session? r))
  (define body (surf-session-body r))
  (check-true (surf-sess-rec? body))
  (check-false (surf-sess-rec-label body)))

(test-case "ws session: (rec Label) → named Mu"
  (define r (desugar-and-parse
    '(session Counter (rec Again) (! Nat) (SVar Again))))
  (check-true (surf-session? r))
  (define body (surf-session-body r))
  (check-true (surf-sess-rec? body))
  (check-equal? (surf-sess-rec-label body) 'Again))

;; ========================================
;; Shared
;; ========================================

(test-case "ws session: shared → Shared"
  (define r (desugar-and-parse
    '(session SharedSvc (shared rec (! Nat) (SVar SharedSvc)))))
  (check-true (surf-session? r))
  (define body (surf-session-body r))
  (check-true (surf-sess-shared? body)))

;; ========================================
;; Bare End
;; ========================================

(test-case "ws session: just end"
  (define r (desugar-and-parse '(session Empty end)))
  (check-true (surf-session? r))
  (check-true (surf-sess-end? (surf-session-body r))))

;; ========================================
;; Metadata
;; ========================================

(test-case "ws session: with :doc metadata"
  (define r (desugar-and-parse
    '(session Greeting :doc "A greeting" (! String) end)))
  (check-true (surf-session? r))
  (check-equal? (length (surf-session-metadata r)) 1)
  (check-true (surf-sess-send? (surf-session-body r))))

;; ========================================
;; Desugaring unit tests (datum → datum)
;; ========================================

(test-case "desugar: basic send/end"
  (define result (desugar-session-ws '(session Foo (! String) end)))
  (check-equal? result '(session Foo (Send String End))))

(test-case "desugar: multi-step"
  (define result (desugar-session-ws '(session Foo (! String) (? Nat) end)))
  (check-equal? result '(session Foo (Send String (Recv Nat End)))))

(test-case "desugar: implicit End"
  ;; If no explicit end, should still produce End
  (define result (desugar-session-ws '(session Foo (! String))))
  (check-equal? result '(session Foo (Send String End))))

(test-case "desugar: choice branches"
  (define result (desugar-session-ws
    '(session Foo (+> ($pipe :a end) ($pipe :b end)))))
  (check-equal? result '(session Foo (Choice ((:a End) (:b End))))))

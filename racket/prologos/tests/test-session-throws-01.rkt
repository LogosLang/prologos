#lang racket/base

;;;
;;; Tests for :throws desugaring (Phase S3c)
;;; Validates that (session Name :throws ErrorType Body) desugars each
;;; protocol step into (sess-offer ((:ok step) (:error (sess-send ErrorType (sess-end))))).
;;;

(require rackunit
         racket/list
         racket/string
         "../driver.rkt"
         "../errors.rkt"
         "../sessions.rkt"
         "../macros.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../metavar-store.rkt")

;; Helper: run through pipeline, return last result string
(define (run s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-session-registry (hasheq)]
                 [current-module-registry (hasheq)]
                 [current-mult-meta-store (make-hasheq)])
    (define results (process-string s))
    (if (list? results)
        (last results)
        results)))

;; Helper: run through pipeline, return the session-entry from the registry
(define (run-get-session s name)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-session-registry (hasheq)]
                 [current-module-registry (hasheq)]
                 [current-mult-meta-store (make-hasheq)])
    (process-string s)
    (lookup-session name)))

;; ========================================
;; Basic :throws wrapping
;; ========================================

(test-case "throws: session with :throws defines successfully"
  (check-equal? (run "(session S :throws String (Send Nat End))")
                "session S defined."))

(test-case "throws: Send wrapped in sess-offer with :ok/:error"
  (define entry (run-get-session "(session S :throws String (Send Nat End))" 'S))
  (check-true (session-entry? entry))
  (define st (session-entry-session-type entry))
  ;; Should be (sess-offer ((:ok (sess-send Nat (sess-end))) (:error (sess-send String (sess-end)))))
  (check-true (sess-offer? st))
  (define branches (sess-offer-branches st))
  (check-equal? (length branches) 2)
  ;; :ok branch
  (define ok-branch (assq ':ok branches))
  (check-true (pair? ok-branch))
  (check-true (sess-send? (cdr ok-branch)))
  ;; :error branch
  (define err-branch (assq ':error branches))
  (check-true (pair? err-branch))
  (check-true (sess-send? (cdr err-branch)))
  ;; Error branch sends the error type then ends
  (check-true (sess-end? (sess-send-cont (cdr err-branch)))))

(test-case "throws: Recv wrapped in sess-offer"
  (define entry (run-get-session "(session S :throws String (Recv Nat End))" 'S))
  (define st (session-entry-session-type entry))
  (check-true (sess-offer? st))
  (define ok-branch (assq ':ok (sess-offer-branches st)))
  (check-true (sess-recv? (cdr ok-branch))))

(test-case "throws: multi-step wraps each step"
  (define entry (run-get-session "(session S :throws String (Send Nat (Recv Bool End)))" 'S))
  (define st (session-entry-session-type entry))
  ;; Top-level: offer wrapping the Send
  (check-true (sess-offer? st))
  (define ok1 (cdr (assq ':ok (sess-offer-branches st))))
  ;; ok1 is (sess-send Nat cont)
  (check-true (sess-send? ok1))
  (define cont (sess-send-cont ok1))
  ;; Continuation is another offer wrapping the Recv
  (check-true (sess-offer? cont))
  (define ok2 (cdr (assq ':ok (sess-offer-branches cont))))
  (check-true (sess-recv? ok2))
  ;; Terminal End is NOT wrapped (it's a terminal, not a protocol step)
  (check-true (sess-end? (sess-recv-cont ok2))))

(test-case "throws: End is NOT wrapped"
  (define entry (run-get-session "(session S :throws String End)" 'S))
  (define st (session-entry-session-type entry))
  ;; End has no wrapping — it's not a protocol interaction
  (check-true (sess-end? st)))

;; ========================================
;; :throws with choice/offer
;; ========================================

(test-case "throws: Choice branches get throws wrapping inside"
  (define entry (run-get-session
    "(session S :throws String (Choice ((a (Send Nat End)) (b End))))" 'S))
  (define st (session-entry-session-type entry))
  ;; Choice itself is NOT wrapped (it's branching, not a protocol step)
  (check-true (sess-choice? st))
  (define branches (sess-choice-branches st))
  ;; Branch 'a: should have offer wrapping on the Send inside
  (define a-branch (cdr (assq 'a branches)))
  (check-true (sess-offer? a-branch))
  (define a-ok (cdr (assq ':ok (sess-offer-branches a-branch))))
  (check-true (sess-send? a-ok))
  ;; Branch 'b: is End — not wrapped
  (define b-branch (cdr (assq 'b branches)))
  (check-true (sess-end? b-branch)))

;; ========================================
;; :throws with recursion
;; ========================================

(test-case "throws: Mu body gets throws wrapping"
  (define entry (run-get-session
    "(session Loop :throws String (Mu (Send Nat (SVar Loop))))" 'Loop))
  (define st (session-entry-session-type entry))
  ;; Top-level is Mu (recursion is structural, not a protocol step)
  (check-true (sess-mu? st))
  (define body (sess-mu-body st))
  ;; Body Send should be wrapped in offer
  (check-true (sess-offer? body))
  (define ok (cdr (assq ':ok (sess-offer-branches body))))
  (check-true (sess-send? ok)))

;; ========================================
;; :throws with dependent types
;; ========================================

(test-case "throws: DSend wrapped in offer"
  (define entry (run-get-session
    "(session S :throws String (DSend (n : Nat) End))" 'S))
  (define st (session-entry-session-type entry))
  (check-true (sess-offer? st))
  (define ok (cdr (assq ':ok (sess-offer-branches st))))
  (check-true (sess-dsend? ok)))

(test-case "throws: DRecv wrapped in offer"
  (define entry (run-get-session
    "(session S :throws String (DRecv (x : Bool) End))" 'S))
  (define st (session-entry-session-type entry))
  (check-true (sess-offer? st))
  (define ok (cdr (assq ':ok (sess-offer-branches st))))
  (check-true (sess-drecv? ok)))

;; ========================================
;; Without :throws — no wrapping (regression)
;; ========================================

(test-case "no-throws: session without :throws has no offer wrapping"
  (define entry (run-get-session "(session S (Send String End))" 'S))
  (define st (session-entry-session-type entry))
  ;; Should be plain (sess-send ...) — no offer wrapper
  (check-true (sess-send? st)))

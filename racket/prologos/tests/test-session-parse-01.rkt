#lang racket/base

;;;
;;; Tests for sexp-mode session type parsing (Phase S1c)
;;;

(require rackunit
         "../surface-syntax.rkt"
         "../parser.rkt"
         "../errors.rkt")

;; Helper: parse from string
(define (p s) (parse-string s))

;; ========================================
;; Basic session forms
;; ========================================

(test-case "session parse: Send/End"
  (define r (p "(session Greeting (Send String End))"))
  (check-true (surf-session? r))
  (check-equal? (surf-session-name r) 'Greeting)
  (check-equal? (surf-session-metadata r) '())
  (define body (surf-session-body r))
  (check-true (surf-sess-send? body))
  (check-true (surf-string-type? (surf-sess-send-type body)))
  (check-true (surf-sess-end? (surf-sess-send-cont body))))

(test-case "session parse: Recv/End"
  (define r (p "(session Listen (Recv Nat End))"))
  (check-true (surf-session? r))
  (check-equal? (surf-session-name r) 'Listen)
  (define body (surf-session-body r))
  (check-true (surf-sess-recv? body))
  ;; Nat is a keyword → surf-nat-type
  (check-true (surf-nat-type? (surf-sess-recv-type body)))
  (check-true (surf-sess-end? (surf-sess-recv-cont body))))

(test-case "session parse: multi-step Send/Recv/End"
  (define r (p "(session Greeting (Send String (Recv String End)))"))
  (check-true (surf-session? r))
  (define body (surf-session-body r))
  (check-true (surf-sess-send? body))
  (define cont (surf-sess-send-cont body))
  (check-true (surf-sess-recv? cont))
  (check-true (surf-sess-end? (surf-sess-recv-cont cont))))

;; ========================================
;; Dependent send/recv
;; ========================================

(test-case "session parse: DSend"
  (define r (p "(session DepSend (DSend (n : Nat) End))"))
  (check-true (surf-session? r))
  (define body (surf-session-body r))
  (check-true (surf-sess-dsend? body))
  (check-equal? (surf-sess-dsend-name body) 'n)
  (check-true (surf-nat-type? (surf-sess-dsend-type body)))
  (check-true (surf-sess-end? (surf-sess-dsend-cont body))))

(test-case "session parse: DRecv"
  (define r (p "(session DepRecv (DRecv (x : Bool) End))"))
  (check-true (surf-session? r))
  (define body (surf-session-body r))
  (check-true (surf-sess-drecv? body))
  (check-equal? (surf-sess-drecv-name body) 'x)
  (check-true (surf-bool-type? (surf-sess-drecv-type body)))
  (check-true (surf-sess-end? (surf-sess-drecv-cont body))))

;; ========================================
;; Choice and Offer branching
;; ========================================

(test-case "session parse: Choice with branches"
  (define r (p "(session Counter (Choice ((inc (Send Nat End)) (done End))))"))
  (check-true (surf-session? r))
  (define body (surf-session-body r))
  (check-true (surf-sess-choice? body))
  (define branches (surf-sess-choice-branches body))
  (check-equal? (length branches) 2)
  ;; First branch: inc -> Send Nat End
  (check-true (surf-sess-branch? (car branches)))
  (check-equal? (surf-sess-branch-label (car branches)) 'inc)
  (check-true (surf-sess-send? (surf-sess-branch-cont (car branches))))
  ;; Second branch: done -> End
  (check-equal? (surf-sess-branch-label (cadr branches)) 'done)
  (check-true (surf-sess-end? (surf-sess-branch-cont (cadr branches)))))

(test-case "session parse: Offer with branches"
  (define r (p "(session Server (Offer ((get (Send String End)) (put (Recv String End)))))"))
  (check-true (surf-session? r))
  (define body (surf-session-body r))
  (check-true (surf-sess-offer? body))
  (define branches (surf-sess-offer-branches body))
  (check-equal? (length branches) 2)
  (check-equal? (surf-sess-branch-label (car branches)) 'get)
  (check-equal? (surf-sess-branch-label (cadr branches)) 'put))

;; ========================================
;; Recursion
;; ========================================

(test-case "session parse: anonymous Mu"
  (define r (p "(session Loop (Mu (Send Nat (SVar Loop))))"))
  (check-true (surf-session? r))
  (define body (surf-session-body r))
  (check-true (surf-sess-rec? body))
  (check-false (surf-sess-rec-label body))  ;; anonymous
  (define inner (surf-sess-rec-body body))
  (check-true (surf-sess-send? inner))
  (check-true (surf-sess-var? (surf-sess-send-cont inner)))
  (check-equal? (surf-sess-var-name (surf-sess-send-cont inner)) 'Loop))

(test-case "session parse: named Mu"
  (define r (p "(session Counter (Mu Again (Send Nat (SVar Again))))"))
  (check-true (surf-session? r))
  (define body (surf-session-body r))
  (check-true (surf-sess-rec? body))
  (check-equal? (surf-sess-rec-label body) 'Again)
  (define inner (surf-sess-rec-body body))
  (check-true (surf-sess-send? inner)))

(test-case "session parse: SVar standalone"
  (define r (p "(session Ref (SVar Other))"))
  (check-true (surf-session? r))
  (define body (surf-session-body r))
  (check-true (surf-sess-var? body))
  (check-equal? (surf-sess-var-name body) 'Other))

;; ========================================
;; Shared session
;; ========================================

(test-case "session parse: Shared"
  (define r (p "(session SharedCounter (Shared (Mu (Choice ((inc (Send Nat (SVar SharedCounter))) (done End))))))"))
  (check-true (surf-session? r))
  (define body (surf-session-body r))
  (check-true (surf-sess-shared? body))
  (check-true (surf-sess-rec? (surf-sess-shared-body body))))

;; ========================================
;; Session reference (bare symbol body)
;; ========================================

(test-case "session parse: bare End"
  (define r (p "(session Empty End)"))
  (check-true (surf-session? r))
  (check-true (surf-sess-end? (surf-session-body r))))

(test-case "session parse: session reference"
  (define r (p "(session Alias OtherSession)"))
  (check-true (surf-session? r))
  (define body (surf-session-body r))
  (check-true (surf-sess-ref? body))
  (check-equal? (surf-sess-ref-name body) 'OtherSession))

;; ========================================
;; Metadata
;; ========================================

(test-case "session parse: with :doc metadata"
  (define r (p "(session Greeting :doc \"A greeting protocol\" (Send String End))"))
  (check-true (surf-session? r))
  (check-equal? (surf-session-name r) 'Greeting)
  (define meta (surf-session-metadata r))
  (check-equal? (length meta) 1)
  (check-equal? (caar meta) ':doc)
  (check-true (surf-sess-send? (surf-session-body r))))

;; ========================================
;; Composition: multi-step protocols
;; ========================================

(test-case "session parse: complex protocol"
  ;; Send String, Recv Nat, Choice of inc (Send Nat End) or done (End)
  (define r (p "(session Complex (Send String (Recv Nat (Choice ((inc (Send Nat End)) (done End))))))"))
  (check-true (surf-session? r))
  (define s1 (surf-session-body r))
  (check-true (surf-sess-send? s1))
  (define s2 (surf-sess-send-cont s1))
  (check-true (surf-sess-recv? s2))
  (define s3 (surf-sess-recv-cont s2))
  (check-true (surf-sess-choice? s3))
  (check-equal? (length (surf-sess-choice-branches s3)) 2))

;; ========================================
;; Error cases
;; ========================================

(test-case "session parse: missing name"
  (define r (p "(session)"))
  (check-true (parse-error? r)))

(test-case "session parse: missing body"
  (define r (p "(session Foo)"))
  (check-true (parse-error? r)))

(test-case "session parse: unknown body form"
  (define r (p "(session Foo (BadForm Nat))"))
  (check-true (parse-error? r)))

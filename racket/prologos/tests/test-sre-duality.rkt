#lang racket/base

;; ========================================================================
;; SRE Track 1 Phase 3: Duality Tests
;; ========================================================================
;;
;; Tests the duality relation on the SRE: constructor pairing (Send↔Recv),
;; sub-relation derivation (payload=equality, continuation=duality),
;; involution (dual(dual(S)) = S), and nested session types.

(require rackunit
         "../propagator.rkt"
         "../sre-core.rkt"
         "../ctor-registry.rkt"
         "../syntax.rkt"
         "../sessions.rkt"
         "../session-lattice.rkt")

;; ========================================================================
;; A. Session domain spec for testing
;; ========================================================================

(define (test-session-merge-registry rel-name)
  (case rel-name
    [(equality duality) session-lattice-merge]
    [else (error 'test-session-merge-registry "no merge for: ~a" rel-name)]))

(define session-domain
  (make-sre-domain
    #:name 'session
    #:merge-registry test-session-merge-registry
    #:contradicts? session-lattice-contradicts?
    #:bot? sess-bot?
    #:bot-value sess-bot
    #:top-value sess-top
    ;; Dual pairs: Send↔Recv, DSend↔DRecv, AsyncSend↔AsyncRecv
    #:dual-pairs '((sess-send . sess-recv)
                   (sess-dsend . sess-drecv)
                   (sess-async-send . sess-async-recv))))

;; Helper: create mini-network, install duality-relate, quiesce
(define (sre-duality-check sa sb)
  "Install duality between two cells, quiesce, return (values net cell-a cell-b)."
  (define net0 (make-prop-network))
  (define-values (net1 cell-a)
    (net-new-cell net0 sa session-lattice-merge session-lattice-contradicts?))
  (define-values (net2 cell-b)
    (net-new-cell net1 sb session-lattice-merge session-lattice-contradicts?))
  (define-values (net3 _pid)
    (net-add-propagator net2 (list cell-a cell-b) (list cell-a cell-b)
      (sre-make-structural-relate-propagator session-domain cell-a cell-b
        #:relation sre-duality)))
  (define net4 (run-to-quiescence net3))
  (values net4 cell-a cell-b))

;; ========================================================================
;; B. Basic duality propagation
;; ========================================================================

(test-case "Duality: Send propagates to Recv"
  (define-values (net ca cb)
    (sre-duality-check
     (sess-send (expr-tycon 'Int) (sess-end))
     sess-bot))
  (check-false (net-contradiction? net))
  (define vb (net-cell-read net cb))
  (check-pred sess-recv? vb)
  (check-equal? (sess-recv-type vb) (expr-tycon 'Int))
  (check-equal? (sess-recv-cont vb) (sess-end)))

(test-case "Duality: Recv propagates to Send"
  (define-values (net ca cb)
    (sre-duality-check
     sess-bot
     (sess-recv (expr-tycon 'Bool) (sess-end))))
  (check-false (net-contradiction? net))
  (define va (net-cell-read net ca))
  (check-pred sess-send? va)
  (check-equal? (sess-send-type va) (expr-tycon 'Bool)))

(test-case "Duality: matching Send/Recv — no contradiction"
  (define-values (net ca cb)
    (sre-duality-check
     (sess-send (expr-tycon 'Int) (sess-end))
     (sess-recv (expr-tycon 'Int) (sess-end))))
  (check-false (net-contradiction? net)))

(test-case "Duality: mismatched Send/Send — contradiction"
  (define-values (net ca cb)
    (sre-duality-check
     (sess-send (expr-tycon 'Int) (sess-end))
     (sess-send (expr-tycon 'Int) (sess-end))))
  (check-true (net-contradiction? net)))

;; ========================================================================
;; C. Self-dual atoms
;; ========================================================================

(test-case "Duality: sess-end is self-dual"
  (define-values (net ca cb)
    (sre-duality-check (sess-end) sess-bot))
  (check-false (net-contradiction? net))
  (check-equal? (net-cell-read net cb) (sess-end)))

;; ========================================================================
;; D. Nested duality
;; ========================================================================

(test-case "Duality: nested Send(Int, Recv(Bool, End)) ↔ Recv(Int, Send(Bool, End))"
  (define-values (net ca cb)
    (sre-duality-check
     (sess-send (expr-tycon 'Int) (sess-recv (expr-tycon 'Bool) (sess-end)))
     sess-bot))
  (check-false (net-contradiction? net))
  (define vb (net-cell-read net cb))
  ;; Expected: Recv(Int, Send(Bool, End))
  (check-pred sess-recv? vb)
  (check-equal? (sess-recv-type vb) (expr-tycon 'Int))
  (define cont (sess-recv-cont vb))
  (check-pred sess-send? cont)
  (check-equal? (sess-send-type cont) (expr-tycon 'Bool))
  (check-equal? (sess-send-cont cont) (sess-end)))

;; ========================================================================
;; E. Sub-relation derivation
;; ========================================================================

(test-case "Duality sub-relation: type component → equality"
  ;; Send's first component (payload) is type-lattice-spec ('type sentinel)
  ;; → cross-domain → equality
  ;; Send's first component variance is 'cross-domain → equality
  (check-eq? (sre-relation-name (derive-sub-relation sre-duality 'cross-domain)) 'equality))

(test-case "Duality sub-relation: session component → duality (via derive-sub-relation)"
  ;; Send's second component variance is 'same-domain → duality
  (check-eq? (sre-relation-name (derive-sub-relation sre-duality 'same-domain)) 'duality))

;; ========================================================================
;; F. Dependent session duality (SRE Track 1B Phase 4)
;; ========================================================================

(test-case "Duality: DSend(Int, Send(bvar(0), End)) ↔ DRecv(Int, Recv(bvar(0), End))"
  ;; Dependent session: continuation references the bound variable
  (define-values (net ca cb)
    (sre-duality-check
     (sess-dsend (expr-tycon 'Int) (sess-send (expr-bvar 0) (sess-end)))
     sess-bot))
  (check-false (net-contradiction? net))
  (define vb (net-cell-read net cb))
  ;; Expected: DRecv(Int, Recv(bvar(0), End))
  (check-pred sess-drecv? vb)
  (check-equal? (sess-drecv-type vb) (expr-tycon 'Int))
  (define cont (sess-drecv-cont vb))
  (check-pred sess-recv? cont)
  ;; The bound variable (bvar 0) is preserved — both sides share it
  (check-equal? (sess-recv-type cont) (expr-bvar 0))
  (check-equal? (sess-recv-cont cont) (sess-end)))

(test-case "Duality: matching DSend/DRecv — no contradiction"
  (define-values (net ca cb)
    (sre-duality-check
     (sess-dsend (expr-tycon 'Int) (sess-send (expr-bvar 0) (sess-end)))
     (sess-drecv (expr-tycon 'Int) (sess-recv (expr-bvar 0) (sess-end)))))
  (check-false (net-contradiction? net)))

(test-case "Duality: mismatched DSend/DSend — contradiction"
  (define-values (net ca cb)
    (sre-duality-check
     (sess-dsend (expr-tycon 'Int) (sess-end))
     (sess-dsend (expr-tycon 'Int) (sess-end))))
  (check-true (net-contradiction? net)))

;; ========================================================================
;; G. Edge cases (SRE Track 1B Phase 5)
;; ========================================================================

;; Deeply nested protocols (5 levels)
(test-case "Duality: 5-level nested Send/Recv"
  (define deep-send
    (sess-send (expr-tycon 'A)
      (sess-recv (expr-tycon 'B)
        (sess-send (expr-tycon 'C)
          (sess-recv (expr-tycon 'D)
            (sess-send (expr-tycon 'E) (sess-end)))))))
  (define-values (net ca cb) (sre-duality-check deep-send sess-bot))
  (check-false (net-contradiction? net))
  ;; Verify outermost: Recv
  (define vb (net-cell-read net cb))
  (check-pred sess-recv? vb)
  (check-equal? (sess-recv-type vb) (expr-tycon 'A)))

;; Mu (recursive) duality: mu is self-dual, body gets duality
(test-case "Duality: mu(Send(Int, svar(0))) ↔ mu(Recv(Int, svar(0)))"
  (define mu-send (sess-mu (sess-send (expr-tycon 'Int) (sess-svar 0))))
  (define-values (net ca cb) (sre-duality-check mu-send sess-bot))
  (check-false (net-contradiction? net))
  (define vb (net-cell-read net cb))
  (check-pred sess-mu? vb)
  ;; Body should be dualized: Recv(Int, svar(0))
  (define body (sess-mu-body vb))
  (check-pred sess-recv? body)
  (check-equal? (sess-recv-type body) (expr-tycon 'Int))
  (check-equal? (sess-recv-cont body) (sess-svar 0)))

;; Mixed constructors: Send + AsyncRecv in same protocol
(test-case "Duality: Send(Int, AsyncRecv(Bool, End)) ↔ Recv(Int, AsyncSend(Bool, End))"
  (define mixed (sess-send (expr-tycon 'Int)
                  (sess-async-recv (expr-tycon 'Bool) (sess-end))))
  (define-values (net ca cb) (sre-duality-check mixed sess-bot))
  (check-false (net-contradiction? net))
  (define vb (net-cell-read net cb))
  (check-pred sess-recv? vb)
  (define cont (sess-recv-cont vb))
  (check-pred sess-async-send? cont))

;; Both sides with concrete values that ARE duals — should succeed
(test-case "Duality: both sides concrete duals — verify, don't contradict"
  (define-values (net ca cb)
    (sre-duality-check
     (sess-send (expr-tycon 'Int) (sess-recv (expr-tycon 'Bool) (sess-end)))
     (sess-recv (expr-tycon 'Int) (sess-send (expr-tycon 'Bool) (sess-end)))))
  (check-false (net-contradiction? net)))

;; Both sides concrete but NOT duals — should contradict
(test-case "Duality: both sides concrete non-duals — contradiction"
  (define-values (net ca cb)
    (sre-duality-check
     (sess-send (expr-tycon 'Int) (sess-end))
     (sess-send (expr-tycon 'Bool) (sess-end))))
  (check-true (net-contradiction? net)))

;; Payload type mismatch under duality — should contradict
(test-case "Duality: Send(Int, End) ↔ Recv(Bool, End) — payload mismatch"
  (define-values (net ca cb)
    (sre-duality-check
     (sess-send (expr-tycon 'Int) (sess-end))
     (sess-recv (expr-tycon 'Bool) (sess-end))))
  ;; Payload types must be EQUAL (not dual). Int ≠ Bool → contradiction.
  (check-true (net-contradiction? net)))

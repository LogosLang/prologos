#lang racket/base

;;;
;;; PROLOGOS INTEGRATION TESTS
;;; Port of prologos-tests.maude — comprehensive cross-module tests.
;;;
;;; These tests exercise the complete specification, including
;;; cross-module interactions between core types, Vec/Fin, QTT,
;;; session types, process typing, normalization, and duality.
;;;

(require rackunit
         "../prelude.rkt"
         "../syntax.rkt"
         "../substitution.rkt"
         "../reduction.rkt"
         (prefix-in tc: "../typing-core.rkt")
         "../qtt.rkt"
         "../sessions.rkt"
         "../processes.rkt"
         "../typing-sessions.rkt")

;; Helper to build channel contexts from pairs
(define (make-chan-ctx . pairs)
  (for/fold ([ctx chan-ctx-empty])
            ([p (in-list pairs)])
    (chan-ctx-add ctx (car p) (cdr p))))

;; ================================================================
;; 1. POLYMORPHIC IDENTITY APPLIED TO NAT ZERO
;;    Tests: Pi types, lambda, application, annotation, conversion
;; ================================================================

(define poly-id-type
  (expr-Pi 'm0 (expr-Type (lzero)) (expr-Pi 'mw (expr-bvar 0) (expr-bvar 1))))
(define poly-id-term
  (expr-lam 'm0 (expr-Type (lzero)) (expr-lam 'mw (expr-bvar 0) (expr-bvar 0))))
(define poly-id-ann
  (expr-ann poly-id-term poly-id-type))

(test-case "1a. Polymorphic identity type checks"
  (check-true (tc:check ctx-empty poly-id-term poly-id-type)))

(test-case "1b. polyId applied to Nat : Pi(mw, Nat, Nat)"
  (check-equal? (tc:infer ctx-empty (expr-app poly-id-ann (expr-Nat)))
                (expr-Pi 'mw (expr-Nat) (expr-Nat))))

(test-case "1c. polyId applied to Nat then zero : Nat"
  (check-equal? (tc:infer ctx-empty (expr-app (expr-app poly-id-ann (expr-Nat)) (expr-zero)))
                (expr-Nat)))

(test-case "1d. Normalize polyId Nat zero = zero"
  (check-equal? (nf (expr-app (expr-app poly-id-ann (expr-Nat)) (expr-zero)))
                (expr-zero)))

;; ================================================================
;; 2. NESTED DEPENDENT TYPES: Vector types
;;    Tests: Vec, dependent Pi, substitution, type formation
;; ================================================================

(test-case "2a. Vec(Nat, suc(suc(zero))) is a type"
  (check-true (tc:is-type ctx-empty (expr-Vec (expr-Nat) (expr-suc (expr-suc (expr-zero)))))))

(test-case "2b. Vec(Vec(Nat, zero), suc(zero)) is a type"
  (check-true (tc:is-type ctx-empty (expr-Vec (expr-Vec (expr-Nat) (expr-zero)) (expr-suc (expr-zero))))))

(test-case "2c. Fin(3) is a type"
  (check-true (tc:is-type ctx-empty (expr-Fin (expr-suc (expr-suc (expr-suc (expr-zero))))))))

;; ================================================================
;; 3. LENGTH-INDEXED SAFE HEAD
;;    Tests: Vec, Fin, vindex, dependent types interaction
;; ================================================================

(define vec2
  (expr-vcons (expr-Nat) (expr-suc (expr-zero)) (expr-zero)
    (expr-vcons (expr-Nat) (expr-zero) (expr-suc (expr-zero)) (expr-vnil (expr-Nat)))))

(test-case "3a. 2-element vector type checks"
  (check-true (tc:check ctx-empty vec2 (expr-Vec (expr-Nat) (expr-suc (expr-suc (expr-zero)))))))

(test-case "3b. fzero(suc(zero)) : Fin(suc(suc(zero)))"
  (check-true (tc:check ctx-empty (expr-fzero (expr-suc (expr-zero))) (expr-Fin (expr-suc (expr-suc (expr-zero)))))))

(test-case "3c. vindex safely indexes 2-vector"
  (check-equal? (tc:infer ctx-empty
                  (expr-vindex (expr-Nat) (expr-suc (expr-suc (expr-zero)))
                    (expr-ann (expr-fzero (expr-suc (expr-zero))) (expr-Fin (expr-suc (expr-suc (expr-zero)))))
                    (expr-ann vec2 (expr-Vec (expr-Nat) (expr-suc (expr-suc (expr-zero)))))))
                (expr-Nat)))

(test-case "3d. NEGATIVE: cannot construct Fin(zero)"
  (check-false (tc:check ctx-empty (expr-fzero (expr-zero)) (expr-Fin (expr-zero)))))

;; ================================================================
;; 4. ATM PROTOCOL AS SESSION TYPE WITH DUALITY
;;    Tests: Session constructors, duality, branching
;; ================================================================

(define atm-client-session
  (sess-choice (list (cons 'deposit (sess-send (expr-Nat) (sess-end)))
                     (cons 'query (sess-recv (expr-Nat) (sess-end))))))

(test-case "4a. ATM dual: choice -> offer with flipped directions"
  (check-equal? (dual atm-client-session)
                (sess-offer (list (cons 'deposit (sess-recv (expr-Nat) (sess-end)))
                                  (cons 'query (sess-send (expr-Nat) (sess-end)))))))

(test-case "4b. ATM dual is involution"
  (check-equal? (dual (dual atm-client-session)) atm-client-session))

;; ================================================================
;; 5. CLIENT-SERVER INTERACTION
;;    Tests: Process typing, send/recv, select/offer, duality
;; ================================================================

(define cs-choice-session
  (sess-choice (list (cons 'ping (sess-send (expr-Nat) (sess-end)))
                     (cons 'quit (sess-end)))))
(define cs-offer-session
  (sess-offer (list (cons 'ping (sess-recv (expr-Nat) (sess-end)))
                    (cons 'quit (sess-end)))))

(test-case "5a. Client: select ping, send zero, stop"
  (check-true
   (type-proc ctx-empty
              (make-chan-ctx (cons 'c cs-choice-session))
              (proc-sel 'c 'ping (proc-send (expr-zero) 'c (proc-stop))))))

(test-case "5b. Server: case { ping -> recv stop, quit -> stop }"
  (check-true
   (type-proc ctx-empty
              (make-chan-ctx (cons 's cs-offer-session))
              (proc-case 's (list (cons 'ping (proc-recv 's (expr-Nat) (proc-stop)))
                                  (cons 'quit (proc-stop)))))))

;; ================================================================
;; 6. DEPENDENT VECTOR PROTOCOL
;;    Tests: dsend/drecv, session substitution, Vec in session
;; ================================================================

(test-case "6a. Session substitution after dependent send"
  (check-equal? (substS (sess-send (expr-Vec (expr-Nat) (expr-bvar 0)) (sess-end))
                        0 (expr-suc (expr-suc (expr-zero))))
                (sess-send (expr-Vec (expr-Nat) (expr-suc (expr-suc (expr-zero)))) (sess-end))))

(test-case "6b. Dependent send with Vec types correctly"
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

(test-case "6c. NEGATIVE: wrong-length vector after dependent send"
  (check-false
   (type-proc ctx-empty
              (make-chan-ctx (cons 'c (sess-dsend (expr-Nat)
                                        (sess-send (expr-Vec (expr-Nat) (expr-bvar 0)) (sess-end)))))
              (proc-send (expr-suc (expr-suc (expr-zero))) 'c
                (proc-send (expr-ann (expr-vcons (expr-Nat) (expr-zero) (expr-zero)
                                                 (expr-vnil (expr-Nat)))
                                     (expr-Vec (expr-Nat) (expr-suc (expr-zero))))
                           'c (proc-stop))))))

;; ================================================================
;; 7. QTT VIOLATION DETECTION
;;    Tests: Linear variable duplication, erased variable use
;; ================================================================

(test-case "7a. Linear identity: uses x exactly once"
  (check-true (checkQ-top ctx-empty
                          (expr-lam 'm1 (expr-Nat) (expr-bvar 0))
                          (expr-Pi 'm1 (expr-Nat) (expr-Nat)))))

(test-case "7b. NEGATIVE: duplicate linear variable"
  (check-false (checkQ-top ctx-empty
                           (expr-lam 'm1 (expr-Nat) (expr-pair (expr-bvar 0) (expr-bvar 0)))
                           (expr-Pi 'm1 (expr-Nat) (expr-Sigma (expr-Nat) (expr-Nat))))))

(test-case "7c. NEGATIVE: unused linear variable"
  (check-false (checkQ-top ctx-empty
                           (expr-lam 'm1 (expr-Nat) (expr-zero))
                           (expr-Pi 'm1 (expr-Nat) (expr-Nat)))))

(test-case "7d. NEGATIVE: erased variable used at runtime"
  (check-false (checkQ-top ctx-empty
                           (expr-lam 'm0 (expr-Nat) (expr-bvar 0))
                           (expr-Pi 'm0 (expr-Nat) (expr-Nat)))))

(test-case "7e. Erased argument correctly ignored"
  (check-true (checkQ-top ctx-empty
                          (expr-lam 'm0 (expr-Nat) (expr-zero))
                          (expr-Pi 'm0 (expr-Nat) (expr-Nat)))))

(test-case "7f. Omega variable used multiple times is OK"
  (check-true (checkQ-top ctx-empty
                          (expr-lam 'mw (expr-Nat) (expr-pair (expr-bvar 0) (expr-bvar 0)))
                          (expr-Pi 'mw (expr-Nat) (expr-Sigma (expr-Nat) (expr-Nat))))))

(test-case "7g. QTT with linear application: consumes argument once"
  (check-true (checkQ-top (ctx-extend ctx-empty (expr-Nat) 'm1)
                          (expr-app (expr-ann (expr-lam 'm1 (expr-Nat) (expr-bvar 0))
                                              (expr-Pi 'm1 (expr-Nat) (expr-Nat)))
                                    (expr-bvar 0))
                          (expr-Nat))))

(test-case "7h. NEGATIVE: linear var passed to unrestricted function"
  ;; Usage: mw * m1 = mw, but declared m1, compatible(m1, mw) = false
  (check-false (checkQ-top (ctx-extend ctx-empty (expr-Nat) 'm1)
                           (expr-app (expr-ann (expr-lam 'mw (expr-Nat) (expr-bvar 0))
                                               (expr-Pi 'mw (expr-Nat) (expr-Nat)))
                                     (expr-bvar 0))
                           (expr-Nat))))

;; ================================================================
;; 8. RECURSIVE SESSIONS
;;    Tests: mu, unfold, svar
;; ================================================================

(test-case "8a. Unfold recursive session"
  (check-equal? (unfold-session (sess-mu (sess-send (expr-Nat) (sess-svar 0))))
                (sess-send (expr-Nat) (sess-mu (sess-send (expr-Nat) (sess-svar 0))))))

(test-case "8b. Dual of recursive session"
  (check-equal? (dual (sess-mu (sess-send (expr-Nat) (sess-svar 0))))
                (sess-mu (sess-recv (expr-Nat) (sess-svar 0)))))

;; ================================================================
;; 9. CONVERSION AND NORMALIZATION CROSS-MODULE
;;    Tests: conv with complex terms, natrec normalization
;; ================================================================

;; plus(a, b) = natrec(motive, b, step, a)
;; motive = lam(mw, Nat, Nat)
;; step = lam(mw, Nat, lam(mw, Nat, suc(bvar(0))))
(define plus-motive
  (expr-ann (expr-lam 'mw (expr-Nat) (expr-Nat))
            (expr-Pi 'mw (expr-Nat) (expr-Type (lzero)))))
(define plus-step
  (expr-ann (expr-lam 'mw (expr-Nat) (expr-lam 'mw (expr-Nat) (expr-suc (expr-bvar 0))))
            (expr-Pi 'mw (expr-Nat) (expr-Pi 'mw (expr-Nat) (expr-Nat)))))

(test-case "9a. natrec computes 2 + 1 = 3"
  (check-equal? (nf (expr-natrec plus-motive
                                  (expr-suc (expr-zero))  ; base = 1
                                  plus-step
                                  (expr-suc (expr-suc (expr-zero)))))  ; target = 2
                (expr-suc (expr-suc (expr-suc (expr-zero))))))

(test-case "9b. Conversion: 1 + 1 == 2"
  (check-true (conv (expr-natrec plus-motive
                                  (expr-suc (expr-zero))
                                  plus-step
                                  (expr-suc (expr-zero)))
                    (expr-suc (expr-suc (expr-zero))))))

;; ================================================================
;; 10. LINK WITH DUAL SESSIONS
;;     Tests: plink, duality check
;; ================================================================

(test-case "10a. Link two channels with dual sessions"
  (check-true
   (type-proc ctx-empty
              (make-chan-ctx (cons 'c1 (sess-send (expr-Nat) (sess-end)))
                            (cons 'c2 (sess-recv (expr-Nat) (sess-end))))
              (proc-link 'c1 'c2))))

(test-case "10b. NEGATIVE: link with non-dual sessions"
  (check-false
   (type-proc ctx-empty
              (make-chan-ctx (cons 'c1 (sess-send (expr-Nat) (sess-end)))
                            (cons 'c2 (sess-send (expr-Nat) (sess-end))))
              (proc-link 'c1 'c2))))

;; ================================================================
;; 11. SOLVE (AXIOMATIC PROOF SEARCH)
;;     Tests: psolve extends unrestricted context
;; ================================================================

(test-case "11. Solve for Nat, then send on channel"
  (check-true
   (type-proc ctx-empty
              (make-chan-ctx (cons 'c (sess-send (expr-Nat) (sess-end))))
              (proc-solve (expr-Nat) (proc-send (expr-bvar 0) 'c (proc-stop))))))

#lang racket/base

;;;
;;; PROLOGOS REDEX — INTEGRATION TESTS
;;; Ports all kernel integration tests to the PLT Redex formalization.
;;; Tests 1-3 (core), 4-6 (sessions), 7 (QTT), 8 (recursive sessions),
;;; 9 (normalization), 10 (link with dual sessions).
;;;
;;; Cross-reference: ../../tests/test-integration.rkt (kernel tests)
;;;

(require redex/reduction-semantics
         "../lang.rkt"
         "../subst.rkt"
         "../reduce.rkt"
         "../typing.rkt"
         "../qtt.rkt"
         "../sessions.rkt"
         "../processes.rkt"
         "../typing-sessions.rkt")

;; ================================================================
;; 1. POLYMORPHIC IDENTITY APPLIED TO NAT ZERO
;;    Tests: Pi types, lambda, application, annotation, conversion
;; ================================================================

;; idType = Pi(m0, Type(lzero), Pi(mw, bvar(0), bvar(1)))
;; "forall (A : Type). A -> A"
(define poly-id-type
  (term (Pi m0 (Type lzero) (Pi mw (bvar 0) (bvar 1)))))

;; idTerm = lam(m0, Type(lzero), lam(mw, bvar(0), bvar(0)))
;; "\ (A : Type) (x : A). x"
(define poly-id-term
  (term (lam m0 (Type lzero) (lam mw (bvar 0) (bvar 0)))))

;; Annotated identity for synthesis mode
(define poly-id
  (term (ann ,poly-id-term ,poly-id-type)))

;; 1a. The polymorphic identity type is well-formed
(test-equal (term (is-type () ,poly-id-type)) #t)

;; 1b. The polymorphic identity checks against its type
(test-equal (term (check () ,poly-id-term ,poly-id-type)) #t)

;; 1c. Applying id to Nat gives Nat -> Nat
;;     infer((), app(poly-id, Nat)) = Pi(mw, Nat, Nat)
(test-equal (term (infer () (app ,poly-id Nat)))
            (term (Pi mw Nat Nat)))

;; 1d. Applying id Nat to zero gives Nat
;;     infer((), app(app(poly-id, Nat), zero)) = Nat
(test-equal (term (infer () (app (app ,poly-id Nat) zero)))
            (term Nat))

;; ================================================================
;; 2. NESTED DEPENDENT TYPES: Vec and Fin well-formedness
;;    Tests: Vec, Fin, dependent type formation
;; ================================================================

;; 2a. Vec(Nat, suc(zero)) is a type
(test-equal (term (is-type () (Vec Nat (suc zero)))) #t)

;; 2b. Fin(suc(suc(zero))) is a type
(test-equal (term (is-type () (Fin (suc (suc zero))))) #t)

;; 2c. Vec(Bool, suc(suc(zero))) is a type
(test-equal (term (is-type () (Vec Bool (suc (suc zero))))) #t)

;; ================================================================
;; 3. SAFE HEAD/INDEX WITH VEC/FIN
;;    Tests: vhead, vtail, vindex, Fin constructors, dependent types
;; ================================================================

;; A single-element vector: [suc(suc(zero))] : Vec(Nat, suc(zero))
;; vcons(Nat, zero, suc(suc(zero)), vnil(Nat)) annotated with Vec(Nat, suc(zero))
(define vec1
  (term (ann (vcons Nat zero (suc (suc zero)) (vnil Nat))
             (Vec Nat (suc zero)))))

;; 3a. vhead of a single-element vector yields Nat
(test-equal (term (infer () (vhead Nat zero ,vec1)))
            (term Nat))

;; 3b. vtail of a single-element vector yields Vec(Nat, zero)
(test-equal (term (infer () (vtail Nat zero ,vec1)))
            (term (Vec Nat zero)))

;; 3c. vindex with fzero(zero) into a single-element vector yields Nat
;;     Need fzero(zero) : Fin(suc(zero)) — the index into a 1-element vector
(test-equal (term (infer () (vindex Nat (suc zero)
                                    (fzero zero)
                                    ,vec1)))
            (term Nat))

;; 3d. NEGATIVE: Cannot construct fzero(zero) : Fin(zero)
;;     Fin(zero) is empty — no inhabitants
(test-equal (term (check () (fzero zero) (Fin zero))) #f)

;; ================================================================
;; 4. ATM PROTOCOL AS SESSION TYPE WITH DUALITY
;;    Tests: Session constructors, duality, branching
;; ================================================================

;; ATM client session: choose deposit(send Nat, end) or query(recv Nat, end)
(define atm-client-session
  `(choice ((deposit . (send ,(term Nat) endS))
            (query . (recv ,(term Nat) endS)))))

;; 4a. ATM dual: choice -> offer with flipped directions
(test-equal (dual atm-client-session)
            `(offer ((deposit . (recv ,(term Nat) endS))
                     (query . (send ,(term Nat) endS)))))

;; 4b. ATM dual is involution: dual(dual(S)) = S
(test-equal (dual (dual atm-client-session))
            atm-client-session)

;; ================================================================
;; 5. CLIENT-SERVER INTERACTION
;;    Tests: Process typing, send/recv, select/offer, duality
;; ================================================================

(define cs-choice-session
  `(choice ((ping . (send ,(term Nat) endS))
            (quit . endS))))
(define cs-offer-session
  `(offer ((ping . (recv ,(term Nat) endS))
           (quit . endS))))

;; 5a. Client: select ping, send zero, stop
(test-equal (type-proc '()
                       (chan-ctx-add chan-ctx-empty 'c cs-choice-session)
                       `(psel c ping (psend ,(term zero) c (stop))))
            #t)

;; 5b. Server: case { ping -> recv stop, quit -> stop }
(test-equal (type-proc '()
                       (chan-ctx-add chan-ctx-empty 's cs-offer-session)
                       `(pcase s ((ping . (precv s ,(term Nat) (stop)))
                                  (quit . (stop)))))
            #t)

;; ================================================================
;; 6. DEPENDENT VECTOR PROTOCOL
;;    Tests: dsend/drecv, session substitution, Vec in session
;; ================================================================

;; 6a. Session substitution after dependent send
;;     substS(send(Vec(Nat, bvar(0)), end), 0, suc(suc(zero)))
;;     = send(Vec(Nat, suc(suc(zero))), end)
(test-equal (substS `(send ,(term (Vec Nat (bvar 0))) endS)
                    0
                    (term (suc (suc zero))))
            `(send ,(term (Vec Nat (suc (suc zero)))) endS))

;; 6b. Dependent send with Vec types correctly
;;     Channel c :: dsend(Nat, send(Vec(Nat, bvar(0)), end))
;;     Process: send suc(suc(zero)) on c, then send annotated 2-element vector, stop
(define dep-vec-session
  `(dsend ,(term Nat) (send ,(term (Vec Nat (bvar 0))) endS)))

(define vec2-ann
  (term (ann (vcons Nat (suc zero) zero
               (vcons Nat zero (suc zero) (vnil Nat)))
             (Vec Nat (suc (suc zero))))))

(test-equal (type-proc '()
                       (chan-ctx-add chan-ctx-empty 'c dep-vec-session)
                       `(psend ,(term (suc (suc zero))) c
                         (psend ,vec2-ann c (stop))))
            #t)

;; 6c. NEGATIVE: wrong-length vector after dependent send
;;     Send 2, then send a 1-element vector — type mismatch
(define vec1-ann-wrong
  (term (ann (vcons Nat zero zero (vnil Nat))
             (Vec Nat (suc zero)))))

(test-equal (type-proc '()
                       (chan-ctx-add chan-ctx-empty 'c dep-vec-session)
                       `(psend ,(term (suc (suc zero))) c
                         (psend ,vec1-ann-wrong c (stop))))
            #f)

;; ================================================================
;; 8. RECURSIVE SESSIONS
;;    Tests: mu, unfold, svar
;; ================================================================

;; 8a. Unfold recursive session: mu(send(Nat, svar(0))) unfolds to
;;     send(Nat, mu(send(Nat, svar(0))))
(test-equal (unfold-session `(mu (send ,(term Nat) (svar 0))))
            `(send ,(term Nat) (mu (send ,(term Nat) (svar 0)))))

;; 8b. Dual of recursive session: mu(send(Nat, svar(0))) -> mu(recv(Nat, svar(0)))
(test-equal (dual `(mu (send ,(term Nat) (svar 0))))
            `(mu (recv ,(term Nat) (svar 0))))

;; ================================================================
;; 10. LINK WITH DUAL SESSIONS
;;     Tests: plink, duality check
;; ================================================================

;; 10a. Link two channels with dual sessions
(test-equal (type-proc '()
                       (chan-ctx-add (chan-ctx-add chan-ctx-empty
                                                   'c1 `(send ,(term Nat) endS))
                                    'c2 `(recv ,(term Nat) endS))
                       '(plink c1 c2))
            #t)

;; 10b. NEGATIVE: link with non-dual sessions
(test-equal (type-proc '()
                       (chan-ctx-add (chan-ctx-add chan-ctx-empty
                                                   'c1 `(send ,(term Nat) endS))
                                    'c2 `(send ,(term Nat) endS))
                       '(plink c1 c2))
            #f)

;; ================================================================
;; 9. CONVERSION AND NORMALIZATION (natrec computes addition)
;;    Tests: natrec reduction, conv with complex terms
;; ================================================================

;; Addition via natrec:
;;   add(m, n) = natrec(motive, n, step, m)
;;   motive = lam(mw, Nat, Nat)             -- result is always Nat
;;   step   = lam(mw, Nat, lam(mw, Nat, suc(bvar(0))))  -- step(k, acc) = suc(acc)

;; 9a. natrec computes 2 + 1 = 3
;;     natrec(motive, suc(zero), step, suc(suc(zero))) normalizes to suc(suc(suc(zero)))
(test-equal (term (nf (natrec (lam mw Nat Nat)
                               (suc zero)
                               (lam mw Nat (lam mw Nat (suc (bvar 0))))
                               (suc (suc zero)))))
            (term (suc (suc (suc zero)))))

;; 9b. The addition expression is well-typed
;;     infer returns app(motive, target) = app(lam(mw, Nat, Nat), suc(suc(zero)))
;;     which is convertible with Nat
(test-equal (term (infer () (natrec (lam mw Nat Nat)
                                     (suc zero)
                                     (lam mw Nat (lam mw Nat (suc (bvar 0))))
                                     (suc (suc zero)))))
            (term (app (lam mw Nat Nat) (suc (suc zero)))))

;; 9c. The inferred type is convertible with Nat
(test-equal (term (conv (infer () (natrec (lam mw Nat Nat)
                                           (suc zero)
                                           (lam mw Nat (lam mw Nat (suc (bvar 0))))
                                           (suc (suc zero))))
                        Nat))
            #t)

;; 9d. Conversion: 1 + 1 == 2
(test-equal (term (conv (natrec (lam mw Nat Nat)
                                 (suc zero)
                                 (lam mw Nat (lam mw Nat (suc (bvar 0))))
                                 (suc zero))
                        (suc (suc zero))))
            #t)

;; ================================================================
;; 7. QTT VIOLATION DETECTION
;;    Tests: Linear variable duplication, erased variable use,
;;           omega usage, linear application
;; ================================================================

;; 7a. Linear identity: uses x exactly once — OK
(test-equal (checkQ-top '()
                        (term (lam m1 Nat (bvar 0)))
                        (term (Pi m1 Nat Nat)))
            #t)

;; 7b. NEGATIVE: duplicate linear variable
;;     lam(m1, Nat, pair(bvar(0), bvar(0))) : Pi(m1, Nat, Sigma(Nat, Nat))
;;     Uses the linear variable twice — fails
(test-equal (checkQ-top '()
                        (term (lam m1 Nat (pair (bvar 0) (bvar 0))))
                        (term (Pi m1 Nat (Sigma Nat Nat))))
            #f)

;; 7c. NEGATIVE: unused linear variable
;;     lam(m1, Nat, zero) : Pi(m1, Nat, Nat) — linear var not used
(test-equal (checkQ-top '()
                        (term (lam m1 Nat zero))
                        (term (Pi m1 Nat Nat)))
            #f)

;; 7d. NEGATIVE: erased variable used at runtime
;;     lam(m0, Nat, bvar(0)) : Pi(m0, Nat, Nat) — erased but used
(test-equal (checkQ-top '()
                        (term (lam m0 Nat (bvar 0)))
                        (term (Pi m0 Nat Nat)))
            #f)

;; 7e. Erased argument correctly ignored — OK
;;     lam(m0, Nat, zero) : Pi(m0, Nat, Nat) — erased and not used
(test-equal (checkQ-top '()
                        (term (lam m0 Nat zero))
                        (term (Pi m0 Nat Nat)))
            #t)

;; 7f. Omega variable used multiple times is OK
;;     lam(mw, Nat, pair(bvar(0), bvar(0))) : Pi(mw, Nat, Sigma(Nat, Nat))
(test-equal (checkQ-top '()
                        (term (lam mw Nat (pair (bvar 0) (bvar 0))))
                        (term (Pi mw Nat (Sigma Nat Nat))))
            #t)

;; 7g. QTT with linear application: consumes argument once — OK
;;     In context [Nat:m1], app(ann(lam(m1, Nat, bvar(0)), Pi(m1, Nat, Nat)), bvar(0))
(test-equal (checkQ-top '((Nat m1) ())
                        (term (app (ann (lam m1 Nat (bvar 0))
                                        (Pi m1 Nat Nat))
                                   (bvar 0)))
                        (term Nat))
            #t)

;; 7h. NEGATIVE: linear var passed to unrestricted function
;;     In context [Nat:m1], app(ann(lam(mw,...), Pi(mw,...)), bvar(0))
;;     Usage: mw * m1 = mw, but declared m1, compatible(m1, mw) = false
(test-equal (checkQ-top '((Nat m1) ())
                        (term (app (ann (lam mw Nat (bvar 0))
                                        (Pi mw Nat Nat))
                                   (bvar 0)))
                        (term Nat))
            #f)

;; ========================================
;; Summary
;; ========================================
(test-results)

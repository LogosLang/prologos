#lang racket/base

;;;
;;; Tests for session-lattice.rkt
;;; Validates lattice merge semantics, pure unification, contradiction detection.
;;;

(require rackunit
         "../syntax.rkt"
         "../sessions.rkt"
         "../session-lattice.rkt")

;; ========================================
;; Sentinel tests
;; ========================================

(test-case "sess-bot is identity for merge"
  (check-equal? (session-lattice-merge sess-bot sess-bot) sess-bot)
  (check-equal? (session-lattice-merge sess-bot (sess-end)) (sess-end))
  (check-equal? (session-lattice-merge (sess-end) sess-bot) (sess-end)))

(test-case "sess-top is absorbing for merge"
  (check-equal? (session-lattice-merge sess-top sess-bot) sess-top)
  (check-equal? (session-lattice-merge sess-bot sess-top) sess-top)
  (check-equal? (session-lattice-merge sess-top (sess-end)) sess-top)
  (check-equal? (session-lattice-merge (sess-end) sess-top) sess-top)
  (check-equal? (session-lattice-merge sess-top sess-top) sess-top))

(test-case "contradicts? only on sess-top"
  (check-true (session-lattice-contradicts? sess-top))
  (check-false (session-lattice-contradicts? sess-bot))
  (check-false (session-lattice-contradicts? (sess-end)))
  (check-false (session-lattice-contradicts? (sess-send (expr-Nat) (sess-end)))))

;; ========================================
;; Idempotent merge (same type → same type)
;; ========================================

(test-case "merge: idempotent — same session merges to itself"
  (define s (sess-send (expr-Nat) (sess-end)))
  (check-equal? (session-lattice-merge s s) s))

(test-case "merge: idempotent — complex session"
  (define s (sess-recv (expr-String) (sess-send (expr-Nat) (sess-end))))
  (check-equal? (session-lattice-merge s s) s))

;; ========================================
;; Compatible structural merging
;; ========================================

(test-case "merge: send + send with same types"
  (define s1 (sess-send (expr-Nat) (sess-end)))
  (define s2 (sess-send (expr-Nat) (sess-end)))
  (check-equal? (session-lattice-merge s1 s2) s1))

(test-case "merge: recv + recv with same types"
  (define s1 (sess-recv (expr-String) (sess-end)))
  (define s2 (sess-recv (expr-String) (sess-end)))
  (check-equal? (session-lattice-merge s1 s2) s1))

(test-case "merge: multi-step sessions"
  (define s1 (sess-send (expr-Nat) (sess-recv (expr-String) (sess-end))))
  (define s2 (sess-send (expr-Nat) (sess-recv (expr-String) (sess-end))))
  (check-equal? (session-lattice-merge s1 s2) s1))

;; ========================================
;; Incompatible structural merging → contradiction
;; ========================================

(test-case "merge: send vs recv → contradiction"
  (define s1 (sess-send (expr-Nat) (sess-end)))
  (define s2 (sess-recv (expr-Nat) (sess-end)))
  (check-true (sess-top? (session-lattice-merge s1 s2))))

(test-case "merge: different message types → contradiction"
  (define s1 (sess-send (expr-Nat) (sess-end)))
  (define s2 (sess-send (expr-String) (sess-end)))
  (check-true (sess-top? (session-lattice-merge s1 s2))))

(test-case "merge: send vs end → contradiction"
  (define s1 (sess-send (expr-Nat) (sess-end)))
  (define s2 (sess-end))
  (check-true (sess-top? (session-lattice-merge s1 s2))))

(test-case "merge: choice vs offer → contradiction"
  (define s1 (sess-choice (list (cons 'a (sess-end)))))
  (define s2 (sess-offer (list (cons 'a (sess-end)))))
  (check-true (sess-top? (session-lattice-merge s1 s2))))

;; ========================================
;; Choice / Offer branch merging
;; ========================================

(test-case "merge: choice with matching branches"
  (define s1 (sess-choice (list (cons 'inc (sess-send (expr-Nat) (sess-end)))
                                (cons 'done (sess-end)))))
  (define s2 (sess-choice (list (cons 'inc (sess-send (expr-Nat) (sess-end)))
                                (cons 'done (sess-end)))))
  (check-equal? (session-lattice-merge s1 s2) s1))

(test-case "merge: offer with matching branches"
  (define s1 (sess-offer (list (cons 'get (sess-send (expr-String) (sess-end)))
                               (cons 'put (sess-recv (expr-String) (sess-end))))))
  (define s2 (sess-offer (list (cons 'get (sess-send (expr-String) (sess-end)))
                               (cons 'put (sess-recv (expr-String) (sess-end))))))
  (check-equal? (session-lattice-merge s1 s2) s1))

(test-case "merge: choice with incompatible branch continuation → contradiction"
  (define s1 (sess-choice (list (cons 'a (sess-send (expr-Nat) (sess-end))))))
  (define s2 (sess-choice (list (cons 'a (sess-send (expr-String) (sess-end))))))
  (check-true (sess-top? (session-lattice-merge s1 s2))))

;; ========================================
;; Recursion (mu + svar)
;; ========================================

(test-case "merge: mu with same body"
  (define s1 (sess-mu (sess-send (expr-Nat) (sess-svar 0))))
  (define s2 (sess-mu (sess-send (expr-Nat) (sess-svar 0))))
  (check-equal? (session-lattice-merge s1 s2) s1))

(test-case "merge: mu with different bodies → contradiction"
  (define s1 (sess-mu (sess-send (expr-Nat) (sess-svar 0))))
  (define s2 (sess-mu (sess-recv (expr-Nat) (sess-svar 0))))
  (check-true (sess-top? (session-lattice-merge s1 s2))))

;; ========================================
;; Dependent sessions
;; ========================================

(test-case "merge: dsend + dsend same type"
  (define s1 (sess-dsend (expr-Nat) (sess-end)))
  (define s2 (sess-dsend (expr-Nat) (sess-end)))
  (check-equal? (session-lattice-merge s1 s2) s1))

(test-case "merge: dsend + drecv → contradiction"
  (define s1 (sess-dsend (expr-Nat) (sess-end)))
  (define s2 (sess-drecv (expr-Nat) (sess-end)))
  (check-true (sess-top? (session-lattice-merge s1 s2))))

;; ========================================
;; Meta handling
;; ========================================

(test-case "merge: sess-meta with concrete → concrete"
  (define m (sess-meta 'test-meta-1))
  (define s (sess-send (expr-Nat) (sess-end)))
  (check-equal? (session-lattice-merge m s) s)
  (check-equal? (session-lattice-merge s m) s))

(test-case "merge: sess-meta with sess-bot → sess-meta"
  (define m (sess-meta 'test-meta-2))
  (check-equal? (session-lattice-merge sess-bot m) m)
  (check-equal? (session-lattice-merge m sess-bot) m))

(test-case "has-unsolved-session-meta?: detects meta in continuation"
  (check-true (has-unsolved-session-meta? (sess-meta 'x)))
  (check-true (has-unsolved-session-meta? (sess-send (expr-Nat) (sess-meta 'x))))
  (check-true (has-unsolved-session-meta? (sess-recv (expr-String) (sess-meta 'x))))
  (check-false (has-unsolved-session-meta? (sess-end)))
  (check-false (has-unsolved-session-meta? (sess-send (expr-Nat) (sess-end))))
  (check-false (has-unsolved-session-meta? sess-bot)))

;; ========================================
;; Pure unification
;; ========================================

(test-case "try-unify-session-pure: identical → self"
  (define s (sess-send (expr-Nat) (sess-recv (expr-String) (sess-end))))
  (check-equal? (try-unify-session-pure s s) s))

(test-case "try-unify-session-pure: bot → other side"
  (define s (sess-send (expr-Nat) (sess-end)))
  (check-equal? (try-unify-session-pure sess-bot s) s)
  (check-equal? (try-unify-session-pure s sess-bot) s))

(test-case "try-unify-session-pure: incompatible → #f"
  (check-false (try-unify-session-pure (sess-send (expr-Nat) (sess-end))
                                        (sess-recv (expr-Nat) (sess-end))))
  (check-false (try-unify-session-pure (sess-send (expr-Nat) (sess-end))
                                        (sess-end)))
  (check-false (try-unify-session-pure (sess-svar 0) (sess-svar 1))))

(test-case "try-unify-session-pure: meta → concrete side"
  (define m (sess-meta 'test))
  (define s (sess-send (expr-Nat) (sess-end)))
  (check-equal? (try-unify-session-pure m s) s)
  (check-equal? (try-unify-session-pure s m) s))

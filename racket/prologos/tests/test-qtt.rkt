#lang racket/base

;;;
;;; Tests for qtt.rkt — Port of test-0f.maude
;;;

(require rackunit
         "../prelude.rkt"
         "../syntax.rkt"
         "../substitution.rkt"
         "../reduction.rkt"
         "../qtt.rkt")

;; ========================================
;; Usage context operations
;; ========================================

(test-case "zero-usage of length 3"
  (check-equal? (zero-usage 3) '(m0 m0 m0)))

(test-case "single-usage(1, 3) — m1 at position 1"
  (check-equal? (single-usage 1 3) '(m0 m1 m0)))

(test-case "add-usage"
  (check-equal? (add-usage '(m0 m1) '(m1 m0)) '(m1 m1)))

;; ---- join-usage: the ALTERNATION combinator (2026-07-30) ----
;; NOTE the `add-usage` case above does NOT discriminate the two operators —
;; '(m0 m1) and '(m1 m0) share no m1 position, so join gives '(m1 m1) too.
;; These cases are chosen to actually distinguish them.

(test-case "join-usage: m1 in the SAME position joins to m1, not mw"
  ;; the discriminating case — add-usage would give '(mw)
  (check-equal? (join-usage '(m1) '(m1)) '(m1))
  (check-equal? (add-usage  '(m1) '(m1)) '(mw)))

(test-case "join-usage: pointwise over a mixed vector"
  (check-equal? (join-usage '(m0 m1 mw) '(m1 m1 m0)) '(m1 m1 mw)))

(test-case "join-usage: shorter vector is treated as all-m0 (lattice bottom)"
  (check-equal? (join-usage '() '(m1 m0)) '(m1 m0))
  (check-equal? (join-usage '(m1 m0) '()) '(m1 m0))
  (check-equal? (join-usage '() '()) '()))

(test-case "join-usage: idempotent — the property add-usage does NOT have"
  ;; qtt.rkt's D2 note records idempotence as REFUTED for add-usage; that was
  ;; about the tensor. The join has it.
  (check-equal? (join-usage '(m0 m1 mw) '(m0 m1 mw)) '(m0 m1 mw))
  (check-equal? (add-usage  '(m0 m1 mw) '(m0 m1 mw)) '(m0 mw mw)))

(test-case "scale-usage with m0 (erased)"
  (check-equal? (scale-usage 'm0 '(m1 mw)) '(m0 m0)))

(test-case "scale-usage with mw"
  (check-equal? (scale-usage 'mw '(m1 m0)) '(mw m0)))

;; ========================================
;; check-all-usages
;; ========================================

(test-case "check-all-usages: omega allows zero usage"
  (check-true (check-all-usages (ctx-extend ctx-empty (expr-Nat) 'mw) '(m0))))

(test-case "check-all-usages: linear used once"
  (check-true (check-all-usages (ctx-extend ctx-empty (expr-Nat) 'm1) '(m1))))

(test-case "check-all-usages: linear used zero — incompatible"
  (check-false (check-all-usages (ctx-extend ctx-empty (expr-Nat) 'm1) '(m0))))

(test-case "check-all-usages: erased used once — incompatible"
  (check-false (check-all-usages (ctx-extend ctx-empty (expr-Nat) 'm0) '(m1))))

;; ========================================
;; inferQ basic tests
;; ========================================

(test-case "inferQ: zero has type Nat, zero usage"
  (check-equal? (inferQ ctx-empty (expr-zero)) (tu (expr-Nat) '())))

(test-case "inferQ: bvar(0) in context [Nat:mw] — uses position 0 once"
  (check-equal? (inferQ (ctx-extend ctx-empty (expr-Nat) 'mw) (expr-bvar 0))
                (tu (expr-Nat) '(m1))))

;; ========================================
;; QTT: Unrestricted identity
;; ========================================

(test-case "checkQ: unrestricted identity lam(mw, Nat, bvar(0)) : Pi(mw, Nat, Nat)"
  (check-equal? (checkQ ctx-empty
                        (expr-lam 'mw (expr-Nat) (expr-bvar 0))
                        (expr-Pi 'mw (expr-Nat) (expr-Nat)))
                (bu #t '())))

(test-case "checkQ-top: unrestricted identity"
  (check-true (checkQ-top ctx-empty
                          (expr-lam 'mw (expr-Nat) (expr-bvar 0))
                          (expr-Pi 'mw (expr-Nat) (expr-Nat)))))

;; ========================================
;; QTT: Linear identity
;; ========================================

(test-case "checkQ: linear identity lam(m1, Nat, bvar(0)) : Pi(m1, Nat, Nat)"
  (check-equal? (checkQ ctx-empty
                        (expr-lam 'm1 (expr-Nat) (expr-bvar 0))
                        (expr-Pi 'm1 (expr-Nat) (expr-Nat)))
                (bu #t '())))

(test-case "checkQ-top: linear identity"
  (check-true (checkQ-top ctx-empty
                          (expr-lam 'm1 (expr-Nat) (expr-bvar 0))
                          (expr-Pi 'm1 (expr-Nat) (expr-Nat)))))

;; ========================================
;; QTT: Erased constant
;; ========================================

(test-case "checkQ: erased constant lam(m0, Nat, zero) : Pi(m0, Nat, Nat)"
  (check-equal? (checkQ ctx-empty
                        (expr-lam 'm0 (expr-Nat) (expr-zero))
                        (expr-Pi 'm0 (expr-Nat) (expr-Nat)))
                (bu #t '())))

(test-case "checkQ-top: erased constant"
  (check-true (checkQ-top ctx-empty
                          (expr-lam 'm0 (expr-Nat) (expr-zero))
                          (expr-Pi 'm0 (expr-Nat) (expr-Nat)))))

;; ========================================
;; NEGATIVE: Erased variable used at runtime
;; ========================================

(test-case "checkQ: erased variable used — fails"
  (let ([r (checkQ ctx-empty
                   (expr-lam 'm0 (expr-Nat) (expr-bvar 0))
                   (expr-Pi 'm0 (expr-Nat) (expr-Nat)))])
    (check-false (bu-ok? r))))

(test-case "checkQ-top: erased variable used — fails"
  (check-false (checkQ-top ctx-empty
                           (expr-lam 'm0 (expr-Nat) (expr-bvar 0))
                           (expr-Pi 'm0 (expr-Nat) (expr-Nat)))))

;; ========================================
;; NEGATIVE: Linear variable not used
;; ========================================

(test-case "checkQ: linear variable not used — fails"
  (let ([r (checkQ ctx-empty
                   (expr-lam 'm1 (expr-Nat) (expr-zero))
                   (expr-Pi 'm1 (expr-Nat) (expr-Nat)))])
    (check-false (bu-ok? r))))

(test-case "checkQ-top: linear variable not used — fails"
  (check-false (checkQ-top ctx-empty
                           (expr-lam 'm1 (expr-Nat) (expr-zero))
                           (expr-Pi 'm1 (expr-Nat) (expr-Nat)))))

;; ========================================
;; QTT: Application — usage combination
;; ========================================

(test-case "inferQ: app(ann(id, Pi), zero) — zero total usage"
  (check-equal? (inferQ ctx-empty
                        (expr-app (expr-ann (expr-lam 'mw (expr-Nat) (expr-bvar 0))
                                            (expr-Pi 'mw (expr-Nat) (expr-Nat)))
                                  (expr-zero)))
                (tu (expr-Nat) '())))

(test-case "inferQ: app(id, bvar(0)) in [Nat:mw] — usage mw"
  (check-equal? (inferQ (ctx-extend ctx-empty (expr-Nat) 'mw)
                        (expr-app (expr-ann (expr-lam 'mw (expr-Nat) (expr-bvar 0))
                                            (expr-Pi 'mw (expr-Nat) (expr-Nat)))
                                  (expr-bvar 0)))
                (tu (expr-Nat) '(mw))))

(test-case "inferQ: app(linear-id, bvar(0)) in [Nat:m1] — usage m1"
  (check-equal? (inferQ (ctx-extend ctx-empty (expr-Nat) 'm1)
                        (expr-app (expr-ann (expr-lam 'm1 (expr-Nat) (expr-bvar 0))
                                            (expr-Pi 'm1 (expr-Nat) (expr-Nat)))
                                  (expr-bvar 0)))
                (tu (expr-Nat) '(m1))))

(test-case "checkQ-top: linear app in [Nat:m1] — linear used once"
  (check-true (checkQ-top (ctx-extend ctx-empty (expr-Nat) 'm1)
                          (expr-app (expr-ann (expr-lam 'm1 (expr-Nat) (expr-bvar 0))
                                              (expr-Pi 'm1 (expr-Nat) (expr-Nat)))
                                    (expr-bvar 0))
                          (expr-Nat))))

;; ========================================
;; NEGATIVE: Linear variable duplicated
;; ========================================

(test-case "checkQ-top: linear var duplicated in pair — fails"
  (check-false (checkQ-top (ctx-extend ctx-empty (expr-Nat) 'm1)
                           (expr-pair (expr-bvar 0) (expr-bvar 0))
                           (expr-Sigma (expr-Nat) (expr-Nat)))))

;; ========================================
;; Pair with proper linear split
;; ========================================

(test-case "checkQ-top: two linear vars used once each in pair"
  (check-true (checkQ-top (ctx-extend (ctx-extend ctx-empty (expr-Nat) 'm1) (expr-Nat) 'm1)
                          (expr-pair (expr-bvar 1) (expr-bvar 0))
                          (expr-Sigma (expr-Nat) (expr-Nat)))))

;; ========================================
;; Branch alternation: eliminator branches JOIN, they do not ADD (2026-07-30)
;; ========================================
;; An eliminator runs exactly ONE branch, so a linear variable used once in each
;; branch is used exactly once on every execution path. Before this change the
;; branches were combined with semiring addition (m1 + m1 = mw) and such code was
;; rejected. The SCRUTINEE still adds — it always runs. See qtt.rkt § boolrec.
;; A constant motive (fn [_ : Bool] Nat) keeps these about usage, not types.

(define bool-motive-nat (expr-lam 'mw (expr-Bool) (expr-Nat)))

(test-case "checkQ-top: linear var used once in EACH boolrec branch — legal"
  ;; THE regression pin. ctx = [b :1 Nat, c :w Bool]; bvar1 = b, bvar0 = c.
  (check-true
   (checkQ-top (ctx-extend (ctx-extend ctx-empty (expr-Nat) 'm1) (expr-Bool) 'mw)
               (expr-boolrec bool-motive-nat
                             (expr-bvar 1)     ;; true  branch uses b
                             (expr-bvar 1)     ;; false branch uses b
                             (expr-bvar 0))    ;; scrutinee is c
               (expr-Nat))))

(test-case "checkQ-top: linear var used TWICE IN ONE branch — still fails"
  ;; Within a branch the uses still ADD. Guards against a fix that joined
  ;; everything instead of only branch-vs-branch.
  (check-false
   (checkQ-top (ctx-extend (ctx-extend ctx-empty (expr-Nat) 'm1) (expr-Bool) 'mw)
               (expr-boolrec (expr-lam 'mw (expr-Bool) (expr-Sigma (expr-Nat) (expr-Nat)))
                             (expr-pair (expr-bvar 1) (expr-bvar 1))  ;; b twice, one branch
                             (expr-pair (expr-bvar 1) (expr-bvar 1))
                             (expr-bvar 0))
               (expr-Sigma (expr-Nat) (expr-Nat)))))

(test-case "checkQ-top: linear scrutinee ADDS to the branch join — fails"
  ;; b in the scrutinee AND in both branches = two uses on every path. Pins that
  ;; the rule is add(scrutinee, join(branches)) and NOT a flat 3-way join, which
  ;; would wrongly accept this.
  (check-false
   (checkQ-top (ctx-extend ctx-empty (expr-Bool) 'm1)
               (expr-boolrec (expr-lam 'mw (expr-Bool) (expr-Bool))
                             (expr-bvar 0)
                             (expr-bvar 0)
                             (expr-bvar 0))   ;; scrutinee is the same linear b
               (expr-Bool))))

;; ========================================
;; Vec / Fin usage rules (QTT P5, 2026-07-30)
;; ========================================
;; These eight nodes were flagged "unsupported" by driver.rkt's
;; `contains-unsupported-qtt?`, which made the driver SKIP multiplicity checking
;; for any def containing one. Arming them here is what allows that guard to be
;; deleted. Type/length INDICES are erased and contribute no usage; runtime
;; sub-terms contribute their own — the split is proven by whnf's own rules,
;; which discard the indices and consume only head/tail.
;;
;; vnil/vcons/fzero/fsuc are CHECK-only (typing-core has no infer arm for them
;; either), so they are checkQ arms; the eliminators are inferQ arms.

(test-case "checkQ: vnil has zero usage (its type index is erased)"
  (check-equal? (checkQ (ctx-extend ctx-empty (expr-Nat) 'm1)
                        (expr-vnil (expr-Nat))
                        (expr-Vec (expr-Nat) (expr-zero)))
                (bu #t '(m0))))

(test-case "checkQ: vcons ADDS head and tail usage — both are stored"
  ;; ctx = [y :1 Nat]; consing y once into a 1-vector uses it exactly once.
  (check-true
   (checkQ-top (ctx-extend ctx-empty (expr-Nat) 'm1)
               (expr-vcons (expr-Nat) (expr-zero)
                           (expr-bvar 0)
                           (expr-vnil (expr-Nat)))
               (expr-Vec (expr-Nat) (expr-suc (expr-zero))))))

(test-case "checkQ: a linear value consed TWICE is a violation"
  ;; head and tail both mention y — add-usage, not join: both are stored.
  (check-false
   (checkQ-top (ctx-extend ctx-empty (expr-Nat) 'm1)
               (expr-vcons (expr-Nat) (expr-suc (expr-zero))
                           (expr-bvar 0)
                           (expr-vcons (expr-Nat) (expr-zero)
                                       (expr-bvar 0)
                                       (expr-vnil (expr-Nat))))
               (expr-Vec (expr-Nat) (expr-suc (expr-suc (expr-zero)))))))

(test-case "inferQ: vhead passes the SUBJECT's usage through (the fst/snd stance)"
  ;; The discarded tail is weakening, invisible to variable-level accounting —
  ;; exactly as `fst` discarding a pair's second component is.
  (define ctx1 (ctx-extend ctx-empty (expr-Vec (expr-Nat) (expr-suc (expr-zero))) 'm1))
  (check-equal? (inferQ ctx1 (expr-vhead (expr-Nat) (expr-zero) (expr-bvar 0)))
                (tu (expr-Nat) '(m1))))

(test-case "inferQ: vtail likewise passes subject usage through"
  (define ctx1 (ctx-extend ctx-empty (expr-Vec (expr-Nat) (expr-suc (expr-zero))) 'm1))
  (check-equal? (inferQ ctx1 (expr-vtail (expr-Nat) (expr-zero) (expr-bvar 0)))
                (tu (expr-Vec (expr-Nat) (expr-zero)) '(m1))))

(test-case "checkQ: fzero is zero usage; fsuc counts its inner Fin"
  (check-equal? (checkQ (ctx-extend ctx-empty (expr-Nat) 'm1)
                        (expr-fzero (expr-zero))
                        (expr-Fin (expr-suc (expr-zero))))
                (bu #t '(m0)))
  ;; fsuc(zero, fzero(zero)) : Fin(suc zero) — inner contributes its own usage,
  ;; which for a closed fzero is none.
  (check-equal? (checkQ (ctx-extend ctx-empty (expr-Nat) 'm1)
                        (expr-fsuc (expr-zero) (expr-fzero (expr-zero)))
                        (expr-Fin (expr-suc (expr-zero))))
                (bu #t '(m0))))

;; ---- linear-per-path: branches must AGREE about each linear resource ----
;; Owner ruling 2026-07-30 (design doc §1). `mult-join` stays the honest lub, so
;; m0 ⊔ m1 = m1; a separate agreement guard supplies linear-per-path. Without it
;; a linear resource consumed on SOME paths and dropped on others type-checks —
;; which in a language with no implicit destructor is a leak, not laxity.

(test-case "checkQ-top: linear var consumed in ONE branch only — fails (leak)"
  ;; THE P3 pin. Accepted before the agreement guard (m0 ⊔ m1 = m1).
  ;; ctx = [b :1 Nat, c :w Bool]; bvar1 = b, bvar0 = c.
  (check-false
   (checkQ-top (ctx-extend (ctx-extend ctx-empty (expr-Nat) 'm1) (expr-Bool) 'mw)
               (expr-boolrec bool-motive-nat
                             (expr-bvar 1)     ;; true branch consumes b
                             (expr-zero)       ;; false branch DROPS it
                             (expr-bvar 0))
               (expr-Nat))))

(test-case "checkQ-top: the guard fires ONLY at linear positions"
  ;; The identical shape with the variable declared UNRESTRICTED must stay legal,
  ;; or the guard would reject ordinary code en masse (drift risk 2).
  (check-true
   (checkQ-top (ctx-extend (ctx-extend ctx-empty (expr-Nat) 'mw) (expr-Bool) 'mw)
               (expr-boolrec bool-motive-nat
                             (expr-bvar 1)
                             (expr-zero)
                             (expr-bvar 0))
               (expr-Nat))))

(test-case "checkQ-top: an ERASED var dropped in one branch is unaffected"
  ;; m0 positions are not the guard's business — using an erased var at all is
  ;; already caught by `compatible m0 m1`, and NOT using it is correct.
  (check-true
   (checkQ-top (ctx-extend (ctx-extend ctx-empty (expr-Nat) 'm0) (expr-Bool) 'mw)
               (expr-boolrec bool-motive-nat
                             (expr-zero)
                             (expr-zero)
                             (expr-bvar 0))
               (expr-Nat))))

(test-case "checkQ-top: linear var used in NEITHER branch — still fails"
  ;; The join must not turn "unused" into "used": m0 ⊔ m0 = m0, and m1 demands
  ;; exactly one use.
  (check-false
   (checkQ-top (ctx-extend (ctx-extend ctx-empty (expr-Nat) 'm1) (expr-Bool) 'mw)
               (expr-boolrec bool-motive-nat
                             (expr-zero)
                             (expr-zero)
                             (expr-bvar 0))
               (expr-Nat))))

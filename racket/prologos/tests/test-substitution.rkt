#lang racket/base

;;;
;;; Tests for substitution.rkt — Port of test-0b.maude
;;;

(require rackunit
         "../prelude.rkt"
         "../syntax.rkt"
         "../substitution.rkt")

;; ========================================
;; Shift tests
;; ========================================

(test-case "shift: bvar(0) by 1 at cutoff 0 -> bvar(1)"
  (check-equal? (shift 1 0 (expr-bvar 0)) (expr-bvar 1)))

(test-case "shift: bvar(0) by 1 at cutoff 1 -> bvar(0) (below cutoff)"
  (check-equal? (shift 1 1 (expr-bvar 0)) (expr-bvar 0)))

(test-case "shift: bvar(2) by 1 at cutoff 0 -> bvar(3)"
  (check-equal? (shift 1 0 (expr-bvar 2)) (expr-bvar 3)))

(test-case "shift: free variable unchanged"
  (check-equal? (shift 1 0 (expr-fvar 'x)) (expr-fvar 'x)))

(test-case "shift: under lambda, bvar(0) in body (lambda's own binding) unchanged"
  (check-equal? (shift 1 0 (expr-lam 'mw (expr-Nat) (expr-bvar 0)))
                (expr-lam 'mw (expr-Nat) (expr-bvar 0))))

(test-case "shift: under lambda, bvar(1) in body (refers outside) shifted to bvar(2)"
  (check-equal? (shift 1 0 (expr-lam 'mw (expr-Nat) (expr-bvar 1)))
                (expr-lam 'mw (expr-Nat) (expr-bvar 2))))

(test-case "shift: constant zero unchanged"
  (check-equal? (shift 1 0 (expr-zero)) (expr-zero)))

(test-case "shift: app(bvar(0), bvar(1)) -> app(bvar(1), bvar(2))"
  (check-equal? (shift 1 0 (expr-app (expr-bvar 0) (expr-bvar 1)))
                (expr-app (expr-bvar 1) (expr-bvar 2))))

;; Additional shift tests
(test-case "shift: under Pi, cutoff increases"
  (check-equal? (shift 1 0 (expr-Pi 'mw (expr-Nat) (expr-bvar 1)))
                (expr-Pi 'mw (expr-Nat) (expr-bvar 2))))

(test-case "shift: under Sigma, cutoff increases"
  (check-equal? (shift 1 0 (expr-Sigma (expr-Nat) (expr-bvar 1)))
                (expr-Sigma (expr-Nat) (expr-bvar 2))))

(test-case "shift: Nat type unchanged"
  (check-equal? (shift 1 0 (expr-Nat)) (expr-Nat)))

(test-case "shift: Bool type unchanged"
  (check-equal? (shift 1 0 (expr-Bool)) (expr-Bool)))

(test-case "shift: refl unchanged"
  (check-equal? (shift 1 0 (expr-refl)) (expr-refl)))

(test-case "shift: Type(lzero) unchanged"
  (check-equal? (shift 1 0 (expr-Type (lzero))) (expr-Type (lzero))))

(test-case "shift: suc(bvar(0)) -> suc(bvar(1))"
  (check-equal? (shift 1 0 (expr-suc (expr-bvar 0)))
                (expr-suc (expr-bvar 1))))

(test-case "shift: Vec non-binding"
  (check-equal? (shift 1 0 (expr-Vec (expr-bvar 0) (expr-bvar 1)))
                (expr-Vec (expr-bvar 1) (expr-bvar 2))))

(test-case "shift: Fin non-binding"
  (check-equal? (shift 1 0 (expr-Fin (expr-bvar 0)))
                (expr-Fin (expr-bvar 1))))

;; ========================================
;; Substitution tests
;; ========================================

(test-case "subst: matching bvar(0) replaced"
  (check-equal? (subst 0 (expr-zero) (expr-bvar 0)) (expr-zero)))

(test-case "subst: bvar(1) above target decrements to bvar(0)"
  (check-equal? (subst 0 (expr-zero) (expr-bvar 1)) (expr-bvar 0)))

(test-case "subst: free variable unchanged"
  (check-equal? (subst 0 (expr-zero) (expr-fvar 'x)) (expr-fvar 'x)))

(test-case "subst: into application (bvar above target decrements)"
  (check-equal? (subst 0 (expr-zero) (expr-app (expr-bvar 0) (expr-bvar 1)))
                (expr-app (expr-zero) (expr-bvar 0))))

(test-case "subst: under lambda, external ref replaced"
  ;; lam(mw, Nat, app(bvar(1), bvar(0))) with subst(0, zero, ...)
  ;; Under binder: K=1, S=shift(1,0,zero)=zero
  ;; subst(1, zero, app(bvar(1), bvar(0))) = app(zero, bvar(0))
  (check-equal? (subst 0 (expr-zero) (expr-lam 'mw (expr-Nat) (expr-app (expr-bvar 1) (expr-bvar 0))))
                (expr-lam 'mw (expr-Nat) (expr-app (expr-zero) (expr-bvar 0)))))

(test-case "subst: under Pi type"
  (check-equal? (subst 0 (expr-zero) (expr-Pi 'mw (expr-Nat) (expr-bvar 1)))
                (expr-Pi 'mw (expr-Nat) (expr-zero))))

(test-case "subst: suc(bvar(0))"
  (check-equal? (subst 0 (expr-zero) (expr-suc (expr-bvar 0)))
                (expr-suc (expr-zero))))

;; ========================================
;; Open tests
;; ========================================

(test-case "open: bvar(0) -> zero"
  (check-equal? (open-expr (expr-bvar 0) (expr-zero)) (expr-zero)))

(test-case "open: bvar(1) decrements to bvar(0)"
  (check-equal? (open-expr (expr-bvar 1) (expr-zero)) (expr-bvar 0)))

(test-case "open: app(bvar(0), bvar(1)) with fvar('x) — bvar(1) decrements"
  (check-equal? (open-expr (expr-app (expr-bvar 0) (expr-bvar 1)) (expr-fvar 'x))
                (expr-app (expr-fvar 'x) (expr-bvar 0))))

;; ========================================
;; Combined / beta-reduction examples
;; ========================================

(test-case "beta: identity applied to zero"
  ;; open(bvar(0), zero) = zero
  (check-equal? (open-expr (expr-bvar 0) (expr-zero)) (expr-zero)))

(test-case "beta: (lam x:Nat. suc x) applied to zero"
  ;; open(suc(bvar(0)), zero) = suc(zero)
  (check-equal? (open-expr (expr-suc (expr-bvar 0)) (expr-zero))
                (expr-suc (expr-zero))))

(test-case "beta: nested (lam x:Nat. lam y:Nat. x) applied to zero"
  ;; Body = lam(mw, Nat, bvar(1)), bvar(1) refers to outer x
  ;; open(lam(mw, Nat, bvar(1)), zero) = lam(mw, Nat, zero)
  (check-equal? (open-expr (expr-lam 'mw (expr-Nat) (expr-bvar 1)) (expr-zero))
                (expr-lam 'mw (expr-Nat) (expr-zero))))

(test-case "subst: expression containing bound vars"
  ;; subst(0, suc(bvar(0)), bvar(0)) = suc(bvar(0))
  (check-equal? (subst 0 (expr-suc (expr-bvar 0)) (expr-bvar 0))
                (expr-suc (expr-bvar 0))))

(test-case "subst: shifting replacement under lambda"
  ;; subst(0, bvar(0), lam(mw, Nat, bvar(1)))
  ;; Inside: K=1, S=shift(1,0,bvar(0))=bvar(1)
  ;; subst(1, bvar(1), bvar(1)) = bvar(1)
  ;; Result: lam(mw, Nat, bvar(1))
  (check-equal? (subst 0 (expr-bvar 0) (expr-lam 'mw (expr-Nat) (expr-bvar 1)))
                (expr-lam 'mw (expr-Nat) (expr-bvar 1))))

;; ========================================
;; Vec/Fin substitution tests
;; ========================================

(test-case "subst: Vec type"
  (check-equal? (subst 0 (expr-Nat) (expr-Vec (expr-bvar 0) (expr-zero)))
                (expr-Vec (expr-Nat) (expr-zero))))

(test-case "subst: vcons"
  (check-equal? (subst 0 (expr-zero) (expr-vcons (expr-Nat) (expr-zero) (expr-bvar 0) (expr-vnil (expr-Nat))))
                (expr-vcons (expr-Nat) (expr-zero) (expr-zero) (expr-vnil (expr-Nat)))))

(test-case "shift: vhead"
  (check-equal? (shift 1 0 (expr-vhead (expr-Nat) (expr-bvar 0) (expr-bvar 1)))
                (expr-vhead (expr-Nat) (expr-bvar 1) (expr-bvar 2))))

;; ========================================
;; Boolrec substitution tests
;; ========================================

(test-case "shift: boolrec shifts all subexpressions"
  (check-equal? (shift 1 0 (expr-boolrec (expr-bvar 0) (expr-bvar 1) (expr-bvar 2) (expr-bvar 3)))
                (expr-boolrec (expr-bvar 1) (expr-bvar 2) (expr-bvar 3) (expr-bvar 4))))

(test-case "subst: boolrec substitutes in all subexpressions"
  (check-equal? (subst 0 (expr-true) (expr-boolrec (expr-bvar 0) (expr-zero) (expr-suc (expr-zero)) (expr-bvar 0)))
                (expr-boolrec (expr-true) (expr-zero) (expr-suc (expr-zero)) (expr-true))))

(test-case "shift: boolrec with constants unchanged"
  (check-equal? (shift 1 0 (expr-boolrec (expr-lam 'mw (expr-Bool) (expr-Nat)) (expr-zero) (expr-suc (expr-zero)) (expr-true)))
                (expr-boolrec (expr-lam 'mw (expr-Bool) (expr-Nat)) (expr-zero) (expr-suc (expr-zero)) (expr-true))))

;; ========================================
;; Substitution containment (SUB.1, 2026-07-24)
;; docs/tracking/2026-07-24_SUBSTITUTION_CONTAINMENT_DEFECT.md
;; ========================================
;; Ruling (D): runtime collection values (champ/hset/rrb + transients) are
;; CLOSED runtime values — shift/subst identity on them is the CONTRACT, not
;; the bug. The bug is that `nf` can CONSTRUCT an open container (normalizing
;; a lambda body without opening the binder); the invariant is owned by the
;; SUB.3 fix (NbE open-the-binder) and guarded meanwhile by the tripwire at
;; the three nf-persisting boundaries. These tests pin (a) the closed-leaf
;; contract, (b) the depth-aware tripwire predicate, (c) a BUG-PIN of the nf
;; mint that FLIPS when SUB.3 lands.

(require (only-in "../reduction.rkt" nf contains-open-container?)
         (only-in "../champ.rkt" champ-empty champ-insert champ-entries)
         (only-in "../rrb.rkt" rrb-from-list))

(define (mk-champ k v)
  (expr-champ (champ-insert champ-empty (equal-hash-code k) k v)))
(define ka (expr-keyword ':a))

;; (a) the closed-leaf CONTRACT under ruling (D)
(test-case "SUB contract: subst over a champ is identity (champ = closed value)"
  (define c (mk-champ ka (expr-bvar 0)))
  (check-true (eq? (subst 0 (expr-int 42) c) c)))

(test-case "SUB contract: shift over a champ is identity"
  (define c (mk-champ ka (expr-bvar 0)))
  (check-true (eq? (shift 1 0 c) c)))

(test-case "SUB contract: subst/shift over hset and rrb are identity"
  (define h (expr-hset (champ-insert champ-empty (equal-hash-code ka) ka (expr-bvar 0))))
  (define r (expr-rrb (rrb-from-list (list (expr-bvar 0)))))
  (check-true (eq? (subst 0 (expr-int 42) h) h))
  (check-true (eq? (shift 1 0 h) h))
  (check-true (eq? (subst 0 (expr-int 42) r) r))
  (check-true (eq? (shift 1 0 r) r)))

;; (b) the tripwire predicate — depth-aware freeness w.r.t. the container
(test-case "SUB predicate: champ holding a free bvar fires"
  (check-true (contains-open-container? (mk-champ ka (expr-bvar 0)))))

(test-case "SUB predicate: the poisoned shape under its binder fires (the repro)"
  (check-true (contains-open-container?
               (expr-lam 'mw (expr-Nat) (mk-champ ka (expr-bvar 0))))))

(test-case "SUB predicate: champ holding a CLOSED lambda does NOT fire (the control)"
  ;; answer row {:f λy.y} — bvar bound INSIDE the container is legal
  (check-false (contains-open-container?
                (mk-champ (expr-keyword ':f)
                          (expr-lam 'mw (expr-Nat) (expr-bvar 0))))))

(test-case "SUB predicate: ground champ does not fire"
  (check-false (contains-open-container? (mk-champ ka (expr-int 42)))))

(test-case "SUB predicate: bvar outside any container does not fire"
  (check-false (contains-open-container? (expr-lam 'mw (expr-Nat) (expr-bvar 0)))))

(test-case "SUB predicate: NESTED poison — champ{:f λy.champ{:a y}} fires"
  ;; the inner champ captures y across ITS boundary even though y is bound
  ;; within the OUTER champ — freeness is w.r.t. the innermost container
  (check-true (contains-open-container?
               (mk-champ (expr-keyword ':f)
                         (expr-lam 'mw (expr-Nat)
                                   (mk-champ ka (expr-bvar 0)))))))

(test-case "SUB predicate: open bvar deeper in a container entry's spine fires"
  ;; {:a [add y 1]} under the binder — the stuck spine holds a free bvar
  (check-true (contains-open-container?
               (mk-champ ka (expr-app (expr-fvar 'add) (expr-bvar 0))))))

(test-case "SUB predicate: rrb holding a free bvar fires"
  (check-true (contains-open-container?
               (expr-rrb (rrb-from-list (list (expr-bvar 0)))))))

;; (c) SUB.3 (ruling D) — FLIPPED from the SUB.1 BUG-PIN: nf opens the binder
;; NbE-style (#%nbe fvar, re-abstraction), so the normalized body carries NO
;; open container and beta after nf computes the right value.

(require (only-in "../reduction.rkt" whnf)
         (only-in racket/match match))

(define lam-with-map-body
  (expr-lam 'mw (expr-Nat)
            (expr-map-assoc (expr-map-empty (expr-hole) (expr-hole))
                            ka (expr-bvar 0))))

(define (champ-entries-sorted e)
  (match e
    [(expr-champ c)
     (sort (champ-entries c) string<? #:key (lambda (kv) (format "~a" (car kv))))]
    [_ #f]))

(test-case "SUB.3: nf under a binder yields NO open container (flipped BUG-PIN)"
  (define lam* (nf lam-with-map-body))
  (check-false (contains-open-container? lam*)
               "NbE nf must not mint an open champ")
  ;; beta over the nf'd body computes the right map
  (define applied (whnf (subst 0 (expr-int 42) (expr-lam-body lam*))))
  (check-equal? (champ-entries-sorted applied)
                (list (cons ka (expr-int 42)))
                "the substituted value reaches the map"))

(test-case "SUB.3: nested binders — both params reach the map"
  (define inner
    (expr-lam 'mw (expr-Nat)
              (expr-map-assoc
               (expr-map-assoc (expr-map-empty (expr-hole) (expr-hole))
                               ka (expr-bvar 1))          ;; outer param
               (expr-keyword ':b) (expr-bvar 0))))        ;; inner param
  (define outer (expr-lam 'mw (expr-Nat) inner))
  (define outer* (nf outer))
  (check-false (contains-open-container? outer*))
  (define inner* (subst 0 (expr-int 10) (expr-lam-body outer*)))
  (define applied (whnf (subst 0 (expr-int 20) (expr-lam-body inner*))))
  (check-equal? (champ-entries-sorted applied)
                (list (cons ka (expr-int 10))
                      (cons (expr-keyword ':b) (expr-int 20)))))

(test-case "SUB.3: Pi codomain opens too"
  (define pi (expr-Pi 'mw (expr-Nat)
                      (expr-map-assoc (expr-map-empty (expr-hole) (expr-hole))
                                      ka (expr-bvar 0))))
  (check-false (contains-open-container? (nf pi))))

(test-case "SUB.3: an OPEN KEY re-abstracts (keys are walked, not just values)"
  (define lam-open-key
    (expr-lam 'mw (expr-Nat)
              (expr-map-assoc (expr-map-empty (expr-hole) (expr-hole))
                              (expr-bvar 0) (expr-int 7))))
  (define lam* (nf lam-open-key))
  (check-false (contains-open-container? lam*))
  (define applied (whnf (subst 0 ka (expr-lam-body lam*))))
  (check-equal? (champ-entries-sorted applied)
                (list (cons ka (expr-int 7)))))

(test-case "SUB.3: a CLOSED map body still normalizes to a champ (no spine regression)"
  (define lam-closed
    (expr-lam 'mw (expr-Nat)
              (expr-map-assoc (expr-map-empty (expr-hole) (expr-hole))
                              ka (expr-int 1))))
  (define lam* (nf lam-closed))
  (check-true (expr-champ? (expr-lam-body lam*))
              "closed contents keep the runtime champ representation"))

;; ── SUB.3 hot-scan: armed walk ≡ reflective oracle (differential contract) ──
;; The production contains-open-container? carries explicit arms for hot node
;; kinds; the fully-reflective twin is the oracle. Poison is planted in EVERY
;; armed field position; clean twins guard the negative side. Any arm that
;; misses a field diverges from the oracle HERE, not in production.

(require (only-in "../reduction.rkt" contains-open-container?/reflective)
         (only-in "../syntax.rkt"
                  expr-map-get expr-suc expr-pvec-literal expr-snd
                  expr-reduce expr-reduce-arm expr-logic-var))

(define POISON (mk-champ ka (expr-bvar 0)))          ;; champ trapping a bvar
(define CLEAN  (mk-champ ka (expr-int 1)))

(define (both-agree label term)
  (check-equal? (contains-open-container? term)
                (contains-open-container?/reflective term)
                label))

(test-case "SUB.3 hot-scan: armed ≡ reflective over the field battery"
  (define battery
    (list
     ;; poison in each armed field position
     (expr-app POISON (expr-int 1))
     (expr-app (expr-int 1) POISON)
     (expr-pair POISON (expr-int 1))
     (expr-pair (expr-int 1) POISON)
     (expr-suc POISON)
     (expr-fst POISON)
     (expr-snd POISON)
     (expr-map-assoc POISON ka (expr-int 1))
     (expr-map-assoc (expr-map-empty (expr-hole) (expr-hole)) POISON (expr-int 1))
     (expr-map-assoc (expr-map-empty (expr-hole) (expr-hole)) ka POISON)
     (expr-map-get POISON ka #f)
     (expr-map-get (expr-map-empty (expr-hole) (expr-hole)) POISON #f)
     ;; P2.b slice 4: the STRICTNESS field is an armed position — poison must
     ;; be reachable there too (the every-armed-field-position contract)
     (expr-map-get (expr-map-empty (expr-hole) (expr-hole)) ka POISON)
     (expr-pvec-literal (list (expr-int 1) POISON))
     ;; binder positions: poison + the bound/free distinction
     (expr-lam 'mw POISON (expr-int 1))
     (expr-lam 'mw (expr-Nat) POISON)
     (expr-lam 'mw (expr-Nat) (mk-champ ka (expr-bvar 0)))   ;; free at champ → fires
     (mk-champ ka (expr-lam 'mw (expr-Nat) (expr-bvar 0)))   ;; bound inside → clean
     (expr-Pi 'mw POISON (expr-int 1))
     (expr-Pi 'mw (expr-Nat) POISON)
     (expr-Sigma POISON (expr-int 1))
     (expr-Sigma (expr-Nat) POISON)
     (expr-reduce POISON '() #f)
     (expr-reduce (expr-int 1)
                  (list (expr-reduce-arm 'suc 1 POISON)) #f)
     ;; cold-fallback coverage: an un-armed node (expr-boolrec)
     (expr-boolrec POISON (expr-int 1) (expr-int 2) (expr-int 3))
     ;; leaves + clean twins
     (expr-logic-var 'x 'in)
     (expr-fvar 'f)
     CLEAN
     (expr-app CLEAN CLEAN)
     (expr-lam 'mw (expr-Nat) (expr-app (expr-bvar 0) (expr-int 1)))
     (expr-pvec-literal (list CLEAN))))
  (for ([t (in-list battery)] [i (in-naturals)])
    (both-agree (format "battery[~a]" i) t)))

(test-case "SUB.3 hot-scan: armed detects the canonical poison + clears the control"
  (check-true (contains-open-container? (expr-lam 'mw (expr-Nat) POISON)))
  (check-false (contains-open-container?
                (mk-champ (expr-keyword ':f)
                          (expr-lam 'mw (expr-Nat) (expr-bvar 0))))))

;; ========================================
;; `occurs?` sees a meta inside a CONTAINER (substitution-containment, META half)
;; ========================================
;;
;; The containment defect's bvar half was closed by the NbE fix; the META half
;; stayed open with an explicit next step — "a probe of a champ carrying an
;; UNSOLVED meta through zonk and through `occurs?`; `occurs?` is the
;; higher-stakes one (an unsound occur-check admits cyclic solutions)."
;;
;; Probed 2026-08-03 and it WAS unsound: `occurs?` walks structs generically via
;; `struct->vector`, and a champ/hset/rrb stores its entries in a RACKET VECTOR
;; inside its nodes. `(vector? …)` is not `(struct? …)`, so the walk stopped
;; dead there and answered #f for a meta that was plainly present.
;;
;; The controls are what make this a test rather than a demonstration: the same
;; meta in a Record field and in a plain application always answered #t, so a
;; test that only checked those would have passed throughout.

(require (only-in "../unify.rkt" occurs?)
         (only-in "../champ.rkt" champ-empty champ-insert)
         (only-in "../rrb.rkt" rrb-from-list))

(define occ-meta (expr-meta 'occ-probe #f))
(define occ-key (expr-keyword 'a))

(test-case "occurs?: a meta inside a champ VALUE is found"
  (check-true (occurs? 'occ-probe
                       (expr-champ (champ-insert champ-empty
                                                 (equal-hash-code occ-key)
                                                 occ-key occ-meta)))))

(test-case "occurs?: a meta inside an hset KEY is found"
  ;; The key position matters separately — a set stores the term AS the key.
  (check-true (occurs? 'occ-probe
                       (expr-hset (champ-insert champ-empty
                                                (equal-hash-code occ-meta)
                                                occ-meta #t)))))

(test-case "occurs?: a meta inside an rrb ELEMENT is found"
  (check-true (occurs? 'occ-probe (expr-rrb (rrb-from-list (list occ-meta))))))

(test-case "occurs?: the controls that always passed, and the negative"
  ;; bare meta and plain application answered #t before the fix too — asserting
  ;; only these is how the container gap stayed invisible.
  (check-true (occurs? 'occ-probe occ-meta))
  (check-true (occurs? 'occ-probe (expr-app (expr-fvar 'f) occ-meta)))
  ;; and a DIFFERENT meta must still not be found, or the fix is just "yes"
  (check-false (occurs? 'other-meta
                        (expr-champ (champ-insert champ-empty
                                                  (equal-hash-code occ-key)
                                                  occ-key occ-meta)))))

;; ========================================
;; `conv-nf` sees INTO containers too (same defect family, opposite direction)
;; ========================================
;;
;; `conv-nf` walks structs generically and stopped at the same RACKET VECTOR
;; `occurs?` did — so container entries fell to `equal?`, which is STRICTER
;; than conv: no hole-as-wildcard, no meta-identity rule.
;;
;; The failure direction is the OPPOSITE of `occurs?`'s and is why this one is
;; not a soundness bug: it answered #f where conv should say #t, so it could
;; REJECT a valid conversion but never ACCEPT an invalid one. Both negatives
;; below are asserted for exactly that reason — a "fix" that just returns #t
;; for containers would satisfy the positives alone.

(require (only-in "../reduction.rkt" conv-nf))

(define conv-key (expr-keyword 'a))
(define (conv-map v)
  (expr-champ (champ-insert champ-empty (equal-hash-code conv-key) conv-key v)))

(test-case "conv-nf: a hole inside a champ VALUE acts as a wildcard"
  (check-true (conv-nf (conv-map (expr-hole)) (conv-map (expr-Int)))))

(test-case "conv-nf: a hole inside an rrb ELEMENT acts as a wildcard"
  (check-true (conv-nf (expr-rrb (rrb-from-list (list (expr-hole))))
                       (expr-rrb (rrb-from-list (list (expr-Int)))))))

(test-case "conv-nf: containers with DIFFERENT contents still differ"
  ;; The negatives that keep the fix honest.
  (check-false (conv-nf (conv-map (expr-Int)) (conv-map (expr-Nat))))
  (check-false (conv-nf (expr-rrb (rrb-from-list (list (expr-Int))))
                        (expr-rrb (rrb-from-list (list (expr-Nat)))))))

(test-case "conv-nf: identical containers convert (control)"
  (check-true (conv-nf (conv-map (expr-Int)) (conv-map (expr-Int)))))

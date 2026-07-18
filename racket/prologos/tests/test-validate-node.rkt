#lang racket/base
;; ============================================================================
;; CIU T6 F1b.5-s2 — expr-validate NODE unit tests (engine level, no surface).
;; The tabulation semantics (ok/err/fill/check/panic/closed/stuck) + the
;; pipeline-walker contract (validate-map-exprs is the single reconstruction
;; point shift/subst/zonk/nf/pp share — the record-map-field-types pattern).
;; Pure-Racket (the test-subtyping convention): no fixture, no network.
;; ============================================================================

(require rackunit
         racket/list
         "../syntax.rkt"
         (only-in "../reduction.rkt" nf definitely-not-map?)
         (only-in "../substitution.rkt" shift subst)
         (only-in "../macros.rkt" subst-underscore normalize-check-pred)
         "../pretty-print.rkt")

(define names (list 'prologos::data::result::Result 'prologos::data::reason::Reason
                    'prologos::data::result::ok 'prologos::data::result::err
                    'prologos::data::reason::missing-required
                    'prologos::data::reason::check-failed
                    'prologos::data::reason::type-mismatch
                    'prologos::data::reason::unexpected-field
                    ;; F1b.7a: index 8 — the Layer B guard's Reason ctor
                    'prologos::data::reason::check-unevaluable))

(define (mk-subj . kvs)
  (let loop ([kvs kvs] [m (expr-map-empty (expr-hole) (expr-hole))])
    (if (null? kvs) m
        (loop (cddr kvs) (expr-map-assoc m (expr-keyword (car kvs)) (cadr kvs))))))

;; F1b.5-s4: plan entries carry a 7th slot required-on-miss? — #t here
;; (schema-style: every field required). A selection sets it #f for optional
;; (non-:requires) fields; see validate-node/selection-optional-field-skips.
(define plan-basic (list (list 'name '(prim String) #f #f "String" #f #t)
                         (list 'age  '(prim Nat Int) #f #f "Int" #f #t)))

(define (v-nf sname closed? plan subj)
  (pp-expr (nf (expr-validate sname closed? plan subj names))))

;; ---- tabulation semantics ---------------------------------------------------

(test-case "validate-node/ok-flat"
  (check-regexp-match #rx"result::ok"
                      (v-nf 'Person #f plan-basic
                            (mk-subj 'name (expr-string "alice") 'age (expr-int 30)))))

(test-case "validate-node/nat-in-int-field-witnesses"
  ;; the D28 err-polarity invariant: a Nat value in an Int field passes
  (check-regexp-match #rx"result::ok"
                      (v-nf 'Person #f plan-basic
                            (mk-subj 'name (expr-string "a") 'age (expr-nat-val 3)))))

(test-case "validate-node/type-mismatch-collects-with-payload"
  (define out (v-nf 'Person #f plan-basic
                    (mk-subj 'name (expr-string "bob") 'age (expr-string "x"))))
  (check-regexp-match #rx"result::err" out)
  (check-regexp-match #rx"type-mismatch \"Int\" \"String\"" out))

(test-case "validate-node/missing-required"
  (define out (v-nf 'Person #f plan-basic (mk-subj 'name (expr-string "gil"))))
  (check-regexp-match #rx"result::err" out)
  (check-regexp-match #rx":age prologos::data::reason::missing-required" out))

(test-case "validate-node/collect-all-two-failures"
  ;; BOTH failures reported (collect-all, never fail-fast — D27.4)
  (define out (v-nf 'Person #f plan-basic (mk-subj 'age (expr-string "x"))))
  (check-regexp-match #rx":name prologos::data::reason::missing-required" out)
  (check-regexp-match #rx":age \\[prologos::data::reason::type-mismatch" out))

(test-case "validate-node/defaults-fill-into-ok"
  (define plan-fill (list (list 'host '(prim String) (expr-string "localhost") #f "String" #f #t)
                          (list 'port '(prim Nat Int) (expr-int 8080) #f "Int" #f #t)))
  (define out (v-nf 'Cfg #f plan-fill (mk-subj)))
  (check-regexp-match #rx"result::ok" out)
  (check-regexp-match #rx":host \"localhost\"" out)
  (check-regexp-match #rx":port 8080" out))

(test-case "validate-node/check-failed"
  (define plan-chk (list (list 'age '(prim Nat Int) #f
                               (expr-lam 'mw (expr-Int) (expr-false)) "Int" "(> _ 0)" #t)))
  (define out (v-nf 'Checked #f plan-chk (mk-subj 'age (expr-int 0))))
  (check-regexp-match #rx"check-failed \"\\(> _ 0\\)\"" out))

(test-case "validate-node/check-passes"
  (define plan-chk (list (list 'age '(prim Nat Int) #f
                               (expr-lam 'mw (expr-Int) (expr-true)) "Int" "(> _ 0)" #t)))
  (check-regexp-match #rx"result::ok" (v-nf 'Checked #f plan-chk (mk-subj 'age (expr-int 5)))))

(test-case "validate-node/panic-in-pred-propagates"
  ;; D27.3: "validate inherits panic semantics, v1"
  (define plan-p (list (list 'age '(prim Nat Int) #f
                             (expr-lam 'mw (expr-Int) (expr-panic (expr-string "boom"))) "Int" "(boom)" #t)))
  (check-regexp-match #rx"panic \"boom\"" (v-nf 'Checked #f plan-p (mk-subj 'age (expr-int 1)))))

(test-case "validate-node/check-unevaluable-nonbool"
  ;; F1b.7a Layer B: a pred that reduces to a non-Bool (here a [fn ..] value —
  ;; mirrors `:check [fn [x] false]` or a stuck trait method) FAILS LOUD as
  ;; check-unevaluable; it must never silently pass (the old `else` = pass bug).
  (define plan-u (list (list 'age '(prim Nat Int) #f
                             (expr-lam 'mw (expr-Int) (expr-lam 'mw (expr-Int) (expr-false)))
                             "Int" "(fn [x] false)" #t)))
  (define out (v-nf 'Checked #f plan-u (mk-subj 'age (expr-int 5))))
  (check-regexp-match #rx"check-unevaluable" out))

(test-case "validate-node/closed-unexpected-field"
  (define out (v-nf 'Locked #t (list (list 'a '(prim Nat Int) #f #f "Int" #f #t))
                    (mk-subj 'a (expr-int 1) 'extra (expr-int 2))))
  (check-regexp-match #rx":extra prologos::data::reason::unexpected-field" out))

(test-case "validate-node/open-schema-extras-pass-through"
  ;; an OPEN schema keeps extra subject fields in the ok payload (views philosophy)
  (define out (v-nf 'Person #f plan-basic
                    (mk-subj 'name (expr-string "a") 'age (expr-int 1) 'extra (expr-int 9))))
  (check-regexp-match #rx"result::ok" out)
  (check-regexp-match #rx":extra 9" out))

(test-case "validate-node/selection-optional-field-skips"
  ;; F1b.5-s4 view semantics: a selection plan sets required?=#f for a
  ;; non-:requires parent field. Absent+no-default+not-required is a partial-view
  ;; SKIP (neither err nor filled); the :requires field still misses if absent.
  (define plan-view (list (list 'name '(prim String) #f #f "String" #f #t)   ; :requires
                          (list 'age  '(prim Nat Int) #f #f "Int" #f #f)))    ; optional (view)
  ;; :name present, :age absent → ok (age SKIPPED, not missing-required)
  (define ok-out (v-nf 'NameOnly #f plan-view (mk-subj 'name (expr-string "ada"))))
  (check-regexp-match #rx"result::ok" ok-out)
  (check-false (regexp-match? #rx"missing-required" ok-out) ":age optional — no miss")
  ;; :name absent → err (the read-capability miss)
  (define err-out (v-nf 'NameOnly #f plan-view (mk-subj 'age (expr-int 9))))
  (check-regexp-match #rx":name prologos::data::reason::missing-required" err-out))

(test-case "validate-node/skip-tag-accepts-anything"
  ;; an 'any tag (unwitnessable field type) never rejects — the D28 skip posture
  (define plan-skip (list (list 'cb 'any #f #f "<Int -> Int>" #f #t)))
  (check-regexp-match #rx"result::ok"
                      (v-nf 'WithFn #f plan-skip (mk-subj 'cb (expr-string "not-a-fn")))))

(test-case "validate-node/stuck-subject-stays-stuck"
  (define out (v-nf 'Person #f plan-basic (expr-fvar 'unknown-thing)))
  (check-regexp-match #rx"\\[validate Person unknown-thing\\]" out))

;; ---- pipeline-walker contract ----------------------------------------------

(test-case "validate-node/map-exprs-hits-exactly-the-expr-slots"
  ;; subject + each entry's default/pred — atoms pass through untouched
  (define n 0)
  (define node (expr-validate 'S #f
                              (list (list 'a '(prim Int) (expr-int 1) (expr-lam 'mw (expr-Int) (expr-true)) "Int" "p" #t)
                                    (list 'b 'any #f #f "T" #f #t))
                              (expr-int 99) names))
  (define out (validate-map-exprs (lambda (e) (set! n (add1 n)) e) node))
  (check-equal? n 3 "subject + one default + one pred")
  (check-equal? (expr-validate-schema-name out) 'S)
  (check-equal? (expr-validate-names out) names))

(test-case "validate-node/shift-subst-nonbinding-identity-on-closed"
  ;; closed node (no bvars) — shift/subst are identity-shaped walks
  (define node (expr-validate 'S #f plan-basic (mk-subj 'name (expr-string "x")) names))
  (check-true (expr-validate? (shift 1 0 node)))
  (check-true (expr-validate? (subst 0 (expr-int 1) node))))

(test-case "validate-node/definitely-not-map-exemption"
  ;; a stuck validate must NOT degrade under map-get (the D22/P6 class)
  (check-false (definitely-not-map? (expr-validate 'S #f '() (expr-fvar 'x) names))))

(test-case "validate-node/pred-lowering-polarity-golden"
  ;; the >-REVERSAL contract the bake composes (subst FIRST, then normalize):
  ;; (> _ 0)  → (> x 0)  → (lt 0 x)   [lower bound: 0 < x]
  ;; (> 10 _) → (> 10 x) → (lt x 10)  [upper bound: x < 10]
  ;; (< _ 10) → (< x 10) → (lt x 10)  [same upper bound, kept order]
  (check-equal? (normalize-check-pred (subst-underscore '(> _ 0) 'x)) '(lt 0 x))
  (check-equal? (normalize-check-pred (subst-underscore '(> 10 _) 'x)) '(lt x 10))
  (check-equal? (normalize-check-pred (subst-underscore '(< _ 10) 'x)) '(lt x 10)))

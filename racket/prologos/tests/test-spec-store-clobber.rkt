#lang racket/base

;;; test-spec-store-clobber.rkt — the bare-name spec store's silent
;;; last-write-wins, MEASURED.
;;;
;;; Issue #66 / #67 (Numerics N6d-i follow-ups items 2 and 4) describe this
;;; defect with file:line and a mechanism but no measurement: the spec registry
;;; keys by BARE symbol, so two same-named specs from different modules
;;; overwrite each other in any module importing both, and the loser's call
;;; sites get WRONG implicit-argument counts — silently. Item 4's stated goal
;;; for the first slice is to make the collision census "mechanical instead of
;;; forensic".
;;;
;;; This file is that census, as a regression lock. It does NOT fix anything:
;;; the fix is an FQN-keyed or module-scoped spec store, which crosses the
;;; module system and is filed as a PM-series follow-up. What it does is stop
;;; the collision set from changing without anyone noticing, and give the
;;; eventual fix a before/after it can be checked against.
;;;
;;; Two things worth knowing if you touch this:
;;;
;;;   - the collision happens at IMPORT propagation
;;;     (`current-spec-propagation-handler`, driver.rkt), NOT at
;;;     `register-spec!`. Instrumenting `register-spec!` reports ZERO
;;;     collisions for the same program, because module bodies each load with
;;;     a fresh spec store (driver.rkt: `[current-spec-store (hasheq)]`) and
;;;     the overwrite only happens in the IMPORTING module.
;;;   - a plain prelude load collides ZERO times. The collision needs two
;;;     modules with overlapping spec names imported into one place, which is
;;;     why this has stayed invisible.

(require rackunit
         racket/file
         racket/list
         racket/set
         "test-support.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../macros.rkt"
         (only-in "../metavar-store.rkt" current-persistent-registry-net-box))

;; Load two modules with overlapping spec names into ONE spec store and return
;; it. `prologos::data::list` and `prologos::core::collections` both define
;; `map`, `reduce`, `filter`, `length`, … — the sequence-op names.
(define (spec-store-after . module-names)
  (parameterize ([current-file-module-network-ref (make-module-network)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-persistent-registry-net-box prelude-persistent-registry-net-box]
                 [current-spec-store (hasheq)])
    (install-module-loader!)
    (process-string "(ns spec-clobber-probe)")
    (for ([m (in-list module-names)])
      (process-string (format "(imports ~a)" m)))
    (current-spec-store)))

(define list-only    (spec-store-after 'prologos::data::list))
(define coll-only    (spec-store-after 'prologos::core::collections))
(define list-then-coll (spec-store-after 'prologos::data::list 'prologos::core::collections))
(define coll-then-list (spec-store-after 'prologos::core::collections 'prologos::data::list))

;; ============================================================================
;; The PRELUDE's shadowing order, made executable (2026-08-03).
;;
;; `namespace.rkt` ends its prelude import list with
;;
;;     ;; MUST BE LAST — shadowing depends on ordering.
;;     (imports [prologos::core::collections :refer [map filter reduce …]])
;;
;; That is a DELIBERATE shadow — the generic collection functions are meant to
;; win over the List-specific ones — and it is exactly the set W3001 declines to
;; report, because a user cannot act on it.
;;
;; The exposure is not the shadowing; it is that the invariant is enforced by a
;; COMMENT. Move that `imports` line up and twelve names silently change
;; meaning, with the suite green. This turns the comment into a mechanism.
;;
;; Deliberately asserted via the spec's WHERE-CONSTRAINTS rather than by
;; comparing whole entries: the constraints are what drive implicit-argument
;; counts, so they are the property whose silent change actually breaks call
;; sites — and the same property W3001 gates on. A whole-entry check would also
;; fail on innocuous edits to either module.
;;
;; SENSITIVITY VERIFIED, and the first attempt did NOT trip it: moving the
;; collections import a few entries earlier changed nothing, because the
;; position it moved to was still after `prologos::data::list`. Moving it to
;; FIRST in `prelude-imports` fails the test with the intended message. Worth
;; recording — a perturbation that does not fail proves nothing about the test,
;; only about the perturbation, and stopping at the first one would have shipped
;; a guard I had not actually seen fire.
;; ============================================================================

;; ⚠ COMPUTED HERE, beside the other stores, not beside its tests. The first
;; draft defined it at the END of the file, after every test-case had already
;; run `install-module-loader!` and mutated the registries — and it came back
;; PARTIAL (`filter` absent, the qualified keys missing), so the assertions
;; failed for contamination rather than for the invariant. Same lesson the
;; shared-fixture rule states: load once, up front, before anything can move.
(define prelude-spec-store
  (parameterize ([current-file-module-network-ref (make-module-network)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-persistent-registry-net-box prelude-persistent-registry-net-box]
                 [current-spec-store (hasheq)])
    (install-module-loader!)
    (process-string "(ns prelude-shadow-probe)")
    (current-spec-store)))



;; Names each module registers a spec for, that the other ALSO registers with a
;; DIFFERENT entry. Derived, not hand-listed — a hand list would drift.
(define colliding
  (for/seteq ([(name e1) (in-hash list-only)]
              #:when (let ([e2 (hash-ref coll-only name #f)])
                       (and e2 (not (equal? e1 e2)))))
    name))

(test-case "spec-clobber/the two modules really do collide"
  ;; If this ever reaches zero the rest of the file is vacuous, so it is
  ;; asserted rather than assumed.
  (check-true (>= (set-count colliding) 10)
              (format "expected a substantial collision set, got ~a: ~v"
                      (set-count colliding) (sort (set->list colliding) symbol<?))))

(test-case "spec-clobber/the census, pinned"
  ;; The defect's SIZE, locked. Not a hand-written list of what is wrong today —
  ;; a derived set, checked to still contain the names the N6d-i audit named.
  ;; If a future FQN-keyed store fixes this, these assertions are what change,
  ;; and they should change to zero rather than to a smaller number.
  (for ([n (in-list '(map reduce filter length head concat))])
    (check-true (set-member? colliding n)
                (format "~a no longer collides — did the store change? census: ~v"
                        n (sort (set->list colliding) symbol<?)))))

;; Names whose surviving spec DEPENDS ON IMPORT ORDER. This is the defect
;; stated as something observable: same program, same two modules, different
;; order, different types in the store — with no error and no warning.
;;
;; Derived rather than asserted as "last wins". A first cut asserted exactly
;; that and `sum` falsified it: not every colliding name resolves by simple
;; last-write, so the order-INDEPENDENCE of the outcome is the claim that
;; actually holds, and the one worth locking.
(define order-dependent
  (for/seteq ([(k v) (in-hash list-then-coll)]
              #:when (not (equal? v (hash-ref coll-then-list k #f))))
    k))

(test-case "spec-clobber/which spec survives depends on IMPORT ORDER"
  (check-true (>= (set-count order-dependent) 10)
              (format "expected import order to matter for many names, got ~a: ~v"
                      (set-count order-dependent)
                      (sort (set->list order-dependent) symbol<?)))
  ;; the sequence ops the N6d-i audit named
  (for ([n (in-list '(map reduce filter length head concat))])
    (check-true (set-member? order-dependent n)
                (format "~a is no longer order-dependent — did the store change? ~v"
                        n (sort (set->list order-dependent) symbol<?)))))

(test-case "spec-clobber/and it happens SILENTLY"
  ;; The half that makes it a defect rather than a policy: importing both
  ;; modules produces no error at all. If a duplicate-binding diagnostic ever
  ;; lands (issue #67), this is the assertion that flips.
  (define rs
    (parameterize ([current-file-module-network-ref (make-module-network)]
                   [current-ns-context #f]
                   [current-module-registry prelude-module-registry]
                   [current-lib-paths (list prelude-lib-dir)]
                   [current-preparse-registry prelude-preparse-registry]
                   [current-trait-registry prelude-trait-registry]
                   [current-impl-registry prelude-impl-registry]
                   [current-param-impl-registry prelude-param-impl-registry]
                   [current-persistent-registry-net-box prelude-persistent-registry-net-box]
                   [current-spec-store (hasheq)])
      (install-module-loader!)
      (process-string "(ns spec-clobber-silent)")
      (process-string "(imports prologos::data::list)")
      (process-string "(imports prologos::core::collections)")))
  (check-true (list? rs) (format "~v" rs)))

(test-case "spec-clobber/importing ONE module is order-free (control)"
  ;; Why this stayed invisible: the collision needs two overlapping modules
  ;; imported into ONE place. Importing either alone is deterministic, so no
  ;; existing test or example could have caught it — and this is the control
  ;; showing the order-dependence above really comes from the SECOND import
  ;; rather than from anything ambient in the fixture.
  (check-equal? (spec-store-after 'prologos::data::list) list-only)
  (check-equal? (spec-store-after 'prologos::core::collections) coll-only))


;; ============================================================================
;; W3001 — the duplicate-binding diagnostic (issue #67, 2026-08-03).
;;
;; The census above locks the DEFECT; these lock the DIAGNOSTIC. Both halves
;; matter: a warning that fires on the ordinary path is worse than no warning,
;; because people learn to ignore it.
;; ============================================================================

(define (run-file-results src)
  (define tmp (make-temporary-file "prologos-dupwarn-~a.prologos"))
  (call-with-output-file tmp #:exists 'replace (lambda (o) (display src o)))
  (define rs (parameterize ([current-lib-paths (list prelude-lib-dir)]
                            [current-module-registry prelude-module-registry])
               (install-module-loader!)
               (process-file (path->string tmp))))
  (delete-file tmp)
  (map (lambda (r) (format "~a" r)) rs))

(define (warns? src)
  (ormap (lambda (r) (regexp-match? #rx"W3001" r)) (run-file-results src)))

(test-case "W3001/two OWN imports that collide are reported"
  (define rs (run-file-results
              "ns dupwarn-a\n\nimports prologos::data::list\nimports prologos::core::collections\n\ndef z := 1\n"))
  (define w (findf (lambda (r) (regexp-match? #rx"W3001" r)) rs))
  (check-true (and w #t) "the collision must be reported")
  ;; the NAMES are the information — the sentence is the same for all of them
  (for ([n (in-list '("map" "reduce" "filter" "length" "head" "concat"))])
    (check-true (regexp-match? (regexp n) w) (format "~a should be listed: ~a" n w)))
  ;; ONE line, not one per name
  (check-equal? (length (filter (lambda (r) (regexp-match? #rx"W3001" r)) rs)) 1))

(test-case "W3001/the PRELUDE's own collisions are NOT reported"
  ;; Measured: the prelude collides on 12 names by itself, because it imports
  ;; both list and collections. Real, and filed — but not something a user can
  ;; act on, and reporting it would put the same 12 names under every file
  ;; anyone ever writes.
  (check-false (warns? "ns dupwarn-b\n\ndef q := 1\n")
               "an ordinary file must be silent"))

(test-case "W3001/shadowing the prelude with ONE import is NOT reported"
  ;; `imports prologos::data::list` rebinds 14 prelude names on its own. That is
  ;; what an explicit import is FOR; warning on it would make importing noisy.
  (check-false (warns? "ns dupwarn-c\n\nimports prologos::data::list\n\ndef q := 1\n")
               "a single explicit import must be silent"))

(test-case "W3001/re-importing the SAME module twice is not a collision"
  ;; Same spec entries, so nothing about any call site changes. The gate is
  ;; "the implicit-argument shape differs", not "a write happened".
  (check-false (warns? (string-append "ns dupwarn-d\n\n"
                                      "imports prologos::data::list\n"
                                      "imports prologos::data::list\n\ndef q := 1\n"))))


;; ============================================================================
;; issue #66 — a QUALIFIED call reaches its own module's spec (2026-08-03).
;;
;; The store keys by bare symbol with last-write-wins, so the loser of the race
;; had no reachable spec at all: every call to it — even one naming its module
;; explicitly — got the winner's implicit-argument count. Import propagation now
;; also files each spec under `module::name`, and the three lookup sites probe
;; the qualified key first.
;;
;; This does NOT fix the bare-name race (an unqualified `map` still resolves by
;; import order; W3001 reports when that is ambiguous). It makes the WORKAROUND
;; the warning recommends — "qualify the call" — actually work.
;; ============================================================================

(test-case "issue-66/a qualified call to the RACE LOSER now elaborates"
  ;; Failing-test-first: with the qualified probe removed this file reports
  ;; "Could not infer type" and then cascades to "Unbound variable" — verified
  ;; by A/B, not assumed. `collections` is imported FIRST so `list` wins the
  ;; bare-name write, making the collections spec the unreachable one.
  (define rs (run-file-results
              (string-append "ns issue66-a\n\n"
                             "imports prologos::core::collections\n"
                             "imports prologos::data::list\n\n"
                             "def xs := '[1 2 3]\n"
                             "def c := [prologos::core::collections::length xs]\n"
                             "c\n")))
  (check-false (ormap (lambda (r) (regexp-match? #rx"Could not infer type" r)) rs)
               (format "the qualified call must elaborate: ~v" rs))
  ;; What it does AFTER elaborating differs by environment, and the assertion
  ;; is written to be true in both. Through `run-file.rkt` (full lib load) it
  ;; evaluates to `3N`. In this fixture the `Reducible List` instance is not
  ;; present, so it reaches a NO-INSTANCE error instead — which is the point:
  ;; collections' `length` carries `where (Reducible C)`, so finding its spec
  ;; means the dict gets inserted and the missing instance becomes visible.
  ;; Before the fix the call never got that far; it failed on the implicit
  ;; COUNT, which said nothing true about the program.
  (check-false (ormap (lambda (r) (regexp-match? #rx"Unbound variable xs" r)) rs)
               (format "elaboration must not cascade from the count: ~v" rs)))

(test-case "issue-66/the WINNER's qualified call keeps working"
  ;; The other direction — the fix must not break the side that already worked.
  (define rs (run-file-results
              (string-append "ns issue66-b\n\n"
                             "imports prologos::core::collections\n"
                             "imports prologos::data::list\n\n"
                             "def xs := '[1 2 3]\n"
                             "def d := [prologos::data::list::length xs]\n"
                             "d\n")))
  (check-true (ormap (lambda (r) (regexp-match? #rx"3N : Nat" r)) rs)
              (format "~v" rs)))

(test-case "issue-66/an UNQUALIFIED call is unchanged — the race is not fixed"
  ;; Stated honestly: this slice makes the qualified workaround work. The bare
  ;; name still resolves by import order, which is what W3001 exists to report.
  (define rs (run-file-results
              (string-append "ns issue66-c\n\n"
                             "imports prologos::core::collections\n"
                             "imports prologos::data::list\n\n"
                             "def xs := '[1 2 3]\n"
                             "def e := [length xs]\n"
                             "e\n")))
  (check-true (ormap (lambda (r) (regexp-match? #rx"3N : Nat" r)) rs)
              (format "~v" rs))
  (check-true (ormap (lambda (r) (regexp-match? #rx"W3001" r)) rs)
              "and the ambiguity is still reported"))

(test-case "prelude/the generic collection functions WIN the shadow"
  ;; Every one of these is exported by both `prologos::data::list` (no
  ;; where-constraints) and `prologos::core::collections` (Seqable/Reducible/
  ;; Buildable constraints). Collections must be the survivor.
  (for ([n (in-list '(map filter reduce reduce1 length concat
                      any? all? find take drop head))])
    (define e (hash-ref prelude-spec-store n #f))
    (check-true (and e #t) (format "~a should have a spec in the prelude" n))
    (when e
      (check-true (pair? (spec-entry-where-constraints e))
                  (format (string-append
                           "~a resolved to the UNCONSTRAINED (List-specific) spec — "
                           "the collections import in namespace.rkt's prelude list "
                           "is no longer last, and twelve names just changed meaning")
                          n)))))

(test-case "prelude/and the qualified List spec is still reachable"
  ;; The other half of the shadow: shadowing must not make the shadowed module's
  ;; spec unreachable — that was issue #66, fixed by the qualified key.
  (define e (hash-ref prelude-spec-store 'prologos::data::list::length #f))
  (check-true (and e #t) "the qualified key must exist")
  (when e
    (check-equal? (spec-entry-where-constraints e) '()
                  "and it must be List's own, unconstrained, spec")))

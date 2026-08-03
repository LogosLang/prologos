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

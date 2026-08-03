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


;; Census the TRAIT registry: is any trait name registered twice with different
;; metadata during an ordinary prelude load?
(require (only-in "../macros.rkt" current-trait-registry read-trait-registry
                  trait-meta-name))
(define traits-after
  (parameterize ([current-file-module-network-ref (make-module-network)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry (hasheq)]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-persistent-registry-net-box prelude-persistent-registry-net-box])
    (install-module-loader!)
    (process-string "(ns trait-census)")
    (current-trait-registry)))
(printf "TRAITS: ~a\n" (hash-count traits-after))

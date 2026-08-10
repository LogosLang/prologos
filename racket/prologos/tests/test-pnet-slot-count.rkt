#lang racket/base

;;; test-pnet-slot-count.rkt — the .pnet positional payload has a fixed shape.
;;;
;;; `serialize-module-state` and `deserialize-module-state` exchange a bare
;;; positional list, and driver.rkt's cache-hit arm is its only consumer. Nothing
;;; named the slots or checked the count, and the reader's gate was a MINIMUM
;;; (`>= 14`), not an equality.
;;;
;;; Appending a slot is safe. INSERTING one anywhere before the tail shifts every
;;; later position — and because almost every slot is a hasheq, the types are
;;; indistinguishable, so the failure is silent wrong registries. That is the
;;; GitHub #78 severity class exactly: a cache that loads and lies.
;;;
;;; `PNET_VERSION` was the only thing between a mis-ordered write and a
;;; mis-read, and it does not move on its own when someone inserts a slot.

(require rackunit
         (only-in "../pnet-serialize.rkt" PNET_VERSION PNET_SLOT_COUNT))

(test-case "pnet/the slot count is a positive integer and is exported"
  ;; Exported so a test can pin it at all. It was a bare literal inside two
  ;; functions that disagreed by construction (31 on the write side, 14 on the
  ;; read side).
  (check-true (exact-positive-integer? PNET_SLOT_COUNT))
  (check-true (exact-positive-integer? PNET_VERSION)))

(test-case "pnet/the slot count matches what the writer actually builds"
  ;; The assertion inside `serialize-module-state` is the real guard — this
  ;; pins the CONSTANT so a change to it is deliberate rather than a silent
  ;; adjustment to make an assertion pass.
  ;;
  ;; If this fails because a slot was legitimately added: bump PNET_SLOT_COUNT
  ;; *and* PNET_VERSION (a payload of a different shape is a different format),
  ;; then update this number.
  (check-equal? PNET_SLOT_COUNT 31
                "a slot was added or removed — bump PNET_VERSION too, then update this"))

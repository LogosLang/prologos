#lang racket/base

;;;
;;; test-io-bridge-01.rkt — IO bridge infrastructure tests
;;;
;;; Phase IO-B: Tests for IO state lattice (B1), IO bridge propagator (B2),
;;; and FFI bridge wrappers (B3).
;;;
;;; Pattern: Direct struct construction, no shared fixtures, no process-string.
;;; Uses temporary files for IO tests.
;;;

(require rackunit
         racket/file
         racket/port
         "../io-bridge.rkt"
         "../propagator.rkt"
         "../sessions.rkt"
         "../session-runtime.rkt"
         "../syntax.rkt")

;; ========================================
;; Group 1: IO State Lattice (IO-B1)
;; ========================================

(test-case "io-state-lattice: bot is identity"
  ;; io-bot ⊔ x = x and x ⊔ io-bot = x
  (define opening (io-opening "/tmp/test" 'read))
  (define mock-port (open-input-string "mock"))
  (define open-st (io-open mock-port 'read))
  ;; bot ⊔ x = x
  (check-equal? (io-state-merge io-bot io-bot) io-bot)
  (check-equal? (io-state-merge io-bot opening) opening)
  (check-equal? (io-state-merge io-bot open-st) open-st)
  (check-equal? (io-state-merge io-bot io-closed) io-closed)
  ;; x ⊔ bot = x
  (check-equal? (io-state-merge opening io-bot) opening)
  (check-equal? (io-state-merge open-st io-bot) open-st)
  (check-equal? (io-state-merge io-closed io-bot) io-closed)
  (close-input-port mock-port))

(test-case "io-state-lattice: top is absorbing"
  ;; io-top ⊔ x = io-top and x ⊔ io-top = io-top
  (define opening (io-opening "/tmp/test" 'read))
  (check-true (io-top? (io-state-merge io-top io-bot)))
  (check-true (io-top? (io-state-merge io-top opening)))
  (check-true (io-top? (io-state-merge io-top io-closed)))
  (check-true (io-top? (io-state-merge io-bot io-top)))
  (check-true (io-top? (io-state-merge opening io-top)))
  (check-true (io-top? (io-state-merge io-closed io-top))))

(test-case "io-state-lattice: valid transitions"
  ;; io-opening → io-open
  (define mock-port (open-input-string "data"))
  (define opening (io-opening "/tmp/test" 'read))
  (define open-st (io-open mock-port 'read))
  (define result1 (io-state-merge opening open-st))
  (check-true (io-open? result1))
  (check-eq? (io-open-port result1) mock-port)
  ;; io-open → io-closed
  (define result2 (io-state-merge open-st io-closed))
  (check-true (io-closed? result2))
  (close-input-port mock-port))

(test-case "io-state-lattice: idempotent"
  ;; merge(x, x) = x for all state values
  (check-equal? (io-state-merge io-bot io-bot) io-bot)
  (check-equal? (io-state-merge io-closed io-closed) io-closed)
  (check-equal? (io-state-merge io-top io-top) io-top)
  (define opening (io-opening "/tmp/test" 'read))
  (check-equal? (io-state-merge opening opening) opening)
  (define mock-port (open-input-string "data"))
  (define open-st (io-open mock-port 'read))
  (check-equal? (io-state-merge open-st open-st) open-st)
  (close-input-port mock-port))

(test-case "io-state-lattice: invalid transitions → contradiction"
  (define mock-port (open-input-string "data"))
  (define opening (io-opening "/tmp/test" 'read))
  (define open-st (io-open mock-port 'read))
  ;; Backward transitions are contradictions
  (check-true (io-top? (io-state-merge io-closed opening)))    ; closed → opening
  (check-true (io-top? (io-state-merge io-closed open-st)))    ; closed → open
  (check-true (io-top? (io-state-merge open-st opening)))      ; open → opening
  ;; Two different openings are contradictions
  (define opening2 (io-opening "/tmp/other" 'write))
  (check-true (io-top? (io-state-merge opening opening2)))
  ;; Contradiction predicate
  (check-true (io-state-contradicts? io-top))
  (check-false (io-state-contradicts? io-bot))
  (check-false (io-state-contradicts? io-closed))
  (check-false (io-state-contradicts? opening))
  (check-false (io-state-contradicts? open-st))
  (close-input-port mock-port))

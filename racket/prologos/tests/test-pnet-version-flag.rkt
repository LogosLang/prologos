#lang racket/base

;; test-pnet-version-flag.rkt — Track 1 seed test.
;;
;; Validates the format-2 wrapped .pnet header introduced by SH series Track 1
;; alignment work. Specifically:
;;
;;   - pnet-wrap produces a list with the expected magic + version + mode + payload
;;   - pnet-unwrap recognizes both legacy (format 1) and wrapped (format 2)
;;   - pnet-unwrap rejects malformed / wrong-major / unknown-mode inputs
;;
;; This is a pure data-shape test — does not exercise the full
;; serialize-module-state / deserialize-module-state round-trip (which requires
;; a populated module state and an on-disk path). The full round-trip is
;; covered indirectly by the existing test suite via process-file.

(require rackunit
         (only-in "../pnet-serialize.rkt"
                  pnet-wrap
                  pnet-unwrap))

;; A representative legacy payload. Only the first two fields matter for
;; format detection (PNET_VERSION at index 0, source-hash at index 1).
;; The rest are placeholders.
(define legacy-payload
  (list 1                              ; PNET_VERSION
        "src.prologos:1234567890"      ; source-hash
        '(s-env)                        ; remaining fields are opaque
        '(s-specs)
        '(s-locs)
        '(exports)
        "test-ns"
        '(s-preparse) '(s-ctor) '(s-tmeta) '(s-multi) '(s-sub)
        '(s-coerce) '(s-cap)))

(test-case "pnet-wrap produces format-2 header with default mode"
  (define wrapped (pnet-wrap legacy-payload))
  (check-equal? (car wrapped) 'pnet
                "magic at position 0")
  (check-equal? (cadr wrapped) '(2 0)
                "format-version (major minor) at position 1")
  (check-equal? (caddr wrapped) 'module
                "default mode = 'module")
  (check-true (string? (cadddr wrapped))
              "substrate-version is a string")
  (check-equal? (list-ref wrapped 4) legacy-payload
                "legacy payload at position 4"))

(test-case "pnet-wrap with explicit mode"
  (define wrapped (pnet-wrap legacy-payload 'program))
  (check-equal? (caddr wrapped) 'program))

(test-case "pnet-wrap rejects unknown mode"
  (check-exn exn:fail?
    (lambda () (pnet-wrap legacy-payload 'bogus))))

(test-case "pnet-unwrap recognizes legacy format-1 (unwrapped) input"
  (define-values (mode subv payload) (pnet-unwrap legacy-payload))
  (check-equal? mode 'module
                "legacy defaults to 'module")
  (check-equal? subv 'pre-versioned
                "legacy reports 'pre-versioned substrate")
  (check-equal? payload legacy-payload
                "legacy returns input as payload"))

(test-case "pnet-unwrap recognizes format-2 wrapped input"
  (define wrapped (pnet-wrap legacy-payload 'module))
  (define-values (mode subv payload) (pnet-unwrap wrapped))
  (check-equal? mode 'module)
  (check-true (string? subv))
  (check-equal? payload legacy-payload))

(test-case "pnet-unwrap recognizes format-2 program-mode"
  (define wrapped (pnet-wrap legacy-payload 'program))
  (define-values (mode _subv _payload) (pnet-unwrap wrapped))
  (check-equal? mode 'program))

(test-case "pnet-unwrap returns #f for major-version mismatch"
  ;; Future major version (3.0) — current code only handles major 2.
  (define future-wrapped
    (list 'pnet '(3 0) 'module "0.1" legacy-payload))
  (check-false (pnet-unwrap future-wrapped)))

(test-case "pnet-unwrap returns #f for unknown mode in wrapped form"
  (define bogus-mode-wrapped
    (list 'pnet '(2 0) 'bogus "0.1" legacy-payload))
  (check-false (pnet-unwrap bogus-mode-wrapped)))

(test-case "pnet-unwrap returns #f for non-pnet inputs"
  (check-false (pnet-unwrap '()))
  (check-false (pnet-unwrap "not a pnet"))
  (check-false (pnet-unwrap '(99 "wrong-version-int" stuff)))
  (check-false (pnet-unwrap 'symbol-not-list))
  (check-false (pnet-unwrap '(other-magic '(2 0) module "0.1" payload))))

(test-case "round-trip: wrap then unwrap returns original payload"
  (define wrapped (pnet-wrap legacy-payload 'module))
  (define-values (mode subv payload) (pnet-unwrap wrapped))
  (check-equal? payload legacy-payload
                "payload survives round-trip")
  (check-equal? mode 'module)
  (check-true (string? subv)))

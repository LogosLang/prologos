#lang racket/base

;;;
;;; Tests for pNN posit literals — Numerics N6b (D-N6.2).
;;; 2p8 / 3.14p16 / 3.14p32 / 1.5e-3p64: dedicated recognize-posit-literal
;;; (priority 99, explicit width REQUIRED — no bare `p`: bare decimals ARE
;;; Posit32 under D-N6.1) → ($posit-literal <exact> <width>) → surf-posit-lit
;;; → eager posit{N}-encode at elaborate (round-to-nearest-even, silent per
;;; D-N6.4: literals never warn). Mirrors the N3c f-literal family.
;;; Also covers the N6b default flip at WS level (decimal→Posit32 etc.).
;;;

(require rackunit
         racket/string
         "test-support.rkt")

(define (ws-val s) (car (string-split (run-ns-ws-last s) "\nwarning:")))

;; ========================================
;; pNN literals — all four widths, value + type
;; ========================================

(test-case "posit-literal/widths"
  (check-equal? (ws-val "2p8")       "2p8 : Posit8")
  (check-equal? (ws-val "3.14p16")   "3.14p16 : Posit16")
  (check-equal? (ws-val "3.14p32")   "3.14 : Posit32")
  (check-equal? (ws-val "1.5e-3p64") "0.0015p64 : Posit64"))

(test-case "posit-literal/negative-and-integer-shapes"
  (check-equal? (ws-val "-2.5p16") "-2.5p16 : Posit16")
  (check-equal? (ws-val "42p32")   "42.0 : Posit32"))

(test-case "posit-literal/arithmetic-composes"
  ;; same-width posit arithmetic over pNN literals
  (check-equal? (ws-val "[p16+ 1.5p16 2.0p16]") "3.5p16 : Posit16"))

(test-case "posit-literal/no-bare-p"
  ;; `3.14p` is NOT a posit literal (width mandatory); it lexes as the decimal
  ;; 3.14 followed by the identifier `p` and fails to parse/elaborate as a lone
  ;; expression — it must never silently produce a posit value.
  (define rs (with-handlers ([(lambda (_) #t) (lambda (_) '())])
               (run-ns-ws-all "3.14p")))
  (check-false (for/or ([r (in-list rs)])
                 (and (string? r) (string-contains? r ": Posit")))
               "bare `p` suffix must not yield a posit value"))

;; ========================================
;; N6b default flip at WS level (decimal/exponent → Posit32; fraction → Rat)
;; ========================================

(test-case "posit-literal/n6b-defaults"
  (check-equal? (ws-val "3.14")        "3.14 : Posit32")
  (check-equal? (ws-val "3.0")         "3.0 : Posit32")
  (check-equal? (ws-val "[+ 3.13 1.0]") "4.13 : Posit32")
  (check-true (string-contains? (ws-val "3/7") "Rat"))
  (check-true (string-contains? (ws-val "1e10") "Int")))

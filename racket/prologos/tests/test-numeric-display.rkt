#lang racket/base

;;;
;;; Numerics N2 — Q10-complete numeric display round-trip properties.
;;;
;;; "Display = a re-readable marked literal of the same value."
;;;
;;; These tests verify the display contract INDEPENDENT of the specific
;;; expected-string assertions scattered across the numeric test suite:
;;;   (a) pp-expr output carries the correct marker (~ / f / f32 / decimal);
;;;   (b) re-parsing that output through the WS pipeline yields the SAME value
;;;       (structural round-trip on the underlying stored representation).
;;;
;;; Posit  → ~<shortest-decimal>            (re-parses to Posit32 via ~ marker)
;;; Float64 → <shortest-decimal>f            (re-parses to Float64)
;;; Float32 → <shortest-decimal>f32          (re-parses to Float32)
;;; Rat    → exact decimal if terminating, else the fraction
;;;

(require rackunit
         racket/string
         racket/flonum
         "test-support.rkt"
         "../driver.rkt"
         "../posit-impl.rkt")

;; Strip " : Type" suffix from a "value : type" display string.
(define (value-part disp)
  (car (regexp-split #px" : " disp)))

;; ========================================
;; Unit-level: the shortest-decimal / rat helpers directly
;; ========================================

(test-case "shortest-decimal: posit32 terminating decimals"
  ;; 3.14 → 157/50 → posit32; shortest re-encoding decimal is "3.14"
  (check-equal? (posit-shortest-decimal 32 (posit32-encode 157/50)) "3.14")
  (check-equal? (posit-shortest-decimal 32 (posit32-encode 1/2))    "0.5")
  (check-equal? (posit-shortest-decimal 32 (posit32-encode 3))      "3")   ; integer
  (check-equal? (posit-shortest-decimal 32 (posit32-encode 0))      "0")
  (check-equal? (posit-shortest-decimal 32 (posit32-encode -5/2))   "-2.5"))

(test-case "posit-shortest-decimal: NaR"
  ;; NaR bit pattern for width 32 = 2^31
  (check-equal? (posit-shortest-decimal 32 (posit32-encode 'nar)) "NaR")
  (check-equal? (posit-shortest-decimal 8  (posit8-encode 'nar))  "NaR"))

(test-case "posit-shortest-decimal: round-trips through the encoder"
  ;; The shortest decimal, re-parsed and re-encoded, must equal the target bits.
  (for ([q (in-list (list 157/50 1/2 3/7 22/7 -1/4 1000 1/1000))])
    (define bits (posit32-encode q))
    (define s (posit-shortest-decimal 32 bits))
    (define p (string->number s))
    (check-equal? (posit32-encode (inexact->exact p)) bits
                  (format "posit32 round-trip for ~a via ~a" q s))))

(test-case "shortest-decimal: Float32 shortest re-encoding"
  ;; A single-precision value's shortest decimal must re-parse+flsingle back.
  (for ([q (in-list (list 314/100 1/10 1/2 3 -25/10))])
    (define v (flsingle (exact->inexact q)))
    (define s (shortest-decimal (inexact->exact v)
                                (lambda (x) (flsingle (exact->inexact x)))
                                v))
    (define p (string->number s))
    (check-equal? (flsingle (exact->inexact p)) v
                  (format "float32 round-trip for ~a via ~a" q s))))

(test-case "rat-terminates? classification"
  (check-true  (rat-terminates? 157/50))  ; 50 = 2·5^2
  (check-true  (rat-terminates? 1/2))
  (check-true  (rat-terminates? 1/8))
  (check-true  (rat-terminates? 3/1))      ; integer
  (check-true  (rat-terminates? 1/1000))   ; 1000 = 2^3·5^3
  (check-false (rat-terminates? 1/3))
  (check-false (rat-terminates? 3/7))
  (check-false (rat-terminates? 22/7)))

(test-case "rat->display-string: terminating → decimal, else fraction"
  (check-equal? (rat->display-string 157/50) "3.14")
  (check-equal? (rat->display-string 1/2)    "0.5")
  (check-equal? (rat->display-string 3)      "3")     ; integer
  (check-equal? (rat->display-string 1/8)    "0.125")
  (check-equal? (rat->display-string 1/3)    "1/3")   ; non-terminating
  (check-equal? (rat->display-string 3/7)    "3/7"))

;; ========================================
;; End-to-end: pp-expr output marker + WS re-parse round-trip
;; ========================================

(test-case "Posit32 display carries ~ marker and round-trips"
  (for ([orig (in-list (list "3.14" "~42" "0.5" "1.0" "~3/7" "0.125"))])
    (define disp (run-ns-ws-last orig))
    (check-true (string-contains? disp ": Posit32")
                (format "~a should be Posit32: ~a" orig disp))
    (check-true (string-prefix? (value-part disp) "~")
                (format "~a display should start with ~~: ~a" orig disp))
    ;; Round-trip: re-parse the displayed literal → same display.
    (check-equal? (run-ns-ws-last (value-part disp)) disp
                  (format "posit round-trip for ~a" orig))))

(test-case "Float64 display carries f marker and round-trips"
  (for ([orig (in-list (list "3.14f" "3.14f64" "-2.5f" "3f" "0.0f"))])
    (define disp (run-ns-ws-last orig))
    (check-true (string-contains? disp ": Float64")
                (format "~a should be Float64: ~a" orig disp))
    (define lit (value-part disp))
    (check-true (and (string-suffix? lit "f")
                     (not (string-suffix? lit "f32"))
                     (not (string-suffix? lit "f64")))
                (format "~a display should end with plain f: ~a" orig disp))
    (check-equal? (run-ns-ws-last lit) disp
                  (format "float64 round-trip for ~a" orig))))

(test-case "Float32 display carries f32 marker and round-trips"
  (for ([orig (in-list (list "3.14f32" "0.5f32" "0.125f32" "-2.5f32"))])
    (define disp (run-ns-ws-last orig))
    (check-true (string-contains? disp ": Float32")
                (format "~a should be Float32: ~a" orig disp))
    (check-true (string-suffix? (value-part disp) "f32")
                (format "~a display should end with f32: ~a" orig disp))
    (check-equal? (run-ns-ws-last (value-part disp)) disp
                  (format "float32 round-trip for ~a" orig))))

(test-case "Rat display: terminating → decimal, non-terminating → fraction"
  ;; 1/2 terminates → "0.5"; but note bare 0.5 is Posit32, so a Rat 0.5 arises
  ;; from a Rat-typed expression. Use rat literals via `/`.
  (let ([d13 (run-ns-ws-last "1/3")])
    (check-true (string-contains? d13 "Rat") (format "1/3 is Rat: ~a" d13))
    (check-equal? (value-part d13) "1/3" "non-terminating rat prints as fraction"))
  (let ([d37 (run-ns-ws-last "3/7")])
    (check-true (string-contains? d37 "Rat") (format "3/7 is Rat: ~a" d37))
    (check-equal? (value-part d37) "3/7"))
  ;; A terminating Rat prints as a decimal. 1/2 → "0.5".
  (let ([d12 (run-ns-ws-last "1/2")])
    (check-true (string-contains? d12 "Rat") (format "1/2 is Rat: ~a" d12))
    (check-equal? (value-part d12) "0.5" "terminating rat prints as decimal")))

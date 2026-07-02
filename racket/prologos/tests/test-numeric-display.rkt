#lang racket/base

;;;
;;; Numerics N2/N6c — Q10-complete numeric display round-trip properties.
;;;
;;; "Display = a re-readable literal of the same value." (sigil-free, N6c)
;;;
;;; These tests verify the display contract INDEPENDENT of the specific
;;; expected-string assertions scattered across the numeric test suite:
;;;   (a) pp-expr output carries the correct form (bare / pNN / f / f32 / fraction);
;;;   (b) re-parsing that output through the WS pipeline yields the SAME value
;;;       (structural round-trip on the underlying stored representation).
;;;
;;; Posit32 → <shortest-decimal>, bare (integral values force `.0`)
;;; Posit8/16/64 → <shortest-decimal>pNN
;;; Float64 → <shortest-decimal>f            (re-parses to Float64)
;;; Float32 → <shortest-decimal>f32          (re-parses to Float32)
;;; Rat    → plain exact notation (fractions; integral Rat displays bare)
;;;

(require rackunit
         racket/string
         racket/flonum
         "test-support.rkt"
         "../driver.rkt"
         "../syntax.rkt"
         "../pretty-print.rkt"
         "../posit-impl.rkt")

;; Strip " : Type" suffix from a "value : type" display string.
(define (value-part disp)
  (car (regexp-split #px" : " disp)))

;; ========================================
;; Unit-level: the shortest-decimal helper directly
;; ========================================

(test-case "shortest-decimal: posit32 terminating decimals"
  ;; 3.14 → 157/50 → posit32; shortest re-encoding decimal is "3.14"
  (check-equal? (posit-shortest-decimal 32 (posit32-encode 157/50)) "3.14")
  (check-equal? (posit-shortest-decimal 32 (posit32-encode 1/2))    "0.5")
  (check-equal? (posit-shortest-decimal 32 (posit32-encode 3))      "3")   ; integer (bare; pp adds .0)
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

;; ========================================
;; Unit-level: pp-expr posit forms (all four widths) + all-256 posit8 sweep
;; ========================================

(test-case "pp-expr posit forms: bare Posit32 (forced .0), pNN others"
  (check-equal? (pp-expr (expr-posit32 (posit32-encode 157/50)) '()) "3.14")
  (check-equal? (pp-expr (expr-posit32 (posit32-encode 3)) '())      "3.0")   ; forced .0
  (check-equal? (pp-expr (expr-posit32 (posit32-encode 0)) '())      "0.0")
  (check-equal? (pp-expr (expr-posit8  (posit8-encode 5/2)) '())     "2.5p8")
  (check-equal? (pp-expr (expr-posit8  (posit8-encode 2)) '())       "2p8")
  (check-equal? (pp-expr (expr-posit16 (posit16-encode 3/2)) '())    "1.5p16")
  (check-equal? (pp-expr (expr-posit64 (posit64-encode 1/2)) '())    "0.5p64"))

(test-case "all-256 posit8 display round-trip (N6c: p8 display is re-readable)"
  ;; Every non-NaR posit8 bit pattern's display, stripped of its p8 suffix and
  ;; re-read as an exact number, must re-encode to the same bits.
  (for ([i (in-range 0 256)])
    (unless (= i 128)  ;; NaR: displays "NaR", no reader literal
      (define s (pp-expr (expr-posit8 i) '()))
      (check-true (string-suffix? s "p8") (format "posit8 ~a display ~a has p8 suffix" i s))
      (define mant (substring s 0 (- (string-length s) 2)))
      (define q (string->number (string-append "#e" mant)))
      (check-equal? (posit8-encode q) i
                    (format "posit8 display round-trip for bits ~a via ~a" i s)))))

;; ========================================
;; End-to-end: pp-expr output + WS re-parse round-trip
;; ========================================

(test-case "Posit32 displays bare and round-trips (incl. integral .0 + p32 input)"
  (for ([orig (in-list (list "3.14" "42.0" "0.5" "1.0" "0.125" "3.14p32" "[p32-from-rat 3/7]"))])
    (define disp (run-ns-ws-last orig))
    (check-true (string-contains? disp ": Posit32")
                (format "~a should be Posit32: ~a" orig disp))
    (check-false (string-prefix? (value-part disp) "~")
                 (format "~a display must be sigil-free: ~a" orig disp))
    ;; Round-trip: re-parse the displayed literal → same display.
    (check-equal? (run-ns-ws-last (value-part disp)) disp
                  (format "posit round-trip for ~a" orig))))

(test-case "Posit8/16/64 display pNN-suffixed and round-trip"
  (for ([orig (in-list (list "2.5p8" "2p8" "1.5p16" "-2.5p16" "0.5p64"))]
        [ty   (in-list (list ": Posit8" ": Posit8" ": Posit16" ": Posit16" ": Posit64"))])
    (define disp (run-ns-ws-last orig))
    (check-true (string-contains? disp ty)
                (format "~a should be ~a: ~a" orig ty disp))
    (check-equal? (run-ns-ws-last (value-part disp)) disp
                  (format "pNN round-trip for ~a" orig))))

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

(test-case "Rat displays as plain exact notation (fractions; N6c revert)"
  (let ([d13 (run-ns-ws-last "1/3")])
    (check-true (string-contains? d13 "Rat") (format "1/3 is Rat: ~a" d13))
    (check-equal? (value-part d13) "1/3"))
  (let ([d37 (run-ns-ws-last "3/7")])
    (check-true (string-contains? d37 "Rat") (format "3/7 is Rat: ~a" d37))
    (check-equal? (value-part d37) "3/7"))
  ;; Terminating rationals also display as fractions post-N6c (a "0.5" display
  ;; would re-read as Posit32; the fraction is the honest exact literal).
  (let ([d12 (run-ns-ws-last "1/2")])
    (check-true (string-contains? d12 "Rat") (format "1/2 is Rat: ~a" d12))
    (check-equal? (value-part d12) "1/2"))
  ;; Integral Rat displays bare (re-reads as Int, which widens via Int <: Rat).
  (let ([d1 (run-ns-ws-last "[+ 1/2 1/2]")])
    (check-true (string-contains? d1 "Rat") (format "1/2+1/2 is Rat: ~a" d1))
    (check-equal? (value-part d1) "1")))

(test-case "~N input is rejected with a migration hint (N6c)"
  (check-exn (regexp "approximate literals were removed")
             (lambda () (run-ns-ws-last "~3.14")))
  (check-exn (regexp "approximate literals were removed")
             (lambda () (run-ns-ws-last "~42"))))

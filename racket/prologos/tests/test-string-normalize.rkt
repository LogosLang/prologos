#lang racket/base

;;; test-string-normalize.rkt — String Library Phase 4b: Unicode normalization.
;;;
;;; DEFERRED asked for `string-normalize : NormForm -> String -> String`
;;; (NFC/NFD/NFKC/NFKD) bridged to Racket's implementations. Delivered as four
;;; FFI bindings in `prologos::data::string` plus a `NormForm` type and a
;;; `normalize` dispatcher in `prologos::core::string-ops`.
;;;
;;; The split is not cosmetic: `data/string.prologos` is a prelude-less leaf, and
;;; a `match` over a user `data` needs machinery it does not have. The Racket
;;; bridge belongs with the other FFI bindings; the type belongs where it can be
;;; eliminated.
;;;
;;; Every assertion is a PROPERTY of the form, not a snapshot of our output:
;;; NFD lengthens a precomposed character, NFC shortens a decomposed one, and
;;; the compatibility forms fold a ligature and a circled digit. A test that
;;; only checked "returns a string" would pass against `values`.

(require rackunit
         racket/string
         "test-support.rkt"
         "../errors.rkt")

(define pre
  (string-append
   "ns nz\n"
   "require [prologos::data::string :as str :refer []]\n"
   "require [prologos::core::string-ops :refer [NormForm nfc nfd nfkc nfkd normalize]]\n"))

(define (run s) (run-ns-ws-last (string-append pre s)))

(test-case "normalize/NFD decomposes a precomposed character"
  ;; "é" U+00E9 becomes "e" + U+0301 — one code point becomes two. Length is
  ;; the observable, and it is the whole point of the form.
  (define r (run "[str::length [normalize nfd \"é\"]]\n"))
  (check-false (prologos-error? r) (format "got: ~v" r))
  (check-true (string-contains? (format "~a" r) "2") (format "expected length 2: ~v" r)))

(test-case "normalize/NFC composes a decomposed character"
  ;; The inverse direction: "e" + U+0301 becomes the single U+00E9.
  (define r (run "[str::length [normalize nfc \"é\"]]\n"))
  (check-false (prologos-error? r) (format "got: ~v" r))
  (check-true (string-contains? (format "~a" r) "1") (format "expected length 1: ~v" r)))

(test-case "normalize/NFC and NFD disagree — the forms are distinct"
  ;; If the dispatcher ignored its NormForm argument, every case above would
  ;; still pass on whichever form it happened to call. This is what rules that
  ;; out.
  (define nfd-len (format "~a" (run "[str::length [normalize nfd \"é\"]]\n")))
  (define nfc-len (format "~a" (run "[str::length [normalize nfc \"é\"]]\n")))
  (check-not-equal? nfd-len nfc-len
                    "nfd and nfc gave the same answer — the form argument is ignored"))

(test-case "normalize/NFKC folds a compatibility ligature"
  ;; U+FB01 LATIN SMALL LIGATURE FI becomes "fi". Compatibility folding is
  ;; LOSSY, which is why it is a separate form rather than the default.
  (define r (run "[normalize nfkc \"ﬁ\"]\n"))
  (check-false (prologos-error? r) (format "got: ~v" r))
  (check-true (string-contains? (format "~a" r) "fi") (format "got: ~v" r)))

(test-case "normalize/NFKD folds a circled digit"
  ;; U+2460 CIRCLED DIGIT ONE becomes "1".
  (define r (run "[normalize nfkd \"①\"]\n"))
  (check-false (prologos-error? r) (format "got: ~v" r))
  (check-true (string-contains? (format "~a" r) "1") (format "got: ~v" r)))

(test-case "normalize/the canonical forms do NOT fold compatibility characters"
  ;; The distinction that makes four forms necessary: NFC leaves the ligature
  ;; alone where NFKC folds it. Getting this backwards silently corrupts data.
  (define r (run "[normalize nfc \"ﬁ\"]\n"))
  (check-false (prologos-error? r) (format "got: ~v" r))
  (check-false (string-contains? (format "~a" r) "fi")
               (format "NFC folded a compatibility character — that is NFKC's job: ~v" r)))

(test-case "normalize/the raw FFI bindings are reachable directly"
  ;; The dispatcher is a convenience; the four bindings are the substrate and
  ;; are usable without the type.
  (for ([f (in-list '("normalize-nfc" "normalize-nfd" "normalize-nfkc" "normalize-nfkd"))])
    (define r (run (format "[str::~a \"abc\"]\n" f)))
    (check-false (prologos-error? r) (format "~a: ~v" f r))
    (check-true (string-contains? (format "~a" r) "abc") (format "~a: ~v" f r))))

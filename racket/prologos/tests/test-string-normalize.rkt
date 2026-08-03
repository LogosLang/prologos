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

;; ----------------------------------------------------------------
;; String similarity (Phase 4c) — the common-prefix half
;; ----------------------------------------------------------------
;;
;; Edit distance is deliberately absent; see the DEFERRED entry. The
;; common-prefix/suffix functions are the part that can be written here.

(define sim-pre
  (string-append
   "ns sim\n"
   "require [prologos::data::string :as str :refer []]\n"
   "require [prologos::core::string-ops :refer [common-prefix common-prefix-length common-suffix common-suffix-length]]\n"))

(define (sim s) (run-ns-ws-last (string-append sim-pre s)))

(test-case "similarity/common-prefix returns the shared leading run"
  (check-true (string-contains? (format "~a" (sim "[common-prefix \"foobar\" \"foobaz\"]\n")) "fooba")))

(test-case "similarity/common-prefix is empty when nothing is shared"
  ;; The boundary that a loop with an off-by-one gets wrong.
  (define r (sim "[common-prefix \"abc\" \"xyz\"]\n"))
  (check-false (prologos-error? r) (format "got: ~v" r))
  (check-true (string-contains? (format "~a" r) "\"\"") (format "expected empty: ~v" r)))

(test-case "similarity/common-prefix stops at the shorter string"
  ;; Reading past the end of the shorter input is the other way to get this
  ;; wrong, and it would be an index error rather than a wrong answer.
  (define r (sim "[common-prefix-length \"ab\" \"abcdef\"]\n"))
  (check-false (prologos-error? r) (format "got: ~v" r))
  (check-true (string-contains? (format "~a" r) "2") (format "got: ~v" r)))

(test-case "similarity/common-suffix returns the shared trailing run"
  (check-true (string-contains? (format "~a" (sim "[common-suffix \"running\" \"jogging\"]\n")) "ing"))
  (check-true (string-contains? (format "~a" (sim "[common-suffix-length \"abc\" \"xbc\"]\n")) "2")))

(test-case "similarity/common-suffix is empty when nothing is shared"
  (define r (sim "[common-suffix \"abc\" \"xyz\"]\n"))
  (check-false (prologos-error? r) (format "got: ~v" r))
  (check-true (string-contains? (format "~a" r) "\"\"") (format "expected empty: ~v" r)))

;; ----------------------------------------------------------------
;; Edit distance and "did you mean?"
;; ----------------------------------------------------------------
;;
;; The `let` in `lev-row-loop` is load-bearing. Each cell's value is needed
;; twice (row entry, and the next cell's `left`), as is the cell above it;
;; computing them inline doubles the work per cell and the whole thing goes
;; exponential — a 3×3 distance then exceeds the reduction budget and returns a
;; STUCK TERM rather than a number. That is why `distance-of-equal-strings`
;; below is not a trivial case: it is the one that failed.

(define lev-pre
  (string-append
   "ns lev\n"
   "require [prologos::data::list :refer [List nil cons]]\n"
   "require [prologos::core::string-ops :refer [levenshtein closest]]\n"))

(define (lev s) (run-ns-ws-last (string-append lev-pre s)))

(test-case "levenshtein/identical strings are distance 0"
  ;; Not a trivial case — this is the size that returned a stuck term before
  ;; the sharing was fixed. A result that is a NUMBER at all is the assertion.
  (define r (lev "[levenshtein \"abc\" \"abc\"]\n"))
  (check-false (prologos-error? r) (format "got: ~v" r))
  (check-true (string-contains? (format "~a" r) "0 : Int")
              (format "expected 0, got (a stuck term is the old failure): ~v" r)))

(test-case "levenshtein/one substitution is distance 1"
  (check-true (string-contains? (format "~a" (lev "[levenshtein \"abc\" \"abd\"]\n")) "1 : Int")))

(test-case "levenshtein/kitten to sitting is 3"
  ;; The textbook case: substitute k→s, substitute e→i, insert g.
  (check-true (string-contains? (format "~a" (lev "[levenshtein \"kitten\" \"sitting\"]\n")) "3 : Int")))

(test-case "levenshtein/an empty string costs its length"
  (check-true (string-contains? (format "~a" (lev "[levenshtein \"\" \"abc\"]\n")) "3 : Int")))

(test-case "levenshtein/flaw to lawn is 2"
  ;; One deletion and one insertion at opposite ends — catches an
  ;; implementation that only walks one diagonal.
  (check-true (string-contains? (format "~a" (lev "[levenshtein \"flaw\" \"lawn\"]\n")) "2 : Int")))

(test-case "closest/picks the nearest candidate within the limit"
  (define r (lev "[closest \"lenght\" [cons \"length\" [cons \"left\" [cons \"list\" nil]]] 3]\n"))
  (check-true (string-contains? (format "~a" r) "length") (format "got: ~v" r)))

(test-case "closest/answers none when nothing is close enough"
  ;; The limit has to actually gate, or every typo gets a confident wrong
  ;; suggestion — worse than no suggestion.
  (define r (lev "[closest \"zzzzzz\" [cons \"length\" [cons \"left\" nil]] 2]\n"))
  (check-true (string-contains? (format "~a" r) "none") (format "got: ~v" r)))

(test-case "closest/an exact match is its own nearest"
  (define r (lev "[closest \"left\" [cons \"length\" [cons \"left\" nil]] 3]\n"))
  (check-true (string-contains? (format "~a" r) "left") (format "got: ~v" r)))

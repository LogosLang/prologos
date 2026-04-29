#lang racket/base

;;;
;;; Phase 4 of OCapN interop — cross-runtime byte-equality with
;;; @endo/ocapn (the JS reference implementation).
;;;
;;; Reads a fixture file `tests/fixtures/syrup-cross-impl.txt`
;;; that was produced by `tools/interop/gen-syrup-vectors.mjs`
;;; using @endo/ocapn's `encodeSyrup`. Each line is:
;;;
;;;   <label> \t <hex-bytes-from-JS> \t <prologos-sexp>
;;;
;;; For each vector, we:
;;;   1. parse the prologos-sexp into a SyrupValue via the test
;;;      fixture
;;;   2. call Prologos's `encode` on it
;;;   3. assert the resulting bytes (after extracting from the
;;;      pretty-printer's quoted form) hex-encode to the same
;;;      string the JS impl produced
;;;
;;; This is the FINAL gate on "Prologos's wire codec is
;;; byte-equivalent with the JS reference." If a future
;;; @endo/ocapn release changes the wire format, regenerating the
;;; fixture catches the drift; if Prologos's encoder drifts, the
;;; existing fixture catches it without a network round-trip.
;;;

(require rackunit
         racket/list
         racket/string
         racket/file
         racket/runtime-path
         "test-support.rkt"
         "../macros.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../source-location.rkt"
         "../surface-syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../pretty-print.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../multi-dispatch.rkt")

(define-runtime-path FIXTURE-PATH "fixtures/syrup-cross-impl.txt")

(define shared-preamble
  "(ns test-ocapn-syrup-cross-impl)
(imports (prologos::ocapn::syrup :refer-all))
(imports (prologos::ocapn::syrup-wire :refer-all))
(imports (prologos::data::list :refer (List nil cons)))
(imports (prologos::data::option :refer (Option some none)))
")

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-ctor-reg
                shared-type-meta)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-multi-defn-registry (current-multi-defn-registry)]
                 [current-spec-store (hasheq)])
    (install-module-loader!)
    (process-string shared-preamble)
    (values (current-prelude-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-ctor-registry)
            (current-type-meta))))

(define (run s)
  (parameterize ([current-prelude-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-ctor-registry shared-ctor-reg]
                 [current-type-meta shared-type-meta])
    (process-string s)))

(define (run-last s) (last (run s)))

;; Extract the literal value string from a "value : type" string.
;; Prologos pretty-prints with C-style escapes (\" / \\); `read`
;; on the quoted prefix recovers the raw byte sequence.
(define (extract-value-bytes s)
  (define m (regexp-match #px"^(\".*\") : String$" s))
  (unless m
    (error 'extract-value-bytes "couldn't extract bytes from: ~s" s))
  (read (open-input-string (cadr m))))

;; Lowercase hex-encode a string treating its chars as bytes.
(define (string->hex s)
  (define bs (string->bytes/utf-8 s))
  (apply string-append
         (for/list ([b (in-bytes bs)])
           (define hh (number->string b 16))
           (if (= 1 (string-length hh)) (string-append "0" hh) hh))))

;; Decode hex string to a Racket String.
(define (hex->string h)
  (define n (/ (string-length h) 2))
  (define bs (make-bytes n))
  (for ([i (in-range n)])
    (bytes-set! bs i
                (string->number (substring h (* 2 i) (* 2 (+ i 1))) 16)))
  (bytes->string/utf-8 bs))

;; ========================================
;; Vector loader
;; ========================================

(define (parse-fixture path)
  ;; Each line: <label> \t <hex> \t <prologos-sexp>
  ;; Skip blank lines.
  (for/list ([line (in-list (file->lines path))]
             #:when (not (regexp-match? #px"^\\s*$" line)))
    (define parts (regexp-split #px"\t" line))
    (unless (= 3 (length parts))
      (error 'parse-fixture "bad line: ~s" line))
    (apply (lambda (label hex sexp) (list label hex sexp))
           parts)))

(define vectors (parse-fixture FIXTURE-PATH))

(printf "syrup-cross-impl: loaded ~a vectors from ~a\n"
        (length vectors)
        (path->string FIXTURE-PATH))

;; ========================================
;; Cross-impl byte-equality + decode roundtrip
;; ========================================
;;
;; For each fixture entry, run TWO checks:
;;   (a) Prologos encode of the sexp == JS-emitted bytes
;;   (b) Prologos decode of those same bytes succeeds (the
;;       resulting SyrupValue need not equal the input — see
;;       pitfall #24 — but at minimum it must not be `none`).
;;
;; Test cases are generated dynamically from the fixture.

(for ([v (in-list vectors)])
  (define label (car v))
  (define hex   (cadr v))
  (define sexp  (caddr v))

  (test-case (format "syrup-cross-impl/encode ~a == JS bytes" label)
    (define prologos-bytes
      (extract-value-bytes
       (run-last (format "(eval (encode ~a))" sexp))))
    (define prologos-hex (string->hex prologos-bytes))
    (check-equal? prologos-hex hex
                  (format "Prologos encode mismatch for `~a`:
  sexp:        ~a
  JS hex:      ~a
  Prologos hex: ~a
  Prologos bytes: ~s"
                          label sexp hex prologos-hex prologos-bytes)))

  (test-case (format "syrup-cross-impl/decode ~a is some" label)
    (define bytes (hex->string hex))
    (define result
      (run-last (format "(eval (decode-value ~v))" bytes)))
    (check-true (string-contains? result "some")
                (format "Prologos decode failed for `~a` (hex ~a): ~s"
                        label hex result))))

#lang racket/base

;; test-splitter.rkt — Dynamic per-test-case file splitting
;;
;; Reads a Racket test file, separates preamble from (test-case ...) forms,
;; and generates one temp file per test-case. Temp files live in the same
;; directory as the original so define-runtime-path and relative requires
;; resolve correctly.
;;
;; Used by bench-lib.rkt to flatten whale test files into individual work
;; items for the thread pool, achieving CPU saturation throughout the run.

(require racket/path
         racket/string
         racket/list
         racket/port
         racket/file)

(provide split-test-file
         cleanup-split-files
         split-info-original
         split-info-test-name
         split-info-temp-path
         split-info-index)

;; A split-info records one extracted test-case
(struct split-info (original     ; string — original file path
                    test-name    ; string — test-case name
                    temp-path    ; string — path to generated temp file
                    index)       ; exact-nonneg-integer — 0-based index
  #:transparent)

;; ============================================================
;; Main entry: split a test file into per-test-case temp files
;; ============================================================

;; split-test-file : string -> (listof split-info)
;; Reads the test file, extracts (test-case ...) forms, writes one temp
;; file per test-case containing the #lang line + all preamble + that
;; single test-case.
(define (split-test-file test-path)
  (define full-text (file->string test-path))
  (define lines (string-split full-text "\n"))

  ;; 1. Capture the #lang line
  (define lang-line
    (cond
      [(and (pair? lines) (string-prefix? (car lines) "#lang"))
       (car lines)]
      [else
       (error 'split-test-file "No #lang line found in ~a" test-path)]))

  ;; 2. Read all s-expressions after the #lang line
  (define rest-text (string-join (cdr lines) "\n"))
  (define forms (read-all-forms rest-text))

  ;; 3. Partition into preamble and test-cases
  ;; Everything that is NOT (test-case ...) goes into preamble.
  ;; This handles interstitial helpers between test-case groups.
  (define-values (preamble test-cases)
    (partition (λ (form) (not (test-case-form? form))) forms))

  (when (null? test-cases)
    (error 'split-test-file "No (test-case ...) forms found in ~a" test-path))

  ;; 4. Generate temp files
  (define dir (path-only (string->path test-path)))
  (define stem (path->string (path-replace-extension
                               (file-name-from-path (string->path test-path))
                               "")))

  (for/list ([tc (in-list test-cases)]
             [i (in-naturals)])
    (define test-name (extract-test-case-name tc))
    (define temp-name (format "._split_~a_~a.rkt" stem (pad-index i)))
    (define temp-path (path->string (build-path dir temp-name)))

    ;; Write: #lang line + preamble forms + single test-case
    (call-with-output-file temp-path #:exists 'replace
      (λ (out)
        (displayln lang-line out)
        (newline out)
        ;; Write preamble forms
        (for ([form (in-list preamble)])
          (write form out)
          (newline out)
          (newline out))
        ;; Write the single test-case
        (write tc out)
        (newline out)))

    (split-info test-path test-name temp-path i)))

;; ============================================================
;; Cleanup: delete all temp files from a split operation
;; ============================================================

;; cleanup-split-files : (listof split-info) -> void
(define (cleanup-split-files infos)
  (for ([info (in-list infos)])
    (define path (split-info-temp-path info))
    (when (file-exists? path)
      (delete-file path))))

;; ============================================================
;; Helpers
;; ============================================================

;; Read all s-expressions from a string
(define (read-all-forms text)
  (define in (open-input-string text))
  (port-count-lines! in)
  (let loop ([acc '()])
    (define form (read in))
    (if (eof-object? form)
        (reverse acc)
        (loop (cons form acc)))))

;; Is this form a (test-case ...) expression?
(define (test-case-form? form)
  (and (pair? form)
       (eq? (car form) 'test-case)))

;; Extract the name string from (test-case "name" body ...)
(define (extract-test-case-name tc)
  (cond
    [(and (pair? tc) (>= (length tc) 2) (string? (cadr tc)))
     (cadr tc)]
    [else (format "test-~a" (gensym))]))

;; Zero-pad an index to 3 digits
(define (pad-index n)
  (define s (number->string n))
  (define padding (max 0 (- 3 (string-length s))))
  (string-append (make-string padding #\0) s))

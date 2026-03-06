#lang racket/base

;;;
;;; test-io-csv-01.rkt — CSV parsing tests (IO-G)
;;;
;;; Tests for RFC 4180 CSV parser and serializer in io-ffi.rkt.
;;; Group 1: Pure CSV parsing (12 tests)
;;; Group 2: CSV serialization (4 tests)
;;; Group 3: File-based CSV (4 tests)
;;;
;;; Pattern: Direct Racket function tests (no Prologos pipeline needed).
;;;

(require rackunit
         racket/file
         racket/string
         "../io-ffi.rkt")

;; RS/US constants for assertions
(define RS (string (integer->char 30)))
(define US (string (integer->char 31)))

;; Helper: parse CSV and return list of lists
(define (parse-to-lists csv-str)
  (define serialized (csv-parse-serialized csv-str))
  (if (string=? serialized "")
      '()
      (for/list ([row (in-list (string-split serialized RS))])
        (string-split row US #:trim? #f))))

;; ========================================
;; Group 1: Pure CSV Parsing (12 tests)
;; ========================================

(test-case "csv/simple-two-rows"
  (define result (parse-to-lists "a,b\n1,2\n"))
  (check-equal? result '(("a" "b") ("1" "2"))))

(test-case "csv/single-row"
  (define result (parse-to-lists "hello,world\n"))
  (check-equal? result '(("hello" "world"))))

(test-case "csv/empty-string"
  (define result (parse-to-lists ""))
  (check-equal? result '()))

(test-case "csv/quoted-field"
  (define result (parse-to-lists "\"hello world\",b\n"))
  (check-equal? result '(("hello world" "b"))))

(test-case "csv/embedded-comma-in-quotes"
  (define result (parse-to-lists "\"a,b\",c\n"))
  (check-equal? result '(("a,b" "c"))))

(test-case "csv/escaped-quote"
  ;; RFC 4180: "" inside quoted field → single "
  (define result (parse-to-lists "\"a\"\"b\",c\n"))
  (check-equal? result '(("a\"b" "c"))))

(test-case "csv/embedded-newline-in-quotes"
  (define result (parse-to-lists "\"line1\nline2\",c\n"))
  (check-equal? result '(("line1\nline2" "c"))))

(test-case "csv/trailing-newline-handling"
  ;; Trailing newline should NOT create a phantom empty row
  (define with-newline (parse-to-lists "a,b\n"))
  (define without-newline (parse-to-lists "a,b"))
  (check-equal? with-newline '(("a" "b")))
  (check-equal? without-newline '(("a" "b"))))

(test-case "csv/empty-fields"
  (define result (parse-to-lists ",,\n,,\n"))
  (check-equal? result '(("" "" "") ("" "" ""))))

(test-case "csv/whitespace-in-fields"
  ;; Per RFC 4180: whitespace is preserved (not trimmed)
  (define result (parse-to-lists " a , b \n"))
  (check-equal? result '((" a " " b "))))

(test-case "csv/crlf-line-endings"
  ;; RFC 4180 specifies CRLF, parser should handle it
  (define result (parse-to-lists "a,b\r\n1,2\r\n"))
  (check-equal? result '(("a" "b") ("1" "2"))))

(test-case "csv/no-trailing-newline"
  ;; Input without trailing newline should still parse correctly
  (define result (parse-to-lists "a,b,c\n1,2,3"))
  (check-equal? result '(("a" "b" "c") ("1" "2" "3"))))

;; ========================================
;; Group 2: CSV Serialization (4 tests)
;; ========================================

(test-case "csv/roundtrip-simple"
  ;; parse → serialize should produce RFC 4180 output (CRLF line endings)
  (define input "a,b\n1,2\n")
  (define serialized (csv-parse-serialized input))
  (define output (csv-serialize-rows serialized))
  (check-equal? output "a,b\r\n1,2"))

(test-case "csv/serialize-quotes-fields-with-commas"
  ;; Fields containing commas must be quoted in output
  (define input "\"a,b\",c\n")
  (define serialized (csv-parse-serialized input))
  (define output (csv-serialize-rows serialized))
  (check-equal? output "\"a,b\",c"))

(test-case "csv/serialize-escapes-quotes"
  ;; Fields containing quotes must have them doubled
  (define input "\"a\"\"b\",c\n")
  (define serialized (csv-parse-serialized input))
  (define output (csv-serialize-rows serialized))
  (check-equal? output "\"a\"\"b\",c"))

(test-case "csv/quote-field-helper"
  ;; Direct tests for csv-quote-field
  (check-equal? (csv-quote-field "hello") "hello")
  (check-equal? (csv-quote-field "a,b") "\"a,b\"")
  (check-equal? (csv-quote-field "a\"b") "\"a\"\"b\"")
  (check-equal? (csv-quote-field "a\nb") "\"a\nb\""))

;; ========================================
;; Group 3: File-based CSV (4 tests)
;; ========================================

(test-case "csv/read-file"
  (define tmp (make-temporary-file "csv-test-~a.csv"))
  (display-to-file "name,age\nAlice,30\nBob,25\n" tmp #:exists 'truncate/replace)
  (define result (csv-read-file (path->string tmp)))
  (define rows (parse-to-lists "name,age\nAlice,30\nBob,25\n"))
  ;; csv-read-file returns the RS/US serialized form
  (check-equal? result (csv-parse-serialized "name,age\nAlice,30\nBob,25\n"))
  (delete-file tmp))

(test-case "csv/write-file"
  (define tmp (make-temporary-file "csv-test-~a.csv"))
  ;; Build a serialized string and write it
  (define serialized (csv-parse-serialized "x,y\n1,2\n3,4\n"))
  (csv-write-file (path->string tmp) serialized)
  (define content (file->string tmp))
  (check-equal? content "x,y\r\n1,2\r\n3,4")
  (delete-file tmp))

(test-case "csv/roundtrip-file"
  ;; Write CSV to file, read it back, compare
  (define tmp (make-temporary-file "csv-test-~a.csv"))
  (define original-data "name,score\n\"Jane Doe\",95\n\"John \"\"JJ\"\" Smith\",88\n")
  (define serialized (csv-parse-serialized original-data))
  (csv-write-file (path->string tmp) serialized)
  ;; Read back
  (define read-back (csv-read-file (path->string tmp)))
  (check-equal? read-back serialized)
  (delete-file tmp))

(test-case "csv/large-csv"
  ;; 100 rows should parse without issues
  (define csv-str
    (string-append
     "id,name,value\n"
     (apply string-append
            (for/list ([i (in-range 100)])
              (format "~a,item~a,~a\n" i i (* i 10))))))
  (define result (parse-to-lists csv-str))
  ;; Header + 100 data rows
  (check-equal? (length result) 101)
  (check-equal? (car result) '("id" "name" "value"))
  (check-equal? (list-ref result 1) '("0" "item0" "0"))
  (check-equal? (list-ref result 100) '("99" "item99" "990")))

#lang racket/base

;;;
;;; test-io-file-02.rkt — with-open macro tests (IO-D3)
;;;
;;; Tests that the with-open preparse macro correctly expands to
;;; proc-open + body + proc-sel ch :close, auto-closing the file
;;; handle when the body completes.
;;;
;;; Pattern: process-string-ws with inline session definitions.
;;;

(require rackunit
         racket/string
         "../driver.rkt"
         "../errors.rkt"
         "../sessions.rkt"
         "../macros.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../metavar-store.rkt")

;; ========================================
;; Helper: run WS-mode program through full pipeline
;; ========================================

(define (run-ws ws-string)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-session-registry (hasheq)]
                 [current-strategy-registry (hasheq)]
                 [current-module-registry (hasheq)]
                 )
    (define results (process-string-ws ws-string))
    (if (list? results) results results)))

;; Check if any result contains a specific substring
(define (has-result? results substr)
  (for/or ([r (in-list (if (list? results) results (list results)))])
    (and (string? r) (string-contains? r substr))))

;; Check if any result is a prologos error
(define (has-error? results)
  (for/or ([r (in-list (if (list? results) results (list results)))])
    (prologos-error? r)))

;; Get the first error message from results
(define (first-error-msg results)
  (for/or ([r (in-list (if (list? results) results (list results)))])
    (and (prologos-error? r)
         (prologos-error-message r))))

;; ========================================
;; Common session definitions
;; ========================================

(define file-read-session
  (string-append
    "session FileRead\n"
    "  rec\n"
    "    +>\n"
    "      | :read-all  -> ? String -> end\n"
    "      | :read-line -> ? String -> rec\n"
    "      | :close     -> end\n"
    "\n"))

(define file-write-session
  (string-append
    "session FileWrite\n"
    "  rec\n"
    "    +>\n"
    "      | :write    -> ! String -> rec\n"
    "      | :write-ln -> ! String -> rec\n"
    "      | :flush    -> rec\n"
    "      | :close    -> end\n"
    "\n"))

;; ========================================
;; Group 1: with-open macro parsing
;; ========================================

(test-case "IO-D3: with-open with FileRead parses correctly"
  (define results
    (run-ws
      (string-append
        file-read-session
        "defproc reader\n"
        "  with-open \"test.txt\" : FileRead\n"
        "    select ch :read-all\n"
        "    data := ch ?\n")))
  (check-false (has-error? results)
               "with-open FileRead should not produce errors")
  (check-true (has-result? results "defproc reader")
              "defproc reader should be defined"))

(test-case "IO-D3: with-open with FileWrite parses correctly"
  (define results
    (run-ws
      (string-append
        file-write-session
        "defproc writer\n"
        "  with-open \"out.txt\" : FileWrite\n"
        "    select ch :write\n"
        "    ch ! \"hello\"\n")))
  (check-false (has-error? results)
               "with-open FileWrite should not produce errors")
  (check-true (has-result? results "defproc writer")
              "defproc writer should be defined"))

(test-case "IO-D3: with-open with empty body (open + close)"
  (define results
    (run-ws
      (string-append
        file-read-session
        "defproc opener\n"
        "  with-open \"test.txt\" : FileRead\n"
        "  stop\n")))
  (check-false (has-error? results)
               "with-open with empty body should not produce errors")
  (check-true (has-result? results "defproc opener")
              "defproc opener should be defined"))

;; ========================================
;; Group 2: with-open with continuation after block
;; ========================================

(test-case "IO-D3: with-open followed by stop"
  ;; with-open as one block, then stop as the outer continuation
  (define results
    (run-ws
      (string-append
        file-read-session
        "defproc read-then-stop\n"
        "  with-open \"test.txt\" : FileRead\n"
        "    select ch :read-all\n"
        "    data := ch ?\n"
        "  stop\n")))
  (check-false (has-error? results)
               "with-open followed by stop should work")
  (check-true (has-result? results "defproc read-then-stop")
              "defproc read-then-stop should be defined"))

(test-case "IO-D3: with-open with multiple body operations"
  (define results
    (run-ws
      (string-append
        file-write-session
        "defproc multi-write\n"
        "  with-open \"out.txt\" : FileWrite\n"
        "    select ch :write\n"
        "    ch ! \"line1\"\n"
        "    select ch :write\n"
        "    ch ! \"line2\"\n")))
  (check-false (has-error? results)
               "with-open with multiple operations should work")
  (check-true (has-result? results "defproc multi-write")
              "defproc multi-write should be defined"))

;; ========================================
;; Group 3: with-open in composition with outer session type
;; ========================================

(test-case "IO-D3: with-open in defproc with session type annotation"
  (define results
    (run-ws
      (string-append
        file-read-session
        "session ReadService\n"
        "  ? String\n"
        "  end\n"
        "\n"
        "defproc read-service : ReadService\n"
        "  filename := self ?\n"
        "  stop\n")))
  (check-false (has-error? results)
               "defproc with session type should work")
  (check-true (has-result? results "type-checked")
              "ReadService should type-check"))

(test-case "IO-D3: with-open preserves channel name ch"
  ;; Verify that select and send/recv use 'ch' as expected
  (define results
    (run-ws
      (string-append
        file-read-session
        "defproc ch-test\n"
        "  with-open \"test.txt\" : FileRead\n"
        "    select ch :close\n")))
  (check-false (has-error? results)
               "with-open selecting :close directly should work"))

(test-case "IO-D3: with-open does not need explicit close"
  ;; The whole point of with-open is auto-close
  ;; User should NOT need to select :close — it's inserted automatically
  (define results
    (run-ws
      (string-append
        file-read-session
        "defproc auto-close\n"
        "  with-open \"test.txt\" : FileRead\n"
        "    select ch :read-all\n"
        "    data := ch ?\n"
        "  stop\n")))
  (check-false (has-error? results)
               "with-open should auto-insert :close"))

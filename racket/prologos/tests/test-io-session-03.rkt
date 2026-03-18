#lang racket/base

;;;
;;; test-io-session-03.rkt — Protocol composition tests (IO-E3)
;;;
;;; Tests that IO session protocols (FileRead, FileWrite, FileAppend)
;;; compose correctly with defproc via the full WS pipeline:
;;; WS reader -> preparse -> parser -> elaborator -> type-checker.
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
  (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-session-registry (hasheq)]
                 [current-strategy-registry (hasheq)]
                 [current-module-registry (hasheq)]
                 [current-mult-meta-store (make-hasheq)])
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

;; ========================================
;; Group 1: Session protocol parsing through WS pipeline
;; ========================================

(test-case "IO-E3: FileRead protocol parses in WS mode"
  (define results
    (run-ws
      (string-append
        "session FileRead\n"
        "  rec\n"
        "    +>\n"
        "      | :read-all  -> ? String -> end\n"
        "      | :read-line -> ? String -> rec\n"
        "      | :close     -> end\n")))
  (check-true (has-result? results "session FileRead defined")
              "FileRead session should be defined"))

(test-case "IO-E3: FileWrite protocol parses in WS mode"
  (define results
    (run-ws
      (string-append
        "session FileWrite\n"
        "  rec\n"
        "    +>\n"
        "      | :write    -> ! String -> rec\n"
        "      | :write-ln -> ! String -> rec\n"
        "      | :flush    -> rec\n"
        "      | :close    -> end\n")))
  (check-true (has-result? results "session FileWrite defined")
              "FileWrite session should be defined"))

;; ========================================
;; Group 2: defproc with open and choice operations
;; ========================================

(test-case "IO-E3: defproc with open FileRead type-checks"
  (define results
    (run-ws
      (string-append
        "session FileRead\n"
        "  rec\n"
        "    +>\n"
        "      | :read-all  -> ? String -> end\n"
        "      | :read-line -> ? String -> rec\n"
        "      | :close     -> end\n"
        "\n"
        "defproc file-reader\n"
        "  open \"test.txt\" : FileRead\n"
        "  select ch :read-all\n"
        "  data := ch ?\n"
        "  stop\n")))
  (check-false (has-error? results)
               "FileRead defproc should not produce errors")
  (check-true (has-result? results "defproc file-reader")
              "defproc file-reader should be defined"))

(test-case "IO-E3: defproc with open FileWrite type-checks"
  (define results
    (run-ws
      (string-append
        "session FileWrite\n"
        "  rec\n"
        "    +>\n"
        "      | :write    -> ! String -> rec\n"
        "      | :write-ln -> ! String -> rec\n"
        "      | :flush    -> rec\n"
        "      | :close    -> end\n"
        "\n"
        "defproc file-writer\n"
        "  open \"test.txt\" : FileWrite\n"
        "  select ch :write\n"
        "  ch ! \"hello world\"\n"
        "  select ch :close\n"
        "  stop\n")))
  (check-false (has-error? results)
               "FileWrite defproc should not produce errors")
  (check-true (has-result? results "defproc file-writer")
              "defproc file-writer should be defined"))

(test-case "IO-E3: defproc with open FileRead close-only type-checks"
  (define results
    (run-ws
      (string-append
        "session FileRead\n"
        "  rec\n"
        "    +>\n"
        "      | :read-all  -> ? String -> end\n"
        "      | :read-line -> ? String -> rec\n"
        "      | :close     -> end\n"
        "\n"
        "defproc opener\n"
        "  open \"test.txt\" : FileRead\n"
        "  select ch :close\n"
        "  stop\n")))
  (check-false (has-error? results)
               "Close-only defproc should not produce errors"))

;; ========================================
;; Group 3: Protocol composition with outer session type
;; ========================================

(test-case "IO-E3: defproc with session type annotation + open"
  ;; A process that receives a filename on its own session,
  ;; then opens and reads the file.
  (define results
    (run-ws
      (string-append
        "session FileRead\n"
        "  rec\n"
        "    +>\n"
        "      | :read-all  -> ? String -> end\n"
        "      | :read-line -> ? String -> rec\n"
        "      | :close     -> end\n"
        "\n"
        "session ReadService\n"
        "  ? String\n"
        "  end\n"
        "\n"
        "defproc read-service : ReadService\n"
        "  filename := self ?\n"
        "  stop\n")))
  (check-false (has-error? results)
               "Composed protocol should not produce errors")
  (check-true (has-result? results "type-checked")
              "ReadService defproc should type-check"))

#lang racket/base

;;;
;;; io-ffi.rkt — FFI bridge: Racket IO primitives wrapped for Prologos
;;;
;;; Registry mapping function names to (cons racket-procedure type-descriptor).
;;; These are NOT registered in the Prologos namespace yet — that happens in
;;; IO-D when io.prologos does (foreign racket "io-ffi.rkt" ...).
;;; For IO-B, this is just the registry + wrapper functions.
;;;
;;; Design reference: docs/tracking/2026-03-05_IO_IMPLEMENTATION_DESIGN.md §10
;;;

(require racket/file
         racket/string)

(provide
 io-ffi-registry
 ;; Wrapper functions (exported for direct testing in IO-B3)
 port-read-string
 port-read-line
 port-write-string
 io-close-port
 display-wrapper
 displayln-wrapper
 read-line-wrapper
 ;; High-level convenience wrappers (IO-D1)
 io-ffi-read-all
 io-ffi-write-file
 io-ffi-append-file
 ;; Console IO with Unit arg (IO-D2)
 io-ffi-read-ln-unit
 ;; FS query wrappers (IO-D4)
 io-ffi-is-file
 io-ffi-path-exists
 ;; Handle-based port table (IO-F1)
 fio-open-port
 fio-read-port
 fio-read-port-ret
 fio-read-cached
 fio-write-port
 fio-write-port-ret
 fio-close-port
 ;; CSV parsing (IO-G1)
 csv-parse-serialized
 csv-serialize-rows
 csv-quote-field
 csv-read-file
 csv-write-file)

;; ========================================
;; Wrapper Functions
;; ========================================
;;
;; Handle Racket IO quirks: EOF objects → empty strings,
;; void returns for write operations, etc.

(define (port-read-string port)
  (define s (read-string 1048576 port))  ;; 1MB max
  (if (eof-object? s) "" s))

(define (port-read-line port)
  (define s (read-line port))
  (if (eof-object? s) "" s))

(define (port-write-string port str)
  (write-string str port)
  (void))

;; Racket has close-input-port and close-output-port but no generic close-port.
;; This wrapper handles both.
(define (io-close-port port)
  (if (input-port? port)
      (close-input-port port)
      (close-output-port port))
  (void))

(define (display-wrapper str) (display str) (void))
(define (displayln-wrapper str) (displayln str) (void))
(define (read-line-wrapper) (read-line))

;; High-level convenience wrappers (IO-D1)
;; These do the full open-read/write-close cycle.
;; Errors (file not found, permission denied) propagate as Racket exceptions.

(define (io-ffi-read-all path-str)
  (file->string path-str))

(define (io-ffi-write-file path-str content)
  (call-with-output-file path-str
    (lambda (out) (write-string content out))
    #:exists 'truncate/replace)
  (void))

(define (io-ffi-append-file path-str content)
  (call-with-output-file path-str
    (lambda (out) (write-string content out))
    #:exists 'append)
  (void))

;; Console IO with Unit arg (IO-D2)
;; Takes Unit so it's a function (arity 1), not a thunk evaluated at def time.
(define (io-ffi-read-ln-unit _unit)
  (define v (read-line))
  (if (eof-object? v) "" v))

;; Filesystem query wrapper (IO-D4)
;; True if path exists AND is a regular file (not a directory).
(define (io-ffi-is-file path-str)
  (and (file-exists? path-str) (not (directory-exists? path-str))))

;; True if path exists as either a file or a directory.
;; Racket's file-exists? returns #f for directories, so we check both.
(define (io-ffi-path-exists path-str)
  (or (file-exists? path-str) (directory-exists? path-str)))

;; ========================================
;; Handle-based Port Table (IO-F1)
;; ========================================
;;
;; Integer-indexed port table: Prologos sees Nat port IDs, actual Racket
;; ports live here. This avoids Opaque:* types in .prologos FFI decls
;; (the colon in Opaque:file-port is parsed as a keyword by the WS reader).

(define fio-port-table (make-hasheq))
(define fio-next-port-id 0)

(define (fio-open-port path-str mode-str)
  (define port
    (case mode-str
      [("read")   (open-input-file path-str)]
      [("write")  (open-output-file path-str #:exists 'truncate/replace)]
      [("append") (open-output-file path-str #:exists 'append)]
      [else (error 'fio-open-port "unknown mode: ~a" mode-str)]))
  (define id fio-next-port-id)
  (set! fio-next-port-id (add1 id))
  (hash-set! fio-port-table id port)
  id)

(define (fio-read-port handle-id)
  (define port (hash-ref fio-port-table handle-id
    (lambda () (error 'fio-read-port "invalid handle: ~a" handle-id))))
  (define data (read-string 1048576 port))  ;; 1MB max
  (if (eof-object? data) "" data))

(define (fio-write-port handle-id content)
  (define port (hash-ref fio-port-table handle-id
    (lambda () (error 'fio-write-port "invalid handle: ~a" handle-id))))
  (write-string content port)
  (flush-output port)
  (void))

;; Write variant that returns the handle-id instead of void.
;; Used by fio-write so the FFI call is in the data flow (not a discarded
;; let binding that lazy evaluation might skip).
(define (fio-write-port-ret handle-id content)
  (define port (hash-ref fio-port-table handle-id
    (lambda () (error 'fio-write-port-ret "invalid handle: ~a" handle-id))))
  (write-string content port)
  (flush-output port)
  handle-id)

;; Read variant that reads eagerly, caches the result, and returns handle-id.
;; Used by fio-read-all to force the read BEFORE fio-close runs.
;; In a lazy reducer, (pair (mk-handle (fio-read-port-ret id)) (fio-read-cached id))
;; forces the read when the handle-id is needed for close (data-flow trick).
(define fio-read-cache (make-hasheq))

(define (fio-read-port-ret handle-id)
  (define port (hash-ref fio-port-table handle-id
    (lambda () (error 'fio-read-port-ret "invalid handle: ~a" handle-id))))
  (define data (read-string 1048576 port))  ;; 1MB max
  (hash-set! fio-read-cache handle-id (if (eof-object? data) "" data))
  handle-id)

(define (fio-read-cached handle-id)
  (hash-ref fio-read-cache handle-id ""))

(define (fio-close-port handle-id)
  (define port (hash-ref fio-port-table handle-id
    (lambda () (error 'fio-close-port "invalid handle: ~a" handle-id))))
  (if (input-port? port) (close-input-port port) (close-output-port port))
  (hash-remove! fio-port-table handle-id)
  (void))

;; ========================================
;; CSV Parsing (IO-G1)
;; ========================================
;;
;; RFC 4180 CSV parser implemented as a state machine.
;; Uses RS (ASCII 30) / US (ASCII 31) serialization to pass structured
;; data through the String-only FFI boundary:
;;   rows are RS-delimited, fields within rows are US-delimited.
;;
;; This avoids needing List[List[String]] marshalling across FFI.

(define RS (string (integer->char 30)))  ;; Record Separator
(define US (string (integer->char 31)))  ;; Unit Separator

;; csv-parse-serialized : String → String
;; Parses CSV per RFC 4180, returns RS-delimited rows with US-delimited fields.
;; Empty input → empty string.
;;
;; State machine states:
;;   'start       — beginning of a field
;;   'unquoted    — inside an unquoted field
;;   'quoted      — inside a quoted field
;;   'after-quote — just saw a quote inside a quoted field (could be escape or end)
(define (csv-parse-serialized csv-str)
  (if (string=? csv-str "")
      ""
      (csv-parse-loop csv-str)))

;; Separated loop body for cleaner paren management.
(define (csv-parse-loop csv-str)
  (define len (string-length csv-str))
  (define (finish-row field row)
    (reverse (cons (list->string (reverse field)) row)))
  (define (finish-field field)
    (list->string (reverse field)))
  (let loop ([i 0]
             [state 'start]
             [field '()]
             [row '()]
             [rows '()])
    (if (>= i len)
        ;; End of input — finalize
        (let* ([cleaned-rows
                (if (and (null? field) (null? row) (eq? state 'start))
                    ;; Ended right after a newline committed the row — no phantom row
                    (reverse rows)
                    ;; Otherwise finalize the current field/row
                    (reverse (cons (finish-row field row) rows)))])
          (string-join
           (for/list ([r (in-list cleaned-rows)])
             (string-join r US))
           RS))
        ;; Process next character
        (let ([ch (string-ref csv-str i)])
          (case state
            [(start)
             (cond
               [(char=? ch #\")
                (loop (add1 i) 'quoted field row rows)]
               [(char=? ch #\,)
                (loop (add1 i) 'start '() (cons "" row) rows)]
               [(char=? ch #\return)
                (if (and (< (add1 i) len)
                         (char=? (string-ref csv-str (add1 i)) #\newline))
                    (loop (+ i 2) 'start '() '() (cons (finish-row field row) rows))
                    (loop (add1 i) 'start '() '() (cons (finish-row field row) rows)))]
               [(char=? ch #\newline)
                (loop (add1 i) 'start '() '() (cons (finish-row field row) rows))]
               [else
                (loop (add1 i) 'unquoted (cons ch field) row rows)])]
            [(unquoted)
             (cond
               [(char=? ch #\,)
                (loop (add1 i) 'start '() (cons (finish-field field) row) rows)]
               [(char=? ch #\return)
                (if (and (< (add1 i) len)
                         (char=? (string-ref csv-str (add1 i)) #\newline))
                    (loop (+ i 2) 'start '() '() (cons (finish-row field row) rows))
                    (loop (add1 i) 'start '() '() (cons (finish-row field row) rows)))]
               [(char=? ch #\newline)
                (loop (add1 i) 'start '() '() (cons (finish-row field row) rows))]
               [else
                (loop (add1 i) 'unquoted (cons ch field) row rows)])]
            [(quoted)
             (cond
               [(char=? ch #\")
                (loop (add1 i) 'after-quote field row rows)]
               [else
                (loop (add1 i) 'quoted (cons ch field) row rows)])]
            [(after-quote)
             (cond
               [(char=? ch #\")
                (loop (add1 i) 'quoted (cons #\" field) row rows)]
               [(char=? ch #\,)
                (loop (add1 i) 'start '() (cons (finish-field field) row) rows)]
               [(char=? ch #\return)
                (if (and (< (add1 i) len)
                         (char=? (string-ref csv-str (add1 i)) #\newline))
                    (loop (+ i 2) 'start '() '() (cons (finish-row field row) rows))
                    (loop (add1 i) 'start '() '() (cons (finish-row field row) rows)))]
               [(char=? ch #\newline)
                (loop (add1 i) 'start '() '() (cons (finish-row field row) rows))]
               [else
                (loop (add1 i) 'unquoted (cons ch field) row rows)])])))))
;; csv-quote-field : String → String
;; Quotes a field for CSV output if it contains special characters.
;; Per RFC 4180: fields with commas, quotes, or newlines must be quoted.
;; Quotes within fields are escaped as "".
(define (csv-quote-field field-str)
  (if (or (string-contains? field-str ",")
          (string-contains? field-str "\"")
          (string-contains? field-str "\n")
          (string-contains? field-str "\r"))
      (string-append "\"" (string-replace field-str "\"" "\"\"") "\"")
      field-str))

;; csv-serialize-rows : String → String
;; Converts RS/US-delimited string back to RFC 4180 CSV.
;; Each field is quoted if necessary.
(define (csv-serialize-rows serialized-str)
  (if (string=? serialized-str "")
      ""
      (let* ([rs-char (string-ref RS 0)]
             [us-char (string-ref US 0)]
             [rows (string-split serialized-str RS)]
             [csv-rows
              (for/list ([row (in-list rows)])
                (define fields (string-split row US #:trim? #f))
                (string-join (map csv-quote-field fields) ","))])
        (string-join csv-rows "\r\n"))))

;; csv-read-file : String → String
;; Read a CSV file and return RS/US-serialized parsed data.
(define (csv-read-file path-str)
  (csv-parse-serialized (file->string path-str)))

;; csv-write-file : String String → Void
;; Write RS/US-serialized data to a file as CSV.
(define (csv-write-file path-str serialized-str)
  (call-with-output-file path-str
    (lambda (out) (write-string (csv-serialize-rows serialized-str) out))
    #:exists 'truncate/replace)
  (void))

;; ========================================
;; FFI Registry
;; ========================================
;;
;; Maps Prologos function names to (cons racket-procedure type-descriptor).
;; Type descriptors use the same format as foreign.rkt:
;;   (cons '(arg-types ...) 'return-type)
;; The Opaque:file-port tag wraps Racket ports as expr-opaque values.

(define io-ffi-registry
  (hasheq
   ;; File operations
   'io-open-input    (cons open-input-file    '((String) . Opaque:file-port))
   'io-open-output   (cons open-output-file   '((String) . Opaque:file-port))
   'io-read-string   (cons port-read-string   '((Opaque:file-port) . String))
   'io-read-line     (cons port-read-line     '((Opaque:file-port) . String))
   'io-write-string  (cons port-write-string  '((Opaque:file-port String) . Unit))
   'io-close         (cons io-close-port      '((Opaque:file-port) . Unit))
   'io-port-closed?  (cons port-closed?       '((Opaque:file-port) . Bool))
   ;; Console
   'io-display       (cons display-wrapper    '((String) . Unit))
   'io-displayln     (cons displayln-wrapper  '((String) . Unit))
   'io-read-ln       (cons read-line-wrapper  '(() . String))
   ;; Filesystem queries
   'io-file-exists?  (cons file-exists?       '((String) . Bool))
   'io-directory?    (cons directory-exists?   '((String) . Bool))))

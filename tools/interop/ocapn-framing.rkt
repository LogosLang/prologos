#lang racket/base

;;;
;;; ocapn-framing.rkt — Phase 58 netlayer framing.
;;;
;;; Configurable framing strategy for the OCapN wire. Two strategies
;;; are supported:
;;;
;;;   'newline       — Each frame is terminated by 0x0a (\n). Our
;;;                    own cross-impl interop tests use this so they
;;;                    can use line-oriented read/write. Convenient
;;;                    but non-canonical.
;;;
;;;   'raw-syrup     — Each frame is one self-delimiting Syrup
;;;                    value. The framing relies on Syrup's
;;;                    structural delimiters (`[]`, `<>`, `{}`,
;;;                    length-prefixed atoms). This is what the
;;;                    OCapN canonical spec uses (the upstream
;;;                    ocapn-test-suite reads via `syrup_read`).
;;;
;;; The reader returns one frame at a time as raw bytes. Callers
;;; can pass the bytes to whatever decoder they need (the Prologos
;;; bridge's `decode-op`, or a JS peer's `decodeSyrup`).

(require racket/base
         racket/port)

(provide read-frame
         write-frame
         framing-strategy?
         current-framing-strategy)

(define (framing-strategy? v)
  (and (memq v '(newline raw-syrup)) #t))

(define (framing-strategy-guard v)
  (unless (framing-strategy? v)
    (raise-arguments-error 'current-framing-strategy
                           "expected 'newline or 'raw-syrup"
                           "got" v))
  v)

(define current-framing-strategy
  (make-parameter 'newline framing-strategy-guard))

;; ========================================
;; Writer
;; ========================================

(define (write-frame port payload [strategy (current-framing-strategy)])
  "Write `payload` (bytes) to `port` as one frame using the given strategy."
  (case strategy
    [(newline)
     (write-bytes payload port)
     (write-byte #x0a port)]
    [(raw-syrup)
     (write-bytes payload port)]
    [else (error 'write-frame "unknown framing strategy: ~v" strategy)])
  (flush-output port))

;; ========================================
;; Reader
;; ========================================

(define (read-frame port [strategy (current-framing-strategy)])
  "Read one frame from `port` as bytes. Returns #f on EOF before
   any bytes are read."
  (case strategy
    [(newline) (read-newline-frame port)]
    [(raw-syrup) (read-syrup-frame port)]
    [else (error 'read-frame "unknown framing strategy: ~v" strategy)]))

(define (read-newline-frame port)
  "Read bytes up to (but not including) the next 0x0a."
  (define out (open-output-bytes))
  (let loop ()
    (define b (read-byte port))
    (cond
      [(eof-object? b)
       (define gathered (get-output-bytes out))
       (if (= 0 (bytes-length gathered)) #f gathered)]
      [(= b #x0a) (get-output-bytes out)]
      [else (write-byte b out) (loop)])))

;; ----------------------------------------
;; Raw-syrup self-delimiting reader
;; ----------------------------------------
;;
;; The Syrup grammar for ONE value is:
;;   atoms       — `digits "+"` (nat) | `digits "-"` (negative int) |
;;                 `digits ":" bytes` (bytes) | `digits '"' bytes` (string) |
;;                 `digits "'" bytes` (symbol) | `"t" | "f"` (bool) |
;;                 `"F" 4-bytes` (float) | `"D" 8-bytes` (double)
;;   composites  — `"[" v* "]"` (list) | `"<" v+ ">"` (record) |
;;                 `"{" (key val)* "}"` (dict)
;;
;; A streaming decoder reads bytes one at a time, tracking nesting
;; depth for `[<{` (open) and `]>}` (close). At depth 0, when a
;; complete value's last byte is consumed, the frame is complete.
;;
;; For length-prefixed atoms (`123:bytes`), we accumulate digits
;; until the prefix-terminator, then read that many payload bytes
;; without counting them toward nesting.

(define (read-syrup-frame port)
  "Read one complete Syrup value from `port` as bytes. Returns #f on EOF before any bytes are read."
  (define out (open-output-bytes))
  (define depth 0)
  ;; State machine for length-prefixed atoms.
  ;;   #f                  — not currently in a length-prefix
  ;;   (cons 'digits buf)  — accumulating digits
  ;;   (cons 'payload n)   — copying n more bytes verbatim
  (define lp #f)
  ;; Did we read at least one non-EOF byte? Used to distinguish
  ;; "EOF before frame" (#f) from "complete frame" (bytes).
  (define got-any? #f)
  (define (done?) (and got-any? (= depth 0) (not lp)))
  (let loop ()
    (define b (read-byte port))
    (cond
      [(eof-object? b)
       (cond
         [(not got-any?) #f]
         [else (error 'read-syrup-frame
                      "EOF mid-frame at depth ~a (lp=~v); bytes so far: ~v"
                      depth lp (get-output-bytes out))])]
      [else
       (set! got-any? #t)
       (write-byte b out)
       (cond
         ;; Inside a length-prefix payload — copy verbatim, decrement count.
         [(and (pair? lp) (eq? (car lp) 'payload))
          (define remaining (- (cdr lp) 1))
          (if (= remaining 0)
              (set! lp #f)
              (set! lp (cons 'payload remaining)))
          (if (done?) (get-output-bytes out) (loop))]
         ;; Inside the digits part of a length-prefix.
         [(and (pair? lp) (eq? (car lp) 'digits))
          (cond
            [(and (>= b #x30) (<= b #x39))
             (set! lp (cons 'digits (bytes-append (cdr lp) (bytes b))))
             (loop)]
            [(or (= b #x3a) (= b #x22) (= b #x27))   ; ':' or '"' or "'"
             ;; Length-prefix terminator: switch to payload mode.
             (define n (string->number (bytes->string/utf-8 (cdr lp))))
             (cond
               [(= n 0)
                (set! lp #f)
                (if (done?) (get-output-bytes out) (loop))]
               [else
                (set! lp (cons 'payload n))
                (loop)])]
            [(or (= b #x2b) (= b #x2d))              ; '+' or '-'
             ;; Length-prefix was actually an integer (nat or negint).
             (set! lp #f)
             (if (done?) (get-output-bytes out) (loop))]
            [else (error 'read-syrup-frame
                         "unexpected byte ~a after digits ~v"
                         b (cdr lp))])]
         ;; Not in a length-prefix.
         [else
          (cond
            [(or (= b #x5b) (= b #x3c) (= b #x7b))   ; '[' or '<' or '{'
             (set! depth (+ depth 1))
             (loop)]
            [(or (= b #x5d) (= b #x3e) (= b #x7d))   ; ']' or '>' or '}'
             (set! depth (- depth 1))
             (if (done?) (get-output-bytes out) (loop))]
            [(or (= b #x74) (= b #x66))              ; 't' or 'f' (bool)
             (if (done?) (get-output-bytes out) (loop))]
            [(= b #x46)                              ; 'F' single-float: read 4 bytes
             (define payload (read-bytes 4 port))
             (write-bytes payload out)
             (if (done?) (get-output-bytes out) (loop))]
            [(= b #x44)                              ; 'D' double-float: read 8 bytes
             (define payload (read-bytes 8 port))
             (write-bytes payload out)
             (if (done?) (get-output-bytes out) (loop))]
            [(and (>= b #x30) (<= b #x39))           ; '0'-'9' starts a digit string
             (set! lp (cons 'digits (bytes b)))
             (loop)]
            [else (error 'read-syrup-frame
                         "unexpected byte ~a at depth ~a (~v so far)"
                         b depth (get-output-bytes out))])])])))

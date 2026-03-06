#lang racket/base

;;;
;;; io-bridge.rkt — IO state lattice and side-effecting IO bridge propagator
;;;
;;; The IO bridge translates session protocol operations on IO channels into
;;; actual side effects (file reads/writes). The propagator network IS the
;;; IO scheduler — side effects are intentional at this boundary.
;;;
;;; Design reference: docs/tracking/2026-03-05_IO_IMPLEMENTATION_DESIGN.md §6
;;;

(require "propagator.rkt"
         "sessions.rkt"
         "syntax.rkt")

(provide
 ;; IO state lattice elements
 io-bot io-top io-closed
 (struct-out io-opening)
 (struct-out io-open)
 ;; IO state predicates
 io-bot? io-top? io-closed?
 ;; Lattice operations
 io-state-merge
 io-state-contradicts?
 ;; IO bridge propagator (IO-B2)
 make-io-bridge-propagator
 make-io-bridge-cell
 io-bridge-open-file
 make-io-error-from-exn)

;; ========================================
;; IO State Lattice
;; ========================================
;;
;; Flat lattice with distinguished transition elements:
;;
;;   io-bot          (⊥ — no IO has occurred)
;;     │
;;   io-opening(path, mode)    (file is being opened)
;;     │
;;   io-open(port, mode)       (file is open, port is the Racket port)
;;     │
;;   io-closed                 (file handle released)
;;     │
;;   io-top          (⊤ — contradiction: e.g., read after close)
;;

;; --- Sentinels ---

(define io-bot 'io-bot)
(define io-top 'io-top)
(define io-closed 'io-closed)

;; --- Structured states ---

(struct io-opening (path mode) #:transparent)  ; path: String, mode: 'read | 'write | 'append
(struct io-open (port mode) #:transparent)     ; port: Racket port, mode preserved

;; --- Predicates ---

(define (io-bot? v) (eq? v 'io-bot))
(define (io-top? v) (eq? v 'io-top))
(define (io-closed? v) (eq? v 'io-closed))

;; --- Lattice merge ---
;;
;; Valid transitions (monotone):
;;   io-bot → anything              (identity)
;;   io-opening → io-open           (file opened successfully)
;;   io-open → io-closed            (file closed)
;;   same → same                    (idempotent)
;;   everything else → io-top       (contradiction)

(define (io-state-merge old new)
  (cond
    [(io-bot? old) new]
    [(io-bot? new) old]
    [(io-top? old) io-top]
    [(io-top? new) io-top]
    ;; Valid transitions: opening → open, open → closed
    [(and (io-opening? old) (io-open? new)) new]
    [(and (io-open? old) (io-closed? new)) new]
    ;; Same state: idempotent
    [(equal? old new) old]
    ;; Everything else: contradiction
    [else io-top]))

;; --- Contradiction detection ---

(define (io-state-contradicts? v) (io-top? v))

;; ========================================
;; IO Bridge Propagator (IO-B2)
;; ========================================
;;
;; Side-effecting propagator that watches session cells and performs actual IO.
;; The propagator network IS the IO scheduler — side effects are intentional.
;; Only used with the sequential Gauss-Seidel scheduler (never BSP/parallel).
;;

;; --- Local predicates ---
;; Avoid circular dependency: session-runtime.rkt requires io-bridge.rkt,
;; so io-bridge.rkt cannot require session-runtime.rkt.
;; msg-bot is the symbol 'msg-bot (sentinel defined in session-runtime.rkt).
(define (io-msg-bot? v) (eq? v 'msg-bot))

;; sess-send-like? / sess-recv-like? are internal to session-runtime.rkt.
;; Define local equivalents using struct predicates from sessions.rkt.
(define (io-sess-send? v) (or (sess-send? v) (sess-async-send? v)))
(define (io-sess-recv? v) (or (sess-recv? v) (sess-async-recv? v)))

;; Unfold session mu-types before matching.
(define (io-unfold-session v)
  (if (sess-mu? v) (unfold-session v) v))

;; --- IO bridge cell creation ---

;; Create a fresh IO state cell in a prop-network.
;; (make-io-bridge-cell net) → (values net* cell-id)
(define (make-io-bridge-cell net)
  (net-new-cell net io-bot io-state-merge io-state-contradicts?))

;; --- File open ---

;; Perform the actual file open side effect.
;; Reads io-cell; if io-opening, opens the file and writes io-open.
;; On exn:fail:filesystem, writes io-top to io-cell (contradiction).
;; (io-bridge-open-file net io-cell) → net*
(define (io-bridge-open-file net io-cell)
  (define state (net-cell-read net io-cell))
  (cond
    [(io-opening? state)
     (define path (io-opening-path state))
     (define mode (io-opening-mode state))
     (with-handlers ([exn:fail:filesystem?
                      (lambda (e)
                        (net-cell-write net io-cell io-top))])
       (define port
         (case mode
           [(read)   (open-input-file path)]
           [(write)  (open-output-file path #:exists 'truncate/replace)]
           [(append) (open-output-file path #:exists 'append)]
           [else (error 'io-bridge-open-file "unknown mode: ~a" mode)]))
       (net-cell-write net io-cell (io-open port mode)))]
    [else net]))

;; --- Error conversion ---

;; Convert a Racket exception to a Prologos error value.
;; Phase 0: returns an expr-string with the error message.
;; Phase IO-C+ will produce proper IOError ADT constructors.
(define (make-io-error-from-exn e)
  (expr-string (exn-message e)))

;; Wrap an error as a value suitable for msg-in-cell.
(define (make-io-error-result e)
  (expr-string (format "IO error: ~a" (exn-message e))))

;; --- IO bridge propagator ---

;; Create a side-effecting fire-fn closure for the IO bridge.
;; Watches: io-cell, session-cell, msg-out-cell
;; Writes to: msg-in-cell, io-cell
;;
;; Conditions:
;;   io-open + sess-send + msg-out available → write to file
;;   io-open + sess-recv                    → read from file, deliver to msg-in
;;   io-open + sess-end                     → close port, set io-closed
;;   else                                   → noop (return net unchanged)
;;
;; (make-io-bridge-propagator io-cell session-cell msg-in-cell msg-out-cell)
;; → (prop-network → prop-network)
(define (make-io-bridge-propagator io-cell session-cell msg-in-cell msg-out-cell)
  (lambda (net)
    (define io-state (net-cell-read net io-cell))
    (define raw-sess (net-cell-read net session-cell))
    (define sess (io-unfold-session raw-sess))
    (define msg-out (net-cell-read net msg-out-cell))
    (cond
      ;; File is open + session expects send + message is available
      ;; → Client is sending data; bridge writes to file
      [(and (io-open? io-state)
            (io-sess-send? sess)
            (not (io-msg-bot? msg-out)))
       (with-handlers ([exn:fail?
                        (lambda (e)
                          (net-cell-write net msg-in-cell
                            (make-io-error-result e)))])
         (define port (io-open-port io-state))
         (define str-val (if (expr-string? msg-out)
                             (expr-string-val msg-out)
                             (format "~a" msg-out)))
         (write-string str-val port)
         (flush-output port)
         net)]

      ;; File is open + session expects recv
      ;; → Client is reading; bridge reads from file, delivers to msg-in
      [(and (io-open? io-state)
            (io-sess-recv? sess))
       (with-handlers ([exn:fail?
                        (lambda (e)
                          (net-cell-write net msg-in-cell
                            (make-io-error-result e)))])
         (define port (io-open-port io-state))
         (define data (read-string 1048576 port))  ;; 1MB max
         (define result
           (if (eof-object? data)
               (expr-string "")
               (expr-string data)))
         (net-cell-write net msg-in-cell result))]

      ;; Session ended → close the file
      [(and (io-open? io-state)
            (sess-end? sess))
       (with-handlers ([exn:fail?
                        (lambda (e) net)])
         (define port (io-open-port io-state))
         (if (input-port? port)
             (close-input-port port)
             (close-output-port port))
         (net-cell-write net io-cell io-closed))]

      [else net])))

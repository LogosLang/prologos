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
         "session-runtime.rkt"
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
 io-state-contradicts?)

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

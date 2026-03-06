#lang racket/base

;;;
;;; EFFECT BRIDGE — Session-Effect Bridge Propagator (AD-B)
;;;
;;; Implements the alpha direction of the Galois connection:
;;;   alpha : Session → EffectPosition
;;;
;;; The bridge propagator watches a session cell and writes the corresponding
;;; effect position to an effect position cell. When the session cell advances
;;; (e.g., !String.?Int.end → ?Int.end), the bridge computes the new depth
;;; and writes the eff-pos to the effect cell.
;;;
;;; This is unidirectional (alpha only) — we don't need gamma at runtime
;;; because effect positions are derived from session advancement, not the
;;; other way around.
;;;
;;; Pattern: follows net-add-cross-domain-propagator from propagator.rkt
;;; but is unidirectional.
;;;
;;; See: docs/tracking/2026-03-07_ARCHITECTURE_AD_IMPLEMENTATION_DESIGN.org §5
;;;

(require "propagator.rkt"
         "sessions.rkt"
         "session-lattice.rkt"
         "effect-position.rkt")

(provide
 ;; AD-B1: Single-channel bridge
 add-session-effect-bridge
 ;; AD-B2: Multi-channel bridge
 add-multi-channel-bridges)


;; ========================================
;; AD-B1: Single-Channel Bridge
;; ========================================

;; Install a bridge propagator that maps session advancement to effect positions.
;;
;; When the session cell advances (e.g., !String.?Int.end → ?Int.end),
;; the bridge computes the new depth and writes it to the effect position cell.
;;
;; net          : prop-network
;; sess-cell    : cell-id (session lattice cell)
;; effect-cell  : cell-id (effect position lattice cell)
;; channel      : symbol (channel identifier)
;; full-session : session type (the complete session, for depth computation)
;; Returns: (values net* prop-id)
(define (add-session-effect-bridge net sess-cell effect-cell channel full-session)
  (define fire-fn
    (lambda (net)
      (define sess-val (net-cell-read net sess-cell))
      (cond
        ;; No information yet — return network unchanged
        [(sess-bot? sess-val) net]
        ;; Session contradiction propagates to effect position
        [(sess-top? sess-val)
         (net-cell-write net effect-cell eff-top)]
        [else
         (define depth (session-steps-to full-session sess-val))
         (if depth
             ;; Valid session suffix — write computed position
             (net-cell-write net effect-cell (eff-pos channel depth))
             ;; Not a suffix of full-session — this shouldn't happen in
             ;; well-typed programs, but treat as contradiction
             (net-cell-write net effect-cell eff-top))])))
  (net-add-propagator net (list sess-cell) (list effect-cell) fire-fn))


;; ========================================
;; AD-B2: Multi-Channel Bridge
;; ========================================

;; Install bridges for all channels in a multi-channel process.
;;
;; channel-sessions: list of (list channel-symbol sess-cell-id full-session-type)
;;   Each entry describes one channel: its name, the propagator cell tracking
;;   its session state, and the full session type for depth computation.
;;
;; Returns: (values net* pos-cells)
;;   net*:      updated prop-network
;;   pos-cells: hasheq channel-symbol → effect-position-cell-id
(define (add-multi-channel-bridges net channel-sessions)
  (for/fold ([net* net]
             [pos-cells (hasheq)])
            ([cs (in-list channel-sessions)])
    (define chan (car cs))
    (define sess-cell (cadr cs))
    (define full-sess (caddr cs))
    ;; Create a fresh effect position cell for this channel
    (define-values (net** effect-cell) (net-new-cell net* eff-bot eff-pos-merge))
    ;; Install the bridge propagator
    (define-values (net*** _pid) (add-session-effect-bridge net** sess-cell effect-cell chan full-sess))
    (values net*** (hash-set pos-cells chan effect-cell))))

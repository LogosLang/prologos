#lang racket/base

;;;
;;; cell-ops.rkt — Worldview-Aware Cell Operations
;;;
;;; Track 8 Phase B1: The architectural centerpiece.
;;;
;;; All reads filter by the current ATMS worldview (speculation stack).
;;; Tagged entries from sibling speculation branches are invisible.
;;; This makes speculation cleanup structural (correct-by-construction)
;;; rather than timing-dependent (imperative restore).
;;;
;;; The speculation stack IS the worldview:
;;; - Untagged entries (depth-0): always visible
;;; - Tagged with assumption on current stack: visible (own branch or parent)
;;; - Tagged with assumption NOT on current stack: invisible (sibling branch)
;;;
;;; This is the same mechanism TMS cells use for type values, extended
;;; to all structural state (meta-info, id-map, mult, level, session).
;;;

(require "propagator.rkt"
         "infra-cell.rkt"
         "champ.rkt")

(provide
 ;; Worldview-aware CHAMP reads
 worldview-visible?
 champ-lookup-worldview
 ;; Re-export for consumers
 tagged-entry
 tagged-entry?
 tagged-entry-value
 tagged-entry-assumption-id)

;; ========================================
;; Worldview-Aware Reads
;; ========================================

;; Check if a tagged-entry is visible under the current speculation stack.
;; The speculation stack (current-speculation-stack from propagator.rkt)
;; IS the ATMS worldview. Entries tagged with assumptions on the stack
;; are visible; entries tagged with assumptions NOT on the stack are invisible.
;;
;; Depth 0 (no speculation): all untagged entries visible. Tagged entries
;; with #f assumption-id are also visible (created at depth-0).
;;
;; Under speculation: the stack is (list innermost-aid ... outermost-aid).
;; An entry tagged with any aid on the stack is visible (own branch or parent).
;; An entry tagged with an aid NOT on the stack is from a sibling branch — invisible.
(define (worldview-visible? entry)
  (cond
    [(not (tagged-entry? entry)) #t]  ;; untagged = always visible
    [else
     (define aid (tagged-entry-assumption-id entry))
     (cond
       [(not aid) #t]  ;; #f assumption = depth-0 = always visible
       [else
        ;; Check if this assumption is on the current speculation stack.
        ;; O(depth) where depth is speculation nesting — rarely > 3.
        (and (pair? (current-speculation-stack))
             (memq aid (current-speculation-stack))
             #t)])]))

;; Look up a key in a CHAMP with worldview filtering.
;; Returns the unwrapped value if visible, or #f if absent or invisible.
(define (champ-lookup-worldview champ hash key)
  (define raw (champ-lookup champ hash key))
  (cond
    [(eq? raw 'none) #f]
    [(not (tagged-entry? raw)) raw]
    [(worldview-visible? raw) (tagged-entry-value raw)]
    [else #f]))  ;; tagged entry from invisible branch

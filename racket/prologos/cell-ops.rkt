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
         "champ.rkt"
         "elab-network-types.rkt")  ;; Track 8 B2: no cycle (types module has no transitive deps)

(provide
 ;; Worldview-aware CHAMP reads
 worldview-visible?
 champ-lookup-worldview
 ;; Re-export for consumers
 tagged-entry
 tagged-entry?
 tagged-entry-value
 tagged-entry-assumption-id
 ;; Track 8 B2: Re-export elab-network types + operations
 (struct-out elab-network)
 (struct-out elab-cell-info)
 (struct-out contradiction-info)
 elab-network-id-map-set
 elab-network-meta-info-set
 make-elaboration-network
 reset-elab-network-command-state
 ;; Worldview-aware elab-network operations
 elab-cell-read-worldview
 elab-meta-info-read-worldview
 elab-id-map-read-worldview)

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

;; ========================================
;; Worldview-Aware Elab-Network Operations
;; ========================================
;; Track 8 B2: These replace the callback-based reads in metavar-store.rkt.
;; Each reads from the elab-network struct field and applies worldview filtering.

;; Read a cell value from an elab-network. TMS-transparent (uses net-cell-read
;; which already applies TMS worldview via current-speculation-stack).
(define (elab-cell-read-worldview enet cid)
  (net-cell-read (elab-network-prop-net enet) cid))

;; Read meta-info for a meta-id from the elab-network, with worldview filtering.
;; Returns the meta-info struct if visible, or #f.
(define (elab-meta-info-read-worldview enet meta-id)
  (define mi-champ (elab-network-meta-info enet))
  (champ-lookup-worldview mi-champ (meta-id-hash meta-id) meta-id))

;; Read cell-id for a meta-id from the elab-network's id-map, with worldview filtering.
;; Returns the cell-id if visible, or #f.
(define (elab-id-map-read-worldview enet meta-id)
  (define id-champ (elab-network-id-map enet))
  (champ-lookup-worldview id-champ (meta-id-hash meta-id) meta-id))

;; Hash helper for meta-id CHAMP lookups.
;; Meta-ids are gensyms; hashed via eq-hash-code (same as metavar-store.rkt).
;; Defined locally to avoid importing metavar-store.rkt (cycle).
(define (meta-id-hash id)
  (eq-hash-code id))

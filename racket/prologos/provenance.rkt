#lang racket/base

;;;
;;; provenance.rkt — Provenance Tracking and Answer Records
;;;
;;; When `explain` is used, each result is an Answer — a record bundling
;;; bindings (the what) with provenance (the why). This module provides
;;; the data structures and utilities for provenance tracking.
;;;
;;; Key concepts:
;;;   - answer-record: bindings + optional derivation + depth + support
;;;   - derivation-tree: recursive proof tree (goal → rule → children)
;;;   - Provenance levels: none, summary, full, atms
;;;   - Level determines which fields are populated
;;;
;;; Design reference: docs/tracking/2026-02-24_LOGIC_ENGINE_DESIGN.org §7.6.3
;;;

(provide
 ;; Core structs (legacy — used by existing callers)
 (struct-out answer-record)
 (struct-out derivation-tree)
 ;; D4 structured answer (new)
 (struct-out answer-result)
 (struct-out provenance-data)
 ;; Construction
 make-answer
 make-derivation
 make-answer-result
 make-provenance-data
 ;; Utilities
 derivation-depth
 answer-bindings-map)

;; ========================================
;; Core structs
;; ========================================

;; An answer record: bindings + provenance bundled together.
;; bindings:   hasheq — keyword → value (the substitution)
;; derivation: #f or derivation-tree (present at :full and :atms)
;; clause-id:  #f or symbol (which clause produced this answer)
;; depth:      nat (derivation depth — 0 for facts)
;; support:    #f or (listof symbol) (ATMS support set — :atms only)
(struct answer-record (bindings derivation clause-id depth support)
  #:transparent)

;; A derivation tree: recursive proof structure.
;; goal:     symbol — relation name
;; args:     (listof any) — instantiated arguments
;; rule:     symbol — clause identifier
;; children: (listof derivation-tree) — sub-derivations
(struct derivation-tree (goal args rule children)
  #:transparent)

;; ========================================
;; D4 Structured Answer (new — replaces answer-record for explain path)
;; ========================================

;; The structured answer returned from explain/explain-with.
;; Separates semantic metadata (certainty, cycle) from observability (provenance).
;;
;; bindings:    hasheq — keyword → value (the what)
;; certainty:   #f (stratified) or 'definite/'unknown (WF semantics)
;; cycle:       #f or (listof symbol) — predicates in negative cycle (WF unknown only)
;; provenance:  #f or provenance-data — gated by solver :provenance level
(struct answer-result (bindings certainty cycle provenance)
  #:transparent)

;; Nested provenance data (present when provenance level ≥ :summary).
;;
;; clause-id:   symbol — which clause/fact produced this (name/arity-index format)
;; depth:       nat — derivation depth (0 for top-level facts)
;; derivation:  #f or derivation-tree — full proof tree (present at :full and :atms)
;; support:     #f or (listof symbol) — ATMS assumption set (:atms only)
(struct provenance-data (clause-id depth derivation support)
  #:transparent)

;; ========================================
;; Construction
;; ========================================

;; Create an answer record.
;; All optional fields default to #f/0.
(define (make-answer #:bindings bindings
                     #:derivation [derivation #f]
                     #:clause-id [clause-id #f]
                     #:depth [depth 0]
                     #:support [support #f])
  (answer-record bindings derivation clause-id depth support))

;; Create a derivation tree node.
(define (make-derivation goal args rule children)
  (derivation-tree goal args rule children))

;; Create an answer-result (D4 structured answer).
;; All optional fields default to #f.
(define (make-answer-result #:bindings bindings
                            #:certainty [certainty #f]
                            #:cycle [cycle #f]
                            #:provenance [provenance #f])
  (answer-result bindings certainty cycle provenance))

;; Create a provenance-data record.
;; Only clause-id and depth are required; derivation and support are optional.
(define (make-provenance-data #:clause-id clause-id
                              #:depth depth
                              #:derivation [derivation #f]
                              #:support [support #f])
  (provenance-data clause-id depth derivation support))

;; ========================================
;; Utilities
;; ========================================

;; Compute the depth of a derivation tree.
;; A leaf (no children) has depth 0.
(define (derivation-depth tree)
  (if (or (not tree) (null? (derivation-tree-children tree)))
      0
      (+ 1 (apply max (map derivation-depth
                            (derivation-tree-children tree))))))

;; Extract the bindings from an answer record as a Racket hash.
(define (answer-bindings-map answer)
  (answer-record-bindings answer))

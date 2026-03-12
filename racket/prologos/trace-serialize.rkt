#lang racket/base

;;;
;;; trace-serialize.rkt — JSON Serialization for Propagator Traces
;;;
;;; Thin adapter over Phase 0 data types (bsp-round, cell-diff, prop-trace).
;;; Converts Racket structs to hasheq trees suitable for jsexpr->string.
;;;
;;; Design reference: docs/tracking/2026-03-12_PROPAGATOR_VISUALIZATION_DESIGN.md §Phase 2
;;;

(require json
         "champ.rkt"
         "propagator.rkt"
         "pretty-print.rkt"
         "type-lattice.rkt")

(provide
 ;; Core serialization
 serialize-cell-diff
 serialize-atms-event
 serialize-bsp-round
 serialize-prop-trace
 ;; Network topology
 serialize-network-topology
 ;; Lattice value display
 serialize-lattice-value
 ;; Full snapshot → JSON string
 trace->json-string)

;; ========================================
;; Lattice Value Serialization
;; ========================================

;; Convert a cell value to a display string.
;; Cell values are arbitrary Racket values — types, multiplicities, registries.
(define (serialize-lattice-value v)
  (cond
    [(eq? v type-bot) "⊥"]
    [(eq? v type-top) "⊤"]
    [(eq? v 'bot) "⊥"]  ;; raw bot symbol used in some cells
    [(hash? v)
     (format "hash(~a entries)" (hash-count v))]
    [(pair? v)
     ;; Could be an AST expression — try pp-expr, fall back to format
     (with-handlers ([exn:fail? (lambda (_) (format "~v" v))])
       (pp-expr v))]
    [(symbol? v) (symbol->string v)]
    [(number? v) (number->string v)]
    [(string? v) v]
    [(boolean? v) (if v "true" "false")]
    [else
     ;; Catch-all for unknown value types (structs, etc.)
     (with-handlers ([exn:fail? (lambda (_) (format "~v" v))])
       (pp-expr v))]))

;; ========================================
;; Cell Diff Serialization
;; ========================================

(define (serialize-cell-diff cd)
  (hasheq 'cellId (cell-id-n (cell-diff-cell-id cd))
          'oldValue (serialize-lattice-value (cell-diff-old-value cd))
          'newValue (serialize-lattice-value (cell-diff-new-value cd))
          'sourcePropagator (prop-id-n (cell-diff-source-propagator cd))))

;; ========================================
;; ATMS Event Serialization
;; ========================================

(define (serialize-atms-event evt)
  (cond
    [(atms-event:assume? evt)
     (hasheq 'type "assume"
             'cellId (cell-id-n (atms-event:assume-cell-id evt))
             'label (format "~a" (atms-event:assume-assumption-label evt)))]
    [(atms-event:retract? evt)
     (hasheq 'type "retract"
             'cellId (cell-id-n (atms-event:retract-cell-id evt))
             'label (format "~a" (atms-event:retract-assumption-label evt))
             'reason (format "~a" (atms-event:retract-reason evt)))]
    [(atms-event:nogood? evt)
     (hasheq 'type "nogood"
             'nogoodSet (map (lambda (x) (format "~a" x))
                             (atms-event:nogood-nogood-set evt))
             'explanation (map (lambda (x) (format "~a" x))
                               (atms-event:nogood-explanation evt)))]
    [else (hasheq 'type "unknown")]))

;; ========================================
;; BSP Round Serialization
;; ========================================

(define (serialize-bsp-round r)
  (hasheq 'roundNumber (bsp-round-round-number r)
          'cellDiffs (map serialize-cell-diff (bsp-round-cell-diffs r))
          'propagatorsFired (map prop-id-n (bsp-round-propagators-fired r))
          'contradiction (let ([c (bsp-round-contradiction r)])
                           (if c (cell-id-n c) (json-null)))
          'atmsEvents (map serialize-atms-event (bsp-round-atms-events r))))

;; ========================================
;; Network Topology Serialization
;; ========================================

;; Serialize the topology of a prop-network (cells, propagators, edges).
;; Does NOT include cell values — use serialize-bsp-round for per-round diffs.
(define (serialize-network-topology net)
  (define cells-champ (prop-network-cells net))
  (define props-champ (prop-network-propagators net))
  ;; Collect all cell IDs
  (define cell-ids (champ-keys cells-champ))
  ;; Collect all propagator IDs and their connections
  (define prop-ids (champ-keys props-champ))
  ;; Serialize cells: id + current value
  (define cells-json
    (map (lambda (cid)
           (define cell (champ-lookup cells-champ (cell-id-hash cid) cid))
           (hasheq 'id (cell-id-n cid)
                   'value (serialize-lattice-value (prop-cell-value cell))))
         cell-ids))
  ;; Serialize propagators: id + input/output cell IDs
  (define props-json
    (map (lambda (pid)
           (define prop (champ-lookup props-champ (prop-id-hash pid) pid))
           (hasheq 'id (prop-id-n pid)
                   'inputs (map cell-id-n (propagator-inputs prop))
                   'outputs (map cell-id-n (propagator-outputs prop))))
         prop-ids))
  ;; Stats
  (define contradiction (prop-network-contradiction net))
  (hasheq 'cells cells-json
          'propagators props-json
          'stats (hasheq 'totalCells (length cell-ids)
                         'totalPropagators (length prop-ids)
                         'contradiction (if contradiction
                                            (cell-id-n contradiction)
                                            (json-null)))))

;; ========================================
;; Prop Trace Serialization
;; ========================================

(define (serialize-prop-trace tr)
  (hasheq 'initialNetwork (serialize-network-topology (prop-trace-initial-network tr))
          'rounds (map serialize-bsp-round (prop-trace-rounds tr))
          'finalNetwork (serialize-network-topology (prop-trace-final-network tr))
          'metadata (serialize-metadata (prop-trace-metadata tr))))

(define (serialize-metadata meta)
  (for/hasheq ([(k v) (in-hash meta)])
    (values k (cond [(string? v) v]
                    [(number? v) v]
                    [(symbol? v) (symbol->string v)]
                    [else (format "~a" v)]))))

;; ========================================
;; Convenience: Full trace → JSON string
;; ========================================

(define (trace->json-string tr)
  (jsexpr->string (serialize-prop-trace tr)))

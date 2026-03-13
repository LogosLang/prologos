#lang racket/base

;;;
;;; observatory-serialize.rkt — JSON Serialization for Propagator Observatory
;;;
;;; Converts observatory structs to hasheq trees suitable for jsexpr->string.
;;; Reuses serialize-network-topology and serialize-prop-trace from trace-serialize.rkt.
;;;
;;; Design reference: docs/tracking/2026-03-12_PROPAGATOR_OBSERVATORY.md §6
;;;

(require json
         "champ.rkt"
         "prop-observatory.rkt"
         "propagator.rkt"
         "trace-serialize.rkt")

(provide
 ;; Core serialization
 serialize-cell-meta
 serialize-net-capture
 serialize-cross-net-link
 serialize-observatory
 ;; Convenience
 observatory->json-string)

;; ========================================
;; Cell-Meta Serialization
;; ========================================

(define (serialize-cell-meta cm)
  (hasheq 'subsystem (symbol->string (cell-meta-subsystem cm))
          'label (cell-meta-label cm)
          'sourceLoc (let ([loc (cell-meta-source-loc cm)])
                       (if loc
                           (hasheq 'line (srcloc-line loc)
                                   'col (srcloc-column loc)
                                   'file (let ([src (srcloc-source loc)])
                                           (if (string? src) src
                                               (if src (format "~a" src) (json-null)))))
                           (json-null)))
          'domain (symbol->string (cell-meta-domain cm))
          'extra (serialize-extra (cell-meta-extra cm))))

(define (serialize-extra h)
  (for/hasheq ([(k v) (in-hash h)])
    (values k (cond [(string? v) v]
                    [(number? v) v]
                    [(symbol? v) (symbol->string v)]
                    [(boolean? v) v]
                    [else (format "~a" v)]))))

;; ========================================
;; Source Location Helpers
;; ========================================

;; srcloc struct accessors — Racket's srcloc has:
;;   source, line, column, position, span
(define (srcloc-line loc) (vector-ref loc 1))
(define (srcloc-column loc) (vector-ref loc 2))
(define (srcloc-source loc) (vector-ref loc 0))

;; ========================================
;; Net-Capture Serialization
;; ========================================

;; Serialize a net-capture to a JSON-ready hasheq.
;; Uses serialize-network-topology from trace-serialize.rkt for the network portion.
;; Cell metadata from cell-metas champ is merged into cell JSON objects.
(define (serialize-net-capture cap)
  ;; Serialize network topology (cells + propagators)
  (define net-json (serialize-network-topology (net-capture-network cap)))
  ;; Enrich cells with cell-meta information
  (define enriched-cells
    (map (lambda (cell-json)
           (define cid-n (hash-ref cell-json 'id))
           (define cid (cell-id cid-n))
           (define meta (champ-lookup (net-capture-cell-metas cap)
                                     (cell-id-hash cid) cid))
           (if (eq? meta 'none)
               cell-json
               (hash-set*
                cell-json
                'label (cell-meta-label meta)
                'cellSubsystem (symbol->string (cell-meta-subsystem meta))
                'domain (symbol->string (cell-meta-domain meta))
                'cellSourceLoc
                (let ([loc (cell-meta-source-loc meta)])
                  (if loc
                      (hasheq 'line (srcloc-line loc)
                              'col (srcloc-column loc))
                      (json-null))))))
         (hash-ref net-json 'cells)))
  ;; Build capture JSON
  (define network-json
    (hash-set net-json 'cells enriched-cells))
  (hasheq 'id (symbol->string (net-capture-id cap))
          'subsystem (symbol->string (net-capture-subsystem cap))
          'label (net-capture-label cap)
          'status (symbol->string (net-capture-status cap))
          'statusDetail (or (net-capture-status-detail cap) (json-null))
          'parentId (let ([pid (net-capture-parent-id cap)])
                      (if pid (symbol->string pid) (json-null)))
          'sequenceNumber (net-capture-sequence-number cap)
          'timestampMs (net-capture-timestamp-ms cap)
          'network network-json
          'trace (let ([tr (net-capture-trace cap)])
                   (if tr (serialize-prop-trace tr) (json-null)))))

;; hash-set* : set multiple keys on a hasheq
(define (hash-set* h . kvs)
  (let loop ([h h] [kvs kvs])
    (if (null? kvs) h
        (loop (hash-set h (car kvs) (cadr kvs))
              (cddr kvs)))))

;; ========================================
;; Cross-Net-Link Serialization
;; ========================================

(define (serialize-cross-net-link link)
  (hasheq 'fromCapture (symbol->string (cross-net-link-from-capture-id link))
          'fromCell (cell-id-n (cross-net-link-from-cell-id link))
          'toCapture (symbol->string (cross-net-link-to-capture-id link))
          'toCell (cell-id-n (cross-net-link-to-cell-id link))
          'relation (symbol->string (cross-net-link-relation link))))

;; ========================================
;; Observatory Serialization
;; ========================================

(define (serialize-observatory obs)
  (define captures (observatory-captures obs))
  (define links (observatory-links obs))
  (define meta (observatory-metadata obs))
  ;; Collect subsystem names
  (define subsystems
    (remove-duplicates
     (map (lambda (cap) (symbol->string (net-capture-subsystem cap)))
          captures)))
  (hasheq 'version 2
          'observatory
          (hasheq 'captures (map serialize-net-capture captures)
                  'links (map serialize-cross-net-link links)
                  'metadata
                  (hash-set*
                   (serialize-extra meta)
                   'totalCaptures (length captures)
                   'subsystems subsystems))))

;; ========================================
;; Convenience: Observatory → JSON string
;; ========================================

(define (observatory->json-string obs)
  (jsexpr->string (serialize-observatory obs)))

;; ========================================
;; Internal helpers
;; ========================================

(define (remove-duplicates lst)
  (let loop ([lst lst] [seen '()] [result '()])
    (cond
      [(null? lst) (reverse result)]
      [(member (car lst) seen) (loop (cdr lst) seen result)]
      [else (loop (cdr lst) (cons (car lst) seen) (cons (car lst) result))])))

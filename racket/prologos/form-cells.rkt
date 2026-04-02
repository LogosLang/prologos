#lang racket/base

;;;
;;; PPN Track 3 Phase 6: Per-Form Cells
;;;
;;; Each top-level source form gets ONE cell on the elaboration network.
;;; The cell value is a form-pipeline-value (Pocket Universe from Phase 5).
;;;
;;; The merge function is set-union on transforms (Boolean lattice).
;;; Production dispatch reads the form cell, runs the pipeline,
;;; and writes the completed result back.
;;;
;;; This module provides the cell infrastructure. It augments the
;;; existing pipeline (Phase 7 will replace the merge with cell reads).
;;;

(require racket/set
         "elaborator-network.rkt"
         "elab-network-types.rkt"
         "parse-reader.rkt"
         "surface-rewrite.rkt"
         "tree-parser.rkt"
         "infra-cell.rkt"
         "source-location.rkt")

(provide
 ;; Cell creation
 create-form-cells-from-tree
 ;; Cell access
 form-cell-ref
 ;; Production dispatch
 dispatch-form-productions
 ;; Merge function (exposed for testing / validation)
 form-cell-merge-fn)

;; ========================================
;; Form cell merge function
;; ========================================

;; form-cell-merge-fn: installed on each per-form cell.
;; This IS form-pipeline-merge from surface-rewrite.rkt (Phase 5).
;; Both pipelines can write to the same cell; the merge resolves.
(define (form-cell-merge-fn old new)
  (form-pipeline-merge old new))

;; ========================================
;; Cell creation: one cell per top-level form
;; ========================================

;; Given a parse-tree (from read-to-tree) and the current elab-network,
;; creates one cell per top-level form node.
;; Each cell starts with (seteq) transforms and the raw tree-node.
;;
;; Returns: (values updated-enet (hasheq source-line -> cell-id))
(define (create-form-cells-from-tree pt enet)
  (define top-forms (tree-top-level-forms pt))

  (let loop ([remaining top-forms]
             [current-enet enet]
             [cell-map (hasheq)])
    (if (null? remaining)
        (values current-enet cell-map)
        (let* ([node (car remaining)]
               [loc (and (parse-tree-node? node)
                         (parse-tree-node-srcloc node))]
               ;; parse-tree-node srcloc is (line col start-pos end-pos) — first element is line
               [line (cond
                       [(srcloc? loc) (srcloc-line loc)]
                       [(and (list? loc) (pair? loc) (number? (car loc))) (car loc)]
                       [else #f])]
               [pv (form-pipeline-value
                    (seteq) node '() loc)])
          (define-values (new-enet cell-id)
            (elab-new-infra-cell current-enet pv form-cell-merge-fn))
          (loop (cdr remaining)
                new-enet
                (if line
                    (hash-set cell-map line cell-id)
                    cell-map))))))

;; ========================================
;; Cell access
;; ========================================

;; Read a form cell's value from the elab-network
(define (form-cell-ref enet cell-id)
  (elab-cell-read enet cell-id))

;; ========================================
;; Production dispatch
;; ========================================

;; Run the full tree pipeline on each form cell:
;; read tree-node → run-form-pipeline → write completed result
;;
;; This is the production dispatch: for each form, the pipeline
;; (G(0) grouping → T(0) tagging → rewrites → parse) produces
;; the final form-pipeline-value with 'done in transforms.
;;
;; Returns: updated elab-network with all form cells at 'done
(define (dispatch-form-productions enet cell-map)
  (for/fold ([current-enet enet])
            ([(line cell-id) (in-hash cell-map)])
    (define pv (elab-cell-read current-enet cell-id))
    (define node (form-pipeline-value-tree-node pv))
    (if (not node)
        current-enet
        ;; Run the full pipeline on this form's tree node
        (let ([result (run-form-pipeline node)])
          ;; Write the completed pipeline value to the cell
          (elab-cell-write current-enet cell-id result)))))

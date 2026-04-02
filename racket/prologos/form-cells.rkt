#lang racket/base

;;;
;;; PPN Track 3 Phase 6+3a: Per-Form Cells + Spec Cells
;;;
;;; Phase 6: Each top-level source form gets ONE cell on the elaboration network.
;;; The cell value is a form-pipeline-value (Pocket Universe from Phase 5).
;;; The merge function is set-union on transforms (Boolean lattice).
;;;
;;; Phase 3a: Per-function spec cells. When a spec form is processed,
;;; the spec entry is written to a spec cell keyed by function name.
;;; Defn forms can read the spec cell to get their type annotation.
;;; Ordering emerges from cell dependency — no two-pass ordering.
;;;

(require racket/set
         "elaborator-network.rkt"
         "elab-network-types.rkt"
         "parse-reader.rkt"
         "surface-rewrite.rkt"
         "tree-parser.rkt"
         "infra-cell.rkt"
         "source-location.rkt"
         "rrb.rkt")

(provide
 ;; Phase 6: Cell creation
 create-form-cells-from-tree
 ;; Phase 6: Cell access
 form-cell-ref
 ;; Phase 6: Production dispatch
 dispatch-form-productions
 ;; Phase 7: Extract surfs from completed form cells
 extract-surfs-from-form-cells
 ;; Phase 6: Merge function (exposed for testing / validation)
 form-cell-merge-fn
 ;; Phase 3a: Spec cells
 (struct-out spec-cell-value)
 spec-cell-merge-fn
 create-spec-cell
 write-spec-cell
 read-spec-cell
 extract-specs-from-form-cells)

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

;; ========================================
;; Phase 7: Extract surfs from form cells
;; ========================================

;; After dispatch-form-productions completes, each form cell holds a
;; completed form-pipeline-value with a rewritten tree-node.
;; This function runs parse-form-tree on each completed tree-node
;; to produce surf-* structs — the same output as the merge pipeline.
;;
;; Returns: list of surf-* structs (in source-line order), suitable
;; for passing to process-surfs.
(define (extract-surfs-from-form-cells enet cell-map)
  (define pairs
    (for/list ([(line cell-id) (in-hash cell-map)])
      (define pv (elab-cell-read enet cell-id))
      (define node (form-pipeline-value-tree-node pv))
      (define surf (if node (parse-form-tree node) #f))
      (cons line surf)))
  ;; Sort by source line to preserve form ordering
  (define sorted (sort pairs < #:key car))
  (map cdr sorted))

;; ========================================
;; Phase 3a: Spec Cells
;; ========================================
;;
;; Per-function spec cells: when a spec form is processed, the spec
;; entry (type signature + metadata) is written to a cell keyed by
;; function name. Defn forms read spec cells to get type annotations.
;;
;; This replaces the two-pass ordering in preparse-expand-all:
;; - OLD: Pass 1 scans all specs → Pass 2 injects into defns
;; - NEW: Spec cell written by spec production → defn reads cell
;;        If spec not yet written, defn proceeds without annotation.
;;        When spec cell is written later, re-fire annotates the defn.
;;
;; For Phase 3a, spec cells are CREATED and POPULATED from tree-parser
;; output. The consumption (defn reading spec cells) is Phase 7 scope.

;; Spec cell value: holds the parsed spec information for one function.
;; D.5 fix (F4): collision = top (error), not first-write-wins.
(struct spec-cell-value
  (name         ;; symbol — function name
   type-surf    ;; surf-* — parsed type expression (or #f if bot)
   metadata     ;; hash or #f — spec metadata (:mixfix, :doc, etc.)
   top?)        ;; boolean — #t if collision detected (two specs for same name)
  #:transparent)

;; Bot value for spec cells
(define spec-cell-bot (spec-cell-value #f #f #f #f))

;; Merge function for spec cells:
;; - bot ⊔ x = x
;; - x ⊔ bot = x
;; - x ⊔ x = x (idempotent)
;; - x ⊔ y = top when x ≠ y (collision = error, D.5 F4)
(define (spec-cell-merge-fn old new)
  (cond
    ;; bot cases
    [(not (spec-cell-value-type-surf old)) new]
    [(not (spec-cell-value-type-surf new)) old]
    ;; Already top → stays top
    [(spec-cell-value-top? old) old]
    [(spec-cell-value-top? new) new]
    ;; Same name + same type → idempotent
    [(and (eq? (spec-cell-value-name old) (spec-cell-value-name new))
          (equal? (spec-cell-value-type-surf old) (spec-cell-value-type-surf new)))
     old]
    ;; Collision: two different specs for the same function → top (error)
    [else (spec-cell-value (spec-cell-value-name old)
                           (spec-cell-value-type-surf old)
                           (spec-cell-value-metadata old)
                           #t)]))

;; Create a spec cell for a function name.
;; Returns: (values updated-enet cell-id)
(define (create-spec-cell enet)
  (elab-new-infra-cell enet spec-cell-bot spec-cell-merge-fn))

;; Write a spec entry to a spec cell.
;; Returns: updated enet
(define (write-spec-cell enet cell-id name type-surf metadata)
  (elab-cell-write enet cell-id
                   (spec-cell-value name type-surf metadata #f)))

;; Read a spec cell's value.
(define (read-spec-cell enet cell-id)
  (elab-cell-read enet cell-id))

;; Extract spec entries from completed form cells.
;; Scans all form cells for spec forms, creates spec cells, and populates them.
;; Returns: (values updated-enet (hasheq function-name -> spec-cell-id))
(define (extract-specs-from-form-cells enet cell-map)
  (for/fold ([current-enet enet]
             [spec-map (hasheq)]
             #:result (values current-enet spec-map))
            ([(line cell-id) (in-hash cell-map)])
    (define pv (elab-cell-read current-enet cell-id))
    (define node (form-pipeline-value-tree-node pv))
    ;; Check if this form is a spec (tag = 'spec after pipeline)
    (if (and node (parse-tree-node? node)
             (eq? (parse-tree-node-tag node) 'spec))
        ;; Extract function name from the spec tree node.
        ;; Spec form's children: [keyword-token, name-token, type-tokens...]
        ;; First token after the "spec" keyword is the function name.
        (let* ([children (rrb-to-list (parse-tree-node-children node))]
               [args (if (and (pair? children) (token-entry? (car children)))
                         (cdr children)  ;; skip keyword token
                         children)]
               [name-token (and (pair? args) (car args))]
               [name (and (token-entry? name-token)
                          (string->symbol (token-entry-lexeme name-token)))])
          (if name
              (let-values ([(enet* scid) (create-spec-cell current-enet)])
                (define enet** (write-spec-cell enet* scid name #f #f))
                (values enet** (hash-set spec-map name scid)))
              (values current-enet spec-map)))
        (values current-enet spec-map))))

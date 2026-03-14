#lang racket/base

;;;
;;; tabling.rkt — SLG-Style Memoization (Table Store)
;;;
;;; A persistent table store for tabled predicates. Tables are indices into
;;; PropNetwork cells: the actual answer data lives in cells with list-based
;;; set-merge. The table-store maps predicate names to table-entries, each
;;; pointing to a cell-id in the wrapped PropNetwork.
;;;
;;; Key concepts:
;;;   - Table entry: predicate name + cell-id + answer-mode + status
;;;   - Answer modes: 'all (set-union) or 'first (freeze after one)
;;;   - Completion: table is complete when its cell reaches fixed point
;;;   - Persistence: all operations return new table-stores (structural sharing)
;;;
;;; This is Racket-level infrastructure with no dependency on Prologos
;;; syntax or type system. The table-store wraps a PropNetwork for storage.
;;;
;;; Design reference: docs/tracking/2026-02-24_LOGIC_ENGINE_DESIGN.org §6
;;;

(require racket/list
         "propagator.rkt")

(provide
 ;; Core structs
 (struct-out table-entry)
 (struct-out table-store)
 ;; Construction
 table-store-empty
 ;; Table management
 table-register
 table-add
 table-answers
 table-freeze
 table-complete?
 ;; Execution
 table-run
 ;; Query
 table-lookup
 ;; Well-founded tabling (Phase 5)
 (struct-out wf-table-entry)
 wf-all-mode-merge
 wf-table-register
 wf-table-add
 wf-table-answers
 wf-table-complete
 wf-table-certainty)

;; ========================================
;; Core structs
;; ========================================

;; A table entry: maps a predicate name to a cell in the PropNetwork
;; name: symbol — predicate name (e.g., 'ancestor)
;; cell-id: cell-id in the prop-network (answers live here)
;; answer-mode: 'all | 'first
;; status: 'active | 'complete
(struct table-entry (name cell-id answer-mode status) #:transparent)

;; The persistent table store
;; network: prop-network (where cell data lives)
;; tables: hasheq : symbol → table-entry (index by name)
(struct table-store (network tables) #:transparent)

;; ========================================
;; Merge functions (internal)
;; ========================================

;; Merge for 'all mode: list-based set union
;; old and new are both lists of answers
;; Uses `equal?` for deduplication (AST structs are #:transparent)
(define (all-mode-merge old new)
  (remove-duplicates (append old new)))

;; Merge for 'first mode: keeps first answer, ignores subsequent
(define (first-mode-merge old new)
  (if (null? old) new old))

;; Select merge function by answer mode symbol
(define (merge-fn-for-mode mode)
  (case mode
    [(all :all) all-mode-merge]
    [(first :first) first-mode-merge]
    [else all-mode-merge]))  ;; default to 'all

;; ========================================
;; Construction
;; ========================================

;; Create an empty table store, optionally wrapping a PropNetwork.
(define (table-store-empty [network #f])
  (table-store (or network (make-prop-network))
               (hasheq)))

;; ========================================
;; Table management
;; ========================================

;; Register a new tabled predicate. Creates a cell in the PropNetwork
;; with the appropriate merge function, and adds a table-entry.
;; Returns (values new-table-store cell-id).
;;
;; name: symbol — predicate name
;; answer-mode: 'all | 'first
(define (table-register ts name answer-mode)
  (define merge (merge-fn-for-mode answer-mode))
  (define-values (net2 cid)
    (net-new-cell (table-store-network ts) '() merge))
  (define entry (table-entry name cid answer-mode 'active))
  (values
   (table-store net2 (hash-set (table-store-tables ts) name entry))
   cid))

;; Add an answer to a table. Writes a singleton list containing the answer
;; to the table's cell. The cell's merge function (set-union or first-keep)
;; merges it with existing answers.
;;
;; name: symbol — predicate name (must be registered)
;; answer: any Racket value (typically a Prologos AST expression)
(define (table-add ts name answer)
  (define entry (hash-ref (table-store-tables ts) name))
  (define net2 (net-cell-write (table-store-network ts)
                               (table-entry-cell-id entry)
                               (list answer)))
  (struct-copy table-store ts [network net2]))

;; Get all answers from a table.
;; Returns a (possibly empty) list of answers.
;;
;; name: symbol — predicate name (must be registered)
(define (table-answers ts name)
  (define entry (hash-ref (table-store-tables ts) name))
  (net-cell-read (table-store-network ts) (table-entry-cell-id entry)))

;; Freeze a table: mark status as 'complete.
;; No more answers should be added after freezing.
;;
;; name: symbol — predicate name (must be registered)
(define (table-freeze ts name)
  (define entry (hash-ref (table-store-tables ts) name))
  (define entry2 (struct-copy table-entry entry [status 'complete]))
  (struct-copy table-store ts
    [tables (hash-set (table-store-tables ts) name entry2)]))

;; Check if a table is marked as complete.
;; Returns #f if the table doesn't exist or isn't complete.
;;
;; name: symbol — predicate name
(define (table-complete? ts name)
  (define entry (hash-ref (table-store-tables ts) name #f))
  (and entry (eq? (table-entry-status entry) 'complete)))

;; ========================================
;; Execution
;; ========================================

;; Run the underlying PropNetwork to quiescence (fixed point).
;; After this, table cells contain all derivable answers.
(define (table-run ts)
  (struct-copy table-store ts
    [network (run-to-quiescence (table-store-network ts))]))

;; ========================================
;; Query
;; ========================================

;; Check if a specific answer exists in a table.
;; Returns #t if the answer is in the table's answer set, #f otherwise.
;; Uses `equal?` for comparison (structural equality on AST exprs).
;;
;; name: symbol — predicate name (must be registered)
;; answer: the answer to look for
(define (table-lookup ts name answer)
  (define answers (table-answers ts name))
  (and (member answer answers) #t))

;; ========================================
;; Well-Founded Tabling (Phase 5)
;; ========================================
;;
;; Three-valued table entries for the well-founded engine.
;; Each answer is paired with a certainty tag ('definite | 'unknown).
;; The merge function deduplicates by answer value, preferring 'definite
;; over 'unknown when the same answer appears with different certainties.

;; Extended table entry with a certainty field for the overall table status.
;; certainty: 'definite | 'unknown — reflects the best certainty across all answers
(struct wf-table-entry table-entry (certainty) #:transparent)

;; Merge for three-valued 'all mode: list-based set union keyed on answer.
;; Each element is (cons answer certainty).
;; If the same answer appears with different certainties, 'definite wins.
(define (wf-all-mode-merge old new)
  (define best (make-hash))
  (for ([entry (in-list (append old new))])
    (define answer (car entry))
    (define certainty (cdr entry))
    (define current (hash-ref best answer #f))
    (when (or (not current) (eq? certainty 'definite))
      (hash-set! best answer certainty)))
  (for/list ([(answer certainty) (in-hash best)])
    (cons answer certainty)))

;; Register a tabled predicate for three-valued answers.
;; Creates a cell with wf-all-mode-merge and a wf-table-entry.
;; Returns (values new-table-store cell-id).
(define (wf-table-register ts name)
  (define-values (net2 cid)
    (net-new-cell (table-store-network ts) '() wf-all-mode-merge))
  (define entry (wf-table-entry name cid 'all 'active 'unknown))
  (values
   (table-store net2 (hash-set (table-store-tables ts) name entry))
   cid))

;; Add an answer with certainty to a three-valued table.
;; answer: any Racket value
;; certainty: 'definite | 'unknown
(define (wf-table-add ts name answer certainty)
  (define entry (hash-ref (table-store-tables ts) name))
  (define net2 (net-cell-write (table-store-network ts)
                               (table-entry-cell-id entry)
                               (list (cons answer certainty))))
  (struct-copy table-store ts [network net2]))

;; Read all answers from a three-valued table.
;; Returns (listof (cons answer certainty)).
(define (wf-table-answers ts name)
  (define entry (hash-ref (table-store-tables ts) name #f))
  (if entry
      (net-cell-read (table-store-network ts) (table-entry-cell-id entry))
      '()))

;; Mark a three-valued table as complete with a final certainty.
;; final-certainty: 'definite | 'unknown
(define (wf-table-complete ts name final-certainty)
  (define entry (hash-ref (table-store-tables ts) name))
  (define entry2 (wf-table-entry (table-entry-name entry)
                                 (table-entry-cell-id entry)
                                 (table-entry-answer-mode entry)
                                 'complete
                                 final-certainty))
  (struct-copy table-store ts
    [tables (hash-set (table-store-tables ts) name entry2)]))

;; Get the certainty of a three-valued table entry.
;; Returns 'definite | 'unknown | #f (if not a wf-table-entry or not found).
(define (wf-table-certainty ts name)
  (define entry (hash-ref (table-store-tables ts) name #f))
  (and entry (wf-table-entry? entry) (wf-table-entry-certainty entry)))

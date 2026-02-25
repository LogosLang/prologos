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
 table-lookup)

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

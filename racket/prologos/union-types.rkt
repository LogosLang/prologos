#lang racket/base

;;;
;;; union-types.rkt — Canonical union type construction and normalization
;;;
;;; SRE Track 2H Phase 1: Extracted from unify.rkt and type-lattice.rkt
;;; to eliminate duplication. Both modules now import from here.
;;;
;;; Depends ONLY on syntax.rkt (struct definitions) and racket/base.
;;; No dependency on metavar-store.rkt, type-lattice.rkt, or unify.rkt.
;;; This is required so both type-lattice.rkt and unify.rkt can import
;;; without circular dependencies.
;;;

(require racket/match
         racket/list
         "syntax.rkt")

(provide flatten-union
         union-sort-key
         dedup-union-components
         build-union-type)

;; ========================================
;; Flatten
;; ========================================

;; Flatten a (possibly nested) expr-union into a list of non-union components.
;; E.g., (union (union A B) C) → (A B C)
(define (flatten-union e)
  (match e
    [(expr-union l r)
     (append (flatten-union l) (flatten-union r))]
    [_ (list e)]))

;; ========================================
;; Canonical sort key
;; ========================================

;; Deterministic ordering for union components.
;; Base types sort first (0:), named types second (1:), bound vars (2:),
;; compound types (3:), applications (4:), metas (5:), other (9:).
(define (union-sort-key e)
  (match e
    [(expr-Nat) "0:Nat"]
    [(expr-nat-val _) "0:NatVal"]
    [(expr-Bool) "0:Bool"]
    [(expr-Unit) "0:Unit"]
    [(expr-Nil) "0:Nil"]
    [(expr-Int) "0:Int"]
    [(expr-Rat) "0:Rat"]
    [(expr-Posit8) "0:Posit8"]
    [(expr-Posit16) "0:Posit16"]
    [(expr-Posit32) "0:Posit32"]
    [(expr-Posit64) "0:Posit64"]
    [(expr-Quire8) "0:Quire8"]
    [(expr-Quire16) "0:Quire16"]
    [(expr-Quire32) "0:Quire32"]
    [(expr-Quire64) "0:Quire64"]
    [(expr-Keyword) "0:Keyword"]
    [(expr-Char) "0:Char"]
    [(expr-String) "0:String"]
    [(expr-net-type) "0:PropNetwork"]
    [(expr-cell-id-type) "0:CellId"]
    [(expr-prop-id-type) "0:PropId"]
    [(expr-uf-type) "0:UnionFind"]
    [(expr-atms-type) "0:ATMS"]
    [(expr-assumption-id-type) "0:AssumptionId"]
    [(expr-table-store-type) "0:TableStore"]
    [(expr-solver-type) "0:Solver"]
    [(expr-goal-type) "0:Goal"]
    [(expr-derivation-type) "0:DerivationTree"]
    [(expr-schema-type name) (format "1:Schema:~a" name)]
    [(expr-answer-type _) "1:Answer"]
    [(expr-relation-type _) "1:Relation"]
    [(expr-Type l) (format "0:Type~a" l)]
    [(expr-fvar name) (format "1:~a" name)]
    [(expr-bvar idx) (format "2:~a" idx)]
    [(expr-Pi _ _ _) "3:Pi"]
    [(expr-Sigma _ _) "3:Sigma"]
    [(expr-Eq _ _ _) "3:Eq"]
    [(expr-Vec _ _) "3:Vec"]
    [(expr-Fin _) "3:Fin"]
    [(expr-Map _ _) "3:Map"]
    [(expr-PVec _) "3:PVec"]
    [(expr-Set _) "3:Set"]
    [(expr-Path) "3:Path"]
    [(expr-TVec _) "3:TVec"]
    [(expr-TMap _ _) "3:TMap"]
    [(expr-TSet _) "3:TSet"]
    [(expr-tycon name) (format "1:tycon:~a" name)]
    [(expr-app _ _) "4:app"]
    [(expr-meta id _) (format "5:?~a" id)]
    [_ "9:other"]))

;; ========================================
;; Deduplication
;; ========================================

;; Remove duplicate components (idempotence: A | A ≡ A).
;; Uses structural equality (equal?) after sorting.
(define (dedup-union-components cs)
  (if (null? cs) '()
      (let loop ([prev (car cs)] [rest (cdr cs)] [acc (list (car cs))])
        (cond
          [(null? rest) (reverse acc)]
          [(equal? prev (car rest))
           (loop prev (cdr rest) acc)]
          [else
           (loop (car rest) (cdr rest) (cons (car rest) acc))]))))

;; ========================================
;; Build canonical union type
;; ========================================

;; Build a canonical union type from a list of types.
;; Flattens any nested unions, sorts by union-sort-key, deduplicates,
;; and builds a right-associated expr-union chain.
;; Single type → identity (no wrapping).
;; Empty → expr-error (should not happen in practice).
(define (build-union-type types)
  (define flat (append-map flatten-union types))
  (define sorted (sort flat string<? #:key union-sort-key))
  (define deduped (dedup-union-components sorted))
  (cond
    [(null? deduped) (expr-error)]
    [(= (length deduped) 1) (car deduped)]
    [else (foldr expr-union (last deduped) (drop-right deduped 1))]))

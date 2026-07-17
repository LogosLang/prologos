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
         racket/string
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
    [(expr-table-store-type) "0:TableStore"]
    [(expr-solver-type) "0:Solver"]
    [(expr-goal-type) "0:Goal"]
    [(expr-derivation-type) "0:DerivationTree"]
    [(expr-answer-type _) "1:Answer"]
    [(expr-relation-type _) "1:Relation"]
    [(expr-Type l) (format "0:Type~a" l)]
    [(expr-fvar name) (format "1:~a" name)]
    [(expr-bvar idx) (format "2:~a" idx)]
    ;; Compound types: include sub-structure in sort key for commutativity
    ;; SRE Track 2H: Pi types with different domains/codomains must sort
    ;; deterministically to ensure union commutativity.
    [(expr-Pi _ d c) (format "3:Pi:~a:~a" (union-sort-key d) (union-sort-key c))]
    [(expr-Sigma f s) (format "3:Sigma:~a:~a" (union-sort-key f) (union-sort-key s))]
    [(expr-Eq t l r) (format "3:Eq:~a" (union-sort-key t))]
    [(expr-Vec e l) (format "3:Vec:~a" (union-sort-key e))]
    [(expr-Fin b) (format "3:Fin:~a" (union-sort-key b))]
    [(expr-Map k v) (format "3:Map:~a:~a" (union-sort-key k) (union-sort-key v))]
    ;; CIU T6 F1 (S1): structural-row key — fields are canonically sorted, so this is
    ;; deterministic → record-containing unions are commutative/idempotent under build-union-type.
    ;; ✏ F1b.3 (D24): the PRESENCE mark joins the key as a deterministic tiebreak —
    ;; without it, presence-twins (same types, different marks) collide on sort key
    ;; and Racket's stable sort makes branch order INPUT-ORDER dependent, silently
    ;; falsifying the commutativity/idempotence claim above.
    [(expr-Record kd fields tail)
     (format "3:Record:~a:~a:~a" kd
             (string-join (for/list ([fld (in-list fields)])
                            (format "~a=~a/~a" (car fld)
                                    (union-sort-key (record-field-type (cdr fld)))
                                    (record-field-presence (cdr fld))))
                          ",")
             tail)]
    [(expr-PVec e) (format "3:PVec:~a" (union-sort-key e))]
    [(expr-Set e) (format "3:Set:~a" (union-sort-key e))]
    [(expr-Path) "3:Path"]
    [(expr-TVec e) (format "3:TVec:~a" (union-sort-key e))]
    [(expr-TMap k v) (format "3:TMap:~a:~a" (union-sort-key k) (union-sort-key v))]
    [(expr-TSet e) (format "3:TSet:~a" (union-sort-key e))]
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
  (define deduped (presence-absorb-adjacent (dedup-union-components sorted)))
  (cond
    [(null? deduped) (expr-error)]
    [(= (length deduped) 1) (car deduped)]
    [else (foldr expr-union (last deduped) (drop-right deduped 1))]))

;; CIU T6 F1b.3 (D24): presence absorption — a row differing from its neighbor
;; ONLY in marks where the neighbor is 'unknown collapses into the neighbor:
;; {P} ⊆ {P,A} at every differing label, so the 'present branch adds no
;; information the 'unknown branch doesn't already admit. Adjacency suffices:
;; the sort key differs only in the presence segment, so candidates sort
;; together. (The first subsumption rule in this file — dedup is pure equal?.)
(define (presence-absorb-adjacent cs)
  ;; a absorbs b iff same kd/tail/labels/types and, per label,
  ;; mark_a = mark_b OR (mark_a = 'unknown AND mark_b = 'present).
  (define (absorbs? a b)
    (and (expr-Record? a) (expr-Record? b)
         (eq? (expr-Record-key-domain a) (expr-Record-key-domain b))
         (eq? (expr-Record-tail a) (expr-Record-tail b))
         (let ([fa (expr-Record-fields a)] [fb (expr-Record-fields b)])
           (and (= (length fa) (length fb))
                (andmap (lambda (pa pb)
                          (and (eqv? (car pa) (car pb))
                               (equal? (record-field-type (cdr pa))
                                       (record-field-type (cdr pb)))
                               (or (eq? (record-field-presence (cdr pa))
                                        (record-field-presence (cdr pb)))
                                   (and (eq? (record-field-presence (cdr pa)) 'unknown)
                                        (eq? (record-field-presence (cdr pb)) 'present)))))
                        fa fb)))))
  (let loop ([cs cs] [acc '()])
    (cond
      [(null? cs) (reverse acc)]
      [(and (pair? (cdr cs)) (absorbs? (car cs) (cadr cs)))
       (loop (cons (car cs) (cddr cs)) acc)]
      [(and (pair? (cdr cs)) (absorbs? (cadr cs) (car cs)))
       (loop (cdr cs) acc)]
      [else (loop (cdr cs) (cons (car cs) acc))])))

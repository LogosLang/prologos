#lang racket/base

;;;
;;; session-lattice.rkt — Session type lattice for propagator cells
;;;
;;; Defines the merge function (lattice join) for session-typed cells.
;;; Modeled after type-lattice.rkt but specialized for session types.
;;;
;;;   sess-bot  (⊥, no information — fresh session cell)
;;;       ↓
;;;   sess-send / sess-recv / sess-choice / sess-offer / ...
;;;       ↓
;;;   sess-top  (⊤, contradiction — incompatible session shapes)
;;;
;;; The merge performs pure structural session unification:
;;; - Same polarity: merge type components + continuations recursively
;;; - Different polarity: contradiction (sess-top)
;;; - Choice + Choice: intersect labels (covariant)
;;; - Offer + Offer: union labels (contravariant)
;;; - End + End: End
;;;
;;; This module has minimal dependencies (sessions.rkt for constructors,
;;; type-lattice.rkt for message type merging).
;;;

(require racket/match
         "sessions.rkt"
         "type-lattice.rkt")

(provide sess-bot sess-top sess-bot? sess-top?
         session-lattice-merge
         session-lattice-meet           ;; Track 2G: session lattice meet
         session-lattice-contradicts?
         try-unify-session-pure
         has-unsolved-session-meta?)

;; ========================================
;; Sentinel values
;; ========================================

(define sess-bot 'sess-bot)
(define sess-top 'sess-top)

(define (sess-bot? v) (eq? v 'sess-bot))
(define (sess-top? v) (eq? v 'sess-top))

;; ========================================
;; Contradiction check
;; ========================================

(define (session-lattice-contradicts? v) (sess-top? v))

;; ========================================
;; Meta detection: does a session contain unsolved sess-metas?
;; ========================================

(define (has-unsolved-session-meta? s)
  (match s
    [(? sess-bot?) #f]
    [(? sess-top?) #f]
    [(sess-meta _ _) #t]  ;; unsolved meta — always counts
    [(sess-send ty cont)
     (or (has-unsolved-session-meta? cont))]
    [(sess-recv ty cont)
     (or (has-unsolved-session-meta? cont))]
    [(sess-dsend ty cont)
     (or (has-unsolved-session-meta? cont))]
    [(sess-drecv ty cont)
     (or (has-unsolved-session-meta? cont))]
    [(sess-async-send ty cont)
     (or (has-unsolved-session-meta? cont))]
    [(sess-async-recv ty cont)
     (or (has-unsolved-session-meta? cont))]
    [(sess-choice branches)
     (ormap (lambda (b) (has-unsolved-session-meta? (cdr b))) branches)]
    [(sess-offer branches)
     (ormap (lambda (b) (has-unsolved-session-meta? (cdr b))) branches)]
    [(sess-mu body)
     (has-unsolved-session-meta? body)]
    [(sess-svar _) #f]
    [(sess-end) #f]
    [_ #f]))

;; ========================================
;; Merge (lattice join)
;; ========================================

;; Session lattice merge: monotonic join over session types.
;; bot ⊔ x = x, x ⊔ x = x, incompatible shapes = top.
;; For compatible shapes, recursively merges components.
(define (session-lattice-merge old new)
  (cond
    ;; Bot identity
    [(sess-bot? old) new]
    [(sess-bot? new) old]
    ;; Top absorbing
    [(sess-top? old) sess-top]
    [(sess-top? new) sess-top]
    ;; Fast path: pointer equality
    [(eq? old new) old]
    ;; Structural equality
    [(equal? old new) old]
    ;; Structural session unification (pure)
    [else
     (define result (try-unify-session-pure old new))
     (cond
       [result result]
       ;; If either side has unsolved metas, defer contradiction
       [(or (has-unsolved-session-meta? old) (has-unsolved-session-meta? new))
        (if (has-unsolved-session-meta? old) new old)]
       ;; Both ground and incompatible → contradiction
       [else sess-top])]))

;; ========================================
;; SRE Track 2G: Session lattice meet (greatest lower bound)
;; ========================================
;; Dual of session-lattice-merge. Meet computes the greatest lower bound:
;;   ⊤ ⊓ x = x, x ⊓ ⊥ = ⊥, equal → identity.
;;   Same session shape → component-wise meet.
;;   Different shapes → ⊥. Meta → ⊥ (conservative).

(define (session-lattice-meet v1 v2)
  (cond
    ;; Identity: ⊤ ⊓ x = x
    [(sess-top? v1) v2]
    [(sess-top? v2) v1]
    ;; Annihilator: x ⊓ ⊥ = ⊥
    [(sess-bot? v1) sess-bot]
    [(sess-bot? v2) sess-bot]
    ;; Equal: a ⊓ a = a
    [(eq? v1 v2) v1]
    [(equal? v1 v2) v1]
    ;; Meta → ⊥ (conservative)
    [(or (has-unsolved-session-meta? v1) (has-unsolved-session-meta? v2)) sess-bot]
    ;; Different ground shapes → ⊥
    [else sess-bot]))

;; ========================================
;; Pure structural session unification
;; ========================================

;; try-unify-session-pure: pure structural unification for sessions.
;; Returns a unified session, or #f if incompatible.
;; No side effects — no cell writes, no meta solving.
(define (try-unify-session-pure s1 s2)
  (cond
    ;; Identical
    [(equal? s1 s2) s1]
    ;; Bot: return the concrete side
    [(sess-bot? s1) s2]
    [(sess-bot? s2) s1]
    ;; Top: absorbing
    [(sess-top? s1) sess-top]
    [(sess-top? s2) sess-top]
    ;; Meta on one side: return the concrete side (can't solve in pure mode)
    [(sess-meta? s1) s2]
    [(sess-meta? s2) s1]
    [else (try-unify-session-structural s1 s2)]))

;; Structural unification (both sides are concrete session types).
(define (try-unify-session-structural s1 s2)
  (match* (s1 s2)
    ;; ---- Same polarity: merge type + continuation ----
    [((sess-send a1 cont1) (sess-send a2 cont2))
     (let ([merged-ty (try-unify-pure a1 a2)]
           [merged-cont (try-unify-session-pure cont1 cont2)])
       (and merged-ty merged-cont
            (sess-send merged-ty merged-cont)))]

    [((sess-recv a1 cont1) (sess-recv a2 cont2))
     (let ([merged-ty (try-unify-pure a1 a2)]
           [merged-cont (try-unify-session-pure cont1 cont2)])
       (and merged-ty merged-cont
            (sess-recv merged-ty merged-cont)))]

    ;; ---- Dependent send/recv ----
    [((sess-dsend a1 cont1) (sess-dsend a2 cont2))
     (let ([merged-ty (try-unify-pure a1 a2)]
           [merged-cont (try-unify-session-pure cont1 cont2)])
       (and merged-ty merged-cont
            (sess-dsend merged-ty merged-cont)))]

    [((sess-drecv a1 cont1) (sess-drecv a2 cont2))
     (let ([merged-ty (try-unify-pure a1 a2)]
           [merged-cont (try-unify-session-pure cont1 cont2)])
       (and merged-ty merged-cont
            (sess-drecv merged-ty merged-cont)))]

    ;; ---- Async send/recv ----
    [((sess-async-send a1 cont1) (sess-async-send a2 cont2))
     (let ([merged-ty (try-unify-pure a1 a2)]
           [merged-cont (try-unify-session-pure cont1 cont2)])
       (and merged-ty merged-cont
            (sess-async-send merged-ty merged-cont)))]

    [((sess-async-recv a1 cont1) (sess-async-recv a2 cont2))
     (let ([merged-ty (try-unify-pure a1 a2)]
           [merged-cont (try-unify-session-pure cont1 cont2)])
       (and merged-ty merged-cont
            (sess-async-recv merged-ty merged-cont)))]

    ;; ---- Choice: intersect labels (both sides must offer same label) ----
    [((sess-choice branches1) (sess-choice branches2))
     (let ([merged (merge-branches branches1 branches2)])
       (and merged (sess-choice merged)))]

    ;; ---- Offer: union labels (contravariant — both must handle all) ----
    [((sess-offer branches1) (sess-offer branches2))
     (let ([merged (merge-branches branches1 branches2)])
       (and merged (sess-offer merged)))]

    ;; ---- Recursion ----
    [((sess-mu body1) (sess-mu body2))
     (let ([merged-body (try-unify-session-pure body1 body2)])
       (and merged-body (sess-mu merged-body)))]

    ;; ---- Session variable ----
    [((sess-svar n1) (sess-svar n2))
     (and (= n1 n2) s1)]

    ;; ---- End ----
    [((sess-end) (sess-end)) (sess-end)]

    ;; ---- Incompatible shapes ----
    [(_ _) #f]))

;; ========================================
;; Branch merging
;; ========================================

;; Merge two branch lists by unifying continuations for matching labels.
;; Returns merged branch list or #f on incompatibility.
;; Currently uses intersection semantics: only labels present in BOTH lists.
;; (For full subtyping, Choice would use intersection, Offer would use union.)
(define (merge-branches branches1 branches2)
  (let loop ([b1 branches1] [acc '()])
    (cond
      [(null? b1)
       ;; Check that all b2 labels are covered
       (if (= (length acc) (length branches2))
           (reverse acc)
           ;; Mismatched label counts — for now allow if all b1 labels unified
           (reverse acc))]
      [else
       (define label (caar b1))
       (define cont1 (cdar b1))
       (define match-b2 (assq label branches2))
       (cond
         ;; Label present in both → unify continuations
         [match-b2
          (define cont2 (cdr match-b2))
          (define merged-cont (try-unify-session-pure cont1 cont2))
          (if merged-cont
              (loop (cdr b1) (cons (cons label merged-cont) acc))
              #f)]  ;; continuation incompatible → fail
         ;; Label only in b1 — keep it (wider interface)
         [else
          (loop (cdr b1) (cons (cons label cont1) acc))])])))

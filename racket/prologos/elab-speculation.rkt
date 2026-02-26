#lang racket/base

;;;
;;; elab-speculation.rkt — ATMS-backed speculative elaboration
;;;
;;; Provides speculative type-checking on top of the elaboration network.
;;; Each speculative branch forks the elab-network (O(1) persistent copy),
;;; applies elaboration operations, and checks for contradictions. An ATMS
;;; tracks hypotheses and records nogoods for error reporting.
;;;
;;; Phase 4 of the type inference refactoring.
;;; Design reference: docs/tracking/2026-02-25_TYPE_INFERENCE_ON_LOGIC_ENGINE_DESIGN.md §3.4, §5.4
;;;

(require "elaborator-network.rkt"
         "atms.rkt"
         "type-lattice.rkt"
         "propagator.rkt")

(provide
 ;; Structs
 (struct-out speculation)
 (struct-out branch)
 (struct-out speculation-result)
 (struct-out nogood-info)
 ;; Core API
 speculation-begin
 speculation-try-branch
 speculation-commit
 ;; Convenience
 speculate-first-success
 ;; Queries
 speculation-branch-count
 speculation-branch-status
 speculation-branch-enet)

;; ========================================
;; Structs
;; ========================================

;; A speculation context: ATMS + base network + branches.
(struct speculation
  (atms           ;; atms (tracks hypotheses, nogoods, mutual exclusion)
   base-enet      ;; elab-network (state at speculation start — fork point)
   branches       ;; (listof branch) (one per alternative)
   next-id)       ;; Nat (deterministic counter)
  #:transparent)

;; A single speculative branch.
(struct branch
  (hypothesis-id  ;; assumption-id (from atms-amb)
   enet           ;; elab-network (forked network for this branch)
   status         ;; 'pending | 'ok | 'contradiction
   contradiction  ;; contradiction-info | #f
   label)         ;; string (debug label)
  #:transparent)

;; Result of committing a speculation.
(struct speculation-result
  (status         ;; 'ok | 'all-failed
   enet           ;; elab-network | #f (winning branch's network)
   winner-index   ;; Nat | #f
   nogoods        ;; (listof nogood-info)
   atms-val)      ;; atms (final state with nogoods recorded)
  #:transparent)

;; Nogood info for error reporting.
(struct nogood-info
  (branch-index   ;; Nat
   branch-label   ;; string
   contradiction  ;; contradiction-info | #f
   hypothesis-id) ;; assumption-id
  #:transparent)

;; ========================================
;; Core API
;; ========================================

;; Create a speculation context with mutually exclusive branches.
;; enet: the current elab-network (fork point)
;; labels: (listof string) — one per alternative
(define (speculation-begin enet labels)
  (define a (atms-empty))
  (define-values (a* hyps) (atms-amb a labels))
  (define branches
    (for/list ([h (in-list hyps)]
               [lbl (in-list labels)])
      (branch h enet 'pending #f lbl)))
  (speculation a* enet branches 0))

;; Try elaboration on a branch.
;; idx: branch index (0-based)
;; try-fn: (elab-network → elab-network) — applies elaboration ops to the forked network
;; Returns updated speculation with branch status set.
(define (speculation-try-branch spec idx try-fn)
  (define br (list-ref (speculation-branches spec) idx))
  (define enet-forked (branch-enet br))
  ;; Apply the elaboration function to the forked network
  (define enet-after (try-fn enet-forked))
  ;; Run to quiescence (use run-to-quiescence directly to keep the
  ;; post-quiescence network even on contradiction — elab-solve discards it)
  (define net* (run-to-quiescence (elab-network-prop-net enet-after)))
  (define enet*
    (elab-network net*
                  (elab-network-cell-info enet-after)
                  (elab-network-next-meta-id enet-after)))
  (define has-contradiction (net-contradiction? net*))
  (define br*
    (if has-contradiction
        (struct-copy branch br
          [enet enet*]
          [status 'contradiction]
          [contradiction (extract-contradiction-info enet*)])
        (struct-copy branch br
          [enet enet*]
          [status 'ok])))
  ;; Update ATMS: record nogood if contradiction
  (define a*
    (if has-contradiction
        (atms-add-nogood (speculation-atms spec)
                         (hasheq (branch-hypothesis-id br*) #t))
        (speculation-atms spec)))
  ;; Replace branch in list
  (define branches*
    (for/list ([b (in-list (speculation-branches spec))]
               [i (in-naturals)])
      (if (= i idx) br* b)))
  (struct-copy speculation spec [branches branches*] [atms a*]))

;; Select the winning branch: first 'ok branch wins.
;; Returns speculation-result.
(define (speculation-commit spec)
  (define branches (speculation-branches spec))
  ;; Collect nogoods from failed branches
  (define ngs
    (for/list ([br (in-list branches)]
               [i (in-naturals)]
               #:when (eq? (branch-status br) 'contradiction))
      (nogood-info i (branch-label br) (branch-contradiction br) (branch-hypothesis-id br))))
  ;; Find first OK branch
  (define winner-idx
    (for/first ([br (in-list branches)]
                [i (in-naturals)]
                #:when (eq? (branch-status br) 'ok))
      i))
  (if winner-idx
      (speculation-result 'ok
                          (branch-enet (list-ref branches winner-idx))
                          winner-idx ngs (speculation-atms spec))
      (speculation-result 'all-failed #f #f ngs (speculation-atms spec))))

;; ========================================
;; Convenience API
;; ========================================

;; Try alternatives sequentially, short-circuiting on first success.
;; try-fns: (listof (elab-network → elab-network))
;; labels: (listof string)
(define (speculate-first-success enet try-fns labels)
  (define spec (speculation-begin enet labels))
  (let loop ([s spec] [idx 0])
    (cond
      [(>= idx (length try-fns))
       (speculation-commit s)]
      [else
       (define s* (speculation-try-branch s idx (list-ref try-fns idx)))
       (define br (list-ref (speculation-branches s*) idx))
       (if (eq? (branch-status br) 'ok)
           (speculation-commit s*)
           (loop s* (+ idx 1)))])))

;; ========================================
;; Queries
;; ========================================

;; Number of branches in a speculation.
(define (speculation-branch-count spec)
  (length (speculation-branches spec)))

;; Status of a specific branch.
(define (speculation-branch-status spec idx)
  (branch-status (list-ref (speculation-branches spec) idx)))

;; Elab-network of a specific branch.
(define (speculation-branch-enet spec idx)
  (branch-enet (list-ref (speculation-branches spec) idx)))

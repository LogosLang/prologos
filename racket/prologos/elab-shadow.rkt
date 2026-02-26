#lang racket/base

;;;
;;; elab-shadow.rkt — Shadow propagator network for type inference validation
;;;
;;; Mirrors metavar operations (fresh, solve, constraint) to a shadow
;;; propagator network via callback hooks in metavar-store.rkt. After
;;; type-checking completes, validates that the propagator network agrees
;;; with the ad-hoc metavar system (no contradictions, no mismatches).
;;;
;;; Phase 3 of the type inference refactoring.
;;; Design reference: docs/tracking/2026-02-25_TYPE_INFERENCE_ON_LOGIC_ENGINE_DESIGN.md §5.3
;;;

(require "elaborator-network.rkt"
         "type-lattice.rkt"
         "metavar-store.rkt"
         "propagator.rkt"
         "syntax.rkt")

(provide
 ;; Report struct
 (struct-out shadow-report)
 ;; State parameters
 current-shadow-network
 current-shadow-id-map
 ;; Lifecycle
 shadow-init!
 shadow-teardown!
 ;; Callbacks (installed as hooks)
 shadow-on-fresh-meta
 shadow-on-solve-meta
 shadow-on-constraint
 ;; Validation
 shadow-validate!
 shadow-log-report!)

;; ========================================
;; Validation report
;; ========================================

(struct shadow-report
  (total-metas       ;; Nat — total metas mirrored
   total-solved      ;; Nat — solved in the ad-hoc system
   shadow-solved     ;; Nat — non-bot in shadow network after propagation
   contradictions    ;; Nat — cells at type-top (contradiction)
   mismatches        ;; (listof (list meta-id ad-hoc-solution shadow-value))
   constraints-added ;; Nat — propagators in shadow network
   ok?)              ;; Bool — #t if no contradictions and no mismatches
  #:transparent)

;; ========================================
;; Internal mutable state
;; ========================================
;; The hooks are called from imperative meta-store ops, so shadow state
;; must be mutable. We box the immutable elab-network (CHAMP-backed).

(define current-shadow-network (make-parameter #f))   ;; box of elab-network | #f
(define current-shadow-id-map (make-parameter #f))    ;; mutable hasheq: meta-id → cell-id | #f

;; ========================================
;; Lifecycle
;; ========================================

;; Initialize shadow network and install hooks.
(define (shadow-init!)
  (current-shadow-network (box (make-elaboration-network)))
  (current-shadow-id-map (make-hasheq))
  (current-shadow-fresh-hook shadow-on-fresh-meta)
  (current-shadow-solve-hook shadow-on-solve-meta)
  (current-shadow-constraint-hook shadow-on-constraint))

;; Uninstall hooks and clear state.
(define (shadow-teardown!)
  (current-shadow-fresh-hook #f)
  (current-shadow-solve-hook #f)
  (current-shadow-constraint-hook #f)
  (current-shadow-network #f)
  (current-shadow-id-map #f))

;; ========================================
;; Hook callbacks
;; ========================================

;; Mirror meta creation to shadow cell.
(define (shadow-on-fresh-meta id ctx type source)
  (define net-box (current-shadow-network))
  (when net-box
    (define enet (unbox net-box))
    (define-values (enet* cid) (elab-fresh-meta enet ctx type source))
    (hash-set! (current-shadow-id-map) id cid)
    (set-box! net-box enet*)))

;; Write solution to shadow cell.
(define (shadow-on-solve-meta id solution)
  (define net-box (current-shadow-network))
  (when net-box
    (define enet (unbox net-box))
    (define cid (hash-ref (current-shadow-id-map) id #f))
    (when cid
      (set-box! net-box (elab-cell-write enet cid solution)))))

;; When a constraint is postponed, add unification propagators between
;; shadow cells referenced by lhs/rhs metas.
(define (shadow-on-constraint lhs rhs ctx source)
  (define net-box (current-shadow-network))
  (when net-box
    (define enet (unbox net-box))
    (define id-map (current-shadow-id-map))
    (define lhs-metas (extract-shallow-meta-ids lhs))
    (define rhs-metas (extract-shallow-meta-ids rhs))
    ;; For each pair of metas (one from lhs, one from rhs), add unify constraint
    (define enet*
      (for*/fold ([net enet])
                 ([lm (in-list lhs-metas)]
                  [rm (in-list rhs-metas)])
        (define lcid (hash-ref id-map lm #f))
        (define rcid (hash-ref id-map rm #f))
        (if (and lcid rcid (not (equal? lcid rcid)))
            (let-values ([(net* _pid) (elab-add-unify-constraint net lcid rcid)])
              net*)
            net)))
    (set-box! net-box enet*)))

;; Shallow meta-id extractor: finds expr-meta nodes without following solutions.
;; Unlike collect-meta-ids in metavar-store.rkt, does NOT chase solved metas.
;; Phase 7b: Ground-atom fast path — skip atoms that can never contain metas.
(define (extract-shallow-meta-ids expr)
  (let walk ([e expr] [acc '()])
    (cond
      [(expr-meta? e)
       (define id (expr-meta-id e))
       (if (memq id acc) acc (cons id acc))]
      ;; Fast path: ground atoms never contain metas
      [(or (symbol? e) (number? e) (string? e) (boolean? e) (char? e))
       acc]
      [(struct? e)
       (define v (struct->vector e))
       (for/fold ([a acc])
                 ([i (in-range 1 (vector-length v))])
         (define field (vector-ref v i))
         (if (or (struct? field) (expr-meta? field))
             (walk field a)
             a))]
      [else acc])))

;; ========================================
;; Validation
;; ========================================

;; Run shadow network to quiescence and compare with meta-store.
;; Unlike elab-solve, always returns the post-quiescence network
;; (even if contradicted) so we can inspect cell values.
(define (shadow-validate!)
  (define net-box (current-shadow-network))
  (unless net-box
    (error 'shadow-validate! "shadow network not initialized"))
  (define enet (unbox net-box))
  ;; Run to quiescence directly (elab-solve discards network on contradiction)
  (define net* (run-to-quiescence (elab-network-prop-net enet)))
  (define enet*
    (elab-network net*
                  (elab-network-cell-info enet)
                  (elab-network-next-meta-id enet)))
  (set-box! net-box enet*)
  ;; Compare each meta with shadow cell
  (define id-map (current-shadow-id-map))
  (define mismatches '())
  (define total 0)
  (define solved 0)
  (define shadow-solved-count 0)
  (define contras 0)
  (for ([(meta-id cid) (in-hash id-map)])
    (set! total (add1 total))
    (define shadow-val (elab-cell-read enet* cid))
    (when (type-top? shadow-val) (set! contras (add1 contras)))
    (when (and (not (type-bot? shadow-val)) (not (type-top? shadow-val)))
      (set! shadow-solved-count (add1 shadow-solved-count)))
    (when (meta-solved? meta-id)
      (set! solved (add1 solved))
      (define ad-hoc-sol (meta-solution meta-id))
      (cond
        [(type-bot? shadow-val) (void)]  ;; shadow didn't get info — expected
        [(type-top? shadow-val)
         (set! mismatches (cons (list meta-id ad-hoc-sol shadow-val) mismatches))]
        [(not (equal? shadow-val ad-hoc-sol))
         ;; Check if merge agrees (structural unification equivalence)
         (define merged (type-lattice-merge shadow-val ad-hoc-sol))
         (when (type-top? merged)
           (set! mismatches (cons (list meta-id ad-hoc-sol shadow-val) mismatches)))])))
  (shadow-report total solved shadow-solved-count contras (reverse mismatches)
                 (prop-network-next-prop-id (elab-network-prop-net enet*))
                 (and (null? mismatches) (= contras 0))))

;; Print report to stderr.
(define (shadow-log-report! report)
  (eprintf "SHADOW: ~a metas, ~a solved, ~a shadow-solved, ~a contradictions, ~a mismatches → ~a\n"
           (shadow-report-total-metas report)
           (shadow-report-total-solved report)
           (shadow-report-shadow-solved report)
           (shadow-report-contradictions report)
           (length (shadow-report-mismatches report))
           (if (shadow-report-ok? report) "OK" "MISMATCH")))

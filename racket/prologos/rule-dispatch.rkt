#lang racket/base
;;; rule-dispatch.rkt — PReduce Track 2 Phase 0: apply-rule + the RHS effect-safety
;;; dispatch guard (D.1 §6.2 Option 2, owner-signed; Track 2 design §2/§5).
;;;
;;; THE SINGLE CHOKE POINT: every RHS instantiation goes through apply-rule. The
;;; guard enforces — an RHS may not DELETE, DUPLICATE, or REORDER a captured
;;; subterm whose class is EFFECT-BEARING. BLOCKING: exists and passes BEFORE β
;;; (the first generic rule) ever fires; β is its first real exercise.
;;;
;;; Pattern language (v1, the seed's shape — hardens with Phase 1):
;;;   LHS  = (head-tag pat ...)  where pat = (capture VAR) | literal-datum
;;;   RHS  = arbitrary datum; (ref VAR) marks a captured-subterm use
;;; capture-profile: derived ONCE at registration (templates are immutable
;;; post-registration — dedup-or-error makes staleness structurally impossible,
;;; design §7 VAG) — per-var LHS/RHS occurrence counts + ordered effemeral...
;;; ordered occurrence sequences for the REORDER check.
;;;
;;; Guard semantics: a violating match SKIPS (structural skip + counter), NOT an
;;; error — semantics are preserved exactly (the term stays reducible elsewhere);
;;; effect-adjacency as a type error was explicitly rejected (SM5: the boundary
;;; is one node thick). Tier-2 rules (no RHS template): capture-profile
;;; underivable → PESSIMISTIC skip on ANY effect-bearing capture + counter
;;; (named upgrade: per-rule declared profiles).
(require racket/set
         racket/list
         "rule-registry.rkt"
         "eclass-graph.rkt"
         "eclass-cell.rkt"
         "propagator.rkt")

(provide derive-capture-profile
         effect-bearing-class?
         guard-allows?
         apply-rule
         guard-skip-count
         reset-guard-skip-count!)

;; --- the Phase-0 observability counter (PERF-COUNTERS struct-field integration
;;     rides with Phase 1's driver wiring, where the counter becomes externally
;;     visible — adding the struct field triggers the pipeline.md checklist and
;;     belongs in that commit) ---
(define guard-skips (box 0))
(define (guard-skip-count) (unbox guard-skips))
(define (reset-guard-skip-count!) (set-box! guard-skips 0))

;; --- capture-profile derivation (at REGISTRATION; templates immutable) ---

(define (pattern-captures lhs)
  ;; ordered capture vars from the LHS, by traversal position
  (let walk ([p lhs] [acc '()])
    (cond
      [(and (pair? p) (eq? (car p) 'capture)) (cons (cadr p) acc)]
      [(pair? p) (for/fold ([a acc]) ([sub (in-list p)]) (walk sub a))]
      [else acc])))

(define (template-refs rhs)
  ;; ordered (ref VAR) occurrences in the RHS, by traversal position
  (let walk ([p rhs] [acc '()])
    (cond
      [(and (pair? p) (eq? (car p) 'ref)) (cons (cadr p) acc)]
      [(pair? p) (for/fold ([a acc]) ([sub (in-list p)]) (walk sub a))]
      [else acc])))

;; → (hash 'lhs-order (listof var) 'rhs-order (listof var)
;;         'counts (hash var (cons lhs-count rhs-count)))  |  'underivable (tier-2)
(define (derive-capture-profile rule)
  (define lhs (preduce-rule-lhs-pattern rule))
  (define rhs (preduce-rule-rhs-template rule))
  (cond
    [(or (not lhs) (not rhs)) 'underivable]
    [else
     (define lhs-order (reverse (pattern-captures lhs)))
     (define rhs-order (reverse (template-refs rhs)))
     (define counts
       (for/hash ([v (in-list (remove-duplicates (append lhs-order rhs-order)))])
         (values v (cons (count (lambda (x) (eq? x v)) lhs-order)
                         (count (lambda (x) (eq? x v)) rhs-order)))))
     (hash 'lhs-order lhs-order 'rhs-order rhs-order 'counts counts)]))

;; --- effect-bearing classification (reads iteration 13's floor markers) ---

(define (effect-bearing-class? net cid)
  (define v (net-cell-read net cid))
  (and (hash? v)
       (set-member? (hash-ref v ':provenance (seteq)) 'effect-occurrence)))

;; --- the guard ---
;; bindings: (hash var → class-cid). Returns #t (fire) or #f (skip; counted).
(define (guard-allows? net profile bindings)
  (define (skip!) (set-box! guard-skips (add1 (unbox guard-skips))) #f)
  (cond
    [(eq? profile 'underivable)
     ;; tier-2 pessimism: any effect-bearing capture ⇒ skip
     (if (for/or ([(v cid) (in-hash bindings)]) (effect-bearing-class? net cid))
         (skip!)
         #t)]
    [else
     (define counts (hash-ref profile 'counts))
     (define effectful-vars
       (for/list ([v (in-list (hash-ref profile 'lhs-order))]
                  #:when (let ([cid (hash-ref bindings v #f)])
                           (and cid (effect-bearing-class? net cid))))
         v))
     (cond
       [(null? effectful-vars) #t]  ;; pure match — fire freely
       [(for/or ([v (in-list (remove-duplicates effectful-vars))])
          (define c (hash-ref counts v (cons 0 0)))
          (or (zero? (cdr c))            ;; DELETE: captured, never used in RHS
              (> (cdr c) (car c))))      ;; DUPLICATE: used more than captured
        (skip!)]
       [else
        ;; REORDER: the relative order of effectful captures must be preserved
        (define lhs-eff (filter (lambda (v) (memq v effectful-vars))
                                (hash-ref profile 'lhs-order)))
        (define rhs-eff (filter (lambda (v) (memq v effectful-vars))
                                (hash-ref profile 'rhs-order)))
        (if (equal? lhs-eff rhs-eff) #t (skip!))])]))

;; --- matching + instantiation (v1: the seed's shape) ---

;; match a form datum against an LHS pattern → (hash var → subform) | #f
(define (match-pattern lhs form)
  (let walk ([p lhs] [f form] [env (hash)])
    (cond
      [(not env) #f]
      [(and (pair? p) (eq? (car p) 'capture)) (and env (hash-set env (cadr p) f))]
      [(and (pair? p) (pair? f) (= (length p) (length f)))
       (for/fold ([e env]) ([sp (in-list p)] [sf (in-list f)])
         (and e (walk sp sf e)))]
      [(equal? p f) env]
      [else #f])))

(define (instantiate-template rhs env)
  (let walk ([p rhs])
    (cond
      [(and (pair? p) (eq? (car p) 'ref)) (hash-ref env (cadr p))]
      [(pair? p) (map walk p)]
      [else p])))

;; --- apply-rule: THE choke point ---
;; The match is driven on the class's best FORM; captured subforms bind to their
;; OWN classes via class-of (caller-supplied: subform → class-cid | #f — lazy
;; ingestion means uninterned subforms have no class and are effect-free by
;; construction: effectful occurrences are ALWAYS interned by the iteration-13
;; floor before any rule can see them).
;; → (values net' fired?)
(define (apply-rule net reg-cid rule class-cid
                    #:class-of [class-of (lambda (subform) #f)]
                    #:cost [cost 1])
  (define v (net-cell-read net class-cid))
  (define best (and (hash? v) (hash-ref v ':best #f)))
  (define form (and best (cdr best)))
  (define lhs (preduce-rule-lhs-pattern rule))
  (cond
    [(or (not form) (not lhs)) (values net #f)]
    [else
     (define env (match-pattern lhs form))
     (cond
       [(not env) (values net #f)]
       [else
        (define bindings
          (for/hash ([(var subform) (in-hash env)])
            (values var (class-of subform))))
        (define cid-bindings
          (for/hash ([(var cid) (in-hash bindings)] #:when cid)
            (values var cid)))
        (define profile (derive-capture-profile rule))
        (cond
          [(not (guard-allows? net profile cid-bindings)) (values net #f)]
          [(not (preduce-rule-rhs-template rule)) (values net #f)]  ;; tier-2: no
          ;; template to instantiate here (closure rules fire via their own path
          ;; once Phase 1 wires apply-fn; the GUARD above still gates them)
          [else
           (define result-form (instantiate-template
                                (preduce-rule-rhs-template rule) env))
           (define-values (net1 result-cid _dig)
             (eclass-intern net reg-cid result-form #:cost cost))
           (define net2 (run-to-quiescence (eclass-union net1 class-cid result-cid)))
           (values net2 #t)])])]))

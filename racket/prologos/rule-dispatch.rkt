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
         "performance-counters.rkt"
         "rule-registry.rkt"
         "eclass-graph.rkt"
         "eclass-cell.rkt"
         "propagator.rkt")

(provide derive-capture-profile
         effect-bearing-class?
         guard-allows?
         apply-rule
         dispatch-rules
         guard-skip-count
         reset-guard-skip-count!
         guard-skip-note!
         process-dispatch-requests)

;; --- the Phase-0 observability counter (PERF-COUNTERS struct-field integration
;;     rides with Phase 1's driver wiring, where the counter becomes externally
;;     visible — adding the struct field triggers the pipeline.md checklist and
;;     belongs in that commit) ---
(define guard-skips (box 0))
(define (guard-skip-count) (unbox guard-skips))
(define (reset-guard-skip-count!) (set-box! guard-skips 0))
;; ONE increment path for BOTH consumers (test box + production pc) — the two
;; counters diverging was gate-caught at iter 25 (the β clause hit only the pc).
(define (guard-skip-note!)
  (set-box! guard-skips (add1 (unbox guard-skips)))
  (perf-inc-guard-skip!))

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
  ;; the box is TEST instrumentation (unit tests run without a pc installed);
  ;; the pc field is PRODUCTION reporting (PERF-COUNTERS line) — different
  ;; consumers, no fallback logic between them
  (define (skip!) (guard-skip-note!) #f)
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

;; The COMPUTE node (Phase 1): keeps fold rules DECLARATIVE-SERIALIZABLE
;; (D.2 tier-1 — what 0.3 hands the LLVM collaborator). The op table is the
;; INTERPRETER'S whitelist (pure, total-or-#f); the rule carries only data.
;; A #f result (e.g. division by zero, type mismatch) aborts instantiation —
;; the rule simply does not fire for that match.
;; ABORT is a DISTINCT sentinel — #f is a legitimate computed VALUE (boolean
;; folds!); conflating them aborted correct false-valued folds (gate-caught at
;; first seed run, iter 20). Domain failures (div/0, type mismatch) return the
;; sentinel; the whole template aborts and the rule does not fire.
(define abort-instantiation (gensym 'abort))
(define (guarded-int2 f)
  (lambda (a b) (if (and (exact-integer? a) (exact-integer? b))
                    (f a b) abort-instantiation)))
(define compute-ops
  (hasheq '+ (guarded-int2 +) '- (guarded-int2 -) '* (guarded-int2 *)
          '/ (lambda (a b) (if (and (exact-integer? a) (exact-integer? b)
                                    (not (zero? b)))
                               (quotient a b) abort-instantiation))
          'mod (lambda (a b) (if (and (exact-integer? a) (exact-integer? b)
                                      (not (zero? b)))
                                 (remainder a b) abort-instantiation))
          '< (guarded-int2 <) '<= (guarded-int2 <=)
          '> (guarded-int2 >) '>= (guarded-int2 >=) '= (guarded-int2 =)
          'and (lambda (a b) (if (and (boolean? a) (boolean? b))
                                 (and a b) abort-instantiation))
          'or  (lambda (a b) (if (and (boolean? a) (boolean? b))
                                 (or a b) abort-instantiation))
          'not (lambda (a) (if (boolean? a) (not a) abort-instantiation))
          'add1 (lambda (a) (if (exact-integer? a) (add1 a) abort-instantiation))
          'sub1 (lambda (a) (if (and (exact-integer? a) (>= a 1))
                                (sub1 a) abort-instantiation))))

(define (instantiate-template rhs env)
  (let/ec return
    (let walk ([p rhs])
      (cond
        [(and (pair? p) (eq? (car p) 'ref)) (hash-ref env (cadr p))]
        [(and (pair? p) (eq? (car p) 'compute))
         (define op (hash-ref compute-ops (cadr p) #f))
         (unless op (return #f))
         (define args (map walk (cddr p)))
         (define result
           (with-handlers ([exn:fail? (lambda (_e) abort-instantiation)])
             (apply op args)))
         (if (eq? result abort-instantiation) (return #f) result)]
        [(pair? p) (map walk p)]
        [else p]))))

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
           (cond
             [(not result-form) (values net #f)]  ;; compute aborted (e.g. div/0)
             [else
              (define-values (net1 result-cid _dig)
                (eclass-intern net reg-cid result-form #:cost cost))
              (define net2 (run-to-quiescence (eclass-union net1 class-cid result-cid)))
              (values net2 #t)])])])]))

;; --- dispatch (design §4/§5: rules-for-tag → apply-rule per matched rule) ---
;; Direct-invocation realization (lazy ingestion; the elaboration call-site is
;; its own unit). → (values net' fired-count)
(define (dispatch-rules net hashcons-cid registry-cid class-cid
                        #:class-of [class-of (lambda (s) #f)]
                        #:result-cost [result-cost 1])
  (define v (net-cell-read net class-cid))
  (define best (and (hash? v) (hash-ref v ':best #f)))
  (define form (and best (cdr best)))
  (define head (and (pair? form) (symbol? (car form)) (car form)))
  (cond
    [(not head) (values net 0)]
    [else
     (define rids (rules-for-tag net registry-cid head))
     (for/fold ([n net] [fired 0]) ([rid (in-set rids)])
       (define rule (registry-rule-by-id n registry-cid rid))
       (cond
         [(not rule) (values n fired)]
         [else
          (define-values (n2 fired?)
            (apply-rule n hashcons-cid rule class-cid
                        #:class-of class-of #:cost result-cost))
          (values n2 (if fired? (add1 fired) fired))]))]))

;; --- Phase 2 (PReduce Track 8): dispatch as a STRATUM FIRING ----------------
;; "Rule application IS propagator firing." Instead of preduce-ingest-int calling
;; dispatch-rules imperatively, it installs an S0 emitter on the redex class that
;; writes dispatch-request-cell-id; run-to-quiescence then fires THIS handler
;; between rounds (topology tier — apply-rule installs union propagators, a
;; structural change). Mirrors the congruence engine (eclass-graph.rkt
;; process-congruence-requests + cell-21).
;;
;; The handler reads the registry + hashcons cell-ids from their parameters
;; (set by the driver / test before whnf, valid in run-to-quiescence's dynamic
;; extent), and runs the existing dispatch-rules on each pending class.
;;
;; Re-entrancy: apply-rule drives its OWN run-to-quiescence (to land the union).
;; That nested quiescence would re-see the SAME pending requests (the framework's
;; post-handler reset has not run yet), re-dispatching ad infinitum. So we CLEAR
;; the request cell on the working net at entry (the stratification.md "fork-based
;; handlers must clear the request cell" idiom) before any apply-rule runs.
(define (process-dispatch-requests net pending)
  (define net0 (net-cell-reset net dispatch-request-cell-id (hash)))
  (define hc (current-eclass-hashcons-cell-id))
  (define reg (current-rule-registry-cell-id))
  (cond
    [(and hc reg (hash? pending))
     (for/fold ([n net0]) ([(cid _v) (in-hash pending)])
       (define-values (n2 _fired)
         (dispatch-rules n hc reg cid #:result-cost 1))
       n2)]
    [else net0]))

(register-stratum-handler! dispatch-request-cell-id
                           process-dispatch-requests
                           #:tier 'topology
                           #:reset-value (hash))

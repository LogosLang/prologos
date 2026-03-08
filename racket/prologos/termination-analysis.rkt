#lang racket/base

;;;
;;; TERMINATION ANALYSIS
;;; Phase 2b of FL Narrowing: size-based termination analysis using the
;;; Lee-Jones-Ben-Amram (LJBA) size-change criterion.
;;;
;;; Analyzes recursive functions to classify them as:
;;;   - 'terminating: all recursive calls decrease some argument (LJBA satisfied)
;;;   - 'bounded: recursion doesn't provably terminate but is non-increasing
;;;     on some argument (use fuel-bounded search)
;;;   - 'non-narrowable: no structural decrease detected (reject for narrowing)
;;;
;;; The analysis works on definitional tree rule RHS expressions:
;;;   1. Extract recursive calls (applications of the same function)
;;;   2. Build size-change matrices comparing call args to formal params
;;;   3. Apply LJBA: check that every idempotent matrix in the transitive
;;;      closure has a decreasing diagonal entry
;;;
;;; DEPENDENCIES: definitional-tree.rkt, syntax.rkt
;;;

(require racket/match
         racket/list
         "definitional-tree.rkt"
         "macros.rkt"
         "syntax.rkt")

(provide
 ;; Structs
 (struct-out size-change-entry)
 (struct-out size-change-matrix)
 (struct-out termination-result)
 ;; Core analysis
 analyze-termination
 ;; Helpers (exported for testing)
 extract-recursive-calls
 build-size-change-matrix
 ljba-check
 classify-arg-change
 scm-multiply
 scm-transitive-closure
 ;; Registry
 current-termination-registry
 lookup-termination
 register-termination!)

;; ========================================
;; Structs
;; ========================================

;; A single entry in a size-change matrix.
;; change: 'decreasing | 'non-increasing | 'increasing | 'unknown
(struct size-change-entry (from-arg to-arg change) #:transparent)

;; A size-change matrix for one recursive call.
;; arity: number of arguments
;; entries: vector of vectors — entries[i][j] = change from param i to call arg j
;;   Interpretation: how does call arg j relate to formal param i?
;;   'decreasing means call-arg-j is structurally smaller than param-i
(struct size-change-matrix (arity entries) #:transparent)

;; Result of termination analysis.
;; class: 'terminating | 'bounded | 'non-narrowable
;; fuel-bound: #f for terminating/non-narrowable, or a natural for bounded
;; matrices: list of size-change matrices (one per recursive call)
(struct termination-result (class fuel-bound matrices) #:transparent)

;; ========================================
;; Registry (caches results per function)
;; ========================================

(define current-termination-registry (make-parameter (hasheq)))

(define (register-termination! name result)
  (current-termination-registry
   (hash-set (current-termination-registry) name result)))

(define (lookup-termination name)
  (hash-ref (current-termination-registry) name #f))

;; ========================================
;; Core analysis
;; ========================================

;; analyze-termination : symbol × tree × nat → termination-result
;; Analyze a function's definitional tree for termination.
;; func-name: the function's name (for identifying recursive calls)
;; tree: the definitional tree (from extract-definitional-tree)
;; arity: number of arguments
(define (analyze-termination func-name tree arity)
  (cond
    [(not tree)
     (termination-result 'non-narrowable #f '())]
    [else
     ;; Extract all recursive calls from the tree
     (define calls (extract-recursive-calls func-name tree arity))
     (cond
       ;; No recursive calls → trivially terminating
       [(null? calls)
        (termination-result 'terminating #f '())]
       [else
        ;; Build size-change matrices
        (define matrices
          (for/list ([call (in-list calls)])
            (build-size-change-matrix call arity)))
        ;; Apply LJBA criterion
        (cond
          [(ljba-check matrices arity)
           (termination-result 'terminating #f matrices)]
          ;; Check if any argument is at least non-increasing in ALL calls
          [(has-non-increasing-arg? matrices arity)
           (define bound (estimate-fuel-bound matrices arity))
           (termination-result 'bounded bound matrices)]
          [else
           (termination-result 'non-narrowable #f matrices)])])]))

;; ========================================
;; Recursive call extraction
;; ========================================

;; A recursive call: the list of argument expressions.
;; call-args: (listof expr) — the arguments passed to the recursive call
;; binding-depth: number of binders enclosing this call (for bvar adjustment)
;; matched-info: (listof (cons param-pos num-fields)), outermost DT branch first
;;   Records which param positions were destructed and how many sub-field
;;   bindings each introduced. Used to determine if a bvar is a sub-field
;;   of a specific formal parameter.
(struct rec-call (call-args binding-depth matched-info) #:transparent)

;; extract-recursive-calls : symbol × tree × nat → (listof rec-call)
;; Walk the definitional tree and collect all recursive calls in rule RHS.
;; Tracks which params are destructed (matched-info) for sub-field detection.
(define (extract-recursive-calls func-name tree arity)
  (extract-recursive-calls* func-name tree arity 0 '()))

;; Internal: accumulate depth and matched-info through DT traversal.
;; matched-info: (listof (cons param-pos num-fields)), outermost first
(define (extract-recursive-calls* func-name tree arity depth matched-info)
  (match tree
    [(dt-rule rhs)
     (extract-calls-from-expr func-name rhs arity depth matched-info)]
    [(dt-branch pos _ children)
     (append-map
      (lambda (child-pair)
        (define child-tree (cdr child-pair))
        (define ctor-meta (lookup-ctor-flexible (car child-pair)))
        (define extra-bindings
          (if ctor-meta (length (ctor-meta-field-types ctor-meta)) 0))
        (extract-recursive-calls*
         func-name child-tree arity
         (+ depth extra-bindings)
         (append matched-info (list (cons pos extra-bindings)))))
      children)]
    [(dt-or branches)
     (append-map
      (lambda (b)
        (extract-recursive-calls* func-name b arity depth matched-info))
      branches)]
    [(dt-exempt) '()]))

;; extract-calls-from-expr : symbol × expr × nat × nat × matched-info → (listof rec-call)
;; Find applications of func-name in expr.
(define (extract-calls-from-expr func-name expr arity depth matched-info)
  (define (walk e depth)
    (match e
      ;; Application chain: check if it's a call to func-name
      [(expr-app _ _)
       (define-values (fn args) (unwrap-app-chain e))
       (define self-call?
         (and (expr-fvar? fn)
              (let ([name (expr-fvar-name fn)])
                (or (eq? name func-name)
                    (eq? (ctor-short-name name) (ctor-short-name func-name))))))
       (cond
         [self-call?
          ;; Found a recursive call
          (define call (rec-call args depth matched-info))
          ;; Also check args for nested recursive calls
          (define nested (append-map (lambda (a) (walk a depth)) args))
          (cons call nested)]
         [else
          ;; Not a self-call, but check sub-expressions
          (append-map (lambda (a) (walk a depth)) args)])]
      [(expr-lam _ _ body)
       (walk body (+ depth 1))]
      [(expr-reduce scrut arms _)
       (define scrut-calls (walk scrut depth))
       (define arm-calls
         (append-map
          (lambda (arm)
            (walk (expr-reduce-arm-body arm)
                  (+ depth (expr-reduce-arm-binding-count arm))))
          arms))
       (append scrut-calls arm-calls)]
      [(expr-suc sub) (walk sub depth)]
      [(expr-pair a b) (append (walk a depth) (walk b depth))]
      [_ '()]))
  (walk expr depth))

;; unwrap-app-chain : expr → (values expr (listof expr))
;; Flatten (app (app (fvar f) a1) a2) → (values (fvar f) (list a1 a2))
(define (unwrap-app-chain e)
  (let loop ([e e] [args '()])
    (match e
      [(expr-app f a) (loop f (cons a args))]
      [_ (values e args)])))

;; ========================================
;; Size-change matrix construction
;; ========================================

;; build-size-change-matrix : rec-call × nat → size-change-matrix
;; Compare each call argument against each formal parameter.
;; Formal params are bvar references: param i = bvar(arity - 1 - i) at depth 0.
(define (build-size-change-matrix call arity)
  (define args (rec-call-call-args call))
  (define depth (rec-call-binding-depth call))
  (define minfo (rec-call-matched-info call))
  (define n (min arity (length args)))
  ;; entries[i][j] = how call-arg j relates to formal param i
  (define entries
    (for/vector ([i (in-range arity)])
      (define param-bvar-idx (+ (- arity 1 i) depth))
      (for/vector ([j (in-range n)])
        (classify-arg-change (list-ref args j) param-bvar-idx depth i minfo))))
  (size-change-matrix arity entries))

;; bvar-is-sub-field-of? : nat × nat × (listof (cons param-pos num-fields)) → boolean
;; Check if bvar at index `idx` is a sub-field of the formal parameter at
;; position `param-pos`, given the matched-info from DT traversal.
;; matched-info is ordered outermost-first; bvar layout is innermost-first.
(define (bvar-is-sub-field-of? idx param-pos matched-info)
  ;; Compute bvar ranges from innermost to outermost.
  ;; The most recent (innermost) match's sub-fields are at the lowest bvar indices.
  (let loop ([info (reverse matched-info)] [lo 0])
    (cond
      [(null? info) #f]
      [else
       (define pos (car (car info)))
       (define k (cdr (car info)))
       (define hi (+ lo k))
       (if (and (= pos param-pos) (>= idx lo) (< idx hi))
           #t
           (loop (cdr info) hi))])))

;; classify-arg-change : expr × nat × nat × nat × matched-info → symbol
;; Compare a call argument expression against a formal parameter.
;; param-bvar-idx: the de Bruijn index of the formal param
;; depth: total binding depth from DT branches
;; param-pos: the 0-based argument position of the formal param
;; matched-info: which params were destructed (for sub-field detection)
;; Returns 'decreasing, 'non-increasing, 'increasing, or 'unknown.
(define (classify-arg-change arg-expr param-bvar-idx depth
                             [param-pos #f] [matched-info '()])
  (match arg-expr
    ;; A bvar reference: check relationship to param
    [(expr-bvar idx)
     (cond
       ;; Same bvar as param → non-increasing (unchanged)
       [(= idx param-bvar-idx) 'non-increasing]
       ;; Sub-field of this param (introduced by pattern matching on this param)
       [(and (< idx depth)
             param-pos
             (bvar-is-sub-field-of? idx param-pos matched-info))
        'decreasing]
       [else 'unknown])]

    ;; Successor wrapping the param → increasing
    [(expr-suc sub)
     (cond
       [(and (expr-bvar? sub) (= (expr-bvar-index sub) param-bvar-idx))
        'increasing]
       [else 'unknown])]

    ;; Ground values (zero, true, false, etc.) → unknown relative to param
    [(expr-zero) 'unknown]
    [(expr-true) 'unknown]
    [(expr-false) 'unknown]
    [(expr-nat-val _) 'unknown]
    [(expr-int _) 'unknown]

    ;; Anything else → unknown
    [_ 'unknown]))

;; ========================================
;; LJBA criterion
;; ========================================

;; Size-change values form a partial order:
;;   'decreasing < 'non-increasing < 'unknown
;;   'increasing is treated as 'unknown for LJBA purposes

;; Compose two size-change values (for matrix multiplication).
;; If a changes to b with relation r1, and b changes to c with relation r2,
;; then a changes to c with compose(r1, r2).
(define (sc-compose r1 r2)
  (cond
    [(or (eq? r1 'unknown) (eq? r2 'unknown)) 'unknown]
    [(or (eq? r1 'increasing) (eq? r2 'increasing)) 'unknown]
    ;; Both are decreasing or non-increasing
    [(or (eq? r1 'decreasing) (eq? r2 'decreasing)) 'decreasing]
    [else 'non-increasing]))

;; Meet (join in the lattice): take the "better" (more decreasing) value.
;; Used when combining paths in the transitive closure.
(define (sc-meet r1 r2)
  (cond
    [(or (eq? r1 'decreasing) (eq? r2 'decreasing)) 'decreasing]
    [(or (eq? r1 'non-increasing) (eq? r2 'non-increasing)) 'non-increasing]
    [else 'unknown]))

;; scm-multiply : scm × scm → scm
;; Matrix multiplication for size-change matrices.
(define (scm-multiply m1 m2)
  (define n (size-change-matrix-arity m1))
  (define e1 (size-change-matrix-entries m1))
  (define e2 (size-change-matrix-entries m2))
  (define result
    (for/vector ([i (in-range n)])
      (for/vector ([j (in-range n)])
        ;; entry[i][j] = meet over k of compose(e1[i][k], e2[k][j])
        (for/fold ([best 'unknown])
                  ([k (in-range n)])
          (define composed (sc-compose (vector-ref (vector-ref e1 i) k)
                                       (vector-ref (vector-ref e2 k) j)))
          (sc-meet best composed)))))
  (size-change-matrix n result))

;; scm-equal? : scm × scm → boolean
(define (scm-equal? m1 m2)
  (define n (size-change-matrix-arity m1))
  (and (= n (size-change-matrix-arity m2))
       (for/and ([i (in-range n)])
         (for/and ([j (in-range n)])
           (eq? (vector-ref (vector-ref (size-change-matrix-entries m1) i) j)
                (vector-ref (vector-ref (size-change-matrix-entries m2) i) j))))))

;; scm-has-decreasing-diagonal? : scm → boolean
;; Check if at least one diagonal entry is 'decreasing.
(define (scm-has-decreasing-diagonal? m)
  (define n (size-change-matrix-arity m))
  (define entries (size-change-matrix-entries m))
  (for/or ([i (in-range n)])
    (eq? (vector-ref (vector-ref entries i) i) 'decreasing)))

;; scm-is-idempotent? : scm → boolean
;; A matrix M is idempotent if M * M = M.
(define (scm-is-idempotent? m)
  (scm-equal? (scm-multiply m m) m))

;; scm-transitive-closure : (listof scm) → (listof scm)
;; Compute the transitive closure of a set of size-change matrices.
;; Repeatedly multiply all pairs until no new matrices appear.
(define (scm-transitive-closure matrices)
  (let loop ([current matrices])
    (define new-matrices
      (for*/fold ([acc current])
                 ([m1 (in-list current)]
                  [m2 (in-list current)])
        (define product (scm-multiply m1 m2))
        (if (for/or ([existing (in-list acc)])
              (scm-equal? existing product))
            acc
            (cons product acc))))
    (if (= (length new-matrices) (length current))
        current
        (loop new-matrices))))

;; ljba-check : (listof scm) × nat → boolean
;; Lee-Jones-Ben-Amram size-change termination criterion.
;; Returns #t if the function definitely terminates.
;; Algorithm: compute transitive closure, check that every idempotent
;; matrix has at least one decreasing diagonal entry.
(define (ljba-check matrices arity)
  (cond
    [(null? matrices) #t]
    [else
     (define closure (scm-transitive-closure matrices))
     (define idempotents (filter scm-is-idempotent? closure))
     (cond
       ;; No idempotent matrices found — can happen with small closure
       ;; Conservatively check: every matrix has a decreasing column
       [(null? idempotents)
        (for/and ([m (in-list closure)])
          (scm-has-decreasing-diagonal? m))]
       ;; Check all idempotent matrices
       [else
        (for/and ([m (in-list idempotents)])
          (scm-has-decreasing-diagonal? m))])]))

;; ========================================
;; Bounded analysis helpers
;; ========================================

;; has-non-increasing-arg? : (listof scm) × nat → boolean
;; Check if any argument column is at least non-increasing in ALL matrices.
(define (has-non-increasing-arg? matrices arity)
  (for/or ([j (in-range arity)])
    (for/and ([m (in-list matrices)])
      (define entries (size-change-matrix-entries m))
      ;; Column j: check the diagonal entry [j][j]
      (define change (vector-ref (vector-ref entries j) j))
      (or (eq? change 'decreasing)
          (eq? change 'non-increasing)))))

;; estimate-fuel-bound : (listof scm) × nat → nat
;; Estimate a reasonable fuel bound for bounded functions.
;; Default: NARROW-DEPTH-LIMIT from narrowing.rkt.
;; If interval domain is available (Phase 2a), this can be refined dynamically.
(define (estimate-fuel-bound matrices arity)
  ;; For now, use the existing depth limit as fuel
  ;; Phase 2a will refine this with interval-based bounds
  50)

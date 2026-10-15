#lang racket/base
;;; benchmarks/par4/o3-observer-fixtures.rkt — PAR 4 O-3 evidence (D.1 Appendix A, re-posed 2026-10-14).
;;;
;;; Five small Racket-level networks, run under the PRODUCTION schedulers with the PRODUCTION observer
;;; (current-bsp-observer):
;;;   bsp     run-to-quiescence-bsp (Jacobi rounds)
;;;   gs-fwd  the sequential Gauss–Seidel scheduler, propagators installed in spec order
;;;   gs-rev  the same, installed in reverse order (the drain follows the worklist, so this varies the schedule)
;;; For each run, the observation each candidate observer contract would report:
;;;   L1  rounds          number of records the observer received
;;;   L0  write events     diff records (BSP: one per write; Gauss–Seidel: one per changed cell, initial→final)
;;;   L2  epoch summary    final values, the set of changed cells, the SET of propagators fired, fire count
;;;   ATTR                 the source-propagator the production observer names for each changed cell
;;;   SHOWN≠HELD           BSP diff records whose new-value is not the value the cell holds after that round
;;;                        (the editor's round scrubber displays new-value as the cell's value)
;;;   FIX-EQ               the fixpoint-equation contributions f_p(x*)_c for every (p, c), computed from the final
;;;                        state alone — a function of x*, so schedule-independent whenever x* is.
;;; Fixture X4 breaks the theorem's hypothesis on purpose (a replacement merge with two writers).
;;;
;;;   racket benchmarks/par4/o3-observer-fixtures.rkt        (prints one block per fixture)
(require racket/list racket/string "../../propagator.rkt")

(define (max-merge a b) (max a b))
(define (set-merge a b) (sort (remove-duplicates (append a b)) <))
(define (replace-merge a b) b)                        ; NOT a join: last write wins
(define (flat-merge a b)
  (cond [(eq? a 'bot) b] [(eq? b 'bot) a] [(equal? a b) a] [else 'top]))

;; spec: cells = (listof (cons init merge)); props = (listof (list ins outs f)); seeds = (listof (cons i v))
(define (build cells props seeds order)
  (define-values (net cids)
    (for/fold ([net (make-prop-network)] [cids '()]) ([cs cells])
      (define-values (n c) (net-new-cell net (car cs) (cdr cs)))
      (values n (cons c cids))))
  (define cv (list->vector (reverse cids)))
  (define pid->idx (make-hash))
  (define net*
    (for/fold ([net net]) ([i order])
      (define ps (list-ref props i))
      (define ins (map (λ (k) (vector-ref cv k)) (car ps)))
      (define outs (map (λ (k) (vector-ref cv k)) (cadr ps)))
      (define f (caddr ps))
      (define-values (n pid)
        (net-add-propagator net ins outs
          (λ (net) (define v (f (map (λ (c) (net-cell-read net c)) ins)))
                   (for/fold ([net net]) ([o outs]) (net-cell-write net o v)))))
      (hash-set! pid->idx (prop-id-n pid) i)
      n))
  (values (for/fold ([net net*]) ([s seeds]) (net-cell-write net (vector-ref cv (car s)) (cdr s)))
          cv pid->idx))

(define (cell-idx cv cid) (for/first ([c cv] [i (in-naturals)] #:when (equal? c cid)) i))

(define (run-one cells props seeds sched)
  (define order (if (eq? sched 'gs-rev) (reverse (range (length props))) (range (length props))))
  (define-values (net cv pid->idx) (build cells props seeds order))
  (define recs '())
  (define final
    (parameterize ([current-use-bsp-scheduler? (eq? sched 'bsp)]
                   [current-bsp-observer (λ (r) (set! recs (cons r recs)))])
      (run-to-quiescence net)))
  (define rs (reverse recs))
  (define xs (for/list ([c cv]) (net-cell-read final c)))
  (define x0 (for/list ([c cv]) (net-cell-read net c)))
  (define changed (for/list ([a x0] [b xs] [i (in-naturals)] #:unless (equal? a b)) i))
  (define fired-list (append* (map bsp-round-propagators-fired rs)))
  (define fired-set (sort (remove-duplicates (map (λ (p) (hash-ref pid->idx (prop-id-n p))) fired-list)) <))
  (define diffs (append* (map bsp-round-cell-diffs rs)))
  ;; production attribution: the source-propagator of the LAST diff record naming the cell
  (define attr
    (for/list ([i changed])
      (define last-d (for/last ([d diffs] #:when (equal? (cell-idx cv (cell-diff-cell-id d)) i)) d))
      (cons i (and last-d (hash-ref pid->idx (prop-id-n (cell-diff-source-propagator last-d)) #f)))))
  (define shown-not-held
    (for*/sum ([r rs] [d (bsp-round-cell-diffs r)])
      (if (equal? (cell-diff-new-value d)
                  (net-cell-read (bsp-round-network-snapshot r) (cell-diff-cell-id d))) 0 1)))
  ;; fixpoint-equation contributions: f_p(x*) for every propagator, from the final values alone
  (define fixeq
    (for/list ([ps props] [pi (in-naturals)])
      (list pi (cadr ps) ((caddr ps) (map (λ (k) (list-ref xs k)) (car ps))))))
  ;; depth: for each changed cell, the first record (1-based) after which the cell holds its final value —
  ;; under BSP the Kleene iterate at which it converged; under Gauss–Seidel always 1 (one record per run)
  (define depth
    (for/list ([i changed])
      (cons i (for/first ([r rs] [k (in-naturals 1)]
                          #:when (equal? (net-cell-read (bsp-round-network-snapshot r) (vector-ref cv i))
                                         (list-ref xs i)))
                k))))
  ;; detail: per record k (1-based), per written cell: old value, value HELD after the round, and the writers
  (define detail
    (for/list ([r rs] [k (in-naturals 1)])
      (define by-cell (make-hash))
      (for ([d (bsp-round-cell-diffs r)])
        (define i (cell-idx cv (cell-diff-cell-id d)))
        (when i (hash-update! by-cell i (λ (ws) (cons (hash-ref pid->idx (prop-id-n (cell-diff-source-propagator d))) ws)) '())))
      (cons k (for/list ([i (sort (hash-keys by-cell) <)])
                (list i (net-cell-read (bsp-round-network-snapshot r) (vector-ref cv i))
                      (sort (remove-duplicates (hash-ref by-cell i)) <))))))
  (hasheq 'detail detail 'x0 x0 'depth depth 'rounds (length rs) 'writes (length diffs) 'final xs 'changed changed
          'fired-set fired-set 'fires (length fired-list) 'attr attr 'shown-not-held shown-not-held
          'fixeq fixeq))

(define CAP 6)
;; Propagators are numbered by their position in the fixture's spec (p0, p1, …); cells likewise (c0, c1, …).
(define fixtures
  (list
   ;; X1 chain: c0 → c1 → c2, +1 each, max lattice capped at CAP
   (list "X1 chain (max)"
         (list (cons 0 max-merge) (cons 0 max-merge) (cons 0 max-merge))
         (list (list '(0) '(1) (λ (v) (min CAP (add1 (car v)))))
               (list '(1) '(2) (λ (v) (min CAP (add1 (car v))))))
         (list (cons 0 1)))
   ;; X2 diamond fan-in: two writers of c3 in the same round (set union)
   (list "X2 fan-in (set ∪)"
         (list (cons '() set-merge) (cons '() set-merge) (cons '() set-merge) (cons '() set-merge))
         (list (list '(0) '(1) (λ (v) (map (λ (x) (+ x 10)) (car v))))
               (list '(0) '(2) (λ (v) (map (λ (x) (+ x 20)) (car v))))
               (list '(1) '(3) (λ (v) (car v)))
               (list '(2) '(3) (λ (v) (car v))))
         (list (cons 0 '(1))))
   ;; X3 cycle: reachability on 0→1→2→0, 2→3 (set union; finite height)
   (list "X3 cycle (set ∪)"
         (list (cons '() set-merge) (cons '() set-merge) (cons '() set-merge) (cons '() set-merge))
         (list (list '(0) '(1) (λ (v) (set-merge (car v) '(1))))
               (list '(1) '(2) (λ (v) (set-merge (car v) '(2))))
               (list '(2) '(0) (λ (v) (set-merge (car v) '(0))))
               (list '(2) '(3) (λ (v) (set-merge (car v) '(3)))))
         (list (cons 0 '(0))))
   ;; X4 hypothesis broken: two writers of a REPLACEMENT cell (not a join)
   (list "X4 non-join (replace)"
         (list (cons 0 max-merge) (cons 'none replace-merge))
         (list (list '(0) '(1) (λ (v) (list 'a (car v))))
               (list '(0) '(1) (λ (v) (list 'b (car v)))))
         (list (cons 0 1)))
   ;; X5 flat lattice conflict: two writers disagree → top
   (list "X5 flat conflict"
         (list (cons 'bot flat-merge) (cons 'bot flat-merge) (cons 'bot flat-merge))
         (list (list '(0) '(1) (λ (v) (car v)))
               (list '(0) '(2) (λ (v) (if (eq? (car v) 'bot) 'bot 7)))
               (list '(1) '(2) (λ (v) (car v))))
         (list (cons 0 3)))))

(for ([fx fixtures])
  (define-values (name cells props seeds) (apply values fx))
  (printf "== ~a\n" name)
  (define results (for/list ([s '(bsp gs-fwd gs-rev)]) (cons s (run-one cells props seeds s))))
  (for ([sr results])
    (define r (cdr sr))
    (printf "  ~a: rounds ~a  writes ~a  fires ~a  fired-set ~a  changed ~a  shown≠held ~a\n"
            (car sr) (hash-ref r 'rounds) (hash-ref r 'writes) (hash-ref r 'fires) (hash-ref r 'fired-set)
            (hash-ref r 'changed) (hash-ref r 'shown-not-held))
    (printf "        final ~s\n        attr ~s\n        depth ~s\n" (hash-ref r 'final) (hash-ref r 'attr) (hash-ref r 'depth)))
  (define (same k) (let ([vs (map (λ (sr) (hash-ref (cdr sr) k)) results)])
                     (if (andmap (λ (v) (equal? v (car vs))) vs) "same" "DIFFER")))
  (printf "  across schedules: final ~a · changed ~a · fired-set ~a · fires ~a · rounds ~a · writes ~a · attr ~a · fix-eq ~a\n"
          (same 'final) (same 'changed) (same 'fired-set) (same 'fires) (same 'rounds) (same 'writes)
          (same 'attr) (same 'fixeq))
  (printf "  fix-eq (bsp's x*): ~s\n" (hash-ref (cdr (car results)) 'fixeq))
  (define bsp (cdr (car results)))
  (define detail (hash-ref bsp 'detail))
  (printf "  BSP rounds as (cell held-after-round writers):\n")
  (for ([kd detail]) (printf "    r~a ~s\n" (car kd) (cdr kd)))
  ;; derivation in logical time: cell i's value after round k came from writers w in round k, each reading its
  ;; inputs as they stood after round k-1 — i.e. at the latest round m <= k-1 that changed them (or x0).
  ;; The cell's own value after round m < k is a premise too (x_k = x_(k-1) ⊔ writes): without it a join that
  ;; goes to top names only the last writer (X5). m < k strictly in both edges, so the unfolding is well-founded
  ;; even on a cycle (X3), with no visited set or depth bound.
  (define (last-change i before)
    (for/last ([kd detail] #:when (and (< (car kd) before) (assoc i (cdr kd)))) (car kd)))
  (define (derive i k indent)
    (define entry (and k (assoc i (cdr (assoc k detail)))))
    (cond
      [(not entry) (printf "~ac~a = ~s (initial)\n" indent i (list-ref (hash-ref bsp 'x0) i))]
      [else
       (printf "~ac~a@r~a = ~s  <- ~a\n" indent i k (cadr entry)
               (string-join (map (λ (w) (format "p~a" w)) (caddr entry)) " ⊔ "))
       (define prior (last-change i k))
       (define init (list-ref (hash-ref bsp 'x0) i))
       (cond [prior (printf "~a  ⊔ own prior value:\n" indent)
                    (derive i prior (string-append indent "    "))]
             [(not (member init '(() 0 bot none)))      ; x0_c is a premise unless it is the fixture's bottom
              (printf "~a  ⊔ own initial value ~s\n" indent init)])
       (for ([w (caddr entry)])
         (for ([in (car (list-ref props w))])
           (derive in (last-change in k) (string-append indent "    "))))]))
  (for ([i (hash-ref bsp 'changed)])
    (printf "  derivation of c~a's final value:\n" i)
    (derive i (last-change i +inf.0) "    ")))

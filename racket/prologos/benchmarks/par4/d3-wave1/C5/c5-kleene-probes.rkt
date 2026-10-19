#lang racket/base
;; C5 (D.3 Theory critic) — probes of D.2 §5 / D.1 A.8 item 2 ("BSP's rounds are the Kleene iterates"),
;; §6.6 (Tier-1 flush "already DIRECT"), §6.3/§10.2 S-5/S-9 (fenced sub-run determinism), §8/S-6 (fuel).
;; Read-only on the repo: requires the worktree's compiled propagator.rkt by absolute path.
;; Schedulers: BSP = (current-use-bsp-scheduler? #t) → run-to-quiescence-bsp :3401;
;;             SEQ = (current-use-bsp-scheduler? #f) → run-to-quiescence-drain :2731 (Gauss–Seidel stand-in for DIRECT K=1).
(require (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt"))

(define (run net bsp?)
  (parameterize ([current-use-bsp-scheduler? bsp?]) (run-to-quiescence net)))
(define (sched b) (if b "BSP" "SEQ"))
(define maxm (λ (a b) (max a b)))

;; ---------------------------------------------------------------------------------------------
;; T1 — Tier-1 flush (propagator.rkt:3412-3445) clears the WHOLE worklist after firing, including the
;; dependents that its own fires' net-cell-writes enqueued. Network: a → q → b (copy, max merge).
;; Quiesce; then add a fire-once EMPTY-INPUT propagator p writing a := 5 (the relations.rkt:2699 shape),
;; and quiesce again. Least fixpoint: b = 5.
(define (t1 bsp? q-after?)
  (define n0 (make-prop-network 100000))
  (define-values (n1 a) (net-new-cell n0 0 maxm))
  (define-values (n2 b) (net-new-cell n1 0 maxm))
  (define (add-q n) (let-values ([(n* _) (net-add-propagator n (list a) (list b)
                                                               (λ (n) (net-cell-write n b (net-cell-read n a))))]) n*))
  (define (add-p n) (let-values ([(n* _) (net-add-fire-once-propagator n '() (list a)
                                                                        (λ (n) (net-cell-write n a 5)))]) n*))
  (define n3 (if q-after? n2 (run (add-q n2) bsp?)))       ; q installed and quiesced first
  (define n4 (add-p n3))
  (define n5 (if q-after? (add-q n4) n4))                  ; control: q installed after p → worklist has q
  (define r (run n5 bsp?))
  (list (net-cell-read r a) (net-cell-read r b) (length (prop-network-worklist r))))
(printf "== T1 Tier-1 flush: lfp is a=5 b=5\n")
(for ([bsp? '(#t #f)])
  (for ([q-after? '(#f #t)])
    (define v (t1 bsp? q-after?))
    (printf "  ~a  ~a  a=~a b=~a worklist-left=~a  ~a\n" (sched bsp?)
            (if q-after? "control (q installed after p: Tier 2)" "q quiesced before p   (Tier 1 eligible)")
            (car v) (cadr v) (caddr v)
            (if (= (cadr v) 5) "fixpoint" "NOT A FIXPOINT (dependent q dropped)"))))

;; ---------------------------------------------------------------------------------------------
;; K-FO — fire-once on an UNSTABLE latch: self-clear (propagator.rkt:3522-3543) removes p from its
;; inputs' dependents after its first productive fire; the Kleene operator F still contains f_p.
(define (kfo bsp?)
  (define n0 (make-prop-network 100000))
  (define-values (n1 a) (net-new-cell n0 0 maxm))
  (define-values (n2 b) (net-new-cell n1 0 maxm))
  (define-values (n3 _p) (net-add-fire-once-propagator n2 (list a) (list b)
                                                        (λ (n) (let ([v (net-cell-read n a)])
                                                                 (if (zero? v) n (net-cell-write n b v))))))
  (define r1 (run (net-cell-write (run n3 bsp?) a 1) bsp?))
  (define r2 (run (net-cell-write r1 a 2) bsp?))
  (net-cell-read r2 b))
(printf "== K-FO fire-once on an unstable latch (b := a, a goes 1 then 2): Kleene/lfp b=2\n")
(for ([bsp? '(#t #f)]) (printf "  ~a  b=~a\n" (sched bsp?) (kfo bsp?)))

;; ---------------------------------------------------------------------------------------------
;; K-UR — an UNDECLARED READ: p's declared input is s, but it also reads u. A later write to u does
;; not enqueue p, so the scheduler's result is not lfp(x0 ⊔ F) (lfp: o = 5).
(define (kur bsp?)
  (define n0 (make-prop-network 100000))
  (define-values (n1 s) (net-new-cell n0 0 maxm))
  (define-values (n2 u) (net-new-cell n1 0 maxm))
  (define-values (n3 o) (net-new-cell n2 0 maxm))
  (define-values (n4 _p) (net-add-propagator n3 (list s) (list o)
                                             (λ (n) (net-cell-write n o (max (net-cell-read n s) (net-cell-read n u))))))
  (define r1 (run (net-cell-write (run n4 bsp?) s 1) bsp?))
  (net-cell-read (run (net-cell-write r1 u 5) bsp?) o))
(printf "== K-UR undeclared read (lfp o=5)\n")
(for ([bsp? '(#t #f)]) (printf "  ~a  o=~a\n" (sched bsp?) (kur bsp?)))

;; ---------------------------------------------------------------------------------------------
;; K-WL — a BSP run's result on a NON-JOIN (fenced) cell is a function of the worklist ORDER, not of
;; the worklist SET: two fenced writers q1 (t1 → f := 'a) and q2 (t2 → f := 'b), replacement merge.
;; The sources t1, t2 are written in two orders before ONE BSP run (both writes land before the run,
;; as the end of a DIRECT phase would leave them). Same set {q1,q2} queued; different order.
(define (kwl bsp? order)
  (define n0 (make-prop-network 100000))
  (define-values (n1 t1) (net-new-cell n0 0 maxm))
  (define-values (n2 t2) (net-new-cell n1 0 maxm))
  (define-values (n3 f) (net-new-cell n2 'none (λ (old new) new)))      ; replacement merge (non-join)
  (define-values (n4 _q1) (net-add-propagator n3 (list t1) (list f)
                                              (λ (n) (if (zero? (net-cell-read n t1)) n (net-cell-write n f 'a)))))
  (define-values (n5 _q2) (net-add-propagator n4 (list t2) (list f)
                                              (λ (n) (if (zero? (net-cell-read n t2)) n (net-cell-write n f 'b)))))
  (define base (run n5 bsp?))
  (define w (if (eq? order 't1-first)
                (net-cell-write (net-cell-write base t1 1) t2 1)
                (net-cell-write (net-cell-write base t2 1) t1 1)))
  (net-cell-read (run w bsp?) f))
(printf "== K-WL fenced sub-run: same queued SET {q1,q2}, two enqueue orders\n")
(for ([bsp? '(#t #f)])
  (printf "  ~a  t1-first: f=~a   t2-first: f=~a\n" (sched bsp?) (kwl bsp? 't1-first) (kwl bsp? 't2-first)))

;; ---------------------------------------------------------------------------------------------
;; A-ALT — K = 1 (no fence: fenced writers interleave with unfenced ones) vs the K > 1 alternation.
;; Cells: s (source, max), u (unfenced, max), f (fenced: replacement merge).
;;   q (fenced):   s → f := 'q          p (unfenced): s → u := 1          r (fenced): u → f := 'r
;; Install orders vary the K=1 schedule. The alternation is computed from D.2 §6.3's definition:
;; DIRECT phase fires only p (u := 1); the fenced sub-run then fires {q, r} in ONE BSP round against
;; the same snapshot, so f = the write applied last in that round — decided by the sub-run's order.
(define (aalt bsp? order)
  (define n0 (make-prop-network 100000))
  (define-values (n1 s) (net-new-cell n0 0 maxm))
  (define-values (n2 u) (net-new-cell n1 0 maxm))
  (define-values (n3 f) (net-new-cell n2 'none (λ (old new) new)))
  (define (q n) (let-values ([(n* _) (net-add-propagator n (list s) (list f)
                                         (λ (n) (if (zero? (net-cell-read n s)) n (net-cell-write n f 'q))))]) n*))
  (define (p n) (let-values ([(n* _) (net-add-propagator n (list s) (list u)
                                         (λ (n) (if (zero? (net-cell-read n s)) n (net-cell-write n u 1))))]) n*))
  (define (r n) (let-values ([(n* _) (net-add-propagator n (list u) (list f)
                                         (λ (n) (if (zero? (net-cell-read n u)) n (net-cell-write n f 'r))))]) n*))
  (define installed (for/fold ([n n3]) ([k (in-list order)]) ((case k [(q) q] [(p) p] [(r) r]) n)))
  (net-cell-read (run (net-cell-write (run installed bsp?) s 1) bsp?) f))
(printf "== A-ALT f under the K=1 schedules (no fence) — compare with the alternation's {q,r}-in-one-round\n")
(for ([order '((q p r) (p q r) (r p q) (r q p))])
  (printf "  install ~a   BSP f=~a   SEQ f=~a\n" order (aalt #t order) (aalt #f order)))

;; ---------------------------------------------------------------------------------------------
;; F-CH — change-counted fuel (O-2 / §6.6 / S-6): count STRICT CHANGES applied to the canonical network
;; for a 16-way fan-in into one max cell c (writers p_i: s → c := i). Changes inside a BSP fire's private
;; copy are excluded (counted only when current-bsp-fire-round? is #f). Σ height bound for c here = 16.
(define (fch bsp? reverse?)
  (define changes (box 0))
  (define counting-max (λ (o n) (define r (max o n))
                          (unless (or (current-bsp-fire-round?) (equal? r o)) (set-box! changes (add1 (unbox changes))))
                          r))
  (define n0 (make-prop-network 100000))
  (define-values (n1 s) (net-new-cell n0 0 maxm))
  (define-values (n2 c) (net-new-cell n1 0 counting-max))
  (define idx (if reverse? (for/list ([i (in-range 16 0 -1)]) i) (for/list ([i (in-range 1 17)]) i)))
  (define n3 (for/fold ([n n2]) ([i (in-list idx)])
               (let-values ([(n* _) (net-add-propagator n (list s) (list c)
                                       (λ (n) (if (zero? (net-cell-read n s)) n (net-cell-write n c i))))]) n*)))
  (define base (run n3 bsp?))
  (set-box! changes 0)
  (define r (run (net-cell-write base s 1) bsp?))
  (list (net-cell-read r c) (unbox changes)))
(printf "== F-CH changes to c for the same fixpoint (c=16), by schedule\n")
(for ([bsp? '(#t #f)])
  (for ([rev? '(#f #t)])
    (define v (fch bsp? rev?))
    (printf "  ~a install ~a  c=~a  changes=~a\n" (sched bsp?) (if rev? "16..1" "1..16") (car v) (cadr v))))

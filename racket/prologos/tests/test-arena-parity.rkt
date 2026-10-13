#lang racket/base
;;; test-arena-parity.rkt — PAR 4 parity skeleton (D.1 §9; DESIGN_METHODOLOGY "Parity Test
;;; Skeleton"). Equivalent computation paths that MUST reach the same fixpoint:
;;;
;;;   BSP      run-to-quiescence-bsp (production default)
;;;   DIRECT1  the sequential Gauss–Seidel drain = DIRECT at K=1 (writes visible at once)
;;;   ORDERS   DIRECT1 under permuted propagator INSTALLATION orders (the drain's firing
;;;            order follows the worklist, so permuting installation varies the schedule)
;;;   ARENA-K  the PAR 4 arena executor at K ∈ {1,4,8,16} — PENDING until P3; those rows
;;;            run only with PAR4_ARENA=1 and fail loudly until the executor exists.
;;;
;;; Theorem under test (Stage 1 synthesis T5–T8, Üresin–Dubois / Bertsekas): monotone,
;;; inflationary operators on a product of finite-height lattices reach the SAME least
;;; fixpoint under every fair schedule. Divergence CLASSES are pinned as well: each is a
;;; violated hypothesis (non-idempotent merge, absence-reading propagator, fire-counted
;;; fuel) and each test asserts the divergence EXISTS, so a future scheduler cannot
;;; silently change which hypotheses the code relies on.
(require rackunit racket/list
         "../propagator.rkt")

;; ── lattices ─────────────────────────────────────────────────────────────────────────
(define (max-merge a b) (max a b))
(define (flat-merge a b)
  (cond [(eq? a 'bot) b] [(eq? b 'bot) a] [(equal? a b) a] [else 'top]))
(define (set-merge a b) (sort (remove-duplicates (append a b)) <))
(define CAP 40)                                     ; finite height for max cells

;; ── schedulers ───────────────────────────────────────────────────────────────────────
(define (run-bsp net) (parameterize ([current-use-bsp-scheduler? #t]) (run-to-quiescence net)))
(define (run-seq net) (parameterize ([current-use-bsp-scheduler? #f]) (run-to-quiescence net)))

;; ── network builder from a spec, with an installation-order permutation ──────────────
;; spec: (values cell-specs prop-specs seeds)
;;   cell-spec  = (cons initial merge)
;;   prop-spec  = (list input-idxs output-idxs (λ (vals) out-val))   ; pure in its inputs
;;   seeds      = (listof (cons idx value)) written after installation
(define (build cell-specs prop-specs seeds order)
  (define-values (net cids)
    (for/fold ([net (make-prop-network)] [cids '()]) ([cs cell-specs])
      (define-values (n c) (net-new-cell net (car cs) (cdr cs)))
      (values n (cons c cids))))
  (define cv (list->vector (reverse cids)))
  (define net*
    (for/fold ([net net]) ([i order])
      (define ps (list-ref prop-specs i))
      (define ins (map (λ (k) (vector-ref cv k)) (car ps)))
      (define outs (map (λ (k) (vector-ref cv k)) (cadr ps)))
      (define f (caddr ps))
      (define-values (n _p)
        (net-add-propagator net ins outs (fire-of ins outs f)))
      n))
  (values (for/fold ([net net*]) ([s seeds]) (net-cell-write net (vector-ref cv (car s)) (cdr s)))
          cv))
(define (fire-of ins outs f)
  (λ (net) (define v (f (map (λ (c) (net-cell-read net c)) ins)))
           (for/fold ([net net]) ([o outs]) (net-cell-write net o v))))

;; EXPLICIT schedule (env-independent): Gauss–Seidel sweeps over the propagators in the given
;; order, firing each directly, until a sweep changes no cell. Divergence rows use TWO such
;; orders, so they never depend on which drain PROLOGOS_SCHEDULER selected.
(define (run-order cell-specs prop-specs seeds order)
  (define-values (net cv) (build cell-specs prop-specs seeds (range (length prop-specs))))
  (define fires (for/list ([i order])
                  (define ps (list-ref prop-specs i))
                  (fire-of (map (λ (k) (vector-ref cv k)) (car ps))
                           (map (λ (k) (vector-ref cv k)) (cadr ps)) (caddr ps))))
  (let sweep ([net net] [n 0])
    (define net* (for/fold ([net net]) ([f fires]) (f net)))
    (if (or (equal? (fixpoint net* cv) (fixpoint net cv)) (> n 100))
        (fixpoint net* cv)
        (sweep net* (add1 n)))))
(define (fixpoint net cv) (for/list ([c cv]) (net-cell-read net c)))

;; deterministic pseudo-random generator (no global state)
(define (lcg s) (modulo (+ (* s 1103515245) 12345) 2147483648))
(define (permutation n seed)
  (let loop ([xs (range n)] [s seed] [acc '()])
    (if (null? xs) (reverse acc)
        (let* ([s* (lcg s)] [i (modulo (quotient s* 65536) (length xs))])
          (loop (append (take xs i) (drop xs (add1 i))) s* (cons (list-ref xs i) acc))))))

;; A random monotone network over max-cells: C cells, P propagators, each reading 1–3 cells
;; and writing min(CAP, max(inputs) + k) to 1–2 cells; cycles allowed (CAP bounds height).
(define (random-max-net C P seed)
  (let loop ([s seed] [i 0] [props '()])
    (if (= i P)
        (values (for/list ([_ C]) (cons 0 max-merge)) (reverse props)
                (list (cons 0 1) (cons (quotient C 2) 3)))
        (let* ([s1 (lcg s)] [s2 (lcg s1)] [s3 (lcg s2)] [s4 (lcg s3)] [s5 (lcg s4)]
               [nin (add1 (modulo s1 3))] [nout (add1 (modulo s2 2))] [k (modulo s3 3)]
               [ins (for/list ([j nin]) (modulo (+ (quotient s4 7) (* j 31)) C))]
               [outs (for/list ([j nout]) (modulo (+ (quotient s5 13) (* j 17)) C))])
          (loop s5 (add1 i)
                (cons (list ins outs (λ (vs) (min CAP (+ (apply max vs) k)))) props))))))

;; ═══ LIVE ROWS: BSP ≡ DIRECT1 ≡ permuted orders ═══════════════════════════════════════

(test-case "parity/S-1 diamond with stale reads (max + monotone sum): BSP = DIRECT1 = all orders"
  (define cells (for/list ([_ 4]) (cons 0 max-merge)))
  (define props (list (list '(0) '(1) car) (list '(0) '(2) car)
                      (list '(1 2) '(3) (λ (vs) (min CAP (apply + vs))))))
  (define results
    (for*/list ([order (list '(0 1 2) '(2 1 0) '(1 2 0))] [run (list run-bsp run-seq)])
      (define-values (net cv) (build cells props (list (cons 0 5)) order))
      (fixpoint (run net) cv)))
  (check-equal? (remove-duplicates results) (list '(5 5 5 10))))

(test-case "parity/random monotone max networks: one fixpoint across BSP, DIRECT1, 4 orders (40 nets)"
  (for ([seed (in-range 1 41)])
    (define-values (cells props seeds) (random-max-net 24 30 seed))
    (define fps
      (for*/list ([pseed '(1 2 3 4)] [run (list run-bsp run-seq)])
        (define-values (net cv) (build cells props seeds (permutation (length props) (* pseed seed))))
        (fixpoint (run net) cv)))
    (check-equal? (length (remove-duplicates fps)) 1 (format "seed ~a: ~a distinct fixpoints" seed (length (remove-duplicates fps))))))

(test-case "parity/set-union lattice with fan-in cycles: BSP = DIRECT1 = orders"
  (define cells (for/list ([_ 6]) (cons '() set-merge)))
  (define props (list (list '(0 1) '(2) (λ (vs) (apply set-merge vs)))
                      (list '(2) '(3 4) (λ (vs) (car vs)))
                      (list '(3 5) '(1) (λ (vs) (apply set-merge vs)))
                      (list '(4) '(5) (λ (vs) (map (λ (x) (min 9 (add1 x))) (car vs))))))
  (define fps
    (for*/list ([order (list '(0 1 2 3) '(3 2 1 0) '(1 3 0 2))] [run (list run-bsp run-seq)])
      (define-values (net cv) (build cells props (list (cons 0 '(1))) order))
      (fixpoint (run net) cv)))
  (check-equal? (length (remove-duplicates fps)) 1))

(test-case "parity/S-7 contradiction is reached under every schedule (top is absorbing)"
  (define cells (for/list ([_ 3]) (cons 'bot flat-merge)))
  (define props (list (list '(0) '(2) (λ (vs) (car vs)))
                      (list '(1) '(2) (λ (vs) (car vs)))))
  (for* ([order (list '(0 1) '(1 0))] [run (list run-bsp run-seq)])
    (define-values (net cv) (build cells props (list (cons 0 'a) (cons 1 'b)) order))
    (check-equal? (net-cell-read (run net) (vector-ref cv 2)) 'top)))

;; ═══ DIVERGENCE CLASSES: each pins a violated hypothesis ═══════════════════════════════

(test-case "divergence/A-2 a NON-IDEMPOTENT merge (+) under two explicit schedules"
  ;; Diamond fan-in: c0 → c1, c0 → c2, {c1,c2} → c3 where c3 ACCUMULATES with +. Order
  ;; (join last) fires the join after both inputs settle; order (join first) fires it on
  ;; every sweep while inputs change: same monotone propagators, different write counts.
  (define cells (list (cons 0 max-merge) (cons 0 max-merge) (cons 0 max-merge) (cons 0 +)))
  (define props (list (list '(0) '(1) car) (list '(0) '(2) car)
                      (list '(1 2) '(3) (λ (vs) (apply max vs)))))
  (check-not-equal? (run-order cells props (list (cons 0 3)) '(0 1 2))
                    (run-order cells props (list (cons 0 3)) '(2 0 1))))

(test-case "divergence/A-2 production pattern: readiness → ready-queue under merge-list-append duplicates entries"
  ;; Mirrors tests/test-readiness-propagator.rkt:340-365 (PM Track 7 Phase 8 readiness):
  ;; threshold latch → readiness propagator appends 'ready! to a merge-list-append queue.
  ;; Found by the PAR 4 P0 full-suite run under seq-shuffle seed 2 (queue length 2 ≠ 1):
  ;; BSP's per-round dedup HIDES the non-idempotence; any direct schedule exposes it.
  (define (append-merge a b) (append a b))
  (define cells (list (cons 'ground (λ (a b) a)) (cons #f (λ (a b) (or a b))) (cons '() append-merge)))
  (define props (list (list '(0) '(1) (λ (vs) (and (car vs) #t)))
                      (list '(1) '(2) (λ (vs) (if (car vs) '(ready!) '())))))
  (define q-late  (run-order cells props '() '(0 1)))   ; latch first, then readiness
  (define q-early (run-order cells props '() '(1 0)))   ; readiness swept before the latch flips
  (check-not-equal? (length (caddr q-late)) (length (caddr q-early))
                    (format "expected different queue lengths: ~a vs ~a" q-late q-early)))

(test-case "divergence/A-1/A-3 an ABSENCE-reading propagator under two explicit schedules"
  ;; p_neg writes 'yes to c2 iff c1 is still 'bot when it fires — negation inside S0.
  (define cells (list (cons 'bot flat-merge) (cons 'bot flat-merge) (cons 'bot flat-merge)))
  (define props (list (list '(0) '(1) car)
                      (list '(0 1) '(2) (λ (vs) (if (eq? (cadr vs) 'bot) 'yes 'no)))))
  (check-not-equal? (run-order cells props (list (cons 0 'go)) '(0 1))
                    (run-order cells props (list (cons 0 'go)) '(1 0))))

(test-case "divergence/A-1 an ANTI-monotone asc→desc pair (tests/test-propagator-descending-01.rkt:169)"
  ;; asc (max) and desc (min, information order reversed): p1 writes asc+1 into desc, so MORE
  ;; information on asc yields LESS information written to desc. Two fixpoints by order —
  ;; observed by the PAR 4 P0 full-suite seq-shuffle runs (asc 9 vs 0).
  (define cells (list (cons 0 max-merge) (cons 10 (λ (a b) (min a b)))))
  (define props (list (list '(0) '(1) (λ (vs) (add1 (car vs))))
                      (list '(1) '(0) (λ (vs) (sub1 (car vs))))))
  (check-not-equal? (run-order cells props '() '(0 1)) (run-order cells props '() '(1 0))))

(test-case "divergence/S-6 fuel counts FIRES today: the charge depends on the schedule, not the lattice"
  ;; Fan-in network: 16 sources → one max-cell join, sources seeded in sequence. Every
  ;; schedule reaches the same fixpoint (asserted) and the same number of STRICT ASCENTS is
  ;; bounded by Σ heights — but the FIRE count (today's fuel charge) differs: BSP dedups the
  ;; join per round, the DIRECT1 drain fires it per input change. O-2 (fuel counts changes)
  ;; is what makes the charge a property of the lattice, not of the scheduler.
  (define n 16)
  (define cells (append (for/list ([_ n]) (cons 0 max-merge)) (list (cons 0 max-merge))))
  (define props (list (list (range n) (list n) (λ (vs) (apply max vs)))))
  (define used
    (for/list ([run (list run-bsp run-seq)])
      (define-values (net0 cv) (build cells props '() '(0)))
      (define net (for/fold ([net net0]) ([i n]) (net-cell-write net (vector-ref cv i) (add1 i))))
      (define out (run net))
      (check-equal? (net-cell-read out (vector-ref cv n)) n)
      (- 1000000 (net-fuel-remaining out))))
  (printf "  S-6 fuel charged for the same 16-way fan-in fixpoint: BSP ~a  DIRECT1 ~a\n" (car used) (cadr used))
  (check-not-equal? (car used) (cadr used) "fire-counted fuel is expected to differ by schedule"))

;; ═══ PENDING ROWS (P3): the arena executor at K ∈ {1,4,8,16} ═══════════════════════════
(when (equal? (getenv "PAR4_ARENA") "1")
  (test-case "arena/K∈{1,4,8,16}: same fixpoint as BSP on every live row above"
    (fail "PAR 4 P3 not implemented: run-to-quiescence-arena does not exist yet")))

#lang racket/base
;;; PAR 4 O-16 probe — WHAT A NETWORK BUDGET COUNTS. Read-only on production code; runs on the real propagator.rkt.
;;; Fixtures (spec level) adapted from W2-9's w29-lifted-kleene.rkt (benchmarks/par4/d3-wave2/W2-9/).
;;; Schedules: BSP (run-to-quiescence with the BSP scheduler, sequential executor) and the DRAIN
;;; (run-to-quiescence-drain, the Gauss-Seidel stand-in for DIRECT at K = 1), each with forward / reversed install order.
;;; Per run it measures the three candidate budget units and the boundary of exhaustion:
;;;   fires     — fire evaluations (what production fuel charges today: BSP charges n per round, propagator.rkt:3493;
;;;               the drain charges per fire)
;;;   changes   — strict increases of a cell's value (O-2's unit). BSP: (cell, round) pairs whose value changed between
;;;               consecutive round states; DRAIN: writes that changed the live cell.
;;;   depth     — Kleene depth: the number of strict Kleene steps to the fixpoint (reference computed in Racket).
;;;   B-min     — the least fuel (make-prop-network F) for which the run ends without 'tropical-fuel-exhausted.
;;;   label     — DRAIN only: an upper-bound depth label a DIRECT run could carry: when a write changes cell c,
;;;               label(c) := max(label(c), 1 + max over declared inputs of label(input)); x0 labels are 0.
;;;               CLAIM (THEOREM under joins + declared reads, checked here): label(c) >= Kleene depth of c's value,
;;;               so "every final label <= B" implies the least fixpoint equals x_B (no exhaustion under a depth budget).
;;; Power rows: (P1) a mutant label rule without the +1 must break label >= depth on the chain; (P2) the divergent
;;; fixture must exhaust at every budget, and the chain must exhaust at F = 1; (P3) the S-6 fan-in must show
;;; 1 change under BSP and 16 under the ascending drain (P0 §5's measured numbers).
(require racket/list racket/set racket/string racket/format
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt"))

(define (mmax a b) (max a b))
(define (munion a b) (set-union a b))
(define (merge-of m) (case m [(max) mmax] [(union) munion]))

;; cell: (name init merge) ; prop: (name (ins) (outs) fn)   fn : (name -> value) -> (listof (out . v))
(define (chain n)
  (list (for/list ([i (in-range (add1 n))]) (list (string->symbol (format "c~a" i)) (if (= i 0) 1 0) 'max))
        (for/list ([i (in-range n)])
          (define a (string->symbol (format "c~a" i))) (define b (string->symbol (format "c~a" (add1 i))))
          (list (string->symbol (format "p~a" i)) (list a) (list b) (λ (rd) (list (cons b (rd a))))))))
(define (fan-in-asc k)            ; P0's S-6 shape: k sources 1..k copied into one max cell
  (list (append (for/list ([i (in-range 1 (add1 k))]) (list (string->symbol (format "s~a" i)) i 'max)) (list (list 'o 0 'max)))
        (for/list ([i (in-range 1 (add1 k))])
          (define s (string->symbol (format "s~a" i)))
          (list (string->symbol (format "p~a" i)) (list s) (list 'o) (λ (rd) (list (cons 'o (rd s))))))))
(define diamond
  (list (list (list 'a 1 'max) (list 'b 0 'max) (list 'c 0 'max) (list 'd 0 'max))
        (list (list 'pb '(a) '(b) (λ (rd) (list (cons 'b (+ 1 (rd 'a))))))
              (list 'pc '(a) '(c) (λ (rd) (list (cons 'c (+ 2 (rd 'a))))))
              (list 'pd '(b c) '(d) (λ (rd) (list (cons 'd (+ (rd 'b) (rd 'c)))))))))
(define x3-cycle
  (list (list (list 'c0 (set 0) 'union) (list 'c1 (set) 'union) (list 'c2 (set) 'union) (list 'c3 (set) 'union))
        (list (list 'p0 '(c0) '(c1) (λ (rd) (list (cons 'c1 (set-add (rd 'c0) 1)))))
              (list 'p1 '(c1) '(c2) (λ (rd) (list (cons 'c2 (set-add (rd 'c1) 2)))))
              (list 'p2 '(c2) '(c0) (λ (rd) (list (cons 'c0 (rd 'c2)))))
              (list 'p3 '(c0) '(c3) (λ (rd) (list (cons 'c3 (rd 'c0))))))))
(define (climb H)                 ; a 2-cycle climbing to height H: depth grows with the lattice height
  (list (list (list 'a 0 'max) (list 'b 0 'max))
        (list (list 'p '(a) '(b) (λ (rd) (list (cons 'b (min H (add1 (rd 'a)))))))
              (list 'q '(b) '(a) (λ (rd) (list (cons 'a (min H (add1 (rd 'b))))))))))
(define (wide k)                  ; k independent copies: work k, depth 1
  (list (append (for/list ([i k]) (list (string->symbol (format "s~a" i)) 1 'max))
                (for/list ([i k]) (list (string->symbol (format "t~a" i)) 0 'max)))
        (for/list ([i k])
          (define s (string->symbol (format "s~a" i))) (define t (string->symbol (format "t~a" i)))
          (list (string->symbol (format "p~a" i)) (list s) (list t) (λ (rd) (list (cons t (rd s))))))))
(define divergent                 ; an infinite ascending chain: no fixpoint
  (list (list (list 'a 0 'max) (list 'b 0 'max))
        (list (list 'p '(a) '(b) (λ (rd) (list (cons 'b (add1 (rd 'a))))))
              (list 'q '(b) '(a) (λ (rd) (list (cons 'a (add1 (rd 'b)))))))))

(define FIXTURES
  (list (cons "chain-8" (chain 8)) (cons "fan-in-asc-16 (S-6)" (fan-in-asc 16)) (cons "diamond" diamond)
        (cons "x3-cycle" x3-cycle) (cons "climb-8" (climb 8)) (cons "wide-64" (wide 64)) (cons "divergent" divergent)))

;; Kleene reference: x_{n+1} = x_n ⊔ ⊔_p f_p(x_n); depth = number of strict steps; #f if > cap.
(define (kleene-depth spec [cap 200])
  (define cells (car spec)) (define props (cadr spec))
  (define merges (for/hasheq ([c cells]) (values (car c) (merge-of (caddr c)))))
  (let loop ([x (for/hasheq ([c cells]) (values (car c) (cadr c)))] [d 0])
    (define nx (for*/fold ([nx x]) ([p props] [w ((cadddr p) (λ (nm) (hash-ref x nm)))])
                 (hash-set nx (car w) ((hash-ref merges (car w)) (hash-ref nx (car w)) (cdr w)))))
    (cond [(equal? nx x) d] [(>= d cap) #f] [else (loop nx (add1 d))])))

(define (state-of net ids cells) (for/hasheq ([c cells]) (values (car c) (net-cell-read net (hash-ref ids (car c))))))

;; One run. Returns a hash of measurements.
(define (run spec order sched fuel #:mutant-label [mutant? #f])
  (define cells (car spec)) (define props (if (eq? order 'rev) (reverse (cadr spec)) (cadr spec)))
  (define fires (box 0)) (define live-changes (box 0))
  (define labels (make-hasheq))
  (define-values (net ids)
    (for/fold ([net (make-prop-network fuel)] [ids (hasheq)]) ([c cells])
      (define-values (n* cid) (net-new-cell net (cadr c) (merge-of (caddr c))))
      (values n* (hash-set ids (car c) cid))))
  (define (fire-of p)
    (λ (n)
      (set-box! fires (add1 (unbox fires)))
      (define in-label (for/fold ([m 0]) ([i (cadr p)]) (max m (hash-ref labels i 0))))
      (for/fold ([n n]) ([w ((cadddr p) (λ (nm) (net-cell-read n (hash-ref ids nm))))])
        (define cid (hash-ref ids (car w)))
        (define before (net-cell-read n cid))
        (define n2 (net-cell-write n cid (cdr w)))
        (unless (equal? before (net-cell-read n2 cid))
          (set-box! live-changes (add1 (unbox live-changes)))
          (hash-set! labels (car w) (max (hash-ref labels (car w) 0) (if mutant? in-label (add1 in-label)))))
        n2)))
  (define net2 (for/fold ([net net]) ([p props])
                 (define-values (n* _) (net-add-propagator net (map (λ (x) (hash-ref ids x)) (cadr p))
                                                           (map (λ (x) (hash-ref ids x)) (caddr p)) (fire-of p)))
                 n*))
  (define recs '())
  (define out
    (case sched
      [(bsp) (parameterize ([current-use-bsp-scheduler? #t] [current-parallel-executor #f]
                            [current-bsp-observer (λ (r) (set! recs (cons r recs)))])
               (run-to-quiescence net2))]
      [(drain) (parameterize ([current-use-bsp-scheduler? #f] [current-bsp-observer #f]) (run-to-quiescence net2))]))
  (define exhausted? (net-contradiction? out))
  (define bsp-states (cons (state-of net2 ids cells)
                           (for/list ([r (reverse recs)]) (state-of (bsp-round-network-snapshot r) ids cells))))
  (define bsp-changes
    (for/sum ([a bsp-states] [b (if (null? bsp-states) '() (cdr bsp-states))])
      (for/sum ([c cells]) (if (equal? (hash-ref a (car c)) (hash-ref b (car c))) 0 1))))
  (define bsp-depth (for/sum ([a bsp-states] [b (if (null? bsp-states) '() (cdr bsp-states))]) (if (equal? a b) 0 1)))
  (hasheq 'fires (unbox fires)
          'changes (if (eq? sched 'bsp) bsp-changes (unbox live-changes))
          'depth (if (eq? sched 'bsp) bsp-depth #f)
          'label (if (eq? sched 'drain) (for/fold ([m 0]) ([(k v) labels]) (max m v)) #f)
          'charged (- fuel (net-fuel-remaining out))
          'exhausted exhausted?
          'final (state-of out ids cells)))

(define (b-min spec order sched [hi 4096])
  ;; least F in [1, hi] with no exhaustion (exhaustion is monotone in F); #f if even hi exhausts
  (if (hash-ref (run spec order sched hi) 'exhausted) #f
      (let loop ([lo 0] [hi hi])            ; invariant: lo exhausts (or 0), hi does not
        (if (= (add1 lo) hi) hi
            (let ([mid (quotient (+ lo hi) 2)])
              (if (hash-ref (run spec order sched mid) 'exhausted) (loop mid hi) (loop lo mid)))))))

(define SCHEDS '((bsp fwd) (bsp rev) (drain fwd) (drain rev)))
(define (fmt v) (cond [(not v) "—"] [(eq? v #t) "yes"] [else (~a v)]))

(printf "# O-16 budget-unit probe  (Racket ~a; propagator.rkt of the par4-arena-executors worktree)\n" (version))
(printf "# columns per schedule: fires / changes / B-min ; BSP adds depth (rounds that changed state); DRAIN adds label (max)\n\n")
(printf "| fixture | Kleene depth | ~a |\n" (string-join (for/list ([s SCHEDS]) (format "~a-~a fires/chg/B-min/~a" (car s) (cadr s) (if (eq? (car s) 'bsp) "depth" "label"))) " | "))
(printf "|---|---|~a\n" (string-join (for/list ([s SCHEDS]) "---") "|"))
(define label-violations 0) (define label-excess '())
(for ([f FIXTURES])
  (define spec (cdr f))
  (define kd (kleene-depth spec))
  (define cols
    (for/list ([s SCHEDS])
      (define big (run spec (cadr s) (car s) 4096))
      (define bm (b-min spec (cadr s) (car s)))
      (define extra (if (eq? (car s) 'bsp) (hash-ref big 'depth) (hash-ref big 'label)))
      (when (and kd (eq? (car s) 'drain) (not (hash-ref big 'exhausted)))
        (when (< (hash-ref big 'label) kd) (set! label-violations (add1 label-violations)))
        (when (> (hash-ref big 'label) kd) (set! label-excess (cons (list (car f) (cadr s) (hash-ref big 'label) kd) label-excess))))
      (if (hash-ref big 'exhausted)
          (format "exhausted at 4096 (charged ~a)" (hash-ref big 'charged))
          (format "~a / ~a / ~a / ~a" (hash-ref big 'fires) (hash-ref big 'changes) (fmt bm) (fmt extra)))))
  (printf "| ~a | ~a | ~a |\n" (car f) (fmt kd) (string-join cols " | ")))

(printf "\n## Theorem check: DRAIN label >= Kleene depth on every converging fixture\n")
(printf "violations: ~a ; label > depth (conservative, inconclusive under a depth budget at B in [depth, label)): ~a\n"
        label-violations (if (null? label-excess) "none" (reverse label-excess)))

(printf "\n## Partial state at exhaustion (divergent fixture, F = 41)\n")
(for ([s SCHEDS])
  (define r (run divergent (cadr s) (car s) 41))
  (printf "~a-~a: exhausted=~a charged=~a final=~a\n" (car s) (cadr s) (fmt (hash-ref r 'exhausted)) (hash-ref r 'charged)
          (sort (hash->list (hash-ref r 'final)) symbol<? #:key car)))

(printf "\n## Power rows\n")
(let* ([m (run (chain 8) 'fwd 'drain 4096 #:mutant-label #t)] [kd (kleene-depth (chain 8))])
  (printf "P1 mutant label (no +1) on chain-8, drain-fwd: label=~a vs Kleene depth ~a -> ~a\n" (hash-ref m 'label) kd
          (if (< (hash-ref m 'label) kd) "VIOLATION DETECTED (the check has power)" "not detected (NO POWER)")))
(printf "P2 divergent exhausts at F=4096 under every schedule: ~a ; chain-8 at F=1 (bsp, drain): ~a ~a\n"
        (for/and ([s SCHEDS]) (hash-ref (run divergent (cadr s) (car s) 4096) 'exhausted))
        (fmt (hash-ref (run (chain 8) 'fwd 'bsp 1) 'exhausted)) (fmt (hash-ref (run (chain 8) 'fwd 'drain 1) 'exhausted)))
(let ([b (run (fan-in-asc 16) 'fwd 'bsp 4096)] [d (run (fan-in-asc 16) 'fwd 'drain 4096)] [r (run (fan-in-asc 16) 'rev 'drain 4096)])
  (printf "P3 S-6 fan-in changes: bsp=~a drain-fwd=~a drain-rev=~a (P0 §5 measured 1 vs up to 16)\n"
          (hash-ref b 'changes) (hash-ref d 'changes) (hash-ref r 'changes)))

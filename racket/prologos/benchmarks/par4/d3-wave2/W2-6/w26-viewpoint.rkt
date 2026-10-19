#lang racket/base
;; W2-6 (PAR 4 D.3 wave 2, CL-6 (b)) — cell-1 split into an INFORMATION projection and a per-query VIEWPOINT.
;; Adapted from C4's c4-worldview-viewpoint.rkt (which replays test-solver-context.rkt:341-362).
;; Part 1: solve-all with
;;   A production cell-1 merge (replacement) + production API                        (control: 2 answers)
;;   B cell-1 merge = ior (D.2 row 1's committed component) + production API         (C4-4's measurement: 1 answer)
;;   C cell-1 merge = ior, viewpoint carried PER QUERY (W passed to the write and the read; cell-1 never written by
;;     with-worldview, never read as a viewpoint)                                  (is (b) enough to restore 2?)
;;   D as C with the replacement merge (is the answer independent of cell-1's merge once (b) holds?)
;;   E as C with the ev_W read (a) on the goal cell
;; Part 2: the information half as a monotone projection α = (C, X) over the real decisions-state
;;   (C = bits of every assumption ever made, X = C ∧ ¬decisions-bitmask), against today's projection
;;   (propagator.rkt:978-987 writes decisions-state-bitmask by replacement). Replays the op sequence of
;;   test-solver-context.rkt:117-140 ("projection updates cache when component narrows") plus random sequences.
;; Run: racket w26-viewpoint.rkt
(require racket/list
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/decision-cell.rkt")
                  tagged-cell-value? tagged-cell-value-base tagged-cell-value-entries
                  decisions-state-empty decisions-state-add-component decisions-state-narrow-component
                  decisions-state-bitmask decision-from-alternatives bit->mask))
(define root "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos")
(define (p f) (list 'file (string-append root "/" f)))
(define (get f id) (dynamic-require (p f) id))
(define atms-ns (begin (dynamic-require (p "atms.rkt") #f) (module->namespace (p "atms.rkt"))))
(define prop-ns (begin (dynamic-require (p "propagator.rkt") #f) (module->namespace (p "propagator.rkt"))))
(define make-solver-state (get "atms.rkt" 'make-solver-state))
(define solver-state-amb (get "atms.rkt" 'solver-state-amb))
(define solver-state-with-worldview (get "atms.rkt" 'solver-state-with-worldview))
(define solver-state-write-cell (get "atms.rkt" 'solver-state-write-cell))
(define solver-state-solve-all (get "atms.rkt" 'solver-state-solve-all))
(define solver-state-consistent? (eval 'solver-state-consistent? atms-ns))
(define solver-state-amb-groups (eval 'solver-state-amb-groups atms-ns))
(define solver-state-key-map (eval 'solver-state-key-map atms-ns))
(define assumption-id-n (eval 'assumption-id-n atms-ns))
(define assumption-id (eval 'assumption-id atms-ns))
(define make-prop-network (get "propagator.rkt" 'make-prop-network))
(define net-cell-read (get "propagator.rkt" 'net-cell-read))
(define net-cell-read-raw (get "propagator.rkt" 'net-cell-read-raw))
(define current-worldview-bitmask (get "propagator.rkt" 'current-worldview-bitmask))
(define wv-cid (get "propagator.rkt" 'worldview-cache-cell-id))
(define set-cell1-merge
  (eval '(lambda (net f)
           (struct-copy prop-network net
             [cold (struct-copy prop-net-cold (prop-network-cold net)
                     [merge-fns (champ-insert (prop-network-merge-fns net)
                                              (cell-id-hash worldview-cache-cell-id) worldview-cache-cell-id f)])]))
        prop-ns))
(define ss-net (eval 'solver-state-net atms-ns))
(define with-net (eval '(lambda (ss net) (solver-state (solver-state-ctx ss) net (solver-state-key-map ss) (solver-state-amb-groups ss))) atms-ns))
(define (ior o n) (bitwise-ior o n))
(define (replace o n) (if (= o n) o n))
(define (W-of believed) (for/fold ([bm 0]) ([(aid _) (in-hash believed)]) (bitwise-ior bm (arithmetic-shift 1 (assumption-id-n aid)))))

;; (b): the viewpoint is an argument. A "query" is (cons ss W); nothing writes cell-1 on a viewpoint switch.
(define (q-with-worldview q believed) (cons (car q) (W-of believed)))
(define (q-write-cell q key val) (cons (parameterize ([current-worldview-bitmask (cdr q)]) (solver-state-write-cell (car q) key val)) (cdr q)))
(define (q-read ss key W reader)
  (define cid (hash-ref (solver-state-key-map ss) key #f))
  (cond [(not cid) 'bot]
        [(eq? reader 'prod) (parameterize ([current-worldview-bitmask W]) (net-cell-read (ss-net ss) cid))]
        [else (define raw (net-cell-read-raw (ss-net ss) cid))   ;; ev_W with the goal cell's domain merge (old new -> new)
              (if (tagged-cell-value? raw)
                  (for/fold ([acc (tagged-cell-value-base raw)]) ([e (tagged-cell-value-entries raw)] #:when (= (bitwise-and (car e) W) (car e)))
                    (cdr e))
                  raw)]))
(define (q-solve-all q key reader)   ;; solver-state-solve-all (atms.rkt:658-685) with W passed per combo
  (define ss (car q))
  (define combos (let loop ([gs (solver-state-amb-groups ss)]) (if (null? gs) '(()) (for*/list ([a (car gs)] [r (loop (cdr gs))]) (cons a r)))))
  (reverse (for/fold ([acc '()]) ([combo combos])
             (define believed (for/hasheq ([a combo]) (values a #t)))
             (if (solver-state-consistent? ss believed)
                 (let ([v (q-read ss key (W-of believed) reader)]) (if (or (eq? v 'bot) (member v acc)) acc (cons v acc)))
                 acc))))

(define (run-prod label cell1-merge)
  (define ss00 (make-solver-state (make-prop-network)))
  (define ss0 (if cell1-merge (with-net ss00 (set-cell1-merge (ss-net ss00) cell1-merge)) ss00))
  (define-values (ss1 hyps) (solver-state-amb ss0 '(left right)))
  (define hl (car hyps)) (define hr (cadr hyps))
  (define ss2 (solver-state-write-cell (solver-state-with-worldview ss1 (hasheq hl #t)) 'goal 'val-left))
  (define ss3 (solver-state-with-worldview ss2 (hasheq hl #t hr #t)))
  (define ss4 (solver-state-write-cell (solver-state-with-worldview ss3 (hasheq hr #t)) 'goal 'val-right))
  (define ss5 (solver-state-with-worldview ss4 (hasheq hl #t hr #t)))
  (printf "  ~a: answers ~s ; cell-1 at the end = ~b\n" label (solver-state-solve-all ss5 'goal) (net-cell-read-raw (ss-net ss5) wv-cid)))
(define (run-viewpoint label cell1-merge reader)
  (define ss00 (make-solver-state (make-prop-network)))
  (define ss0 (with-net ss00 (set-cell1-merge (ss-net ss00) cell1-merge)))
  (define-values (ss1 hyps) (solver-state-amb ss0 '(left right)))
  (define hl (car hyps)) (define hr (cadr hyps))
  (define q1 (cons ss1 0))
  (define q2 (q-write-cell (q-with-worldview q1 (hasheq hl #t)) 'goal 'val-left))       ;; same op sequence as the test
  (define q3 (q-with-worldview q2 (hasheq hl #t hr #t)))
  (define q4 (q-write-cell (q-with-worldview q3 (hasheq hr #t)) 'goal 'val-right))
  (define q5 (q-with-worldview q4 (hasheq hl #t hr #t)))
  (define raw (net-cell-read-raw (ss-net (car q5)) (hash-ref (solver-state-key-map (car q5)) 'goal)))
  (printf "  ~a: answers ~s ; goal entries ~s ; cell-1 at the end = ~b\n" label (q-solve-all q5 'goal reader)
          (tagged-cell-value-entries raw) (net-cell-read-raw (ss-net (car q5)) wv-cid)))

(printf "Part 1: test-solver-context.rkt:341-362 sequence (expects 2 answers: val-left, val-right)\n")
(run-prod "A production merge, production API" #f)
(run-prod "B ior merge, production API (C4-4)" ior)
(run-viewpoint "C ior merge, W per query, production read" ior 'prod)
(run-viewpoint "D replacement merge, W per query, production read" replace 'prod)
(run-viewpoint "E ior merge, W per query, ev_W read" ior 'ev)

;; ---- Part 2 ------------------------------------------------------------------------------------------------
(printf "\nPart 2: information half as α = (C, X) vs today's projection (decisions-state-bitmask, replacement)\n")
(define AIDS (make-hasheqv))
(define (aid n) (hash-ref! AIDS n (λ () (assumption-id n))))   ;; one object per id: assumption-id is compared by equal? in decision-domain-narrow (decision-cell.rkt:292)
(define (apply-op st op)   ;; st = (list ds C) ; op = (assume n) | (narrow n)
  (define ds (car st)) (define C (cadr st))
  (case (car op)
    [(assume) (define n (cadr op))
              (list (decisions-state-add-component ds (aid n) (decision-from-alternatives (list (aid n)) (bit->mask n) (list n)))
                    (bitwise-ior C (bit->mask n)))]
    [(narrow) (define n (cadr op)) (list (decisions-state-narrow-component ds (aid n) (aid n)) C)]))
(define (alpha st) (let ([bm (decisions-state-bitmask (car st))] [C (cadr st)]) (cons C (bitwise-and C (bitwise-not bm)))))
(define (live a) (bitwise-and (car a) (bitwise-not (cdr a))))
(define (leq-pair a b) (and (= (bitwise-and (car a) (car b)) (car a)) (= (bitwise-and (cdr a) (cdr b)) (cdr a))))
(define (leq-bits a b) (= (bitwise-and a b) a))
(define (check-seq ops)
  (define sts (let loop ([st (list (decisions-state-empty assumption-id-n) 0)] [ops ops] [acc '()])
                (define acc* (cons st acc)) (if (null? ops) (reverse acc*) (loop (apply-op st (car ops)) (cdr ops) acc*))))
  (for/fold ([proj-viol 0] [alpha-viol 0] [live-mismatch 0]) ([a sts] [b (cdr sts)])
    (values (+ proj-viol (if (leq-bits (decisions-state-bitmask (car a)) (decisions-state-bitmask (car b))) 0 1))
            (+ alpha-viol (if (leq-pair (alpha a) (alpha b)) 0 1))
            (+ live-mismatch (if (= (live (alpha b)) (decisions-state-bitmask (car b))) 0 1)))))
(let-values ([(pv av lm) (check-seq '((assume 0) (assume 1) (narrow 1)))])
  (printf "  test-solver-context.rkt:117-140 sequence (assume h0, assume h1, narrow h1):\n")
  (printf "    today's projection non-monotone steps (ior order): ~a ; α non-monotone steps: ~a ; live(α) ≠ today's cell-1: ~a\n" pv av lm))
(define rng (make-pseudo-random-generator))
(parameterize ([current-pseudo-random-generator rng]) (random-seed 2606))
(define-values (PV AV LM N)
  (for/fold ([PV 0] [AV 0] [LM 0] [N 0]) ([trial 500])
    (define ops (for/list ([k (add1 (random 8 rng))]) (list (if (zero? (random 2 rng)) 'assume 'narrow) (random 4 rng))))
    ;; narrow only what exists; assume each bit once (fresh ids, C9-4's invariant)
    (define-values (ops* _s) (for/fold ([acc '()] [seen '()]) ([o ops])
                               (case (car o)
                                 [(assume) (if (memv (cadr o) seen) (values acc seen) (values (append acc (list o)) (cons (cadr o) seen)))]
                                 [(narrow) (if (memv (cadr o) seen) (values (append acc (list o)) seen) (values acc seen))])))
    (define-values (pv av lm) (check-seq ops*))
    (values (+ PV pv) (+ AV av) (+ LM lm) (+ N (length ops*)))))
(printf "  500 random op sequences (~a steps): projection non-monotone ~a ; α non-monotone ~a ; live(α) ≠ projection ~a\n" N PV AV LM)
(printf "  POWER: the method flags the projection (must be > 0 when a narrow occurs) — see the line above\n")

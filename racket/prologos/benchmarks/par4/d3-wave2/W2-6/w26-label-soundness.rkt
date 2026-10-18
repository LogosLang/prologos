#lang racket/base
;; W2-6 (PAR 4 D.3 wave 2, CL-6 (a)+(c)) — one rule for labelled fires: SOUNDNESS comes from labelling every output
;; with the W its inputs were read at (ev_W read, C4-1/C9-3); COMPLETENESS comes from evaluating at enough W
;; (the union-closure of the input labels, C4-7; or per label when the fire is additive).
;; THEOREM checked here by enumeration. Hypotheses: D is a join-semilattice (set union); ev_W(t) = base ⊔ ⨆{v | b ⊆ W};
;; f monotone. Every output entry is (W, f(ev_W(in))). Then for every boundary viewpoint V:
;;   ev_V(out) ⊑ f(ev_V(in))   (sound: ev_W ⊑ ev_V for W ⊆ V, f monotone)
;;   ev_V(out) = f(ev_V(in))   when V is an evaluation point, or f is additive and every input label is one.
;; Power rows: an output written PLAIN from a read at a viewpoint (C9-4's static-plain / today's unwrapped fire), an
;; output labelled with FEWER bits than it read, and the production base-dropping reader, must all be flagged.
;; Adapted from C4's c4-lattices.rkt B4 and C9's c9-labelled.rkt B2. Uses the real tagged-cell-value struct and reader.
;; Run: racket w26-label-soundness.rkt
(require racket/list racket/set
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/decision-cell.rkt")
                  tagged-cell-value tagged-cell-value-base tagged-cell-value-entries tagged-cell-read))
(define su set-union)
(define (ev t W) (for/fold ([acc (tagged-cell-value-base t)]) ([e (tagged-cell-value-entries t)] #:when (= (bitwise-and (car e) W) (car e))) (su acc (cdr e))))
(define (ev-prod t W) (tagged-cell-read t W su))   ;; production reader (decision-cell.rkt:452-477)
(define (closure ls) (let loop ([acc '(0)] [ls (remove-duplicates ls)])
                       (if (null? ls) acc (loop (remove-duplicates (append acc (map (λ (w) (bitwise-ior w (car ls))) acc))) (cdr ls)))))
(define rng (make-pseudo-random-generator))
(parameterize ([current-pseudo-random-generator rng]) (random-seed 2606))
(define vals (list (seteq) (seteq 'a) (seteq 'b) (seteq 'c) (seteq 'a 'b)))
(define (rand-t) (tagged-cell-value (list-ref vals (random 5 rng))
                                    (remove-duplicates (for/list ([k (random 4 rng)]) (cons (add1 (random 7 rng)) (list-ref vals (random 5 rng)))))))
(define TS (for/list ([i 400]) (rand-t)))
(define (f-add s) (for/seteq ([x s]) (case x [(a) 'A] [(b) 'B] [else 'C])))          ;; additive (join-preserving)
(define (f-both s) (if (and (set-member? s 'a) (set-member? s 'b)) (seteq 'both) (seteq)))  ;; monotone, not additive
(define (labels t) (map car (tagged-cell-value-entries t)))
(define strategies
  (list
   (list "closure-evaluated, outputs labelled by read-W"
         (λ (f t) (tagged-cell-value (f (ev t 0)) (for/list ([W (closure (labels t))] #:unless (zero? W)) (cons W (f (ev t W)))))))
   (list "per input label (static-label fires), labelled"
         (λ (f t) (tagged-cell-value (f (ev t 0)) (for/list ([b (remove-duplicates (labels t))]) (cons b (f (ev t b)))))))
   (list "POWER plain output read at a viewpoint V0 (random)"
         (λ (f t) (tagged-cell-value (f (ev t (random 8 rng))) '())))
   (list "POWER under-labelled: read at b|extra, write under b"
         (λ (f t) (tagged-cell-value (f (ev t 0)) (for/list ([b (remove-duplicates (labels t))]) (cons b (f (ev t (bitwise-ior b (arithmetic-shift 1 (random 3 rng))))))))))
   (list "POWER closure-evaluated but production reader (drops base)"
         (λ (f t) (tagged-cell-value (f (ev-prod t 0)) (for/list ([W (closure (labels t))] #:unless (zero? W)) (cons W (f (ev-prod t W)))))))))
(printf "400 random tagged inputs × 8 boundary viewpoints V = 3 200 checks per row\n")
(for ([st strategies])
  (for ([fr (list (cons "additive f" f-add) (cons "non-additive f" f-both))])
    (define-values (unsound incomplete)
      (for*/fold ([u 0] [i 0]) ([t TS] [V 8])
        (define out ((cadr st) (cdr fr) t))
        (define got (ev out V)) (define want ((cdr fr) (ev t V)))
        (values (+ u (if (subset? got want) 0 1)) (+ i (if (subset? want got) 0 1)))))
    (printf "  ~a | ~a: unsound ~a/3200, incomplete ~a/3200\n" (car st) (car fr) unsound incomplete)))
(let* ([t (tagged-cell-value (seteq) (list (cons 1 (seteq 'a)) (cons 2 (seteq 'b))))])
  (printf "witness (C4-7): entries {1:{a}, 2:{b}}, V=3: f(ev_V) = ~s ; per-label output read at V = ~s ; closure output = ~s\n"
          (f-both (ev t 3)) (ev ((cadr (list-ref strategies 1)) f-both t) 3) (ev ((cadr (list-ref strategies 0)) f-both t) 3)))

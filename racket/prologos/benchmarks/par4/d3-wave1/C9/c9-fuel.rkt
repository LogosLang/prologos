#lang racket/base
;; C9 (f) + S-6: change-counted fuel (D.2 §6.6, §8, §10.2 S-6) on the REAL propagator.rkt.
;;
;; E1  Is the number of CHANGES schedule-independent? 16 producers P_i (trigger -> s_i := i+1) and a
;;     join J (max of all s_i). Two explicit DIRECT orders (both fair, both legal at K > 1):
;;     J after every P_i, and J after all P_i; plus production BSP and drain.
;;     D.2 S-6 claims: below Σ heights, 'tropical-fuel-exhausted under EVERY schedule.
;; E2  A fenced NON-INFLATIONARY merge (LWW) in a cycle: W1, W2 read T and write constants a / b.
;;     §6.6 says fuel counts "changes (strict increases)"; §8 says it counts changes "which includes
;;     non-ascending ones". Count both, and run production BSP / drain with a small fuel budget.
;; E3  fork identity (h): two forks of one template — is there anything that tells them apart?
(require racket/list
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt"))

(define (run-bsp net) (parameterize ([current-use-bsp-scheduler? #t]) (run-to-quiescence net)))
(define (run-seq net) (parameterize ([current-use-bsp-scheduler? #f]) (run-to-quiescence net)))

;; a merge wrapper that counts calls whose result differs from old (a "change") and calls whose
;; result is a strict increase in the merge's own induced order (old ⊑ r iff merge(r, old) = r, r ≠ old)
(define (counting merge changes incs)
  (λ (old new)
    (define r (merge old new))
    (unless (equal? r old)
      (set-box! changes (add1 (unbox changes)))
      (when (equal? (merge r old) r) (set-box! incs (add1 (unbox incs)))))
    r))

;; ===== E1 =====
(define N 16)
(define (E1 order-kind)
  (define ch (box 0)) (define inc (box 0))
  (define m (counting (λ (a b) (max a b)) ch inc))
  (define-values (net0 t) (net-new-cell (make-prop-network 1000000) 0 (λ (a b) (max a b))))
  (define-values (net1 ss)
    (for/fold ([net net0] [ss '()]) ([i N])
      (define-values (n c) (net-new-cell net 0 m)) (values n (cons c ss))))
  (define s (list->vector (reverse ss)))
  (define-values (net2 j) (net-new-cell net1 0 m))
  (define (P i) (λ (n) (if (> (net-cell-read n t) 0) (net-cell-write n (vector-ref s i) (add1 i)) n)))
  (define (J n) (net-cell-write n j (for/fold ([acc 0]) ([c s]) (max acc (net-cell-read n c)))))
  (define net3 (for/fold ([n net2]) ([i N])
                 (let-values ([(n* _p) (net-add-propagator n (list t) (list (vector-ref s i)) (P i))]) n*)))
  (define-values (net4 _pj) (net-add-propagator net3 (vector->list s) (list j) J))
  (define net5 (net-cell-write net4 t 1))
  (set-box! ch 0) (set-box! inc 0)
  (define final
    (case order-kind
      [(bsp) (run-bsp net5)]
      [(drain) (run-seq net5)]
      [(J-after-each) (for/fold ([n net5]) ([i N]) (J ((P i) n)))]
      [(J-last) (J (for/fold ([n net5]) ([i N]) ((P i) n)))]))
  (list order-kind 'J= (net-cell-read final j) 'changes (unbox ch) 'strict-incs (unbox inc)))
(printf "== E1: changes to reach the SAME fixpoint (J = 16), by schedule\n")
(define e1 (for/list ([k '(bsp drain J-after-each J-last)]) (E1 k)))
(for ([r e1]) (printf "  ~a\n" r))
(let* ([cs (map (λ (r) (list-ref r 4)) e1)] [lo (apply min cs)] [hi (apply max cs)] [B (quotient (+ lo hi) 2)])
  (printf "  change counts range ~a..~a: a change-counted budget B=~a exhausts under ~a and not under ~a\n"
          lo hi B (for/list ([r e1] #:when (> (list-ref r 4) B)) (car r)) (for/list ([r e1] #:unless (> (list-ref r 4) B)) (car r))))
;; E1 with the BSP oracle's own batching vs ONE delta per message at K>1: the bound Σ heights (here
;; heights ≥ i+1 per s_i plus 16 for J) is what every schedule respects:
(printf "  Σ (values reached) bound = ~a (s_i reach i+1 => Σ = ~a, J reaches 16)\n" (+ (for/sum ([i N]) (add1 i)) 16) (for/sum ([i N]) (add1 i)))

;; ===== E2 =====
(define (lww a b) (if (eq? b 'none) a b))
(define (E2 sched fuel)
  (define ch (box 0)) (define inc (box 0))
  (define-values (net0 s) (net-new-cell (make-prop-network fuel) 0 (λ (a b) (max a b))))
  (define-values (net1 T) (net-new-cell net0 'none (counting lww ch inc)))
  (define (W v) (λ (n) (if (> (net-cell-read n s) 0) (net-cell-write n T v) n)))
  (define-values (net2 _1) (net-add-propagator net1 (list s T) (list T) (W 'a)))
  (define-values (net3 _2) (net-add-propagator net2 (list s T) (list T) (W 'b)))
  (define net4 (net-cell-write net3 s 1))
  (set-box! ch 0) (set-box! inc 0)
  (define final (case sched [(bsp) (run-bsp net4)] [(drain) (run-seq net4)]))
  (list sched 'fuel fuel 'T (net-cell-read final T) 'contradiction (net-contradiction? final)
        'changes-charged-to-T (unbox ch) 'strict-increases (unbox inc)))
(printf "== E2: fenced LWW cell T in a cycle with two monotone constant writers\n")
(for* ([sched '(bsp drain)] [fuel '(50 500)]) (printf "  ~a\n" (E2 sched fuel)))

;; ===== E3 =====
(printf "== E3: two forks of one template (relations.rkt:3117 forks one per solve)\n")
(let* ([tmpl (make-prop-network 1000)]
       [f1 (fork-prop-network tmpl 1000)]
       [f2 (fork-prop-network tmpl 1000)])
  (printf "  struct fields of prop-network: (hot warm cold) — no identity field\n")
  (printf "  cold eq? ~a; equal? ~a; cell-1 equal? ~a; fuel equal? ~a\n"
          (eq? (prop-network-cold f1) (prop-network-cold f2)) (equal? f1 f2)
          (equal? (net-cell-read f1 worldview-cache-cell-id) (net-cell-read f2 worldview-cache-cell-id))
          (equal? (net-cell-read f1 fuel-cell-id) (net-cell-read f2 fuel-cell-id))))

#lang racket/base
;;; W2-9 (PAR 4 D.3 wave 2). Read-only on the repo.
;;; Question: does DIRECT (P2) remove a class of lost updates that "P2-lite" (BSP kept; writes carried through the
;;; round as DELTAS instead of post-fire values; C10-3) does not?
;;; Three S0 dynamics on the REAL propagator.rkt, same network, same install order:
;;;   BSP      production inner loop, sequential executor (value-writes = post-fire value vs snapshot; undeclared
;;;            writes applied by direct set — fire-and-collect-writes :2897-2932, bulk-merge-writes :3037-3070)
;;;   BSP+Δ    P2-lite-full: an injected executor (current-parallel-executor, no rebuild) returns, per fire, the
;;;            DELTAS the fire passed to net-cell-write (logged by the probe's write wrapper), all applied through
;;;            the merge (157(a) included). This is the most favourable reading of "delta-carried writes".
;;;   DRAIN    run-to-quiescence-drain: fires write the live network in sequence (Gauss–Seidel), the K = 1 DIRECT
;;;            stand-in (P0 §4.4: it lacks fire-once and strata; none of these rows uses either).
;;; Rows (two writers p1, p2 triggered by the same source s, so BSP fires them in one round):
;;;   R1   per-key replacement map (merge-hasheq-replace shape: constraint store), declared outputs; each writer
;;;        updates a DIFFERENT key already present in the snapshot. Correct: both updates survive.
;;;   R1u  the same, outputs undeclared (the retry-bridge shape, metavar-store.rkt:1058-1064).
;;;   R2   read-modify-write on a replacement cell (cell-1's AND-NOT narrowing shape, 157(b)): p_i writes w & ~bit_i.
;;;        Correct (serializable): w & ~1 & ~2.
;;;   R5   undeclared writes into a JOIN (max) cell, values 5 then 3 in install order. Correct: 5.
;;;   R3   CONTROL: declared writes into a join (ior) cell, each writer sets its bit. Every dynamics must agree.
(require racket/list
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt")
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/champ.rkt")
                  champ-lookup))

(define delta-log (make-parameter #f))
(define (w! n cid v) (let ([b (delta-log)]) (when b (set-box! b (cons (cons cid v) (unbox b))))) (net-cell-write n cid v))

(define (delta-executor snap pids)
  (for/list ([pid pids])
    (define prop (champ-lookup (prop-network-propagators snap) (prop-id-hash pid) pid))
    (define b (box '()))
    (parameterize ([delta-log b] [current-bsp-fire-round? #t]) (fire-propagator prop snap))
    ;; every delta through the merge (value-writes), nothing by direct set
    ;; old-style write list: bulk-merge-writes applies each pair through net-cell-write (propagator.rkt:2995-3001, :3038-3041)
    (reverse (unbox b))))

(define (run net mode)
  (case mode
    [(bsp)  (parameterize ([current-use-bsp-scheduler? #t] [current-parallel-executor sequential-fire-all]) (run-to-quiescence net))]
    [(bspd) (parameterize ([current-use-bsp-scheduler? #t] [current-parallel-executor delta-executor]) (run-to-quiescence net))]
    [(drain) (parameterize ([current-use-bsp-scheduler? #f]) (run-to-quiescence net))]))

(define (hreplace old new) (for/fold ([o old]) ([(k v) (in-hash new)]) (hash-set o k v)))   ; per key, new wins
(define (repl old new) new)
(define (maxm a b) (max a b))

;; build: a source s (written after a first quiescence, so p1 and p2 fire in the same round), a target cell
(define (build init merge mk-p1 mk-p2 declared?)
  (define n0 (make-prop-network 100000))
  (define-values (n1 s) (net-new-cell n0 0 maxm))
  (define-values (n2 c) (net-new-cell n1 init merge))
  (define outs (if declared? (list c) '()))
  (define-values (n3 _1) (net-add-propagator n2 (list s) outs (mk-p1 s c)))
  (define-values (n4 _2) (net-add-propagator n3 (list s) outs (mk-p2 s c)))
  (values n4 s c))

(define (row name init merge mk-p1 mk-p2 declared? correct)
  (printf "~a\n" name)
  (for ([mode '(bsp bspd drain)])
    (define-values (net s c) (build init merge mk-p1 mk-p2 declared?))
    (define q (run net mode))
    (define r (run (net-cell-write q s 1) mode))
    (define v (net-cell-read r c))
    (printf "   ~a  ~a  ~a\n" (case mode [(bsp) "BSP     "] [(bspd) "BSP+Δ   "] [(drain) "DRAIN   "]) v
            (if (equal? v correct) "correct" "LOST UPDATE"))))

;; R1 / R1u: keys k1, k2 present at 'old; p1 sets k1 := 'new1, p2 sets k2 := 'new2 (each reads s as trigger)
(define (kp key val) (λ (s c) (λ (n) (if (zero? (net-cell-read n s)) n (w! n c (hasheq key val))))))
(define init-map (hasheq 'k1 'old 'k2 'old))
(define both (hasheq 'k1 'new1 'k2 'new2))
(row "R1  per-key replacement map, declared outputs, different keys" init-map hreplace (kp 'k1 'new1) (kp 'k2 'new2) #t both)
(row "R1u per-key replacement map, UNDECLARED outputs" init-map hreplace (kp 'k1 'new1) (kp 'k2 'new2) #f both)
;; R2: read-modify-write on a replacement cell
(define (clear bit) (λ (s c) (λ (n) (if (zero? (net-cell-read n s)) n (w! n c (bitwise-and (net-cell-read n c) (bitwise-not bit)))))))
(row "R2  read-modify-write, replacement merge (cell-1 AND-NOT shape), w0 = #b111" #b111 repl (clear 1) (clear 2) #t #b100)
;; R5: undeclared writes into a join cell
(define (put v) (λ (s c) (λ (n) (if (zero? (net-cell-read n s)) n (w! n c v)))))
(row "R5  undeclared writes into a JOIN (max) cell, 5 then 3" 0 maxm (put 5) (put 3) #f 5)
;; R3: control
(define (setbit bit) (λ (s c) (λ (n) (if (zero? (net-cell-read n s)) n (w! n c bit)))))
(row "R3  CONTROL join (ior), declared" 0 (λ (a b) (bitwise-ior a b)) (setbit 1) (setbit 2) #t 3)
(row "R5' undeclared writes into a JOIN (max) cell, 3 then 5 (install order reversed)" 0 maxm (put 3) (put 5) #f 5)

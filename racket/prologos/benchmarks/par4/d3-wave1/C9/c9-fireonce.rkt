#lang racket/base
;; C9 (d): fire-once on the REAL propagator.rkt (D.2 §6.4 'unstable latch' row, §6.6 self-clear, §7 epoch
;; records "the set of propagators fired ... depend on the program only, under H").
;;
;; D1  the proposed repair "latch only on a value that cannot grow (a ground type)": F is fire-once and
;;     writes out := x only once x is ground. x lives on a FENCED, non-inflationary cell (LWW), written
;;     first with ground 'a then with ground 'b. Is the latch stable?
;; D2  "productive" decides the self-clear (propagator.rkt:3534-3542: a write that DIFFERS FROM THE
;;     SNAPSHOT). Two STABLE fire-once writers A, B of the same constant into C. Epoch 1 raises the
;;     trigger t; epoch 2 raises it again. Which propagators fire in epoch 2, by scheduler?
(require racket/list
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt"))
(define (run-bsp net) (parameterize ([current-use-bsp-scheduler? #t]) (run-to-quiescence net)))
(define (run-seq net) (parameterize ([current-use-bsp-scheduler? #f]) (run-to-quiescence net)))
(define (mx a b) (max a b))
(define (lww a b) (if (eq? b 'none) a b))
(define (flat a b) (cond [(eq? a 'none) b] [(eq? b 'none) a] [(equal? a b) a] [else 'top]))

;; ===== D1 =====
(define (D1 sched install-order)
  ;; cells s (max), x (fenced LWW), out (flat), chain c1 c2 (max) to delay W2
  (define-values (n0 s) (net-new-cell (make-prop-network 10000) 0 mx))
  (define-values (n1 x) (net-new-cell n0 'none lww))
  (define-values (n2 out) (net-new-cell n1 'none flat))
  (define-values (n3 c1) (net-new-cell n2 0 mx))
  (define-values (n4 c2) (net-new-cell n3 0 mx))
  (define props
    (list (list 'W1 (list s) (list x) (λ (n) (if (> (net-cell-read n s) 0) (net-cell-write n x 'a) n)) #f)
          (list 'p1 (list s) (list c1) (λ (n) (net-cell-write n c1 (net-cell-read n s))) #f)
          (list 'p2 (list c1) (list c2) (λ (n) (net-cell-write n c2 (net-cell-read n c1))) #f)
          (list 'W2 (list c2) (list x) (λ (n) (if (> (net-cell-read n c2) 0) (net-cell-write n x 'b) n)) #f)
          (list 'F  (list x) (list out) (λ (n) (let ([v (net-cell-read n x)]) (if (eq? v 'none) n (net-cell-write n out v)))) #t)))
  (define n5 (for/fold ([n n4]) ([i install-order])
               (define p (list-ref props i))
               (define-values (n* _pid)
                 (if (list-ref p 4)
                     (net-add-fire-once-propagator n (list-ref p 1) (list-ref p 2) (list-ref p 3))
                     (net-add-propagator n (list-ref p 1) (list-ref p 2) (list-ref p 3))))
               n*))
  (define final ((if (eq? sched 'bsp) run-bsp run-seq) (net-cell-write n5 s 1)))
  (list sched install-order 'x (net-cell-read final x) 'out (net-cell-read final out)))
(printf "== D1: fire-once F latches on a GROUND value of a fenced LWW cell x (a then b)\n")
(for* ([sched '(bsp drain)] [o '((0 1 2 3 4) (4 3 2 1 0) (1 2 3 0 4))]) (printf "  ~a\n" (D1 sched o)))

;; ===== D2 =====
(define (D2 sched order)
  (define fires (make-hash))
  (define-values (n0 t) (net-new-cell (make-prop-network 10000) 0 mx))
  (define-values (n1 c) (net-new-cell n0 0 mx))
  (define (W name) (λ (n) (hash-update! fires name add1 0) (if (> (net-cell-read n t) 0) (net-cell-write n c 7) n)))
  (define n2 (for/fold ([n n1]) ([name order])
               (define-values (n* _p) (net-add-fire-once-propagator n (list t) (list c) (W name))) n*))
  (define run (if (eq? sched 'bsp) run-bsp run-seq))
  (define e1 (run (net-cell-write n2 t 1)))
  (define after1 (hash-copy fires))
  (define e2 (run (net-cell-write e1 t 2)))
  (list sched 'install order 'C (net-cell-read e2 c)
        'fires-epoch1 (sort (hash->list after1) symbol<? #:key car)
        'fired-in-epoch2 (sort (for/list ([(k v) (in-hash fires)] #:when (> v (hash-ref after1 k 0))) k) symbol<?)))
(printf "== D2: two STABLE fire-once writers A, B of the same constant; epoch 2 raises the trigger again\n")
(for* ([sched '(bsp drain)] [o '((A B) (B A))]) (printf "  ~a\n" (D2 sched o)))
;; D2' — P2's K = 1 executor as D.2 §6.6 specifies it: DIRECT on the live network, fire-once self-clears
;; "on first productive fire"; productive = the fire's write changed the LIVE cell (there is no snapshot).
(define (D2-direct order)
  (define-values (n0 t) (net-new-cell (make-prop-network 10000) 0 mx))
  (define-values (n1 c) (net-new-cell n0 0 mx))
  (define (W n) (if (> (net-cell-read n t) 0) (net-cell-write n c 7) n))
  (define cleared (make-hasheq))
  (define (epoch net)
    (for/fold ([net net] [fired '()]) ([name order] #:unless (hash-ref cleared name #f))
      (define net* (W net))
      (unless (equal? (net-cell-read net c) (net-cell-read net* c)) (hash-set! cleared name #t))
      (values net* (cons name fired))))
  (define-values (e1 f1) (epoch (net-cell-write n1 t 1)))
  (define-values (e2 f2) (epoch (net-cell-write e1 t 2)))
  (list 'K1-DIRECT 'install order 'fired-in-epoch1 (reverse f1) 'fired-in-epoch2 (reverse f2)))
(for ([o '((A B) (B A))]) (printf "  ~a\n" (D2-direct o)))

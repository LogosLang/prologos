#lang racket/base
;; W2-7 Q1(c): which :usage carrier preserves today's QTT verdicts?
;; (1) Today's verdict path does not read :usage at all (static; see the census and driver.rkt:1970/2199 checkQ-top/err).
;; (2) For the day QTT moves on-network: a lattice-level model of the one on-network rule that meets an unsolved
;;     multiplicity, make-usage-app-fire-fn (typing-propagators.rkt:1686-1701: total = func + m·arg, m := mw when m is
;;     a meta), on the shape `(fn [y :d] (f y))` where f : Pi(?m, …).  Schedules: ?m solved BEFORE the first fire,
;;     AFTER it (the fire re-fires), or NEVER (boundary ω default, zonk-mult-default).
;;     ORACLE = what checkQ decides on the zonked term: compatible(d, ?m_final·m1), with ?m_final = ω if never solved.
;;     Carriers: TODAY (ω inside the fire, add-usage merge) | CHAIN-LB (the chain's best sound abstraction, ⊥·x = m0,
;;     max merge) | CHAIN-STRICT (⊥·x = ⊥, max) | FLAT (⊥·m0 = m0, else ⊥; flat join) | INTERVAL ([m0,mw], join).
;;     Boundary: a coordinate still OPEN at quiescence gets the ω default as a boundary action (C4-6's proposal);
;;     a carrier that cannot tell open from closed (CHAIN-LB) reads its value as final.
(require racket/list
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/prelude.rkt")
                  mult-add mult-mul mult-leq compatible))
(define M '(m0 m1 mw))
(define (rk x) (case x [(bot) 0] [(m0) 1] [(m1) 2] [(mw) 3]))
(define (cmax a b) (if (>= (rk a) (rk b)) a b))
(define (cmin a b) (if (<= (rk a) (rk b)) a b))
;; one usage coordinate for y in (f y): func usage of y = m0 (f closed), arg usage = m1, scaled by f's mult m
;; carrier = (fire m-or-#f) -> value ; (merge old new) ; (open? v) ; (read v) -> M
(define carriers
  (list
   (list "TODAY (ω in fire, add-usage)"
         (λ (m) (mult-add 'm0 (mult-mul (or m 'mw) 'm1)))
         (λ (o n) (if (equal? o n) o (mult-add o n))) (λ (v) #f) values)
   (list "CHAIN-LB (⊥·x=m0, max)"
         (λ (m) (mult-add 'm0 (if m (mult-mul m 'm1) 'm0)))
         cmax (λ (v) #f) values)
   (list "CHAIN-STRICT (⊥·x=⊥, max)"
         (λ (m) (if m (mult-add 'm0 (mult-mul m 'm1)) 'bot))
         cmax (λ (v) (eq? v 'bot)) values)
   (list "FLAT (⊥·m0=m0 else ⊥; flat join)"
         (λ (m) (if m (mult-add 'm0 (mult-mul m 'm1)) 'bot))
         (λ (o n) (cond [(eq? o 'bot) n] [(eq? n 'bot) o] [(eq? o n) o] [else 'TOP])) (λ (v) (eq? v 'bot)) values)
   (list "INTERVAL ([m0,mw], join)"
         (λ (m) (if m (let ([t (mult-add 'm0 (mult-mul m 'm1))]) (cons t t))
                    (cons (mult-add 'm0 (mult-mul 'm0 'm1)) (mult-add 'm0 (mult-mul 'mw 'm1)))))
         (λ (o n) (cons (cmax (car o) (car n)) (cmin (cdr o) (cdr n))))
         (λ (v) (not (eq? (car v) (cdr v)))) car)))
(define (run carrier sched final-m)
  (define-values (name fire merge open? rd) (apply values carrier))
  ;; schedules: 'before = first fire already sees final-m; 'after = fire with #f, then re-fire with final-m;
  ;; 'never = fire with #f only, boundary applies ω default to an OPEN coordinate
  (define v
    (case sched
      [(before) (fire final-m)]
      [(after) (merge (fire #f) (fire final-m))]
      [(never) (let ([v0 (fire #f)]) (if (open? v0) (merge v0 (fire 'mw)) v0))]))
  (if (eq? v 'TOP) 'TOP (rd v)))
(define cases
  (for*/list ([d M] [sched '(before after never)] [fm (if (eq? sched 'never) '(#f) M)])
    (list d sched fm)))
(printf "W27 :usage carriers vs the checkQ oracle — ~a cases (declared d × schedule × final ?m)\n" (length cases))
(for ([c carriers])
  (define mism
    (for/list ([cs cases]
               #:unless (let* ([d (car cs)] [sched (cadr cs)] [fm (caddr cs)]
                               [oracle (compatible d (mult-mul (or fm 'mw) 'm1))]
                               [got (run c sched (or fm 'mw))]
                               [verdict (and (not (eq? got 'TOP)) (compatible d got))])
                          (eq? (and oracle #t) (and verdict #t))))
      cs))
  (printf "  ~a: verdict mismatches ~a/~a ~a\n" (car c) (length mism) (length cases)
          (if (null? mism) "" (format "e.g. ~s" (take mism (min 4 (length mism)))))))
(printf "  (case = (declared-mult-of-y schedule final-?m); #f = never solved, ω default)\n")
;; the decisive witness for CHAIN-LB: an ERASED y passed to an f whose mult is never solved
(printf "  witness: (fn [y :0] (f y)), f : Pi(?m,…), ?m never solved — oracle accepts? ~a ; CHAIN-LB accepts? ~a ; INTERVAL accepts? ~a\n"
        (and (compatible 'm0 (mult-mul 'mw 'm1)) #t)
        (and (compatible 'm0 (run (list-ref carriers 1) 'never 'mw)) #t)
        (and (compatible 'm0 (run (list-ref carriers 4) 'never 'mw)) #t))

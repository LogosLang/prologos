#lang racket/base
;; C9 (b) labelled reads on the REAL propagator.rkt + decision-cell.rkt.
;;
;; B1  tagged-cell-read drops the BASE when a matching entry exists (decision-cell.rkt:452-477):
;;     with an ACI domain merge (max), is a labelled read order-independent? (D.2 §6.3 row 3 says an
;;     order-independent read "needs an ACI domain merge"; D2L-1 says fires compute on labelled values.)
;;     Lattice-level alternative row: read = base ⊔ matching entries.
;; B2  a fire that reads under the LIVE worldview (cell-1) while an invalidation arrives in S0
;;     (the production guard shape relations.rkt:2331-2349 clears a bit in cell-1 from an S0 fire).
;;     Rows: today's cell-1 (replacement); D.2 row 1's two-phase set with a reader filtering by
;;     live = committed ∧ ¬invalidated; D2L-1's rule (static label) writing a PLAIN cell; the same
;;     writing a TAGGED cell.
;; B3  retry after invalidation under a grow-only invalidated set: can bit b be live again?
(require racket/list
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt")
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/decision-cell.rkt")
                  tagged-cell-value tagged-cell-value? tagged-cell-value-base tagged-cell-value-entries
                  make-tagged-merge tagged-cell-read))

(define (run-bsp net) (parameterize ([current-use-bsp-scheduler? #t]) (run-to-quiescence net)))
(define (run-seq net) (parameterize ([current-use-bsp-scheduler? #f]) (run-to-quiescence net)))
(define (max-merge a b) (max a b))

;; Build: cells (init . merge); props (ins outs fire) with fire : net cv -> net; returns net, cv, fires
(define (build cells props [order #f])
  (define-values (net cids)
    (for/fold ([net (make-prop-network 100000)] [cids '()]) ([c cells])
      (define-values (n cid) (net-new-cell net (car c) (cdr c)))
      (values n (cons cid cids))))
  (define cv (list->vector (reverse cids)))
  (define fires (for/list ([p props]) (λ (n) ((caddr p) n cv))))
  (define net*
    (for/fold ([net net]) ([i (or order (range (length props)))])
      (define p (list-ref props i))
      (define-values (n _pid)
        (net-add-propagator net (map (λ (k) (vector-ref cv k)) (car p))
                            (map (λ (k) (vector-ref cv k)) (cadr p)) (list-ref fires i)))
      n))
  (values net* cv fires))
;; explicit Gauss–Seidel sweeps in a given order until a sweep changes nothing
(define (sweep net fires order cv)
  (let loop ([net net] [n 0])
    (define net* (for/fold ([net net]) ([i order]) ((list-ref fires i) net)))
    (if (or (> n 50) (for/and ([c cv]) (equal? (net-cell-read-raw net c) (net-cell-read-raw net* c))))
        net* (loop net* (add1 n)))))
(define (rd net cv k) (net-cell-read net (vector-ref cv k)))
(define (wr net cv k v) (net-cell-write net (vector-ref cv k) v))
(define (under bm f) (λ (n cv) (parameterize ([current-worldview-bitmask bm]) (f n cv))))

;; ===== B1 =====
;; cells: 0 s (max), 1 T tagged (domain max), 2 out (max, plain)
;; A (unlabelled) writes T base 5;  B (label bit0) writes T 2 under bit 0;  C (label bit0) reads T -> out
(define (B1-props read-mode)
  (list (list '(0) '(1) (λ (n cv) (if (> (rd n cv 0) 0) (wr n cv 1 5) n)))
        (list '(0) '(1) (under 1 (λ (n cv) (if (> (rd n cv 0) 0) (wr n cv 1 2) n))))
        (list '(1) '(2) (under 1 (λ (n cv)
                                   (define v (case read-mode
                                               [(production) (rd n cv 1)]
                                               [(base-join)  (let ([raw (net-cell-read-raw n (vector-ref cv 1))])
                                                               (max (tagged-cell-value-base raw)
                                                                    (tagged-cell-read raw 1 max-merge)))]))
                                   (wr n cv 2 v))))))
(define B1-cells (list (cons 0 max-merge) (cons (tagged-cell-value 0 '()) (make-tagged-merge max-merge)) (cons 0 max-merge)))
(printf "== B1: labelled read with an ACI (max) domain merge; out = value C read under bit 0\n")
(for ([mode '(production base-join)])
  (define results
    (for/list ([o (list '(0 1 2) '(0 2 1) '(1 2 0) '(2 1 0))])
      (define-values (net cv fires) (build B1-cells (B1-props mode)))
      (define net0 (wr net cv 0 1))
      (list o (rd (sweep net0 fires o cv) cv 2))))
  (define-values (net cv fires) (build B1-cells (B1-props mode)))
  (define net0 (wr net cv 0 1))
  (define-values (netr cvr firesr) (build B1-cells (B1-props mode) '(2 1 0)))
  (define net0r (wr netr cvr 0 1))
  (printf "  read=~a  explicit orders (A=0,B=1,C=2) -> out: ~a | BSP ~a  DRAIN ~a  DRAIN(rev install) ~a  => ~a\n"
          mode results (rd (run-bsp net0) cv 2) (rd (run-seq net0) cv 2) (rd (run-seq net0r) cvr 2)
          (if (= 1 (length (remove-duplicates (append (map cadr results) (list (rd (run-bsp net0) cv 2) (rd (run-seq net0) cv 2) (rd (run-seq net0r) cvr 2))))))
              "order-independent" "ORDER-DEPENDENT")))
(let ()
  (define tv (tagged-cell-value 5 (list (cons 1 2))))
  (printf "  direct: (tagged-cell-read (tagged-cell-value 5 ((1 . 2))) wv=1 max) = ~a ; base ⊔ entry = 5\n"
          (tagged-cell-read tv 1 max-merge)))

;; ===== B2 =====
;; T is tagged: base 1, entry (bit0 . 7). Reader R writes the value it reads into out (max).
;; G is the guard: it invalidates bit 0 inside S0.
(printf "== B2: a reader filtering by the LIVE worldview while an S0 invalidation arrives\n")
(define (seed-T net cv) ; T base 1 (unconditional), entry (bit0 . 7)
  (parameterize ([current-worldview-bitmask 1]) (wr (parameterize ([current-worldview-bitmask 0]) (wr net cv 1 1)) cv 1 7)))
;; (i) today: cell-1 is the live worldview, cleared by AND-NOT (relations.rkt:2346-2349)
(define (B2-today order)
  (define cells (list (cons 0 max-merge) (cons (tagged-cell-value 0 '()) (make-tagged-merge max-merge)) (cons 0 max-merge)))
  (define props
    (list (list '(0) '() (λ (n cv) (if (> (rd n cv 0) 0)
                                        (let ([wv (net-cell-read n worldview-cache-cell-id)])
                                          (net-cell-write n worldview-cache-cell-id (bitwise-and wv (bitwise-not 1))))
                                        n)))
          (list '(1) '(2) (λ (n cv) (wr n cv 2 (rd n cv 1))))))      ; unlabelled reader: reads cell-1
  (define-values (net cv fires) (build cells props))
  (define net1 (net-cell-write (seed-T net cv) worldview-cache-cell-id 1))
  ;; R must also wake on cell-1: add it as an input
  (define-values (net2 _p) (net-add-propagator net1 (list worldview-cache-cell-id) (list (vector-ref cv 2)) (list-ref fires 1)))
  (define net3 (wr net2 cv 0 1))
  (list (rd (sweep net3 fires order cv) cv 2)))
;; (ii) D.2 row 1: committed (ior) and invalidated (ior) cells; R filters T by live
(define (B2-twophase order reader)
  (define (ior a b) (bitwise-ior a b))
  ;; cells: 0 s, 1 T tagged, 2 out, 3 committed, 4 invalidated, 5 outT (tagged out)
  (define cells (list (cons 0 max-merge) (cons (tagged-cell-value 0 '()) (make-tagged-merge max-merge)) (cons 0 max-merge)
                      (cons 0 ior) (cons 0 ior) (cons (tagged-cell-value 0 '()) (make-tagged-merge max-merge))))
  (define props
    (list (list '(0) '(4) (λ (n cv) (if (> (rd n cv 0) 0) (wr n cv 4 1) n)))            ; guard: invalidated |= bit0
          (case reader
            [(live) (list '(1 3 4) '(2)
                          (λ (n cv) (define live (bitwise-and (rd n cv 3) (bitwise-not (rd n cv 4))))
                                    (wr n cv 2 (parameterize ([current-worldview-bitmask live])
                                                 (if (zero? live) (tagged-cell-value-base (net-cell-read-raw n (vector-ref cv 1))) (rd n cv 1))))))]
            [(static-plain)  (list '(1) '(2) (under 1 (λ (n cv) (wr n cv 2 (rd n cv 1)))))]
            [(static-tagged) (list '(1) '(5) (under 1 (λ (n cv) (wr n cv 5 (rd n cv 1)))))])))
  (define-values (net cv fires) (build cells props))
  (define net1 (wr (seed-T net cv) cv 3 1))
  (define net2 (wr net1 cv 0 1))
  (define final (sweep net2 fires order cv))
  (define live (bitwise-and (rd final cv 3) (bitwise-not (rd final cv 4))))
  (case reader
    [(static-tagged) (list 'outT-read-at-boundary-under-live live '=
                           (tagged-cell-read (net-cell-read-raw final (vector-ref cv 5)) live max-merge)
                           'outT-raw (net-cell-read-raw final (vector-ref cv 5)))]
    [else (list 'out (rd final cv 2) 'live live)]))
(printf "  today (cell-1 replacement, reader reads cell-1): guard-first ~a  reader-first ~a\n" (B2-today '(0 1)) (B2-today '(1 0)))
(for ([r '(live static-plain static-tagged)])
  (printf "  D.2 two-phase, reader=~a: guard-first ~a  reader-first ~a\n" r (B2-twophase '(0 1) r) (B2-twophase '(1 0) r)))

;; ===== B3 =====
(printf "== B3: retry after invalidation, grow-only invalidated set (two-phase set, Shapiro 2011)\n")
(let* ([ior bitwise-ior]
       [committed (ior 0 1)] [invalidated (ior 0 1)]          ; assume b0, then b0 fails
       [committed2 (ior committed 1)]                        ; retry: re-assume b0
       [live (λ (c i) (bitwise-and c (bitwise-not i)))])
  (printf "  after assume b0: live=~a; after invalidate b0: live=~a; after re-assume b0: live=~a (b0 can never be live again)\n"
          (live committed 0) (live committed invalidated) (live committed2 invalidated))
  (printf "  a retry needs a FRESH bit: re-assume as b1 -> live=~a\n" (live (ior committed2 2) invalidated)))

;; ===== B4: the c1-overwrite.prologos Q3 shape at the lattice level =====
;; query scope base {x 1} (direct write, bitmask 0); clause-2 entry (bit1 . {x 2}).
(require (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/decision-cell.rkt")
                  scope-cell scope-cell-merge scope-cell-bindings scope-cell-bot))
(define (flat-scope-merge a b) ; D.2 P1a row 2: per key, equal => same, different => top
  (scope-cell (for/fold ([acc (scope-cell-bindings a)]) ([(k v) (in-hash (scope-cell-bindings b))])
                (define e (hash-ref acc k scope-cell-bot))
                (hash-set acc k (cond [(eq? e scope-cell-bot) v] [(eq? v scope-cell-bot) e] [(equal? e v) e] [else 'top])))))
(printf "== B4: Q3 of c1-overwrite.prologos — base {x 1}, entry (2 . {x 2}), read under clause-2's worldview 2\n")
(let* ([tv (tagged-cell-value (scope-cell (hasheq 'x 1)) (list (cons 2 (scope-cell (hasheq 'x 2)))))])
  (printf "  production read (drops base), today's LWW merge: ~a\n" (scope-cell-bindings (tagged-cell-read tv 2 scope-cell-merge)))
  (printf "  production read (drops base), D.2 row-2 flat merge: ~a   <- row 2 never sees the conflict\n" (scope-cell-bindings (tagged-cell-read tv 2 flat-scope-merge)))
  (printf "  base ⊔ entries, today's LWW merge: ~a\n" (scope-cell-bindings (scope-cell-merge (tagged-cell-value-base tv) (tagged-cell-read tv 2 scope-cell-merge))))
  (printf "  base ⊔ entries, D.2 row-2 flat merge: ~a   <- branch 2 inconsistent, as DFS says\n" (scope-cell-bindings (flat-scope-merge (tagged-cell-value-base tv) (tagged-cell-read tv 2 flat-scope-merge)))))

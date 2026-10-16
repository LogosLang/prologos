#lang racket/base
;; C9 (a): the fence boundary of D.2 §6.3 / §10.2 S-9, on the REAL propagator.rkt.
;;
;; D.2 says: at K = 1 "nothing changes (the order is deterministic)"; at K > 1 every
;; propagator with a fenced output runs in a deterministic BSP sub-run after the DIRECT
;; run quiesces, "the two alternate until neither has work"; S-9 expects an unfenced
;; fire reading a fenced cell to give the "same result as K = 1"; the P2/P3 replay
;; monitor claims "equal on every converted cell".
;;
;; Schedulers compared (all on the same network value):
;;   BSP      production run-to-quiescence-bsp (the replay oracle)
;;   DRAIN    production sequential drain (current-use-bsp-scheduler? #f)
;;   K1       explicit DIRECT FIFO over all propagators (D.2's K = 1: no fence)
;;   K>1F     explicit simulation of D.2's K > 1 fence: DIRECT FIFO over unfenced
;;            propagators to quiescence, then a BSP sub-run of the fenced ones
;;            (snapshot, fire all, merge in pid order, repeat until no fenced work,
;;            publish), alternating until neither has work. Executor interleaving
;;            inside the DIRECT half cannot matter here (its cells are joins).
(require racket/list racket/set
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt"))

(define (run-bsp net) (parameterize ([current-use-bsp-scheduler? #t]) (run-to-quiescence net)))
(define (run-seq net) (parameterize ([current-use-bsp-scheduler? #f]) (run-to-quiescence net)))

;; spec: cells = list of (init . merge); props = list of (list ins outs fire-fn fenced?)
;; fire-fn : (net cv) -> net, reading/writing through cv (vector of cell ids)
(define (build cells props)
  (define-values (net cids)
    (for/fold ([net (make-prop-network 100000)] [cids '()]) ([c cells])
      (define-values (n cid) (net-new-cell net (car c) (cdr c)))
      (values n (cons cid cids))))
  (define cv (list->vector (reverse cids)))
  (define net*
    (for/fold ([net net]) ([p props])
      (define-values (n _pid)
        (net-add-propagator net (map (λ (k) (vector-ref cv k)) (first p))
                            (map (λ (k) (vector-ref cv k)) (second p))
                            (λ (n) ((third p) n cv))))
      n))
  (values net* cv))

(define (raw net cv k) (net-cell-read-raw net (vector-ref cv k)))

;; ---- explicit DIRECT / fence simulator over the same fire functions ----
(define (deps-of props k) ; propagator indices reading cell k
  (for/list ([p props] [i (in-naturals)] #:when (memv k (first p))) i))
(define (outs-changed before after cv p)
  (for/list ([o (second p)] #:unless (equal? (raw before cv o) (raw after cv o))) o))

;; DIRECT FIFO restricted to the propagators in `allowed` (a set of indices)
(define (direct net cv props allowed wl counters)
  (let loop ([net net] [wl wl])
    (define wl* (filter (λ (i) (set-member? allowed i)) wl))
    (cond
      [(null? wl*) (values net (filter (λ (i) (not (set-member? allowed i))) wl))]
      [else
       (define i (car wl*))
       (define rest (remove i wl))           ; dedup FIFO
       (define p (list-ref props i))
       (define net2 ((third p) net cv))
       (hash-update! counters 'direct-fires add1 0)
       (define ch (outs-changed net net2 cv p))
       (define new (remove-duplicates (append-map (λ (k) (deps-of props k)) ch)))
       (loop net2 (append rest (filter (λ (j) (not (memv j rest))) new)))])))

;; BSP sub-run over `allowed`: rounds of (snapshot, fire all queued, merge in index order)
(define (bsp-sub net cv props allowed wl counters)
  (let loop ([net net] [wl wl])
    (define round (sort (remove-duplicates (filter (λ (i) (set-member? allowed i)) wl)) <))
    (define others (filter (λ (i) (not (set-member? allowed i))) wl))
    (cond
      [(null? round) (values net others)]
      [else
       (hash-update! counters 'subrun-rounds add1 0)
       (define writes ; list of (cell-k . raw-value) per fire, in index order
         (for/list ([i round])
           (define p (list-ref props i))
           (define r ((third p) net cv))
           (hash-update! counters 'fenced-fires add1 0)
           (for/list ([o (second p)] #:unless (equal? (raw net cv o) (raw r cv o)))
             (cons o (raw r cv o)))))
       (define net2 (for*/fold ([n net]) ([ws writes] [w ws])
                      (net-cell-write n (vector-ref cv (car w)) (cdr w))))
       (define ch (for/list ([k (in-range (vector-length cv))]
                             #:unless (equal? (raw net cv k) (raw net2 cv k))) k))
       (define new (remove-duplicates (append-map (λ (k) (deps-of props k)) ch)))
       (loop net2 (remove-duplicates (append others new)))])))

(define (k1 net cv props)
  (define c (make-hasheq))
  (define-values (n _) (direct net cv props (list->set (range (length props))) (range (length props)) c))
  (values n c))

(define (k>1-fence net cv props)
  (define c (make-hasheq))
  (define fenced (for/set ([p props] [i (in-naturals)] #:when (fourth p)) i))
  (define free (set-subtract (list->set (range (length props))) fenced))
  (let loop ([net net] [wl (range (length props))])
    (define-values (n1 wl1) (direct net cv props free wl c))
    (hash-update! c 'direct-quiescence-detections add1 0)
    (define-values (n2 wl2) (bsp-sub n1 cv props fenced wl1 c))
    (if (null? wl2)
        (values n2 c)
        (begin (hash-update! c 'alternations add1 0) (loop n2 wl2)))))

;; ---- lattices ----
(define (max-merge a b) (max a b))
(define (lww a b) (if (eq? b 'none) a b))                       ; a fenced, non-join merge
(define (set-merge a b) (sort (remove-duplicates (append a b)) symbol<?))  ; a join (converted)

(define (rd net cv k) (net-cell-read net (vector-ref cv k)))
(define (wr net cv k v) (net-cell-write net (vector-ref cv k) v))

;; ============ A1: unfenced reader F of a fenced cell T, downstream converted cell `out` ============
;; cells: 0 s, 1 a1, 2 a2, 3 a3 (max), 4 T (fenced LWW), 5 out (set-union join, CONVERTED)
(define A1-cells (list (cons 0 max-merge) (cons 0 max-merge) (cons 0 max-merge) (cons 0 max-merge)
                       (cons 'none lww) (cons '() set-merge)))
(define A1-props
  (list (list '(0) '(1) (λ (n cv) (wr n cv 1 (rd n cv 0))) #f)
        (list '(1) '(2) (λ (n cv) (wr n cv 2 (rd n cv 1))) #f)
        (list '(2) '(3) (λ (n cv) (wr n cv 3 (rd n cv 2))) #f)
        (list '(3) '(4) (λ (n cv) (if (> (rd n cv 3) 0) (wr n cv 4 'w1) n)) #t)   ; W1: late input
        (list '(1) '(4) (λ (n cv) (if (> (rd n cv 1) 0) (wr n cv 4 'w2) n)) #t)   ; W2: early input
        (list '(4) '(5) (λ (n cv) (let ([t (rd n cv 4)]) (if (eq? t 'none) n (wr n cv 5 (list t))))) #f)))

(define (row label net cv ks)
  (printf "  ~a  ~a\n" label (for/list ([k ks]) (raw net cv k))))

(printf "== A1: S-9 — unfenced F reads fenced T (LWW); out = set of T values F saw (a JOIN, converted)\n")
(let ()
  (define-values (net cv) (build A1-cells A1-props))
  (define net0 (wr net cv 0 1))
  (row "BSP   (replay oracle) T,out:" (run-bsp net0) cv '(4 5))
  (row "DRAIN (production)    T,out:" (run-seq net0) cv '(4 5))
  (define-values (nk1 c1) (k1 net0 cv A1-props))
  (row "K1    (DIRECT, no fence) T,out:" nk1 cv '(4 5))
  (define-values (nkf cf) (k>1-fence net0 cv A1-props))
  (row "K>1F  (fence alternation) T,out:" nkf cv '(4 5))
  (printf "  converted cell `out`: K>1F vs BSP ~a; K>1F vs K1 ~a\n"
          (if (equal? (raw nkf cv 5) (raw (run-bsp net0) cv 5)) "same" "DIFFER")
          (if (equal? (raw nkf cv 5) (raw nk1 cv 5)) "same" "DIFFER"))
  (printf "  fence counters: ~a\n" (sort (hash->list cf) symbol<? #:key car)))

;; ============ A1b: the same, with install order putting F between the two writers ============
;; props: p0 s->a1 | We a1->T (fenced) | F T->out | p1 a1->a2 | p2 a2->a3 | Wl a3->T (fenced)
(define A1b-props
  (list (list '(0) '(1) (λ (n cv) (wr n cv 1 (rd n cv 0))) #f)
        (list '(1) '(4) (λ (n cv) (if (> (rd n cv 1) 0) (wr n cv 4 'early) n)) #t)
        (list '(4) '(5) (λ (n cv) (let ([t (rd n cv 4)]) (if (eq? t 'none) n (wr n cv 5 (list t))))) #f)
        (list '(1) '(2) (λ (n cv) (wr n cv 2 (rd n cv 1))) #f)
        (list '(2) '(3) (λ (n cv) (wr n cv 3 (rd n cv 2))) #f)
        (list '(3) '(4) (λ (n cv) (if (> (rd n cv 3) 0) (wr n cv 4 'late) n)) #t)))
(printf "== A1b: S-9 with F installed between the writers (K = 1 sees both values of T)\n")
(let ()
  (define-values (net cv) (build A1-cells A1b-props))
  (define net0 (wr net cv 0 1))
  (define nb (run-bsp net0))
  (row "BSP   (replay oracle) T,out:" nb cv '(4 5))
  (row "DRAIN (production)    T,out:" (run-seq net0) cv '(4 5))
  (define-values (nk1 c1) (k1 net0 cv A1b-props))
  (row "K1    (DIRECT, no fence) T,out:" nk1 cv '(4 5))
  (define-values (nkf cf) (k>1-fence net0 cv A1b-props))
  (row "K>1F  (fence alternation) T,out:" nkf cv '(4 5))
  (printf "  converted cell `out`: K>1F vs K1 ~a (S-9 expects same); K>1F vs BSP ~a; K1 vs BSP ~a\n"
          (if (equal? (raw nkf cv 5) (raw nk1 cv 5)) "same" "DIFFER")
          (if (equal? (raw nkf cv 5) (raw nb cv 5)) "same" "DIFFER")
          (if (equal? (raw nk1 cv 5) (raw nb cv 5)) "same" "DIFFER")))

;; ============ A2: one fire writes a fenced AND an unfenced cell ============
;; X writes T (fenced) and U (unfenced max); G reads U writes V (max). Under the fence X runs
;; only in the sub-run, so U — an unfenced, converted cell — is also written only there.
(printf "== A2: a fire writing both a fenced cell T and an unfenced cell U\n")
(define A2-cells (list (cons 0 max-merge) (cons 'none lww) (cons 0 max-merge) (cons 0 max-merge)))
(define A2-props
  (list (list '(0) '(1 2) (λ (n cv) (let ([s (rd n cv 0)]) (if (> s 0) (wr (wr n cv 1 (list 't s)) cv 2 (+ s 10)) n))) #t)
        (list '(2) '(3) (λ (n cv) (wr n cv 3 (rd n cv 2))) #f)))
(let ()
  (define-values (net cv) (build A2-cells A2-props))
  (define net0 (wr net cv 0 1))
  (row "BSP   T,U,V:" (run-bsp net0) cv '(1 2 3))
  (define-values (nkf cf) (k>1-fence net0 cv A2-props))
  (row "K>1F  T,U,V:" nkf cv '(1 2 3))
  (printf "  fence counters: ~a\n" (sort (hash->list cf) symbol<? #:key car)))

;; ============ A3: a dependency chain crossing the fence d times ============
;; link i: D_i (unfenced) u_{i-1} -> v_i ; X_i (fenced, writes t_i AND u_i) v_i -> (t_i, u_i)
;; Fenced FIRES are exactly half; the alternation count grows with the crossing depth d.
(printf "== A3: chain crossing the fence d times (half the fires fenced): alternations vs BSP rounds\n")
(define (chain d)
  ;; cells: u0..ud (max) at 0..d, v1..vd at d+1..2d, t1..td (fenced LWW) at 2d+1..3d
  (define (u i) i) (define (v i) (+ d i)) (define (t i) (+ (* 2 d) i))
  (define cells (append (for/list ([_ (add1 d)]) (cons 0 max-merge))
                        (for/list ([_ d]) (cons 0 max-merge))
                        (for/list ([_ d]) (cons 'none lww))))
  (define props
    (append*
     (for/list ([i (in-range 1 (add1 d))])
       (list (list (list (u (sub1 i))) (list (v i)) (λ (n cv) (wr n cv (v i) (rd n cv (u (sub1 i))))) #f)
             (list (list (v i)) (list (t i) (u i))
                   (λ (n cv) (let ([x (rd n cv (v i))]) (if (> x 0) (wr (wr n cv (t i) (list 't x)) cv (u i) x) n))) #t)))))
  (values cells props (u d)))
(for ([d '(1 4 16 64)])
  (define-values (cells props last) (chain d))
  (define-values (net cv) (build cells props))
  (define net0 (wr net cv 0 1))
  (define rounds (box 0))
  (define nb (parameterize ([current-bsp-observer (λ (r) (set-box! rounds (add1 (unbox rounds))))]) (run-bsp net0)))
  (define-values (nkf cf) (k>1-fence net0 cv props))
  (printf "  d=~a  BSP rounds ~a | K>1F alternations ~a, DIRECT-quiescence detections ~a, sub-run rounds ~a, fenced fires ~a, direct fires ~a | u_d BSP=~a K>1F=~a\n"
          d (unbox rounds) (hash-ref cf 'alternations 0) (hash-ref cf 'direct-quiescence-detections 0)
          (hash-ref cf 'subrun-rounds 0) (hash-ref cf 'fenced-fires 0) (hash-ref cf 'direct-fires 0)
          (raw nb cv last) (raw nkf cv last)))

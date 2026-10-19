#lang racket/base
;;; W2-9 (PAR 4 D.3 wave 2, defender of P2 + BSP-as-oracle). Read-only on the repo.
;;; Question (C1-8): is a LIFTED KLEENE NETWORK (each cell carries a sparse value per Kleene depth; each lifted
;;; propagator reads depth n and writes depth n+1; any fair scheduler runs it) a sound and cheaper replacement for
;;; BSP's rounds as the replay oracle / canonical round trace?
;;;
;;; Everything runs on the REAL propagator.rkt (BSP = run-to-quiescence-bsp with the sequential executor;
;;; DRAIN = run-to-quiescence-drain, the Gauss-Seidel stand-in for DIRECT at K = 1).
;;; Free parameters, printed in the header:
;;;   install order  fwd | rev        (varies the drain's schedule; BSP's merge order)
;;;   lifted DEPS    decl | all       (lifted propagator depends on the lifted DECLARED inputs, or on every lifted cell)
;;;   lifted VIEW    depth | latest   (an undeclared read sees the cell's value at depth d, or its latest value)
;;;   H              height of the climbing 2-cycle (F4), the fixture whose depth grows with the lattice height
;;; The lifted propagator is STATELESS (Propagator Statelessness, DESIGN_PRINCIPLES.org:700): each fire evaluates the
;;; original fire function at every breakpoint depth of what it depends on. It cannot be one propagator per depth
;;; without creating propagators during S0 (G-1), and it cannot remember which depths it already did without state.
;;; Reference: KLEENE = x_{n+1} = x_n ⊔ ⊔_p f_p(x_n) over ALL propagators, ALL reads at depth n (computed in Racket).
(require racket/list racket/set racket/string
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt")
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/champ.rkt")
                  champ-lookup champ-insert))

;; ------------------------------------------------------------------ fixtures (spec level)
;; cell: (name init merge-sym) ; prop: (name (ins) (outs) fn (undeclared-reads))   fn : (name -> value) -> (listof (out . v))
(define (mmax a b) (max a b))
(define (munion a b) (set-union a b))
(define (mrepl a b) b)   ; replacement merge (non-join; the X4 / F1-band shape)
(define (merge-of m) (case m [(max) mmax] [(union) munion] [(repl) mrepl]))

(define (chain n)
  (list (for/list ([i (in-range (add1 n))]) (list (string->symbol (format "c~a" i)) (if (= i 0) 1 0) 'max))
        (for/list ([i (in-range n)])
          (define a (string->symbol (format "c~a" i))) (define b (string->symbol (format "c~a" (add1 i))))
          (list (string->symbol (format "p~a" i)) (list a) (list b) (λ (rd) (list (cons b (rd a)))) '()))))
(define fan-in
  (list (append (for/list ([i (in-range 1 5)]) (list (string->symbol (format "s~a" i)) i 'max)) (list (list 'o 0 'max)))
        (for/list ([i (in-range 1 5)])
          (define s (string->symbol (format "s~a" i)))
          (list (string->symbol (format "p~a" i)) (list s) (list 'o) (λ (rd) (list (cons 'o (rd s)))) '()))))
(define x3-cycle
  (list (list (list 'c0 (set 0) 'union) (list 'c1 (set) 'union) (list 'c2 (set) 'union) (list 'c3 (set) 'union))
        (list (list 'p0 '(c0) '(c1) (λ (rd) (list (cons 'c1 (set-add (rd 'c0) 1)))) '())
              (list 'p1 '(c1) '(c2) (λ (rd) (list (cons 'c2 (set-add (rd 'c1) 2)))) '())
              (list 'p2 '(c2) '(c0) (λ (rd) (list (cons 'c0 (rd 'c2)))) '())
              (list 'p3 '(c0) '(c3) (λ (rd) (list (cons 'c3 (rd 'c0)))) '()))))
(define (climb H)
  (list (list (list 'a 0 'max) (list 'b 0 'max))
        (list (list 'p '(a) '(b) (λ (rd) (list (cons 'b (min H (add1 (rd 'a)))))) '())
              (list 'q '(b) '(a) (λ (rd) (list (cons 'a (min H (add1 (rd 'b)))))) '()))))
(define diamond
  (list (list (list 'a 1 'max) (list 'b 0 'max) (list 'c 0 'max) (list 'd 0 'max))
        (list (list 'pb '(a) '(b) (λ (rd) (list (cons 'b (+ 1 (rd 'a))))) '())
              (list 'pc '(a) '(c) (λ (rd) (list (cons 'c (+ 2 (rd 'a))))) '())
              (list 'pd '(b c) '(d) (λ (rd) (list (cons 'd (+ (rd 'b) (rd 'c))))) '()))))
;; F5: E1 fails (C5-4): p declares s but also reads u, which q writes during the same epoch.
(define e1-undeclared
  (list (list (list 's 1 'max) (list 't 5 'max) (list 'u 0 'max) (list 'o 0 'max))
        (list (list 'q '(t) '(u) (λ (rd) (list (cons 'u (rd 't)))) '())
              (list 'p '(s) '(o) (λ (rd) (list (cons 'o (max (rd 's) (rd 'u))))) '(u)))))

;; F5b: E1 fails AND the undeclared cell changes at the same depth as the declared one, so whether the lifted
;; propagator sees u@1 depends on whether q's lifted fire ran first; nothing re-fires p when u@1 arrives.
(define e1-same-depth
  (list (list (list 's0 1 'max) (list 's 0 'max) (list 't 5 'max) (list 'u 0 'max) (list 'o 0 'max))
        (list (list 'r '(s0) '(s) (λ (rd) (list (cons 's (rd 's0)))) '())
              (list 'p '(s) '(o) (λ (rd) (list (cons 'o (max (rd 's) (rd 'u))))) '(u))
              (list 'q '(t) '(u) (λ (rd) (list (cons 'u (rd 't)))) '()))))
;; F7: a NON-JOIN cell (replacement merge), two writers in the same depth (X4's shape). The hypothesis is broken;
;; the question is whether the oracle stays a function of the program (install order) or of the schedule.
(define x4-nonjoin
  (list (list (list 't1 1 'max) (list 't2 1 'max) (list 'f 'none 'repl))
        (list (list 'q1 '(t1) '(f) (λ (rd) (list (cons 'f 'a))) '())
              (list 'q2 '(t2) '(f) (λ (rd) (list (cons 'f 'b))) '()))))

;; ------------------------------------------------------------------ Kleene reference (spec level, all reads at depth n)
(define (kleene spec)
  (define cells (car spec)) (define props (cadr spec))
  (define merges (for/hasheq ([c cells]) (values (car c) (merge-of (caddr c)))))
  (define x0 (for/hasheq ([c cells]) (values (car c) (cadr c))))
  (let loop ([x x0] [seq (list x0)])
    (define nx (for*/fold ([nx x]) ([p props] [w ((cadddr p) (λ (nm) (hash-ref x nm)))])
                 (hash-set nx (car w) ((hash-ref merges (car w)) (hash-ref nx (car w)) (cdr w)))))
    (if (equal? nx x) (reverse seq) (loop nx (cons nx seq)))))

;; ------------------------------------------------------------------ base network on the real propagator.rkt
(define evals (box 0))
(define (build-base spec order)
  (define cells (car spec)) (define props (if (eq? order 'rev) (reverse (cadr spec)) (cadr spec)))
  (define-values (net ids)
    (for/fold ([net (make-prop-network 1000000)] [ids (hasheq)]) ([c cells])
      (define-values (n* cid) (net-new-cell net (cadr c) (merge-of (caddr c))))
      (values n* (hash-set ids (car c) cid))))
  (define (fire-of p)
    (λ (n) (set-box! evals (add1 (unbox evals)))
       (for/fold ([n n]) ([w ((cadddr p) (λ (nm) (net-cell-read n (hash-ref ids nm))))])
         (net-cell-write n (hash-ref ids (car w)) (cdr w)))))
  (define net2
    (for/fold ([net net]) ([p props])
      (define-values (n* _pid) (net-add-propagator net (map (λ (x) (hash-ref ids x)) (cadr p))
                                                   (map (λ (x) (hash-ref ids x)) (caddr p)) (fire-of p)))
      n*))
  (values net2 ids))

(define (state-of net ids cells) (for/hasheq ([c cells]) (values (car c) (net-cell-read net (hash-ref ids (car c))))))

(define (run-base spec order sched)
  (define-values (net ids) (build-base spec order))
  (define cells (car spec))
  (define recs '())
  (set-box! evals 0)
  (define out
    (case sched
      [(bsp) (parameterize ([current-use-bsp-scheduler? #t] [current-parallel-executor #f]
                            [current-bsp-observer (λ (r) (set! recs (cons r recs)))])
               (run-to-quiescence net))]
      [(drain) (parameterize ([current-use-bsp-scheduler? #f] [current-bsp-observer #f]) (run-to-quiescence net))]))
  (define seq (cons (state-of net ids cells)
                    (for/list ([r (reverse recs)]) (state-of (bsp-round-network-snapshot r) ids cells))))
  (values (state-of out ids cells) seq (unbox evals)))

;; ------------------------------------------------------------------ the lifted network (C1-8), on the real propagator.rkt
;; lifted value: immutable hasheqv depth -> value, sparse (an entry only where the value changes); read at depth d =
;; the entry at the greatest stored depth <= d. Lifted merge: per-depth join, closed upward (the sequence stays
;; increasing), canonicalized. THEOREM (W2-9, below): with F monotone, the least fixpoint of the closed operator is
;; the Kleene sequence.
(define (lift-read m d)
  (define ks (sort (for/list ([k (in-hash-keys m)] #:when (<= k d)) k) >))
  (hash-ref m (car ks)))
(define (make-lifted-merge j broken?)
  (λ (old new)
    (define ks (sort (remove-duplicates (append (hash-keys old) (hash-keys new))) <))
    (define-values (res _prev)
      (for/fold ([res (hasheqv)] [run #f]) ([k ks])
        (define contribs (append (if (hash-has-key? old k) (list (hash-ref old k)) '())
                                 (if (hash-has-key? new k) (list (hash-ref new k)) '())))
        (define here (for/fold ([acc (if (or broken? (not run)) (car contribs) run)]) ([v contribs]) (j acc v)))
        ;; broken? = the POWER ROW: no upward closure (a later depth does not absorb an earlier one)
        (if (and run (equal? here run)) (values res run) (values (hash-set res k here) here))))
    (if (equal? res old) old res)))

(define (run-lifted spec order sched deps view #:broken [broken? #f] #:off-by-one [obo? #f])
  (define cells (car spec)) (define props (if (eq? order 'rev) (reverse (cadr spec)) (cadr spec)))
  (define-values (base ids) (build-base spec order))          ; template network: the original cells and fires
  (define base-props (for/hasheq ([p (cadr spec)]) (values (car p) p)))
  (define-values (L lids)
    (for/fold ([L (make-prop-network 1000000)] [lids (hasheq)]) ([c cells])
      (define-values (L* lc) (net-new-cell L (hasheqv 0 (cadr c)) (make-lifted-merge (merge-of (caddr c)) broken?)))
      (values L* (hash-set lids (car c) lc))))
  (define all-names (map car cells))
  (define lfires (box 0))
  (define (view-at Lnet p d)
    ;; the original network with every relevant cell set to its depth-d lifted value (VIEW=depth), or, for cells the
    ;; propagator does not declare, its latest lifted value (VIEW=latest)
    (define declared (append (cadr p) (caddr p)))
    (for/fold ([n base]) ([nm all-names])
      (define m (net-cell-read Lnet (hash-ref lids nm)))
      (define v (if (or (eq? view 'depth) (memq nm declared)) (lift-read m d) (lift-read m +inf.0)))
      (define cid (hash-ref ids nm))
      (define cells* (prop-network-cells n))
      (define cell (champ-lookup cells* (cell-id-hash cid) cid))
      (struct-copy prop-network n
        [warm (struct-copy prop-net-warm (prop-network-warm n)
                [cells (champ-insert cells* (cell-id-hash cid) cid (struct-copy prop-cell cell [value v]))])])))
  (define (lifted-fire p)
    (define dep-names (if (eq? deps 'all) all-names (cadr p)))
    (λ (Lnet)
      (set-box! lfires (add1 (unbox lfires)))
      (define bps (sort (remove-duplicates
                         (append* (for/list ([nm dep-names]) (hash-keys (net-cell-read Lnet (hash-ref lids nm))))))
                        <))
      (for/fold ([Lnet Lnet]) ([d bps])
        (set-box! evals (add1 (unbox evals)))
        (define v (view-at Lnet p d))
        (define rd (λ (nm) (net-cell-read v (hash-ref ids nm))))
        (for/fold ([Lnet Lnet]) ([w ((cadddr p) rd)])
          (define out-old (lift-read (net-cell-read Lnet (hash-ref lids (car w))) d))
          (net-cell-write Lnet (hash-ref lids (car w))
                          (hasheqv (if obo? d (add1 d)) ((merge-of (caddr (assq (car w) cells))) out-old (cdr w))))))))
  (define L2 (for/fold ([L L]) ([p props])
               (define dep-names (if (eq? deps 'all) all-names (cadr p)))
               (define-values (L* _) (net-add-propagator L (map (λ (x) (hash-ref lids x)) dep-names)
                                                         (map (λ (x) (hash-ref lids x)) (caddr p)) (lifted-fire p)))
               L*))
  (set-box! evals 0)
  (define out (case sched
                [(bsp) (parameterize ([current-use-bsp-scheduler? #t] [current-parallel-executor #f]) (run-to-quiescence L2))]
                [(drain) (parameterize ([current-use-bsp-scheduler? #f] [current-bsp-observer #f]) (run-to-quiescence L2))]))
  (define maps (for/hasheq ([c cells]) (values (car c) (net-cell-read out (hash-ref lids (car c))))))
  (define D (apply max (append* (map hash-keys (hash-values maps)))))
  (define seq (for/list ([d (in-range (add1 D))]) (for/hasheq ([c cells]) (values (car c) (lift-read (hash-ref maps (car c)) d)))))
  (define stored (for/sum ([m (hash-values maps)]) (hash-count m)))
  (values seq (unbox evals) (unbox lfires) stored))

;; ------------------------------------------------------------------ comparison
(define (pad seq n) (if (>= (length seq) n) seq (append seq (make-list (- n (length seq)) (last seq)))))
(define (seq-equal? a b) (let ([n (max (length a) (length b))]) (equal? (pad a n) (pad b n))))
(define (show-final s keys) (string-join (for/list ([k keys]) (format "~a=~a" k (let ([v (hash-ref s k)]) (if (set? v) (sort (set->list v) <) v)))) " "))

(define fixtures
  (list (list "F1 chain-6" (chain 6) '(c6))
        (list "F2 fan-in-4" fan-in '(o))
        (list "F3 X3-cycle" x3-cycle '(c0 c3))
        (list "F4 climb H=8" (climb 8) '(a b))
        (list "F4 climb H=16" (climb 16) '(a b))
        (list "F4 climb H=32" (climb 32) '(a b))
        (list "F6 diamond" diamond '(d))
        (list "F5 E1-undeclared-read" e1-undeclared '(o))
        (list "F5b E1, undeclared cell changes at the same depth" e1-same-depth '(o))
        (list "F7 non-join cell, two same-depth writers (Kleene n/a)" x4-nonjoin '(f))))

(printf "W2-9 lifted-Kleene probe | propagator.rkt at worktree HEAD | BSP = sequential executor; DRAIN = Gauss-Seidel (DIRECT K=1 stand-in)\n")
(printf "columns: K-depth = Kleene depth; final; for each run: seq= per-depth sequence equal to KLEENE? (=K) and to BSP's rounds? (=B); evals = original-fire evaluations; stored = (cell,depth) entries\n\n")
(for ([fx fixtures])
  (define name (car fx)) (define spec (cadr fx)) (define keys (caddr fx))
  (define K (kleene spec))
  (printf "== ~a   Kleene depth ~a, final ~a\n" name (sub1 (length K)) (show-final (last K) keys))
  (define bsp-seqs '())
  (for* ([order '(fwd rev)] [sched '(bsp drain)])
    (define-values (fin seq ev) (run-base spec order sched))
    (when (eq? sched 'bsp) (set! bsp-seqs (cons seq bsp-seqs)))
    (printf "   base  ~a ~a  final ~a  ~a  fires=~a\n" sched order (show-final fin keys)
            (if (eq? sched 'bsp) (format "rounds=~a rounds=K:~a" (sub1 (length seq)) (seq-equal? seq K))
                (format "final=K:~a" (equal? fin (last K))))
            ev))
  (define B (car bsp-seqs))
  (for* ([mode '((decl depth) (decl latest) (all depth))] [order '(fwd rev)] [sched '(bsp drain)])
    (define-values (seq ev lf st) (run-lifted spec order sched (car mode) (cadr mode)))
    (printf "   lift  deps=~a view=~a ~a ~a  final ~a  =K:~a =B:~a  lifted-fires=~a evals=~a stored=~a\n"
            (car mode) (cadr mode) sched order (show-final (last seq) keys) (seq-equal? seq K) (seq-equal? seq B) lf ev st))
  ;; power rows: the comparison must be able to fail
  (define-values (seqb evb lfb stb) (run-lifted spec 'fwd 'drain 'decl 'depth #:broken #t))
  (define-values (seqo evo lfo sto) (run-lifted spec 'fwd 'drain 'decl 'depth #:off-by-one #t))
  (printf "   POWER broken lift (no upward closure)  =K:~a final=K:~a | off-by-one lift (writes depth d)  =K:~a final=K:~a\n\n"
          (seq-equal? seqb K) (equal? (last seqb) (last K)) (seq-equal? seqo K) (equal? (last seqo) (last K))))

#lang racket/base
;;; W2-9 (PAR 4 D.3 wave 2). Read-only on the repo. ONE .prologos file per process:
;;;   racket w29-e1-census.rkt FILE.prologos        (FILE = "POWER" runs the constructed power rows only)
;;; Question: does production S0 satisfy C5-4's E1 (a fire's read set ⊆ its declared inputs, at cell AND at
;;; component-path level)? E1 is the hypothesis a lifted Kleene network over declared inputs needs (C1-8), and the
;;; hypothesis BSP's snapshot does NOT need (BSP gives every read, declared or not, the round-n value).
;;; Method (no rebuild): an injected executor (current-parallel-executor) fires each pid normally (the result the run
;;; uses), then re-fires it against perturbed copies of the same snapshot and compares the fire's CONTRIBUTION
;;; (per output: the changed component paths with their values, or the post value for non-map cells):
;;;   L0  same snapshot, unperturbed  -> a difference = the fire is not a function of the network (statelessness)
;;;   L1  poison every NON-declared cell that is some propagator's declared output (cells that can change in S0)
;;;   L3  poison every NON-declared cell
;;;   LP  poison, inside each declared input map cell (attribute maps), every component the propagator neither
;;;       declares as a watched path nor writes (path-level E1: filter-dependents-by-paths re-enqueues only on paths)
;;; A raise under poison counts as a dependence. Poison is a fresh opaque struct. Lower bound: a read that does not
;;; change the contribution is not seen; reads through the warm caches (worldview / fuel cell) are not poisoned.
(require racket/list racket/port json
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/driver.rkt")
                  process-file current-use-pnet-cache? current-pnet-write-enabled?)
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt")
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/champ.rkt")
                  champ-lookup champ-insert champ-fold))

(struct poison ())
(define POISON (poison))

(define (contribution snap res outs [excl (hash)])
  ;; per output: changed paths with values (maps) or the post value; paths in excl (cid . path) are ignored
  ;; (they were poisoned in the snapshot, so a change there is the MERGE reading poison, not the fire)
  (for/list ([cid outs])
    (define old (net-cell-read-raw snap cid))
    (define new (net-cell-read-raw res cid))
    (cond
      [(and (hash? old) (hash? new) (immutable? old) (immutable? new))
       (define ch0 (pu-value-diff old new))
       (define ch (and ch0 (filter (λ (p) (not (hash-ref excl (cons cid p) #f))) ch0)))
       (if (not ch) (cons cid new)
           (cons cid (sort (for/list ([p ch])
                             (format "~s" (cons p (if (pair? p)
                                                      (let ([r (hash-ref new (car p) #f)]) (and (hash? r) (hash-ref r (cdr p) 'absent)))
                                                      (hash-ref new p 'absent)))))
                           string<?)))]
      [else (cons cid (if (equal? old new) 'same new))])))
(define (written-paths snap res outs)
  (for*/list ([cid outs]
              [old (in-value (net-cell-read-raw snap cid))] [new (in-value (net-cell-read-raw res cid))]
              #:when (and (hash? old) (hash? new))
              [p (or (pu-value-diff old new) '())])
    (cons cid p)))

(define (fire-on net pid)
  (define prop (champ-lookup (prop-network-propagators net) (prop-id-hash pid) pid))
  (with-handlers ([(λ (e) #t) (λ (e) 'raised)])
    (parameterize ([current-bsp-fire-round? #t]) (fire-propagator prop net))))

(define (set-cells net f)   ; f : cid cell -> new value or #f (keep)
  (define cells (prop-network-cells net))
  (define cells*
    (champ-fold cells (λ (cid cell acc)
                        (define v (f cid cell))
                        (if v (champ-insert acc (cell-id-hash cid) cid (struct-copy prop-cell cell [value v])) acc))
                cells))
  (struct-copy prop-network net [warm (struct-copy prop-net-warm (prop-network-warm net) [cells cells*])]))

(define writable-cache (make-weak-hasheq))
(define (s0-writable net)
  (define props (prop-network-propagators net))
  (hash-ref! writable-cache props
             (λ () (champ-fold props (λ (pid p acc) (for/fold ([acc acc]) ([c (propagator-outputs p)]) (hash-set acc (cell-id-n c) #t))) (hasheqv)))))

(define poisoned-paths (box (hash)))   ; (cid . path) -> #t, filled by path-poison-map
(define (path-poison-map cid m keep)   ; keep : set of paths (k or (k . f)) to keep
  (for/hasheq ([(k rec) (in-hash m)])
    (values k (cond [(hash-ref keep k #f) rec]
                    [(and (hash? rec) (immutable? rec))
                     (for/hasheq ([(f v) (in-hash rec)])
                       (values f (if (hash-ref keep (cons k f) #f) v
                                     (begin (set-box! poisoned-paths (hash-set (unbox poisoned-paths) (cons cid (cons k f)) #t)) POISON))))]
                    [else (set-box! poisoned-paths (hash-set (unbox poisoned-paths) (cons cid k) #t)) POISON]))))

(define stats (make-hash))   ; level -> (fires . differing)
(define sites (make-hash))   ; (level . site) -> count
(define (bump! lvl diff? site)
  (define c (hash-ref stats lvl (cons 0 0)))
  (hash-set! stats lvl (cons (add1 (car c)) (+ (cdr c) (if diff? 1 0))))
  (when diff? (hash-set! sites (cons lvl site) (add1 (hash-ref sites (cons lvl site) 0)))))
(define (site-of prop) (format "~a" (object-name (propagator-fire-fn prop))))

(define (census-one snap pid)
  (define prop (champ-lookup (prop-network-propagators snap) (prop-id-hash pid) pid))
  (define outs (propagator-outputs prop)) (define ins (propagator-inputs prop))
  (define res (fire-on snap pid))
  (unless (eq? res 'raised)
    (define base (contribution snap res outs))
    (define site (site-of prop))
    (define (differs? net*)
      (define r* (fire-on net* pid))
      (or (eq? r* 'raised) (not (equal? base (contribution net* r* outs)))))
    (define (cmp lvl net*) (bump! lvl (differs? net*) site))
    ;; L0 first: an impure fire is counted there only, and the poison levels are skipped for it
    (define impure? (differs? snap))
    (bump! 'L0 impure? site)
    (unless impure?
    (define declared (for/hasheqv ([c (append ins outs)]) (values (cell-id-n c) #t)))
    (define w (s0-writable snap))
    (cmp 'L1 (set-cells snap (λ (cid cell) (and (not (hash-ref declared (cell-id-n cid) #f)) (hash-ref w (cell-id-n cid) #f) POISON))))
    (cmp 'L3 (set-cells snap (λ (cid cell) (and (not (hash-ref declared (cell-id-n cid) #f)) POISON))))
    ;; LP: only for inputs whose dependent entry for this pid carries component paths
    (define wp (written-paths snap res outs))
    (define path-inputs
      (for*/list ([c ins]
                  [cell (in-value (champ-lookup (prop-network-cells snap) (cell-id-hash c) c))]
                  #:unless (eq? cell 'none)
                  [e (in-value (champ-lookup (prop-cell-dependents cell) (prop-id-hash pid) pid))]
                  #:unless (eq? e 'none)
                  [paths (in-value (if (dependent-entry? e) (dependent-entry-paths e) e))]
                  #:when (and (list? paths) (pair? paths) (not (memq #f paths)) (hash? (prop-cell-value cell))))
        (cons c paths)))
    (when (pair? path-inputs)
      (set-box! poisoned-paths (hash))
      (define net*
        (for/fold ([n snap]) ([pi path-inputs])
          (define c (car pi))
          (define keep (for/fold ([h (for/hash ([p (cdr pi)]) (values p #t))]) ([x wp] #:when (equal? (car x) c)) (hash-set h (cdr x) #t)))
          (set-cells n (λ (cid cell) (and (equal? cid c) (path-poison-map c (prop-cell-value cell) keep))))))
      (define excl (unbox poisoned-paths))
      (define r* (fire-on net* pid))
      (cond
        [(eq? r* 'raised) (bump! 'LP-raised #t site)]
        [else
         (bump! 'LP (not (equal? (contribution snap res outs excl) (contribution net* r* outs excl))) site)])))))

(define (census-exec snap pids)
  (define results (for/list ([pid (in-list pids)] [idx (in-naturals 1)]) (fire-and-collect-writes snap pid idx)))
  (for ([pid (in-list pids)]) (census-one snap pid))
  results)

(define (report label extra)
  (printf "W29E1:~a\n"
          (jsexpr->string
           (hash-set* (for/hasheq ([(k v) (in-hash stats)])
                        (values k (hasheq 'fires (car v) 'differ (cdr v))))
                      'label label
                      'extra extra
                      'top_sites (for/list ([p (take (sort (hash->list sites) > #:key cdr) (min 25 (hash-count sites)))])
                                   (list (symbol->string (car (car p))) (cdr (car p)) (cdr p)))))))

(define arg (vector-ref (current-command-line-arguments) 0))
(cond
  [(equal? arg "POWER")
   ;; power rows: (a) undeclared CELL read (C5's K-UR shape) must differ at L1/L3, not at L0;
   ;;             (b) declared-only fire must differ nowhere; (c) undeclared PATH read must differ at LP only;
   ;;             (d) an impure fire (counter in a box) must differ at L0.
   (define maxm (λ (a b) (max a b)))
   (define hmerge (λ (a b) (for/fold ([a a]) ([(k v) (in-hash b)]) (hash-set a k (if (and (hash? v) (hash? (hash-ref a k #f))) (for/fold ([r (hash-ref a k)]) ([(f fv) (in-hash v)]) (hash-set r f fv)) v)))))
   (define n0 (make-prop-network 100000))
   (define-values (n1 s) (net-new-cell n0 1 maxm))
   (define-values (n2 u) (net-new-cell n1 4 maxm))
   (define-values (n3 o) (net-new-cell n2 0 maxm))
   (define-values (n4 m) (net-new-cell n3 (hasheq 'p1 (hasheq ':type 1 ':ctx 7) 'p2 (hasheq ':type 2)) hmerge))
   (define-values (n5 o2) (net-new-cell n4 0 maxm))
   (define-values (n6 o3) (net-new-cell n5 0 maxm))
   (define-values (n6b o4) (net-new-cell n6 0 maxm))
   (define-values (n7 _q) (net-add-propagator n6b (list u) (list u) (λ (n) n)))   ; makes u S0-writable
   (define-values (n8 pa) (net-add-propagator n7 (list s) (list o) (λ (n) (net-cell-write n o (max (net-cell-read n s) (net-cell-read n u))))))
   (define-values (n9 pb) (net-add-propagator n8 (list s) (list o2) (λ (n) (net-cell-write n o2 (net-cell-read n s)))))
   (define-values (n10 pc) (net-add-propagator n9 (list m) (list o3)
                                               (λ (n) (let ([r (hash-ref (net-cell-read n m) 'p1)]) (net-cell-write n o3 (+ (hash-ref r ':type) (hash-ref r ':ctx)))))
                                               #:component-paths (list (cons m (cons 'p1 ':type)))))
   (define-values (n10b pe) (net-add-propagator n10 (list m) (list o3)
                                               (λ (n) (let ([r (hash-ref (net-cell-read n m) 'p1)]) (net-cell-write n o3 (if (equal? (hash-ref r ':ctx) 7) 1 2))))
                                               #:component-paths (list (cons m (cons 'p1 ':type)))))
   (define ctr (box 0))
   (define-values (n11 pd) (net-add-propagator n10b (list s) (list o4) (λ (n) (set-box! ctr (add1 (unbox ctr))) (net-cell-write n o4 (unbox ctr)))))
   (for ([pid (list pa pb pc pe pd)] [nm '("a: undeclared cell read" "b: declared-only" "c: undeclared path read (raises on poison)" "e: undeclared path read (branches on it, no raise)" "d: impure (box counter)")])
     (hash-clear! stats) (hash-clear! sites)
     (census-one n11 pid)
     (printf "POWER ~a -> ~a\n" nm (for/list ([l '(L0 L1 L3 LP LP-raised)]) (list l (let ([c (hash-ref stats l #f)]) (if c (cdr c) '-))))))]
  [else
   (define preload "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/benchmarks/par4/preload-empty.prologos")
   (define (run-file* f exec)
     (parameterize ([current-output-port (open-output-nowhere)]
                    [current-use-pnet-cache? #t]
                    [current-pnet-write-enabled? #f]
                    [current-parallel-executor exec])
       (process-file f)))
   (run-file* preload sequential-fire-all)
   ;; control: fires and rounds with the plain sequential executor, to show the census does not perturb the run
   (define (count-run exec)
     (define rs (box '()))
     (parameterize ([current-bsp-round-stats rs]) (run-file* arg exec))
     (list (length (unbox rs)) (for/sum ([r (unbox rs)]) (car r))))
   (define ctl (count-run sequential-fire-all))
   (hash-clear! stats) (hash-clear! sites)
   (define cen (count-run census-exec))
   (report arg (hasheq 'rounds_fires_control ctl 'rounds_fires_census cen))])

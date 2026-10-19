#lang racket/base
;; W2-7 Q3: Role A vs Role B — the INSTALLED merge of every cell written in S0 (BSP rounds), over one suite test file.
;; Instrument: current-bsp-observer (no rebuild). For every cell-diff of every BSP round, the cell's installed merge is
;; looked up in the round's network (prop-network-merge-fns) and classified BEHAVIOURALLY, once per distinct closure:
;;   raw   mf(Nat, Bool):                      union => ROLE-A (type-lattice-merge)   type-top => ROLE-B (type-unify-or-top)
;;   tagged mf(tcv(Nat,∅), tcv(Bool,∅)), base: union => TAGGED-ROLE-A                type-top => TAGGED-ROLE-B
;;   eq? attribute-map-merge-fn => HUB (its :type facet merge is merge-classify-inhabit -> type-unify-or-top, Role B)
;;   anything else => its object-name.
;; Also: how many written values contain an APPLIED META (expr-app whose spine head is an expr-meta) — the third
;; blocked shape of Q2 — per class.
;; POWER rows (mode "power"): a cell made by sre-identify-sub-cell (sre-core.rkt:2277-2297) must classify ROLE-A; an
;; elab meta cell (elaborator-network.rkt:141-143, make-tagged-merge type-unify-or-top) TAGGED-ROLE-B; a raw
;; type-unify-or-top cell ROLE-B.
;; Run: racket w27-merge-census.rkt <tests/test-X.rkt> | power
(require racket/list racket/port racket/string
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt")
                  current-bsp-observer current-parallel-executor sequential-fire-all
                  bsp-round-network-snapshot bsp-round-cell-diffs cell-diff-cell-id cell-diff-new-value
                  prop-network-merge-fns cell-id-hash make-prop-network net-new-cell)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/champ.rkt")
                  champ-lookup)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/typing-propagators.rkt")
                  attribute-map-merge-fn)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/syntax.rkt")
                  expr-Nat expr-Bool expr-union? expr-app? expr-app-func expr-meta?)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/type-lattice.rkt")
                  type-top? type-lattice-merge type-unify-or-top)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/decision-cell.rkt")
                  tagged-cell-value tagged-cell-value? tagged-cell-value-base make-tagged-merge))

(define arg (vector-ref (current-command-line-arguments) 0))
(define role-cache (make-hasheq))
(define (try thunk) (with-handlers ([(λ (_) #t) (λ (e) 'RAISED)]) (thunk)))
(define (classify mf)
  (hash-ref! role-cache mf
   (λ ()
     (cond
       [(eq? mf 'none) "none"]
       [(eq? mf attribute-map-merge-fn) "HUB attribute-map (:type facet = Role B)"]
       [(eq? mf type-lattice-merge) "ROLE-A type-lattice-merge"]
       [(eq? mf type-unify-or-top) "ROLE-B type-unify-or-top"]
       [else
        (define r1 (try (λ () (mf (expr-Nat) (expr-Bool)))))
        (define r2 (try (λ () (mf (tagged-cell-value (expr-Nat) '()) (tagged-cell-value (expr-Bool) '())))))
        (define b2 (and (tagged-cell-value? r2) (tagged-cell-value-base r2)))
        (define nm (let ([n (object-name mf)]) (if n (regexp-replace #rx"^.*/" (format "~a" n) "") "anon")))
        (cond [(expr-union? r1) (format "ROLE-A (behavioural) ~a" nm)]
              [(and (not (eq? r1 'RAISED)) (type-top? r1)) (format "ROLE-B (behavioural) ~a" nm)]
              [(and b2 (expr-union? b2)) (format "TAGGED-ROLE-A ~a" nm)]
              [(and b2 (type-top? b2)) (format "TAGGED-ROLE-B ~a" nm)]
              [else (format "other ~a" nm)])]))))

(define (applied-meta? v [depth 0])
  (cond [(> depth 40) #f]
        [(expr-app? v) (or (let loop ([h v]) (if (expr-app? h) (loop (expr-app-func h)) (expr-meta? h)))
                           (applied-meta? (expr-app-func v) (add1 depth)))]
        [(struct? v) (for/or ([x (in-vector (struct->vector v) 1)]) (applied-meta? x (add1 depth)))]
        [(pair? v) (or (applied-meta? (car v) (add1 depth)) (applied-meta? (cdr v) (add1 depth)))]
        [(hash? v) (for/or ([(k x) (in-hash v)]) (applied-meta? x (add1 depth)))]
        [else #f]))

(define writes (make-hash)) (define cells (make-hash)) (define am-vals (make-hash)) (define rounds 0)
(define (observe r)
  (set! rounds (add1 rounds))
  (define snap (bsp-round-network-snapshot r))
  (define mfs (prop-network-merge-fns snap))
  (for ([d (in-list (bsp-round-cell-diffs r))])
    (define cid (cell-diff-cell-id d))
    (define cls (classify (champ-lookup mfs (cell-id-hash cid) cid)))
    (hash-update! writes cls add1 0)
    (hash-update! cells cls (λ (s) (hash-set s cid #t)) (hash))
    (when (regexp-match? #rx"^ROLE-A" cls) (eprintf "ROLE-A-WRITE round ~a cell ~a value ~a\n" rounds cid (let ([s (format "~s" (cell-diff-new-value d))]) (substring s 0 (min 160 (string-length s))))))
    (when (and (regexp-match? #rx"HUB" cls) (applied-meta? (cell-diff-new-value d)) (< (hash-ref am-vals cls 0) 1)) (eprintf "HUB-APPLIED-META ~a\n" (let ([s (format "~s" (cell-diff-new-value d))]) (let ([i (or (let ([m (regexp-match-positions #rx"expr-app #\\(struct:expr-meta" s)]) (and m (caar m))) 0)]) (substring s (max 0 (- i 200)) (min (string-length s) (+ i 200)))))))
    (when (and (regexp-match? #rx"ROLE-[AB]|HUB" cls) (applied-meta? (cell-diff-new-value d)))
      (hash-update! am-vals cls add1 0))))

(define (report label)
  (printf "W27-MERGE-CENSUS ~a\n  BSP rounds observed: ~a\n" label rounds)
  (for ([p (sort (hash->list writes) > #:key cdr)])
    (printf "  ~a: cells ~a, S0 writes ~a, writes holding an applied meta ~a\n" (car p) (hash-count (hash-ref cells (car p))) (cdr p)
            (hash-ref am-vals (car p) 0))))

(cond
  [(equal? arg "power")
   (define sre-core (list 'file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/sre-core.rkt"))
   (define unify (list 'file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/unify.rkt"))
   (define sre-identify-sub-cell (dynamic-require sre-core 'sre-identify-sub-cell))
   (define type-domain (with-handlers ([exn:fail? (λ (_) (dynamic-require unify #f) (eval 'type-sre-domain (module->namespace unify)))])
                         (dynamic-require unify 'type-sre-domain)))
   (define net0 (make-prop-network))
   (define-values (net1 c1) (sre-identify-sub-cell net0 type-domain (expr-Nat)))
   (define-values (net2 c2) (net-new-cell net1 (tagged-cell-value 'type-bot '()) (make-tagged-merge type-unify-or-top)))
   (define-values (net3 c3) (net-new-cell net2 'type-bot type-unify-or-top))
   (define mfs (prop-network-merge-fns net3))
   (for ([c (list c1 c2 c3)] [lbl '("sre-identify-sub-cell (expect ROLE-A)" "elab meta cell shape (expect TAGGED-ROLE-B)" "raw type-unify-or-top (expect ROLE-B)")])
     (printf "POWER ~a -> ~a\n" lbl (classify (champ-lookup mfs (cell-id-hash c) c))))]
  [else
   (parameterize ([current-bsp-observer observe]
                  [current-parallel-executor sequential-fire-all]
                  [current-output-port (open-output-nowhere)]
                  )
     (dynamic-require (list 'file arg) #f))
   (report (regexp-replace #rx"^.*/" arg ""))])

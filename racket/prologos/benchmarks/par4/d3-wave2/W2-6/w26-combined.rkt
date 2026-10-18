#lang racket/base
;; W2-6 (PAR 4 D.3 wave 2, CL-6) — the COMBINED worldview proposal at the lattice level, on the REAL substrate
;; (propagator.rkt's net-cell-write auto-tagging, promote-cell-to-tagged, run-to-quiescence under BSP and the drain;
;; decision-cell.rkt's tagged-cell-value / scope-cell structs and the production tagged-cell-read).
;; Adapted from C9's c9-labelled.rkt (B1, B4) and C4's c4-tagged-reader.rkt.
;;
;; Parts of the combined proposal, each switchable so the rows show which part each answer needs:
;;   (a) read = ev_W(t) = base ⊔ ⨆{v | b ⊆ W}                         (C4-1, C9-3)       :reader 'ev   vs 'prod
;;   row 2: per-key flat merge with ⊤ on the scope cell               (D.2 P1a row 2)    :dm flat      vs LWW
;;   (e) unify-fire writes each side into the other                    (C4-12, C9-5)      :unify 'both  vs 'today
;;   (b) no network-wide viewpoint: cell-1 is never the W of a fire    (C4-4, C2-4)       :cell1 'zero  vs 'all-bits
;;       (today solver-assume writes the OR of every assumption bit into cell-1 eagerly, atms.rkt:281)
;;   (c) labelled fires are closure-evaluated (C4-7) and write tagged outputs (C9-4)       :lift 'closure vs 'static
;;   boundary: answers read at each product of decision components (one alternative per site); a ⊤ under W is
;;       W's nogood; a ⊤ in the base is the query's failure (C9-5).  TODAY's boundary mirrors dissolve-solver-pu
;;       (relations.rkt:2869-2975: group entries by bound vars, product worldviews, production read).
;; Rows R1-R4 are DEFERRED 177's table; R5-R7 come from w26-crosssite.prologos; R8 is a completeness row.
;; Run: racket w26-combined.rkt
(require racket/list racket/set
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt")
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/decision-cell.rkt")
                  tagged-cell-value tagged-cell-value? tagged-cell-value-base tagged-cell-value-entries
                  make-tagged-merge tagged-cell-read scope-cell scope-cell? scope-cell-bindings scope-cell-bot
                  scope-cell-merge scope-cell-ref))

(define bot scope-cell-bot)
;; ---- domain merges -----------------------------------------------------------------------------------------
(define (flat-merge a b)  ;; D.2 P1a row 2: per key, equal => same, different => top
  (cond [(eq? a 'infra-bot) b] [(eq? b 'infra-bot) a]
        [(and (scope-cell? a) (scope-cell? b))
         (define ab (scope-cell-bindings a))
         (define m (for/fold ([acc ab]) ([(k v) (in-hash (scope-cell-bindings b))])
                     (define e (hash-ref acc k bot))
                     (hash-set acc k (cond [(eq? e bot) v] [(eq? v bot) e] [(equal? e v) e] [else 'top]))))
         (if (equal? m ab) a (scope-cell m))]
        [else b]))
;; ---- readers ------------------------------------------------------------------------------------------------
(define (read-ev raw dm W)   ;; (a)
  (if (tagged-cell-value? raw)
      (for/fold ([acc (tagged-cell-value-base raw)]) ([e (tagged-cell-value-entries raw)]
                                                     #:when (= (bitwise-and (car e) W) (car e)))
        (dm acc (cdr e)))
      raw))
(define (union-closure labels)
  (let loop ([acc '(0)] [ls (remove-duplicates labels)])
    (if (null? ls) (sort acc <) (loop (remove-duplicates (append acc (map (λ (w) (bitwise-ior w (car ls))) acc))) (cdr ls)))))

;; ---- one configuration ---------------------------------------------------------------------------------------
(struct cfg (name dm reader unify cell1 lift answer) #:transparent)
(define UNIFY-FIRES (box 0))
(define UNIFY-EVALS (box 0))
(define LWW scope-cell-merge)
(define TODAY   (cfg "TODAY (production)"                LWW        'prod 'today 'all-bits 'static  'prod))
(define A-ONLY  (cfg "(a) only"                          LWW        'ev   'today 'all-bits 'static  'ev))
(define A-R2    (cfg "(a)+row2"                          flat-merge 'ev   'today 'all-bits 'static  'ev))
(define A-R2-E  (cfg "(a)+row2+(e)"                      flat-merge 'ev   'both  'all-bits 'static  'ev))
(define A-R2-EB (cfg "(a)+row2+(e)+(b), static labels"   flat-merge 'ev   'both  'zero     'static  'ev))
(define FULL    (cfg "FULL (a)+row2+(e)+(b)+(c)"         flat-merge 'ev   'both  'zero     'closure 'ev))
(define FULL-noE (cfg "FULL minus (e)"                   flat-merge 'ev   'today 'zero     'closure 'ev))
(define FULL-noA (cfg "FULL minus (a) (prod read)"       flat-merge 'prod 'both  'zero     'closure 'ev-prodread))
(define FULL-LWW (cfg "FULL minus row2 (LWW)"            LWW        'ev   'both  'zero     'closure 'ev))
(define FULL-oldC1 (cfg "FULL but cell-1 = all bits"     flat-merge 'ev   'both  'all-bits 'closure 'ev))
(define FULL-ENTRIES (cfg "FULL with per-entry lift (additive unify)" flat-merge 'ev 'both 'zero 'entries 'ev))
(define FULL-ENTRIES-noE (cfg "per-entry lift with TODAY's unify (not additive)" flat-merge 'ev 'today 'zero 'entries 'ev))

;; ---- scenario: base writes (W=0, construction time, in goal order), branch sites, var-var unifies ------------
;; steps: (list 'base var val) | (list 'site var (val ...)) | (list 'unify v1 v2)
(struct scen (name steps qvars dfs) #:transparent)
(define SCENS
  (list (scen "R1 two: x=a, x=b"            '((base x a) (base x b))                 '(x)   '())
        (scen "R2 q3: x=a, pick x"          '((base x a) (site x (a b)))            '(x)   '(((x . a))))
        (scen "R3 clash: x=a, y=b, x=y"     '((base x a) (base y b) (unify x y))    '(x y) '())
        (scen "R4 agree: x=a, y=a, x=y"     '((base x a) (base y a) (unify x y))    '(x y) '(((x . a) (y . a))))
        (scen "R5 cross: pick x, pick y, x=y" '((site x (a b)) (site y (a b)) (unify x y)) '(x y) '(((x . a) (y . a)) ((x . b) (y . b))))
        (scen "R6 q3rev: pick x, x=b"       '((site x (a b)) (base x b))            '(x)   '(((x . b))))
        (scen "R7: pick x, y=a, x=y"        '((site x (a b)) (base y a) (unify x y)) '(x y) '(((x . a) (y . a))))
        (scen "R8: pick x, x=y (y free)"    '((site x (a b)) (unify x y))           '(x y) '(((x . a) (y . a)) ((x . b) (y . b))))))

(define (build c s install-rev?)
  (define-values (n0 S) (net-new-cell (make-prop-network 100000) (scope-cell (hasheq 'x bot 'y bot 'z bot)) (cfg-dm c)))
  (define sites (for/list ([st (scen-steps s)] #:when (eq? (car st) 'site)) st))
  ;; bit allocation: one bit per alternative, sites in order
  (define-values (site-bits _n)
    (for/fold ([acc '()] [k 0]) ([st sites])
      (define bs (for/list ([i (length (caddr st))]) (arithmetic-shift 1 (+ k i))))
      (values (append acc (list bs)) (+ k (length bs)))))
  (define all-bits (apply bitwise-ior 0 (apply append site-bits)))
  (define (rd net var W)
    (define raw (net-cell-read-raw net S))
    ;; W resolution mirrors net-cell-read (propagator.rkt:1601-1606): W = 0 falls back to cell-1. Under (b)
    ;; cell-1 stays 0, so the fallback is inert; under 'all-bits the (a) reader sees today's viewpoint.
    (define W* (if (zero? W) (net-cell-read-raw net worldview-cache-cell-id) W))
    (define sc (case (cfg-reader c)
                 [(ev) (read-ev raw (cfg-dm c) W*)]
                 [(prod) (parameterize ([current-worldview-bitmask W]) (net-cell-read net S))]))
    (if (scope-cell? sc) (scope-cell-ref sc var) bot))
  (define (wr net var val W)
    (if (eq? val bot) net
        (parameterize ([current-worldview-bitmask W]) (net-cell-write net S (scope-cell (hasheq var val))))))
  (define (unify-at net v1n v2n W)
    (set-box! UNIFY-EVALS (add1 (unbox UNIFY-EVALS)))
    (define v1 (rd net v1n W)) (define v2 (rd net v2n W))
    (case (cfg-unify c)
      [(today) (cond [(eq? v1 bot) (if (eq? v2 bot) net (wr net v1n v2 W))]   ;; relations.rkt:2112-2120
                     [(eq? v2 bot) (wr net v2n v1 W)]
                     [(equal? v1 v2) net]
                     [else net])]
      [(both) (wr (wr net v1n v2 W) v2n v1 W)]))
  (define (unify-fire v1n v2n)
    (λ (net)
      (set-box! UNIFY-FIRES (add1 (unbox UNIFY-FIRES)))
      (case (cfg-lift c)
        [(static) (unify-at net v1n v2n 0)]          ;; installed unlabelled: W = 0 (today: falls back to cell-1)
        [(closure)
         (define raw (net-cell-read-raw net S))
         (define labels (if (tagged-cell-value? raw) (map car (tagged-cell-value-entries raw)) '()))
         (for/fold ([n net]) ([W (union-closure labels)]) (unify-at n v1n v2n W))]
        [(entries)   ;; per-entry lift: legal when the fire is additive; (e)'s swap (v1,v2) -> (v2,v1) is
         (define raw (net-cell-read-raw net S))
         (define labels (if (tagged-cell-value? raw) (map car (tagged-cell-value-entries raw)) '()))
         (for/fold ([n net]) ([W (remove-duplicates (cons 0 labels))]) (unify-at n v1n v2n W))])))
  ;; construction: walk steps in goal order; collect propagator installs, apply base writes directly
  (define props '())   ;; (ins outs fire once?)
  (define net
    (for/fold ([net n0]) ([st (scen-steps s)])
      (case (car st)
        [(base) (wr net (cadr st) (caddr st) 0)]        ;; bitmask-0 direct write (relations.rkt:2141-2142)
        [(site)
         (define bs (list-ref site-bits (index-of sites st)))
         ;; solver-assume per alternative: cell-1 := OR of all bits so far (atms.rkt:281) when cell1='all-bits
         (define net1 (if (eq? (cfg-cell1 c) 'all-bits)
                          (net-cell-write net worldview-cache-cell-id
                                          (bitwise-ior (net-cell-read-raw net worldview-cache-cell-id) (apply bitwise-ior bs)))
                          net))
         (define net2 (promote-cell-to-tagged net1 S))
         (for ([b bs] [v (caddr st)])
           (define var (cadr st))
           (set! props (append props (list (list '() (list S) (λ (n) (wr n var v b)) #t)))))  ;; clause body under its label
         net2]
        [(unify) (set! props (append props (list (list (list S) (list S) (unify-fire (cadr st) (caddr st)) #f)))) net])))
  (define net*
    (for/fold ([net net]) ([p (if install-rev? (reverse props) props)])
      (define-values (n _pid)
        (if (cadddr p)
            (net-add-fire-once-propagator net (car p) (cadr p) (caddr p))
            (net-add-propagator net (car p) (cadr p) (caddr p))))
      n))
  (values net* S site-bits))

;; ---- boundary read (answers) ---------------------------------------------------------------------------------
(define (project sc qvars) (for/list ([q qvars]) (cons q (let ([v (if (scope-cell? sc) (scope-cell-ref sc q) bot)]) (if (eq? v bot) q v)))))
(define (answers c net S site-bits qvars)
  (define raw (net-cell-read-raw net S))
  (case (cfg-answer c)
    [(prod)   ;; mirror of dissolve-solver-pu (relations.rkt:2869-2975)
     (cond
       [(and (tagged-cell-value? raw) (pair? (tagged-cell-value-entries raw)))
        (define by-bm (make-hash))
        (for ([e (tagged-cell-value-entries raw)]) (hash-update! by-bm (car e) (λ (x) (scope-cell-merge x (cdr e))) (cdr e)))
        (define groups (make-hash))
        (for ([(bm v) (in-hash by-bm)])
          (define bound (for/seteq ([(k x) (in-hash (scope-cell-bindings v))] #:unless (eq? x bot)) k))
          (unless (set-empty? bound) (hash-update! groups bound (λ (s) (set-add s bm)) (seteq bm))))
        (define gs (hash-values groups))
        (define prods (if (null? gs) '()
                          (remove-duplicates (for/fold ([ps (set->list (car gs))]) ([g (cdr gs)])
                                               (for*/list ([p ps] [x (in-set g)]) (bitwise-ior p x))))))
        (define fw (net-cell-read-raw net worldview-cache-cell-id))
        (define dm (make-tagged-merge scope-cell-merge))
        (filter (λ (r) (not (for/and ([pr r]) (eq? (car pr) (cdr pr)))))
                (for/list ([bm prods] #:when (or (zero? bm) (= (bitwise-and bm fw) bm)))
                  (project (tagged-cell-read raw bm dm) qvars)))]
       [else (list (project (if (tagged-cell-value? raw) (tagged-cell-value-base raw) raw) qvars))])]
    [(ev ev-prodread)
     (define Ws (if (null? site-bits) '(0)
                    (for/fold ([ps '(0)]) ([bs site-bits]) (for*/list ([p ps] [b bs]) (bitwise-ior p b)))))
     (for*/list ([W Ws]
                 [sc (in-value (if (eq? (cfg-answer c) 'ev)
                                   (read-ev raw (cfg-dm c) W)
                                   (if (tagged-cell-value? raw) (tagged-cell-read raw W (make-tagged-merge (cfg-dm c))) raw)))]
                 [r (in-value (project sc qvars))]
                 #:unless (for/or ([pr r]) (eq? (cdr pr) 'top)))   ;; ⊤ under W = W's nogood; ⊤ in base kills all W
       r)]))

(define (canon rs) (sort (remove-duplicates (map (λ (r) (format "~s" r)) rs)) string<?))
(define (run-one c s sched)
  (define-values (net S site-bits) (build c s (eq? sched 'drain-rev)))
  (define final
    (case sched
      [(bsp) (parameterize ([current-use-bsp-scheduler? #t]) (run-to-quiescence net))]
      [(drain drain-rev) (parameterize ([current-use-bsp-scheduler? #f]) (run-to-quiescence net))]))
  (values (answers c final S site-bits (scen-qvars s)) (net-cell-read-raw final worldview-cache-cell-id)))

(define CFGS (list TODAY A-ONLY A-R2 A-R2-E A-R2-EB FULL FULL-noE FULL-noA FULL-LWW FULL-oldC1 FULL-ENTRIES FULL-ENTRIES-noE))
(define tally (make-hash))
(for ([c CFGS])
  (printf "== ~a\n" (cfg-name c))
  (for ([s SCENS])
    (define results (for/list ([sched '(bsp drain drain-rev)])
                      (define-values (rs c1) (run-one c s sched)) (list sched rs c1)))
    (define cs (map (λ (r) (canon (cadr r))) results))
    (define sched-indep (= 1 (length (remove-duplicates cs))))
    (define dfs-ok (andmap (λ (x) (equal? x (canon (scen-dfs s)))) cs))
    (hash-update! tally (cfg-name c) (λ (p) (list (+ (car p) (if dfs-ok 1 0)) (+ (cadr p) (if sched-indep 1 0)))) (list 0 0))
    (printf "  ~a ~a  ~a\n" (if dfs-ok "DFS-OK " "WRONG  ") (if sched-indep "sched-indep" "SCHED-DEP  ") (scen-name s))
    (unless (and dfs-ok sched-indep (not (eq? c TODAY)))
      (for ([r results]) (printf "      ~a: ~s~a\n" (car r) (cadr r)
                                 (if (and (memq (cfg-cell1 c) '(zero)) (not (zero? (caddr r)))) "  !! cell-1 written" ""))))
    (when (eq? (cfg-cell1 c) 'zero)
      (for ([r results]) (unless (zero? (caddr r)) (printf "      !! cell-1 nonzero under (b): ~a\n" (caddr r)))))))
(printf "\n== SUMMARY (rows matching DFS under all 3 schedules / rows schedule-independent), of ~a rows\n" (length SCENS))
(for ([c CFGS]) (printf "  ~a: ~a\n" (cfg-name c) (hash-ref tally (cfg-name c))))

;; ---- T1: coupling of (b) with BSP's Tier-1 dispatch (propagator.rkt:3410: cell-1 = 0 ⇒ "no speculation") ----
;; Under (b) cell-1 is never written, so the dispatch's "zero worldview" holds on speculative networks too. Scenario
;; (FULL config): pick z (assumptions exist), x=y with x, y free; run; then a LATE unconditional write x=c arrives
;; as a fire-once empty-input propagator (the shape of every bitmask-gated goal write, relations.rkt:2146-2165);
;; run again. DFS: {x c, y c, z a}, {x c, y c, z b}. Tier 1 fires the late write and clears the worklist, so the
;; unify fire (its dependent) never re-fires (DEFERRED 178's mechanism). Today solver-assume makes cell-1 nonzero
;; whenever an assumption exists, so this network would take Tier 2.
(printf "\n== T1: (b) × Tier-1 dispatch (FULL config; late fire-once write x=c after a first quiescence)\n")
(define late-scen (scen "T1" '((site z (a b)) (unify x y)) '(x y z) '()))
(for ([sched '(bsp bsp-control-plain drain)])
  (define-values (net S site-bits) (build FULL late-scen #f))
  (define (run n) (parameterize ([current-use-bsp-scheduler? (not (eq? sched 'drain))]) (run-to-quiescence n)))
  (define n1 (run net))
  (define-values (n2 _p)
    ((if (eq? sched 'bsp-control-plain) net-add-propagator net-add-fire-once-propagator) n1 '() (list S)
      (λ (n) (parameterize ([current-worldview-bitmask 0]) (net-cell-write n S (scope-cell (hasheq 'x 'c)))))))
  (set-box! UNIFY-FIRES 0)
  (define n3 (run n2))
  (printf "  ~a: cell-1 = ~a ; worklist before 2nd run = ~a ; unify fires in 2nd run = ~a ; answers ~s\n"
          sched (net-cell-read-raw n2 worldview-cache-cell-id) (length (prop-network-worklist n2)) (unbox UNIFY-FIRES)
          (answers FULL n3 S site-bits '(x y z))))
(printf "  DFS: ((x . c) (y . c) (z . a)) ((x . c) (y . c) (z . b))\n")

;; ---- cost of (c): unify evaluations per row (drain), closure vs per-entry lift -----------------------------
(printf "\n== cost of (c): unify evaluations per row under the drain (closure-evaluated vs per-entry lift)\n")
(for ([s SCENS])
  (define counts
    (for/list ([c (list FULL FULL-ENTRIES)])
      (set-box! UNIFY-EVALS 0)
      (run-one c s 'drain)
      (unbox UNIFY-EVALS)))
  (printf "  ~a: closure ~a, per-entry ~a\n" (scen-name s) (car counts) (cadr counts)))

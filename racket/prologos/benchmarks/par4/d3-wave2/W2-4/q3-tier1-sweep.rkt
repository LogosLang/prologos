#lang racket/base
;; W2-4 Q3 (PD-2 / DEFERRED 178): Tier-1 reach on the production construction path, no rebuild.
;; For ONE .prologos file: process it (populating the relation store), then for every relation R/n in the store
;; build the ATMS solver's network EXACTLY as solve-goal-propagator does (relations.rkt:3077-3158; internals
;; reached through module->namespace on the same module instances), for (a) the all-free query R(?v1..?vn) and
;; (b) R(c, ?v2..?vn) with c = arg 1 of R's first fact. On net3 (the network handed to run-to-quiescence) it
;; evaluates BSP's Tier-1 predicate (propagator.rkt:3411-3430, re-stated here), runs run-to-quiescence, and applies
;; the generic non-fixpoint detector to the result: re-fire every propagator once (fire-and-collect-writes against
;; the result) and report every propagator whose fire would change a cell.
;; POWER rows (printed first): C2's Tier-1 network (must be flagged) and its Tier-2 control (must not).
(require racket/list racket/port json
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/driver.rkt") process-file)
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt")
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/champ.rkt") champ-fold champ-lookup)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/metavar-store.rkt")
                  current-prop-net-box current-persistent-registry-net-box)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/performance-counters.rkt") current-perf-counters))
(define R "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/")
(define rel-ns (module->namespace (string->path (string-append R "relations.rkt"))))
(define (rel s) (eval s rel-ns))

;; ---- detector
(define (fr-field r i) (vector-ref (struct->vector r) i))
(define (nonfix net)
  (define pids (champ-fold (prop-network-propagators net) (lambda (k v acc) (cons k acc)) '()))
  (define nb (current-prop-net-box)) (define rb (current-persistent-registry-net-box))
  (parameterize ([current-prop-net-box (and nb (box (unbox nb)))]
                 [current-persistent-registry-net-box (and rb (box (unbox rb)))]
                 [current-perf-counters #f] [current-bsp-observer #f])
    (for/fold ([acc '()]) ([pid (in-list pids)])
      (define r (with-handlers ([exn:fail? (lambda (e) 'exn)]) (fire-and-collect-writes net pid 0)))
      (cond [(eq? r 'exn) (cons (list (prop-id-n pid) 'fire-raised) acc)]
            [(or (pair? (fr-field r 1)) (pair? (fr-field r 5)) (fr-field r 4))
             (cons (list (prop-id-n pid) (map (lambda (w) (cell-id-n (car w))) (append (fr-field r 1) (fr-field r 5)))) acc)]
            [else acc]))))
(define (tier1-eligible? net)
  (and (zero? (net-cell-read net worldview-cache-cell-id))
       (pair? (prop-network-worklist net))
       (not (prop-network-contradiction net))
       (> (net-cell-read net fuel-cell-id) 0)
       (let ([p (net-cell-read net naf-pending-cell-id)]) (or (not p) (and (hash? p) (hash-empty? p))))
       (for/and ([pid (in-list (prop-network-worklist net))])
         (define prop (champ-lookup (prop-network-propagators net) (prop-id-hash pid) pid))
         (and (not (eq? prop 'none))
              (= (bitwise-and (propagator-flags prop) (bitwise-ior PROP-FIRE-ONCE PROP-EMPTY-INPUTS))
                 (bitwise-ior PROP-FIRE-ONCE PROP-EMPTY-INPUTS))))))

;; ---- power rows: C2's network
(define (c2 fire-once?)
  (define net0 (make-prop-network))
  (define-values (net1 a) (net-new-cell net0 0 max))
  (define-values (net2 b) (net-new-cell net1 0 max))
  (define-values (net3 _p1) (net-add-propagator net2 (list a) (list b) (lambda (n) (net-cell-write n b (net-cell-read n a)))))
  (define net4 (run-to-quiescence net3))
  (define-values (net5 _p0)
    (if fire-once? (net-add-fire-once-propagator net4 '() (list a) (lambda (n) (net-cell-write n a 7)))
        (net-add-propagator net4 '() (list a) (lambda (n) (net-cell-write n a 7)))))
  (define out (run-to-quiescence net5))
  (printf "POWER c2 ~a: tier1-eligible ~a, B = ~a, non-fixpoint propagators ~s\n"
          (if fire-once? "fire-once (Tier 1)" "plain (Tier 2 control)") (tier1-eligible? net5) (net-cell-read out b) (nonfix out)))
(c2 #t) (c2 #f)

;; ---- the file
(define (file-name-from-path* f) (let-values ([(b n d) (split-path f)]) n))
(define file (vector-ref (current-command-line-arguments) 0))
(void (parameterize ([current-output-port (open-output-nowhere)] [current-error-port (open-output-nowhere)]) (process-file file)))
(define store ((rel 'current-relation-store)))
(define default-solver-config (rel 'default-solver-config))
(define cfg default-solver-config)
(define (solve-net goal-name goal-args query-vars)
  ;; relations.rkt:3077-3158, verbatim in structure
  (define st store)
  (define tier-1 ((rel 'tier-1-direct-fact-return) st goal-name goal-args query-vars))
  (cond
    [tier-1 'tier1-direct-fact-return]
    [(null? query-vars) 'dfs-0-arity]
    [else
     (define fuel 1000000)
     (define net0 ((rel 'fork-prop-network) ((rel 'get-or-create-solver-template) fuel) fuel))
     (define net0a (net-cell-write net0 relation-store-cell-id st))
     (define net0b (net-cell-write net0a config-cell-id cfg))
     (define-values (net-ctx ctx) ((rel 'make-solver-context) net0b))
     (define-values (net1 query-env) ((rel 'build-var-env) net-ctx query-vars))
     (define-values (net2 answer-cid) (net-new-cell net1 '() (rel 'merge-list-append)))
     (define scope-ref? (rel 'scope-ref?)) (define scope-ref-cid (rel 'scope-ref-cid))
     (define qcids (remove-duplicates (for/list ([ref (in-hash-values query-env)] #:when (scope-ref? ref)) (scope-ref-cid ref))))
     (define net2a (for/fold ([n net2]) ([cid (in-list qcids)]) ((rel 'promote-cell-to-tagged) n cid)))
     (define net3 ((rel 'install-goal-propagator) net2a ((rel 'goal-desc) 'app (list goal-name goal-args)) query-env answer-cid ctx))
     net3]))
(define counts (make-hasheq))
(define (inc! k) (hash-set! counts k (add1 (hash-ref counts k 0))))
(define examples '())
(parameterize ([current-use-bsp-scheduler? #t]
               [(rel 'current-is-eval-fn) (or ((rel 'current-is-eval-fn)) (lambda (x) x))]
               [(rel 'current-relation-store) store])
  (for ([(name ri) (in-hash store)])
    (define arity ((rel 'relation-info-arity) ri))
    (when (and (exact-positive-integer? arity) (<= arity 6))
      (define vars (for/list ([i arity]) (string->symbol (format "w24v~a" i))))
      (define facts (append* (for/list ([v ((rel 'relation-info-variants) ri)]) ((rel 'variant-info-facts) v))))
      (define queries
        (append (list (cons vars vars))
                (if (and (pair? facts) (pair? ((rel 'fact-row-terms) (car facts))))
                    (list (cons (cons (car ((rel 'fact-row-terms) (car facts))) (cdr vars)) (cdr vars)))
                    '())))
      (for ([q (in-list queries)])
        (inc! 'queries)
        (define r (with-handlers ([exn:fail? (lambda (e) (list 'raised (exn-message e)))]) (solve-net name (car q) (cdr q))))
        (cond
          [(symbol? r) (inc! r)]
          [(pair? r) (inc! 'build-raised)]
          [else
           (define t1? (tier1-eligible? r))
           (inc! (if t1? 'tier1-entered 'tier2-entered))
           (define out (with-handlers ([exn:fail? (lambda (e) #f)]) (run-to-quiescence r)))
           (cond
             [(not out) (inc! 'run-raised)]
             [else
              (define bad (nonfix out))
              (when (pair? bad)
                (inc! (if t1? 'tier1-nonfixpoint 'tier2-nonfixpoint))
                (when (< (length examples) 5) (set! examples (cons (list name (car q) t1? (take bad (min 3 (length bad)))) examples))))
              (when t1?
                ;; how many propagators did the Tier-1 network carry beyond the flushed ones (potential dependents)?
                (define nprops (champ-fold (prop-network-propagators r) (lambda (k v acc) (add1 acc)) 0))
                (define nwl (length (prop-network-worklist r)))
                (when (> nprops nwl) (inc! 'tier1-with-other-propagators)))])])))))
(printf "W24Q3 ~a ~a examples ~s\n" (path->string (file-name-from-path* file)) (jsexpr->string (for/hasheq ([(k v) (in-hash counts)]) (values k v))) examples)

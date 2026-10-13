#lang racket/base
;; sw24-probe.rkt <new racket/prologos> <old-regenerated racket/prologos> <stale dep-graph.rkt copy>
;; 1. Cost: warm derivation (what a runner pays) ×5, full scan (no cache) ×3 — CPU ms in-process.
;; 2. Equivalence: the derived graph vs the data the OLD `update-deps --write` regenerates, layer by layer.
;; 3. Impact of the stale graph: for a change to each root source module and each library module,
;;    affected tests selected by the STALE stored graph vs the derived one (both through
;;    compute-affected-tests with #:project-root, as the runner calls it).
(require racket/list racket/set racket/port)
(define-values (new-root old-root stale-path) (apply values (vector->list (current-command-line-arguments))))
(define (mod root) (list 'file (string-append root "/tools/dep-graph.rkt")))
(define N (mod new-root))
(define derive (dynamic-require N 'derive-dep-graph))
(define cdg (dynamic-require N 'current-dep-graph))
(define acc (for/list ([f '(dep-graph-source-deps dep-graph-test-deps dep-graph-prologos-lib-deps dep-graph-test-prologos-deps)])
              (dynamic-require N f)))
(define (cpu thunk) (define t0 (current-process-milliseconds)) (thunk) (- (current-process-milliseconds) t0))
(derive new-root) ; ensure warm
(printf "warm derivation CPU ms: ~a\n" (for/list ([i 5]) (cpu (λ () (derive new-root)))))
(printf "full scan (no cache) CPU ms: ~a\n" (for/list ([i 3]) (cpu (λ () (derive new-root #:cache-path #f)))))
;; 2. equivalence with the old regeneration
(define O (mod old-root))
(define old-layers (for/list ([n '(source-deps test-deps prologos-lib-deps test-prologos-deps)]) (dynamic-require O n)))
(define g (cdg))
(define new-layers (for/list ([a acc]) (a g)))
(define new-td? (dynamic-require N 'test-dep?)) (define new-td-mods (dynamic-require N 'test-dep-source-modules)) (define new-td-drv (dynamic-require N 'test-dep-uses-driver?))
(define old-td-mods (dynamic-require O 'test-dep-source-modules)) (define old-td-drv (dynamic-require O 'test-dep-uses-driver?)) (define old-td? (dynamic-require O 'test-dep?))
(define (norm v td? mods drv) (if (td? v) (list (sort (mods v) symbol<?) (drv v)) (sort v symbol<?)))
(for ([name '(source-deps test-deps prologos-lib-deps test-prologos-deps)] [o old-layers] [n new-layers])
  (define keys (remove-duplicates (append (hash-keys o) (hash-keys n))))
  (define diffs (for/list ([k keys]
                           #:unless (let ([a (hash-ref o k #f)] [b (hash-ref n k #f)])
                                      (and a b (equal? (norm a old-td? old-td-mods old-td-drv) (norm b new-td? new-td-mods new-td-drv)))))
                  k))
  (printf "~a: old-regenerated ~a, derived ~a, differing keys ~a ~a\n" name (hash-count o) (hash-count n) (length diffs)
          (if (null? diffs) "" (take diffs (min 5 (length diffs))))))
;; 3. impact of the stale stored graph
(define S (list 'file stale-path))
(define caf-old (dynamic-require S 'compute-affected-tests))
(define cs-old (dynamic-require S 'changed-source)) (define cp-old (dynamic-require S 'changed-prologos))
(define caf-new (dynamic-require N 'compute-affected-tests))
(define cs-new (dynamic-require N 'changed-source)) (define cp-new (dynamic-require N 'changed-prologos))
(define (impact label keys mk-old mk-new)
  (define rows
    (for/list ([k keys])
      (define o (list->seteq (parameterize ([current-error-port (open-output-nowhere)])
                               (caf-old (list (mk-old k)) #:project-root new-root))))
      (define n (list->seteq (caf-new (list (mk-new k)) #:graph g)))
      (list k (set-count n) (set-count (set-subtract n o)) (set-count (set-subtract o n)))))
  (define affected-any (filter (λ (r) (> (cadr r) 0)) rows))
  (define missed (filter (λ (r) (> (caddr r) 0)) rows))
  (printf "~a: ~a changeable modules; ~a select ≥1 test; for ~a of them the stale graph MISSED tests: ~a missed of ~a selected in total; ~a extra (stale) selections\n"
          label (length rows) (length affected-any) (length missed)
          (apply + (map caddr rows)) (apply + (map cadr rows)) (apply + (map cadddr rows)))
  (for ([r (take (sort missed > #:key caddr) (min 8 (length missed)))])
    (printf "    ~a: derived selects ~a, stale missed ~a\n" (car r) (cadr r) (caddr r))))
(impact "source modules" (sort (hash-keys (first new-layers)) symbol<?) cs-old cs-new)
(impact "library modules" (sort (hash-keys (third new-layers)) symbol<?) cp-old cp-new)

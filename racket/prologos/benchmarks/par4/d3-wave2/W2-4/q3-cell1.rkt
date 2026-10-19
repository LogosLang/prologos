#lang racket/base
;; W2-4 Q3 follow-up: the detector's only flags on the production construction path are propagator 0 writing
;; cell 1 (the worldview cache) after relations with NAF. Is the flag real, and does it matter for answers?
;; For relation NAME of FILE (all-free query): build net3 as solve-goal-propagator does, run, then
;;  (i) print cell 1 and what propagator 0 would write;
;; (ii) dissolve answers from the result, and from the result after propagator 0 is re-fired (S0 re-run).
(require racket/list racket/port
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/driver.rkt") process-file)
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt")
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/champ.rkt") champ-lookup))
(define R "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/")
(define rel-ns (module->namespace (string->path (string-append R "relations.rkt"))))
(define (rel s) (eval s rel-ns))
(define file (vector-ref (current-command-line-arguments) 0))
(define name (string->symbol (vector-ref (current-command-line-arguments) 1)))
(void (parameterize ([current-output-port (open-output-nowhere)] [current-error-port (open-output-nowhere)]) (process-file file)))
(define store ((rel 'current-relation-store)))
(define cfg (rel 'default-solver-config))
(define ri (hash-ref store name))
(define arity ((rel 'relation-info-arity) ri))
(define vars (for/list ([i arity]) (string->symbol (format "v~a" i))))
(parameterize ([current-use-bsp-scheduler? #t]
               [(rel 'current-is-eval-fn) (or ((rel 'current-is-eval-fn)) (lambda (x) x))]
               [(rel 'current-relation-store) store])
  (define fuel 1000000)
  (define net0 ((rel 'fork-prop-network) ((rel 'get-or-create-solver-template) fuel) fuel))
  (define net0b (net-cell-write (net-cell-write net0 relation-store-cell-id store) config-cell-id cfg))
  (define-values (net-ctx ctx) ((rel 'make-solver-context) net0b))
  (define-values (net1 query-env) ((rel 'build-var-env) net-ctx vars))
  (define-values (net2 answer-cid) (net-new-cell net1 '() (rel 'merge-list-append)))
  (define qcids (remove-duplicates (for/list ([ref (in-hash-values query-env)] #:when ((rel 'scope-ref?) ref)) ((rel 'scope-ref-cid) ref))))
  (define net2a (for/fold ([n net2]) ([cid qcids]) ((rel 'promote-cell-to-tagged) n cid)))
  (define net3 ((rel 'install-goal-propagator) net2a ((rel 'goal-desc) 'app (list name vars)) query-env answer-cid ctx))
  (define net5 (run-to-quiescence net3))
  (define pidn (string->number (or (getenv "PID") "0")))
  (define p0 (champ-lookup (prop-network-propagators net5) (prop-id-hash (prop-id pidn)) (prop-id pidn)))
  (define fr (fire-and-collect-writes net5 (prop-id pidn) 0))
  (printf "propagator ~a inputs ~a outputs ~a flags ~a ; re-fire: value-writes ~s undeclared-writes ~s\n" pidn
          (map cell-id-n (propagator-inputs p0)) (map cell-id-n (propagator-outputs p0)) (propagator-flags p0)
          (map (lambda (w) (cell-id-n (car w))) (vector-ref (struct->vector fr) 1))
          (map (lambda (w) (cons (cell-id-n (car w)) (cdr w))) (vector-ref (struct->vector fr) 5)))
  (define out-c (if (pair? (propagator-outputs p0)) (car (propagator-outputs p0)) (car (car (vector-ref (struct->vector fr) 5)))))
  (printf "output cell ~a merge ~a\n  value after run:    ~s\n" (cell-id-n out-c)
          (champ-lookup (prop-network-merge-fns net5) (cell-id-hash out-c) out-c) (net-cell-read-raw net5 out-c))
  (printf "  value after refire: ~s\n" (net-cell-read-raw (fire-propagator p0 net5) out-c))
  (printf "  inputs ~a: ~s\n" (map cell-id-n (propagator-inputs p0)) (for/list ([c (propagator-inputs p0)]) (net-cell-read-raw net5 c)))
  (printf "propagator 0: inputs ~a outputs ~a flags ~a\n" (map cell-id-n (propagator-inputs p0)) (map cell-id-n (propagator-outputs p0)) (propagator-flags p0))
  (define refired (fire-propagator p0 net5))
  (printf "cell 1 after the run: ~a ; after re-firing propagator ~a: ~a\n"
          (number->string (net-cell-read net5 worldview-cache-cell-id) 2) pidn (number->string (net-cell-read refired worldview-cache-cell-id) 2))
  (define (answers n) ((rel 'dissolve-solver-pu) n vars query-env answer-cid))
  (printf "answers from the run's result:           ~s\n" (answers net5))
  (printf "answers after S0 re-fires propagator 0:  ~s\n" (answers (run-to-quiescence refired)))
  (printf "production solve-goal-propagator:        ~s\n" ((rel 'solve-goal-propagator) cfg store name vars vars))
  (printf "DFS solve-goal:                          ~s\n" ((rel 'solve-goal) (rel '(make-solver-config (hasheq 'strategy 'depth-first))) store name vars vars)))

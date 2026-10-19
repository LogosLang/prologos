#lang racket/base
;; W2-7 Q1(b): is the :usage cell merge EXERCISED in production S0?  Who writes each :usage position?
;; Instrument (no rebuild): an injected BSP executor (current-parallel-executor) that fires each pid on a COPY of the
;; snapshot in which every attribute-map cell's installed merge (cold merge-fns champ, read by
;; net-cell-write/slow-path, propagator.rkt:1995-1996) is replaced by a LOGGING WRAPPER that delegates to
;; attribute-map-merge-fn unchanged.  The wrapper sees every :usage write as (old-at-pos, X = the fire's total)
;; BEFORE the merge, so writes the merge absorbs (add-usage(mw, ·) = mw) and equal re-writes (hidden by the equal?
;; guard at typing-propagators.rkt:466) are both visible.
;; Classes per :usage write:  first (old = bot) | equal re-write (X = old) | EXERCISED (old ≠ bot, X ≠ old).
;; For EXERCISED writes it reports same-writer vs other-writer, the relation old→X, and what each candidate merge
;; returns: today add-usage, chain max (join-usage), flat (⊤ if X ≠ old), replace (X).
;; Modes:  racket w27-usage-census.rkt power | qtt | <file.prologos>
(require racket/list racket/port racket/string
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/driver.rkt")
                  process-file process-string current-use-pnet-cache? current-pnet-write-enabled?)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/metavar-store.rkt")
                  with-fresh-meta-env)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt")
                  current-parallel-executor fire-and-collect-writes
                  prop-network-merge-fns prop-network-propagators
                  cell-id-hash prop-id-hash make-prop-network net-new-cell net-add-propagator net-cell-read
                  net-cell-write run-to-quiescence-bsp)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/champ.rkt")
                  champ-lookup champ-insert champ-fold)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/typing-propagators.rkt")
                  attribute-map-merge-fn that-write that-read)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/qtt.rkt")
                  add-usage scale-usage join-usage)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/prelude.rkt")
                  mult-leq))
(define prop-path '(file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt"))
(define with-merge-fns   ;; (net new-merge-fns-champ) -> net, via struct-copy inside propagator.rkt's namespace
  (parameterize ([current-namespace (module->namespace prop-path)])
    (eval '(lambda (net mf) (struct-copy prop-network net
                              [cold (struct-copy prop-net-cold (prop-network-cold net) [merge-fns mf])])))))

(define mode (vector-ref (current-command-line-arguments) 0))
(define (usage-of rec) (and (hash? rec) (hash-ref rec ':usage #f)))
(define (bot-u? u) (or (not u) (null? u)))
(define (prop-of snap pid) (champ-lookup (prop-network-propagators snap) (prop-id-hash pid) pid))
(define (writer-kind snap pid)
  (define p (prop-of snap pid))
  (if (eq? p 'none) "?"
      (let ([f (vector-ref (struct->vector p) 3)])
        (let ([n (object-name f)]) (if n (regexp-replace #rx"^.*/" (format "~a" n) "") "anon")))))
(define (pointwise-le a b) (and (= (length a) (length b)) (andmap mult-leq a b)))
(define (relation a b) (cond [(not (= (length a) (length b))) 'length-differs]
                             [(pointwise-le a b) 'up] [(pointwise-le b a) 'down] [else 'incomparable]))

;; ---- state ----
(define cur-pid #f) (define cur-snap #f)
(define n-fires 0) (define rounds 0)
(define n-first 0) (define n-equal 0)
(define writers (make-hasheq))     ;; pos -> list of pid-numbers
(define kinds (make-hash))
(define exercised '())
(define (pid-n p) (vector-ref (struct->vector p) 1))
(define (logging-merge old new)
  (when (and (hash? new) cur-pid)
    (for ([(pos rec) (in-hash new)])
      (define X (usage-of rec))
      (unless (bot-u? X)
        (define ou (usage-of (and (hash? old) (hash-ref old pos #f))))
        (define prev (hash-ref writers pos '()))
        (define me (pid-n cur-pid))
        (unless (memv me prev) (hash-set! writers pos (cons me prev)))
        (hash-update! kinds (writer-kind cur-snap cur-pid) add1 0)
        (cond
          [(bot-u? ou) (set! n-first (add1 n-first))]
          [(equal? ou X) (set! n-equal (add1 n-equal))]
          [else
           (set! exercised
                 (cons (list (if (and (pair? prev) (andmap (λ (q) (= q me)) prev)) 'same-writer 'other-writer)
                             (relation ou X) ou X (add-usage ou X) (join-usage ou X) 'TOP
                             (writer-kind cur-snap cur-pid))
                       exercised))]))))
  (attribute-map-merge-fn old new))
(define last-mf #f) (define last-wrapped #f)
(define (wrap-snapshot snap)
  (define mf (prop-network-merge-fns snap))
  (unless (eq? mf last-mf)
    (set! last-mf mf)
    (set! last-wrapped
          (champ-fold mf (λ (cid f acc) (if (eq? f attribute-map-merge-fn)
                                             (champ-insert acc (cell-id-hash cid) cid logging-merge)
                                             acc))
                      mf)))
  (with-merge-fns snap last-wrapped))
(define (instrumented snap pids)
  (set! rounds (add1 rounds))
  (define snap* (wrap-snapshot snap))
  (set! cur-snap snap)
  (begin0
    (for/list ([pid (in-list pids)] [idx (in-naturals 1)])
      (set! n-fires (add1 n-fires))
      (set! cur-pid pid)
      (begin0 (fire-and-collect-writes snap* pid idx) (set! cur-pid #f)))
    (set! cur-snap #f)))

(define (report label)
  (define multi (for/sum ([(pos ps) (in-hash writers)]) (if (> (length ps) 1) 1 0)))
  (printf "W27-USAGE ~a\n" label)
  (printf "  BSP rounds ~a, fires ~a\n" rounds n-fires)
  (printf "  :usage writes seen by the merge: first (old=bot) ~a | equal re-write ~a | EXERCISED (old≠bot, X≠old) ~a\n"
          n-first n-equal (length exercised))
  (printf "  :usage positions ~a; positions with >1 distinct writer pid ~a\n" (hash-count writers) multi)
  (define (tally f) (let ([h (make-hash)]) (for ([r exercised]) (hash-update! h (f r) add1 0)) (sort (hash->list h) > #:key cdr)))
  (printf "    exercised by writer: ~s\n" (tally car))
  (printf "    exercised by relation old->X: ~s\n" (tally cadr))
  (printf "    exercised by writer kind: ~s\n" (tally (λ (r) (list-ref r 7))))
  (for ([r (take exercised (min 6 (length exercised)))])
    (printf "    e.g. ~a ~a old=~s X=~s | today add-usage=~s  chain-max=~s  flat=~s  replace=~s  [~a]\n"
            (list-ref r 0) (list-ref r 1) (list-ref r 2) (list-ref r 3) (list-ref r 4) (list-ref r 5) (list-ref r 6)
            (list-ref r 3) (list-ref r 7)))
  (printf "  writer kinds (top 14): ~s\n" (take (sort (hash->list kinds) > #:key cdr) (min 14 (hash-count kinds)))))

(define preload "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/benchmarks/par4/preload-empty.prologos")
(define (quiet thunk) (parameterize ([current-output-port (open-output-nowhere)]) (thunk)))
(define (short r) (if (string? r) (car (string-split r "\n"))
                      (let ([s (format "~a" r)]) (string-append "ERR:" (substring s 0 (min 60 (string-length s)))))))

(cond
  [(equal? mode "power")
   ;; fixture 1: two DIFFERENT propagators write different usage at one position (two writers)
   ;; fixture 2: ONE propagator re-fires after its multiplicity input changes from "unsolved" (read as mw, the
   ;;            :1699 default) to m1 — a revision of its own total that add-usage ABSORBS (mw + m1 = mw)
   (define net0 (make-prop-network))
   (define-values (net1 am) (net-new-cell net0 (hasheq) attribute-map-merge-fn))
   (define-values (net2 mc) (net-new-cell net1 'unsolved (λ (o n) n)))
   (define-values (net3 go) (net-new-cell net2 #f (λ (o n) (or o n))))
   (define-values (net4 _p1) (net-add-propagator net3 (list go) (list am)
                               (λ (n) (if (net-cell-read n go) (that-write n am 'pos-a ':usage '(m1)) n))))
   (define-values (net5 _p2) (net-add-propagator net4 (list go) (list am)
                               (λ (n) (if (net-cell-read n go) (that-write n am 'pos-a ':usage '(m0)) n))))
   (define-values (net6 _p3) (net-add-propagator net5 (list mc) (list am)
                               (λ (n) (let* ([m (net-cell-read n mc)] [eff (if (memq m '(m0 m1 mw)) m 'mw)])
                                        (that-write n am 'pos-b ':usage (scale-usage eff '(m1)))))))
   (define net7 (net-cell-write net6 go #t))
   (parameterize ([current-parallel-executor instrumented])
     (define n8 (run-to-quiescence-bsp net7))
     (define n9 (run-to-quiescence-bsp (net-cell-write n8 mc 'm1)))
     (printf "POWER fixture final: pos-a ~s pos-b ~s\n" (that-read (net-cell-read n9 am) 'pos-a ':usage)
             (that-read (net-cell-read n9 am) 'pos-b ':usage)))
   (report "POWER (expect 2 exercised: pos-a other-writer; pos-b same-writer down mw->m1 absorbed by add-usage)")]
  [(equal? mode "qtt")
   ;; programs: verbatim strings from tests/test-qtt-pipeline.rkt and tests/test-mult-inference.rkt, plus three
   ;; applications of an un-annotated lambda (its Pi mult is a mult-meta when the app usage fire runs, :1699)
   (define progs
     (list "(def id <(-> Nat Nat)> (fn [x <Nat>] x))\n(eval (id zero))"
           "(def lin-id <(Pi [x :1 <Nat>] Nat)> (fn [x :1 <Nat>] x))\n(eval (lin-id zero))"
           "(def erased-c <(Pi [x :0 <Nat>] Nat)> (fn [x :0 <Nat>] zero))\n(eval (erased-c zero))"
           "(def use-twice <(-> Nat Nat)> (fn [x <Nat>] (natrec (fn [_ <Nat>] Nat) x (fn [_ <Nat>] (fn [r <Nat>] (suc r))) x)))"
           "(def dup <(Pi [x :1 <Nat>] Nat)> (fn [x :1 <Nat>] (natrec (fn [_ <Nat>] Nat) x (fn [_ <Nat>] (fn [r <Nat>] (suc r))) x)))"
           "(def drop <(Pi [x :1 <Nat>] Nat)> (fn [x :1 <Nat>] zero))"
           "(def use-erased <(Pi [x :0 <Nat>] Nat)> (fn [x :0 <Nat>] x))"
           "(def suc-erased <(Pi [x :0 <Nat>] Nat)> (fn [x :0 <Nat>] (suc x)))"
           "(def m1ok <(Pi [y :1 <Nat>] (Pi [s <Nat>] Nat))> (fn [y :1 <Nat>] (fn [s <Nat>] (match s (zero -> y) (suc _ -> y)))))"
           "(def m1leak <(Pi [y :1 <Nat>] (Pi [s <Nat>] Nat))> (fn [y :1 <Nat>] (fn [s <Nat>] (match s (zero -> y) (suc _ -> zero)))))"
           "(def r <Nat> (let a : Nat := (suc zero) a))\n(eval r)"
           "(def linear-id <(Pi [x :1 <Nat>] Nat)> (fn [x <Nat>] x))\n(eval (linear-id zero))"
           "(eval (the (-> Nat Nat) (fn [x <Nat>] x)))"
           "(def k1 <(Pi [y :1 <Nat>] Nat)> (fn [y :1 <Nat>] ((fn [x <Nat>] x) y)))"
           "(def k2 <(Pi [y :1 <Nat>] Nat)> (fn [y :1 <Nat>] ((fn [x :1 <Nat>] x) y)))"
           "(def k3 <(-> Nat Nat)> (fn [y <Nat>] ((fn [x <Nat>] (natrec (fn [_ <Nat>] Nat) x (fn [_ <Nat>] (fn [r <Nat>] (suc r))) x)) y)))"))
   (define (run-all) (for/list ([s progs]) (map short (with-fresh-meta-env (quiet (λ () (process-string s)))))))
   (define plain (run-all))                                              ;; perturbation control: no instrument
   (define verdicts (parameterize ([current-parallel-executor instrumented]) (run-all)))
   (for ([s progs] [v verdicts]) (printf "  ~a\n    -> ~s\n" (car (string-split s "\n")) v))
   (printf "  instrumented results identical to uninstrumented: ~a\n" (equal? plain verdicts))
   (report "QTT programs (16)")]
  [else
   (quiet (λ () (parameterize ([current-use-pnet-cache? #t] [current-pnet-write-enabled? #f]) (process-file preload))))
   (parameterize ([current-parallel-executor instrumented] [current-use-pnet-cache? #t] [current-pnet-write-enabled? #f])
     (quiet (λ () (process-file mode))))
   (report mode)])

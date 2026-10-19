#lang racket/base
;; C4 (PAR 4 D.3, SRE lens) — is cell-1 one lattice? D.2 §6.3 row 1 makes the worldview cache a two-phase set
;; (committed bits ior, invalidated bits ior). Production ALSO uses cell-1 as a read VIEWPOINT that is switched by
;; replacement: atms.rkt:588-596 solver-state-with-worldview, used by solver-state-solve-all (:658-685).
;; This probe replays test-solver-context.rkt:341-362 ("solve-all: enumeration through with-worldview + read-cell")
;; twice: with production's merge on cell-1 (replacement, propagator.rkt:964), and with cell-1's merge swapped to
;; the committed component of D.2's target (bitwise-ior). Same code otherwise.
;; Run: ROOT=<racket/prologos> racket c4-worldview-viewpoint.rkt
(define root (or (getenv "ROOT")
                 "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos"))
(define (p f) (list 'file (string-append root "/" f)))
(define (get f id) (dynamic-require (p f) id))
(define atms-ns (begin (dynamic-require (p "atms.rkt") #f) (module->namespace (p "atms.rkt"))))
(define prop-ns (begin (dynamic-require (p "propagator.rkt") #f) (module->namespace (p "propagator.rkt"))))
(define make-solver-state (get "atms.rkt" 'make-solver-state))
(define solver-state-amb (get "atms.rkt" 'solver-state-amb))
(define solver-state-with-worldview (get "atms.rkt" 'solver-state-with-worldview))
(define solver-state-write-cell (get "atms.rkt" 'solver-state-write-cell))
(define solver-state-solve-all (get "atms.rkt" 'solver-state-solve-all))
(define make-prop-network (get "propagator.rkt" 'make-prop-network))
(define net-cell-read-raw (get "propagator.rkt" 'net-cell-read-raw))
(define wv-cid (get "propagator.rkt" 'worldview-cache-cell-id))
(define set-cell1-merge
  (eval '(lambda (net f)
           (struct-copy prop-network net
             [cold (struct-copy prop-net-cold (prop-network-cold net)
                     [merge-fns (champ-insert (prop-network-merge-fns net)
                                              (cell-id-hash worldview-cache-cell-id) worldview-cache-cell-id f)])]))
        prop-ns))
(define ss-net (eval 'solver-state-net atms-ns))
(define with-net (eval '(lambda (ss net) (solver-state (solver-state-ctx ss) net (solver-state-key-map ss) (solver-state-amb-groups ss))) atms-ns))

(define (run label cell1-merge)
  (define ss00 (make-solver-state (make-prop-network)))
  (define ss0 (if cell1-merge (with-net ss00 (set-cell1-merge (ss-net ss00) cell1-merge)) ss00))
  (define-values (ss1 hyps) (solver-state-amb ss0 '(left right)))
  (define h-left (car hyps)) (define h-right (cadr hyps))
  (define (wv ss) (net-cell-read-raw (ss-net ss) wv-cid))
  (define ss-left (solver-state-with-worldview ss1 (hasheq h-left #t)))
  (define ss-left2 (solver-state-write-cell ss-left 'goal 'val-left))
  (define ss-full (solver-state-with-worldview ss-left2 (hasheq h-left #t h-right #t)))
  (define ss-right (solver-state-with-worldview ss-full (hasheq h-right #t)))
  (define ss-right2 (solver-state-write-cell ss-right 'goal 'val-right))
  (define ss-final (solver-state-with-worldview ss-right2 (hasheq h-left #t h-right #t)))
  (define answers (solver-state-solve-all ss-final 'goal))
  (printf "~a\n  cell-1 after amb ~b, after with-worldview{left} ~b, {right} ~b\n  solve-all answers: ~s   (test expects 2: val-left, val-right)\n"
          label (wv ss1) (wv ss-left) (wv ss-right) answers))

(run "PRODUCTION cell-1 merge (replacement)" #f)
(run "cell-1 merge = bitwise-ior (D.2 row 1, committed component)" (lambda (o n) (bitwise-ior o n)))

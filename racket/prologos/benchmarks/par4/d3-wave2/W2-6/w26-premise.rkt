#lang racket/base
;; W2-6 (PAR 4 D.3 wave 2, CL-6 (b)) — the THIRD role of cell-1: the default viewpoint of every unlabelled reader.
;; Elaboration's speculation commits by doing NOTHING: the hypothesis bit stays in cell-1 (elab-speculation-bridge.rkt
;; :305-309), and later readers with no per-propagator W fall back to cell-1 (net-cell-read propagator.rkt:1601-1606;
;; meta-universe.rkt:283-300, whose comment records that without the fallback test-speculation-bridge.rkt
;; "success — keeps meta-state" (:69-88) broke). C4-4/C2-4's (b) deletes that fallback. This probe checks, on the real
;; tagged-cell substrate, what the read gives after a committed hypothesis h1 and a failed hypothesis h2 under:
;;   TODAY     cell-1 as viewpoint (h1 kept, h2 set during its thunk then cleared)
;;   B-BARE    (b) with no commit rule: an unlabelled read uses W = 0
;;   B-LIVE    (b) but unlabelled fires read W = live(α) = C ∧ ¬X  (the two-phase set read INSIDE S0)
;;   B-PREMISE (b) + a grow-only premise set P (committed hypotheses): an unlabelled read uses W = W_p ∪ P
;; and whether the value an unlabelled S0 reader sees is monotone along the command (it must be, for a fire).
;; Run: racket w26-premise.rkt
(require racket/list
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt")
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/decision-cell.rkt")
                  tagged-cell-value tagged-cell-value? tagged-cell-value-base tagged-cell-value-entries make-tagged-merge))
(define (flat a b) (cond [(eq? a 'bot) b] [(eq? b 'bot) a] [(equal? a b) a] [else 'top]))   ;; a flat type lattice
(define (rank v) (case v [(bot) 0] [(top) 2] [else 1]))
(define (flat<= a b) (or (eq? a 'bot) (eq? b 'top) (equal? a b)))
(define (ev raw W) (if (tagged-cell-value? raw)
                       (for/fold ([acc (tagged-cell-value-base raw)]) ([e (tagged-cell-value-entries raw)] #:when (= (bitwise-and (car e) W) (car e))) (flat acc (cdr e)))
                       raw))
(define-values (n0 M) (net-new-cell (make-prop-network) (tagged-cell-value 'bot '()) (make-tagged-merge flat)))
(define h1 1) (define h2 2)
;; the command, as a list of states: (net cell1 C X P label)
(define (write-under net W v) (parameterize ([current-worldview-bitmask W]) (net-cell-write net M v)))
(define s0 (list n0 0 0 0 0 "start"))
(define s1 (list (write-under n0 h1 'Bool) h1 h1 0 0 "h1 thunk wrote Bool under h1"))
(define s2 (list (car s1) h1 h1 0 h1 "h1 succeeded (commit)"))
(define s3 (list (write-under (car s2) (bitwise-ior h1 h2) 'Nat) (bitwise-ior h1 h2) (bitwise-ior h1 h2) 0 h1 "h2 thunk wrote Nat under h1|h2"))
(define s4 (list (car s3) h1 (bitwise-ior h1 h2) h2 h1 "h2 failed (cleared / excluded)"))
(define states (list s0 s1 s2 s3 s4))
(define rules
  (list (cons "TODAY (W = cell-1)" (λ (s) (list-ref s 1)))
        (cons "B-BARE (W = 0)" (λ (s) 0))
        (cons "B-LIVE (W = C ∧ ¬X)" (λ (s) (bitwise-and (list-ref s 2) (bitwise-not (list-ref s 3)))))
        (cons "B-PREMISE (W = 0 ∪ P)" (λ (s) (list-ref s 4)))))
(for ([r rules])
  (define reads (for/list ([s states]) (ev (net-cell-read-raw (car s) M) ((cdr r) s))))
  (define nonmono (for/sum ([a reads] [b (cdr reads)]) (if (flat<= a b) 0 1)))
  (printf "~a: reads along the command ~s ; non-monotone steps ~a ; final read ~a (test-speculation-bridge.rkt:69-88 expects the committed Bool)\n"
          (car r) reads nonmono (last reads)))
(printf "the thunk of h2 itself reads at its own W = h1|h2 (elab-speculation-bridge.rkt:296-300): ~a\n"
        (ev (net-cell-read-raw (car s3) M) (bitwise-ior h1 h2)))

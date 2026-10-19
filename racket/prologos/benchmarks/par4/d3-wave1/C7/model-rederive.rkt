#lang racket/base
;; C7 probe 3: P0's per-file models re-derived at HEAD with ONE instrument set, in one process:
;; profile (1 ms sampler, P0's do-profile) over REPS runs of the target after an untimed empty preload,
;; with current-bsp-round-stats collected over the SAME runs. Reports:
;;  - command ms/run = process-command inclusive / reps (P0's denominator)
;;  - bulk-merge-writes / run-to-quiescence-bsp / fire-and-collect-writes shares (P0 §10.2's columns)
;;  - round stats per run: fire, merge, fire in rounds >= 8 wide, Σ fire/min(n,8)
;;  - H-S = cmd / (cmd - merge) and H-S+K8 = cmd / (cmd - fire - merge + Σ fire/min(n,8) + L*rounds)
;;    using the SAME runs' round stats (P0 used a separate single-run `stats` process for the numerator)
(require racket/port racket/list
         (only-in profile profile-thunk)
         (only-in profile/analyzer profile-nodes node-id node-total node-self profile-total-time profile-sample-number)
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/driver.rkt")
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt"))
(define root "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/")
(define fname (or (getenv "C7_FILE") "constraints-adversarial.prologos"))
(define target (string-append root "benchmarks/comparative/" fname))
(define reps (string->number (or (getenv "C7_REPS") "10")))
(define (r2 x) (/ (round (* 100 (exact->inexact x))) 100.0))
(define (run-file f)
  (parameterize ([current-output-port (open-output-nowhere)]
                 [current-error-port (open-output-nowhere)]
                 [current-pnet-write-enabled? #f])
    (process-file f)))
(void (run-file (string-append root "benchmarks/par4/preload-empty.prologos")))

(define rounds (box '()))
(define captured #f)
(define t0 (current-inexact-monotonic-milliseconds))
(parameterize ([current-bsp-round-stats rounds])
  (profile-thunk (λ () (for ([_ reps]) (run-file target))) #:delay 0.001 #:render (λ (p o) (set! captured p))))
(define wall (- (current-inexact-monotonic-milliseconds) t0))
(define by-name (make-hash))
(for ([n (profile-nodes captured)])
  (hash-update! by-name (format "~a" (or (node-id n) "?")) (λ (v) (+ v (node-total n))) 0))
(define (incl k) (hash-ref by-name k 0))
(define cmd (/ (incl "process-command") reps))
(define rs (unbox rounds))
(define fire (/ (for/sum ([r rs]) (cadr r)) reps))
(define merge (/ (for/sum ([r rs]) (caddr r)) reps))
(define fire-wide (/ (for/sum ([r rs] #:when (>= (car r) 8)) (cadr r)) reps))
(define fire/k8 (/ (for/sum ([r rs]) (/ (cadr r) (min (max 1 (car r)) 8))) reps))
(define nrounds (/ (length rs) reps))
(printf "file ~a reps ~a samples ~a wall ~a ms\n" fname reps (profile-sample-number captured) (r2 wall))
(printf "command ms/run ~a | shares of command: rtq-bsp ~a%  fire-and-collect ~a%  bulk-merge ~a%  pu-value-diff ~a%\n"
        (r2 cmd) (r2 (* 100 (/ (incl "run-to-quiescence-bsp") reps cmd))) (r2 (* 100 (/ (incl "fire-and-collect-writes") reps cmd)))
        (r2 (* 100 (/ (incl "bulk-merge-writes") reps cmd))) (r2 (* 100 (/ (incl "pu-value-diff") reps cmd))))
(printf "round stats per run: rounds ~a fires ~a fire ~a ms (width>=8: ~a) merge ~a ms  sum fire/min(n,8) ~a ms\n"
        (r2 nrounds) (r2 (/ (apply + (map car rs)) reps)) (r2 fire) (r2 fire-wide) (r2 merge) (r2 fire/k8))
(printf "MODELS (P0 formulas, same-run inputs): H-S ~ax   H-S+K8 ~ax   | profile-only H-S (bulk-merge removed) ~ax\n"
        (r2 (/ cmd (- cmd merge)))
        (r2 (/ cmd (+ (- cmd fire merge) fire/k8 (* 0.001 nrounds))))
        (r2 (/ 1 (- 1 (/ (incl "bulk-merge-writes") reps cmd)))))
